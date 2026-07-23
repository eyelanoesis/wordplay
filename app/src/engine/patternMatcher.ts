// Ported from Sources/AnagramEngine/PatternMatcher.swift
import { WordList } from "./wordList";

/**
 * Crossword-style pattern search over a word list.
 *
 * Pattern syntax:
 *   - a letter a–z matches itself
 *   - `?` or `.` matches exactly one letter
 *   - `*` matches any run of letters (including none)
 * Matching is anchored to the whole word.
 */
export class PatternMatcher {
  private readonly wordList: WordList;

  constructor(wordList: WordList) {
    this.wordList = wordList;
  }

  matches(rawPattern: string, limit = 0): string[] {
    const pattern = rawPattern.toLowerCase();
    if (pattern.length === 0) return [];

    const out: string[] = [];
    for (const w of this.wordList.words) {
      if (PatternMatcher.match(w, pattern)) {
        out.push(w);
        if (limit > 0 && out.length >= limit) break;
      }
    }
    return out;
  }

  /** Glob-style match with `?`/`.` = one char and `*` = any run. */
  static match(word: string, pattern: string): boolean {
    // Classic two-pointer wildcard matcher with backtracking on `*`.
    let wi = 0,
      pi = 0;
    let star = -1,
      mark = 0;
    while (wi < word.length) {
      const p = pattern[pi];
      if (pi < pattern.length && (p === word[wi] || p === "?" || p === ".")) {
        wi++;
        pi++;
      } else if (pi < pattern.length && p === "*") {
        star = pi;
        mark = wi;
        pi++;
      } else if (star !== -1) {
        pi = star + 1;
        mark++;
        wi = mark;
      } else {
        return false;
      }
    }
    while (pi < pattern.length && pattern[pi] === "*") pi++;
    return pi === pattern.length;
  }
}
