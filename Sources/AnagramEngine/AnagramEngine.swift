import Foundation

public struct AnagramResult: Sendable {
    public let words: [String]
    public var text: String { words.joined(separator: " ") }
}

/// Multi-word anagram search engine.
///
/// Strategy (the same idea I.A.S. uses):
///   1. Reduce the phrase to a 26-letter count vector.
///   2. Build the *candidate* set — dictionary words whose letters fit the
///      phrase and satisfy the length/exclude filters.
///   3. Depth-first search: pick a candidate that fits the remaining letters,
///      subtract it, recurse on the remainder. When the remainder is empty we
///      have a complete anagram. Using a non-decreasing start index avoids
///      emitting the same word-set in different orders.
public final class AnagramEngine: Sendable {
    private let wordList: WordList

    public init(wordList: WordList) {
        self.wordList = wordList
    }

    /// Stream results to `emit`. Return `false` from `emit` to stop early.
    /// `isCancelled` lets a UI abort a long search.
    public func search(
        phrase: String,
        options: AnagramOptions,
        isCancelled: @escaping () -> Bool = { false },
        emit: (AnagramResult) -> Bool
    ) {
        var target = LetterCount(phrase)
        guard !target.isEmpty else { return }

        let excludeSet = Set(options.exclude.map { $0.lowercased() })

        // Forced "include" word: subtract its letters up front; it is prepended
        // to every result and counts as one word toward maxWords.
        var forced: [String] = []
        if !options.include.isEmpty {
            let incWord = options.include.lowercased()
            let incLetters = LetterCount(incWord)
            guard incLetters.total > 0, target.contains(incLetters) else { return }
            target = target.subtracting(incLetters)
            forced = [incWord]
        }

        // Build candidates against the (post-include) target.
        var candidates: [DictWord] = []
        candidates.reserveCapacity(4096)
        for w in wordList.words {
            let len = w.count
            if len < options.minWordLength || len > options.maxWordLength { continue }
            if excludeSet.contains(w) { continue }
            let lc = LetterCount(w)
            if lc.total == 0 { continue }
            if target.contains(lc) {
                candidates.append(DictWord(display: w, letters: lc, length: len))
            }
        }
        // Longest words first → more "interesting" anagrams surface earliest.
        candidates.sort { $0.length != $1.length ? $0.length > $1.length : $0.display < $1.display }

        guard !candidates.isEmpty else {
            // The phrase might be satisfied by the include word alone.
            if target.isEmpty, !forced.isEmpty {
                _ = emit(AnagramResult(words: forced))
            }
            return
        }

        let minCandLen = candidates.map(\.length).min() ?? 1
        let wordCap = options.maxWords > 0 ? options.maxWords : Int.max
        let resultCap = options.maxResults > 0 ? options.maxResults : Int.max

        var stack: [String] = forced
        var produced = 0
        var stop = false

        func recurse(_ remaining: LetterCount, _ startIndex: Int, _ depth: Int) {
            if stop { return }
            if remaining.isEmpty {
                let result = AnagramResult(words: stack)
                if !emit(result) { stop = true }
                produced += 1
                if produced >= resultCap { stop = true }
                return
            }
            // Pruning: not enough letters left to form even the shortest word,
            // or we've hit the word-count ceiling.
            if remaining.total < minCandLen { return }
            if depth >= wordCap { return }
            if (depth % 64) == 0 && isCancelled() { stop = true; return }

            var i = startIndex
            while i < candidates.count {
                if stop { return }
                let cand = candidates[i]
                if cand.length <= remaining.total, remaining.contains(cand.letters) {
                    stack.append(cand.display)
                    let next = options.allowRepeats ? i : i + 1
                    recurse(remaining.subtracting(cand.letters), next, depth + 1)
                    stack.removeLast()
                }
                i += 1
            }
        }

        recurse(target, 0, forced.count)
    }

    /// Convenience: collect all results (respecting maxResults) into an array,
    /// with casing applied.
    public func anagrams(
        phrase: String,
        options: AnagramOptions,
        isCancelled: @escaping () -> Bool = { false }
    ) -> [String] {
        var out: [String] = []
        search(phrase: phrase, options: options, isCancelled: isCancelled) { result in
            out.append(Self.format(result.words, casing: options.casing))
            return true
        }
        return out
    }

    /// Apply output casing to a word list and join.
    public static func format(_ words: [String], casing: Casing) -> String {
        let cased: [String]
        switch casing {
        case .lower:
            cased = words
        case .upper:
            cased = words.map { $0.uppercased() }
        case .firstUpper:
            cased = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        }
        return cased.joined(separator: " ")
    }
}
