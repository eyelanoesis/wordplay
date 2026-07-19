import Foundation

public struct HiddenWord: Sendable, Identifiable {
    public let word: String
    public let spansBoundary: Bool   // true if it crosses original word boundaries
    public var id: String { word }
}

/// Tools for cryptic-crossword setting and solving.
public struct CrypticHelper: Sendable {
    private let wordSet: Set<String>
    /// sorted-letters signature -> words (exact single-word anagrams)
    private let anagramIndex: [String: [String]]

    public init(wordList: WordList) {
        var set = Set<String>(minimumCapacity: wordList.words.count)
        var index: [String: [String]] = [:]
        for w in wordList.words {
            set.insert(w)
            let sig = String(w.sorted())
            index[sig, default: []].append(w)
        }
        wordSet = set
        anagramIndex = index
    }

    public func isWord(_ w: String) -> Bool { wordSet.contains(w.lowercased()) }

    // MARK: Hidden words

    /// Words concealed as a contiguous run of letters inside `text` (ignoring
    /// spaces/punctuation). `spansBoundary` flags the classic cryptic case where
    /// the hidden word straddles two or more words of the clue.
    public func hiddenWords(in text: String, minLength: Int = 4) -> [HiddenWord] {
        // Build the letter stream plus, per letter, which original token it's in.
        var letters: [Character] = []
        var token: [Int] = []
        var currentToken = 0
        var inWord = false
        for ch in text.lowercased() {
            if ch >= "a" && ch <= "z" {
                letters.append(ch)
                token.append(currentToken)
                inWord = true
            } else if inWord {
                currentToken += 1
                inWord = false
            }
        }
        guard letters.count >= minLength else { return [] }

        var seen = Set<String>()
        var out: [HiddenWord] = []
        let n = letters.count
        for i in 0..<n {
            // Longest sensible window is capped to keep this quick.
            let maxLen = min(n - i, 24)
            if maxLen < minLength { break }
            var sub = String(letters[i..<i])
            for len in 1...maxLen {
                sub.append(letters[i + len - 1])
                if len < minLength { continue }
                if wordSet.contains(sub), !seen.contains(sub) {
                    seen.insert(sub)
                    let spans = token[i] != token[i + len - 1]
                    out.append(HiddenWord(word: sub, spansBoundary: spans))
                }
            }
        }
        // Prefer boundary-spanning, then longer words.
        out.sort {
            if $0.spansBoundary != $1.spansBoundary { return $0.spansBoundary }
            if $0.word.count != $1.word.count { return $0.word.count > $1.word.count }
            return $0.word < $1.word
        }
        return out
    }

    // MARK: Charades (word = concatenation of dictionary words)

    /// All ways to split `word` into 2…maxParts consecutive dictionary words,
    /// e.g. "carpet" -> ["car","pet"]. Each part must be at least `minPart` long.
    public func charades(of word: String, maxParts: Int = 3, minPart: Int = 2) -> [[String]] {
        let chars = Array(word.lowercased())
        var results: [[String]] = []
        var current: [String] = []

        func recurse(_ start: Int) {
            if current.count > maxParts { return }
            if start == chars.count {
                if current.count >= 2 { results.append(current) }
                return
            }
            // Don't let the remaining tail be unsplittable into >maxParts pieces.
            let partsLeft = maxParts - current.count
            if partsLeft <= 0 { return }
            for end in (start + minPart)...chars.count {
                if end - start < minPart { continue }
                let piece = String(chars[start..<end])
                if wordSet.contains(piece) {
                    current.append(piece)
                    recurse(end)
                    current.removeLast()
                }
            }
        }
        recurse(0)
        results.sort { $0.count != $1.count ? $0.count < $1.count : $0.joined() < $1.joined() }
        return results
    }

    // MARK: Anagrams / palindromes

    /// Exact single-word anagrams of the given letters (excluding the input word).
    public func anagramWords(of letters: String) -> [String] {
        let cleaned = letters.lowercased().filter { $0 >= "a" && $0 <= "z" }
        let sig = String(cleaned.sorted())
        let input = String(cleaned)
        return (anagramIndex[sig] ?? []).filter { $0 != input }.sorted()
    }

    public func isAnagramPair(_ a: String, _ b: String) -> Bool {
        let ca = a.lowercased().filter { $0 >= "a" && $0 <= "z" }.sorted()
        let cb = b.lowercased().filter { $0 >= "a" && $0 <= "z" }.sorted()
        return !ca.isEmpty && ca == cb
    }

    public static func isPalindrome(_ s: String) -> Bool {
        let cleaned = s.lowercased().filter { $0 >= "a" && $0 <= "z" }
        return cleaned.count > 1 && cleaned == String(cleaned.reversed())
    }
}
