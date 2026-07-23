// Ported from Sources/AnagramEngine/Dictionary.swift
import { LetterCount } from "./letterCount";

/** A word plus its precomputed letter vector, for anagram candidate filtering. */
export interface DictWord {
  display: string;
  letters: LetterCount;
  length: number;
}

/**
 * A loaded word list, ready to be filtered into candidates for a given phrase.
 * The engine never does I/O — callers load text (fetch, fs, ?raw import) and
 * hand it over.
 */
export class WordList {
  readonly words: string[];
  private readonly set: Set<string>;

  constructor(words: string[]) {
    this.words = words;
    this.set = new Set(words);
  }

  /** Number of words loaded. */
  get count(): number {
    return this.words.length;
  }

  /** Whether the list contains `word` (lowercased exact match). */
  contains(word: string): boolean {
    return this.set.has(word);
  }

  /**
   * Load from newline-delimited text (e.g. an ENABLE dump). Keeps only
   * purely-alphabetic entries, lowercased and de-duplicated.
   */
  static fromText(text: string): WordList {
    const seen = new Set<string>();
    const out: string[] = [];
    for (const raw of text.split("\n")) {
      const w = raw.toLowerCase();
      if (w.length === 0 || !/^[a-z]+$/.test(w)) continue;
      if (!seen.has(w)) {
        seen.add(w);
        out.push(w);
      }
    }
    return new WordList(out);
  }
}
