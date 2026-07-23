// Ported from Tests/AnagramEngineTests/WordplayTests.swift
import { describe, test, expect } from "vitest";
import { scrabbleScore } from "../../src/engine/scrabble";
import { RackSolver } from "../../src/engine/rackSolver";
import { PatternMatcher } from "../../src/engine/patternMatcher";
import { WordLadder } from "../../src/engine/wordLadder";
import { PhoneticDictionary } from "../../src/engine/phonetics";
import { WordList } from "../../src/engine/wordList";
import { miniCmudict } from "../fixtures";

describe("Scrabble", () => {
  test("scrabbleScores", () => {
    expect(scrabbleScore("quiz")).toBe(22); // q10 u1 i1 z10
    expect(scrabbleScore("cat")).toBe(5); // c3 a1 t1
  });
});

describe("RackSolver", () => {
  test("rackFindsSubAnagrams", () => {
    const solver = new RackSolver(new WordList(["cat", "act", "at", "cab", "dog"]));
    const words = new Set(solver.solve("cabt", 2).map((r) => r.word));
    expect(words.has("cat")).toBe(true);
    expect(words.has("cab")).toBe(true);
    expect(words.has("at")).toBe(true);
    expect(words.has("dog")).toBe(false); // no d/o/g in rack
  });

  test("rackBlankTileFillsMissingLetter", () => {
    const solver = new RackSolver(new WordList(["cat"]));
    // No 't', but one blank should cover it; blank scores 0 so score = c3+a1 = 4.
    const results = solver.solve("ca?", 3);
    expect(results.length).toBe(1);
    expect(results[0]!.word).toBe("cat");
    expect(results[0]!.blanksUsed).toBe(1);
    expect(results[0]!.score).toBe(4);
  });
});

describe("PatternMatcher", () => {
  test("patternMatching", () => {
    expect(PatternMatcher.match("cat", "c?t")).toBe(true);
    expect(PatternMatcher.match("coat", "c*t")).toBe(true);
    expect(PatternMatcher.match("ct", "c*t")).toBe(true);
    expect(PatternMatcher.match("cat", "c?")).toBe(false);
    expect(PatternMatcher.match("nation", "*tion")).toBe(true);
  });
});

describe("WordLadder", () => {
  test("wordLadderFindsPath", () => {
    const words = ["cold", "cord", "word", "ward", "warm", "card"];
    const ladder = new WordLadder(new WordList(words));
    const path = ladder.ladder("cold", "warm");
    expect(path[0]).toBe("cold");
    expect(path[path.length - 1]).toBe("warm");
    // Each consecutive pair differs by exactly one letter.
    for (let i = 1; i < path.length; i++) {
      const a = path[i - 1]!,
        b = path[i]!;
      let diff = 0;
      for (let j = 0; j < a.length; j++) if (a[j] !== b[j]) diff++;
      expect(diff).toBe(1);
    }
  });

  test("letterAddDropBehead", () => {
    const ladder = new WordLadder(new WordList(["cat", "cart", "scat", "car"]));
    expect(ladder.addOneLetter("cat")).toContain("cart");
    expect(ladder.dropOneLetter("cart")).toContain("car");
    expect(ladder.beheadment("scat")).toBe("cat");
    expect(ladder.curtailment("cart")).toBe("car");
    expect(WordLadder.isPalindrome("level")).toBe(true);
    expect(WordLadder.isPalindrome("cat")).toBe(false);
  });
});

describe("PhoneticDictionary", () => {
  test("phoneticRhymes", () => {
    const dict = new PhoneticDictionary(miniCmudict);
    const r = new Set(dict.rhymes("cat"));
    expect(r.has("bat")).toBe(true);
    expect(r.has("hat")).toBe(true);
    expect(r.has("dog")).toBe(false);
    expect(r.has("cat")).toBe(false); // excludes itself
  });

  test("phoneticHomophones", () => {
    const dict = new PhoneticDictionary(miniCmudict);
    const h = new Set(dict.homophones("two"));
    expect(h).toEqual(new Set(["to", "too"]));
  });

  test("phoneticSyllables", () => {
    const dict = new PhoneticDictionary(miniCmudict);
    expect(dict.syllableCount("cat")).toBe(1);
    expect(dict.syllableCount("orange")).toBe(2);
    expect(dict.syllableCount("notaword")).toBeNull();
  });
});
