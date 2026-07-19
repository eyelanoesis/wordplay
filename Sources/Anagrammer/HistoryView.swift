import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var history: HistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("History").font(.title.bold())
                    Text("Your recent queries across every tool.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) { history.clear() } label: {
                    Label("Clear", systemImage: "trash")
                }.disabled(history.entries.isEmpty)
            }
            .padding(16)
            Divider()
            if history.entries.isEmpty {
                Spacer(); Text("No history yet.").foregroundStyle(.secondary).frame(maxWidth: .infinity); Spacer()
            } else {
                List(history.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.query).font(.body)
                            Text("\(entry.tool) · \(entry.count) result(s)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.date, format: .relative(presentation: .named))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .textSelection(.enabled)
                }
                .listStyle(.plain)
            }
        }
    }
}

struct FavoritesView: View {
    @EnvironmentObject var favorites: FavoritesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorites").font(.title.bold())
                    Text("Starred results you've saved.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Exporter.save(lines: favorites.items.map(\.text), suggestedName: "Favorites.txt")
                } label: { Label("Export…", systemImage: "square.and.arrow.up") }
                    .disabled(favorites.items.isEmpty)
                Button(role: .destructive) { favorites.clear() } label: {
                    Label("Clear", systemImage: "trash")
                }.disabled(favorites.items.isEmpty)
            }
            .padding(16)
            Divider()
            if favorites.items.isEmpty {
                Spacer()
                Text("No favorites yet — hover a result and tap the star.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                List(favorites.items) { item in
                    HStack {
                        Text(item.text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                        Text(item.tool).font(.caption2).foregroundStyle(.tertiary)
                        Button {
                            favorites.remove(item.text)
                        } label: { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                            .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
