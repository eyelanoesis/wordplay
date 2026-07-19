import Testing
import Foundation
@testable import AnagramEngine

// MARK: Scrabble

@Test func scrabbleScores() {
    #expect(Scrabble.score("quiz") == 22)   // q10 u1 i1 z10
    #expect(Scrabble.score("cat") == 5)      // c3 a1 t1
}

// MARK: Rack solver

@Test func rackFindsSubAnagrams() {
    let solver = RackSolver(wordList: WordList(words: ["cat", "act", "at", "cab", "dog"]))
    let words = Set(solver.solve(rack: "cabt", minLength: 2).map(\.word))
    #expect(words.contains("cat"))
    #expect(words.contains("cab"))
    #expect(words.contains("at"))
    #expect(!words.contains("dog"))   // no d/o/g in rack
}

@Test func rackBlankTileFillsMissingLetter() {
    let solver = RackSolver(wordList: WordList(words: ["cat"]))
    // No 't', but one blank should cover it; blank scores 0 so score = c3+a1 = 4.
    let results = solver.solve(rack: "ca?", minLength: 3)
    #expect(results.count == 1)
    #expect(results[0].word == "cat")
    #expect(results[0].blanksUsed == 1)
    #expect(results[0].score == 4)
}

// MARK: Pattern matcher

@Test func patternMatching() {
    #expect(PatternMatcher.match(Array("cat"), Array("c?t")))
    #expect(PatternMatcher.match(Array("coat"), Array("c*t")))
    #expect(PatternMatcher.match(Array("ct"), Array("c*t")))
    #expect(!PatternMatcher.match(Array("cat"), Array("c?")))
    #expect(PatternMatcher.match(Array("nation"), Array("*tion")))
}

// MARK: Word ladder

@Test func wordLadderFindsPath() {
    let words = ["cold", "cord", "word", "ward", "warm", "card"]
    let ladder = WordLadder(wordList: WordList(words: words))
    let path = ladder.ladder(from: "cold", to: "warm")
    #expect(path.first == "cold")
    #expect(path.last == "warm")
    // Each consecutive pair differs by exactly one letter.
    for i in 1..<path.count {
        let a = Array(path[i-1]), b = Array(path[i])
        let diff = zip(a, b).filter { $0 != $1 }.count
        #expect(diff == 1)
    }
}

@Test func letterAddDropBehead() {
    let ladder = WordLadder(wordList: WordList(words: ["cat", "cart", "scat", "car"]))
    #expect(ladder.addOneLetter("cat").contains("cart"))
    #expect(ladder.dropOneLetter("cart").contains("car"))
    #expect(ladder.beheadment("scat") == "cat")
    #expect(ladder.curtailment("cart") == "car")
    #expect(WordLadder.isPalindrome("level"))
    #expect(!WordLadder.isPalindrome("cat"))
}

// MARK: Phonetics

private let miniCmudict = """
cat K AE1 T
bat B AE1 T
hat HH AE1 T
dog D AO1 G
two T UW1
to T UW1
too T UW1
orange AO1 R AH0 N JH
"""

@Test func phoneticRhymes() {
    let dict = PhoneticDictionary(cmudictText: miniCmudict)
    let r = Set(dict.rhymes("cat"))
    #expect(r.contains("bat"))
    #expect(r.contains("hat"))
    #expect(!r.contains("dog"))
    #expect(!r.contains("cat"))      // excludes itself
}

@Test func phoneticHomophones() {
    let dict = PhoneticDictionary(cmudictText: miniCmudict)
    let h = Set(dict.homophones("two"))
    #expect(h == ["to", "too"])
}

@Test func phoneticSyllables() {
    let dict = PhoneticDictionary(cmudictText: miniCmudict)
    #expect(dict.syllableCount("cat") == 1)
    #expect(dict.syllableCount("orange") == 2)
    #expect(dict.syllableCount("notaword") == nil)
}
