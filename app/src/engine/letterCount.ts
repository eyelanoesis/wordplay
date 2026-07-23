// Ported from Sources/AnagramEngine/LetterCount.swift

/**
 * A multiset of the 26 ASCII letters a–z, stored as fixed-size counts.
 * Non-letters are ignored; case is folded. This is the workhorse type:
 * anagram search is just repeated subtraction of these vectors.
 */
export class LetterCount {
  /** counts[0] == number of 'a', … counts[25] == number of 'z' */
  counts: Int32Array;
  /** Total number of letters (sum of counts), cached for fast emptiness checks. */
  total: number;

  constructor(text?: string) {
    this.counts = new Int32Array(26);
    this.total = 0;
    if (text !== undefined) {
      const lower = text.toLowerCase();
      for (let i = 0; i < lower.length; i++) {
        const v = lower.charCodeAt(i);
        if (v >= 97 && v <= 122) {
          this.counts[v - 97]!++;
          this.total++;
        }
      }
    }
  }

  get isEmpty(): boolean {
    return this.total === 0;
  }

  /** True if `other` is a sub-multiset of this (every letter fits). */
  contains(other: LetterCount): boolean {
    if (other.total > this.total) return false;
    for (let i = 0; i < 26; i++) {
      if (other.counts[i]! > this.counts[i]!) return false;
    }
    return true;
  }

  /** Returns this minus other. Caller guarantees `contains(other)`. */
  subtracting(other: LetterCount): LetterCount {
    const result = new LetterCount();
    for (let i = 0; i < 26; i++) {
      result.counts[i] = this.counts[i]! - other.counts[i]!;
    }
    result.total = this.total - other.total;
    return result;
  }

  equals(other: LetterCount): boolean {
    if (this.total !== other.total) return false;
    for (let i = 0; i < 26; i++) {
      if (this.counts[i] !== other.counts[i]) return false;
    }
    return true;
  }
}
