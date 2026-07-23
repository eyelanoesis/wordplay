// The Wordplay engine — the single source of truth for all wordplay logic.
// Every module is a 1:1 port of its Swift twin in Sources/AnagramEngine/,
// held to the same 40-test suite (tests/engine/).
export { LetterCount } from "./letterCount";
export { WordList, type DictWord } from "./wordList";
export { type AnagramOptions, type Casing, defaultAnagramOptions } from "./anagramOptions";
export { AnagramEngine, type AnagramResult, anagramResultText } from "./anagramEngine";
export { scrabbleScore } from "./scrabble";
export { RackSolver, type RackWord } from "./rackSolver";
export { PatternMatcher } from "./patternMatcher";
export { WordLadder } from "./wordLadder";
export { PhoneticDictionary, stripStress } from "./phonetics";
export { FusionFinder, type Fusion, type FusionPosition } from "./fusion";
export { CrypticHelper, type HiddenWord } from "./cryptic";
export { MinimalPairFinder, type MinimalPairNeighbor, describeContrast } from "./minimalPairs";
export {
  ConnectionWeb,
  ALL_RELATIONS,
  type Relation,
  type ConnectionNode,
  type AssociationsProvider,
  type ConnectionWebDeps,
} from "./connections";
export { PathFinder, type PathStep, type PathFinderDeps } from "./pathFinder";
export { AssociationIndex } from "./associations";
