import SwiftUI
import AnagramEngine

struct AnagramsView: View {
    @EnvironmentObject var store: WordStore
    @EnvironmentObject var history: HistoryStore

    @State private var phrase = ""
    @State private var include = ""
    @State private var excludeText = ""
    @State private var maxResults = 500
    @State private var maxWords = 2
    @State private var minWordLength = 3
    @State private var casing: Casing = .firstUpper

    @State private var results: [String] = []
    @State private var isBusy = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        ToolScaffold(
            toolName: "Anagrams",
            title: "Anagrams",
            subtitle: "Rearrange every letter of a word or phrase into other words. Results stream in as they're found.",
            controls: { controls },
            resultCount: results.count,
            copyText: results.joined(separator: "\n"),
            isBusy: isBusy,
            lines: results,
            emptyHint: "Type a word or phrase and press Find."
        )
    }

    @ViewBuilder private var controls: some View {
        Field(label: "Word or phrase") {
            TextField("e.g. dormitory", text: $phrase)
                .textFieldStyle(.roundedBorder).onSubmit(run)
        }
        HStack(spacing: 12) {
            Field(label: "Include word") {
                TextField("optional", text: $include).textFieldStyle(.roundedBorder)
            }
            Field(label: "Exclude words") {
                TextField("space separated", text: $excludeText).textFieldStyle(.roundedBorder)
            }
        }
        HStack(spacing: 12) {
            Field(label: "Max words") {
                Picker("", selection: $maxWords) {
                    Text("Any").tag(0); ForEach(1...6, id: \.self) { Text("\($0)").tag($0) }
                }.labelsHidden()
            }
            Field(label: "Min letters/word") {
                Picker("", selection: $minWordLength) {
                    ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                }.labelsHidden()
            }
            Field(label: "Max results") {
                Picker("", selection: $maxResults) {
                    Text("100").tag(100); Text("500").tag(500); Text("2000").tag(2000); Text("All").tag(0)
                }.labelsHidden()
            }
        }
        Field(label: "Casing") {
            Picker("", selection: $casing) {
                Text("lower").tag(Casing.lower)
                Text("First Upper").tag(Casing.firstUpper)
                Text("UPPER").tag(Casing.upper)
            }.pickerStyle(.segmented).labelsHidden()
        }
        HStack {
            if isBusy {
                Button("Stop", role: .destructive) { task?.cancel(); isBusy = false }
            } else {
                Button("Find Anagrams", action: run)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    private func run() {
        guard let engine = store.anagram else { return }
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var o = AnagramOptions()
        o.maxResults = maxResults
        o.maxWords = maxWords
        o.include = include.trimmingCharacters(in: .whitespacesAndNewlines)
        o.exclude = excludeText.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        o.minWordLength = minWordLength
        o.casing = casing

        task?.cancel()
        isBusy = true
        results = []
        let opts = o

        // Producer/consumer streaming: the background search yields batches; the
        // consumer appends them to the published array so results appear live.
        let (batches, continuation) = AsyncStream.makeStream(of: [String].self)

        task = Task { @MainActor in
            let producer = Task.detached(priority: .userInitiated) { [engine] in
                var buffer: [String] = []
                engine.search(phrase: trimmed, options: opts, isCancelled: { Task.isCancelled }) { result in
                    buffer.append(AnagramEngine.format(result.words, casing: opts.casing))
                    if buffer.count >= 100 {
                        continuation.yield(buffer)
                        buffer.removeAll(keepingCapacity: true)
                    }
                    return true
                }
                if !buffer.isEmpty { continuation.yield(buffer) }
                continuation.finish()
            }
            for await batch in batches {
                results.append(contentsOf: batch)
            }
            _ = await producer.value
            isBusy = false
            history.record(tool: "Anagrams", query: trimmed, count: results.count)
        }
    }
}
