import Testing
import Foundation
@testable import AnagramEngine

// MARK: Connection web

private let webCMU = """
brain B R EY1 N
braid B R EY1 D
rain R EY1 N
train T R EY1 N
explain IH0 K S P L EY1 N
angel EY1 N JH AH0 L
gel JH EH1 L
"""

private func makeWeb() -> ConnectionWeb {
    let words = ["brain", "braid", "rain", "train", "explain", "angel", "gel", "bra"]
    let list = WordList(words: words)
    let phonetics = PhoneticDictionary(cmudictText: webCMU)
    return ConnectionWeb(
        cryptic: CrypticHelper(wordList: list),
        ladder: WordLadder(wordList: list),
        phonetics: phonetics,
        fusion: FusionFinder(phonetics: phonetics, wordList: list))
}

@Test func webGathersEveryRelationKind() {
    let nodes = makeWeb().connections(of: "brain", perRelation: 5)
    func relation(of word: String) -> ConnectionWeb.Relation? {
        nodes.first { $0.word == word }?.relation
    }
    #expect(relation(of: "braid") == .oneLetter)     // change n→d
    #expect(relation(of: "rain") == .oneLetter)      // drop the b (first relation wins)
    #expect(relation(of: "explain") == .rhyme)       // shares /EY N/ tail, 2+ letters apart
    #expect(relation(of: "angel") == .fusion)        // brain ⋈ angel = brangel
    #expect(relation(of: "bra") == .hidden)          // spelled inside brain, 2 letters short
    #expect(relation(of: "brain") == nil)            // never its own neighbor
}

@Test func webDeduplicatesAcrossRelations() {
    let nodes = makeWeb().connections(of: "brain", perRelation: 5)
    // "rain" is one letter away AND hidden AND audible AND a rhyme — it must
    // appear exactly once, under the first relation that claimed it.
    #expect(nodes.filter { $0.word == "rain" }.count == 1)
}

@Test func webWorksWithoutPhonetics() {
    let list = WordList(words: ["brain", "braid", "rain", "bran"])
    let web = ConnectionWeb(
        cryptic: CrypticHelper(wordList: list),
        ladder: WordLadder(wordList: list),
        phonetics: nil, fusion: nil)
    let nodes = web.connections(of: "brain")
    #expect(nodes.contains { $0.word == "braid" })   // letter relations still work
    #expect(!nodes.contains { $0.relation == .rhyme })
}

@Test func webRespectsPerRelationCap() {
    let nodes = makeWeb().connections(of: "brain", perRelation: 1)
    for relation in ConnectionWeb.Relation.allCases {
        #expect(nodes.filter { $0.relation == relation }.count <= 1)
    }
}

@Test func webRespectsRelationFilter() {
    let web = makeWeb()
    // Only one-letter steps allowed: nothing else may appear.
    let only = web.connections(of: "brain", relations: [.oneLetter])
    #expect(!only.isEmpty)
    #expect(only.allSatisfy { $0.relation == .oneLetter })
    // Empty filter: nothing at all.
    #expect(web.connections(of: "brain", relations: []).isEmpty)
    // A word claimed by a disabled first relation falls to the next enabled one:
    // "rain" is normally .oneLetter; with letters off it surfaces phonetically.
    let noLetters = web.connections(of: "brain",
                                    relations: [.rhyme, .fusion, .hidden, .audible])
    if let rain = noLetters.first(where: { $0.word == "rain" }) {
        #expect(rain.relation != .oneLetter)
    }
}
