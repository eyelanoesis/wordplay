// Ported from Sources/AnagramEngine/Connections.swift
import { CrypticHelper } from "./cryptic";
import { WordLadder } from "./wordLadder";
import { PhoneticDictionary } from "./phonetics";
import { FusionFinder } from "./fusion";
import { WordList } from "./wordList";

/** The nine kinds of connection between words. */
export type Relation =
  | "anagram"
  | "oneLetter"
  | "homophone"
  | "rhyme"
  | "fusion"
  | "hidden"
  | "audible"
  | "reversal"
  | "association";

export const ALL_RELATIONS: readonly Relation[] = [
  "anagram",
  "oneLetter",
  "homophone",
  "rhyme",
  "fusion",
  "hidden",
  "audible",
  "reversal",
  "association",
];

export interface ConnectionNode {
  word: string;
  relation: Relation;
  detail: string;
}

/** Semantic-neighbor provider, injected (data-driven on web, NLEmbedding in the Swift app). */
export type AssociationsProvider = (word: string, cap: number) => string[];

export interface ConnectionWebDeps {
  cryptic: CrypticHelper;
  ladder: WordLadder;
  phonetics?: PhoneticDictionary;
  fusion?: FusionFinder;
  /** needed for the reversal relation */
  words?: WordList;
  associations?: AssociationsProvider;
}

/**
 * Aggregates every relation type into one word-web: the neighbors of a word
 * across all nine dimensions at once, first-relation-wins dedup.
 */
export class ConnectionWeb {
  private readonly deps: ConnectionWebDeps;

  constructor(deps: ConnectionWebDeps) {
    this.deps = deps;
  }

  /**
   * Up to `perRelation` neighbors of `word` for every relation type.
   * `relations` restricts which dimensions are searched at all — a disabled
   * relation costs nothing and contributes nothing.
   */
  connections(
    word: string,
    perRelation = 5,
    relations: ReadonlySet<Relation> = new Set(ALL_RELATIONS),
  ): ConnectionNode[] {
    const w = word.toLowerCase();
    const { cryptic, ladder, phonetics, fusion, words, associations } = this.deps;
    const nodes: ConnectionNode[] = [];
    const seen = new Set([w]);

    const add = (candidates: string[], relation: Relation, detail: (c: string) => string): void => {
      let n = 0;
      for (const c of candidates) {
        if (n >= perRelation) break;
        if (seen.has(c)) continue;
        seen.add(c);
        nodes.push({ word: c, relation, detail: detail(c) });
        n++;
      }
    };

    if (relations.has("anagram")) {
      add(
        cryptic.anagramWords(w).filter((x) => x !== w),
        "anagram",
        (c) => `${c}: the letters of ${w}, rearranged`,
      );
    }

    if (relations.has("oneLetter")) {
      const steps = [...ladder.changeOneLetter(w), ...ladder.dropOneLetter(w), ...ladder.addOneLetter(w)];
      steps.sort((a, b) => (a.length !== b.length ? a.length - b.length : a < b ? -1 : 1));
      add(steps, "oneLetter", (c) => `${c}: one letter away from ${w}`);
    }

    if (phonetics) {
      if (relations.has("homophone")) {
        add(phonetics.homophones(w), "homophone", (c) => `${c}: pronounced exactly like ${w}`);
      }
      if (relations.has("rhyme")) {
        const rhymes = phonetics.rhymes(w);
        rhymes.sort((a, b) => (a.length !== b.length ? a.length - b.length : a < b ? -1 : 1));
        add(rhymes, "rhyme", (c) => `${c}: rhymes with ${w}`);
      }
    }

    if (fusion) {
      if (relations.has("fusion")) {
        const fusions = fusion.fusions(w, ["before", "after"], 2, perRelation * 2);
        const details = new Map<string, string>();
        for (const f of fusions) {
          if (!details.has(f.partner)) {
            details.set(f.partner, `${f.partner} ⋈ ${w} → “${f.spelling}”`);
          }
        }
        add(
          fusions.map((f) => f.partner),
          "fusion",
          (c) => details.get(c) ?? `sound-overlaps ${w}`,
        );
      }
      if (relations.has("audible")) {
        add(fusion.audibleWords(w), "audible", (c) => `you can hear ${c} inside ${w}`);
      }
    }

    if (relations.has("hidden")) {
      add(
        cryptic
          .hiddenWords(w, 3)
          .map((h) => h.word)
          .filter((x) => x !== w),
        "hidden",
        (c) => `${c} is spelled inside ${w}`,
      );
    }

    if (relations.has("reversal") && words) {
      const rev = [...w].reverse().join("");
      if (rev !== w && words.contains(rev)) {
        add([rev], "reversal", (c) => `${c}: ${w} spelled backwards`);
      }
    }

    if (relations.has("association") && associations) {
      add(associations(w, perRelation * 2), "association", (c) => `${c} keeps company with ${w}`);
    }

    return nodes;
  }
}
