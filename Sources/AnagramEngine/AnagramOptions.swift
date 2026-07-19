import Foundation

/// Output casing, mirroring the I.A.S. `k` parameter.
public enum Casing: Int, Sendable, CaseIterable {
    case lower = 0       // "lowercase"
    case firstUpper = 1  // "First Upper" (per-word capitalization) — I.A.S. default
    case upper = 2       // "UPPERCASE"
}

/// All the knobs from the advanced form, plus engine limits.
public struct AnagramOptions: Sendable {
    /// Max number of complete anagrams to return (I.A.S. `t`). 0 == unlimited.
    public var maxResults: Int = 500
    /// Max words per anagram (I.A.S. `d`). 0 == unlimited.
    public var maxWords: Int = 0
    /// A word that must appear in every result (I.A.S. `include`). Empty == none.
    public var include: String = ""
    /// Words that may not appear in any result (I.A.S. `exclude`).
    public var exclude: [String] = []
    /// Min letters per word (I.A.S. `n`).
    public var minWordLength: Int = 1
    /// Max letters per word (I.A.S. `m`).
    public var maxWordLength: Int = 20
    /// Allow the same word to be reused within one anagram (I.A.S. `a`).
    public var allowRepeats: Bool = false
    /// Output casing (I.A.S. `k`).
    public var casing: Casing = .firstUpper

    public init() {}
}
