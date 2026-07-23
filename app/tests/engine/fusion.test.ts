// Ported from Tests/AnagramEngineTests/FusionTests.swift
import { describe, test, expect } from "vitest";
import { FusionFinder } from "../../src/engine/fusion";
import { PhoneticDictionary } from "../../src/engine/phonetics";
import { WordList } from "../../src/engine/wordList";

const miniCMU = `
angel EY1 N JH AH0 L
brain B R EY1 N
rain R EY1 N
gel JH EH1 L
train T R EY1 N
low L OW1
elbow EH1 L B OW0
dog D AO1 G
`;

function makeFinder(): FusionFinder {
  const phonetics = new PhoneticDictionary(miniCMU);
  const list = new WordList(["angel", "brain", "rain", "gel", "train", "low", "elbow", "dog"]);
  return new FusionFinder(phonetics, list);
}

describe("FusionFinder", () => {
  test("brainFusesBeforeAngel", () => {
    const fusions = makeFinder().fusions("angel", ["before"], 2);
    const brangel = fusions.find((f) => f.partner === "brain");
    expect(brangel).toBeDefined();
    expect(brangel!.sharedPhones).toEqual(["EY", "N"]); // /EY N/ shared
    expect(brangel!.fusedPhones).toEqual(["B", "R", "EY", "N", "JH", "AH", "L"]);
    expect(brangel!.spelling).toBe("brangel"); // br + angel
    // "train" overlaps the same way; "dog" shares nothing.
    expect(fusions.some((f) => f.partner === "train")).toBe(true);
    expect(fusions.some((f) => f.partner === "dog")).toBe(false);
  });

  test("bonusWordsAreAudibleInTheStream", () => {
    const fusions = makeFinder().fusions("angel", ["before"], 2);
    const brangel = fusions.find((f) => f.partner === "brain");
    // /R EY N/ = rain, exactly; /JH AH L/ = gel via schwa flexibility.
    expect(brangel?.bonusWords).toContain("rain");
    expect(brangel?.bonusWords).toContain("gel");
    // The parents themselves are not "bonus" words.
    expect(brangel?.bonusWords).not.toContain("angel");
    expect(brangel?.bonusWords).not.toContain("brain");
  });

  test("fusionAfterSeed", () => {
    // brain /B R EY N/ tail /R EY N/ == rain /R EY N/ head — but rain has no
    // phones beyond the overlap, so it must NOT appear.
    const fusions = makeFinder().fusions("brain", ["after"], 3);
    expect(fusions.some((f) => f.partner === "rain")).toBe(false);
  });

  test("minOverlapIsRespected", () => {
    const loose = makeFinder().fusions("angel", ["before"], 1);
    const tight = makeFinder().fusions("angel", ["before"], 3);
    expect(loose.length).toBeGreaterThanOrEqual(
      makeFinder().fusions("angel", ["before"], 2).length,
    );
    expect(tight.some((f) => f.partner === "brain")).toBe(false); // only 2 phones shared
  });

  test("unknownSeedReturnsEmpty", () => {
    expect(makeFinder().fusions("zzzz")).toEqual([]);
  });
});
