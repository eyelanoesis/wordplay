// Ported from Sources/AnagramEngine/WordLadder.swift
import { WordList } from "./wordList";

const AZ = "abcdefghijklmnopqrstuvwxyz";

/** Word-transformation toys: ladders and single-letter mutations. */
export class WordLadder {
  /** Set of valid words for fast membership tests, grouped by length. */
  private readonly byLength: Map<number, Set<string>>;

  constructor(wordList: WordList) {
    const d = new Map<number, Set<string>>();
    for (const w of wordList.words) {
      let bucket = d.get(w.length);
      if (!bucket) d.set(w.length, (bucket = new Set()));
      bucket.add(w);
    }
    this.byLength = d;
  }

  private wordsOfLength(n: number): Set<string> {
    return this.byLength.get(n) ?? new Set();
  }

  private isWord(w: string): boolean {
    return this.byLength.get(w.length)?.has(w) ?? false;
  }

  /**
   * Shortest ladder from `start` to `goal`, both same length, changing one
   * letter per step where every intermediate is a real word. Empty if none.
   */
  ladder(start: string, goal: string, maxDepth = 60): string[] {
    const s = start.toLowerCase(),
      g = goal.toLowerCase();
    if (s.length !== g.length || !this.isWord(s) || !this.isWord(g)) return [];
    if (s === g) return [s];

    const pool = this.wordsOfLength(s.length);
    const visited = new Set([s]);
    let queue: string[][] = [[s]];
    let steps = 0;
    while (queue.length > 0 && steps < maxDepth) {
      steps++;
      const next: string[][] = [];
      for (const path of queue) {
        const last = path[path.length - 1]!;
        for (const neighbor of this.oneLetterNeighbors(last, pool)) {
          if (visited.has(neighbor)) continue;
          const newPath = [...path, neighbor];
          if (neighbor === g) return newPath;
          visited.add(neighbor);
          next.push(newPath);
        }
      }
      queue = next;
    }
    return [];
  }

  /** All real words differing from `word` by exactly one letter (same length). */
  changeOneLetter(word: string): string[] {
    const w = word.toLowerCase();
    return this.oneLetterNeighbors(w, this.wordsOfLength(w.length)).sort();
  }

  private oneLetterNeighbors(word: string, pool: Set<string>): string[] {
    const result: string[] = [];
    for (let i = 0; i < word.length; i++) {
      const original = word[i];
      for (const c of AZ) {
        if (c === original) continue;
        const candidate = word.slice(0, i) + c + word.slice(i + 1);
        if (pool.has(candidate)) result.push(candidate);
      }
    }
    return result;
  }

  /** Real words made by inserting one letter anywhere (e.g. cat → cart). */
  addOneLetter(word: string): string[] {
    const w = word.toLowerCase();
    const pool = this.wordsOfLength(w.length + 1);
    if (pool.size === 0) return [];
    const result = new Set<string>();
    for (let i = 0; i <= w.length; i++) {
      for (const c of AZ) {
        const candidate = w.slice(0, i) + c + w.slice(i);
        if (pool.has(candidate)) result.add(candidate);
      }
    }
    return [...result].sort();
  }

  /** Real words made by removing one letter (e.g. cart → cat / car). */
  dropOneLetter(word: string): string[] {
    const w = word.toLowerCase();
    if (w.length <= 1) return [];
    const pool = this.wordsOfLength(w.length - 1);
    const result = new Set<string>();
    for (let i = 0; i < w.length; i++) {
      const candidate = w.slice(0, i) + w.slice(i + 1);
      if (pool.has(candidate)) result.add(candidate);
    }
    return [...result].sort();
  }

  /** Beheadment: remove first letter and still a word (scat → cat). */
  beheadment(word: string): string | null {
    const w = word.toLowerCase();
    if (w.length <= 1) return null;
    const tail = w.slice(1);
    return this.isWord(tail) ? tail : null;
  }

  /** Curtailment: remove last letter and still a word (cart → car). */
  curtailment(word: string): string | null {
    const w = word.toLowerCase();
    if (w.length <= 1) return null;
    const head = w.slice(0, -1);
    return this.isWord(head) ? head : null;
  }

  static isPalindrome(word: string): boolean {
    const cleaned = word.toLowerCase().replace(/[^a-z]/g, "");
    return cleaned.length > 1 && cleaned === [...cleaned].reverse().join("");
  }
}
