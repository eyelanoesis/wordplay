import Testing
@testable import AnagramEngine

private func helper(_ words: [String]) -> CrypticHelper {
    CrypticHelper(wordList: WordList(words: words))
}

@Test func hiddenWordsAcrossBoundary() {
    // "drama idea" -> "dramaidea" conceals "maid" across the word boundary.
    let h = helper(["maid", "dish", "scam", "rama"])
    let found = h.hiddenWords(in: "drama idea", minLength: 4)
    let words = Set(found.map(\.word))
    #expect(words.contains("maid"))
    #expect(found.first(where: { $0.word == "maid" })?.spansBoundary == true)
    // "rama" sits wholly inside "drama" — not boundary-spanning.
    #expect(found.first(where: { $0.word == "rama" })?.spansBoundary == false)
}

@Test func charadeSplits() {
    let h = helper(["car", "pet", "carpet", "cape", "t"])
    let splits = h.charades(of: "carpet", maxParts: 3, minPart: 2)
    // car + pet should be among the splits.
    #expect(splits.contains { $0 == ["car", "pet"] })
}

@Test func singleWordAnagrams() {
    let h = helper(["listen", "silent", "tinsel", "enlist", "dog"])
    let words = Set(h.anagramWords(of: "listen"))
    #expect(words.contains("silent"))
    #expect(words.contains("tinsel"))
    #expect(words.contains("enlist"))
    #expect(!words.contains("listen"))   // excludes the input itself
    #expect(!words.contains("dog"))
}

@Test func anagramPairAndPalindrome() {
    let h = helper([])
    #expect(h.isAnagramPair("listen", "silent"))
    #expect(!h.isAnagramPair("listen", "tinned"))
    #expect(CrypticHelper.isPalindrome("racecar"))
    #expect(!CrypticHelper.isPalindrome("racecars"))
}
