// Ported from Tests/AnagramEngineTests/AnagramEngineTests.swift
import { describe, test, expect } from "vitest";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { AnagramEngine } from "../../src/engine/anagramEngine";
import { WordList } from "../../src/engine/wordList";
import { defaultAnagramOptions } from "../../src/engine/anagramOptions";

function engine(words: string[]): AnagramEngine {
  return new AnagramEngine(new WordList(words));
}

describe("AnagramEngine", () => {
  test("findsSimpleTwoWordAnagram", () => {
    const e = engine(["dog", "god", "cat", "act", "go", "do"]);
    const opts = defaultAnagramOptions();
    opts.casing = "lower";
    const results = new Set(e.anagrams("god", opts));
    expect(results.has("dog")).toBe(true);
    expect(results.has("god")).toBe(true);
  });

  test("respectsMaxWords", () => {
    const e = engine(["a", "b", "ab", "ba"]);
    const opts = defaultAnagramOptions();
    opts.maxWords = 1;
    opts.casing = "lower";
    const results = e.anagrams("ab", opts);
    // With one word only, "a b" must not appear.
    expect(results.every((r) => !r.includes(" "))).toBe(true);
    expect(new Set(results)).toEqual(new Set(["ab", "ba"]));
  });

  test("includeForcesWord", () => {
    const e = engine(["dog", "god", "go", "do", "dg"]);
    const opts = defaultAnagramOptions();
    opts.include = "go";
    opts.casing = "lower";
    const results = e.anagrams("godo", opts);
    expect(results.every((r) => r.split(" ").includes("go"))).toBe(true);
  });

  test("excludeRemovesWord", () => {
    const e = engine(["dog", "god"]);
    const opts = defaultAnagramOptions();
    opts.exclude = ["god"];
    opts.casing = "lower";
    const results = e.anagrams("god", opts);
    expect(results).not.toContain("god");
    expect(results).toContain("dog");
  });

  test("casingFirstUpper", () => {
    const e = engine(["dog"]);
    const opts = defaultAnagramOptions();
    opts.casing = "firstUpper";
    const results = e.anagrams("dog", opts);
    expect(results).toContain("Dog");
  });

  test("minWordLengthFilters", () => {
    const e = engine(["a", "i", "ai", "ia"]);
    const opts = defaultAnagramOptions();
    opts.minWordLength = 2;
    opts.casing = "lower";
    const results = new Set(e.anagrams("ai", opts));
    expect(results).toEqual(new Set(["ai", "ia"]));
  });

  test("realDictionarySanityCheck", () => {
    // The Swift test loads /usr/share/dict/words (macOS-only); the TS suite
    // asserts against the in-repo ENABLE list so it runs anywhere.
    const here = dirname(fileURLToPath(import.meta.url));
    const text = readFileSync(join(here, "..", "..", "public", "data", "enable.txt"), "utf-8");
    const list = WordList.fromText(text);
    expect(list.count).toBeGreaterThan(50_000);
    const e = new AnagramEngine(list);
    const o = defaultAnagramOptions();
    o.casing = "lower";
    o.maxWords = 2;
    o.minWordLength = 3;
    o.maxResults = 1000;
    const results = new Set(e.anagrams("dormitory", o));
    // "dirty room" is the famous anagram of "dormitory".
    expect(results.has("dirty room") || results.has("room dirty")).toBe(true);
  });
});
