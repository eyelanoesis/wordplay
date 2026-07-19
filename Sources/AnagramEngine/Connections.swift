import Foundation

/// The web: every relation the app knows, radiating from one word.
///
/// Each tool in the app is one kind of edge between words — rearranged letters,
/// one-letter steps, shared sounds, phonetic overlaps, words hiding inside
/// words. `ConnectionWeb` gathers them all so a UI can show the whole
/// neighborhood at once and let you walk it: everything is connected.
public struct ConnectionWeb: Sendable {

    public enum Relation: String, CaseIterable, Sendable, Identifiable, Codable {
        case anagram = "Anagram"            // same letters, rearranged
        case oneLetter = "One letter away"  // change/add/drop a letter
        case homophone = "Homophone"        // sounds identical
        case rhyme = "Rhyme"                // shares the tail sound
        case fusion = "Fusion"              // overlaps by sound (brangel)
        case hidden = "Hidden inside"       // spelled inside the word
        case audible = "Heard inside"       // audible in the pronunciation
        public var id: String { rawValue }
    }

    public struct Node: Sendable, Identifiable, Hashable {
        public let word: String
        public let relation: Relation
        public let detail: String           // tooltip: why these are connected
        public var id: String { "\(relation.rawValue):\(word)" }

        public init(word: String, relation: Relation, detail: String) {
            self.word = word
            self.relation = relation
            self.detail = detail
        }
    }

    private let cryptic: CrypticHelper
    private let ladder: WordLadder
    private let phonetics: PhoneticDictionary?
    private let fusion: FusionFinder?

    public init(
        cryptic: CrypticHelper,
        ladder: WordLadder,
        phonetics: PhoneticDictionary?,
        fusion: FusionFinder?
    ) {
        self.cryptic = cryptic
        self.ladder = ladder
        self.phonetics = phonetics
        self.fusion = fusion
    }

    /// Up to `perRelation` neighbors of `word` for every relation type.
    public func connections(of word: String, perRelation: Int = 5) -> [Node] {
        let w = word.lowercased()
        var nodes: [Node] = []

        func add(_ words: some Sequence<String>, _ relation: Relation, _ detail: (String) -> String) {
            var seen = Set(nodes.map(\.word))
            seen.insert(w)
            var count = 0
            for other in words where !seen.contains(other) {
                guard count < perRelation else { break }
                nodes.append(Node(word: other, relation: relation, detail: detail(other)))
                seen.insert(other)
                count += 1
            }
        }

        add(cryptic.anagramWords(of: w).filter { $0 != w },
            .anagram) { "\($0): the letters of \(w), rearranged" }

        let steps = (ladder.changeOneLetter(w) + ladder.dropOneLetter(w) + ladder.addOneLetter(w))
        add(steps.sorted { ($0.count, $0) < ($1.count, $1) },
            .oneLetter) { "\($0): one letter away from \(w)" }

        if let phonetics {
            add(phonetics.homophones(w), .homophone) { "\($0): pronounced exactly like \(w)" }
            add(phonetics.rhymes(w).sorted { ($0.count, $0) < ($1.count, $1) },
                .rhyme) { "\($0): rhymes with \(w)" }
        }

        if let fusion {
            let fusions = fusion.fusions(of: w, minOverlap: 2, cap: perRelation * 2)
            var details: [String: String] = [:]
            for f in fusions where details[f.partner] == nil {
                details[f.partner] = "\(f.partner) ⋈ \(w) → “\(f.spelling)”"
            }
            add(fusions.map(\.partner), .fusion) { details[$0] ?? "sound-overlaps \(w)" }
            add(fusion.audibleWords(in: w), .audible) { "you can hear \($0) inside \(w)" }
        }

        add(cryptic.hiddenWords(in: w, minLength: 3).map(\.word).filter { $0 != w },
            .hidden) { "\($0) is spelled inside \(w)" }

        return nodes
    }
}
