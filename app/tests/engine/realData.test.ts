// TS-only integration tests over the full committed data — not part of the
// Swift 40, added for the port's own risks: full-scale parsing, and the
// codex smoke expectation pinned as a regression test.
import { describe, test, expect } from "vitest";
import { readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { WordList } from "../../src/engine/wordList";
import { PhoneticDictionary } from "../../src/engine/phonetics";
import { FusionFinder } from "../../src/engine/fusion";
import { CrypticHelper } from "../../src/engine/cryptic";
import { WordLadder } from "../../src/engine/wordLadder";
import { ConnectionWeb } from "../../src/engine/connections";
import { PathFinder } from "../../src/engine/pathFinder";

const here = dirname(fileURLToPath(import.meta.url));
const data = (name: string): string =>
  readFileSync(join(here, "..", "..", "public", "data", name), "utf-8");

describe("real data", () => {
  const list = WordList.fromText(data("enable.txt"));
  const phonetics = PhoneticDictionary.fromLexicon(data("lexicon.txt"));
  const cryptic = new CrypticHelper(list);
  const ladder = new WordLadder(list);
  const fusion = new FusionFinder(phonetics, list);

  test("lexiconParsesAtFullScale", () => {
    expect(list.count).toBeGreaterThan(150_000);
    expect(phonetics.count).toBeGreaterThan(50_000);
    expect(phonetics.rhymes("moon")).toContain("baboon");
    expect(phonetics.homophones("pair")).toContain("pear");
  });

  test("connectionWebFindsAllRelationKindsForBrain", () => {
    const web = new ConnectionWeb({ cryptic, ladder, phonetics, fusion, words: list });
    const nodes = web.connections("brain", 5);
    const kinds = new Set(nodes.map((n) => n.relation));
    for (const k of ["anagram", "oneLetter", "rhyme", "fusion", "hidden", "audible"]) {
      expect(kinds.has(k as never)).toBe(true);
    }
    // stressed/desserts, the canonical reversal
    const rev = web.connections("stressed", 5, new Set(["reversal"]));
    expect(rev[0]?.word).toBe("desserts");
  });

  test("fireToWaterIsTheCanonicalPath", () => {
    // The codex smoke expectation, pinned: fire → firm → term → water.
    const finder = new PathFinder({ cryptic, ladder, phonetics, fusion });
    const steps = finder.path("fire", "water");
    expect(steps).not.toBeNull();
    expect(steps!.map((s) => s.word)).toEqual(["fire", "firm", "term", "water"]);
  });
});
