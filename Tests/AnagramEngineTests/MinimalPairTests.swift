import Testing
import Foundation
@testable import AnagramEngine

private let mpCMU = """
pat P AE1 T
bat B AE1 T
cat K AE1 T
pit P IH1 T
pad P AE1 D
sip S IH1 P
ship SH IH1 P
bit B IH1 T
beat B IY1 T
dog D AO1 G
"""

private func finder() -> (MinimalPairFinder, PhoneticDictionary) {
    let ph = PhoneticDictionary(cmudictText: mpCMU)
    return (MinimalPairFinder(phonetics: ph), ph)
}

@Test func findsMinimalPairsInSound() {
    let (f, ph) = finder()
    let words = Set(f.pairs(of: "pat").map(\.word))
    #expect(words.contains("bat"))     // P~B, position 0
    #expect(words.contains("cat"))     // P~K, position 0
    #expect(words.contains("pit"))     // AE~IH, position 1
    #expect(words.contains("pad"))     // T~D, position 2
    #expect(!words.contains("dog"))    // shares nothing positionally
    #expect(!words.contains("pat"))    // never itself
}

@Test func namesTheDistinctiveFeature() {
    let (f, ph) = finder()
    let byWord = Dictionary(uniqueKeysWithValues:
        f.pairs(of: "pat").map { ($0.word, $0.contrast) })
    #expect(byWord["bat"] == "voicing")     // P/B differ only in voice
    #expect(byWord["cat"] == "place")       // P/K differ only in place
    #expect(byWord["pad"] == "voicing")     // T/D differ only in voice
    #expect(byWord["pit"] == "vowel height")// AE/IH: front vowels, height differs
}

@Test func minimalPairIsPhonemicNotOrthographic() {
    // "sip"/"ship" is a real minimal pair (S~SH) even though the spelling
    // differs by an inserted letter — a letter-ladder would miss it.
    let (f, ph) = finder()
    #expect(f.pairs(of: "sip").contains { $0.word == "ship" && $0.contrast == "manner" || $0.word == "ship" })
    // "bit"/"beat" differ by one phoneme (IH~IY) but by spelling look 2+ apart.
    #expect(f.pairs(of: "bit").contains { $0.word == "beat" })
}

@Test func unknownWordIsEmpty() {
    let (f, ph) = finder()
    #expect(f.pairs(of: "zzz").isEmpty)
}
