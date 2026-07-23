// Ported from Sources/AnagramEngine/Phonetics.swift

/**
 * Phonetic queries backed by the CMU Pronouncing Dictionary.
 *
 * CMUdict line format (cmudict.dict):  `word P H ON EM`
 * Vowel phonemes carry a stress digit (0/1/2); consonants don't. Alternate
 * pronunciations appear as `word(2)`. Lines may end with a `#` comment.
 */
export class PhoneticDictionary {
  /** word -> list of pronunciations (each a phoneme array) */
  private readonly prons: Map<string, string[][]>;
  /** perfect-rhyme key (last stressed vowel → end) -> words */
  private readonly rhymeIndex: Map<string, Set<string>>;
  /** full pronunciation, stress stripped -> words (for homophones) */
  private readonly homophoneIndex: Map<string, Set<string>>;

  constructor(cmudictText: string) {
    this.prons = new Map();
    this.rhymeIndex = new Map();
    this.homophoneIndex = new Map();

    for (const rawLine of cmudictText.split("\n")) {
      // Strip trailing comment.
      let line = rawLine;
      const hash = line.indexOf("#");
      if (hash !== -1) line = line.slice(0, hash);
      const tokens = line.split(/[ \t]+/).filter((t) => t.length > 0);
      if (tokens.length < 2) continue;

      // Word, dropping any "(2)" variant suffix.
      let word = tokens[0]!.toLowerCase();
      const paren = word.indexOf("(");
      if (paren !== -1) word = word.slice(0, paren);
      if (!/^[a-z'-]+$/.test(word)) continue;

      const phonemes = tokens.slice(1);
      let list = this.prons.get(word);
      if (!list) this.prons.set(word, (list = []));
      list.push(phonemes);

      const key = PhoneticDictionary.rhymeKey(phonemes);
      if (key !== null) {
        let bucket = this.rhymeIndex.get(key);
        if (!bucket) this.rhymeIndex.set(key, (bucket = new Set()));
        bucket.add(word);
      }
      const homoKey = phonemes.map(stripStress).join(" ");
      let hb = this.homophoneIndex.get(homoKey);
      if (!hb) this.homophoneIndex.set(homoKey, (hb = new Set()));
      hb.add(word);
    }
  }

  /**
   * Fast path for the baked lexicon format (`word|PHONES|RHYMEKEY`, one line
   * per word, phones already stress-stripped, rhyme key precomputed — see
   * scripts/build-lexicon.mjs). Skips the cmudict parse entirely.
   */
  static fromLexicon(text: string): PhoneticDictionary {
    const dict = new PhoneticDictionary("");
    for (const line of text.split("\n")) {
      if (line.length === 0) continue;
      const [word, ph, rk] = line.split("|");
      if (!word || !ph) continue;
      const phones = ph.split(" ");
      let list = dict.prons.get(word);
      if (!list) dict.prons.set(word, (list = []));
      list.push(phones);
      if (rk) {
        let bucket = dict.rhymeIndex.get(rk);
        if (!bucket) dict.rhymeIndex.set(rk, (bucket = new Set()));
        bucket.add(word);
      }
      let hb = dict.homophoneIndex.get(ph);
      if (!hb) dict.homophoneIndex.set(ph, (hb = new Set()));
      hb.add(word);
    }
    return dict;
  }

  get count(): number {
    return this.prons.size;
  }

  isKnown(word: string): boolean {
    return this.prons.has(word.toLowerCase());
  }

  /**
   * Syllable count = number of vowel phonemes. Returns null if the word isn't
   * in the dictionary. (Swift counts stress digits; every ARPABET vowel starts
   * with A/E/I/O/U and no consonant does, so this test is equivalent on
   * cmudict input — and, unlike the digit test, also works on the baked
   * lexicon, whose phones are stress-stripped.)
   */
  syllableCount(word: string): number | null {
    const first = this.prons.get(word.toLowerCase())?.[0];
    if (!first) return null;
    return first.filter((p) => /^[AEIOU]/.test(p)).length;
  }

  /**
   * Words that perfectly rhyme with `word` (share the sound from the last
   * stressed vowel onward), excluding the word itself.
   */
  rhymes(word: string): string[] {
    const w = word.toLowerCase();
    const prons = this.prons.get(w);
    if (!prons) return [];
    const result = new Set<string>();
    for (const p of prons) {
      const key = PhoneticDictionary.rhymeKey(p);
      if (key !== null) {
        for (const r of this.rhymeIndex.get(key) ?? []) result.add(r);
      }
    }
    result.delete(w);
    return [...result].sort();
  }

  /** Words pronounced identically to `word` (different spelling). */
  homophones(word: string): string[] {
    const w = word.toLowerCase();
    const prons = this.prons.get(w);
    if (!prons) return [];
    const result = new Set<string>();
    for (const p of prons) {
      const key = p.map(stripStress).join(" ");
      for (const h of this.homophoneIndex.get(key) ?? []) result.add(h);
    }
    result.delete(w);
    return [...result].sort();
  }

  /** All pronunciations of `word` (raw phonemes, stress digits intact). */
  pronunciations(word: string): string[][] {
    return this.prons.get(word.toLowerCase()) ?? [];
  }

  /** Words whose full stress-stripped pronunciation equals `phones`. */
  wordsPronouncedAs(phones: string[]): Set<string> {
    return this.homophoneIndex.get(phones.join(" ")) ?? new Set();
  }

  /**
   * Every word with its first (primary) pronunciation, stress stripped —
   * the raw material for phoneme-level neighborhood searches.
   */
  allStrippedPronunciations(): Array<{ word: string; phones: string[] }> {
    const out: Array<{ word: string; phones: string[] }> = [];
    for (const [word, prons] of this.prons) {
      const first = prons[0];
      if (first) out.push({ word, phones: first.map(stripStress) });
    }
    return out;
  }

  /**
   * Key for perfect rhyme: phonemes from the last stressed vowel to the end.
   * Falls back to the last vowel if none carry primary/secondary stress.
   */
  static rhymeKey(phonemes: string[]): string | null {
    let lastStressed = -1;
    let lastVowel = -1;
    for (let i = 0; i < phonemes.length; i++) {
      const p = phonemes[i]!;
      if (/\d/.test(p)) {
        lastVowel = i;
        if (p.includes("1") || p.includes("2")) lastStressed = i;
      }
    }
    const start = lastStressed >= 0 ? lastStressed : lastVowel;
    if (start < 0) return null;
    return phonemes.slice(start).map(stripStress).join(" ");
  }
}

/** Remove the stress digit from a phoneme ("AE1" → "AE"). */
export function stripStress(phoneme: string): string {
  return phoneme.replace(/\d/g, "");
}
