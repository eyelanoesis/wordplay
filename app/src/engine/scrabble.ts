// Ported from Sources/AnagramEngine/Scrabble.swift

/** Standard English Scrabble tile values. */
const VALUES: Record<string, number> = {
  a: 1, e: 1, i: 1, o: 1, u: 1, l: 1, n: 1, s: 1, t: 1, r: 1,
  d: 2, g: 2,
  b: 3, c: 3, m: 3, p: 3,
  f: 4, h: 4, v: 4, w: 4, y: 4,
  k: 5,
  j: 8, x: 8,
  q: 10, z: 10,
};

/** Sum of tile values for a word (lowercased a–z only). */
export function scrabbleScore(word: string): number {
  let total = 0;
  for (const ch of word.toLowerCase()) {
    if (ch >= "a" && ch <= "z") total += VALUES[ch] ?? 0;
  }
  return total;
}
