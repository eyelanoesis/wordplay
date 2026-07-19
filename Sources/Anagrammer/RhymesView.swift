import SwiftUI
import AnagramEngine

struct RhymesView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore

    enum Mode: String, CaseIterable, Identifiable {
        case rhymes = "Rhymes"
        case homophones = "Homophones"
        case syllables = "Syllables"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .rhymes
    @State private var word = ""
    @State private var results: [String] = []
    @State private var isBusy = false

    var body: some View {
        ToolScaffold(
            toolName: "Rhymes & Sounds",
            title: "Rhymes & Sounds",
            subtitle: "Sound-based wordplay from the CMU Pronouncing Dictionary.",
            controls: { controls },
            resultCount: results.count,
            copyText: results.joined(separator: "\n"),
            isBusy: isBusy || store.phoneticsLoading,
            lines: results,
            emptyHint: store.phoneticsReady ? "Enter a word." : "Loading the pronouncing dictionary…"
        )
        .onAppear { store.loadPhonetics() }
    }

    @ViewBuilder private var controls: some View {
        Picker("", selection: $mode) {
            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented).labelsHidden()

        Field(label: "Word") {
            TextField("e.g. orange", text: $word)
                .textFieldStyle(.roundedBorder).onSubmit(run)
        }
        Button("Look up", action: run)
            .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
            .disabled(!store.phoneticsReady)
    }

    private func run() {
        guard let dict = store.phonetics else { return }
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !w.isEmpty else { return }
        guard dict.isKnown(w) else {
            results = ["“\(w)” isn’t in the pronouncing dictionary."]
            return
        }
        let m = mode
        isBusy = true
        Task.detached(priority: .userInitiated) { [dict] in
            var out: [String]
            switch m {
            case .rhymes:
                let r = dict.rhymes(w)
                out = r.isEmpty ? ["No rhymes found."] : r
            case .homophones:
                let h = dict.homophones(w)
                out = h.isEmpty ? ["No homophones found."] : h
            case .syllables:
                let n = dict.syllableCount(w) ?? 0
                out = ["\(w): \(n) syllable\(n == 1 ? "" : "s")"]
            }
            let snapshot = out
            await MainActor.run {
                results = snapshot; isBusy = false
                history.record(tool: "Rhymes & Sounds", query: "\(m.rawValue): \(w)", count: snapshot.count)
            }
        }
    }
}
