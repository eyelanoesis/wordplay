// Ported from Sources/AnagramEngine/AnagramEngine.swift
import { LetterCount } from "./letterCount";
import { WordList, type DictWord } from "./wordList";
import type { AnagramOptions, Casing } from "./anagramOptions";

export interface AnagramResult {
  words: string[];
}

export function anagramResultText(result: AnagramResult): string {
  return result.words.join(" ");
}

/**
 * Multi-word anagram search engine.
 *
 * Strategy (the same idea I.A.S. uses):
 *   1. Reduce the phrase to a 26-letter count vector.
 *   2. Build the *candidate* set — dictionary words whose letters fit the
 *      phrase and satisfy the length/exclude filters.
 *   3. Depth-first search: pick a candidate that fits the remaining letters,
 *      subtract it, recurse on the remainder. When the remainder is empty we
 *      have a complete anagram. Using a non-decreasing start index avoids
 *      emitting the same word-set in different orders.
 */
export class AnagramEngine {
  private readonly wordList: WordList;

  constructor(wordList: WordList) {
    this.wordList = wordList;
  }

  /**
   * Stream results to `emit`. Return `false` from `emit` to stop early.
   * `isCancelled` lets a UI abort a long search.
   */
  search(
    phrase: string,
    options: AnagramOptions,
    emit: (result: AnagramResult) => boolean,
    isCancelled: () => boolean = () => false,
  ): void {
    let target = new LetterCount(phrase);
    if (target.isEmpty) return;

    const excludeSet = new Set(options.exclude.map((w) => w.toLowerCase()));

    // Forced "include" word: subtract its letters up front; it is prepended
    // to every result and counts as one word toward maxWords.
    let forced: string[] = [];
    if (options.include.length > 0) {
      const incWord = options.include.toLowerCase();
      const incLetters = new LetterCount(incWord);
      if (incLetters.total === 0 || !target.contains(incLetters)) return;
      target = target.subtracting(incLetters);
      forced = [incWord];
    }

    // Build candidates against the (post-include) target.
    const candidates: DictWord[] = [];
    for (const w of this.wordList.words) {
      const len = w.length;
      if (len < options.minWordLength || len > options.maxWordLength) continue;
      if (excludeSet.has(w)) continue;
      const lc = new LetterCount(w);
      if (lc.total === 0) continue;
      if (target.contains(lc)) {
        candidates.push({ display: w, letters: lc, length: len });
      }
    }
    // Longest words first → more "interesting" anagrams surface earliest.
    candidates.sort((a, b) =>
      a.length !== b.length ? b.length - a.length : a.display < b.display ? -1 : 1,
    );

    if (candidates.length === 0) {
      // The phrase might be satisfied by the include word alone.
      if (target.isEmpty && forced.length > 0) {
        emit({ words: forced });
      }
      return;
    }

    let minCandLen = Infinity;
    for (const c of candidates) minCandLen = Math.min(minCandLen, c.length);
    const wordCap = options.maxWords > 0 ? options.maxWords : Infinity;
    const resultCap = options.maxResults > 0 ? options.maxResults : Infinity;

    const stack: string[] = [...forced];
    let produced = 0;
    let stop = false;

    const recurse = (remaining: LetterCount, startIndex: number, depth: number): void => {
      if (stop) return;
      if (remaining.isEmpty) {
        if (!emit({ words: [...stack] })) stop = true;
        produced++;
        if (produced >= resultCap) stop = true;
        return;
      }
      // Pruning: not enough letters left to form even the shortest word,
      // or we've hit the word-count ceiling.
      if (remaining.total < minCandLen) return;
      if (depth >= wordCap) return;
      if (depth % 64 === 0 && isCancelled()) {
        stop = true;
        return;
      }

      for (let i = startIndex; i < candidates.length; i++) {
        if (stop) return;
        const cand = candidates[i]!;
        if (cand.length <= remaining.total && remaining.contains(cand.letters)) {
          stack.push(cand.display);
          const next = options.allowRepeats ? i : i + 1;
          recurse(remaining.subtracting(cand.letters), next, depth + 1);
          stack.pop();
        }
      }
    };

    recurse(target, 0, forced.length);
  }

  /**
   * Convenience: collect all results (respecting maxResults) into an array,
   * with casing applied.
   */
  anagrams(
    phrase: string,
    options: AnagramOptions,
    isCancelled: () => boolean = () => false,
  ): string[] {
    const out: string[] = [];
    this.search(
      phrase,
      options,
      (result) => {
        out.push(AnagramEngine.format(result.words, options.casing));
        return true;
      },
      isCancelled,
    );
    return out;
  }

  /** Apply output casing to a word list and join. */
  static format(words: string[], casing: Casing): string {
    let cased: string[];
    switch (casing) {
      case "lower":
        cased = words;
        break;
      case "upper":
        cased = words.map((w) => w.toUpperCase());
        break;
      case "firstUpper":
        cased = words.map((w) => w.charAt(0).toUpperCase() + w.slice(1));
        break;
    }
    return cased.join(" ");
  }
}
