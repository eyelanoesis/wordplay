import SwiftUI
import AnagramEngine

/// Phonetic fusions — the "brangel" tool. Give it a word; it finds words that
/// overlap it by sound and welds them into pseudo-words where every parent
/// (and sometimes a stowaway) stays audible.
struct FusionView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore

    enum Where: String, CaseIterable, Identifiable {
        case before = "Word in front"
        case after = "Word behind"
        case both = "Both"
        var id: String { rawValue }

        var positions: Set<FusionFinder.Position> {
            switch self {
            case .before: return [.before]
            case .after: return [.after]
            case .both: return [.before, .after]
            }
        }
    }

    @State private var word = ""
    @State private var mode: Where = .both
    @State private var minOverlap = 2
    @State private var results: [String] = []
    @State private var isBusy = false

    var body: some View {
        ToolScaffold(
            toolName: "Fusions",
            title: "Fusions",
            subtitle: "Overlap words by sound: brain ⋈ angel → “brangel” — and you still hear rain and gel.",
            controls: { controls },
            resultCount: results.count,
            copyText: results.joined(separator: "\n"),
            isBusy: isBusy || store.phoneticsLoading,
            lines: results,
            emptyHint: store.phoneticsReady
                ? "Enter a word to fuse — try “angel”."
                : "Loading the pronouncing dictionary…"
        )
        .onAppear { store.loadPhonetics() }
    }

    @ViewBuilder private var controls: some View {
        Picker("", selection: $mode) {
            ForEach(Where.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented).labelsHidden()

        HStack(alignment: .bottom, spacing: 12) {
            Field(label: "Word") {
                TextField("e.g. angel", text: $word)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 260).onSubmit(run)
            }
            Field(label: "Min shared sounds") {
                Stepper("\(minOverlap)", value: $minOverlap, in: 1...4).frame(width: 80)
            }
            Button("Fuse", action: run)
                .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
                .disabled(!store.phoneticsReady)
        }
    }

    private func run() {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !w.isEmpty, store.phoneticsReady else { return }
        let positions = mode.positions
        let minOv = minOverlap
        isBusy = true
        Task {
            guard let finder = await store.fusionFinder() else {
                results = ["Dictionary still loading — try again in a moment."]
                isBusy = false
                return
            }
            let lines = await Task.detached(priority: .userInitiated) { [finder] in
                let fusions = finder.fusions(of: w, positions: positions, minOverlap: minOv)
                if fusions.isEmpty {
                    return ["No fusions found for “\(w)” — is it in the pronouncing dictionary?"]
                }
                return fusions.map { f in
                    let pair = f.position == .before ? "\(f.partner) ⋈ \(f.seed)" : "\(f.seed) ⋈ \(f.partner)"
                    var line = "\(f.spelling)  —  \(pair) · share /\(f.sharedPhones.joined(separator: " "))/"
                    if !f.bonusWords.isEmpty {
                        line += " · also hear: \(f.bonusWords.joined(separator: ", "))"
                    }
                    return line
                }
            }.value
            results = lines
            isBusy = false
            history.record(tool: "Fusions", query: "\(mode.rawValue): \(w)", count: lines.count)
        }
    }
}
