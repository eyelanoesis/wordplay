import SwiftUI
import UniformTypeIdentifiers
import AnagramEngine

// MARK: - Dimension tints on paper

extension ConnectionWeb.Relation {
    var color: Color {
        switch self {
        case .anagram: return Color(red: 0.95, green: 0.60, blue: 0.10)
        case .oneLetter: return Color(red: 0.25, green: 0.50, blue: 0.95)
        case .homophone: return Color(red: 0.60, green: 0.35, blue: 0.90)
        case .rhyme: return Color(red: 0.90, green: 0.30, blue: 0.45)
        case .fusion: return Color(red: 0.15, green: 0.70, blue: 0.45)
        case .hidden: return Color(red: 0.75, green: 0.60, blue: 0.10)
        case .audible: return Color(red: 0.15, green: 0.65, blue: 0.75)
        case .reversal: return Color(red: 0.40, green: 0.42, blue: 0.55)
        case .association: return Color(red: 0.80, green: 0.25, blue: 0.72)
        }
    }

    var notation: String {
        switch self {
        case .anagram: return "letter permutation"
        case .oneLetter: return "single-letter mutation"
        case .homophone: return "identical phonetics"
        case .rhyme: return "rhyme bond"
        case .fusion: return "phonetic fusion"
        case .hidden: return "substring"
        case .audible: return "audible substring"
        case .reversal: return "mirror word"
        case .association: return "semantic association"
        }
    }

    /// A full sentence for tooltips: what this dimension actually means.
    var explanation: String {
        switch self {
        case .anagram:
            return "both words use exactly the same letters, rearranged (silent / listen)"
        case .oneLetter:
            return "changing, adding, or dropping one letter turns one word into the other (word → ward)"
        case .homophone:
            return "spelled differently but pronounced exactly the same (pair / pear)"
        case .rhyme:
            return "the words share their final sounds, from the last stressed vowel on (moon / June)"
        case .fusion:
            return "the words overlap by sound and fuse into one audible pseudo-word (brain ⋈ angel → brangel)"
        case .hidden:
            return "one word is spelled, letter for letter, inside the other (ear inside heart)"
        case .audible:
            return "one word can be heard inside the other's pronunciation, whatever the spelling (cane inside hurricane)"
        case .reversal:
            return "one word is the other spelled backwards (stressed / desserts)"
        case .association:
            return "the words keep close company in meaning — neighbors in an on-device semantic map, no network involved (harbor / wharf)"
        }
    }
}

// MARK: - Shared Web-tab settings

/// The seven dimensions as a persisted on/off set, plus the auto-write cadence.
/// Both pages (codex and crossword) read the same @AppStorage keys, so the
/// choices carry across the toggle and across launches.
enum WebDimensions {
    static let allRaw = ConnectionWeb.Relation.allCases.map(\.rawValue).joined(separator: ",")

    static func parse(_ raw: String) -> Set<ConnectionWeb.Relation> {
        Set(raw.split(separator: ",").compactMap { ConnectionWeb.Relation(rawValue: String($0)) })
    }

    static func encode(_ set: Set<ConnectionWeb.Relation>) -> String {
        ConnectionWeb.Relation.allCases.filter(set.contains).map(\.rawValue).joined(separator: ",")
    }

    static let cadences: [Double] = [1, 2, 3, 5, 10, 30]

    static func cadenceLabel(_ s: Double) -> String {
        s == 1 ? "every second" : "every \(Int(s)) seconds"
    }

    /// Complexity: how many connections each dimension may contribute when a
    /// word is grown by hand. Self-writing uses roughly half.
    static let complexities: [(Int, String)] =
        [(1, "sparse — one per dimension"), (2, "modest — two"),
         (4, "rich — four"), (6, "lush — six")]

    static func autoCount(for perRelation: Int) -> Int {
        max(1, perRelation - 2)
    }

    /// Frontier ink: unopened, clickable words — the doors not yet walked
    /// through. Verdigris against the parchment.
    static let frontier = Color(red: 0.13, green: 0.42, blue: 0.38)
}

// MARK: - Trackpad zoom (pinch + two-finger scroll)

/// Catches pinch and scroll events over the page without stealing clicks from
/// the canvas beneath. Uses a local event monitor, so SwiftUI's own gestures
/// (drag-to-pan, click-to-grow) keep working; events over real scroll views
/// (the log panel) are left alone.
struct ZoomCatcher: NSViewRepresentable {
    var onZoom: (CGFloat, CGPoint) -> Void   // (factor, cursor in view coords)

    final class Catcher: NSView {
        var onZoom: ((CGFloat, CGPoint) -> Void)?
        private var monitor: Any?

        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }  // never block clicks

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            // Tear the monitor down when leaving the window (deinit cannot,
            // under strict concurrency).
            if newWindow == nil, let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard monitor == nil, window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) {
                [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                let p = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(p) else { return event }
                // Leave real scroll views (the log panel) to their own scrolling.
                if let hit = window.contentView?.hitTest(event.locationInWindow) {
                    var v: NSView? = hit
                    while let cur = v {
                        if cur is NSScrollView { return event }
                        v = cur.superview
                    }
                }
                switch event.type {
                case .magnify:
                    self.onZoom?(1 + event.magnification, p)
                    return nil
                case .scrollWheel:
                    let dy = event.scrollingDeltaY
                    guard abs(dy) > 0.01 else { return event }
                    self.onZoom?(exp(dy * (event.hasPreciseScrollingDeltas ? 0.004 : 0.02)), p)
                    return nil
                default:
                    return event
                }
            }
        }

    }

    func makeNSView(context: Context) -> Catcher {
        let v = Catcher()
        v.onZoom = onZoom
        return v
    }

    func updateNSView(_ v: Catcher, context: Context) { v.onZoom = onZoom }
}

struct Cell: Hashable {
    var x: Int, y: Int
}

// MARK: - The living crossword

/// Words laid on an endless letter grid, crossing at shared letters. The
/// crossing cell is tinted by the dimension that links the two words. The
/// puzzle writes itself outward — a crossword, metastasizing.
@MainActor
final class CrosswordModel: ObservableObject {
    struct Placed: Identifiable {
        let id: String                          // the word
        let letters: [Character]
        var relation: ConnectionWeb.Relation?   // how it joined (nil = seed)
        var detail: String
        var start: Cell
        var horizontal: Bool
        var born: Date
        var expanded = false
        var viral = false

        func cell(_ i: Int) -> Cell {
            horizontal ? Cell(x: start.x + i, y: start.y) : Cell(x: start.x, y: start.y + i)
        }
    }

    @Published private(set) var revision = 0
    @Published var status: String?
    @Published var isBusy = false
    @Published private(set) var log: [String] = []
    @Published var autoSpread = false

    private(set) var placed: [Placed] = []
    private(set) var letters: [Cell: Character] = [:]
    private(set) var crossings: [Cell: ConnectionWeb.Relation] = [:]  // tinted cells
    private(set) var owners: [Cell: [Int]] = [:]                      // cell → placed indices
    var current: String?
    var hovered: String?
    var lastSpread = Date.distantPast
    let maxWords = 120

    // Camera: pan offset in points; the grid is infinite. Zoom scales the page.
    var camera = CGPoint.zero
    var zoom: CGFloat = 1

    private var wordIndex: [String: Int] = [:]

    var isFull: Bool { placed.count >= maxWords }
    func entry(for word: String) -> Placed? { wordIndex[word].map { placed[$0] } }

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    func record(_ line: String) {
        log.append("[\(Self.clock.string(from: Date()))] \(line)")
        if log.count > 200 { log.removeFirst(log.count - 200) }
    }

    func clear() {
        placed = []; letters = [:]; crossings = [:]; owners = [:]
        wordIndex = [:]; current = nil; hovered = nil
        status = nil; log = []; camera = .zero; zoom = 1
        revision += 1
    }

    func seed(_ word: String, now: Date) {
        clear()
        let chars = Array(word)
        let entry = Placed(id: word, letters: chars, relation: nil, detail: "seed word",
                           start: Cell(x: -chars.count / 2, y: 0), horizontal: true, born: now)
        commit(entry)
        current = word
        revision += 1
    }

    /// Try to weave `word` into the grid crossing `host` at a shared letter.
    @discardableResult
    func weave(_ word: String, crossing host: String,
               relation: ConnectionWeb.Relation, detail: String,
               viral: Bool, now: Date) -> Bool {
        guard wordIndex[word] == nil, !isFull,
              let hostIdx = wordIndex[host] else { return false }
        let hostEntry = placed[hostIdx]
        let chars = Array(word)

        // Middle-out over host letters, so the grid grows balanced.
        let hostOrder = hostEntry.letters.indices.sorted {
            abs($0 - hostEntry.letters.count / 2) < abs($1 - hostEntry.letters.count / 2)
        }
        for i in hostOrder {
            let hostLetter = hostEntry.letters[i]
            let crossCell = hostEntry.cell(i)
            for j in chars.indices where chars[j] == hostLetter {
                let horizontal = !hostEntry.horizontal
                let start = horizontal
                    ? Cell(x: crossCell.x - j, y: crossCell.y)
                    : Cell(x: crossCell.x, y: crossCell.y - j)
                var candidate = Placed(id: word, letters: chars, relation: relation,
                                       detail: detail, start: start,
                                       horizontal: horizontal, born: now)
                candidate.viral = viral
                if fits(candidate) {
                    commit(candidate)
                    crossings[crossCell] = relation
                    revision += 1
                    return true
                }
            }
        }
        return false
    }

    private func fits(_ candidate: Placed) -> Bool {
        var newCells = 0
        for (k, ch) in candidate.letters.enumerated() {
            let c = candidate.cell(k)
            if let existing = letters[c] {
                if existing != ch { return false }        // letter conflict
            } else {
                newCells += 1
                // Don't butt up against a parallel neighbor (crossword hygiene):
                // a fresh cell may not sit flush beside an occupied cell.
                let sides = candidate.horizontal
                    ? [Cell(x: c.x, y: c.y - 1), Cell(x: c.x, y: c.y + 1)]
                    : [Cell(x: c.x - 1, y: c.y), Cell(x: c.x + 1, y: c.y)]
                for side in sides where letters[side] != nil { return false }
            }
        }
        // Must add something, and the ends must not extend another word.
        guard newCells > 0 else { return false }
        let before = candidate.horizontal
            ? Cell(x: candidate.start.x - 1, y: candidate.start.y)
            : Cell(x: candidate.start.x, y: candidate.start.y - 1)
        let afterIdx = candidate.letters.count
        let after = candidate.horizontal
            ? Cell(x: candidate.start.x + afterIdx, y: candidate.start.y)
            : Cell(x: candidate.start.x, y: candidate.start.y + afterIdx)
        return letters[before] == nil && letters[after] == nil
    }

    private func commit(_ entry: Placed) {
        let idx = placed.count
        placed.append(entry)
        wordIndex[entry.id] = idx
        for (k, ch) in entry.letters.enumerated() {
            let c = entry.cell(k)
            letters[c] = ch
            owners[c, default: []].append(idx)
        }
    }

    func markExpanded(_ word: String) {
        if let i = wordIndex[word] { placed[i].expanded = true }
        current = word
        revision += 1
    }

    func word(at cell: Cell) -> String? {
        owners[cell].flatMap { $0.last.map { placed[$0].id } }
    }
}

// MARK: - The view

/// The Web tool: three ways of seeing the same web. The codex (sigil circles
/// on parchment) is the default; the crossword and the orrery (3D) are
/// toggles. The codex and the orrery share one model — the same inscriptions,
/// seen flat or in the round.
struct WebExplorerView: View {
    @AppStorage("webPageMode") private var mode = "sigil"
    @StateObject private var codexModel = SigilModel()

    var body: some View {
        ZStack {
            switch mode {
            case "crossword": CrosswordPageView()
            case "orrery": OrreryPageView(model: codexModel)
            default: SigilPageView(model: codexModel)
            }
        }
        .overlay(alignment: .topTrailing) {
            Picker("", selection: $mode) {
                Image(systemName: "seal").tag("sigil")
                    .help("The codex: sigil circles on parchment.")
                Image(systemName: "squareshape.split.3x3").tag("crossword")
                    .help("The crossword: the same web as a self-writing crossword grid.")
                Image(systemName: "globe").tag("orrery")
                    .help("The orrery: the codex's own inscriptions in 3D — drag to orbit, scroll or pinch to dolly, ⌥-drag to pan.")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 130)
            .padding(.top, 14).padding(.trailing, 270)
        }
        .onAppear {
            if codexModel.words.isEmpty {
                let restored = codexModel.restore()
                if restored > 0 {
                    codexModel.record("the codex remembers: \(restored) inscriptions restored.")
                }
            }
        }
    }
}

/// The crossword page: words laid on an endless grid, crossing at shared
/// letters, tinted by the dimension that binds them.
struct CrosswordPageView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore
    @StateObject private var model = CrosswordModel()

    @State private var word = ""
    @State private var toWord = ""
    @AppStorage("web7.soundOn") private var soundOn = false
    @AppStorage("web7.dims") private var relationsOnRaw = ""
    @AppStorage("web7.spreadSeconds") private var spreadSeconds = 3.0
    @AppStorage("web7.autoWrite") private var autoWrite = false
    @AppStorage("web7.glyphs") private var glyphsOn = false
    @AppStorage("web7.perRelation") private var perRelation = 1
    @State private var showLog = true
    @State private var panning = false
    @State private var lastDrag = CGSize.zero
    @State private var canvasSize = CGSize(width: 800, height: 500)

    private let cellSize: CGFloat = 34

    private let paper = Color(red: 0.965, green: 0.955, blue: 0.93)
    private let inkDark = Color(red: 0.13, green: 0.12, blue: 0.11)

    private var relationsOn: Set<ConnectionWeb.Relation> { WebDimensions.parse(relationsOnRaw) }

    private func relationBinding(_ r: ConnectionWeb.Relation) -> Binding<Bool> {
        Binding(
            get: { WebDimensions.parse(relationsOnRaw).contains(r) },
            set: { on in
                var s = WebDimensions.parse(relationsOnRaw)
                if on { s.insert(r) } else { s.remove(r) }
                relationsOnRaw = WebDimensions.encode(s)
            })
    }

    var body: some View {
        ZStack {
            page
            VStack {
                hud
                Spacer()
                legend
            }
            .padding(12)
        }
        .overlay(alignment: .trailing) {
            if showLog { logPanel.padding(.vertical, 76).padding(.trailing, 12) }
        }
        .environment(\.colorScheme, .light)
        .onAppear {
            store.loadPhonetics()
            ChimeEngine.shared.muted = !soundOn
            model.autoSpread = autoWrite
        }
        .task { await spreadLoop() }
    }

    // MARK: Growth

    private func spreadLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
            guard model.autoSpread, !model.isBusy, !model.isFull, store.isReady,
                  !model.placed.isEmpty, !relationsOn.isEmpty,
                  Date().timeIntervalSince(model.lastSpread) >= max(1, spreadSeconds),
                  let host = model.placed.filter({ !$0.expanded }).randomElement()
            else { continue }
            model.lastSpread = Date()
            expand(host.id, auto: true)
        }
    }

    private func expand(_ target: String, auto: Bool = false) {
        guard !model.isBusy, let cryptic = store.cryptic, let ladder = store.ladder else { return }
        let relations = relationsOn
        guard !relations.isEmpty else {
            model.status = "all dimensions are off — switch some on in the ☰ menu or click the legend below"
            return
        }
        model.isBusy = true
        let count = auto ? WebDimensions.autoCount(for: perRelation) : perRelation
        let wordsList = store.wordList
        let assoc: @Sendable (String, Int) -> [String] = { w, n in
            SemanticNeighbors.shared.neighbors(of: w, count: n, within: wordsList)
        }
        Task {
            let fusion = await store.fusionFinder()
            let phonetics = store.phonetics
            let found = await Task.detached(priority: auto ? .utility : .userInitiated) {
                ConnectionWeb(cryptic: cryptic, ladder: ladder, phonetics: phonetics,
                              fusion: fusion, words: wordsList, associations: assoc)
                    .connections(of: target, perRelation: count, relations: relations)
            }.value
            var woven = 0
            for connection in found {
                if model.weave(connection.word, crossing: target,
                               relation: connection.relation, detail: connection.detail,
                               viral: auto, now: Date()) {
                    woven += 1
                }
            }
            model.markExpanded(target)
            if woven > 0 {
                model.record(auto
                    ? "!! \(target) grew · +\(woven) words"
                    : "\(target): wove \(woven) of \(found.count) connections")
                if auto {
                    ChimeEngine.shared.playInfection()
                } else {
                    ChimeEngine.shared.play(model.entry(for: target)?.relation)
                }
            } else {
                model.record("\(target): no room to weave")
            }
            model.isBusy = false
            if !auto { history.record(tool: "Web", query: target, count: woven) }
        }
    }

    private func seed() {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !w.isEmpty, store.isReady else { return }
        model.seed(w, now: Date())
        model.record("\(w): laid across the page.")
        ChimeEngine.shared.play(nil)
        expand(w)
    }

    private func findPath() {
        let a = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let b = toWordTrimmed
        guard !a.isEmpty, !b.isEmpty, !model.isBusy,
              let cryptic = store.cryptic, let ladder = store.ladder else { return }
        model.isBusy = true
        model.status = "searching for a way from \(a) to \(b)…"
        Task {
            let fusion = await store.fusionFinder()
            let phonetics = store.phonetics
            let steps = await Task.detached(priority: .userInitiated) {
                PathFinder(cryptic: cryptic, ladder: ladder, phonetics: phonetics, fusion: fusion)
                    .path(from: a, to: b)
            }.value
            guard let steps, steps.count > 1 else {
                model.status = steps == nil
                    ? "no path found within search bounds"
                    : "same word twice — nothing to weave"
                model.isBusy = false
                return
            }
            model.seed(steps[0].word, now: Date())
            model.record("path \(a) ⇢ \(b): weaving.")
            ChimeEngine.shared.play(nil)
            var prev = steps[0].word
            var broken = false
            for step in steps.dropFirst() {
                try? await Task.sleep(for: .milliseconds(450))
                let ok = model.weave(step.word, crossing: prev,
                                     relation: step.relation ?? .rhyme, detail: step.detail,
                                     viral: false, now: Date())
                if ok {
                    model.record("\(prev) ⨯ \(step.word) · \((step.relation ?? .rhyme).notation)")
                    ChimeEngine.shared.play(step.relation)
                    model.markExpanded(step.word)
                } else {
                    model.record("\(step.word): no legal crossing — chain breaks here")
                    broken = true
                    break
                }
                prev = step.word
            }
            model.status = broken
                ? "the chain could not be fully woven — some links share no letters"
                : "path woven: \(a) ⇢ \(b), \(steps.count - 1) crossings"
            model.isBusy = false
            history.record(tool: "Web", query: "\(a) → \(b)", count: steps.count)
        }
    }

    // MARK: HUD

    private var toWordTrimmed: String {
        toWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func go() {
        if toWordTrimmed.isEmpty { seed() } else { findPath() }
    }

    private var hud: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TextField("a word…", text: $word)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 150)
                    .onSubmit { go() }
                    .help("The seed word: it is laid across the grid and its connections are woven around it. Press ⏎ to start.")
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                TextField("…cross to (optional)", text: $toWord)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 140)
                    .onSubmit { go() }
                    .help("Optional destination. With both fields filled, the app finds a six-degrees chain from the first word to this one and weaves it step by step. Path-finding always searches all seven dimensions, even ones you have switched off.")
                Button(toWordTrimmed.isEmpty ? "Lay it down" : "Weave path") { go() }
                    .buttonStyle(.borderedProminent).tint(inkDark)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!store.isReady || model.isBusy)
                    .help(toWordTrimmed.isEmpty
                        ? "Start a new puzzle from the seed word (⌘⏎)."
                        : "Find and weave the chain between the two words (⌘⏎).")
                if model.isBusy || store.phoneticsLoading { ProgressView().controlSize(.small) }
                Divider().frame(height: 16)
                Text(model.isFull
                     ? "page full — clear to begin again"
                     : "\(model.placed.count) words woven")
                    .font(.caption).foregroundStyle(.secondary)
                    .help("How many words are on the grid. The page holds \(model.maxWords) at most.")
                Menu {
                    ForEach(ConnectionWeb.Relation.allCases) { r in
                        Toggle(isOn: relationBinding(r)) {
                            Text(glyphsOn ? "\(r.glyph)  \(r.rawValue)" : r.rawValue)
                        }
                    }
                    Divider()
                    Button("All dimensions on") { relationsOnRaw = WebDimensions.allRaw }
                    Button("All dimensions off") { relationsOnRaw = "" }
                    Divider()
                    Picker("complexity", selection: $perRelation) {
                        ForEach(WebDimensions.complexities, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Toggle(isOn: $glyphsOn) { Text("planetary glyphs (☉ ☽ ☿ ♀ ♂ ♃ ♄ ♅ ♆)") }
                } label: { Image(systemName: "slider.horizontal.3") }
                    .controlSize(.small)
                    .fixedSize()
                    .help("The nine dimensions: check which kinds of connection may weave new words (all off by default; what is on the grid stays). Also here: complexity — how many connections each dimension contributes per word — and the glyphs.")
                Menu {
                    Picker("cadence", selection: $spreadSeconds) {
                        ForEach(WebDimensions.cadences, id: \.self) { s in
                            Text(WebDimensions.cadenceLabel(s)).tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: { Image(systemName: "timer") }
                    .controlSize(.small)
                    .fixedSize()
                    .help("How many seconds between the puzzle's own moves while self-writing plays. Clicking a word grows it immediately.")
                Button {
                    autoWrite.toggle()
                    model.autoSpread = autoWrite
                } label: {
                    Image(systemName: autoWrite ? "pause.fill" : "play.fill")
                }
                    .controlSize(.small)
                    .tint(autoWrite ? Color(red: 0.85, green: 0.25, blue: 0.25) : nil)
                    .help("Play / pause the self-writing (off by default). While playing, the puzzle picks an unexpanded word at the chosen cadence and weaves its connections, shown in red. Paused, you still grow words by clicking them.")
                Button {
                    soundOn.toggle()
                    ChimeEngine.shared.muted = !soundOn
                } label: { Image(systemName: soundOn ? "speaker.wave.2" : "speaker.slash") }
                    .controlSize(.small)
                    .help("Sound on / off (off by default): a pentatonic note per dimension as words are woven; self-growth plays a low detuned interval.")
                Menu {
                    Toggle(isOn: $showLog) { Text("show the weave log") }
                    Divider()
                    Button("Export page as PNG…") { exportPNG() }
                        .disabled(model.placed.isEmpty)
                    Button("Clear the grid") { model.clear() }
                        .disabled(model.placed.isEmpty)
                } label: { Image(systemName: "ellipsis.circle") }
                    .controlSize(.small)
                    .fixedSize()
                    .help("More: the weave log, PNG export, and clearing the grid (the crossword is not saved between launches).")
                Spacer()
            }
            if let status = model.status {
                Text(status).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(inkDark.opacity(0.2), lineWidth: 1))
        .frame(maxWidth: 820, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(ConnectionWeb.Relation.allCases) { r in
                let on = relationsOn.contains(r)
                Button { relationBinding(r).wrappedValue = !on } label: {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(r.color.opacity(on ? 0.55 : 0.15))
                            .frame(width: 10, height: 10)
                        Text(r.rawValue).font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(on ? .secondary : .tertiary)
                            .strikethrough(!on, color: .secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("\(r.rawValue): \(r.explanation). Click to toggle whether this kind of connection may be woven (struck through = off).")
            }
            Spacer()
            Text("green = unexplored, click to grow · red = grew on its own · drag pans · scroll zooms")
                .font(.system(.caption2, design: .monospaced)).foregroundStyle(.tertiary)
                .help("The ink is the map: verdigris-green words are the unexplored frontier (click one to weave its connections), dark words are already grown, red words were added by the puzzle itself. Drag to pan, pinch or two-finger scroll to zoom, hover for why a word is connected.")
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(paper.opacity(0.9), in: Capsule())
        .overlay(Capsule().stroke(inkDark.opacity(0.15), lineWidth: 1))
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("weave.log")
                .font(.system(.callout, design: .monospaced).bold())
                .foregroundStyle(inkDark)
            Divider()
            if model.log.isEmpty {
                Text("> awaiting first word_")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(model.log.enumerated()), id: \.offset) { i, line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(line.contains("!!")
                                        ? Color(red: 0.8, green: 0.2, blue: 0.2)
                                        : inkDark.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .id(i)
                            }
                        }
                    }
                    .onChange(of: model.log.count) { _, n in
                        withAnimation { proxy.scrollTo(n - 1, anchor: .bottom) }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 250)
        .frame(maxHeight: 520, alignment: .top)
        .background(paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(inkDark.opacity(0.2), lineWidth: 1))
    }

    // MARK: The page

    private var page: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    drawPage(ctx, size: size, now: timeline.date)
                }
            }
            .onChange(of: geo.size, initial: true) { _, s in canvasSize = s }
            .gesture(pointer)
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): model.hovered = model.word(at: cellAt(p))
                case .ended: model.hovered = nil
                }
            }
            .overlay(ZoomCatcher(onZoom: applyZoom))
        }
        .background(paper)
        .ignoresSafeArea(edges: .bottom)
    }

    private func origin(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + model.camera.x, y: size.height / 2 + model.camera.y)
    }

    /// A cell's rectangle in world coordinates (pre-zoom).
    private func worldRect(of cell: Cell) -> CGRect {
        CGRect(x: CGFloat(cell.x) * cellSize, y: CGFloat(cell.y) * cellSize,
               width: cellSize, height: cellSize)
    }

    private func cellAt(_ point: CGPoint) -> Cell {
        let o = origin(in: canvasSize)
        let z = model.zoom
        return Cell(x: Int(floor((point.x - o.x) / z / cellSize)),
                    y: Int(floor((point.y - o.y) / z / cellSize)))
    }

    /// Zoom about the cursor: the world point under the pointer stays put.
    private func applyZoom(_ factor: CGFloat, at p: CGPoint) {
        let old = model.zoom
        let new = min(4, max(0.25, old * factor))
        guard new != old else { return }
        let o = origin(in: canvasSize)
        let world = CGPoint(x: (p.x - o.x) / old, y: (p.y - o.y) / old)
        model.zoom = new
        model.camera.x = p.x - canvasSize.width / 2 - world.x * new
        model.camera.y = p.y - canvasSize.height / 2 - world.y * new
    }

    private func drawPage(_ ctx: GraphicsContext, size: CGSize, now: Date) {
        let o = origin(in: size)
        let z = model.zoom
        var w = ctx
        w.translateBy(x: o.x, y: o.y)
        w.scaleBy(x: z, y: z)
        let viewport = CGRect(x: -o.x / z, y: -o.y / z,
                              width: size.width / z, height: size.height / z)

        // Faint ruled grid across the visible page.
        var grid = Path()
        var gx = (viewport.minX / cellSize).rounded(.down) * cellSize
        while gx < viewport.maxX {
            grid.move(to: CGPoint(x: gx, y: viewport.minY))
            grid.addLine(to: CGPoint(x: gx, y: viewport.maxY))
            gx += cellSize
        }
        var gy = (viewport.minY / cellSize).rounded(.down) * cellSize
        while gy < viewport.maxY {
            grid.move(to: CGPoint(x: viewport.minX, y: gy))
            grid.addLine(to: CGPoint(x: viewport.maxX, y: gy))
            gy += cellSize
        }
        w.stroke(grid, with: .color(inkDark.opacity(0.045)), lineWidth: 1 / z)

        guard !model.placed.isEmpty else {
            ctx.draw(
                Text(store.isReady
                     ? "type a word — then grow it, or press play to let it write itself"
                     : "loading dictionary…")
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(inkDark.opacity(0.35)),
                at: CGPoint(x: size.width / 2, y: size.height / 2))
            return
        }

        let t = now.timeIntervalSinceReferenceDate

        for entry in model.placed {
            let grown = 1 - pow(1 - min(now.timeIntervalSince(entry.born) / 0.4, 1), 3)
            let isCurrent = entry.id == model.current
            let isHovered = entry.id == model.hovered
            for (k, ch) in entry.letters.enumerated() {
                let cell = entry.cell(k)
                let r = worldRect(of: cell).insetBy(dx: 1.2, dy: 1.2)
                guard r.intersects(viewport) else { continue }

                let fill: Color
                if let crossTint = model.crossings[cell] {
                    fill = crossTint.color.opacity(0.30)
                } else if entry.viral {
                    fill = Color(red: 0.95, green: 0.35, blue: 0.30).opacity(0.10)
                } else {
                    fill = .white
                }
                let box = Path(roundedRect: r, cornerRadius: 4)
                w.fill(box, with: .color(fill.opacity(Double(grown))))
                let border: Color = isCurrent
                    ? inkDark
                    : (isHovered ? inkDark.opacity(0.7) : inkDark.opacity(0.22))
                w.stroke(box, with: .color(border.opacity(Double(grown))),
                         lineWidth: isCurrent ? 1.8 : 1)

                let pulse = isCurrent ? 0.75 + 0.25 * (1 + sin(t * 2.2)) / 2 : 1.0
                // Navigation ink: red = self-written, verdigris = unopened
                // frontier (click to grow), dark ink = already explored.
                let letterColor: Color
                if entry.viral {
                    letterColor = Color(red: 0.72, green: 0.15, blue: 0.12)
                } else if !entry.expanded && entry.relation != nil {
                    letterColor = WebDimensions.frontier
                } else {
                    letterColor = inkDark
                }
                w.draw(
                    Text(String(ch).uppercased())
                        .font(.system(size: cellSize * 0.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(letterColor.opacity(Double(grown) * pulse)),
                    at: CGPoint(x: r.midX, y: r.midY))
            }
        }

        drawHoverCard(ctx, size: size)
    }

    private func drawHoverCard(_ ctx: GraphicsContext, size: CGSize) {
        guard let id = model.hovered, !panning,
              let entry = model.entry(for: id), !entry.detail.isEmpty else { return }
        var caption = entry.detail
        if let relation = entry.relation {
            caption = "\(relation.rawValue) — \(relation.explanation)\n" + caption
        }
        if let phones = store.phonetics?.pronunciations(of: id).first {
            caption += "\n/\(phones.joined(separator: " "))/"
        }
        caption += entry.viral
            ? "\nwoven by the puzzle itself · click to grow it"
            : "\nclick to grow its connections"
        let text = Text(caption).font(.system(.caption, design: .monospaced))
            .foregroundStyle(inkDark.opacity(0.9))
        let resolved = ctx.resolve(text)
        let measured = resolved.measure(in: CGSize(width: 420, height: 120))
        let o = origin(in: size)
        let wr = worldRect(of: entry.cell(0))
        let anchor = CGRect(x: o.x + wr.minX * model.zoom, y: o.y + wr.minY * model.zoom,
                            width: wr.width * model.zoom, height: wr.height * model.zoom)
        var cardOrigin = CGPoint(x: anchor.minX, y: anchor.minY - measured.height - 16)
        cardOrigin.x = min(max(cardOrigin.x, 8), size.width - measured.width - 8)
        if cardOrigin.y < 8 { cardOrigin.y = anchor.maxY + 12 }
        let card = CGRect(x: cardOrigin.x - 8, y: cardOrigin.y - 5,
                          width: measured.width + 16, height: measured.height + 10)
        ctx.fill(Path(roundedRect: card, cornerRadius: 6), with: .color(.white.opacity(0.97)))
        ctx.stroke(Path(roundedRect: card, cornerRadius: 6),
                   with: .color((entry.relation?.color ?? inkDark).opacity(0.55)), lineWidth: 1)
        ctx.draw(resolved, in: CGRect(origin: cardOrigin, size: measured))
    }

    // MARK: Interaction — tap grows a word, drag pans the page

    private var pointer: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let delta = CGSize(width: value.translation.width - lastDrag.width,
                                   height: value.translation.height - lastDrag.height)
                lastDrag = value.translation
                if hypot(value.translation.width, value.translation.height) > 6 {
                    panning = true
                    model.camera.x += delta.width
                    model.camera.y += delta.height
                }
            }
            .onEnded { value in
                defer { panning = false; lastDrag = .zero }
                guard hypot(value.translation.width, value.translation.height) <= 6 else { return }
                if let hit = model.word(at: cellAt(value.location)) {
                    expand(hit)
                }
            }
    }

    /// Snapshot the visible page to a retina PNG.
    private func exportPNG() {
        let size = canvasSize
        let now = Date()
        let content = Canvas { ctx, sz in
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(paper))
            drawPage(ctx, size: sz, now: now)
        }
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let tiff = renderer.nsImage?.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            model.status = "couldn't render the page"
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "crossword-\(model.current ?? "web").png"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try png.write(to: url)
                model.status = "saved \(url.lastPathComponent)"
            } catch {
                model.status = "couldn't save: \(error.localizedDescription)"
            }
        }
    }
}
