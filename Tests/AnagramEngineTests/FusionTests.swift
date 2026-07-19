import Testing
import Foundation
@testable import AnagramEngine

// MARK: Fusions

private let miniCMU = """
angel EY1 N JH AH0 L
brain B R EY1 N
rain R EY1 N
gel JH EH1 L
train T R EY1 N
low L OW1
elbow EH1 L B OW0
dog D AO1 G
"""

private func makeFinder() -> FusionFinder {
    let phonetics = PhoneticDictionary(cmudictText: miniCMU)
    let list = WordList(words: ["angel", "brain", "rain", "gel", "train", "low", "elbow", "dog"])
    return FusionFinder(phonetics: phonetics, wordList: list)
}

@Test func brainFusesBeforeAngel() {
    let fusions = makeFinder().fusions(of: "angel", positions: [.before], minOverlap: 2)
    let brangel = fusions.first { $0.partner == "brain" }
    #expect(brangel != nil)
    #expect(brangel?.sharedPhones == ["EY", "N"])          // /EY N/ shared
    #expect(brangel?.fusedPhones == ["B", "R", "EY", "N", "JH", "AH", "L"])
    #expect(brangel?.spelling == "brangel")                // br + angel
    // "train" overlaps the same way; "dog" shares nothing.
    #expect(fusions.contains { $0.partner == "train" })
    #expect(!fusions.contains { $0.partner == "dog" })
}

@Test func bonusWordsAreAudibleInTheStream() {
    let fusions = makeFinder().fusions(of: "angel", positions: [.before], minOverlap: 2)
    let brangel = fusions.first { $0.partner == "brain" }
    // /R EY N/ = rain, exactly; /JH AH L/ = gel via schwa flexibility.
    #expect(brangel?.bonusWords.contains("rain") == true)
    #expect(brangel?.bonusWords.contains("gel") == true)
    // The parents themselves are not "bonus" words.
    #expect(brangel?.bonusWords.contains("angel") != true)
    #expect(brangel?.bonusWords.contains("brain") != true)
}

@Test func fusionAfterSeed() {
    // angel ends /AH L/ … nothing exact here, but elbow /EH L B OW/ after
    // low /L OW/: low ⋈ elbow? Test the .after direction with a clean pair:
    // brain /B R EY N/ + rain? rain is fully contained (no new phones) — the
    // "both must extend" rule rejects it, so use train: brain's tail /R EY N/
    // matches train's tail, not head. Verify head-overlap works: rain after b…
    let fusions = makeFinder().fusions(of: "brain", positions: [.after], minOverlap: 3)
    // brain /B R EY N/ tail /R EY N/ == rain /R EY N/ head — but rain has no
    // phones beyond the overlap, so it must NOT appear.
    #expect(!fusions.contains { $0.partner == "rain" })
}

@Test func minOverlapIsRespected() {
    let loose = makeFinder().fusions(of: "angel", positions: [.before], minOverlap: 1)
    let tight = makeFinder().fusions(of: "angel", positions: [.before], minOverlap: 3)
    #expect(loose.count >= makeFinder().fusions(of: "angel", positions: [.before], minOverlap: 2).count)
    #expect(!tight.contains { $0.partner == "brain" })     // only 2 phones shared
}

@Test func unknownSeedReturnsEmpty() {
    #expect(makeFinder().fusions(of: "zzzz").isEmpty)
}
