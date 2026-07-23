import Foundation

/// A word plus its precomputed letter vector and original-cased display form.
struct DictWord {
    let display: String       // the word as it should be shown (lowercased canonical)
    let letters: LetterCount
    let length: Int
}

/// A loaded word list, ready to be filtered into candidates for a given phrase.
public struct WordList: Sendable {
    let words: [String]

    /// Number of words loaded.
    public var count: Int { words.count }

    /// Whether the list contains `word` (lowercased exact match).
    public func contains(_ word: String) -> Bool { words.contains(word) }

    public init(words: [String]) {
        self.words = words
    }

    /// Load from a newline-delimited file (e.g. /usr/share/dict/words).
    /// Keeps only purely-alphabetic entries, lowercased and de-duplicated.
    public static func load(from url: URL) throws -> WordList {
        let text = try String(contentsOf: url, encoding: .utf8)
        var seen = Set<String>()
        var out: [String] = []
        out.reserveCapacity(64_000)
        for raw in text.split(separator: "\n") {
            let w = raw.lowercased()
            // alphabetic only — no apostrophes, accents, digits
            if w.allSatisfy({ $0 >= "a" && $0 <= "z" }) && !w.isEmpty {
                if seen.insert(w).inserted { out.append(w) }
            }
        }
        return WordList(words: out)
    }

    /// The default macOS system dictionary.
    public static func systemDefault() throws -> WordList {
        try load(from: URL(fileURLWithPath: "/usr/share/dict/words"))
    }
}
