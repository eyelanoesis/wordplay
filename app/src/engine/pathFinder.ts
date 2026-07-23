// Ported from Sources/AnagramEngine/PathFinder.swift
import { CrypticHelper } from "./cryptic";
import { WordLadder } from "./wordLadder";
import { PhoneticDictionary } from "./phonetics";
import { FusionFinder } from "./fusion";
import type { Relation } from "./connections";

export interface PathStep {
  word: string;
  /** Relation used to arrive here from the previous step; null for the start. */
  relation: Relation | null;
  detail: string;
}

export interface PathFinderDeps {
  cryptic: CrypticHelper;
  ladder: WordLadder;
  phonetics?: PhoneticDictionary;
  fusion?: FusionFinder;
}

/**
 * Six-degrees mode: the shortest chain between any two words, where each hop
 * may cross a *different* dimension — a rhyme, then an anagram, then a
 * homophone… Proof, one path at a time, that everything is connected.
 */
export class PathFinder {
  private readonly deps: PathFinderDeps;

  constructor(deps: PathFinderDeps) {
    this.deps = deps;
  }

  /**
   * Bidirectional breadth-first search over the mixed-relation graph
   * (treated as undirected): expand the smaller frontier from each end
   * until the two waves meet. Fusion edges are expensive (a full-dictionary
   * scan), so only the two endpoints get them. Returns null if no path
   * exists within `maxVisited` explored words.
   */
  path(start: string, goal: string, maxVisited = 60_000): PathStep[] | null {
    const s = start.toLowerCase(),
      t = goal.toLowerCase();
    if (s.length === 0 || t.length === 0) return null;
    if (s === t) return [{ word: s, relation: null, detail: "already there" }];

    const parentF = new Map<string, [string, Relation]>();
    const parentB = new Map<string, [string, Relation]>();
    const visitedF = new Set([s]),
      visitedB = new Set([t]);
    let frontierF = [s],
      frontierB = [t];

    while (
      frontierF.length > 0 &&
      frontierB.length > 0 &&
      visitedF.size + visitedB.size < maxVisited
    ) {
      const forward = frontierF.length <= frontierB.length;
      const nextFrontier: string[] = [];
      for (const u of forward ? frontierF : frontierB) {
        for (const [v, relation] of this.neighbors(u, u === s || u === t)) {
          if (forward) {
            if (visitedF.has(v)) continue;
            visitedF.add(v);
            parentF.set(v, [u, relation]);
            if (visitedB.has(v)) return join(v, s, t, parentF, parentB);
          } else {
            if (visitedB.has(v)) continue;
            visitedB.add(v);
            parentB.set(v, [u, relation]);
            if (visitedF.has(v)) return join(v, s, t, parentF, parentB);
          }
          nextFrontier.push(v);
        }
      }
      if (forward) frontierF = nextFrontier;
      else frontierB = nextFrontier;
    }
    return null;
  }

  /**
   * Cheap-to-enumerate edges. Ordered so that when several relations reach
   * the same word in one layer, the more distinctive one claims the hop
   * (rhyme last — its fan-out is huge and bland).
   */
  private neighbors(u: string, isEndpoint: boolean): Array<[string, Relation]> {
    const { cryptic, ladder, phonetics, fusion } = this.deps;
    const out: Array<[string, Relation]> = [];
    if (phonetics) {
      for (const w of phonetics.homophones(u)) out.push([w, "homophone"]);
    }
    for (const w of cryptic.anagramWords(u)) if (w !== u) out.push([w, "anagram"]);
    for (const w of ladder.changeOneLetter(u)) out.push([w, "oneLetter"]);
    for (const w of ladder.dropOneLetter(u)) out.push([w, "oneLetter"]);
    for (const w of ladder.addOneLetter(u)) out.push([w, "oneLetter"]);
    for (const h of cryptic.hiddenWords(u, 3)) if (h.word !== u) out.push([h.word, "hidden"]);
    if (isEndpoint && fusion) {
      for (const f of fusion.fusions(u, ["before", "after"], 2, 15)) {
        out.push([f.partner, "fusion"]);
      }
    }
    if (phonetics) {
      for (const w of phonetics.rhymes(u)) out.push([w, "rhyme"]);
    }
    return out;
  }
}

/** Stitch the two half-paths together at the meeting word. */
function join(
  meeting: string,
  s: string,
  t: string,
  parentF: Map<string, [string, Relation]>,
  parentB: Map<string, [string, Relation]>,
): PathStep[] {
  const forward: PathStep[] = [];
  let cursor = meeting;
  while (cursor !== s) {
    const p = parentF.get(cursor);
    if (!p) break;
    forward.push({ word: cursor, relation: p[1], detail: phrase(p[1], p[0], cursor) });
    cursor = p[0];
  }
  forward.push({ word: s, relation: null, detail: "the journey begins" });
  const steps = forward.reverse();
  cursor = meeting;
  while (cursor !== t) {
    const p = parentB.get(cursor);
    if (!p) break;
    steps.push({ word: p[0], relation: p[1], detail: phrase(p[1], cursor, p[0]) });
    cursor = p[0];
  }
  return steps;
}

function phrase(r: Relation, a: string, b: string): string {
  switch (r) {
    case "anagram":
      return `${b}: the letters of ${a}, rearranged`;
    case "oneLetter":
      return `${b}: one letter away from ${a}`;
    case "homophone":
      return `${b}: pronounced exactly like ${a}`;
    case "rhyme":
      return `${b}: rhymes with ${a}`;
    case "fusion":
      return `${b} sound-overlaps ${a}`;
    case "hidden":
      return `${b} is spelled inside ${a}`;
    case "audible":
      return `you can hear ${b} inside ${a}`;
    case "reversal":
      return `${b}: ${a} spelled backwards`;
    case "association":
      return `${b} keeps company with ${a}`;
  }
}
