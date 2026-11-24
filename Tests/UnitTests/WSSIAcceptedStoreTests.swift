import Foundation
import SwiftData
import Testing
@testable import SkyAware

struct WSSIAcceptedStoreTests {
    private enum SaveFailure: Error { case injected }

    @Test
    func fifteenSlotsSurviveMigrationReplacementAndReopen() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("production.store")
        let fixtures = try Fixtures()
        let originalManifest = try Fixtures.manifest(fixtures.entries)
        let original = try WSSISourceDecoder.manifest(from: originalManifest)
        let legacyID = try seedVersion7(at: url)
        var sizeReport: [String] = []
        let selected = try #require(original.datasets.first)

        do {
            let container = try reopen(url)
            let legacy = try ModelContext(container).fetch(FetchDescriptor<SPCAcceptedDay1Convective>())
            #expect(legacy.map(\.id) == [legacyID])
            let store = WSSIAcceptedStore(modelContainer: container)
            #expect(try await store.manifest() == nil)
            let saved = try await store.saveManifest(originalManifest, eTag: #""m1""#, replacing: nil)
            var bytes = 0
            for (index, entry) in original.datasets.enumerated() {
                let geometry = try fixtures.geometry(fixtures.entries[index])
                bytes += geometry.count
                try await store.acceptGeometry(geometry, eTag: index.isMultiple(of: 2) ? #""g1""# : nil,
                                               product: entry.product, day: entry.day,
                                               manifestGeneration: saved.generation)
            }
            sizeReport.append("Initial commit: logical geometry \(bytes) bytes, \(try sizes(at: url))")
        }

        var revisedEntries = fixtures.entries
        revisedEntries[0] = try Fixtures.revised(revisedEntries[0], retrievedAt: "2026-11-24T19:15:00Z")
        revisedEntries[1] = try Fixtures.revised(revisedEntries[1], retrievedAt: "2026-11-24T19:15:00Z", issuedAt: "2026-11-24T17:00:00Z")
        let revisedBody = try Fixtures.manifest(revisedEntries, freshness: "Incomplete")
        let replacement = try fixtures.geometry(revisedEntries[0])
        let pending = try fixtures.geometry(revisedEntries[1])

        do {
            let container = try reopen(url)
            let store = WSSIAcceptedStore(modelContainer: container)
            let saved = try #require(try await store.manifest())
            #expect(saved.eTag == #""m1""#)
            #expect(saved.document.pollFreshness == .scheduled)
            #expect(saved.document.datasets.allSatisfy {
                $0.validity == .valid && $0.sourceStatus == .available && $0.pollHealth == .successful
            })
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<WSSIAcceptedSlot>()) == 15)
            for (index, entry) in original.datasets.enumerated() {
                let slot = try #require(try await store.slot(product: entry.product, day: entry.day))
                #expect(slot.revision == entry.accepted)
                #expect(slot.coverage == entry.coverage)
                #expect(slot.geometry == (try fixtures.geometry(fixtures.entries[index])))
                #expect(slot.eTag == (index.isMultiple(of: 2) ? #""g1""# : nil))
            }
            let new = try await store.saveManifest(revisedBody, eTag: #""m2""#, replacing: saved.generation)
            await #expect(throws: WSSIAcceptedStore.Rejection.supersededManifest) {
                try await store.saveManifest(originalManifest, eTag: #""late""#, replacing: saved.generation)
            }
            await #expect(throws: WSSIAcceptedStore.Rejection.supersededManifest) {
                try await store.acceptGeometry(replacement, eTag: nil, product: selected.product, day: selected.day,
                                               manifestGeneration: saved.generation)
            }
            try await store.acceptGeometry(replacement, eTag: nil, product: selected.product, day: selected.day,
                                           manifestGeneration: new.generation)
        }

        do {
            let store = WSSIAcceptedStore(modelContainer: try reopen(url), save: { _ in throw SaveFailure.injected })
            let current = try #require(try await store.manifest())
            let next = current.document.datasets[1]
            #expect(current.eTag == #""m2""#)
            #expect(current.document.pollFreshness == .incomplete)
            await #expect(throws: SaveFailure.injected) {
                try await store.acceptGeometry(pending, eTag: nil, product: next.product, day: next.day,
                                               manifestGeneration: current.generation)
            }
            let prior = try #require(try await store.slot(product: next.product, day: next.day))
            #expect(prior.revision == original.datasets[1].accepted)
        }

        do {
            let container = try reopen(url)
            let store = WSSIAcceptedStore(modelContainer: container)
            let current = try #require(try await store.manifest())
            #expect(current.eTag == #""m2""#)
            #expect(current.document.datasets.count == 15)
            let accepted = try #require(try await store.slot(product: selected.product, day: selected.day))
            #expect(accepted.revision == current.document.datasets[0].accepted)
            #expect(accepted.geometry == replacement)
            #expect(accepted.validity(at: accepted.revision.validFrom.addingTimeInterval(-1)) == .notYetValid)
            #expect(accepted.validity(at: accepted.revision.validFrom) == .valid)
            #expect(accepted.validity(at: accepted.revision.validTo) == .expired)
            let outstanding = current.document.datasets[1]
            let retained = try #require(try await store.slot(product: outstanding.product, day: outstanding.day))
            #expect(retained.revision != outstanding.accepted)
            #expect(retained.revision == original.datasets[1].accepted)
            #expect(retained.geometry == (try fixtures.geometry(fixtures.entries[1])))
            let interrupted = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                try await store.acceptGeometry(pending, eTag: nil, product: outstanding.product,
                                               day: outstanding.day, manifestGeneration: current.generation)
            }
            await #expect(throws: CancellationError.self) { try await interrupted.value }
            let afterCancellation = try #require(try await store.slot(product: outstanding.product, day: outstanding.day))
            #expect(afterCancellation.revision == retained.revision)
            #expect(try ModelContext(container).fetchCount(FetchDescriptor<WSSIAcceptedSlot>()) == 15)
            sizeReport.append("Consolidated reopen: \(try sizes(at: url))")
            Attachment.record(sizeReport.joined(separator: "\n"), named: "WSSIProductionStoreSizes.txt")

            // A stale source revision can appear in a later response with a fresh request generation.
            let staleBody = try Fixtures.manifest(fixtures.entries, freshness: "Unknown")
            let stale = try await store.saveManifest(staleBody, eTag: nil, replacing: current.generation)
            let oldGeometry = try fixtures.geometry(fixtures.entries[0])
            await #expect(throws: WSSIAcceptedStore.Rejection.staleRevision) {
                try await store.acceptGeometry(oldGeometry, eTag: nil, product: selected.product, day: selected.day,
                                               manifestGeneration: stale.generation)
            }
            let stillAccepted = try #require(try await store.slot(product: selected.product, day: selected.day))
            #expect(stillAccepted.geometry == replacement)
        }

        let store = WSSIAcceptedStore(modelContainer: try reopen(url))
        let unconditional = try #require(try await store.manifest())
        #expect(unconditional.document.pollFreshness == .unknown)
        #expect(unconditional.eTag == nil)
    }

    @Test
    func statusAndInvalidGeometryLeaveAcceptedBytesUntouched() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("production.store")
        let fixtures = try Fixtures()
        let body = try Fixtures.manifest(fixtures.entries)
        let geometry = try fixtures.geometry(fixtures.entries[0])
        var malformedEntries = fixtures.entries
        var misaddressed = try #require(malformedEntries[0]["accepted"] as? [String: Any])
        misaddressed["geometryPath"] = "/wrong-revision"
        malformedEntries[0]["accepted"] = misaddressed
        let malformed = try Fixtures.manifest(malformedEntries)
        do {
            let context = ModelContext(try reopen(url))
            context.insert(WSSIStoredManifest(body: malformed, eTag: #""orphaned""#))
            try context.save()
        }

        do {
            let store = WSSIAcceptedStore(modelContainer: try reopen(url))
            #expect(try await store.manifest() == nil)
            let first = try await store.saveManifest(body, eTag: nil, replacing: nil)
            let selected = try #require(first.document.datasets.first)
            try await store.acceptGeometry(geometry, eTag: #""original""#, product: selected.product,
                                           day: selected.day, manifestGeneration: first.generation)
            var entries = fixtures.entries
            entries[0]["validity"] = "Expired"
            entries[0]["sourceStatus"] = "Unavailable"
            entries[0]["pollHealth"] = "Failed"
            entries[1]["validity"] = "NeverAccepted"
            entries[1]["accepted"] = NSNull()
            entries[1]["sourceStatus"] = "Unknown"
            entries[1]["pollHealth"] = "Unknown"
            entries[2]["validity"] = "NotYetValid"
            let changed = try await store.saveManifest(Fixtures.manifest(entries, freshness: "Overdue"),
                                                       eTag: #""status""#, replacing: first.generation)
            await #expect(throws: WSSISourceDecoder.Error.invalidManifest) {
                try await store.saveManifest(malformed, eTag: #""wrong""#, replacing: changed.generation)
            }
            await #expect(throws: (any Error).self) {
                try await store.acceptGeometry(Data(), eTag: nil, product: selected.product, day: selected.day,
                                               manifestGeneration: changed.generation)
            }

            // Trailing whitespace decodes as the same revision but changes the immutable representation.
            var conflicting = geometry
            conflicting.append(0x20)
            await #expect(throws: WSSIAcceptedStore.Rejection.conflictingRevision) {
                try await store.acceptGeometry(conflicting, eTag: nil, product: selected.product, day: selected.day,
                                               manifestGeneration: changed.generation)
            }
            try await store.acceptGeometry(geometry, eTag: #""different""#, product: selected.product, day: selected.day,
                                           manifestGeneration: changed.generation)
        }

        let store = WSSIAcceptedStore(modelContainer: try reopen(url))
        let current = try #require(try await store.manifest())
        #expect(current.eTag == #""status""#)
        #expect(current.document.pollFreshness == .overdue)
        let selected = current.document.datasets[0]
        #expect(selected.validity == .expired)
        #expect(selected.sourceStatus == .unavailable)
        #expect(selected.pollHealth == .failed)
        #expect(current.document.datasets[1].validity == .neverAccepted)
        #expect(current.document.datasets[1].sourceStatus == .unknown)
        #expect(current.document.datasets[1].pollHealth == .unknown)
        #expect(current.document.datasets[2].validity == .notYetValid)
        var expected = try WSSISourceDecoder.manifest(from: body).datasets.map(\.accepted)
        expected[1] = nil
        #expect(current.document.datasets.map(\.accepted) == expected)
        let accepted = try #require(try await store.slot(product: selected.product, day: selected.day))
        #expect(accepted.revision == selected.accepted)
        #expect(accepted.geometry == geometry)
        #expect(accepted.eTag == #""original""#)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func seedVersion7(at url: URL) throws -> UUID {
        let schema = Schema(versionedSchema: SkyAwarePersistenceSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        let context = ModelContext(container)
        let prior = SPCAcceptedDay1Convective(issued: nil, valid: nil, expires: nil,
                                             acceptedAt: .now, stormCount: 0, severeCount: 0)
        context.insert(prior)
        try context.save()
        return prior.id
    }

    private func reopen(_ url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SkyAwarePersistenceSchema.self)
        return try ModelContainer(for: schema, migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                                  configurations: ModelConfiguration(schema: schema, url: url))
    }

    private func sizes(at url: URL) throws -> String {
        let keys: Set<URLResourceKey> = [.fileAllocatedSizeKey]
        let sqlite = try url.resourceValues(forKeys: keys).fileAllocatedSize ?? 0
        let walURL = URL(fileURLWithPath: url.path + "-wal")
        let wal = (try? walURL.resourceValues(forKeys: keys).fileAllocatedSize) ?? 0
        return "SQLite \(sqlite) allocated bytes, WAL \(wal) allocated bytes"
    }
}

private struct Fixtures {
    let entries: [[String: Any]]
    let captured: [String: Any]

    init() throws {
        let url = try #require(Bundle(for: WSSIStoreFixtureLocator.self).url(forResource: "overall-1", withExtension: "geojson"))
        captured = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let metadata = try #require(captured["metadata"] as? [String: Any])
        // Reuse full-resolution captured shapes with independently identified source-defined slots.
        entries = WSSIProduct.allCases.flatMap { product in
            (1...3).map { day in
                var accepted = metadata
                let revision = UUID()
                accepted["revision"] = revision.uuidString
                accepted["geometryPath"] = Self.path(product: product.rawValue, day: day, revision: revision)
                for key in ["product", "day", "coverage"] { accepted.removeValue(forKey: key) }
                if day == 2 { accepted.removeValue(forKey: "gisFileDate") }
                if day == 3 { accepted.removeValue(forKey: "gisIngestDate") }
                return ["product": product.rawValue, "day": day, "coverage": "unknown",
                        "validity": "Valid", "sourceStatus": "Available", "pollHealth": "Successful",
                        "accepted": accepted]
            }
        }
    }

    static func revised(
        _ entry: [String: Any], retrievedAt: String, issuedAt: String? = nil
    ) throws -> [String: Any] {
        var entry = entry
        var accepted = try #require(entry["accepted"] as? [String: Any])
        let product = try #require(entry["product"] as? String)
        let day = try #require(entry["day"] as? Int)
        let revision = UUID()
        accepted["revision"] = revision.uuidString
        accepted["geometryPath"] = path(product: product, day: day, revision: revision)
        if let issuedAt { accepted["issuedAt"] = issuedAt }
        accepted["retrievedAt"] = retrievedAt
        accepted["gisFileDate"] = "2026-11-24T17:15:00Z"
        entry["accepted"] = accepted
        return entry
    }

    static func manifest(_ entries: [[String: Any]], freshness: String = "Scheduled") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["datasets": entries, "pollFreshness": freshness])
    }

    func geometry(_ entry: [String: Any]) throws -> Data {
        var object = captured
        var metadata = try #require(entry["accepted"] as? [String: Any])
        metadata.removeValue(forKey: "geometryPath")
        for key in ["product", "day", "coverage"] { metadata[key] = entry[key] }
        object["metadata"] = metadata
        return try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
    }

    private static func path(product: String, day: Int, revision: UUID) -> String {
        "/v1/wssi/\(product)/days/\(day)/revisions/\(revision.uuidString.lowercased())/geometry"
    }
}

private final class WSSIStoreFixtureLocator: NSObject {}
