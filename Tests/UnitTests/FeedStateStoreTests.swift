import Foundation
import Testing
@testable import SkyAware

@Suite("FeedStateStore")
struct FeedStateStoreTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("round trips primitive feed metadata and advances generation only on acceptance")
    func roundTrip_persistsMetadata() async throws {
        let directory = try makeDirectory()
        let store = FeedStateStore(directoryURL: directory, nowProvider: { now })
        let update = FeedStateUpdate(
            feedID: "arcus.alerts",
            attemptedAt: now,
            networkSucceededAt: now,
            canonicalAcceptedAt: now,
            validAt: now,
            transportSource: .revalidated,
            failure: .transport
        )

        let saved = try await store.update(update)
        let reopened = FeedStateStore(directoryURL: directory, nowProvider: { now })

        #expect(saved.generation == 1)
        #expect(saved.lastAttemptAt == now)
        #expect(saved.lastNetworkSuccessAt == now)
        #expect(saved.lastCanonicalAcceptanceAt == now)
        #expect(saved.lastValidityAt == now)
        #expect(saved.lastTransportSource == .revalidated)
        #expect(saved.lastFailure == .transport)
        #expect(try await reopened.record(for: "arcus.alerts") == saved)
    }

    @Test("concurrent updates retain every feed deterministically")
    func updates_concurrentlyRetainsEveryFeed() async throws {
        let store = FeedStateStore(directoryURL: try makeDirectory(), maximumRecordCount: 128, nowProvider: { now })
        let feedIDs = (0..<64).map { "feed.\($0)" }

        await withTaskGroup(of: Void.self) { group in
            for feedID in feedIDs {
                group.addTask {
                    _ = try? await store.update(.init(feedID: feedID, attemptedAt: self.now))
                }
            }
        }

        for feedID in feedIDs {
            #expect(try await store.record(for: feedID)?.feedID == feedID)
        }
    }

    @Test("same-feed updates merge deterministically when attempts arrive out of order")
    func updates_sameFeedMergesDeterministically() async throws {
        let older = FeedStateUpdate(
            feedID: "arcus.alerts",
            attemptedAt: now.addingTimeInterval(-60),
            networkSucceededAt: now.addingTimeInterval(-60),
            canonicalAcceptedAt: now.addingTimeInterval(-60),
            validAt: now.addingTimeInterval(-60),
            transportSource: .live
        )
        let newer = FeedStateUpdate(
            feedID: "arcus.alerts",
            attemptedAt: now,
            transportSource: .errorFallback,
            failure: .transport
        )

        let firstStore = FeedStateStore(directoryURL: try makeDirectory(), nowProvider: { now })
        _ = try await firstStore.update(older)
        _ = try await firstStore.update(newer)
        let first = try #require(await firstStore.record(for: "arcus.alerts"))

        let secondStore = FeedStateStore(directoryURL: try makeDirectory(), nowProvider: { now })
        _ = try await secondStore.update(newer)
        _ = try await secondStore.update(older)
        let second = try #require(await secondStore.record(for: "arcus.alerts"))

        #expect(first == second)
        #expect(first.lastAttemptAt == now)
        #expect(first.lastNetworkSuccessAt == older.networkSucceededAt)
        #expect(first.lastCanonicalAcceptanceAt == older.canonicalAcceptedAt)
        #expect(first.lastValidityAt == older.validAt)
        #expect(first.lastTransportSource == .errorFallback)
        #expect(first.lastFailure == .transport)
        #expect(first.generation == 1)
    }

    @Test("prunes oldest records to the configured retention bound")
    func updates_prunesOldestRecords() async throws {
        let store = FeedStateStore(directoryURL: try makeDirectory(), maximumRecordCount: 2, nowProvider: { now })
        for offset in 0..<3 {
            let date = now.addingTimeInterval(TimeInterval(-offset))
            _ = try await store.update(.init(feedID: "feed.\(offset)", attemptedAt: date))
        }

        #expect(try await store.record(for: "feed.0") != nil)
        #expect(try await store.record(for: "feed.1") != nil)
        #expect(try await store.record(for: "feed.2") == nil)
    }

    @Test(arguments: [
        "attemptedAt",
        "networkSucceededAt",
        "canonicalAcceptedAt",
        "validAt"
    ])
    func updates_futureDatesFailSafely(field: String) async throws {
        let store = FeedStateStore(directoryURL: try makeDirectory(), nowProvider: { now })
        let original = try await store.update(.init(feedID: "spc.outlook", attemptedAt: now, transportSource: .live))
        let future = now.addingTimeInterval(1)
        let update: FeedStateUpdate
        switch field {
        case "attemptedAt":
            update = .init(feedID: "spc.outlook", attemptedAt: future)
        case "networkSucceededAt":
            update = .init(feedID: "spc.outlook", attemptedAt: now, networkSucceededAt: future)
        case "canonicalAcceptedAt":
            update = .init(feedID: "spc.outlook", attemptedAt: now, canonicalAcceptedAt: future)
        case "validAt":
            update = .init(feedID: "spc.outlook", attemptedAt: now, validAt: future)
        default:
            Issue.record("Unexpected field: \(field)")
            return
        }

        await #expect(throws: FeedStateStoreError.futureDate) {
            try await store.update(update)
        }
        #expect(try await store.record(for: "spc.outlook") == original)
    }

    @Test("corrupt and newer sidecars fail closed")
    func load_corruptOrNewerDataFailsSafely() async throws {
        let directory = try makeDirectory()
        let fileURL = directory.appendingPathComponent("feed-state.v1.json")
        try Data("not-json".utf8).write(to: fileURL, options: .atomic)
        let corruptStore = FeedStateStore(directoryURL: directory, nowProvider: { now })
        await #expect(throws: FeedStateStoreError.corruptData) {
            try await corruptStore.record(for: "spc.meso")
        }
        let recovered = try await corruptStore.update(.init(feedID: "spc.meso", attemptedAt: now))
        let reopened = FeedStateStore(directoryURL: directory, nowProvider: { now })
        #expect(try await reopened.record(for: "spc.meso") == recovered)

        let newerData = Data("{\"version\":2,\"records\":[{\"futureOnly\":true}]}".utf8)
        try newerData.write(to: fileURL, options: .atomic)
        let newerStore = FeedStateStore(directoryURL: directory, nowProvider: { now })
        await #expect(throws: FeedStateStoreError.unsupportedVersion(2)) {
            try await newerStore.record(for: "spc.meso")
        }
        await #expect(throws: FeedStateStoreError.unsupportedVersion(2)) {
            try await newerStore.update(.init(feedID: "spc.meso", attemptedAt: now))
        }
        #expect(try Data(contentsOf: fileURL) == newerData)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FeedStateStoreTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
