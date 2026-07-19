import SwiftUI
import AnagramEngine

struct LadderView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore

    enum Mode: String, CaseIterable, Identifiable {
        case ladder = "Ladder"
        case change = "Change a letter"
        case add = "Add a letter"
        case drop = "Drop a letter"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .ladder
    @State private var start = ""
    @State private var goal = ""
    @State private var results: [String] = []
    @State private var isBusy = false

    var body: some View {
        ToolScaffold(
            toolName: "Word Ladder",
            title: "Word Ladder",
            subtitle: "Transform one word into another a letter at a time — or list the words one step away.",
            controls: { controls },
            resultCount: results.count,
            copyText: results.joined(separator: "\n"),
            isBusy: isBusy,
            lines: results,
            emptyHint: "Enter a word (and a goal for a ladder)."
        )
    }

    @ViewBuilder private var controls: some View {
        Picker("", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented).labelsHidden()

        HStack(spacing: 12) {
            Field(label: "Word") {
                TextField("e.g. cold", text: $start)
                    .textFieldStyle(.roundedBorder).onSubmit(run)
            }
            if mode == .ladder {
                Field(label: "Goal (same length)") {
                    TextField("e.g. warm", text: $goal)
                        .textFieldStyle(.roundedBorder).onSubmit(run)
                }
            }
        }
        Button(mode == .ladder ? "Find Ladder" : "Find Words", action: run)
            .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
    }

    private func run() {
        guard let ladder = store.ladder else { return }
        let s = start.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return }
        let g = goal.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let m = mode
        isBusy = true
        Task.detached(priority: .userInitiated) { [ladder] in
            var out: [String]
            switch m {
            case .ladder:
                let path = ladder.ladder(from: s, to: g)
                out = path.isEmpty
                    ? ["No ladder found between “\(s)” and “\(g)”."]
                    : path.enumerated().map { "\($0.offset + 1). \($0.element)" }
            case .change:
                out = ladderDecorate(ladder.changeOneLetter(s), empty: "No one-letter changes.")
            case .add:
                out = ladderDecorate(ladder.addOneLetter(s), empty: "No words by adding a letter.")
            case .drop:
                out = ladderDecorate(ladder.dropOneLetter(s), empty: "No words by dropping a letter.")
            }
            let snapshot = out
            await MainActor.run {
                results = snapshot; isBusy = false
                let q = m == .ladder ? "\(s) → \(g)" : s
                history.record(tool: "Word Ladder", query: q, count: snapshot.count)
            }
        }
    }
}

private func ladderDecorate(_ list: [String], empty: String) -> [String] {
    list.isEmpty ? [empty] : list
}
