import Foundation

/// A multiset of the 26 ASCII letters a–z, stored as fixed-size counts.
/// Non-letters are ignored; case is folded. This is the workhorse type:
/// anagram search is just repeated subtraction of these vectors.
struct LetterCount: Equatable {
    /// counts[0] == number of 'a', … counts[25] == number of 'z'
    var counts: [Int32]
    /// Total number of letters (sum of counts), cached for fast emptiness checks.
    var total: Int32

    init() {
        counts = [Int32](repeating: 0, count: 26)
        total = 0
    }

    /// Build from arbitrary text, folding case and dropping non-letters.
    init(_ text: String) {
        self.init()
        for scalar in text.lowercased().unicodeScalars {
            let v = scalar.value
            if v >= 97 && v <= 122 { // a…z
                let idx = Int(v - 97)
                counts[idx] += 1
                total += 1
            }
        }
    }

    var isEmpty: Bool { total == 0 }

    /// True if `other` is a sub-multiset of self (every letter fits).
    func contains(_ other: LetterCount) -> Bool {
        if other.total > total { return false }
        for i in 0..<26 where other.counts[i] > counts[i] { return false }
        return true
    }

    /// Returns self minus other. Caller guarantees `contains(other)`.
    func subtracting(_ other: LetterCount) -> LetterCount {
        var result = self
        for i in 0..<26 { result.counts[i] -= other.counts[i] }
        result.total -= other.total
        return result
    }
}
