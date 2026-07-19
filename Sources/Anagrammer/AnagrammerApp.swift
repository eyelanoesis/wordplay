import SwiftUI

@main
struct AnagrammerApp: App {
    @StateObject private var store = WordStore()
    @StateObject private var history = HistoryStore()
    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup("Wordplay") {
            RootView()
                .environmentObject(store)
                .environmentObject(history)
                .environmentObject(favorites)
                .onAppear { store.loadIfNeeded() }
                .frame(minWidth: 860, minHeight: 580)
        }
    }
}

enum Tool: String, CaseIterable, Identifiable {
    case anagrams = "Anagrams"
    case rack = "Rack Solver"
    case pattern = "Crossword"
    case ladder = "Word Ladder"
    case cryptic = "Cryptic"
    case rhymes = "Rhymes & Sounds"
    case fusions = "Fusions"
    case web = "Web"
    case favorites = "Favorites"
    case history = "History"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .anagrams: return "arrow.triangle.2.circlepath"
        case .rack: return "square.grid.3x3.fill"
        case .pattern: return "rectangle.grid.1x2"
        case .ladder: return "arrow.up.arrow.down"
        case .cryptic: return "questionmark.diamond"
        case .rhymes: return "waveform"
        case .fusions: return "arrow.triangle.merge"
        case .web: return "point.3.connected.trianglepath.dotted"
        case .favorites: return "star"
        case .history: return "clock.arrow.circlepath"
        }
    }

    static var toolsSection: [Tool] { [.anagrams, .rack, .pattern, .ladder, .cryptic, .rhymes, .fusions, .web] }
    static var librarySection: [Tool] { [.favorites, .history] }
}

struct RootView: View {
    @EnvironmentObject var store: WordStore
    @State private var selection: Tool = .anagrams

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Tools") {
                    ForEach(Tool.toolsSection) { tool in
                        Label(tool.rawValue, systemImage: tool.icon).tag(tool)
                    }
                }
                Section("Library") {
                    ForEach(Tool.librarySection) { tool in
                        Label(tool.rawValue, systemImage: tool.icon).tag(tool)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
            .safeAreaInset(edge: .bottom) { dictionaryFooter }
        } detail: {
            detail
        }
    }

    private var dictionaryFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Picker("Dictionary", selection: Binding(
                get: { store.selected },
                set: { store.select($0) }
            )) {
                ForEach(DictionaryChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            Text(store.status).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            Text("Wordplay v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(8)
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .anagrams: gated { AnagramsView() }
        case .rack: gated { RackView() }
        case .pattern: gated { PatternView() }
        case .ladder: gated { LadderView() }
        case .cryptic: gated { CrypticView() }
        case .rhymes: gated { RhymesView() }
        case .fusions: gated { FusionView() }
        case .web: gated { WebExplorerView() }
        case .favorites: FavoritesView()
        case .history: HistoryView()
        }
    }

    /// Wraps dictionary-backed tools so they disable + show a spinner while loading.
    @ViewBuilder private func gated<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .disabled(!store.isReady)
            .overlay { if !store.isReady { ProgressView("Loading dictionary…") } }
    }
}
