import Foundation
import SwiftUI
import AnagramEngine

/// Selectable word lists.
enum DictionaryChoice: String, CaseIterable, Identifiable {
    case scrabble = "Scrabble (ENABLE)"
    case system = "System (large)"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .scrabble: return "172k tournament words — clean, no archaic cruft"
        case .system: return "236k words incl. proper/archaic forms"
        }
    }
}

/// Loads a dictionary and vends every engine. Switching dictionaries rebuilds
/// the engines. Phonetics (CMUdict) loads lazily on first use.
@MainActor
final class WordStore: ObservableObject {
    @Published var status = "Loading dictionary…"
    @Published var isReady = false
    @Published var selected: DictionaryChoice = .scrabble
    @Published var phoneticsReady = false
    @Published var phoneticsLoading = false

    private(set) var wordList: WordList?
    private(set) var anagram: AnagramEngine?
    private(set) var rack: RackSolver?
    private(set) var pattern: PatternMatcher?
    private(set) var ladder: WordLadder?
    private(set) var cryptic: CrypticHelper?
    private(set) var phonetics: PhoneticDictionary?
    private var fusionCache: FusionFinder?

    func loadIfNeeded() {
        guard !isReady else { return }
        load(selected)
    }

    /// Switch the active dictionary and rebuild engines.
    func select(_ choice: DictionaryChoice) {
        guard choice != selected || !isReady else { return }
        selected = choice
        isReady = false
        status = "Loading \(choice.rawValue)…"
        load(choice)
    }

    private func load(_ choice: DictionaryChoice) {
        Task.detached(priority: .userInitiated) {
            let list = Self.loadWordList(choice)
            let anagram = AnagramEngine(wordList: list)
            let rack = RackSolver(wordList: list)
            let pattern = PatternMatcher(wordList: list)
            let ladder = WordLadder(wordList: list)
            let cryptic = CrypticHelper(wordList: list)
            await MainActor.run {
                guard self.selected == choice else { return } // a newer switch won
                self.fusionCache = nil // word list changed; rebuild on next use
                self.wordList = list
                self.anagram = anagram
                self.rack = rack
                self.pattern = pattern
                self.ladder = ladder
                self.cryptic = cryptic
                self.isReady = true
                self.status = "\(list.count) words — \(choice.rawValue)."
            }
        }
    }

    /// Loads CMUdict for the rhymes/syllables tab. Observe `phoneticsReady` /
    /// `phoneticsLoading` for progress.
    func loadPhonetics() {
        if phoneticsReady || phoneticsLoading { return }
        phoneticsLoading = true
        Task.detached(priority: .userInitiated) {
            let text = Self.resourceText("cmudict", "dict") ?? ""
            let dict = PhoneticDictionary(cmudictText: text)
            await MainActor.run {
                self.phonetics = dict
                self.phoneticsReady = dict.count > 0
                self.phoneticsLoading = false
            }
        }
    }

    /// Fusion finder over the current word list + CMUdict. Built off-main on
    /// first use (it precomputes ~170k pronunciations), then cached until the
    /// dictionary changes.
    func fusionFinder() async -> FusionFinder? {
        if let cached = fusionCache { return cached }
        guard let phonetics, let wordList else { return nil }
        let finder = await Task.detached(priority: .userInitiated) {
            FusionFinder(phonetics: phonetics, wordList: wordList)
        }.value
        fusionCache = finder
        return finder
    }

    // MARK: Resource loading (works under `swift run` and packaged .app)

    private nonisolated static func loadWordList(_ choice: DictionaryChoice) -> WordList {
        switch choice {
        case .system:
            return (try? WordList.systemDefault()) ?? WordList(words: [])
        case .scrabble:
            if let url = resourceURL("enable", "txt"), let list = try? WordList.load(from: url) {
                return list
            }
            // Fall back to the system dict if the bundled list is missing.
            return (try? WordList.systemDefault()) ?? WordList(words: [])
        }
    }

    private nonisolated static func resourceURL(_ name: String, _ ext: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: ext)
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    private nonisolated static func resourceText(_ name: String, _ ext: String) -> String? {
        guard let url = resourceURL(name, ext) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
