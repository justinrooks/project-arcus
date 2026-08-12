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
    let id: String
    let date: Date
    let level: OSLogEntryLog.Level
    let subsystem: String
    let category: String
    let message: String

    init(
        date: Date,
        level: OSLogEntryLog.Level,
        subsystem: String,
        category: String,
        message: String
    ) {
        self.date = date
        self.level = level
        self.subsystem = subsystem
        self.category = category
        self.message = message
        // Keep identity stable across refreshes when content does not change.
        self.id = "\(date.timeIntervalSinceReferenceDate)|\(level.rawValue)|\(subsystem)|\(category)|\(message)"
    }
}

@MainActor
struct LogViewerView: View {
    private let logger = Logger.uiDiagnostics

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

    private struct LoadConfiguration: Equatable {
        let window: Window
        let includeAllSubsystems: Bool
        let maxEntries: Int
    }

    @State private var loadState = LogViewerLoadState()
    @State private var window: Window = .thirtyMin
    @State private var query = ""
    @State private var includeAllSubsystems = false
    @State private var maxEntriesSelection = 250
    @State private var loadTask: Task<Void, Never>?

    private let dateFormatter = LogViewerView.makeDateFormatter()
    private var loadConfiguration: LoadConfiguration {
        LoadConfiguration(
            window: window,
            includeAllSubsystems: includeAllSubsystems,
            maxEntries: maxEntriesSelection
        )
    }

    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                triggerLoad(debounced: false)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            if !loadState.lines.isEmpty {
                ShareLink(item: loadState.exportCache, preview: .init("Logs", image: "doc.text"))
            }
        }
    }

    private static func makeDateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }

    var body: some View {
        VStack(spacing: 12) {
            controls
            contentList
        }
        .padding()
        .background(Color(.skyAwareBackground).ignoresSafeArea())
        .navigationTitle("Logs")
        .toolbar { toolbarItems }
        .task { triggerLoad(debounced: false) }
        .onChange(of: loadConfiguration) { _, _ in
            triggerLoad(debounced: false)
        }
        .onChange(of: query) { _, _ in
            triggerLoad(debounced: true)
        }
        .onDisappear {
            loadTask?.cancel()
            _ = loadState.startRequest()
            loadTask = nil
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

            Picker("Max Entries", selection: $maxEntriesSelection) {
                Text("250").tag(250)
                Text("500").tag(500)
                Text("1000").tag(1000)
                Text("2000").tag(2000)
            }
            .pickerStyle(.segmented)
        }
        .padding(10)
        .cardBackground(cornerRadius: SkyAwareRadius.content, shadowOpacity: 0.12, shadowRadius: 10, shadowY: 4)
    }

    private var contentList: some View {
        Group {
            if loadState.isLoading {
                ProgressView("Loading logs…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if loadState.lines.isEmpty {
                ContentUnavailableView {
                    Label("No log entries", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("There are no log entries to display.")
                }
            } else {
                List(loadState.lines) { line in
                    LogRowView(line: line, includeSubsystem: includeAllSubsystems, dateFormatter: dateFormatter)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(.skyAwareBackground)
            }
        }
    }

    // MARK: - Loading

    private func load(requestID: Int) async {
        guard loadState.beginLoading(for: requestID) else { return }
        defer { loadState.finish(requestID) }

        do {
            let fetched = try await fetchLogs(
                since: window.rawValue,
                subsystem: includeAllSubsystems ? nil : (Bundle.main.bundleIdentifier ?? ""),
                contains: query.isEmpty ? nil : query,
                maxEntries: maxEntriesSelection
            )
            try Task.checkCancellation()
            guard loadState.owns(requestID) else { return }
            let export = exportText(for: fetched)
            _ = loadState.publish(fetched, exportCache: export, for: requestID)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, loadState.owns(requestID) else { return }
            _ = loadState.fail(requestID)
            // You can also surface a toast here.
            logger.error("Failed to read logs: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private func exportText(for lines: [LogLine]) -> String {
        lines.map { line in
            "[\(dateFormatter.string(from: line.date))] [\(line.level.rawValue)] [\(line.subsystem):\(line.category)] \(line.message)"
        }.joined(separator: "\n")
    }

    private func triggerLoad(debounced: Bool) {
        loadTask?.cancel()
        let requestID = loadState.startRequest()
        loadTask = Task { [requestID] in
            if debounced {
                do {
                    try await Task.sleep(nanoseconds: 400_000_000)
                } catch {
                    return
                }
            }
            await load(requestID: requestID)
        }
    }
}

@MainActor
struct LogViewerLoadState {
    private(set) var lines: [LogLine] = []
    private(set) var isLoading = false
    private(set) var exportCache = ""

    private var activeRequestID = 0

    mutating func startRequest() -> Int {
        activeRequestID += 1
        return activeRequestID
    }

    func owns(_ requestID: Int) -> Bool {
        requestID == activeRequestID
    }

    mutating func beginLoading(for requestID: Int) -> Bool {
        guard owns(requestID), !Task.isCancelled else { return false }
        isLoading = true
        return true
    }

    mutating func publish(_ lines: [LogLine], exportCache: String, for requestID: Int) -> Bool {
        guard owns(requestID), !Task.isCancelled else { return false }
        self.lines = lines
        self.exportCache = exportCache
        return true
    }

    mutating func fail(_ requestID: Int) -> Bool {
        guard owns(requestID), !Task.isCancelled else { return false }
        lines = []
        exportCache = ""
        return true
    }

    mutating func finish(_ requestID: Int) {
        guard owns(requestID) else { return }
        isLoading = false
    }
}

private struct LogRowView: View {
    let line: LogLine
    let includeSubsystem: Bool
    let dateFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(logBadge(for: line.level))
                .font(.caption2.weight(.bold))
                .foregroundStyle(logColor(for: line.level))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .skyAwareChip(cornerRadius: SkyAwareRadius.chipCompact, tint: logColor(for: line.level).opacity(0.16))
            VStack(alignment: .leading, spacing: 2) {
                Text(line.message)
                    .font(.callout)
                    .lineLimit(6)
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
    case .debug:   return "Debug"
    case .info:    return "Info"
    case .notice:  return "Ok"
    case .error:   return "Error"
    case .fault:   return "Fault"
    case .undefined:
        return "Unknown"
    @unknown default: return "Other"
    }
}

private func logColor(for level: OSLogEntryLog.Level) -> Color {
    switch level {
    case .debug: return .secondary
    case .info: return .blue
    case .notice: return .green
    case .error: return .orange
    case .fault: return .red
    case .undefined: return .secondary
    @unknown default: return .secondary
    }
}

// MARK: - OSLogStore bridge (async-friendly)

private func fetchLogs(since seconds: TimeInterval,
                       subsystem: String?,
                       contains: String?,
                       maxEntries: Int) async throws -> [LogLine] {
    // OSLogStore is sync; wrap in Task to avoid blocking main.
    try await runDetachedLogScan {
        try Task.checkCancellation()
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let start = store.position(date: Date().addingTimeInterval(-seconds))
        let entries = try store.getEntries(at: start)

        var result: [LogLine] = []
        result.reserveCapacity(256)

        for case let e as OSLogEntryLog in entries {
            try Task.checkCancellation()
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
        try Task.checkCancellation()
        // Newest last from the store; reverse so newest appears first in UI if you prefer.
        return Array(result.reversed())
    }
}

func runDetachedLogScan(
    _ scan: @escaping @Sendable () async throws -> [LogLine]
) async throws -> [LogLine] {
    let scanTask = Task.detached(priority: .utility) {
        try Task.checkCancellation()
        let result = try await scan()
        try Task.checkCancellation()
        return result
    }

    return try await withTaskCancellationHandler(operation: {
        let result = try await scanTask.value
        try Task.checkCancellation()
        return result
    }, onCancel: {
        scanTask.cancel()
    })
}
