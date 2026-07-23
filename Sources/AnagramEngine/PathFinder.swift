import Foundation

/// Six-degrees mode: the shortest chain between any two words, where each hop
/// may cross a *different* dimension — a rhyme, then an anagram, then a
/// homophone… Proof, one path at a time, that everything is connected.
public struct PathFinder: Sendable {

    public struct Step: Sendable, Equatable {
        public let word: String
        /// Relation used to arrive here from the previous step; nil for the start.
        public let relation: ConnectionWeb.Relation?
        public let detail: String
    }

    private let cryptic: CrypticHelper
    private let ladder: WordLadder
    private let phonetics: PhoneticDictionary?
    private let fusion: FusionFinder?

    public init(
        cryptic: CrypticHelper,
        ladder: WordLadder,
        phonetics: PhoneticDictionary?,
        fusion: FusionFinder? = nil
    ) {
        self.cryptic = cryptic
        self.ladder = ladder
        self.phonetics = phonetics
        self.fusion = fusion
    }

    /// Bidirectional breadth-first search over the mixed-relation graph
    /// (treated as undirected): expand the smaller frontier from each end
    /// until the two waves meet. Fusion edges are expensive (a full-dictionary
    /// scan), so only the two endpoints get them. Returns nil if no path
    /// exists within `maxVisited` explored words.
    public func path(
        from start: String, to goal: String,
        maxVisited: Int = 60_000
    ) -> [Step]? {
        let s = start.lowercased(), t = goal.lowercased()
        guard !s.isEmpty, !t.isEmpty else { return nil }
        if s == t { return [Step(word: s, relation: nil, detail: "already there")] }

        typealias Parent = [String: (word: String, relation: ConnectionWeb.Relation)]
        var parentF: Parent = [:], parentB: Parent = [:]
        var visitedF: Set<String> = [s], visitedB: Set<String> = [t]
        var frontierF = [s], frontierB = [t]

        while !frontierF.isEmpty, !frontierB.isEmpty,
              visitedF.count + visitedB.count < maxVisited {
            let forward = frontierF.count <= frontierB.count
            var nextFrontier: [String] = []
            for u in (forward ? frontierF : frontierB) {
                for (v, relation) in neighbors(of: u, isEndpoint: u == s || u == t) {
                    if forward {
                        guard visitedF.insert(v).inserted else { continue }
                        parentF[v] = (u, relation)
                        if visitedB.contains(v) {
                            return join(at: v, s: s, t: t, parentF: parentF, parentB: parentB)
                        }
                    } else {
                        guard visitedB.insert(v).inserted else { continue }
                        parentB[v] = (u, relation)
                        if visitedF.contains(v) {
                            return join(at: v, s: s, t: t, parentF: parentF, parentB: parentB)
                        }
                    }
                    nextFrontier.append(v)
                }
            }
            if forward { frontierF = nextFrontier } else { frontierB = nextFrontier }
        }
        return nil
    }

    /// Cheap-to-enumerate edges. Ordered so that when several relations reach
    /// the same word in one layer, the more distinctive one claims the hop
    /// (rhyme last — its fan-out is huge and bland).
    private func neighbors(of u: String, isEndpoint: Bool) -> [(String, ConnectionWeb.Relation)] {
        var out: [(String, ConnectionWeb.Relation)] = []
        if let phonetics {
            for w in phonetics.homophones(u) { out.append((w, .homophone)) }
        }
        for w in cryptic.anagramWords(of: u) where w != u { out.append((w, .anagram)) }
        for w in ladder.changeOneLetter(u) { out.append((w, .oneLetter)) }
        for w in ladder.dropOneLetter(u) { out.append((w, .oneLetter)) }
        for w in ladder.addOneLetter(u) { out.append((w, .oneLetter)) }
        for h in cryptic.hiddenWords(in: u, minLength: 3) where h.word != u {
            out.append((h.word, .hidden))
        }
        if isEndpoint, let fusion {
            for f in fusion.fusions(of: u, minOverlap: 2, cap: 15) {
                out.append((f.partner, .fusion))
            }
        }
        if let phonetics {
            for w in phonetics.rhymes(u) { out.append((w, .rhyme)) }
        }
        return out
    }

    /// Stitch the two half-paths together at the meeting word.
    private func join(
        at meeting: String, s: String, t: String,
        parentF: [String: (word: String, relation: ConnectionWeb.Relation)],
        parentB: [String: (word: String, relation: ConnectionWeb.Relation)]
    ) -> [Step] {
        var forward: [Step] = []
        var cursor = meeting
        while cursor != s, let p = parentF[cursor] {
            forward.append(Step(word: cursor, relation: p.relation,
                                detail: Self.phrase(p.relation, from: p.word, to: cursor)))
            cursor = p.word
        }
        forward.append(Step(word: s, relation: nil, detail: "the journey begins"))
        var steps = Array(forward.reversed())
        cursor = meeting
        while cursor != t, let p = parentB[cursor] {
            steps.append(Step(word: p.word, relation: p.relation,
                              detail: Self.phrase(p.relation, from: cursor, to: p.word)))
            cursor = p.word
        }
        return steps
    }

    private static func phrase(_ r: ConnectionWeb.Relation, from a: String, to b: String) -> String {
        switch r {
        case .anagram: return "\(b): the letters of \(a), rearranged"
        case .oneLetter: return "\(b): one letter away from \(a)"
        case .homophone: return "\(b): pronounced exactly like \(a)"
        case .rhyme: return "\(b): rhymes with \(a)"
        case .fusion: return "\(b) sound-overlaps \(a)"
        case .hidden: return "\(b) is spelled inside \(a)"
        case .audible: return "you can hear \(b) inside \(a)"
        case .reversal: return "\(b): \(a) spelled backwards"
        case .association: return "\(b) keeps company with \(a)"
        }
    }
}
