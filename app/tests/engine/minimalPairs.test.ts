// Ported from Tests/AnagramEngineTests/MinimalPairTests.swift
import { describe, test, expect } from "vitest";
import { MinimalPairFinder } from "../../src/engine/minimalPairs";
import { PhoneticDictionary } from "../../src/engine/phonetics";

const mpCMU = `
pat P AE1 T
bat B AE1 T
cat K AE1 T
pit P IH1 T
pad P AE1 D
sip S IH1 P
ship SH IH1 P
bit B IH1 T
beat B IY1 T
dog D AO1 G
`;

function finder(): MinimalPairFinder {
  return new MinimalPairFinder(new PhoneticDictionary(mpCMU));
}

describe("MinimalPairFinder", () => {
  test("findsMinimalPairsInSound", () => {
    const words = new Set(finder().pairs("pat").map((n) => n.word));
    expect(words.has("bat")).toBe(true); // P~B, position 0
    expect(words.has("cat")).toBe(true); // P~K, position 0
    expect(words.has("pit")).toBe(true); // AE~IH, position 1
    expect(words.has("pad")).toBe(true); // T~D, position 2
    expect(words.has("dog")).toBe(false); // shares nothing positionally
    expect(words.has("pat")).toBe(false); // never itself
  });

  test("namesTheDistinctiveFeature", () => {
    const byWord = new Map(finder().pairs("pat").map((n) => [n.word, n.contrast]));
    expect(byWord.get("bat")).toBe("voicing"); // P/B differ only in voice
    expect(byWord.get("cat")).toBe("place"); // P/K differ only in place
    expect(byWord.get("pad")).toBe("voicing"); // T/D differ only in voice
    expect(byWord.get("pit")).toBe("vowel height"); // AE/IH: front vowels, height differs
  });

  test("minimalPairIsPhonemicNotOrthographic", () => {
    // "sip"/"ship" is a real minimal pair (S~SH) even though the spelling
    // differs by an inserted letter — a letter-ladder would miss it.
    expect(finder().pairs("sip").some((n) => n.word === "ship")).toBe(true);
    // "bit"/"beat" differ by one phoneme (IH~IY) but by spelling look 2+ apart.
    expect(finder().pairs("bit").some((n) => n.word === "beat")).toBe(true);
  });

  test("unknownWordIsEmpty", () => {
    expect(finder().pairs("zzz")).toEqual([]);
  });
});
