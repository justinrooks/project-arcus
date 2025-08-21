//
//  DataExplorer.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/20/25.
//

// DebugFeedCacheView_iOS.swift
// SkyAware — iOS-only SwiftData inspector for FeedCache (DEBUG builds only)

#if DEBUG
import SwiftUI
import SwiftData
import UIKit
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Quick attach: toolbar button → sheet
struct DebugFeedCacheButton: ViewModifier {
    @State private var showInspector = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInspector = true
                    } label: {
                        Label("Cache", systemImage: "externaldrive")
                    }
                    .accessibilityIdentifier("DebugFeedCacheButton")
                }
            }
            .sheet(isPresented: $showInspector) {
                NavigationStack { DebugFeedCacheView() }
            }
    }
}

public extension View {
    func debugFeedCacheButton() -> some View {
        modifier(DebugFeedCacheButton())
    }
}

// MARK: - Main list
struct DebugFeedCacheView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\FeedCache.updatedAt, order: .reverse)])
    private var items: [FeedCache]

    @State private var searchText = ""
    @State private var selected: FeedCache?
    @State private var isExporting = false
    @State private var exportURL: URL?

    var body: some View {
        List {
            Section("Summary") {
                summaryRow("Rows", "\(items.count)")
                summaryRow("Total Body Size",
                           items.reduce(0) { $0 + ($1.body?.count ?? 0) }.prettyBytes)
            }

            Section("FeedCache") {
                ForEach(filtered(items)) { cache in
                    Button { selected = cache } label: { FeedCacheRow(cache: cache) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(cache)
                            } label: { Label("Delete", systemImage: "trash") }

                            Button {
                                UIPasteboard.general.string = cache.jsonString()
                            } label: { Label("Copy JSON", systemImage: "doc.on.doc") }
                        }
                }
                .onDelete(perform: delete(at:))
            }
        }
        .navigationTitle("Cache Inspector")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search feedKey, ETag, Last-Modified")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { insertSample() } label: {
                    Label("Insert Sample", systemImage: "plus.circle")
                }
                Button(role: .destructive) { deleteAll() } label: {
                    Label("Delete All", systemImage: "trash")
                }
                Spacer()
                Button { exportAll() } label: {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $selected) { cache in
            NavigationStack { FeedCacheDetail(cache: cache) }
                .presentationDetents([.medium, .large])
        }
        .onDisappear { try? context.save() }
        .shareExporter(url: $exportURL, isExporting: $isExporting)
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Label(title, systemImage: "info.circle")
            Spacer()
            Text(value).font(.body.monospaced())
        }
    }

    private func filtered(_ src: [FeedCache]) -> [FeedCache] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return src }
        return src.filter { c in
            c.feedKey.lowercased().contains(q)
            || (c.etag ?? "").lowercased().contains(q)
            || (c.lastModified ?? "").lowercased().contains(q)
        }
    }

    @MainActor private func insertSample() {
        let demo = FeedCache(feedKey: "demo.\(UUID().uuidString.prefix(6))")
        demo.etag = "W/\"\(Int.random(in: 1000...9999))\""
        demo.lastModified = HTTPDateFormatter.rfc1123.string(from: .now.addingTimeInterval(-Double.random(in: 0...30_000)))
        demo.lastSuccessAt = .now.addingTimeInterval(-Double.random(in: 0...3600))
        demo.nextPlannedAt = .now.addingTimeInterval(Double.random(in: 600...7200))
        demo.body = Data((0..<Int.random(in: 128...4096)).map { _ in UInt8.random(in: 0...255) })
        demo.bodyHash = demo.body?.sha256Hex()
        demo.updatedAt = .now
        context.insert(demo)
        try? context.save()
    }

    @MainActor private func deleteAll() {
        items.forEach { context.delete($0) }
        try? context.save()
    }

    @MainActor private func delete(_ cache: FeedCache) {
        context.delete(cache)
        try? context.save()
    }

    @MainActor private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(items[index]) }
        try? context.save()
    }

    @MainActor private func exportAll() {
        do {
            let dto = items.map { $0.toDTO() }
            let data = try JSONEncoder.pretty.encode(dto)
            let url = try data.writeTempJSONFile(named: "FeedCache-export")
            exportURL = url
            isExporting = true
        } catch {
            UIPasteboard.general.string = items
                .map { $0.jsonString() }
                .joined(separator: "\n")
        }
    }
}

// MARK: - Row
private struct FeedCacheRow: View {
    let cache: FeedCache
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(cache.feedKey).font(.headline).lineLimit(1)
                Spacer()
                Text(cache.updatedAt.relative)
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(cache.bodySizeLabel, systemImage: "doc.richtext")
                if let lm = cache.lastModified {
                    Label(lm, systemImage: "clock").lineLimit(1).minimumScaleFactor(0.7)
                }
                if let et = cache.etag {
                    Label(et, systemImage: "tag").lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if let s = cache.lastSuccessAt { KeyValuePill("success", s.relative) }
                if let n = cache.nextPlannedAt { KeyValuePill("next", n.relative) }
                if let h = cache.bodyHash { KeyValuePill("hash", h.shortHex) }
            }
            .font(.caption2)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Detail
private struct FeedCacheDetail: View {
    @Environment(\.dismiss) private var dismiss
    let cache: FeedCache
    @State private var copied = false

    var body: some View {
        Form {
            Section("Identity") {
                KeyValueRow1("feedKey", cache.feedKey)
                KeyValueRow1("createdAt", cache.createdAt.iso8601)
                KeyValueRow1("updatedAt", cache.updatedAt.iso8601)
            }
            Section("Validators & Times") {
                KeyValueRow1("ETag", cache.etag ?? "—")
                KeyValueRow1("Last-Modified", cache.lastModified ?? "—")
                KeyValueRow1("lastSuccessAt", cache.lastSuccessAt?.iso8601 ?? "—")
                KeyValueRow1("nextPlannedAt", cache.nextPlannedAt?.iso8601 ?? "—")
            }
            Section("Body") {
                KeyValueRow1("size", cache.bodySizeLabel)
                KeyValueRow1("hash", cache.bodyHash ?? "—")
                if let body = cache.body, let asText = String(data: body, encoding: .utf8) {
                    LabeledContent("preview") {
                        ScrollView {
                            Text(asText)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                        .frame(minHeight: 120)
                    }
                } else {
                    Text("No UTF-8 preview available.").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("FeedCache")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = cache.jsonString()
                    copied = true
                } label: { Label("Copy JSON", systemImage: "doc.on.doc") }
            }
        }
        .overlay(alignment: .bottom) {
            if copied {
                CopiedToast()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        withAnimation { copied = false }
                    }
            }
        }
    }
}

// MARK: - Small UI bits
private struct KeyValueRow1: View {
    let key: String, value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.monospaced()).multilineTextAlignment(.trailing)
        }
    }
}

private struct KeyValuePill: View {
    let key: String, value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        HStack(spacing: 4) {
            Text(key)
            Text(value).fontWeight(.semibold)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
    }
}

private struct CopiedToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("Copied").font(.callout).fontWeight(.semibold)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .shadow(radius: 6)
        .padding(.bottom, 12)
    }
}

// MARK: - DTO + helpers
private struct FeedCacheDTO: Codable {
    var feedKey: String
    var etag: String?
    var lastModified: String?
    var lastSuccessAt: String?
    var nextPlannedAt: String?
    var bodyHash: String?
    var bodySize: Int
    var createdAt: String
    var updatedAt: String
}

private extension FeedCache {
    func toDTO() -> FeedCacheDTO {
        .init(
            feedKey: feedKey,
            etag: etag,
            lastModified: lastModified,
            lastSuccessAt: lastSuccessAt?.iso8601,
            nextPlannedAt: nextPlannedAt?.iso8601,
            bodyHash: bodyHash,
            bodySize: body?.count ?? 0,
            createdAt: createdAt.iso8601,
            updatedAt: updatedAt.iso8601
        )
    }

    func jsonString() -> String {
        (try? String(data: JSONEncoder.pretty.encode(toDTO()), encoding: .utf8)) ?? "{}"
    }

    var bodySizeLabel: String {
        (body?.count ?? 0).prettyBytes
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }
}

private extension Int {
    var prettyBytes: String {
        let units = ["B","KB","MB","GB","TB"]
        var size = Double(self)
        var idx = 0
        while size >= 1024 && idx < units.count - 1 {
            size /= 1024; idx += 1
        }
        return String(format: "%.1f %@", size, units[idx])
    }
}

private extension String {
    var shortHex: String {
        count > 12 ? "\(prefix(8))…\(suffix(4))" : self
    }
}

private extension Date {
    var iso8601: String { ISO8601DateFormatter().string(from: self) }

    var relative: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: self, relativeTo: .now)
    }
}

private enum HTTPDateFormatter {
    static let rfc1123: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
}

private extension Data {
    func sha256Hex() -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        // Simple non-cryptographic fallback for debug.
        var hash = 5381
        for b in self { hash = ((hash << 5) &+ hash) &+ Int(b) }
        return withUnsafeBytes(of: hash.bigEndian) { buf in
            buf.map { String(format: "%02x", $0) }.joined()
        }
        #endif
    }

    func writeTempJSONFile(named base: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(base)-\(UUID().uuidString.prefix(6)).json")
        try self.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Share exporter (iOS)
private struct ShareExporter: ViewModifier {
    @Binding var url: URL?
    @Binding var isExporting: Bool

    func body(content: Content) -> some View {
        content.background(ShareLinkWrapper(url: $url, isExporting: $isExporting))
    }

    private struct ShareLinkWrapper: View {
        @Binding var url: URL?
        @Binding var isExporting: Bool

        var body: some View {
            Group {
                if let url, isExporting {
                    ShareLink(item: url) { EmptyView() }
                        .onAppear {
                            // Reset after presenting once
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isExporting = false
                                self.url = nil
                            }
                        }
                }
            }
        }
    }
}

private extension View {
    func shareExporter(url: Binding<URL?>, isExporting: Binding<Bool>) -> some View {
        modifier(ShareExporter(url: url, isExporting: isExporting))
    }
}

// MARK: - Preview (in-memory SwiftData for iOS)
#Preview("Inspector (iOS)") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FeedCache.self, configurations: config)
    let ctx = ModelContext(container)

    let fc1 = FeedCache(feedKey: "outlook.day1")
    fc1.etag = "W/\"1234\""
    fc1.lastModified = "Wed, 20 Aug 2025 01:32:06 GMT"
    fc1.lastSuccessAt = .now.addingTimeInterval(-1800)
    fc1.nextPlannedAt = .now.addingTimeInterval(1800)
    fc1.body = Data("Hello World".utf8)
    fc1.bodyHash = fc1.body?.sha256Hex()
    ctx.insert(fc1)

    let fc2 = FeedCache(feedKey: "meso.index")
    fc2.etag = "W/\"5678\""
    fc2.lastModified = "Wed, 20 Aug 2025 00:05:01 GMT"
    fc2.lastSuccessAt = .now.addingTimeInterval(-7200)
    fc2.body = Data((0..<2048).map { _ in UInt8.random(in: 0...255) })
    fc2.bodyHash = fc2.body?.sha256Hex()
    ctx.insert(fc2)

    try? ctx.save()

    return NavigationStack { DebugFeedCacheView() }
        .modelContainer(container)
}
#endif
