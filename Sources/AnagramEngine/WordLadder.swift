import Foundation

/// Word-transformation toys: ladders and single-letter mutations.
public struct WordLadder: Sendable {
    /// Set of valid words for fast membership tests, grouped by length.
    private let byLength: [Int: Set<String>]

    public init(wordList: WordList) {
        var d: [Int: Set<String>] = [:]
        for w in wordList.words {
            d[w.count, default: []].insert(w)
        }
        byLength = d
    }

    private func words(ofLength n: Int) -> Set<String> { byLength[n] ?? [] }
    private func isWord(_ w: String) -> Bool { byLength[w.count]?.contains(w) ?? false }

    // MARK: Word ladder (change one letter at a time)

    /// Shortest ladder from `start` to `goal`, both same length, changing one
    /// letter per step where every intermediate is a real word. Empty if none.
    public func ladder(from start: String, to goal: String, maxDepth: Int = 60) -> [String] {
        let s = start.lowercased(), g = goal.lowercased()
        guard s.count == g.count, isWord(s), isWord(g) else { return [] }
        if s == g { return [s] }

        let pool = words(ofLength: s.count)
        var visited: Set<String> = [s]
        var queue: [[String]] = [[s]]
        var steps = 0
        while !queue.isEmpty, steps < maxDepth {
            steps += 1
            var next: [[String]] = []
            for path in queue {
                let last = path.last!
                for neighbor in oneLetterNeighbors(of: last, in: pool) where !visited.contains(neighbor) {
                    var newPath = path
                    newPath.append(neighbor)
                    if neighbor == g { return newPath }
                    visited.insert(neighbor)
                    next.append(newPath)
                }
            }
            queue = next
        }
        return []
    }

    /// All real words differing from `word` by exactly one letter (same length).
    public func changeOneLetter(_ word: String) -> [String] {
        let w = word.lowercased()
        return oneLetterNeighbors(of: w, in: words(ofLength: w.count)).sorted()
    }

    private func oneLetterNeighbors(of word: String, in pool: Set<String>) -> [String] {
        var result: [String] = []
        var chars = Array(word)
        for i in chars.indices {
            let original = chars[i]
            for c in "abcdefghijklmnopqrstuvwxyz" where c != original {
                chars[i] = c
                let candidate = String(chars)
                if pool.contains(candidate) { result.append(candidate) }
            }
            chars[i] = original
        }
        return result
    }

    // MARK: Single-letter add / drop

    /// Real words made by inserting one letter anywhere (e.g. cat → cart).
    public func addOneLetter(_ word: String) -> [String] {
        let w = word.lowercased()
        let pool = words(ofLength: w.count + 1)
        guard !pool.isEmpty else { return [] }
        var result: Set<String> = []
        let chars = Array(w)
        for i in 0...chars.count {
            for c in "abcdefghijklmnopqrstuvwxyz" {
                var copy = chars
                copy.insert(c, at: i)
                let candidate = String(copy)
                if pool.contains(candidate) { result.insert(candidate) }
            }
        }
        return result.sorted()
    }

    /// Real words made by removing one letter (e.g. cart → cat / car).
    public func dropOneLetter(_ word: String) -> [String] {
        let chars = Array(word.lowercased())
        guard chars.count > 1 else { return [] }
        let pool = words(ofLength: chars.count - 1)
        var result: Set<String> = []
        for i in chars.indices {
            var copy = chars
            copy.remove(at: i)
            let candidate = String(copy)
            if pool.contains(candidate) { result.insert(candidate) }
        }
        return result.sorted()
    }

    /// Beheadment: remove first letter and still a word (scat → cat).
    public func beheadment(_ word: String) -> String? {
        let w = word.lowercased()
        guard w.count > 1 else { return nil }
        let tail = String(w.dropFirst())
        return isWord(tail) ? tail : nil
    }

    /// Curtailment: remove last letter and still a word (cart → car).
    public func curtailment(_ word: String) -> String? {
        let w = word.lowercased()
        guard w.count > 1 else { return nil }
        let head = String(w.dropLast())
        return isWord(head) ? head : nil
    }

    // MARK: Palindrome

    public static func isPalindrome(_ word: String) -> Bool {
        let cleaned = word.lowercased().filter { $0 >= "a" && $0 <= "z" }
        return cleaned.count > 1 && cleaned == String(cleaned.reversed())
    }
}
