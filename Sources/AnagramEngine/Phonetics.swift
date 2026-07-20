import Foundation

/// Phonetic queries backed by the CMU Pronouncing Dictionary.
///
/// CMUdict line format (cmudict.dict):  `word P H ON EM`
/// Vowel phonemes carry a stress digit (0/1/2); consonants don't. Alternate
/// pronunciations appear as `word(2)`. Lines may end with a `#` comment.
public struct PhoneticDictionary: Sendable {
    /// word -> list of pronunciations (each a phoneme array)
    private let pronunciations: [String: [[String]]]
    /// perfect-rhyme key (last stressed vowel → end) -> words
    private let rhymeIndex: [String: Set<String>]
    /// full pronunciation, stress stripped -> words (for homophones)
    private let homophoneIndex: [String: Set<String>]

    public init(cmudictText text: String) {
        var pron: [String: [[String]]] = [:]
        var rhyme: [String: Set<String>] = [:]
        var homo: [String: Set<String>] = [:]

        for rawLine in text.split(separator: "\n") {
            // Strip trailing comment.
            var line = Substring(rawLine)
            if let hash = line.firstIndex(of: "#") { line = line[..<hash] }
            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard tokens.count >= 2 else { continue }

            // Word, dropping any "(2)" variant suffix.
            var word = String(tokens[0]).lowercased()
            if let paren = word.firstIndex(of: "(") { word = String(word[..<paren]) }
            guard word.allSatisfy({ ($0 >= "a" && $0 <= "z") || $0 == "'" || $0 == "-" }) else { continue }

            let phonemes = tokens[1...].map(String.init)
            pron[word, default: []].append(phonemes)

            if let key = Self.rhymeKey(phonemes) {
                rhyme[key, default: []].insert(word)
            }
            let homoKey = phonemes.map(Self.stripStress).joined(separator: " ")
            homo[homoKey, default: []].insert(word)
        }

        pronunciations = pron
        rhymeIndex = rhyme
        homophoneIndex = homo
    }

    public var count: Int { pronunciations.count }
    public func isKnown(_ word: String) -> Bool { pronunciations[word.lowercased()] != nil }

    // MARK: Syllables

    /// Syllable count = number of vowel phonemes (those carrying a stress digit).
    /// Returns nil if the word isn't in the dictionary.
    public func syllableCount(_ word: String) -> Int? {
        guard let prons = pronunciations[word.lowercased()], let first = prons.first else { return nil }
        return first.filter { $0.contains(where: \.isNumber) }.count
    }

    // MARK: Rhymes

    /// Words that perfectly rhyme with `word` (share the sound from the last
    /// stressed vowel onward), excluding the word itself.
    public func rhymes(_ word: String) -> [String] {
        let w = word.lowercased()
        guard let prons = pronunciations[w] else { return [] }
        var result: Set<String> = []
        for p in prons {
            if let key = Self.rhymeKey(p) {
                result.formUnion(rhymeIndex[key] ?? [])
            }
        }
        result.remove(w)
        return result.sorted()
    }

    // MARK: Homophones

    /// Words pronounced identically to `word` (different spelling).
    public func homophones(_ word: String) -> [String] {
        let w = word.lowercased()
        guard let prons = pronunciations[w] else { return [] }
        var result: Set<String> = []
        for p in prons {
            let key = p.map(Self.stripStress).joined(separator: " ")
            result.formUnion(homophoneIndex[key] ?? [])
        }
        result.remove(w)
        return result.sorted()
    }

    // MARK: Raw access (for FusionFinder and friends)

    /// All pronunciations of `word` (raw phonemes, stress digits intact).
    public func pronunciations(of word: String) -> [[String]] {
        pronunciations[word.lowercased()] ?? []
    }

    /// Words whose full stress-stripped pronunciation equals `phones`.
    public func words(pronouncedAs phones: [String]) -> Set<String> {
        homophoneIndex[phones.joined(separator: " ")] ?? []
    }

    /// Every word with its first (primary) pronunciation, stress stripped —
    /// the raw material for phoneme-level neighborhood searches.
    public func allStrippedPronunciations() -> [(word: String, phones: [String])] {
        pronunciations.compactMap { word, prons in
            guard let first = prons.first else { return nil }
            return (word, first.map(Self.stripStress))
        }
    }

    // MARK: Helpers

    private static func stripStress(_ phoneme: String) -> String {
        String(phoneme.filter { !$0.isNumber })
    }

    /// Key for perfect rhyme: phonemes from the last stressed vowel to the end.
    /// Falls back to the last vowel if none carry primary/secondary stress.
    static func rhymeKey(_ phonemes: [String]) -> String? {
        var lastStressed = -1
        var lastVowel = -1
        for (i, p) in phonemes.enumerated() where p.contains(where: \.isNumber) {
            lastVowel = i
            if p.contains("1") || p.contains("2") { lastStressed = i }
        }
        let start = lastStressed >= 0 ? lastStressed : lastVowel
        guard start >= 0 else { return nil }
        return phonemes[start...].map(stripStress).joined(separator: " ")
    }
}
