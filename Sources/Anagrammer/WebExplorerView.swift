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
        }
    }
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
    @Published var autoSpread = true

    private(set) var placed: [Placed] = []
    private(set) var letters: [Cell: Character] = [:]
    private(set) var crossings: [Cell: ConnectionWeb.Relation] = [:]  // tinted cells
    private(set) var owners: [Cell: [Int]] = [:]                      // cell → placed indices
    var current: String?
    var hovered: String?
    var lastSpread = Date.distantPast
    let maxWords = 120

    // Camera: pan offset in points; the grid is infinite.
    var camera = CGPoint.zero

    private var wordIndex: [String: Int] = [:]

    var isFull: Bool { placed.count >= maxWords }
    func entry(for word: String) -> Placed? { wordIndex[word].map { placed[$0] } }

    private static let clock: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    func record(_ line: String) {
        log.append("[\(Self.clock.string(from: Date()))] \(line)")
    }

    func clear() {
        placed = []; letters = [:]; crossings = [:]; owners = [:]
        wordIndex = [:]; current = nil; hovered = nil
        status = nil; log = []; camera = .zero
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

/// The Web tool: two ways of seeing the same web. The codex (sigil circles on
/// parchment) is the default; this crossword page is the toggle.
struct WebExplorerView: View {
    @AppStorage("webPageMode") private var mode = "sigil"

    var body: some View {
        ZStack {
            if mode == "sigil" { SigilPageView() } else { CrosswordPageView() }
        }
        .overlay(alignment: .topTrailing) {
            Picker("", selection: $mode) {
                Image(systemName: "seal").tag("sigil").help("the codex")
                Image(systemName: "squareshape.split.3x3").tag("crossword").help("the crossword")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 90)
            .padding(.top, 14).padding(.trailing, 270)
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
    @State private var muted = false
    @State private var showLog = true
    @State private var panning = false
    @State private var lastDrag = CGSize.zero
    @State private var canvasSize = CGSize(width: 800, height: 500)

    private let cellSize: CGFloat = 34

    private let paper = Color(red: 0.965, green: 0.955, blue: 0.93)
    private let inkDark = Color(red: 0.13, green: 0.12, blue: 0.11)

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
        .onAppear { store.loadPhonetics() }
        .task { await spreadLoop() }
    }

    // MARK: Growth

    private func spreadLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard model.autoSpread, !model.isBusy, !model.isFull, store.isReady,
                  !model.placed.isEmpty,
                  Date().timeIntervalSince(model.lastSpread) > 2.8,
                  let host = model.placed.filter({ !$0.expanded }).randomElement()
            else { continue }
            model.lastSpread = Date()
            expand(host.id, auto: true)
        }
    }

    private func expand(_ target: String, auto: Bool = false) {
        guard !model.isBusy, let cryptic = store.cryptic, let ladder = store.ladder else { return }
        model.isBusy = true
        Task {
            let fusion = await store.fusionFinder()
            let phonetics = store.phonetics
            let found = await Task.detached(priority: auto ? .utility : .userInitiated) {
                ConnectionWeb(cryptic: cryptic, ladder: ladder, phonetics: phonetics, fusion: fusion)
                    .connections(of: target, perRelation: auto ? 3 : 6)
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
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
                TextField("…cross to (optional)", text: $toWord)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 140)
                    .onSubmit { go() }
                Button(toWordTrimmed.isEmpty ? "Lay it down" : "Weave path") { go() }
                    .buttonStyle(.borderedProminent).tint(inkDark)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!store.isReady || model.isBusy)
                if model.isBusy || store.phoneticsLoading { ProgressView().controlSize(.small) }
                Divider().frame(height: 16)
                Text(model.isFull
                     ? "page full — clear to begin again"
                     : "\(model.placed.count) words woven")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Clear") { model.clear() }
                    .controlSize(.small)
                    .disabled(model.placed.isEmpty)
                Button { model.autoSpread.toggle() } label: {
                    Image(systemName: model.autoSpread ? "allergens.fill" : "allergens")
                }
                    .controlSize(.small)
                    .tint(model.autoSpread ? Color(red: 0.85, green: 0.25, blue: 0.25) : nil)
                    .help(model.autoSpread ? "the puzzle is writing itself — click to pause" : "let it write itself")
                Button {
                    muted.toggle()
                    ChimeEngine.shared.muted = muted
                } label: { Image(systemName: muted ? "speaker.slash" : "speaker.wave.2") }
                    .controlSize(.small)
                Button { exportPNG() } label: { Image(systemName: "camera") }
                    .controlSize(.small)
                    .disabled(model.placed.isEmpty)
                Button { showLog.toggle() } label: {
                    Image(systemName: showLog ? "text.append" : "text.justify.left")
                }
                    .controlSize(.small)
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
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(r.color.opacity(0.55))
                        .frame(width: 10, height: 10)
                    Text(r.rawValue).font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("click a word to grow it · drag to pan · red words grew on their own")
                .font(.system(.caption2, design: .monospaced)).foregroundStyle(.tertiary)
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
            TimelineView(.animation) { timeline in
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
        }
        .background(paper)
        .ignoresSafeArea(edges: .bottom)
    }

    private func origin(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + model.camera.x, y: size.height / 2 + model.camera.y)
    }

    private func rect(of cell: Cell, in size: CGSize) -> CGRect {
        let o = origin(in: size)
        return CGRect(x: o.x + CGFloat(cell.x) * cellSize,
                      y: o.y + CGFloat(cell.y) * cellSize,
                      width: cellSize, height: cellSize)
    }

    private func cellAt(_ point: CGPoint) -> Cell {
        let o = origin(in: canvasSize)
        return Cell(x: Int(floor((point.x - o.x) / cellSize)),
                    y: Int(floor((point.y - o.y) / cellSize)))
    }

    private func drawPage(_ ctx: GraphicsContext, size: CGSize, now: Date) {
        // Faint ruled grid across the whole page.
        var grid = Path()
        let o = origin(in: size)
        var gx = o.x.truncatingRemainder(dividingBy: cellSize)
        while gx < size.width {
            grid.move(to: CGPoint(x: gx, y: 0)); grid.addLine(to: CGPoint(x: gx, y: size.height))
            gx += cellSize
        }
        var gy = o.y.truncatingRemainder(dividingBy: cellSize)
        while gy < size.height {
            grid.move(to: CGPoint(x: 0, y: gy)); grid.addLine(to: CGPoint(x: size.width, y: gy))
            gy += cellSize
        }
        ctx.stroke(grid, with: .color(inkDark.opacity(0.045)), lineWidth: 1)

        guard !model.placed.isEmpty else {
            ctx.draw(
                Text(store.isReady
                     ? "type a word — the crossword writes itself"
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
                let r = rect(of: cell, in: size).insetBy(dx: 1.2, dy: 1.2)
                guard r.maxX > 0, r.minX < size.width, r.maxY > 0, r.minY < size.height else { continue }

                let fill: Color
                if let crossTint = model.crossings[cell] {
                    fill = crossTint.color.opacity(0.30)
                } else if entry.viral {
                    fill = Color(red: 0.95, green: 0.35, blue: 0.30).opacity(0.10)
                } else {
                    fill = .white
                }
                let box = Path(roundedRect: r, cornerRadius: 4)
                ctx.fill(box, with: .color(fill.opacity(Double(grown))))
                let border: Color = isCurrent
                    ? inkDark
                    : (isHovered ? inkDark.opacity(0.7) : inkDark.opacity(0.22))
                ctx.stroke(box, with: .color(border.opacity(Double(grown))),
                           lineWidth: isCurrent ? 1.8 : 1)

                let pulse = isCurrent ? 0.75 + 0.25 * (1 + sin(t * 2.2)) / 2 : 1.0
                let letterColor = entry.viral
                    ? Color(red: 0.72, green: 0.15, blue: 0.12)
                    : inkDark
                ctx.draw(
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
        if let phones = store.phonetics?.pronunciations(of: id).first {
            caption += "\n/\(phones.joined(separator: " "))/"
        }
        let text = Text(caption).font(.system(.caption, design: .monospaced))
            .foregroundStyle(inkDark.opacity(0.9))
        let resolved = ctx.resolve(text)
        let measured = resolved.measure(in: CGSize(width: 360, height: 80))
        let anchor = rect(of: entry.cell(0), in: size)
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
