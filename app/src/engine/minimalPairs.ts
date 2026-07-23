// Ported from Sources/AnagramEngine/MinimalPairs.swift
import { PhoneticDictionary } from "./phonetics";

/** One minimal-pair neighbor: the word, and the contrast that makes it one. */
export interface MinimalPairNeighbor {
  word: string;
  /** phoneme index that differs */
  position: number;
  /** this word's phoneme there */
  from: string;
  /** the neighbor's phoneme there */
  to: string;
  /** human description of the difference */
  contrast: string;
}

/**
 * Minimal pairs: two words whose pronunciations differ by exactly one
 * phoneme in the same position — `pat`/`bat`, `sip`/`ship`, `bit`/`beat`.
 *
 * This is the phonological counterpart to the orthographic "one letter away"
 * ladder: it works in *sound*, not spelling, and names the single distinctive
 * feature that separates the two words (voicing, place, manner, or a vowel
 * dimension). Minimal pairs are the classic evidence that two sounds contrast
 * in a language, so this turns the word list into a phonology instrument.
 */
export class MinimalPairFinder {
  /**
   * Wildcard key ("_" at position i) -> [(word, phoneme-at-i)].
   * Two entries under the same key are a minimal pair at position i.
   */
  private readonly index: Map<string, Array<{ word: string; phoneme: string }>>;
  /** word -> its stress-stripped phonemes, so a query needs no rescan. */
  private readonly phonesOf: Map<string, string[]>;

  constructor(phonetics: PhoneticDictionary) {
    this.index = new Map();
    this.phonesOf = new Map();
    for (const { word, phones } of phonetics.allStrippedPronunciations()) {
      if (phones.length === 0) continue;
      this.phonesOf.set(word, phones);
      for (let i = 0; i < phones.length; i++) {
        const here = phones[i]!;
        const key = [...phones.slice(0, i), "_", ...phones.slice(i + 1)].join(" ");
        let bucket = this.index.get(key);
        if (!bucket) this.index.set(key, (bucket = []));
        bucket.push({ word, phoneme: here });
      }
    }
  }

  /**
   * Minimal pairs of `word`, each annotated with the distinctive feature
   * that separates it from `word`. Sorted by contrast type then word.
   */
  pairs(word: string): MinimalPairNeighbor[] {
    const w = word.toLowerCase();
    const phones = this.phonesOf.get(w);
    if (!phones) return [];

    const out: MinimalPairNeighbor[] = [];
    const seen = new Set<string>();
    for (let i = 0; i < phones.length; i++) {
      const here = phones[i]!;
      const key = [...phones.slice(0, i), "_", ...phones.slice(i + 1)].join(" ");
      for (const entry of this.index.get(key) ?? []) {
        if (entry.word === w || seen.has(entry.word)) continue;
        seen.add(entry.word);
        out.push({
          word: entry.word,
          position: i,
          from: here,
          to: entry.phoneme,
          contrast: describeContrast(here, entry.phoneme),
        });
      }
    }
    return out.sort((a, b) =>
      a.contrast !== b.contrast
        ? a.contrast < b.contrast
          ? -1
          : 1
        : a.word < b.word
          ? -1
          : 1,
    );
  }
}

// MARK: Distinctive features (ARPABET)

type Kind = "consonant" | "vowel";

interface Feat {
  kind: Kind;
  voiced: boolean;
  /** consonants: articulation place; vowels: backness */
  place: string;
  /** consonants: manner; vowels: height */
  manner: string;
  /** vowels only */
  round: boolean;
}

function c(voiced: boolean, place: string, manner: string): Feat {
  return { kind: "consonant", voiced, place, manner, round: false };
}
function vw(height: string, back: string, round: boolean): Feat {
  return { kind: "vowel", voiced: true, place: back, manner: height, round };
}

const FEATURES: Record<string, Feat> = {
  // stops
  P: c(false, "bilabial", "stop"), B: c(true, "bilabial", "stop"),
  T: c(false, "alveolar", "stop"), D: c(true, "alveolar", "stop"),
  K: c(false, "velar", "stop"), G: c(true, "velar", "stop"),
  // fricatives
  F: c(false, "labiodental", "fricative"), V: c(true, "labiodental", "fricative"),
  TH: c(false, "dental", "fricative"), DH: c(true, "dental", "fricative"),
  S: c(false, "alveolar", "fricative"), Z: c(true, "alveolar", "fricative"),
  SH: c(false, "postalveolar", "fricative"), ZH: c(true, "postalveolar", "fricative"),
  HH: c(false, "glottal", "fricative"),
  // affricates
  CH: c(false, "postalveolar", "affricate"), JH: c(true, "postalveolar", "affricate"),
  // nasals
  M: c(true, "bilabial", "nasal"), N: c(true, "alveolar", "nasal"),
  NG: c(true, "velar", "nasal"),
  // approximants
  L: c(true, "alveolar", "liquid"), R: c(true, "alveolar", "liquid"),
  W: c(true, "velar", "glide"), Y: c(true, "palatal", "glide"),
  // vowels — (height, backness, rounded)
  IY: vw("high", "front", false), IH: vw("near-high", "front", false),
  EY: vw("mid", "front", false), EH: vw("mid", "front", false),
  AE: vw("low", "front", false),
  AA: vw("low", "back", false), AO: vw("mid", "back", true),
  OW: vw("mid", "back", true), UH: vw("near-high", "back", true),
  UW: vw("high", "back", true),
  AH: vw("mid", "central", false), ER: vw("mid", "central", false),
  AW: vw("low", "central", false), AY: vw("low", "central", false),
  OY: vw("mid", "central", true),
};

/** Describe the single-feature contrast between two ARPABET phonemes. */
export function describeContrast(a: string, b: string): string {
  const fa = FEATURES[a],
    fb = FEATURES[b];
  if (!fa || !fb) return "sound";
  if (fa.kind !== fb.kind) return "consonant↔vowel";
  if (fa.kind === "consonant") {
    if (fa.voiced !== fb.voiced && fa.place === fb.place && fa.manner === fb.manner) {
      return "voicing"; // p~b, s~z, t~d
    }
    if (fa.place !== fb.place && fa.manner === fb.manner && fa.voiced === fb.voiced) {
      return "place"; // p~t, k~t, m~n
    }
    if (fa.manner !== fb.manner && fa.place === fb.place) {
      return "manner"; // t~s, d~n
    }
    return "consonant quality";
  }
  // vowels
  if (fa.manner !== fb.manner && fa.place === fb.place) {
    return "vowel height"; // ih~eh, uh~ow (front/back held)
  }
  if (fa.place !== fb.place && fa.manner === fb.manner) {
    return "vowel backness"; // ih~uh
  }
  if (fa.round !== fb.round) {
    return "rounding";
  }
  return "vowel quality";
}
