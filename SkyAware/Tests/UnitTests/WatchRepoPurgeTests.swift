import Testing
@testable import SkyAware
import SwiftData
import Foundation

@Suite("WatchRepo purge()", .serialized)
struct WatchRepoPurgeTests {
    // Helper to quickly build a WatchModel
    private func makeWatch(number: String, issued: Date, validEnd: Date) -> Watch {
        let iso = ISO8601DateFormatter()
        return Watch(
            nwsId: number,
            messageId: number,
            areaDesc: "Butler, AL; Clarke, AL; Conecuh, AL; Crenshaw, AL; Monroe, AL; Washington, AL; Wilcox, AL",
            ugcZones: ["ALC013", "ALC025", "ALC035", "ALC041", "ALC099", "ALC129", "ALC131"],
            sameCodes: ["001013", "001025", "001035", "001041", "001099", "001129", "001131"],
            sent: issued,
            effective: iso.date(from: "2025-11-25T22:20:00Z")!,
            onset: iso.date(from: "2025-11-25T22:20:00Z")!,
            expires: validEnd,
            ends: validEnd,
            status: "Actual",
            messageType: "Update",
            severity: "Extreme",
            certainty: "Possible",
            urgency: "Future",
            event: "Tornado Watch",
            headline: "Tornado Watch issued Nov 25 at 4:20 PM CST until Nov 25 at 6:00 PM CST by NWS Mobile AL",
            watchDescription: "TORNADO WATCH remains valid until 6 PM CST this evening. Primary threats include a couple tornadoes possible and damaging winds.",
            sender: "w-nws.webmaster@noaa.gov",
            instruction: "Take shelter in an interior room. Avoid windows. If in a mobile home, move to a sturdier shelter.",
            response: "Monitor"
        )
    }

    private func fetchWatches(tag: String, in context: ModelContext) throws -> [Watch] {
        let descriptor = FetchDescriptor<Watch>(predicate: #Predicate { $0.nwsId.contains(tag) })
        return try context.fetch(descriptor)
    }

    private func fetchCount(tag: String, in context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<Watch>(predicate: #Predicate { $0.nwsId.contains(tag) })
        return try context.fetchCount(descriptor)
    }

    @Test("Deletes only records with validEnd < now (== now stays)")
    func deletesExpiredOnly() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [Watch.self]) }
        try await MainActor.run { try TestStore.reset(Watch.self, in: container) }
        let repo = WatchRepo(modelContainer: container)
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let tag = "-D"

        let expired = makeWatch(number: "1\(tag)", issued: now.addingTimeInterval(-3600), validEnd: now.addingTimeInterval(-1)) // < now
        let boundary = makeWatch(number: "2\(tag)", issued: now.addingTimeInterval(-3600), validEnd: now)                       // == now
        let future = makeWatch(number: "3\(tag)", issued: now.addingTimeInterval(-3600), validEnd: now.addingTimeInterval(60))  // > now

        ctx.insert(expired)
        ctx.insert(boundary)
        ctx.insert(future)
        try ctx.save()

        try await repo.purge(asOf: now)

        let remaining = try fetchWatches(tag: tag, in: ctx)
        let remainingIds = Set(remaining.map { $0.nwsId })
        #expect(!remainingIds.contains("1\(tag)"), "Expired (< now) should be deleted")
        #expect(remainingIds.contains("2\(tag)"), "Boundary (== now) should remain")
        #expect(remainingIds.contains("3\(tag)"), "Future (> now) should remain")
    }

    @Test("Deletes multiple expired records in one pass")
    func deletesMultipleExpired() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [Watch.self]) }
        try await MainActor.run { try TestStore.reset(Watch.self, in: container) }
        let repo = WatchRepo(modelContainer: container)
        let ctx = ModelContext(container)
        let now = Date()
        let tag = "-M"

        for i in 1...8 {
            let model = makeWatch(number: "\(i)\(tag)", issued: now.addingTimeInterval(-7200), validEnd: now.addingTimeInterval(-10))
            ctx.insert(model)
        }
        try ctx.save()

        try await repo.purge(asOf: now)

        let count = try fetchCount(tag: tag, in: ctx)
        #expect(count == 0, "All expired watches should be purged")
    }

    @Test("No-op when nothing is expired")
    func noExpired() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [Watch.self]) }
        try await MainActor.run { try TestStore.reset(Watch.self, in: container) }
        let repo = WatchRepo(modelContainer: container)
        let ctx = ModelContext(container)
        let now = Date()
        let tag = "-N"

        let boundary = makeWatch(number: "1\(tag)", issued: now.addingTimeInterval(-3600), validEnd: now)
        let future = makeWatch(number: "2\(tag)", issued: now.addingTimeInterval(-3600), validEnd: now.addingTimeInterval(60))
        ctx.insert(boundary)
        ctx.insert(future)
        try ctx.save()

        try await repo.purge(asOf: now)

        let remaining = try fetchWatches(tag: tag, in: ctx)
        let remainingIds = Set(remaining.map { $0.nwsId })
        #expect(remainingIds.contains("1\(tag)"))
        #expect(remainingIds.contains("2\(tag)"))
    }

    @Test("Idempotency: second purge immediately is a no-op")
    func idempotent() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [Watch.self]) }
        try await MainActor.run { try TestStore.reset(Watch.self, in: container) }
        let repo = WatchRepo(modelContainer: container)
        let ctx = ModelContext(container)
        let now = Date()
        let tag = "-I"

        let expired = makeWatch(number: "999\(tag)", issued: now.addingTimeInterval(-7200), validEnd: now.addingTimeInterval(-10))
        ctx.insert(expired)
        try ctx.save()

        try await repo.purge(asOf: now)
        var count = try fetchCount(tag: tag, in: ctx)
        #expect(count == 0)

        // Second purge should not throw and should keep store unchanged
        try await repo.purge(asOf: now)
        count = try fetchCount(tag: tag, in: ctx)
        #expect(count == 0)
    }
}
