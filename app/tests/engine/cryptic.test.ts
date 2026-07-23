// Ported from Tests/AnagramEngineTests/CrypticTests.swift
import { describe, test, expect } from "vitest";
import { CrypticHelper } from "../../src/engine/cryptic";
import { WordList } from "../../src/engine/wordList";

function helper(words: string[]): CrypticHelper {
  return new CrypticHelper(new WordList(words));
}

describe("CrypticHelper", () => {
  test("hiddenWordsAcrossBoundary", () => {
    // "drama idea" -> "dramaidea" conceals "maid" across the word boundary.
    const h = helper(["maid", "dish", "scam", "rama"]);
    const found = h.hiddenWords("drama idea", 4);
    const words = new Set(found.map((f) => f.word));
    expect(words.has("maid")).toBe(true);
    expect(found.find((f) => f.word === "maid")?.spansBoundary).toBe(true);
    // "rama" sits wholly inside "drama" — not boundary-spanning.
    expect(found.find((f) => f.word === "rama")?.spansBoundary).toBe(false);
  });

  test("charadeSplits", () => {
    const h = helper(["car", "pet", "carpet", "cape", "t"]);
    const splits = h.charades("carpet", 3, 2);
    // car + pet should be among the splits.
    expect(splits.some((s) => s.length === 2 && s[0] === "car" && s[1] === "pet")).toBe(true);
  });

  test("singleWordAnagrams", () => {
    const h = helper(["listen", "silent", "tinsel", "enlist", "dog"]);
    const words = new Set(h.anagramWords("listen"));
    expect(words.has("silent")).toBe(true);
    expect(words.has("tinsel")).toBe(true);
    expect(words.has("enlist")).toBe(true);
    expect(words.has("listen")).toBe(false); // excludes the input itself
    expect(words.has("dog")).toBe(false);
  });

  test("anagramPairAndPalindrome", () => {
    const h = helper([]);
    expect(h.isAnagramPair("listen", "silent")).toBe(true);
    expect(h.isAnagramPair("listen", "tinned")).toBe(false);
    expect(CrypticHelper.isPalindrome("racecar")).toBe(true);
    expect(CrypticHelper.isPalindrome("racecars")).toBe(false);
  });
});
