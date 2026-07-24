// Dump precomputed semantic neighbors for the web app's Association (♅)
// dimension. Mirrors the app's SemanticNeighbors (WordStore.swift): Apple's
// on-device NLEmbedding, neighbors filtered to the same word list — but run
// once at build time on a Mac, so any platform can ship the result as data.
//
// Usage:
//   swift run assoc-dump <wordlist.txt> <output.txt> [--limit-to <lexicon.txt>] [--n <count>]
//
// Output: one line per word that has neighbors — `word|n1 n2 n3 …` — sorted.
import Foundation
import NaturalLanguage

func loadWords(_ path: String) -> Set<String> {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("cannot read \(path)\n".utf8))
        exit(1)
    }
    var out = Set<String>()
    for raw in text.split(separator: "\n") {
        // lexicon lines are `word|…`; wordlist lines are bare words
        let head = raw.split(separator: "|").first.map(String.init) ?? String(raw)
        let w = head.lowercased()
        if !w.isEmpty, w.allSatisfy({ $0 >= "a" && $0 <= "z" }) { out.insert(w) }
    }
    return out
}

var args = Array(CommandLine.arguments.dropFirst())
var limitPath: String? = nil
var topN = 12
if let i = args.firstIndex(of: "--limit-to"), i + 1 < args.count {
    limitPath = args[i + 1]
    args.removeSubrange(i...(i + 1))
}
if let i = args.firstIndex(of: "--n"), i + 1 < args.count {
    topN = Int(args[i + 1]) ?? 12
    args.removeSubrange(i...(i + 1))
}
guard args.count == 2 else {
    FileHandle.standardError.write(Data(
        "usage: assoc-dump <wordlist.txt> <output.txt> [--limit-to <lexicon.txt>] [--n <count>]\n".utf8))
    exit(2)
}
let (wordlistPath, outputPath) = (args[0], args[1])

guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
    FileHandle.standardError.write(Data("NLEmbedding unavailable on this system\n".utf8))
    exit(1)
}

let words = loadWords(wordlistPath)
// Source words: the wordlist, optionally narrowed to the lexicon (the codex
// only ever expands lexicon words). Neighbor candidates: same universe.
let universe = limitPath.map { words.intersection(loadWords($0)) } ?? words

var lines: [String] = []
var sourcesWithVectors = 0
for word in universe.sorted() {
    guard embedding.contains(word) else { continue }
    sourcesWithVectors += 1
    var neighbors: [String] = []
    for (neighbor, _) in embedding.neighbors(for: word, maximumCount: topN * 4) {
        let w = neighbor.lowercased()
        guard w != word, w.allSatisfy({ $0 >= "a" && $0 <= "z" }) else { continue }
        guard universe.contains(w) else { continue }
        if !neighbors.contains(w) { neighbors.append(w) }
        if neighbors.count >= topN { break }
    }
    if !neighbors.isEmpty {
        lines.append("\(word)|\(neighbors.joined(separator: " "))")
    }
}

let out = lines.joined(separator: "\n") + "\n"
try! out.write(toFile: outputPath, atomically: true, encoding: .utf8)
print("words in universe: \(universe.count); with vectors: \(sourcesWithVectors); with neighbors: \(lines.count)")
print("wrote \(outputPath) (\(out.utf8.count) bytes)")
