import Foundation

public struct RackWord: Sendable, Identifiable {
    public let word: String
    public let score: Int      // Scrabble score (blanks count as 0)
    public let length: Int
    public let blanksUsed: Int
    public var id: String { word }
}

/// Finds every dictionary word that can be built from a subset of a letter rack,
/// optionally using blank tiles (wildcards) to fill missing letters.
public struct RackSolver: Sendable {
    let wordList: WordList
    public init(wordList: WordList) { self.wordList = wordList }

    /// - Parameters:
    ///   - rack: available letters; `?` or `*` characters count as blank tiles.
    ///   - minLength: ignore words shorter than this.
    /// - Returns: matching words sorted by score (desc), then length, then alpha.
    public func solve(rack: String, minLength: Int = 2) -> [RackWord] {
        let lower = rack.lowercased()
        let blanks = lower.filter { $0 == "?" || $0 == "*" }.count
        let rackLetters = LetterCount(lower)            // ignores ? and *
        let capacity = rackLetters.total + Int32(blanks)

        var out: [RackWord] = []
        out.reserveCapacity(2048)

        for w in wordList.words {
            let len = w.count
            if len < minLength { continue }
            if Int32(len) > capacity { continue }

            let wc = LetterCount(w)
            // How many letters does the rack lack? Those must be covered by blanks.
            var deficit = 0
            var blankScorePenalty = 0
            var ok = true
            for i in 0..<26 {
                let need = wc.counts[i] - rackLetters.counts[i]
                if need > 0 {
                    deficit += Int(need)
                    if deficit > blanks { ok = false; break }
                    // Letters covered by blanks score 0.
                    let ch = Character(UnicodeScalar(UInt8(97 + i)))
                    blankScorePenalty += Int(need) * Scrabble.score(String(ch))
                }
            }
            guard ok else { continue }

            let score = Scrabble.score(w) - blankScorePenalty
            out.append(RackWord(word: w, score: score, length: len, blanksUsed: deficit))
        }

        out.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.length != $1.length { return $0.length > $1.length }
            return $0.word < $1.word
        }
        return out
    }
}
