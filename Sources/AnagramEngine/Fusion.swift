import Foundation

/// Phonetic fusions: overlap two words by *sound* so both stay audible in one
/// pseudo-word — brain + angel share /EY N/, giving "brangel", in which you
/// also hear "rain" and (schwa-flexed) "gel".
///
/// Linguistically these are overlapping blends; perceptually they are one-word
/// oronyms (a single sound stream with several word parses).
public struct FusionFinder: Sendable {

    /// Where the partner word sits relative to the seed.
    public enum Position: String, CaseIterable, Sendable {
        case before = "Before"   // partner's tail overlaps seed's head (br+angel)
        case after = "After"     // partner's head overlaps seed's tail
    }

    public struct Fusion: Sendable {
        public let partner: String        // "brain"
        public let seed: String           // "angel"
        public let position: Position
        public let sharedPhones: [String] // ["EY", "N"] (stress stripped)
        public let fusedPhones: [String]  // ["B","R","EY","N","JH","AH","L"]
        public let spelling: String       // "brangel" (heuristic suggestion)
        public var bonusWords: [String]   // other words audible in the stream
    }

    private struct Entry: Sendable {
        let word: String
        let phones: [String]  // first pronunciation, stress stripped
    }

    private let phonetics: PhoneticDictionary
    private let allowed: Set<String>
    private let entries: [Entry]

    /// CMU vowel phonemes (stress stripped). A fused-stream "AH" (schwa-ish)
    /// is allowed to stand in for any of these when hunting bonus words.
    private static let vowels: Set<String> = [
        "AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER",
        "EY", "IH", "IY", "OW", "OY", "UH", "UW",
    ]

    public init(phonetics: PhoneticDictionary, wordList: WordList) {
        self.phonetics = phonetics
        var allowed = Set<String>()
        var entries: [Entry] = []
        entries.reserveCapacity(wordList.words.count)
        for word in wordList.words {
            guard let pron = phonetics.pronunciations(of: word).first else { continue }
            allowed.insert(word)
            entries.append(Entry(word: word, phones: pron.map(Self.stripStress)))
        }
        self.allowed = allowed
        self.entries = entries
    }

    /// All fusions of `seed` with dictionary words, longest sound-overlap first.
    /// `minOverlap` is in phonemes; both words must contribute at least one
    /// phoneme beyond the shared stretch. Bonus words are computed for the
    /// returned (capped) results only.
    public func fusions(
        of seed: String,
        positions: Set<Position> = [.before, .after],
        minOverlap: Int = 2,
        cap: Int = 200
    ) -> [Fusion] {
        let seed = seed.lowercased()
        guard let seedPron = phonetics.pronunciations(of: seed).first else { return [] }
        let seedPhones = seedPron.map(Self.stripStress)

        var results: [Fusion] = []
        for entry in entries where entry.word != seed {
            for position in positions {
                guard let k = maxOverlap(entry.phones, seedPhones, position: position),
                      k >= minOverlap else { continue }
                let shared: [String]
                let fused: [String]
                switch position {
                case .before:
                    shared = Array(seedPhones.prefix(k))
                    fused = entry.phones + seedPhones.dropFirst(k)
                case .after:
                    shared = Array(entry.phones.prefix(k))
                    fused = seedPhones + entry.phones.dropFirst(k)
                }
                results.append(Fusion(
                    partner: entry.word,
                    seed: seed,
                    position: position,
                    sharedPhones: shared,
                    fusedPhones: fused,
                    spelling: Self.spellingGuess(
                        partner: entry.word, partnerPhones: entry.phones,
                        seed: seed, overlap: k, position: position),
                    bonusWords: []
                ))
            }
        }

        results.sort {
            if $0.sharedPhones.count != $1.sharedPhones.count {
                return $0.sharedPhones.count > $1.sharedPhones.count
            }
            if $0.fusedPhones.count != $1.fusedPhones.count {
                return $0.fusedPhones.count < $1.fusedPhones.count
            }
            return $0.partner < $1.partner
        }
        results = Array(results.prefix(cap))
        for i in results.indices {
            results[i].bonusWords = bonusWords(
                in: results[i].fusedPhones,
                excluding: [results[i].seed, results[i].partner])
        }
        return results
    }

    /// Dictionary words audible inside `word`'s own pronunciation (the
    /// bonus-word scan, run on the word itself): "rain" hides in "brain".
    public func audibleWords(in word: String) -> [String] {
        let w = word.lowercased()
        guard let pron = phonetics.pronunciations(of: w).first else { return [] }
        return bonusWords(in: pron.map(Self.stripStress), excluding: [w])
    }

    // MARK: Overlap search

    /// Longest k such that the partner and seed share k phonemes at the joint,
    /// with both words extending past it. Nil if below 1.
    private func maxOverlap(_ partner: [String], _ seed: [String], position: Position) -> Int? {
        let limit = min(partner.count, seed.count) - 1
        guard limit >= 1 else { return nil }
        for k in stride(from: limit, through: 1, by: -1) {
            switch position {
            case .before:
                if partner.suffix(k).elementsEqual(seed.prefix(k)) { return k }
            case .after:
                if seed.suffix(k).elementsEqual(partner.prefix(k)) { return k }
            }
        }
        return nil
    }

    // MARK: Bonus words

    /// Dictionary words audible as a contiguous run inside `phones`. An "AH"
    /// in the stream may stand in for any vowel (spoken schwas are elastic —
    /// that's how "gel" /JH EH L/ hides in brangel's /JH AH L/).
    private func bonusWords(in phones: [String], excluding: Set<String>) -> [String] {
        var found = Set<String>()
        let n = phones.count
        for start in 0..<n {
            let maxEnd = min(start + 8, n)
            guard start + 2 <= maxEnd else { continue }
            for end in (start + 2)...maxEnd {
                let slice = Array(phones[start..<end])
                guard slice.contains(where: { Self.vowels.contains($0) }) else { continue }
                for key in Self.schwaVariants(slice) {
                    for word in phonetics.words(pronouncedAs: key)
                    where word.count >= 3 && allowed.contains(word) && !excluding.contains(word) {
                        found.insert(word)
                    }
                }
            }
        }
        return found.sorted { ($0.count, $0) > ($1.count, $1) }.prefix(6).sorted()
    }

    /// The slice itself plus every vowel-substitution of its "AH" positions
    /// (capped at 2 schwas to bound the expansion). Slices under 3 phones get
    /// no flexing — with one consonant of context, "AH → any vowel" claims
    /// you can hear "aisle" in a schwa, which is a stretch too far.
    private static func schwaVariants(_ phones: [String]) -> [[String]] {
        guard phones.count >= 3 else { return [phones] }
        let schwaIdx = phones.indices.filter { phones[$0] == "AH" }
        guard !schwaIdx.isEmpty, schwaIdx.count <= 2 else { return [phones] }
        var variants: [[String]] = [phones]
        for idx in schwaIdx {
            variants = variants.flatMap { v in
                vowels.map { vowel in
                    var copy = v
                    copy[idx] = vowel
                    return copy
                }
            }
        }
        return variants
    }

    // MARK: Spelling suggestion

    /// Written form is a guess — phones don't map cleanly to letters. Estimate
    /// how many of the partner's letters spell the shared phones (proportional
    /// to its phone count) and splice the rest onto the seed's spelling:
    /// brain (5 letters, 4 phones, 2 shared) → drop ceil(5·2/4)=3 → "br"+"angel".
    private static func spellingGuess(
        partner: String, partnerPhones: [String],
        seed: String, overlap: Int, position: Position
    ) -> String {
        let letters = partner.count
        let dropCount = min(
            letters - 1,
            Int((Double(letters) * Double(overlap) / Double(partnerPhones.count)).rounded(.up)))
        switch position {
        case .before: return String(partner.dropLast(dropCount)) + seed
        case .after: return seed + String(partner.dropFirst(dropCount))
        }
    }

    private static func stripStress(_ phoneme: String) -> String {
        String(phoneme.filter { !$0.isNumber })
    }
}
