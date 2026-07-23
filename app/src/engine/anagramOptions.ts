// Ported from Sources/AnagramEngine/AnagramOptions.swift

/** Output casing, mirroring the I.A.S. `k` parameter. */
export type Casing = "lower" | "firstUpper" | "upper";

/** All the knobs from the advanced form, plus engine limits. */
export interface AnagramOptions {
  /** Max number of complete anagrams to return (I.A.S. `t`). 0 == unlimited. */
  maxResults: number;
  /** Max words per anagram (I.A.S. `d`). 0 == unlimited. */
  maxWords: number;
  /** A word that must appear in every result (I.A.S. `include`). Empty == none. */
  include: string;
  /** Words that may not appear in any result (I.A.S. `exclude`). */
  exclude: string[];
  /** Min letters per word (I.A.S. `n`). */
  minWordLength: number;
  /** Max letters per word (I.A.S. `m`). */
  maxWordLength: number;
  /** Allow the same word to be reused within one anagram (I.A.S. `a`). */
  allowRepeats: boolean;
  /** Output casing (I.A.S. `k`). */
  casing: Casing;
}

export function defaultAnagramOptions(): AnagramOptions {
  return {
    maxResults: 500,
    maxWords: 0,
    include: "",
    exclude: [],
    minWordLength: 1,
    maxWordLength: 20,
    allowRepeats: false,
    casing: "firstUpper",
  };
}
