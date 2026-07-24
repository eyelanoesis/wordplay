// Builds the engine stack for the active dictionary and exposes the three
// calls the codex UI makes: connections, findPath, and pronunciation lookup.
// Replaces the legacy inline engine script — the math now comes from
// src/engine/, which the test suite holds to the Swift originals.
import {
  WordList,
  PhoneticDictionary,
  FusionFinder,
  CrypticHelper,
  WordLadder,
  ConnectionWeb,
  PathFinder,
  AssociationIndex,
  type ConnectionNode,
  type PathStep,
  type Relation,
} from "../engine";
import type { CodexData } from "./dataSource";
import { S, type DictName } from "./settings";

export const DICT_LABELS: Record<DictName, string> = {
  scrabble: "Scrabble (ENABLE)",
  biblical: "Biblical (KJV)",
  dance: "Dance",
};

interface DictEngines {
  wordList: WordList;
  web: ConnectionWeb;
  pathFinder: PathFinder;
}

let phonetics: PhoneticDictionary;
let raw: CodexData;
/** lazy per-dictionary engine stacks (`built` flag pattern from the legacy DICTS) */
const built = new Map<DictName, DictEngines>();

export function initEngines(data: CodexData): void {
  raw = data;
  phonetics = PhoneticDictionary.fromLexicon(data.lexicon);
}

function enginesFor(name: DictName): DictEngines {
  let e = built.get(name);
  if (e) return e;
  const wordList = WordList.fromText(raw.wordlists[name]);
  const cryptic = new CrypticHelper(wordList);
  const ladder = new WordLadder(wordList);
  const fusion = new FusionFinder(phonetics, wordList);
  const assocText = raw.assoc[name];
  const associations = assocText ? AssociationIndex.fromText(assocText).provider : undefined;
  e = {
    wordList,
    web: new ConnectionWeb({ cryptic, ladder, phonetics, fusion, words: wordList, associations }),
    pathFinder: new PathFinder({ cryptic, ladder, phonetics, fusion }),
  };
  built.set(name, e);
  return e;
}

export function activeWordList(): WordList {
  return enginesFor(S.dict).wordList;
}

export function connections(
  word: string,
  perRelation: number,
  relations: ReadonlySet<Relation>,
): ConnectionNode[] {
  return enginesFor(S.dict).web.connections(word, perRelation, relations);
}

export function findPath(a: string, b: string): PathStep[] | null {
  return enginesFor(S.dict).pathFinder.path(a, b); // maxVisited 60000, as always
}

/** First pronunciation (stress-stripped phones) for tooltips and consonance. */
export function pronOf(word: string): string[] | undefined {
  return phonetics.pronunciations(word)[0];
}

export function isKnownWord(word: string): boolean {
  return enginesFor(S.dict).wordList.contains(word);
}
