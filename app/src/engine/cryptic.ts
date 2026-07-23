// Ported from Sources/AnagramEngine/Cryptic.swift
import { WordList } from "./wordList";

export interface HiddenWord {
  word: string;
  /** true if it crosses original word boundaries */
  spansBoundary: boolean;
}

/** Tools for cryptic-crossword setting and solving. */
export class CrypticHelper {
  private readonly wordSet: Set<string>;
  /** sorted-letters signature -> words (exact single-word anagrams) */
  private readonly anagramIndex: Map<string, string[]>;

  constructor(wordList: WordList) {
    this.wordSet = new Set(wordList.words);
    this.anagramIndex = new Map();
    for (const w of wordList.words) {
      const sig = [...w].sort().join("");
      let bucket = this.anagramIndex.get(sig);
      if (!bucket) this.anagramIndex.set(sig, (bucket = []));
      bucket.push(w);
    }
  }

  isWord(w: string): boolean {
    return this.wordSet.has(w.toLowerCase());
  }

  /**
   * Words concealed as a contiguous run of letters inside `text` (ignoring
   * spaces/punctuation). `spansBoundary` flags the classic cryptic case where
   * the hidden word straddles two or more words of the clue.
   */
  hiddenWords(text: string, minLength = 4): HiddenWord[] {
    // Build the letter stream plus, per letter, which original token it's in.
    const letters: string[] = [];
    const token: number[] = [];
    let currentToken = 0;
    let inWord = false;
    for (const ch of text.toLowerCase()) {
      if (ch >= "a" && ch <= "z") {
        letters.push(ch);
        token.push(currentToken);
        inWord = true;
      } else if (inWord) {
        currentToken++;
        inWord = false;
      }
    }
    if (letters.length < minLength) return [];

    const seen = new Set<string>();
    const out: HiddenWord[] = [];
    const n = letters.length;
    for (let i = 0; i < n; i++) {
      // Longest sensible window is capped to keep this quick.
      const maxLen = Math.min(n - i, 24);
      if (maxLen < minLength) break;
      let sub = "";
      for (let len = 1; len <= maxLen; len++) {
        sub += letters[i + len - 1];
        if (len < minLength) continue;
        if (this.wordSet.has(sub) && !seen.has(sub)) {
          seen.add(sub);
          const spans = token[i] !== token[i + len - 1];
          out.push({ word: sub, spansBoundary: spans });
        }
      }
    }
    // Prefer boundary-spanning, then longer words.
    out.sort((a, b) => {
      if (a.spansBoundary !== b.spansBoundary) return a.spansBoundary ? -1 : 1;
      if (a.word.length !== b.word.length) return b.word.length - a.word.length;
      return a.word < b.word ? -1 : 1;
    });
    return out;
  }

  /**
   * All ways to split `word` into 2…maxParts consecutive dictionary words,
   * e.g. "carpet" -> ["car","pet"]. Each part must be at least `minPart` long.
   */
  charades(word: string, maxParts = 3, minPart = 2): string[][] {
    const chars = word.toLowerCase();
    const results: string[][] = [];
    const current: string[] = [];

    const recurse = (start: number): void => {
      if (current.length > maxParts) return;
      if (start === chars.length) {
        if (current.length >= 2) results.push([...current]);
        return;
      }
      const partsLeft = maxParts - current.length;
      if (partsLeft <= 0) return;
      for (let end = start + minPart; end <= chars.length; end++) {
        const piece = chars.slice(start, end);
        if (this.wordSet.has(piece)) {
          current.push(piece);
          recurse(end);
          current.pop();
        }
      }
    };
    recurse(0);
    results.sort((a, b) => {
      if (a.length !== b.length) return a.length - b.length;
      const ja = a.join(""),
        jb = b.join("");
      return ja < jb ? -1 : ja > jb ? 1 : 0;
    });
    return results;
  }

  /** Exact single-word anagrams of the given letters (excluding the input word). */
  anagramWords(letters: string): string[] {
    const cleaned = letters.toLowerCase().replace(/[^a-z]/g, "");
    const sig = [...cleaned].sort().join("");
    return (this.anagramIndex.get(sig) ?? []).filter((w) => w !== cleaned).sort();
  }

  isAnagramPair(a: string, b: string): boolean {
    const ca = [...a.toLowerCase().replace(/[^a-z]/g, "")].sort().join("");
    const cb = [...b.toLowerCase().replace(/[^a-z]/g, "")].sort().join("");
    return ca.length > 0 && ca === cb;
  }

  static isPalindrome(s: string): boolean {
    const cleaned = s.toLowerCase().replace(/[^a-z]/g, "");
    return cleaned.length > 1 && cleaned === [...cleaned].reverse().join("");
  }
}
