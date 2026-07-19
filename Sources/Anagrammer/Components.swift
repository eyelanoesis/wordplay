import SwiftUI

/// A labeled field wrapper used across tool panels.
struct Field<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }
}

/// Standard tool layout: a title/subtitle header, a controls block, and a
/// scrollable results pane with count, copy-all, export, and per-row favoriting.
struct ToolScaffold<Controls: View>: View {
    let toolName: String
    let title: String
    let subtitle: String
    @ViewBuilder var controls: () -> Controls
    let resultCount: Int
    let copyText: String
    let isBusy: Bool
    let lines: [String]
    let emptyHint: String

    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title.bold())
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                controls()
            }
            .padding(16)
            Divider()
            resultsHeader
            Divider()
            resultsBody
        }
    }

    private var resultsHeader: some View {
        HStack(spacing: 12) {
            Text("\(resultCount) result(s)").font(.headline)
            if isBusy { ProgressView().controlSize(.small) }
            Spacer()
            Button {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(copyText, forType: .string)
            } label: { Label("Copy all", systemImage: "doc.on.doc") }
                .disabled(lines.isEmpty)
            Button {
                Exporter.save(lines: lines, suggestedName: "\(toolName).txt")
            } label: { Label("Export…", systemImage: "square.and.arrow.up") }
                .disabled(lines.isEmpty)
        }
        .padding(10)
    }

    private var resultsBody: some View {
        Group {
            if lines.isEmpty {
                VStack { Spacer(); Text(isBusy ? "Working…" : emptyHint).foregroundStyle(.secondary); Spacer() }
                    .frame(maxWidth: .infinity)
            } else {
                List(Array(lines.enumerated()), id: \.offset) { _, line in
                    ResultRow(text: line, toolName: toolName)
                }
                .listStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

/// One result line with a hover-revealed favorite star.
private struct ResultRow: View {
    let text: String
    let toolName: String
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var hovering = false

    var body: some View {
        HStack {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
            let fav = favorites.contains(text)
            Button {
                favorites.toggle(text, tool: toolName)
            } label: {
                Image(systemName: fav ? "star.fill" : "star")
                    .foregroundStyle(fav ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .opacity(fav || hovering ? 1 : 0)
        }
        .onHover { hovering = $0 }
    }
}
