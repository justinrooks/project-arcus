import Testing
@testable import SkyAware
import SwiftData
import Foundation

@Suite("WatchRepo purge()")
struct WatchRepoPurgeTests {
    let container: ModelContainer
    let repo: WatchRepo

    init() throws {
        // In-memory container with only the WatchModel schema to keep tests lightweight
        let schema = Schema([WatchModel.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        repo = WatchRepo(modelContainer: container)
    }

    // Helper to quickly build a WatchModel
    private func makeWatch(number: Int, issued: Date, validEnd: Date) -> WatchModel {
        WatchModel(
            number: number,
            title: "WW \(number)",
            link: URL(string: "https://example.com/ww\(number)")!,
            issued: issued,
            validStart: issued, // not relevant for purge, but required
            validEnd: validEnd,
            summary: "Test Watch \(number)",
            alertType: .watch
        )
    }

    @Test("Deletes only records with validEnd < now (== now stays)")
    func deletesExpiredOnly() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!

        let expired = makeWatch(number: 1, issued: now.addingTimeInterval(-3600), validEnd: now.addingTimeInterval(-1)) // < now
        let boundary = makeWatch(number: 2, issued: now.addingTimeInterval(-3600), validEnd: now)                       // == now
        let future = makeWatch(number: 3, issued: now.addingTimeInterval(-3600), validEnd: now.addingTimeInterval(60))  // > now

        ctx.insert(expired)
        ctx.insert(boundary)
        ctx.insert(future)
        try ctx.save()

        try await repo.purge(asOf: now)

        let remaining = try ctx.fetch(FetchDescriptor<WatchModel>())
        let remainingNumbers = Set(remaining.map { $0.number })
        #expect(!remainingNumbers.contains(1), "Expired (< now) should be deleted")
        #expect(remainingNumbers.contains(2), "Boundary (== now) should remain")
        #expect(remainingNumbers.contains(3), "Future (> now) should remain")
    }

    @Test("Purges in batches when more than 50 expired")
    func purgesInBatches() async throws {
        let ctx = ModelContext(container)
        let now = Date()

        // Insert more than the fetchLimit (50) to exercise the while-loop batching
        for i in 1...120 {
            let model = makeWatch(number: i, issued: now.addingTimeInterval(-7200), validEnd: now.addingTimeInterval(-10))
            ctx.insert(model)
        }
        try ctx.save()

        try await repo.purge(asOf: now)

        let count = try ctx.fetchCount(FetchDescriptor<WatchModel>())
        #expect(count == 0, "All expired watches should be purged across multiple batches")
    }

    @Test("Idempotency: second purge immediately is a no-op")
    func idempotent() async throws {
        let ctx = ModelContext(container)
        let now = Date()

        let expired = makeWatch(number: 999, issued: now.addingTimeInterval(-7200), validEnd: now.addingTimeInterval(-10))
        ctx.insert(expired)
        try ctx.save()

        try await repo.purge(asOf: now)
        var count = try ctx.fetchCount(FetchDescriptor<WatchModel>())
        #expect(count == 0)

        // Second purge should not throw and should keep store unchanged
        try await repo.purge(asOf: now)
        count = try ctx.fetchCount(FetchDescriptor<WatchModel>())
        #expect(count == 0)
    }
}
