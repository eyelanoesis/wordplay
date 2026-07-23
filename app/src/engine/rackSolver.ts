// Ported from Sources/AnagramEngine/RackSolver.swift
import { LetterCount } from "./letterCount";
import { WordList } from "./wordList";
import { scrabbleScore } from "./scrabble";

export interface RackWord {
  word: string;
  /** Scrabble score (blanks count as 0). */
  score: number;
  length: number;
  blanksUsed: number;
}

/**
 * Finds every dictionary word that can be built from a subset of a letter rack,
 * optionally using blank tiles (wildcards) to fill missing letters.
 */
export class RackSolver {
  private readonly wordList: WordList;

  constructor(wordList: WordList) {
    this.wordList = wordList;
  }

  /**
   * @param rack available letters; `?` or `*` characters count as blank tiles.
   * @param minLength ignore words shorter than this.
   * @returns matching words sorted by score (desc), then length, then alpha.
   */
  solve(rack: string, minLength = 2): RackWord[] {
    const lower = rack.toLowerCase();
    let blanks = 0;
    for (const ch of lower) if (ch === "?" || ch === "*") blanks++;
    const rackLetters = new LetterCount(lower); // ignores ? and *
    const capacity = rackLetters.total + blanks;

    const out: RackWord[] = [];
    for (const w of this.wordList.words) {
      const len = w.length;
      if (len < minLength) continue;
      if (len > capacity) continue;

      const wc = new LetterCount(w);
      // How many letters does the rack lack? Those must be covered by blanks.
      let deficit = 0;
      let blankScorePenalty = 0;
      let ok = true;
      for (let i = 0; i < 26; i++) {
        const need = wc.counts[i]! - rackLetters.counts[i]!;
        if (need > 0) {
          deficit += need;
          if (deficit > blanks) {
            ok = false;
            break;
          }
          // Letters covered by blanks score 0.
          blankScorePenalty += need * scrabbleScore(String.fromCharCode(97 + i));
        }
      }
      if (!ok) continue;

      const score = scrabbleScore(w) - blankScorePenalty;
      out.push({ word: w, score, length: len, blanksUsed: deficit });
    }

    out.sort((a, b) => {
      if (a.score !== b.score) return b.score - a.score;
      if (a.length !== b.length) return b.length - a.length;
      return a.word < b.word ? -1 : 1;
    });
    return out;
  }
}
