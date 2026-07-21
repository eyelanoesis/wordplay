import SwiftUI
import AnagramEngine

/// Minimal Pairs — the phonology tool. Give it a word; it finds every word
/// that differs by exactly one *sound* and groups them by the distinctive
/// feature that separates the pair (voicing, place, manner, vowel height…).
/// Tap any word — or the seed — to hear the contrast.
struct MinimalPairsView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore

    @State private var word = ""
    @State private var seed = ""
    @State private var groups: [(contrast: String, pairs: [MinimalPairFinder.Neighbor])] = []
    @State private var isBusy = false
    @State private var searched = false

    /// Order contrasts from consonantal to vocalic, most pedagogically common
    /// first, so the list reads like a phonetics lesson.
    private static let order = [
        "voicing", "place", "manner", "consonant quality", "consonant↔vowel",
        "vowel height", "vowel backness", "rounding", "vowel quality", "sound",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            resultsHeader
            Divider()
            body(for: groups)
        }
        .onAppear { store.loadPhonetics() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Minimal Pairs").font(.title.bold())
                Text("Words that differ by exactly one sound — grouped by the feature that separates them. Tap to hear it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 12) {
                Field(label: "Word") {
                    TextField("e.g. cat", text: $word)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 240).onSubmit(run)
                }
                Button("Find pairs", action: run)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
                    .disabled(!store.phoneticsReady)
                if isBusy || store.phoneticsLoading { ProgressView().controlSize(.small) }
                Spacer()
            }
        }
        .padding(16)
    }

    private var resultsHeader: some View {
        HStack(spacing: 12) {
            let total = groups.reduce(0) { $0 + $1.pairs.count }
            Text("\(total) minimal pair(s)").font(.headline)
            if !seed.isEmpty, let ph = store.phonetics?.pronunciations(of: seed).first {
                Button {
                    ChimeEngine.shared.speakNow(seed)
                } label: {
                    Label("/\(ph.map(stripStress).joined(separator: " "))/",
                          systemImage: "speaker.wave.2")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help("hear \(seed)")
            }
            Spacer()
        }
        .padding(10)
    }

    private func stripStress(_ p: String) -> String {
        String(p.filter { !$0.isNumber })
    }

    @ViewBuilder private func body(for groups: [(contrast: String, pairs: [MinimalPairFinder.Neighbor])]) -> some View {
        if groups.isEmpty {
            VStack {
                Spacer()
                Text(placeholder).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(groups, id: \.contrast) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(group.contrast)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(color(for: group.contrast))
                                Text("\(group.pairs.count)")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Capsule().fill(.quaternary))
                            }
                            FlowChips(pairs: group.pairs) { neighbor in
                                ChimeEngine.shared.speakNow(neighbor.word)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var placeholder: String {
        if !store.phoneticsReady { return "Loading the pronouncing dictionary…" }
        return searched ? "No minimal pairs for “\(seed)”." : "Enter a word to find its minimal pairs."
    }

    /// Warm-to-cool by articulatory type so the eye can navigate the groups.
    private func color(for contrast: String) -> Color {
        switch contrast {
        case "voicing": return Color(red: 0.85, green: 0.45, blue: 0.15)
        case "place": return Color(red: 0.80, green: 0.30, blue: 0.35)
        case "manner": return Color(red: 0.70, green: 0.35, blue: 0.60)
        case "vowel height": return Color(red: 0.25, green: 0.55, blue: 0.75)
        case "vowel backness": return Color(red: 0.20, green: 0.60, blue: 0.55)
        case "rounding": return Color(red: 0.30, green: 0.60, blue: 0.35)
        default: return .secondary
        }
    }

    private func run() {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !w.isEmpty, store.phoneticsReady else { return }
        isBusy = true
        Task {
            guard let finder = await store.minimalPairFinder() else { isBusy = false; return }
            let pairs = await Task.detached(priority: .userInitiated) { [finder] in
                finder.pairs(of: w)
            }.value
            let grouped = Dictionary(grouping: pairs, by: \.contrast)
                .map { (contrast: $0.key, pairs: $0.value) }
                .sorted { lhs, rhs in
                    (Self.order.firstIndex(of: lhs.contrast) ?? 99)
                        < (Self.order.firstIndex(of: rhs.contrast) ?? 99)
                }
            seed = w
            groups = grouped
            searched = true
            isBusy = false
            history.record(tool: "Minimal Pairs", query: w, count: pairs.count)
        }
    }
}

/// A wrapping row of tappable word chips, each showing the phoneme swap.
private struct FlowChips: View {
    let pairs: [MinimalPairFinder.Neighbor]
    let onTap: (MinimalPairFinder.Neighbor) -> Void
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(pairs, id: \.word) { p in
                Button { onTap(p) } label: {
                    HStack(spacing: 5) {
                        Text(p.word).font(.system(.body, design: .rounded))
                        Text("\(p.from.lowercased())→\(p.to.lowercased())")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Image(systemName: "speaker.wave.1")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Minimal wrapping layout — chips flow left to right, wrapping to new rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var x: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, !(rows[rows.count - 1].isEmpty) {
                rows.append([]); x = 0
            }
            rows[rows.count - 1].append(s); x += s.width + spacing
        }
        let height = rows.reduce(CGFloat(0)) { acc, row in
            acc + (row.map(\.height).max() ?? 0) + spacing
        } - spacing
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
