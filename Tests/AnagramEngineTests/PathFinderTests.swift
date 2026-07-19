import Testing
import Foundation
@testable import AnagramEngine

// MARK: Path finder

private let pathCMU = """
brain B R EY1 N
rain R EY1 N
reign R EY1 N
rein R EY1 N
ruin R UW1 AH0 N
dog D AO1 G
cog K AO1 G
cot K AA1 T
cat K AE1 T
"""

private func makePathFinder(_ words: [String]) -> PathFinder {
    let list = WordList(words: words)
    let phonetics = PhoneticDictionary(cmudictText: pathCMU)
    return PathFinder(
        cryptic: CrypticHelper(wordList: list),
        ladder: WordLadder(wordList: list),
        phonetics: phonetics,
        fusion: FusionFinder(phonetics: phonetics, wordList: list))
}

@Test func classicLadderPath() {
    let finder = makePathFinder(["cat", "cot", "cog", "dog"])
    let steps = finder.path(from: "cat", to: "dog")
    #expect(steps?.map(\.word) == ["cat", "cot", "cog", "dog"])
    #expect(steps?.dropFirst().allSatisfy { $0.relation == .oneLetter } == true)
}

@Test func mixedDimensionPathBeatsSingleDimension() {
    // ruin → rain is a letter step; rain → reign only connects by sound.
    // No pure letter-ladder or pure sound chain can make this trip alone.
    let finder = makePathFinder(["ruin", "rain", "reign"])
    let steps = finder.path(from: "ruin", to: "reign")
    #expect(steps?.map(\.word) == ["ruin", "rain", "reign"])
    #expect(steps?[1].relation == .oneLetter)
    #expect(steps?.last?.relation == .homophone || steps?.last?.relation == .rhyme)
}

@Test func directRhymeIsOneHop() {
    // brain and reign share the /EY N/ tail — connected in a single hop.
    let finder = makePathFinder(["brain", "reign"])
    let steps = finder.path(from: "brain", to: "reign")
    #expect(steps?.count == 2)
}

@Test func unreachableReturnsNil() {
    let finder = makePathFinder(["cat", "dog"])   // no bridge words at all
    #expect(finder.path(from: "cat", to: "dog") == nil)
}

@Test func sameWordIsTrivialPath() {
    let finder = makePathFinder(["cat"])
    #expect(makePathFinder(["cat"]).path(from: "cat", to: "cat")?.count == 1)
    _ = finder
}
