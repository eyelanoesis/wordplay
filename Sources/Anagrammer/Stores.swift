import Foundation
import SwiftUI

// MARK: - Persistence helper

enum AppStorageDir {
    /// ~/Library/Application Support/Wordplay, created on demand.
    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Wordplay", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        let url = url.appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to file: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url.appendingPathComponent(file), options: .atomic)
    }
}

// MARK: - History

struct HistoryEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var tool: String
    var query: String
    var count: Int
    var date: Date
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    private let file = "history.json"
    private let limit = 250

    init() { entries = AppStorageDir.load([HistoryEntry].self, from: file) ?? [] }

    func record(tool: String, query: String, count: Int) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        // Collapse an immediately-repeated identical query.
        if let first = entries.first, first.tool == tool, first.query == q { return }
        entries.insert(HistoryEntry(tool: tool, query: q, count: count, date: Date()), at: 0)
        if entries.count > limit { entries.removeLast(entries.count - limit) }
        AppStorageDir.save(entries, to: file)
    }

    func clear() {
        entries = []
        AppStorageDir.save(entries, to: file)
    }
}

// MARK: - Favorites

struct FavoriteEntry: Codable, Identifiable, Hashable {
    var text: String
    var tool: String
    var date: Date
    var id: String { text }
}

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var items: [FavoriteEntry] = []
    private var index: Set<String> = []
    private let file = "favorites.json"

    init() {
        items = AppStorageDir.load([FavoriteEntry].self, from: file) ?? []
        index = Set(items.map(\.text))
    }

    func contains(_ text: String) -> Bool { index.contains(text) }

    func toggle(_ text: String, tool: String) {
        if index.contains(text) {
            items.removeAll { $0.text == text }
            index.remove(text)
        } else {
            items.insert(FavoriteEntry(text: text, tool: tool, date: Date()), at: 0)
            index.insert(text)
        }
        AppStorageDir.save(items, to: file)
    }

    func remove(_ text: String) {
        items.removeAll { $0.text == text }
        index.remove(text)
        AppStorageDir.save(items, to: file)
    }

    func clear() {
        items = []
        index = []
        AppStorageDir.save(items, to: file)
    }
}

// MARK: - Export

enum Exporter {
    /// Presents a save panel and writes the lines as .txt or .csv.
    @MainActor
    static func save(lines: [String], suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.plainText, .commaSeparatedText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let isCSV = url.pathExtension.lowercased() == "csv"
        let body: String
        if isCSV {
            body = "result\n" + lines.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                .joined(separator: "\n")
        } else {
            body = lines.joined(separator: "\n")
        }
        try? body.write(to: url, atomically: true, encoding: .utf8)
    }
}
