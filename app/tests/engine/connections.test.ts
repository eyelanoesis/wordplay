// Ported from Tests/AnagramEngineTests/ConnectionsTests.swift
import { describe, test, expect } from "vitest";
import { ConnectionWeb, ALL_RELATIONS, type Relation } from "../../src/engine/connections";
import { CrypticHelper } from "../../src/engine/cryptic";
import { WordLadder } from "../../src/engine/wordLadder";
import { PhoneticDictionary } from "../../src/engine/phonetics";
import { FusionFinder } from "../../src/engine/fusion";
import { WordList } from "../../src/engine/wordList";

const webCMU = `
brain B R EY1 N
braid B R EY1 D
rain R EY1 N
train T R EY1 N
explain IH0 K S P L EY1 N
angel EY1 N JH AH0 L
gel JH EH1 L
`;

function makeWeb(): ConnectionWeb {
  const words = ["brain", "braid", "rain", "train", "explain", "angel", "gel", "bra"];
  const list = new WordList(words);
  const phonetics = new PhoneticDictionary(webCMU);
  return new ConnectionWeb({
    cryptic: new CrypticHelper(list),
    ladder: new WordLadder(list),
    phonetics,
    fusion: new FusionFinder(phonetics, list),
  });
}

describe("ConnectionWeb", () => {
  test("webGathersEveryRelationKind", () => {
    const nodes = makeWeb().connections("brain", 5);
    const relation = (word: string): Relation | undefined =>
      nodes.find((n) => n.word === word)?.relation;
    expect(relation("braid")).toBe("oneLetter"); // change n→d
    expect(relation("rain")).toBe("oneLetter"); // drop the b (first relation wins)
    expect(relation("explain")).toBe("rhyme"); // shares /EY N/ tail, 2+ letters apart
    expect(relation("angel")).toBe("fusion"); // brain ⋈ angel = brangel
    expect(relation("bra")).toBe("hidden"); // spelled inside brain, 2 letters short
    expect(relation("brain")).toBeUndefined(); // never its own neighbor
  });

  test("webDeduplicatesAcrossRelations", () => {
    const nodes = makeWeb().connections("brain", 5);
    // "rain" is one letter away AND hidden AND audible AND a rhyme — it must
    // appear exactly once, under the first relation that claimed it.
    expect(nodes.filter((n) => n.word === "rain").length).toBe(1);
  });

  test("webWorksWithoutPhonetics", () => {
    const list = new WordList(["brain", "braid", "rain", "bran"]);
    const web = new ConnectionWeb({
      cryptic: new CrypticHelper(list),
      ladder: new WordLadder(list),
    });
    const nodes = web.connections("brain");
    expect(nodes.some((n) => n.word === "braid")).toBe(true); // letter relations still work
    expect(nodes.some((n) => n.relation === "rhyme")).toBe(false);
  });

  test("webRespectsPerRelationCap", () => {
    const nodes = makeWeb().connections("brain", 1);
    for (const relation of ALL_RELATIONS) {
      expect(nodes.filter((n) => n.relation === relation).length).toBeLessThanOrEqual(1);
    }
  });

  test("webFindsReversalsAndAssociations", () => {
    const list = new WordList(["stressed", "desserts", "level", "brain"]);
    const web = new ConnectionWeb({
      cryptic: new CrypticHelper(list),
      ladder: new WordLadder(list),
      words: list,
      associations: (w) => (w === "stressed" ? ["brain"] : []),
    });
    const nodes = web.connections("stressed", 5, new Set(["reversal", "association"]));
    expect(nodes.find((n) => n.word === "desserts")?.relation).toBe("reversal");
    expect(nodes.find((n) => n.word === "brain")?.relation).toBe("association");
    // A palindrome is not its own reversal-neighbor.
    expect(web.connections("level", 5, new Set(["reversal"]))).toEqual([]);
  });

  test("webRespectsRelationFilter", () => {
    const web = makeWeb();
    // Only one-letter steps allowed: nothing else may appear.
    const only = web.connections("brain", 5, new Set(["oneLetter"]));
    expect(only.length).toBeGreaterThan(0);
    expect(only.every((n) => n.relation === "oneLetter")).toBe(true);
    // Empty filter: nothing at all.
    expect(web.connections("brain", 5, new Set())).toEqual([]);
    // A word claimed by a disabled first relation falls to the next enabled one:
    // "rain" is normally .oneLetter; with letters off it surfaces phonetically.
    const noLetters = web.connections(
      "brain",
      5,
      new Set(["rhyme", "fusion", "hidden", "audible"]),
    );
    const rain = noLetters.find((n) => n.word === "rain");
    if (rain) {
      expect(rain.relation).not.toBe("oneLetter");
    }
  });
});
