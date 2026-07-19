import Foundation

/// Crossword-style pattern search over a word list.
///
/// Pattern syntax:
///   - a letter a–z matches itself
///   - `?` or `.` matches exactly one letter
///   - `*` matches any run of letters (including none)
/// Matching is anchored to the whole word.
public struct PatternMatcher: Sendable {
    let wordList: WordList
    public init(wordList: WordList) { self.wordList = wordList }

    public func matches(pattern rawPattern: String, limit: Int = 0) -> [String] {
        let pattern = Array(rawPattern.lowercased())
        guard !pattern.isEmpty else { return [] }

        var out: [String] = []
        for w in wordList.words {
            if Self.match(Array(w), pattern) {
                out.append(w)
                if limit > 0 && out.count >= limit { break }
            }
        }
        return out
    }

    /// Glob-style match with `?`/`.` = one char and `*` = any run.
    static func match(_ word: [Character], _ pattern: [Character]) -> Bool {
        // Classic two-pointer wildcard matcher with backtracking on `*`.
        var wi = 0, pi = 0
        var star = -1, mark = 0
        while wi < word.count {
            if pi < pattern.count && (pattern[pi] == word[wi] || pattern[pi] == "?" || pattern[pi] == ".") {
                wi += 1; pi += 1
            } else if pi < pattern.count && pattern[pi] == "*" {
                star = pi; mark = wi; pi += 1
            } else if star != -1 {
                pi = star + 1; mark += 1; wi = mark
            } else {
                return false
            }
        }
        while pi < pattern.count && pattern[pi] == "*" { pi += 1 }
        return pi == pattern.count
    }
}
