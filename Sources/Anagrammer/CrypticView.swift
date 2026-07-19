import SwiftUI
import AnagramEngine

struct CrypticView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore

    enum Mode: String, CaseIterable, Identifiable {
        case hidden = "Hidden words"
        case charade = "Charades"
        case anagram = "Anagram"
        case palindrome = "Palindrome"
        var id: String { rawValue }
        var prompt: String {
            switch self {
            case .hidden: return "a clue or phrase, e.g. “the scampi dish”"
            case .charade: return "a word to split, e.g. carpet"
            case .anagram: return "letters to rearrange, e.g. listen"
            case .palindrome: return "a word or phrase to test"
            }
        }
    }

    @State private var mode: Mode = .hidden
    @State private var input = ""
    @State private var results: [String] = []
    @State private var isBusy = false

    var body: some View {
        ToolScaffold(
            toolName: "Cryptic",
            title: "Cryptic Helper",
            subtitle: "Tools for setting and solving cryptic clues.",
            controls: { controls },
            resultCount: results.count,
            copyText: results.joined(separator: "\n"),
            isBusy: isBusy,
            lines: results,
            emptyHint: "Pick a mode and enter \(mode.prompt)."
        )
    }

    @ViewBuilder private var controls: some View {
        Picker("", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented).labelsHidden()

        Field(label: hint) {
            TextField(mode.prompt, text: $input)
                .textFieldStyle(.roundedBorder).onSubmit(run)
        }
        Button("Find", action: run)
            .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
    }

    private var hint: String {
        switch mode {
        case .hidden: return "Clue / phrase (★ = spans word boundary)"
        case .charade: return "Word to split into smaller words"
        case .anagram: return "Letters"
        case .palindrome: return "Word or phrase"
        }
    }

    private func run() {
        guard let cryptic = store.cryptic else { return }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let m = mode
        isBusy = true
        Task.detached(priority: .userInitiated) { [cryptic] in
            var out: [String]
            switch m {
            case .hidden:
                let hidden = cryptic.hiddenWords(in: text, minLength: 4)
                out = hidden.isEmpty ? ["No hidden words found."]
                    : hidden.map { ($0.spansBoundary ? "★ " : "  ") + $0.word }
            case .charade:
                let parts = cryptic.charades(of: text)
                out = parts.isEmpty ? ["No charade split found."]
                    : parts.map { $0.joined(separator: " + ") }
            case .anagram:
                let words = cryptic.anagramWords(of: text)
                out = words.isEmpty ? ["No single-word anagram found."] : words
            case .palindrome:
                out = [CrypticHelper.isPalindrome(text)
                    ? "“\(text)” is a palindrome ✓"
                    : "“\(text)” is not a palindrome ✗"]
            }
            let snapshot = out
            await MainActor.run {
                results = snapshot; isBusy = false
                history.record(tool: "Cryptic", query: "\(m.rawValue): \(text)", count: snapshot.count)
            }
        }
    }
}
