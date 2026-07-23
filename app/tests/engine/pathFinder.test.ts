// Ported from Tests/AnagramEngineTests/PathFinderTests.swift
import { describe, test, expect } from "vitest";
import { PathFinder } from "../../src/engine/pathFinder";
import { CrypticHelper } from "../../src/engine/cryptic";
import { WordLadder } from "../../src/engine/wordLadder";
import { PhoneticDictionary } from "../../src/engine/phonetics";
import { FusionFinder } from "../../src/engine/fusion";
import { WordList } from "../../src/engine/wordList";

const pathCMU = `
brain B R EY1 N
rain R EY1 N
reign R EY1 N
rein R EY1 N
ruin R UW1 AH0 N
dog D AO1 G
cog K AO1 G
cot K AA1 T
cat K AE1 T
`;

function makePathFinder(words: string[]): PathFinder {
  const list = new WordList(words);
  const phonetics = new PhoneticDictionary(pathCMU);
  return new PathFinder({
    cryptic: new CrypticHelper(list),
    ladder: new WordLadder(list),
    phonetics,
    fusion: new FusionFinder(phonetics, list),
  });
}

describe("PathFinder", () => {
  test("classicLadderPath", () => {
    const finder = makePathFinder(["cat", "cot", "cog", "dog"]);
    const steps = finder.path("cat", "dog");
    expect(steps?.map((s) => s.word)).toEqual(["cat", "cot", "cog", "dog"]);
    expect(steps?.slice(1).every((s) => s.relation === "oneLetter")).toBe(true);
  });

  test("mixedDimensionPathBeatsSingleDimension", () => {
    // ruin → rain is a letter step; rain → reign only connects by sound.
    // No pure letter-ladder or pure sound chain can make this trip alone.
    const finder = makePathFinder(["ruin", "rain", "reign"]);
    const steps = finder.path("ruin", "reign");
    expect(steps?.map((s) => s.word)).toEqual(["ruin", "rain", "reign"]);
    expect(steps?.[1]?.relation).toBe("oneLetter");
    const last = steps?.[steps.length - 1]?.relation;
    expect(last === "homophone" || last === "rhyme").toBe(true);
  });

  test("directRhymeIsOneHop", () => {
    // brain and reign share the /EY N/ tail — connected in a single hop.
    const finder = makePathFinder(["brain", "reign"]);
    const steps = finder.path("brain", "reign");
    expect(steps?.length).toBe(2);
  });

  test("unreachableReturnsNil", () => {
    const finder = makePathFinder(["cat", "dog"]); // no bridge words at all
    expect(finder.path("cat", "dog")).toBeNull();
  });

  test("sameWordIsTrivialPath", () => {
    expect(makePathFinder(["cat"]).path("cat", "cat")?.length).toBe(1);
  });
});
