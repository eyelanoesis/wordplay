import Testing
import Foundation
@testable import AnagramEngine

private func engine(_ words: [String]) -> AnagramEngine {
    AnagramEngine(wordList: WordList(words: words))
}

@Test func findsSimpleTwoWordAnagram() {
    let e = engine(["dog", "god", "cat", "act", "go", "do"])
    var opts = AnagramOptions()
    opts.casing = .lower
    let results = Set(e.anagrams(phrase: "god", options: opts))
    #expect(results.contains("dog"))
    #expect(results.contains("god"))
}

@Test func respectsMaxWords() {
    let e = engine(["a", "b", "ab", "ba"])
    var opts = AnagramOptions()
    opts.maxWords = 1
    opts.casing = .lower
    let results = e.anagrams(phrase: "ab", options: opts)
    // With one word only, "a b" must not appear.
    #expect(results.allSatisfy { !$0.contains(" ") })
    #expect(Set(results) == ["ab", "ba"])
}

@Test func includeForcesWord() {
    let e = engine(["dog", "god", "go", "do", "dg"])
    var opts = AnagramOptions()
    opts.include = "go"
    opts.casing = .lower
    let results = e.anagrams(phrase: "godo", options: opts)
    #expect(results.allSatisfy { $0.split(separator: " ").contains("go") })
}

@Test func excludeRemovesWord() {
    let e = engine(["dog", "god"])
    var opts = AnagramOptions()
    opts.exclude = ["god"]
    opts.casing = .lower
    let results = e.anagrams(phrase: "god", options: opts)
    #expect(!results.contains("god"))
    #expect(results.contains("dog"))
}

@Test func casingFirstUpper() {
    let e = engine(["dog"])
    var opts = AnagramOptions()
    opts.casing = .firstUpper
    let results = e.anagrams(phrase: "dog", options: opts)
    #expect(results.contains("Dog"))
}

@Test func minWordLengthFilters() {
    let e = engine(["a", "i", "ai", "ia"])
    var opts = AnagramOptions()
    opts.minWordLength = 2
    opts.casing = .lower
    let results = Set(e.anagrams(phrase: "ai", options: opts))
    #expect(results == ["ai", "ia"])
}

@Test func realDictionarySanityCheck() throws {
    let url = URL(fileURLWithPath: "/usr/share/dict/words")
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    let list = try WordList.load(from: url)
    #expect(list.count > 50_000)
    let e = AnagramEngine(wordList: list)
    var o = AnagramOptions()
    o.casing = .lower
    o.maxWords = 2
    o.minWordLength = 3
    o.maxResults = 1000
    let results = Set(e.anagrams(phrase: "dormitory", options: o))
    // "dirty room" is the famous anagram of "dormitory".
    #expect(results.contains("dirty room") || results.contains("room dirty"))
}
