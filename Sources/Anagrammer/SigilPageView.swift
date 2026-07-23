import SwiftUI
import UniformTypeIdentifiers
import AnagramEngine

// MARK: - The seven planetary glyphs

/// The seven dimensions as the seven classical planets — the alchemist's
/// seven metals. Every connection bears its planet's mark.
extension ConnectionWeb.Relation {
    var glyph: String {
        switch self {
        case .anagram: return "☉"     // Sol — gold: the same matter, transmuted
        case .oneLetter: return "☽"   // Luna — silver: waxing, waning by one
        case .homophone: return "☿"   // Mercury — the twin-tongued messenger
        case .rhyme: return "♀"       // Venus — harmony of endings
        case .fusion: return "♂"      // Mars — two forged into one
        case .hidden: return "♄"      // Saturn — lead, buried within
        case .audible: return "♃"     // Jupiter — the voice within the voice
        case .reversal: return "♆"    // Neptune — the mirror sea (a modern)
        case .association: return "♅" // Uranus — the electric kinship (a modern)
        }
    }
}

// MARK: - The codex model

/// Sigil circles chained across parchment. Each expanded word is the center of
/// a construction circle; its connections are inscribed around the rim. The
/// codex writes itself onward.
@MainActor
final class SigilModel: ObservableObject {
    struct SWord: Identifiable, Codable {
        let id: String
        var relation: ConnectionWeb.Relation?
        var detail: String
        var pos: CGPoint            // world coordinates
        var outDir: CGVector        // direction this word faces, away from its ring
        var generation: Int
        var born: Date
        var expanded = false
        var viral = false
        var circleCenter: CGPoint?  // set once expanded
        var circleRadius: CGFloat = 0
        var expandedAt: Date?       // when its circle was drawn
        var dying: Date?            // fading out; reaped when the ink is gone
        var parent: String? = nil   // the word whose circle this one sits on
    }

    @Published private(set) var revision = 0
    @Published var status: String?
    @Published var isBusy = false
    @Published private(set) var log: [String] = []
    @Published var autoSpread = false

    private(set) var words: [SWord] = []
    var current: String?
    var hovered: String?
    var lastSpread = Date.distantPast
    var camera = CGPoint.zero
    var zoom: CGFloat = 1
    var cameraTarget: CGPoint?      // the codex pulls the eye toward new ink
    var lastInteraction = Date.distantPast
    let maxWords = 110

    private var index: [String: Int] = [:]

    var isFull: Bool { words.count >= maxWords }
    func entry(for word: String) -> SWord? { index[word].map { words[$0] } }

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    func record(_ line: String) {
        log.append("[\(Self.clock.string(from: Date()))] \(line)")
        if log.count > 200 { log.removeFirst(log.count - 200) }
    }

    func clear() {
        words = []; index = [:]
        current = nil; hovered = nil; status = nil; log = []
        camera = .zero; zoom = 1
        revision += 1
        saveSoon()
    }

    func seed(_ word: String, now: Date) {
        clear()
        words.append(SWord(id: word, relation: nil, detail: "the first inscription",
                           pos: .zero, outDir: CGVector(dx: 0, dy: -1),
                           generation: 0, born: now))
        index[word] = 0
        current = word
        revision += 1
    }

    /// Inscribe `found` around a new circle grown from `word`.
    func inscribe(from word: String, with found: [ConnectionWeb.Node],
                  viral: Bool, now: Date) -> Int {
        guard let i = index[word] else { return 0 }
        let host = words[i]
        let radius = max(68, 118 * pow(0.92, CGFloat(host.generation)))
        // The seed's circle is centered on itself; later circles grow outward
        // from the host's position on its parent ring, so the circles chain.
        let center = host.generation == 0
            ? host.pos
            : CGPoint(x: host.pos.x + host.outDir.dx * radius * 0.9,
                      y: host.pos.y + host.outDir.dy * radius * 0.9)

        let fresh = found.filter { index[$0.word] == nil }
        guard !fresh.isEmpty else {
            words[i].expanded = true
            current = word
            revision += 1
            return 0
        }
        let outAngle = host.generation == 0
            ? -CGFloat.pi / 2
            : atan2(host.outDir.dy, host.outDir.dx)
        let spread: CGFloat = host.generation == 0 ? 2 * .pi : 4.4  // radians
        var placedCount = 0
        for (k, connection) in fresh.enumerated() {
            guard !isFull else { break }
            let n = CGFloat(fresh.count)
            let angle = host.generation == 0
                ? outAngle + spread * CGFloat(k) / n
                : outAngle - spread / 2 + spread * (n == 1 ? 0.5 : CGFloat(k) / (n - 1))
            let pos = CGPoint(x: center.x + cos(angle) * radius,
                              y: center.y + sin(angle) * radius)
            var member = SWord(id: connection.word, relation: connection.relation,
                               detail: connection.detail, pos: pos,
                               outDir: CGVector(dx: cos(angle), dy: sin(angle)),
                               generation: host.generation + 1, born: now)
            member.viral = viral
            member.parent = word
            index[connection.word] = words.count
            words.append(member)
            placedCount += 1
        }
        words[i].expanded = true
        words[i].circleCenter = center
        words[i].circleRadius = radius
        if words[i].expandedAt == nil { words[i].expandedAt = now }
        current = word
        revision += 1
        saveSoon()
        return placedCount
    }

    /// Choose the oldest unopened inscription and let its ink begin to fade.
    func beginDecay(now: Date) -> String? {
        let candidates = words.filter {
            !$0.expanded && $0.dying == nil && $0.generation > 0 && $0.id != current
        }
        guard let victim = candidates.min(by: { $0.born < $1.born }) else { return nil }
        if let i = words.firstIndex(where: { $0.id == victim.id }) {
            words[i].dying = now
            return victim.id
        }
        return nil
    }

    /// Remove inscriptions whose ink has fully faded.
    func reap(now: Date) {
        let before = words.count
        words.removeAll { w in
            if let dying = w.dying { return now.timeIntervalSince(dying) > 1.8 }
            return false
        }
        guard words.count != before else { return }
        index = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1.id, $0) })
        revision += 1
        saveSoon()
    }

    // MARK: The codex remembers — persistence across launches

    private struct Snapshot: Codable {
        var words: [SWord]
        var cameraX: CGFloat
        var cameraY: CGFloat
        var zoom: CGFloat?
        var current: String?
        var log: [String]
    }

    private static var archiveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
            .appendingPathComponent("Wordplay", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("codex.json")
    }

    private var saveGeneration = 0

    /// Debounced save: many changes, one write.
    func saveSoon() {
        saveGeneration += 1
        let generation = saveGeneration
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.saveGeneration == generation else { return }
            let snapshot = Snapshot(words: self.words,
                                    cameraX: self.camera.x, cameraY: self.camera.y,
                                    zoom: self.zoom,
                                    current: self.current,
                                    log: Array(self.log.suffix(40)))
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: Self.archiveURL, options: .atomic)
            }
        }
    }

    /// Reopen the codex where it was left. Returns the number of inscriptions.
    func restore() -> Int {
        guard let data = try? Data(contentsOf: Self.archiveURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              !snapshot.words.isEmpty else { return 0 }
        words = snapshot.words.filter { $0.dying == nil }
        index = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1.id, $0) })
        camera = CGPoint(x: snapshot.cameraX, y: snapshot.cameraY)
        zoom = snapshot.zoom ?? 1
        current = snapshot.current
        log = snapshot.log
        revision += 1
        return words.count
    }

    func nearestWord(to worldPoint: CGPoint, within reach: CGFloat) -> String? {
        var best: (String, CGFloat)?
        for w in words {
            let d = hypot(w.pos.x - worldPoint.x, w.pos.y - worldPoint.y)
            if d < reach, d < (best?.1 ?? .infinity) { best = (w.id, d) }
        }
        return best?.0
    }
}

// MARK: - The codex page

/// Aged parchment; sigil circles in wobbling sepia ink; curved script around
/// the rims; planetary glyphs for the seven dimensions; mirror-written margin
/// notes. The codex inscribes itself while you watch.
struct SigilPageView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore
    @ObservedObject var model: SigilModel

    @State private var word = ""
    @State private var toWord = ""
    @AppStorage("web7.soundOn") private var soundOn = false
    @AppStorage("web7.dims") private var relationsOnRaw = ""
    @AppStorage("web7.spreadSeconds") private var spreadSeconds = 3.0
    @AppStorage("web7.autoWrite") private var autoWrite = false
    @AppStorage("web7.voiceOn") private var voiceOn = false
    @AppStorage("web7.glyphs") private var glyphsOn = false
    @AppStorage("web7.perRelation") private var perRelation = 1
    @State private var showLog = true
    @State private var panning = false
    @State private var lastDrag = CGSize.zero
    @State private var canvasSize = CGSize(width: 800, height: 500)

    private let parchment = Color(red: 0.91, green: 0.86, blue: 0.74)
    private let ink = Color(red: 0.32, green: 0.22, blue: 0.12)       // sepia
    private let ochre = Color(red: 0.62, green: 0.18, blue: 0.10)     // red ochre

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
            if showLog { codexPanel.padding(.vertical, 76).padding(.trailing, 12) }
        }
        .environment(\.colorScheme, .light)
        .onAppear {
            store.loadPhonetics()
            ChimeEngine.shared.muted = !soundOn
            ChimeEngine.shared.voiceEnabled = voiceOn
            model.autoSpread = autoWrite
        }
        .task { await spreadLoop() }
    }

    // MARK: Growth

    private func spreadLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let now = Date()
            model.reap(now: now)
            // When the page grows crowded, the oldest unopened ink fades —
            // the codex forgets so it may keep writing. Evolution, not archive.
            if model.autoSpread, model.words.count > 88,
               let victim = model.beginDecay(now: now) {
                model.record("∴ \(victim) fades from the page")
                ChimeEngine.shared.play(rawFrequency: 130.8, amplitude: 0.06)
            }
            guard model.autoSpread, !model.isBusy, !model.isFull, store.isReady,
                  !model.words.isEmpty, !relationsOn.isEmpty,
                  now.timeIntervalSince(model.lastSpread) >= max(1, spreadSeconds) else { continue }
            // Mostly open new circles; sometimes return to an old one and
            // deepen it with connections missed the first time.
            let unopened = model.words.filter { !$0.expanded && $0.dying == nil }
            let opened = model.words.filter { $0.expanded }
            let host: SigilModel.SWord?
            if let deepen = opened.randomElement(), Int.random(in: 0..<4) == 0 {
                host = deepen
            } else {
                host = unopened.randomElement() ?? opened.randomElement()
            }
            guard let host else { continue }
            model.lastSpread = now
            expand(host.id, auto: true)
        }
    }

    private func expand(_ target: String, auto: Bool = false) {
        guard !model.isBusy, let cryptic = store.cryptic, let ladder = store.ladder else { return }
        let relations = relationsOn
        guard !relations.isEmpty else {
            model.status = "all dimensions are set aside — switch some on in the ☰ menu or touch the legend below"
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
            let placed = model.inscribe(from: target, with: found, viral: auto, now: Date())
            if auto, placed > 0, let c = model.entry(for: target)?.circleCenter {
                model.cameraTarget = CGPoint(x: -c.x, y: -c.y)
            }
            if placed > 0 {
                if !auto { ChimeEngine.shared.speak(target) }
                model.record(auto
                    ? "✦ the codex inscribed \(target) · +\(placed)"
                    : "\(target): \(placed) inscriptions")
                if auto {
                    ChimeEngine.shared.playInfection()
                } else {
                    ChimeEngine.shared.play(model.entry(for: target)?.relation)
                }
            } else {
                model.record("\(target): nothing new under this sun")
            }
            model.isBusy = false
            if !auto { history.record(tool: "Web", query: target, count: placed) }
        }
    }

    private func seed() {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !w.isEmpty, store.isReady else { return }
        model.seed(w, now: Date())
        model.record("\(w): set at the center of the first circle.")
        ChimeEngine.shared.play(nil)
        expand(w)
    }

    private func findPath() {
        let a = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let b = toWordTrimmed
        guard !a.isEmpty, !b.isEmpty, !model.isBusy,
              let cryptic = store.cryptic, let ladder = store.ladder else { return }
        model.isBusy = true
        model.status = "divining a way from \(a) to \(b)…"
        Task {
            let fusion = await store.fusionFinder()
            let phonetics = store.phonetics
            let steps = await Task.detached(priority: .userInitiated) {
                PathFinder(cryptic: cryptic, ladder: ladder, phonetics: phonetics, fusion: fusion)
                    .path(from: a, to: b)
            }.value
            guard let steps, steps.count > 1 else {
                model.status = steps == nil
                    ? "the way is hidden — no path within reach"
                    : "one and the same word"
                model.isBusy = false
                return
            }
            model.seed(steps[0].word, now: Date())
            model.record("the way \(a) ⇢ \(b): begun.")
            ChimeEngine.shared.play(nil)
            var prev = steps[0].word
            for step in steps.dropFirst() {
                try? await Task.sleep(for: .milliseconds(500))
                let node = ConnectionWeb.Node(word: step.word,
                                              relation: step.relation ?? .rhyme,
                                              detail: step.detail)
                _ = model.inscribe(from: prev, with: [node], viral: false, now: Date())
                model.record("\(prev) → \(step.word) \((step.relation ?? .rhyme).glyph)")
                ChimeEngine.shared.play(step.relation)
                ChimeEngine.shared.speak(step.word)
                prev = step.word
            }
            model.record("the way is complete: \(steps.count - 1) turns of the compass.")
            model.status = "the way is drawn — touch any word to open its circle"
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
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: 150)
                    .onSubmit { go() }
                    .help("The word to set at the center of a fresh page. The codex will study it and inscribe its connections around it. Press ⏎ to begin.")
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                TextField("…the way to (optional)", text: $toWord)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: 150)
                    .onSubmit { go() }
                    .help("Optional destination. With both fields filled, the codex divines a six-degrees chain from the first word to this one and inscribes it step by step. The divination always searches all seven dimensions, even ones you have set aside.")
                Button(toWordTrimmed.isEmpty ? "Inscribe" : "Divine the way") { go() }
                    .buttonStyle(.borderedProminent).tint(ink)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!store.isReady || model.isBusy)
                    .help(toWordTrimmed.isEmpty
                        ? "Begin a new page from this word (⌘⏎)."
                        : "Find and inscribe the chain between the two words (⌘⏎).")
                if model.isBusy || store.phoneticsLoading { ProgressView().controlSize(.small) }
                Divider().frame(height: 16)
                Text(model.isFull
                     ? "the page is full — clear to turn a new leaf"
                     : "\(model.words.count) inscriptions")
                    .font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
                    .help("How many words are inscribed. The page holds \(model.maxWords) at most; near capacity the oldest unopened ink fades so the codex can keep writing.")
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
                    .help("The nine dimensions: check which kinds of connection may be drawn (all off by default; ink already on the page stays). Also here: complexity — how many connections each dimension contributes per circle — and the glyphs.")
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
                    .help("How many seconds between the codex's own inscriptions while self-writing plays. Opening a circle by hand is always immediate.")
                Button {
                    autoWrite.toggle()
                    model.autoSpread = autoWrite
                } label: {
                    Image(systemName: autoWrite ? "pause.fill" : "play.fill")
                }
                    .controlSize(.small)
                    .tint(autoWrite ? ochre : nil)
                    .help("Play / pause the self-writing (off by default). While playing, the codex opens or deepens a circle on its own at the chosen cadence — ✦ in the log, red ochre on the page. Paused, you still open circles by clicking words.")
                Button {
                    soundOn.toggle()
                    ChimeEngine.shared.muted = !soundOn
                } label: { Image(systemName: soundOn ? "speaker.wave.2" : "speaker.slash") }
                    .controlSize(.small)
                    .help("Sound on / off (off by default). When on: a pentatonic note per dimension as words are inscribed, a low detuned interval for self-growth, and the voice if enabled.")
                Menu {
                    Toggle(isOn: Binding(
                        get: { voiceOn },
                        set: { on in
                            voiceOn = on
                            ChimeEngine.shared.voiceEnabled = on
                            if on, let w = model.current { ChimeEngine.shared.speak(w) }
                        })) { Text("voice — speak each word as its circle opens") }
                    Toggle(isOn: $showLog) { Text("show the codex's log") }
                    Divider()
                    Button("Export page as PNG…") { exportPNG() }
                        .disabled(model.words.isEmpty)
                    Button("Clear the page") { model.clear() }
                        .disabled(model.words.isEmpty)
                } label: { Image(systemName: "ellipsis.circle") }
                    .controlSize(.small)
                    .fixedSize()
                    .help("More: the spoken voice, the log panel, PNG export, and clearing the page (which also clears what is saved between launches).")
                Spacer()
            }
            if let status = model.status {
                Text(status)
                    .font(.system(.caption, design: .serif)).italic()
                    .foregroundStyle(ink.opacity(0.7))
            }
        }
        .padding(10)
        .background(parchment.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ink.opacity(0.3), lineWidth: 1))
        .frame(maxWidth: 840, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legend: some View {
        HStack(spacing: 13) {
            ForEach(ConnectionWeb.Relation.allCases) { r in
                let on = relationsOn.contains(r)
                Button { relationBinding(r).wrappedValue = !on } label: {
                    HStack(spacing: 4) {
                        if glyphsOn {
                            Text(r.glyph).font(.system(size: 12))
                                .foregroundStyle(r.color.opacity(on ? 0.85 : 0.25))
                        } else {
                            Circle().fill(r.color.opacity(on ? 0.7 : 0.2))
                                .frame(width: 8, height: 8)
                        }
                        Text(r.rawValue)
                            .font(.system(.caption2, design: .serif))
                            .foregroundStyle(ink.opacity(on ? 0.6 : 0.3))
                            .strikethrough(!on, color: ink.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
                .help("\(r.rawValue): \(r.explanation). Click to toggle whether this kind of connection may be drawn (struck through = off).")
            }
            Spacer()
            Text("green ink = unopened doors · ochre = the codex's own hand · drag wanders · scroll zooms")
                .font(.system(.caption2, design: .serif).italic())
                .foregroundStyle(ink.opacity(0.45))
                .help("The ink is the map: verdigris-green words are unopened doors (touch one to open its circle), sepia words are already opened, red ochre words were written by the codex itself. Drag to wander, pinch or two-finger scroll to zoom, hover for why a word is connected.")
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(parchment.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(ink.opacity(0.25), lineWidth: 1))
    }

    private var codexPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("the codex")
                .font(.system(.callout, design: .serif).bold().italic())
                .foregroundStyle(ink)
            Divider().overlay(ink.opacity(0.4))
            if model.log.isEmpty {
                Text("the page is blank, and waiting.")
                    .font(.system(.caption, design: .serif)).italic()
                    .foregroundStyle(ink.opacity(0.5))
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(model.log.enumerated()), id: \.offset) { i, line in
                                Text(line)
                                    .font(.system(.caption, design: .serif))
                                    .foregroundStyle(line.contains("✦")
                                        ? ochre.opacity(0.9)
                                        : ink.opacity(0.7))
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
        .background(parchment.opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ink.opacity(0.3), lineWidth: 1))
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
                case .active(let p):
                    model.hovered = model.nearestWord(to: world(p), within: 34 / model.zoom)
                case .ended: model.hovered = nil
                }
            }
            .overlay(ZoomCatcher(onZoom: applyZoom))
        }
        .background(parchment)
        .ignoresSafeArea(edges: .bottom)
    }

    private func origin(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + model.camera.x, y: size.height / 2 + model.camera.y)
    }

    private func screen(_ p: CGPoint, in size: CGSize) -> CGPoint {
        let o = origin(in: size)
        return CGPoint(x: o.x + p.x * model.zoom, y: o.y + p.y * model.zoom)
    }

    private func world(_ p: CGPoint) -> CGPoint {
        let o = origin(in: canvasSize)
        return CGPoint(x: (p.x - o.x) / model.zoom, y: (p.y - o.y) / model.zoom)
    }

    /// Zoom about the cursor: the inscription under the pointer stays put.
    private func applyZoom(_ factor: CGFloat, at p: CGPoint) {
        let old = model.zoom
        let new = min(4, max(0.25, old * factor))
        guard new != old else { return }
        let o = origin(in: canvasSize)
        let worldP = CGPoint(x: (p.x - o.x) / old, y: (p.y - o.y) / old)
        model.zoom = new
        model.camera.x = p.x - canvasSize.width / 2 - worldP.x * new
        model.camera.y = p.y - canvasSize.height / 2 - worldP.y * new
        model.lastInteraction = Date()
        model.cameraTarget = nil
        model.saveSoon()
    }

    /// Slow hand-tremor: everything on the page breathes, barely.
    private func drift(_ p: CGPoint, seed: Int, t: TimeInterval) -> CGPoint {
        let s = Double(seed & 1023)
        return CGPoint(x: p.x + CGFloat(sin(t * 0.07 + s) * 1.4),
                       y: p.y + CGFloat(cos(t * 0.055 + s * 1.7) * 1.4))
    }

    private func drawPage(_ ctx: GraphicsContext, size: CGSize, now: Date) {
        // The eye follows the pen, unless your hand is on the page.
        if let target = model.cameraTarget,
           now.timeIntervalSince(model.lastInteraction) > 8 {
            model.camera.x += (target.x - model.camera.x) * 0.03
            model.camera.y += (target.y - model.camera.y) * 0.03
            if hypot(target.x - model.camera.x, target.y - model.camera.y) < 5 {
                model.cameraTarget = nil
            }
        }
        drawParchment(ctx, size: size)

        // Everything inscribed lives in world coordinates; one transformed
        // context applies pan + zoom to ink, script, and glyphs alike.
        let o = origin(in: size)
        let z = model.zoom
        var w = ctx
        w.translateBy(x: o.x, y: o.y)
        w.scaleBy(x: z, y: z)
        let viewport = CGRect(x: -o.x / z, y: -o.y / z,
                              width: size.width / z, height: size.height / z)

        drawVitruvian(w)

        guard !model.words.isEmpty else {
            ctx.draw(
                Text(store.isReady
                     ? "speak a word, and the codex will study it"
                     : "the codex is being bound…")
                    .font(.system(.title3, design: .serif).italic())
                    .foregroundStyle(ink.opacity(0.45)),
                at: CGPoint(x: size.width / 2, y: size.height / 2))
            return
        }

        let t = now.timeIntervalSinceReferenceDate

        // Circles and spokes first, then the script on top.
        for entry in model.words where entry.expanded && entry.circleCenter != nil {
            drawCircle(w, entry: entry, viewport: viewport, t: t)
        }
        for entry in model.words {
            drawWord(w, entry: entry, viewport: viewport, now: now, t: t)
        }
        drawHoverCard(ctx, size: size)
    }

    private func drawParchment(_ ctx: GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 0.93, green: 0.885, blue: 0.775),
                                      Color(red: 0.85, green: 0.78, blue: 0.63)]),
                    center: CGPoint(x: size.width / 2, y: size.height * 0.45),
                    startRadius: 0, endRadius: max(size.width, size.height) * 0.8))
        // Stains and foxing.
        var rng: UInt64 = 0x0DE1CA7EDC0DEB00
        for _ in 0..<14 {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let x = Double(rng >> 40 % 1000) / 1000 * size.width
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let y = Double(rng >> 40 % 1000) / 1000 * size.height
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let r = 26.0 + Double(rng >> 40 % 90)
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(Color(red: 0.55, green: 0.42, blue: 0.22).opacity(0.028)))
        }
    }

    /// The construction behind everything: circle, square, diagonals — faint,
    /// as if the page began as a study of proportion. Drawn in world space.
    private func drawVitruvian(_ ctx: GraphicsContext) {
        let c = CGPoint.zero
        let R: CGFloat = 275
        let faint = ink.opacity(0.07)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)),
                   with: .color(faint), lineWidth: 1)
        let s = R * 0.885
        ctx.stroke(Path(CGRect(x: c.x - s, y: c.y - s, width: s * 2, height: s * 2)),
                   with: .color(faint), lineWidth: 1)
        var diag = Path()
        diag.move(to: CGPoint(x: c.x - s, y: c.y - s)); diag.addLine(to: CGPoint(x: c.x + s, y: c.y + s))
        diag.move(to: CGPoint(x: c.x + s, y: c.y - s)); diag.addLine(to: CGPoint(x: c.x - s, y: c.y + s))
        ctx.stroke(diag, with: .color(ink.opacity(0.045)), lineWidth: 1)
    }

    /// A hand-drawn circle: a polyline with seeded radial wobble.
    private func wobbledCircle(center: CGPoint, radius: CGFloat, seed: Int) -> Path {
        var path = Path()
        var h = UInt64(bitPattern: Int64(seed)) &* 0x9E3779B97F4A7C15
        var first = CGPoint.zero
        for k in 0...48 {
            let a = CGFloat(k) / 48 * 2 * .pi
            h = h &* 6364136223846793005 &+ 1442695040888963407
            let wobble = CGFloat(Int64(h >> 40 % 300) - 150) / 100  // ±1.5
            let r = radius + wobble
            let p = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if k == 0 { path.move(to: p); first = p } else { path.addLine(to: p) }
        }
        path.addLine(to: first)
        return path
    }

    private func drawCircle(_ ctx: GraphicsContext, entry: SigilModel.SWord,
                            viewport: CGRect, t: TimeInterval) {
        guard let centerW = entry.circleCenter else { return }
        let c = drift(centerW, seed: entry.id.hashValue, t: t)
        let r = entry.circleRadius
        guard viewport.insetBy(dx: -r, dy: -r).contains(c) else { return }
        // Fresh circles are wet ink; old ones pale into the parchment.
        let circleAge = entry.expandedAt.map { Date().timeIntervalSince($0) } ?? 0
        let aged = 1 - 0.5 * min(circleAge / 150, 1)
        let seed = entry.id.hashValue
        ctx.stroke(wobbledCircle(center: c, radius: r, seed: seed),
                   with: .color(ink.opacity(0.42 * aged + 0.08)), lineWidth: 1.1)
        ctx.stroke(wobbledCircle(center: c, radius: r - 5, seed: seed &+ 1),
                   with: .color(ink.opacity(0.20 * aged + 0.04)), lineWidth: 0.8)
        // The active circle turns, slowly, dashed — the compass still moving.
        if entry.id == model.current {
            var dashed = Path(ellipseIn: CGRect(x: c.x - r - 9, y: c.y - r - 9,
                                                width: (r + 9) * 2, height: (r + 9) * 2))
            dashed = dashed.strokedPath(StrokeStyle(lineWidth: 0.9, dash: [3, 7],
                                                    dashPhase: CGFloat(t * 14)))
            ctx.fill(dashed, with: .color(ochre.opacity(0.5)))
        }
        // Spokes to the rim words.
        for member in model.words where member.generation == entry.generation + 1 {
            let d = hypot(member.pos.x - centerW.x, member.pos.y - centerW.y)
            guard abs(d - r) < 2 else { continue }
            var spoke = Path()
            spoke.move(to: c)
            spoke.addLine(to: drift(member.pos, seed: member.id.hashValue, t: t))
            ctx.stroke(spoke, with: .color(ink.opacity(0.14 * aged + 0.03)), lineWidth: 0.7)
        }
        // Mirror-written margin note, the way the master kept his own counsel.
        if !entry.detail.isEmpty, entry.generation > 0 {
            var mirror = ctx
            let notePos = CGPoint(x: c.x, y: c.y + r + 14)
            mirror.translateBy(x: notePos.x, y: notePos.y)
            mirror.scaleBy(x: -1, y: 1)
            mirror.rotate(by: .degrees(-3))
            mirror.draw(
                Text(entry.detail)
                    .font(.system(size: 9, design: .serif).italic())
                    .foregroundStyle(ink.opacity(0.28)),
                at: .zero)
        }
    }

    private func drawWord(_ ctx: GraphicsContext, entry: SigilModel.SWord,
                          viewport: CGRect, now: Date, t: TimeInterval) {
        let p = drift(entry.pos, seed: entry.id.hashValue, t: t)
        guard viewport.insetBy(dx: -80, dy: -40).contains(p) else { return }
        let grown = 1 - pow(1 - min(now.timeIntervalSince(entry.born) / 0.5, 1), 3)
        let isCurrent = entry.id == model.current
        let isHovered = entry.id == model.hovered
        // Ink ages; dying ink fades to nothing before it is reaped.
        let aged = 1 - 0.4 * min(now.timeIntervalSince(entry.born) / 150, 1)
        var alpha = Double(grown) * aged * (isCurrent || isHovered ? 1.0 : 0.82)
        if let dying = entry.dying {
            alpha *= max(0, 1 - now.timeIntervalSince(dying) / 1.8)
        }

        if entry.generation == 0 {
            // The seed: large, centered, the word under study.
            ctx.draw(
                Text(entry.id)
                    .font(.system(size: 26, design: .serif).weight(.semibold).smallCaps())
                    .foregroundStyle(ink.opacity(alpha)),
                at: p)
            return
        }

        // Rim script: written along the tangent of its ring.
        let angle = atan2(entry.outDir.dy, entry.outDir.dx)
        var layer = ctx
        layer.translateBy(x: p.x, y: p.y)
        // Keep script upright-ish: flip when on the left half of the circle.
        let upsideDown = cos(angle) < 0
        layer.rotate(by: .radians(angle + (upsideDown ? .pi : 0)))
        // Navigation ink: ochre = self-written, verdigris = unopened frontier
        // (touch to open), sepia = already opened.
        let scriptColor: Color
        if entry.viral {
            scriptColor = ochre
        } else if !entry.expanded && entry.dying == nil {
            scriptColor = WebDimensions.frontier
        } else {
            scriptColor = ink
        }
        let script = Text(entry.id)
            .font(.system(size: isCurrent ? 15 : 13, design: .serif)
                .weight(isCurrent ? .semibold : .regular).italic())
            .foregroundStyle(scriptColor.opacity(alpha))
        layer.draw(script, at: CGPoint(x: upsideDown ? -26 : 26, y: 0),
                   anchor: upsideDown ? .trailing : .leading)

        // Its dimension's mark at the rim: the planet glyph, or a plain dot.
        if let relation = entry.relation {
            let mark = CGPoint(x: p.x - entry.outDir.dx * 12, y: p.y - entry.outDir.dy * 12)
            if glyphsOn {
                ctx.draw(
                    Text(relation.glyph)
                        .font(.system(size: 13))
                        .foregroundStyle(relation.color.opacity(0.9 * alpha)),
                    at: mark)
            } else {
                ctx.fill(Path(ellipseIn: CGRect(x: mark.x - 2.5, y: mark.y - 2.5,
                                                width: 5, height: 5)),
                         with: .color(relation.color.opacity(0.75 * alpha)))
            }
        }
    }

    private func drawHoverCard(_ ctx: GraphicsContext, size: CGSize) {
        guard let id = model.hovered, !panning,
              let entry = model.entry(for: id), !entry.detail.isEmpty else { return }
        var caption = entry.detail
        if let relation = entry.relation {
            let mark = glyphsOn ? "\(relation.glyph) " : ""
            caption = "\(mark)\(relation.rawValue) — \(relation.explanation)\n" + caption
        }
        if let parent = entry.parent {
            caption += model.entry(for: parent) == nil
                ? "\njoined through \(parent), whose ink has since faded"
                : "\njoined through \(parent)"
        }
        if let phones = store.phonetics?.pronunciations(of: id).first {
            caption += "\n/\(phones.joined(separator: " "))/"
        }
        caption += entry.viral
            ? "\ninscribed by the codex itself · click to open its circle"
            : "\nclick to open its circle"
        let text = Text(caption)
            .font(.system(.caption, design: .serif))
            .foregroundStyle(ink.opacity(0.9))
        let resolved = ctx.resolve(text)
        let measured = resolved.measure(in: CGSize(width: 420, height: 120))
        let anchor = screen(entry.pos, in: size)
        var cardOrigin = CGPoint(x: anchor.x - measured.width / 2,
                                 y: anchor.y - measured.height - 24)
        cardOrigin.x = min(max(cardOrigin.x, 8), size.width - measured.width - 8)
        if cardOrigin.y < 8 { cardOrigin.y = anchor.y + 20 }
        let card = CGRect(x: cardOrigin.x - 8, y: cardOrigin.y - 5,
                          width: measured.width + 16, height: measured.height + 10)
        ctx.fill(Path(roundedRect: card, cornerRadius: 6),
                 with: .color(Color(red: 0.95, green: 0.92, blue: 0.83).opacity(0.97)))
        ctx.stroke(Path(roundedRect: card, cornerRadius: 6),
                   with: .color(ink.opacity(0.5)), lineWidth: 1)
        ctx.draw(resolved, in: CGRect(origin: cardOrigin, size: measured))
    }

    // MARK: Interaction

    private var pointer: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let delta = CGSize(width: value.translation.width - lastDrag.width,
                                   height: value.translation.height - lastDrag.height)
                lastDrag = value.translation
                if hypot(value.translation.width, value.translation.height) > 6 {
                    panning = true
                    model.lastInteraction = Date()
                    model.cameraTarget = nil
                    model.camera.x += delta.width
                    model.camera.y += delta.height
                }
            }
            .onEnded { value in
                defer { panning = false; lastDrag = .zero }
                model.lastInteraction = Date()
                guard hypot(value.translation.width, value.translation.height) <= 6 else { return }
                if let hit = model.nearestWord(to: world(value.location), within: 34) {
                    expand(hit)
                }
            }
    }

    private func exportPNG() {
        let size = canvasSize
        let now = Date()
        let content = Canvas { ctx, sz in
            drawPage(ctx, size: sz, now: now)
        }
        .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let tiff = renderer.nsImage?.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            model.status = "the page would not be captured"
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "codex-\(model.current ?? "page").png"
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
