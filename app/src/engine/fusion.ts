// Ported from Sources/AnagramEngine/Fusion.swift
import { PhoneticDictionary, stripStress } from "./phonetics";
import { WordList } from "./wordList";

/** Where the partner word sits relative to the seed. */
export type FusionPosition = "before" | "after";

export interface Fusion {
  /** "brain" */
  partner: string;
  /** "angel" */
  seed: string;
  position: FusionPosition;
  /** ["EY", "N"] (stress stripped) */
  sharedPhones: string[];
  /** ["B","R","EY","N","JH","AH","L"] */
  fusedPhones: string[];
  /** "brangel" (heuristic suggestion) */
  spelling: string;
  /** other words audible in the stream */
  bonusWords: string[];
}

interface Entry {
  word: string;
  /** first pronunciation, stress stripped */
  phones: string[];
}

/**
 * CMU vowel phonemes (stress stripped). A fused-stream "AH" (schwa-ish)
 * is allowed to stand in for any of these when hunting bonus words.
 */
const VOWELS = new Set([
  "AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER",
  "EY", "IH", "IY", "OW", "OY", "UH", "UW",
]);

/**
 * Phonetic fusions: overlap two words by *sound* so both stay audible in one
 * pseudo-word — brain + angel share /EY N/, giving "brangel", in which you
 * also hear "rain" and (schwa-flexed) "gel".
 *
 * Linguistically these are overlapping blends; perceptually they are one-word
 * oronyms (a single sound stream with several word parses).
 */
export class FusionFinder {
  private readonly phonetics: PhoneticDictionary;
  private readonly allowed: Set<string>;
  private readonly entries: Entry[];

  constructor(phonetics: PhoneticDictionary, wordList: WordList) {
    this.phonetics = phonetics;
    this.allowed = new Set();
    this.entries = [];
    for (const word of wordList.words) {
      const pron = phonetics.pronunciations(word)[0];
      if (!pron) continue;
      this.allowed.add(word);
      this.entries.push({ word, phones: pron.map(stripStress) });
    }
  }

  /**
   * All fusions of `seed` with dictionary words, longest sound-overlap first.
   * `minOverlap` is in phonemes; both words must contribute at least one
   * phoneme beyond the shared stretch. Bonus words are computed for the
   * returned (capped) results only.
   */
  fusions(
    seed: string,
    positions: FusionPosition[] = ["before", "after"],
    minOverlap = 2,
    cap = 200,
  ): Fusion[] {
    const s = seed.toLowerCase();
    const seedPron = this.phonetics.pronunciations(s)[0];
    if (!seedPron) return [];
    const seedPhones = seedPron.map(stripStress);

    const results: Fusion[] = [];
    for (const entry of this.entries) {
      if (entry.word === s) continue;
      for (const position of positions) {
        const k = maxOverlap(entry.phones, seedPhones, position);
        if (k === null || k < minOverlap) continue;
        let shared: string[];
        let fused: string[];
        if (position === "before") {
          shared = seedPhones.slice(0, k);
          fused = [...entry.phones, ...seedPhones.slice(k)];
        } else {
          shared = entry.phones.slice(0, k);
          fused = [...seedPhones, ...entry.phones.slice(k)];
        }
        results.push({
          partner: entry.word,
          seed: s,
          position,
          sharedPhones: shared,
          fusedPhones: fused,
          spelling: spellingGuess(entry.word, entry.phones, s, k, position),
          bonusWords: [],
        });
      }
    }

    results.sort((a, b) => {
      if (a.sharedPhones.length !== b.sharedPhones.length) {
        return b.sharedPhones.length - a.sharedPhones.length;
      }
      if (a.fusedPhones.length !== b.fusedPhones.length) {
        return a.fusedPhones.length - b.fusedPhones.length;
      }
      return a.partner < b.partner ? -1 : 1;
    });
    const capped = results.slice(0, cap);
    for (const f of capped) {
      f.bonusWords = this.bonusWords(f.fusedPhones, new Set([f.seed, f.partner]));
    }
    return capped;
  }

  /**
   * Dictionary words audible inside `word`'s own pronunciation (the
   * bonus-word scan, run on the word itself): "rain" hides in "brain".
   */
  audibleWords(word: string): string[] {
    const w = word.toLowerCase();
    const pron = this.phonetics.pronunciations(w)[0];
    if (!pron) return [];
    return this.bonusWords(pron.map(stripStress), new Set([w]));
  }

  /**
   * Dictionary words audible as a contiguous run inside `phones`. An "AH"
   * in the stream may stand in for any vowel (spoken schwas are elastic —
   * that's how "gel" /JH EH L/ hides in brangel's /JH AH L/).
   */
  private bonusWords(phones: string[], excluding: Set<string>): string[] {
    const found = new Set<string>();
    const n = phones.length;
    for (let start = 0; start < n; start++) {
      const maxEnd = Math.min(start + 8, n);
      if (start + 2 > maxEnd) continue;
      for (let end = start + 2; end <= maxEnd; end++) {
        const slice = phones.slice(start, end);
        if (!slice.some((p) => VOWELS.has(p))) continue;
        for (const key of schwaVariants(slice)) {
          for (const word of this.phonetics.wordsPronouncedAs(key)) {
            if (word.length >= 3 && this.allowed.has(word) && !excluding.has(word)) {
              found.add(word);
            }
          }
        }
      }
    }
    return [...found]
      .sort((a, b) => (a.length !== b.length ? b.length - a.length : a < b ? 1 : -1))
      .slice(0, 6)
      .sort();
  }
}

/**
 * Longest k such that the partner and seed share k phonemes at the joint,
 * with both words extending past it. Null if below 1.
 */
function maxOverlap(partner: string[], seed: string[], position: FusionPosition): number | null {
  const limit = Math.min(partner.length, seed.length) - 1;
  if (limit < 1) return null;
  for (let k = limit; k >= 1; k--) {
    if (position === "before") {
      if (arraysEqual(partner.slice(partner.length - k), seed.slice(0, k))) return k;
    } else {
      if (arraysEqual(seed.slice(seed.length - k), partner.slice(0, k))) return k;
    }
  }
  return null;
}

function arraysEqual(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}

/**
 * The slice itself plus every vowel-substitution of its "AH" positions
 * (capped at 2 schwas to bound the expansion). Slices under 3 phones get
 * no flexing — with one consonant of context, "AH → any vowel" claims
 * you can hear "aisle" in a schwa, which is a stretch too far.
 *
 * (Port note: the legacy JS re-appended the original slice after the
 * substitution loop — redundant, since AH ∈ VOWELS regenerates it. Ported
 * from the Swift original, which doesn't.)
 */
function schwaVariants(phones: string[]): string[][] {
  if (phones.length < 3) return [phones];
  const schwaIdx: number[] = [];
  phones.forEach((p, i) => {
    if (p === "AH") schwaIdx.push(i);
  });
  if (schwaIdx.length === 0 || schwaIdx.length > 2) return [phones];
  let variants: string[][] = [phones];
  for (const idx of schwaIdx) {
    const next: string[][] = [];
    for (const v of variants) {
      for (const vowel of VOWELS) {
        const copy = [...v];
        copy[idx] = vowel;
        next.push(copy);
      }
    }
    variants = next;
  }
  return variants;
}

/**
 * Written form is a guess — phones don't map cleanly to letters. Estimate
 * how many of the partner's letters spell the shared phones (proportional
 * to its phone count) and splice the rest onto the seed's spelling:
 * brain (5 letters, 4 phones, 2 shared) → drop ceil(5·2/4)=3 → "br"+"angel".
 */
function spellingGuess(
  partner: string,
  partnerPhones: string[],
  seed: string,
  overlap: number,
  position: FusionPosition,
): string {
  const letters = partner.length;
  const dropCount = Math.min(
    letters - 1,
    Math.ceil((letters * overlap) / partnerPhones.length),
  );
  if (position === "before") return partner.slice(0, letters - dropCount) + seed;
  return seed + partner.slice(dropCount);
}
