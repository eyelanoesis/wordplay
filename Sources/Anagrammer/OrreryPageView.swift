import SwiftUI
import simd
import AnagramEngine

// MARK: - The orrery: the codex in the round

/// The same inscriptions as the codex, lifted into three dimensions — words as
/// bodies in an armillary sphere, chained outward from the seed at the center.
/// Navigated like a 3D modelling app: drag to orbit, scroll or pinch to dolly,
/// ⌥-drag to pan. Shares the codex's model, so both pages show one web.
struct OrreryPageView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore
    @ObservedObject var model: SigilModel

    @AppStorage("web7.soundOn") private var soundOn = false
    @AppStorage("web7.dims") private var relationsOnRaw = ""
    @AppStorage("web7.spreadSeconds") private var spreadSeconds = 3.0
    @AppStorage("web7.autoWrite") private var autoWrite = false

    @State private var word = ""
    @State private var yaw = 0.6
    @State private var pitch = -0.3
    @State private var dist = 720.0
    @State private var pan = CGSize.zero
    @State private var panning = false
    @State private var lastDrag = CGSize.zero
    @State private var canvasSize = CGSize(width: 800, height: 500)
    @State private var hovered: String?
    @State private var positions: [String: SIMD3<Double>] = [:]
    @State private var positionsRevision = -1

    private let parchment = Color(red: 0.91, green: 0.86, blue: 0.74)
    private let ink = Color(red: 0.32, green: 0.22, blue: 0.12)
    private let ochre = Color(red: 0.62, green: 0.18, blue: 0.10)

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
        .environment(\.colorScheme, .light)
        .onAppear {
            store.loadPhonetics()
            ChimeEngine.shared.muted = !soundOn
            model.autoSpread = autoWrite
            rebuildPositions()
        }
        .onChange(of: model.revision) { _, _ in rebuildPositions() }
        .task { await spreadLoop() }
    }

    // MARK: 3D layout — deterministic, derived from the codex's parent chains

    private func randUnit(seed: Int) -> SIMD3<Double> {
        var h = UInt64(bitPattern: Int64(seed)) &* 0x9E3779B97F4A7C15
        func next() -> Double {
            h = h &* 6364136223846793005 &+ 1442695040888963407
            return Double(h >> 40 % 2000) / 1000 - 1     // -1...1
        }
        var v = SIMD3(next(), next(), next())
        if simd_length(v) < 0.001 { v = SIMD3(0, 1, 0) }
        return simd_normalize(v)
    }

    /// Seed at the origin; each child leaves its parent along a seeded
    /// direction biased outward, so chains of circles become chains of arms.
    private func rebuildPositions() {
        guard positionsRevision != model.revision else { return }
        positionsRevision = model.revision
        var out: [String: SIMD3<Double>] = [:]
        for w in model.words {           // parents precede children in order
            if w.generation == 0 {
                out[w.id] = .zero
                continue
            }
            guard let parent = w.parent, let pp = out[parent] else {
                out[w.id] = randUnit(seed: w.id.hashValue) * 240
                continue
            }
            let outward = simd_length(pp) < 0.001
                ? randUnit(seed: w.id.hashValue)
                : simd_normalize(pp)
            let jitter = randUnit(seed: w.id.hashValue &* 31 &+ w.generation)
            let dir = simd_normalize(outward + jitter * 1.1)
            let reach = 150.0 * pow(0.92, Double(w.generation - 1))
            out[w.id] = pp + dir * reach
        }
        positions = out
    }

    // MARK: Projection

    private func rotated(_ v: SIMD3<Double>) -> SIMD3<Double> {
        var p = v
        p = SIMD3(p.x * cos(yaw) + p.z * sin(yaw), p.y, -p.x * sin(yaw) + p.z * cos(yaw))
        p = SIMD3(p.x, p.y * cos(pitch) - p.z * sin(pitch), p.y * sin(pitch) + p.z * cos(pitch))
        return p
    }

    /// Perspective-project a world point. Returns screen point + scale, or nil
    /// when behind the near plane.
    private func project(_ v: SIMD3<Double>, in size: CGSize) -> (CGPoint, Double)? {
        let p = rotated(v)
        let depth = p.z + dist
        guard depth > 80 else { return nil }
        let s = 560.0 / depth
        return (CGPoint(x: size.width / 2 + pan.width + p.x * s,
                        y: size.height / 2 + pan.height + p.y * s), s)
    }

    private func nearestWord(to point: CGPoint, within reach: CGFloat) -> String? {
        var best: (String, CGFloat)?
        for w in model.words {
            guard let pos = positions[w.id],
                  let (p, _) = project(pos, in: canvasSize) else { continue }
            let d = hypot(p.x - point.x, p.y - point.y)
            if d < reach, d < (best?.1 ?? .infinity) { best = (w.id, d) }
        }
        return best?.0
    }

    // MARK: Growth (the same web, opened from the round)

    private func spreadLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let now = Date()
            model.reap(now: now)
            if model.autoSpread, model.words.count > 88,
               let victim = model.beginDecay(now: now) {
                model.record("∴ \(victim) fades from the page")
                ChimeEngine.shared.play(rawFrequency: 130.8, amplitude: 0.06)
            }
            guard model.autoSpread, !model.isBusy, !model.isFull, store.isReady,
                  !model.words.isEmpty, !relationsOn.isEmpty,
                  now.timeIntervalSince(model.lastSpread) >= max(1, spreadSeconds) else { continue }
            let unopened = model.words.filter { !$0.expanded && $0.dying == nil }
            guard let host = unopened.randomElement()
                ?? model.words.filter({ $0.expanded }).randomElement() else { continue }
            model.lastSpread = now
            expand(host.id, auto: true)
        }
    }

    private func expand(_ target: String, auto: Bool = false) {
        guard !model.isBusy, let cryptic = store.cryptic, let ladder = store.ladder else { return }
        let relations = relationsOn
        guard !relations.isEmpty else {
            model.status = "all seven dimensions are set aside — switch some on in the ☰ menu"
            return
        }
        model.isBusy = true
        Task {
            let fusion = await store.fusionFinder()
            let phonetics = store.phonetics
            let found = await Task.detached(priority: auto ? .utility : .userInitiated) {
                ConnectionWeb(cryptic: cryptic, ladder: ladder, phonetics: phonetics, fusion: fusion)
                    .connections(of: target, perRelation: auto ? 2 : 4, relations: relations)
            }.value
            let placed = model.inscribe(from: target, with: found, viral: auto, now: Date())
            if placed > 0 {
                if !auto { ChimeEngine.shared.speak(target) }
                model.record(auto
                    ? "✦ the codex inscribed \(target) · +\(placed)"
                    : "\(target): \(placed) inscriptions")
                if auto { ChimeEngine.shared.playInfection() }
                else { ChimeEngine.shared.play(model.entry(for: target)?.relation) }
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
        model.record("\(w): set at the heart of the sphere.")
        ChimeEngine.shared.play(nil)
        expand(w)
    }

    // MARK: HUD

    private var hud: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TextField("a word…", text: $word)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: 150)
                    .onSubmit { seed() }
                    .help("The word to set at the heart of a fresh sphere. Press ⏎ to begin. (Divining a way between two words lives on the codex page.)")
                Button("Inscribe") { seed() }
                    .buttonStyle(.borderedProminent).tint(ink)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!store.isReady || model.isBusy)
                    .help("Begin a new sphere from this word (⌘⏎).")
                if model.isBusy || store.phoneticsLoading { ProgressView().controlSize(.small) }
                Divider().frame(height: 16)
                Text(model.isFull
                     ? "the sphere is full — clear to begin anew"
                     : "\(model.words.count) inscriptions")
                    .font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
                    .help("How many words are inscribed — the same web the codex page shows, seen in the round.")
                Button("Clear") { model.clear() }
                    .controlSize(.small)
                    .disabled(model.words.isEmpty)
                    .help("Wipe the sphere (and the codex — they are one web). This also clears what was saved between launches.")
                Menu {
                    ForEach(ConnectionWeb.Relation.allCases) { r in
                        Toggle(isOn: relationBinding(r)) { Text("\(r.glyph)  \(r.rawValue)") }
                    }
                    Divider()
                    Button("All seven on") { relationsOnRaw = WebDimensions.allRaw }
                } label: { Image(systemName: "slider.horizontal.3") }
                    .controlSize(.small)
                    .fixedSize()
                    .help("Which of the seven dimensions may forge new connections (\(relationsOn.count) of 7 on). All are OFF by default — switch on the ones you want to see.")
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
                    .help("How often the sphere grows on its own — currently \(WebDimensions.cadenceLabel(spreadSeconds)). Applies only to self-writing.")
                Button {
                    autoWrite.toggle()
                    model.autoSpread = autoWrite
                } label: { Image(systemName: autoWrite ? "pause.fill" : "play.fill") }
                    .controlSize(.small)
                    .tint(autoWrite ? ochre : nil)
                    .help(autoWrite
                        ? "The sphere is growing on its own, \(WebDimensions.cadenceLabel(spreadSeconds)). Click to pause."
                        : "Self-writing is OFF (the default). Click to let the sphere grow on its own; needs at least one dimension switched on.")
                Button {
                    soundOn.toggle()
                    ChimeEngine.shared.muted = !soundOn
                } label: { Image(systemName: soundOn ? "speaker.wave.2" : "speaker.slash") }
                    .controlSize(.small)
                    .help(soundOn
                        ? "Sound is ON — a pentatonic chime per dimension. Click to silence."
                        : "Sound is OFF (the default). Click to hear the chimes.")
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
                        Text(r.glyph).font(.system(size: 12))
                            .foregroundStyle(r.color.opacity(on ? 0.85 : 0.25))
                        Text(r.rawValue)
                            .font(.system(.caption2, design: .serif))
                            .foregroundStyle(ink.opacity(on ? 0.6 : 0.3))
                            .strikethrough(!on, color: ink.opacity(0.4))
                    }
                }
                .buttonStyle(.plain)
                .help("\(r.glyph) \(r.rawValue): \(r.explanation). \(on ? "On — click to set aside." : "Set aside — click to allow.")")
            }
            Spacer()
            Text("drag to orbit · ⌥drag to pan · scroll/pinch to dolly · click a word to open it")
                .font(.system(.caption2, design: .serif).italic())
                .foregroundStyle(ink.opacity(0.45))
                .help("Navigate like a 3D modelling app: drag anywhere to orbit the sphere, hold ⌥ (option) and drag to pan, pinch or two-finger scroll to move closer or further. Click a word to inscribe its connections around it; hover to learn why it is connected.")
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(parchment.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(ink.opacity(0.25), lineWidth: 1))
    }

    // MARK: The sphere

    private var page: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    drawScene(ctx, size: size, now: timeline.date)
                }
            }
            .onChange(of: geo.size, initial: true) { _, s in canvasSize = s }
            .gesture(pointer)
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): hovered = nearestWord(to: p, within: 28)
                case .ended: hovered = nil
                }
            }
            .overlay(ZoomCatcher(onZoom: { factor, _ in
                dist = min(2600, max(180, dist / Double(factor)))
            }))
        }
        .background(parchment)
        .ignoresSafeArea(edges: .bottom)
    }

    private var pointer: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let delta = CGSize(width: value.translation.width - lastDrag.width,
                                   height: value.translation.height - lastDrag.height)
                lastDrag = value.translation
                guard hypot(value.translation.width, value.translation.height) > 6 else { return }
                panning = true
                if NSEvent.modifierFlags.contains(.option) {
                    pan.width += delta.width
                    pan.height += delta.height
                } else {
                    yaw += Double(delta.width) * 0.008
                    pitch = min(1.45, max(-1.45, pitch + Double(delta.height) * 0.008))
                }
            }
            .onEnded { value in
                defer { panning = false; lastDrag = .zero }
                guard hypot(value.translation.width, value.translation.height) <= 6 else { return }
                if let hit = nearestWord(to: value.location, within: 28) {
                    expand(hit)
                }
            }
    }

    private func drawScene(_ ctx: GraphicsContext, size: CGSize, now: Date) {
        // Parchment wash, same hand as the codex.
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(
                    Gradient(colors: [Color(red: 0.93, green: 0.885, blue: 0.775),
                                      Color(red: 0.85, green: 0.78, blue: 0.63)]),
                    center: CGPoint(x: size.width / 2, y: size.height * 0.45),
                    startRadius: 0, endRadius: max(size.width, size.height) * 0.8))

        drawArmillary(ctx, size: size)

        guard !model.words.isEmpty else {
            ctx.draw(
                Text(store.isReady
                     ? "speak a word, and the sphere will turn around it"
                     : "the codex is being bound…")
                    .font(.system(.title3, design: .serif).italic())
                    .foregroundStyle(ink.opacity(0.45)),
                at: CGPoint(x: size.width / 2, y: size.height / 2))
            return
        }

        // Edges first (parent → child), then words back-to-front.
        for w in model.words {
            guard let parent = w.parent,
                  let a = positions[parent], let b = positions[w.id],
                  let (pa, _) = project(a, in: size),
                  let (pb, sb) = project(b, in: size) else { continue }
            var path = Path()
            path.move(to: pa)
            path.addLine(to: pb)
            ctx.stroke(path, with: .color(ink.opacity(0.10 + 0.14 * min(sb, 1))),
                       lineWidth: 0.7)
        }

        let ordered = model.words.compactMap { entry -> (SigilModel.SWord, CGPoint, Double, Double)? in
            guard let pos = positions[entry.id],
                  let (p, s) = project(pos, in: size) else { return nil }
            return (entry, p, s, rotated(pos).z)
        }.sorted { $0.3 > $1.3 }                                   // far first

        for (entry, p, s, _) in ordered {
            drawWord(ctx, entry: entry, at: p, scale: s, now: now)
        }

        drawHoverCard(ctx, size: size)
    }

    /// Three faint great circles — the armillary rings the sphere hangs in.
    private func drawArmillary(_ ctx: GraphicsContext, size: CGSize) {
        let R = 250.0
        let rings: [(SIMD3<Double>, SIMD3<Double>)] = [
            (SIMD3(1, 0, 0), SIMD3(0, 0, 1)),      // equator
            (SIMD3(1, 0, 0), SIMD3(0, 1, 0)),      // meridian
            (SIMD3(0, 1, 0), SIMD3(0, 0, 1)),      // colure
        ]
        for (u, v) in rings {
            var path = Path()
            var started = false
            for k in 0...72 {
                let a = Double(k) / 72 * 2 * .pi
                let world = (u * cos(a) + v * sin(a)) * R
                guard let (p, _) = project(world, in: size) else { started = false; continue }
                if started { path.addLine(to: p) } else { path.move(to: p); started = true }
            }
            ctx.stroke(path, with: .color(ink.opacity(0.08)), lineWidth: 1)
        }
    }

    private func drawWord(_ ctx: GraphicsContext, entry: SigilModel.SWord,
                          at p: CGPoint, scale s: Double, now: Date) {
        let grown = 1 - pow(1 - min(now.timeIntervalSince(entry.born) / 0.5, 1), 3)
        let isCurrent = entry.id == model.current
        let isHovered = entry.id == hovered
        let aged = 1 - 0.4 * min(now.timeIntervalSince(entry.born) / 150, 1)
        var alpha = Double(grown) * aged * (isCurrent || isHovered ? 1.0 : 0.82)
        if let dying = entry.dying {
            alpha *= max(0, 1 - now.timeIntervalSince(dying) / 1.8)
        }
        alpha *= min(1, 0.35 + s)                                   // haze with distance

        let base = entry.generation == 0 ? 24.0 : (isCurrent ? 15.0 : 13.0)
        let fontSize = max(5, min(30, base * s * 1.15))
        ctx.draw(
            Text(entry.id)
                .font(.system(size: fontSize, design: .serif)
                    .weight(entry.generation == 0 || isCurrent ? .semibold : .regular)
                    .italic())
                .foregroundStyle((entry.viral ? ochre : ink).opacity(alpha)),
            at: p)
        if let relation = entry.relation {
            ctx.draw(
                Text(relation.glyph)
                    .font(.system(size: max(6, min(16, 11 * s * 1.15))))
                    .foregroundStyle(relation.color.opacity(0.9 * alpha)),
                at: CGPoint(x: p.x, y: p.y - fontSize * 0.9))
        }
    }

    private func drawHoverCard(_ ctx: GraphicsContext, size: CGSize) {
        guard let id = hovered, !panning,
              let entry = model.entry(for: id), !entry.detail.isEmpty,
              let pos = positions[id],
              let (anchor, _) = project(pos, in: size) else { return }
        var caption = entry.detail
        if let relation = entry.relation {
            caption = "\(relation.glyph) \(relation.rawValue) — \(relation.explanation)\n" + caption
        }
        if let phones = store.phonetics?.pronunciations(of: id).first {
            caption += "\n/\(phones.joined(separator: " "))/"
        }
        caption += entry.viral
            ? "\ninscribed by the codex itself · click to open it"
            : "\nclick to open it"
        let text = Text(caption)
            .font(.system(.caption, design: .serif))
            .foregroundStyle(ink.opacity(0.9))
        let resolved = ctx.resolve(text)
        let measured = resolved.measure(in: CGSize(width: 420, height: 120))
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
}
