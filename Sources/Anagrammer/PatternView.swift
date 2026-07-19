import SwiftUI
import AnagramEngine

struct PatternView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore

    @State private var pattern = ""
    @State private var results: [String] = []
    @State private var isBusy = false

    var body: some View {
        ToolScaffold(
            toolName: "Crossword",
            title: "Crossword",
            subtitle: "Find words matching a pattern. ? = one letter, * = any run. Example: c?t, *ology, h__se.",
            controls: { controls },
            resultCount: results.count,
            copyText: results.joined(separator: "\n"),
            isBusy: isBusy,
            lines: results,
            emptyHint: "Enter a pattern like cr?ssw*d."
        )
    }

    @ViewBuilder private var controls: some View {
        Field(label: "Pattern") {
            TextField("e.g. c?t or *tion", text: $pattern)
                .textFieldStyle(.roundedBorder).onSubmit(run)
        }
        Button("Search", action: run)
            .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
    }

    private func run() {
        guard let matcher = store.pattern else { return }
        let p = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) { [matcher] in
            let out = matcher.matches(pattern: p, limit: 5000)
            await MainActor.run {
                results = out; isBusy = false
                history.record(tool: "Crossword", query: p, count: out.count)
            }
        }
    }
}
