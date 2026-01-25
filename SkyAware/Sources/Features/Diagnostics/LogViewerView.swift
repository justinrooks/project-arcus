//
//  LogViewerView.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/14/25.
//

import SwiftUI
import OSLog

// A Sendable DTO so we don’t pass OSLogEntry (not Sendable) around.
struct LogLine: Identifiable, Sendable {
    let id = UUID()
    var _id: UUID { id }
    let date: Date
    let level: OSLogEntryLog.Level
    let subsystem: String
    let category: String
    let message: String
}

@MainActor
struct LogViewerView: View {
    private let logger = Logger.uiDiagnostics
    private let maxEntries = 1000
    enum Window: TimeInterval, CaseIterable, Identifiable {
        case fiveMin = 300, thirtyMin = 1800, twoHours = 7200
        var id: Self { self }
        var label: String {
            switch self {
            case .fiveMin:   return "5 min"
            case .thirtyMin: return "30 min"
            case .twoHours:  return "2 hr"
            }
        }
    }

    @State private var lines: [LogLine] = []
    @State private var isLoading = false
    @State private var window: Window = .thirtyMin
    @State private var query = ""
    @State private var includeAllSubsystems = false
    @State private var loadTask: Task<Void, Never>?
    @State private var exportCache: String = ""

    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                triggerLoad(debounced: false)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            if !lines.isEmpty {
                ShareLink(item: exportCache, preview: .init("Logs", image: "doc.text"))
            }
        }
    }

    private static func makeDateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }
    @State private var dateFormatter = LogViewerView.makeDateFormatter()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                controls
                contentList
            }
            .padding()
            .navigationTitle("Logs")
            .toolbar { toolbarItems }
            .task { triggerLoad(debounced: false) }
            .task(id: window) { triggerLoad(debounced: false) }
            .task(id: includeAllSubsystems) { triggerLoad(debounced: false) }
            .task(id: query) { triggerLoad(debounced: true) }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Window", selection: $window) {
                    ForEach(Window.allCases) { win in
                        Text(win.label).tag(win)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("All", isOn: $includeAllSubsystems)
                    .toggleStyle(.switch)
                    .help("Include all subsystems (not just this app)")
            }

            TextField("Filter text…", text: $query)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var contentList: some View {
        Group {
            if isLoading {
                ProgressView("Loading logs…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if lines.isEmpty {
                ContentUnavailableView {
                    Label("No log entries", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("There are no log entries to display.")
                }
            } else {
                List(lines, id: \._id) { line in
                    LogRowView(line: line, includeSubsystem: includeAllSubsystems, dateFormatter: dateFormatter)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await fetchLogs(
                since: window.rawValue,
                subsystem: includeAllSubsystems ? nil : (Bundle.main.bundleIdentifier ?? ""),
                contains: query.isEmpty ? nil : query,
                maxEntries: maxEntries
            )
            lines = fetched
            exportCache = exportText()
        } catch {
            lines = []
            exportCache = ""
            // You can also surface a toast here.
            logger.error("Failed to read logs: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private func exportText() -> String {
        lines.map { line in
            "[\(dateFormatter.string(from: line.date))] [\(line.level.rawValue)] [\(line.subsystem):\(line.category)] \(line.message)"
        }.joined(separator: "\n")
    }

    private func triggerLoad(debounced: Bool) {
        loadTask?.cancel()
        loadTask = Task {
            if debounced {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
            }
            await load()
        }
    }
}

private struct LogRowView: View {
    let line: LogLine
    let includeSubsystem: Bool
    let dateFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(logBadge(for: line.level))
                .font(.system(.headline, design: .rounded))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.message)
                    .font(.callout)
                    .lineLimit(3)
                HStack(spacing: 8) {
                    Text(dateFormatter.string(from: line.date))
                        .foregroundStyle(.secondary)
                    Text(line.category)
                        .foregroundStyle(.secondary)
                    if includeSubsystem {
                        Text(line.subsystem)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
        }
    }
}

private func logBadge(for level: OSLogEntryLog.Level) -> String {
    switch level {
    case .debug:   return "◻︎"
    case .info:    return "ℹ︎"
    case .notice:  return "●"
    case .error:   return "⚠︎"
    case .fault:   return "⛔️"
    case .undefined:
        return "•"
    @unknown default: return "•"
    }
}

// MARK: - OSLogStore bridge (async-friendly)

private func fetchLogs(since seconds: TimeInterval,
                       subsystem: String?,
                       contains: String?,
                       maxEntries: Int) async throws -> [LogLine] {
    // OSLogStore is sync; wrap in Task to avoid blocking main.
    try await Task.detached(priority: .utility) {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let start = store.position(date: Date().addingTimeInterval(-seconds))
        let entries = try store.getEntries(at: start)

        var result: [LogLine] = []
        result.reserveCapacity(256)

        for case let e as OSLogEntryLog in entries {
            if Task.isCancelled { break }
            if let subsystem, e.subsystem != subsystem { continue }
            if let contains, !e.composedMessage.localizedCaseInsensitiveContains(contains) { continue }
            result.append(LogLine(
                date: e.date,
                level: e.level,
                subsystem: e.subsystem,
                category: e.category,
                message: e.composedMessage
            ))
            if result.count >= maxEntries { break }
        }
        // Newest last from the store; reverse so newest appears first in UI if you prefer.
        return result.reversed()
    }.value
}
