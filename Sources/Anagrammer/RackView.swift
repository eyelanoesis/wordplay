import SwiftUI
import AnagramEngine

struct RackView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore

    @State private var rack = ""
    @State private var minLength = 2
    @State private var results: [RackWord] = []
    @State private var isBusy = false

    var body: some View {
        ToolScaffold(
            toolName: "Rack Solver",
            title: "Rack Solver",
            subtitle: "Every word you can build from these letters, ranked by Scrabble score. Use ? or * for blank tiles.",
            controls: { controls },
            resultCount: results.count,
            copyText: lines.joined(separator: "\n"),
            isBusy: isBusy,
            lines: lines,
            emptyHint: "Enter your letters (e.g. retinas?)."
        )
    }

    private var lines: [String] {
        results.map { r in
            let blanks = r.blanksUsed > 0 ? "  (\(r.blanksUsed) blank)" : ""
            return String(format: "%3d  %@%@", r.score, r.word, blanks)
        }
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 12) {
            Field(label: "Your letters") {
                TextField("e.g. wordplay", text: $rack)
                    .textFieldStyle(.roundedBorder).onSubmit(run)
            }
            Field(label: "Min length") {
                Picker("", selection: $minLength) {
                    ForEach(2...8, id: \.self) { Text("\($0)").tag($0) }
                }.labelsHidden().frame(width: 70)
            }
        }
        Button("Solve", action: run)
            .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
    }

    private func run() {
        guard let solver = store.rack else { return }
        let r = rack.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty else { return }
        isBusy = true
        let minL = minLength
        Task.detached(priority: .userInitiated) { [solver] in
            let out = solver.solve(rack: r, minLength: minL)
            await MainActor.run {
                results = out; isBusy = false
                history.record(tool: "Rack Solver", query: r, count: out.count)
            }
        }
    }
}
