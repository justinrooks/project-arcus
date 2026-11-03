// Generate only in a standalone process, never in the app/test module alongside the current model.
// xcrun swiftc -parse-as-library -module-name SkyAwareTests tools/fixtures/generate_bg_health_v1.swift -o /tmp/bg-v1
// /tmp/bg-v1 generate /tmp/bg-v1.sqlite
// /tmp/bg-v1 encode /tmp/bg-v1.sqlite
// Update the test's embedded base64 and uncompressed SHA-256 together. A new store has a new UUID/hash.

#if os(macOS)
import CryptoKit
import Foundation
import SQLite3
import SwiftData

// Frozen V1 schema from aa9150b; never add current diagnostic fields to this model.
enum BgRunSnapshotSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] { [BgRunSnapshot.self] }

    @Model
    final class BgRunSnapshot {
        @Attribute(.unique) var runId: String
        var startedAt: Date
        var endedAt: Date
        var outcomeCode: Int
        var didNotify: Bool
        var reasonNoNotify: String?
        var budgetSecUsed: Int
        var nextScheduledAt: Date
        var cadence: Int
        var cadenceReason: String?
        var activeSeconds: Int64

        init(
            runId: String,
            startedAt: Date,
            endedAt: Date,
            outcomeCode: Int,
            didNotify: Bool,
            reasonNoNotify: String?,
            budgetSecUsed: Int,
            nextScheduledAt: Date,
            cadence: Int,
            cadenceReason: String?,
            activeSeconds: Int64
        ) {
            self.runId = runId
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.outcomeCode = outcomeCode
            self.didNotify = didNotify
            self.reasonNoNotify = reasonNoNotify
            self.budgetSecUsed = budgetSecUsed
            self.nextScheduledAt = nextScheduledAt
            self.cadence = cadence
            self.cadenceReason = cadenceReason
            self.activeSeconds = activeSeconds
        }
    }
}

@main
private enum GenerateLegacyBackgroundHealth {
    @MainActor
    static func main() throws {
        guard CommandLine.arguments.count == 3,
              ["generate", "encode"].contains(CommandLine.arguments[1]) else {
            FileHandle.standardError.write(Data("Usage: bg-v1 <generate|encode> <new-store.sqlite>\n".utf8))
            exit(64)
        }
        let url = URL(fileURLWithPath: CommandLine.arguments[2])
        if CommandLine.arguments[1] == "encode" {
            try checkpoint(url)
            let data = try Data(contentsOf: url)
            let compressed = try (data as NSData).compressed(using: .zlib) as Data
            print("SHA-256: \(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())")
            print(compressed.base64EncodedString(options: .lineLength76Characters))
            return
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        let schema = Schema(versionedSchema: BgRunSnapshotSchemaV1.self)
        let configuration = ModelConfiguration("SkyAware_Data", schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        context.insert(BgRunSnapshotSchemaV1.BgRunSnapshot(
            runId: "legacy-run", startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_010), outcomeCode: 0, didNotify: true,
            reasonNoNotify: nil, budgetSecUsed: 10, nextScheduledAt: Date(timeIntervalSince1970: 2_200),
            cadence: 20, cadenceReason: "legacy", activeSeconds: 8
        ))
        try context.save()
        print("Saved V1 store. Encode in a separate invocation after this process closes the store/WAL.")
    }

    private static func checkpoint(_ url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(database) }
        guard sqlite3_wal_checkpoint_v2(database, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil) == SQLITE_OK else {
            throw CocoaError(.fileReadUnknown)
        }
    }
}
#endif
