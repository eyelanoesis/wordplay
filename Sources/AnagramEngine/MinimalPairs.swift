import Foundation

/// Minimal pairs: two words whose pronunciations differ by exactly one
/// phoneme in the same position — `pat`/`bat`, `sip`/`ship`, `bit`/`beat`.
///
/// This is the phonological counterpart to the orthographic "one letter away"
/// ladder: it works in *sound*, not spelling, and names the single distinctive
/// feature that separates the two words (voicing, place, manner, or a vowel
/// dimension). Minimal pairs are the classic evidence that two sounds contrast
/// in a language, so this turns the word list into a phonology instrument.
public struct MinimalPairFinder: Sendable {

    /// One minimal-pair neighbor: the word, and the contrast that makes it one.
    public struct Neighbor: Sendable, Hashable {
        public let word: String
        public let position: Int          // phoneme index that differs
        public let from: String           // this word's phoneme there
        public let to: String             // the neighbor's phoneme there
        public let contrast: String       // human description of the difference
    }

    /// Wildcard key ("_" at position i) -> [(word, phoneme-at-i)].
    /// Two entries under the same key are a minimal pair at position i.
    private let index: [String: [(word: String, phoneme: String)]]
    /// word -> its stress-stripped phonemes, so a query needs no rescan.
    private let phonesOf: [String: [String]]

    public init(phonetics: PhoneticDictionary) {
        var idx: [String: [(word: String, phoneme: String)]] = [:]
        var pmap: [String: [String]] = [:]
        for (word, phones) in phonetics.allStrippedPronunciations() {
            guard !phones.isEmpty else { continue }
            pmap[word] = phones
            for i in phones.indices {
                var key = phones
                let here = key[i]
                key[i] = "_"
                idx[key.joined(separator: " "), default: []].append((word, here))
            }
        }
        index = idx
        phonesOf = pmap
    }

    /// Minimal pairs of `word`, each annotated with the distinctive feature
    /// that separates it from `word`. Sorted by contrast type then word.
    public func pairs(of word: String) -> [Neighbor] {
        let w = word.lowercased()
        guard let phones = phonesOf[w] else { return [] }

        var out: [Neighbor] = []
        var seen = Set<String>()
        for i in phones.indices {
            var key = phones
            let here = key[i]
            key[i] = "_"
            for entry in index[key.joined(separator: " "), default: []] {
                guard entry.word != w, !seen.contains(entry.word) else { continue }
                seen.insert(entry.word)
                out.append(Neighbor(
                    word: entry.word, position: i, from: here, to: entry.phoneme,
                    contrast: Self.describe(here, entry.phoneme)))
            }
        }
        return out.sorted { ($0.contrast, $0.word) < ($1.contrast, $1.word) }
    }

    // MARK: Distinctive features (ARPABET)

    private enum Kind { case consonant, vowel }

    private struct Feat {
        let kind: Kind
        let voiced: Bool
        let place: String     // consonants: articulation place; vowels: backness
        let manner: String    // consonants: manner; vowels: height
        let round: Bool       // vowels only
    }

    /// Describe the single-feature contrast between two ARPABET phonemes.
    static func describe(_ a: String, _ b: String) -> String {
        guard let fa = FEATURES[a], let fb = FEATURES[b] else { return "sound" }
        if fa.kind != fb.kind { return "consonant↔vowel" }
        if fa.kind == .consonant {
            if fa.voiced != fb.voiced && fa.place == fb.place && fa.manner == fb.manner {
                return "voicing"                      // p~b, s~z, t~d
            }
            if fa.place != fb.place && fa.manner == fb.manner && fa.voiced == fb.voiced {
                return "place"                        // p~t, k~t, m~n
            }
            if fa.manner != fb.manner && fa.place == fb.place {
                return "manner"                       // t~s, d~n
            }
            return "consonant quality"
        }
        // vowels
        if fa.manner != fb.manner && fa.place == fb.place {
            return "vowel height"                     // ih~eh, uh~ow (front/back held)
        }
        if fa.place != fb.place && fa.manner == fb.manner {
            return "vowel backness"                   // ih~uh
        }
        if fa.round != fb.round {
            return "rounding"
        }
        return "vowel quality"
    }

    private static let FEATURES: [String: Feat] = {
        func c(_ v: Bool, _ p: String, _ m: String) -> Feat {
            Feat(kind: .consonant, voiced: v, place: p, manner: m, round: false)
        }
        func vw(_ height: String, _ back: String, _ r: Bool) -> Feat {
            Feat(kind: .vowel, voiced: true, place: back, manner: height, round: r)
        }
        return [
            // stops
            "P": c(false, "bilabial", "stop"),   "B": c(true, "bilabial", "stop"),
            "T": c(false, "alveolar", "stop"),   "D": c(true, "alveolar", "stop"),
            "K": c(false, "velar", "stop"),      "G": c(true, "velar", "stop"),
            // fricatives
            "F": c(false, "labiodental", "fricative"), "V": c(true, "labiodental", "fricative"),
            "TH": c(false, "dental", "fricative"),     "DH": c(true, "dental", "fricative"),
            "S": c(false, "alveolar", "fricative"),    "Z": c(true, "alveolar", "fricative"),
            "SH": c(false, "postalveolar", "fricative"), "ZH": c(true, "postalveolar", "fricative"),
            "HH": c(false, "glottal", "fricative"),
            // affricates
            "CH": c(false, "postalveolar", "affricate"), "JH": c(true, "postalveolar", "affricate"),
            // nasals
            "M": c(true, "bilabial", "nasal"), "N": c(true, "alveolar", "nasal"),
            "NG": c(true, "velar", "nasal"),
            // approximants
            "L": c(true, "alveolar", "liquid"), "R": c(true, "alveolar", "liquid"),
            "W": c(true, "velar", "glide"),     "Y": c(true, "palatal", "glide"),
            // vowels — (height, backness, rounded)
            "IY": vw("high", "front", false), "IH": vw("near-high", "front", false),
            "EY": vw("mid", "front", false),  "EH": vw("mid", "front", false),
            "AE": vw("low", "front", false),
            "AA": vw("low", "back", false),   "AO": vw("mid", "back", true),
            "OW": vw("mid", "back", true),    "UH": vw("near-high", "back", true),
            "UW": vw("high", "back", true),
            "AH": vw("mid", "central", false), "ER": vw("mid", "central", false),
            "AW": vw("low", "central", false), "AY": vw("low", "central", false),
            "OY": vw("mid", "central", true),
        ]
    }()
}
