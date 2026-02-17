import Testing
@testable import SkyAware
import SwiftData
import Foundation

@Suite("WatchRepo active()")
struct WatchRepoActiveTests {
    let container: ModelContainer
    let repo: WatchRepo

    init() throws {
        let schema = Schema([Watch.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        repo = WatchRepo(modelContainer: container)
    }

    private func makeWatch(number: String, issued: Date, effective: Date, validEnd: Date) -> Watch {
        let iso = ISO8601DateFormatter()
        return Watch(
            nwsId: number,
            messageId: number,
            areaDesc: "Butler, AL; Clarke, AL; Conecuh, AL; Crenshaw, AL; Monroe, AL; Washington, AL; Wilcox, AL",
            ugcZones: ["ALC013", "ALC025", "ALC035", "ALC041", "ALC099", "ALC129", "ALC131"],
            sameCodes: ["001013", "001025", "001035", "001041", "001099", "001129", "001131"],
            sent: issued,
            effective: effective,
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

    @Test("Filters out expired and not-yet-effective watches")
    func filtersByValidityWindow() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let tag = "-E"

        let active = makeWatch(number: "1\(tag)", issued: now.addingTimeInterval(-3600), effective: now.addingTimeInterval(-300), validEnd: now.addingTimeInterval(600))
        let expired = makeWatch(number: "2\(tag)", issued: now.addingTimeInterval(-7200), effective: now.addingTimeInterval(-7200), validEnd: now.addingTimeInterval(-10))
        let upcoming = makeWatch(number: "3\(tag)", issued: now.addingTimeInterval(-600), effective: now.addingTimeInterval(600), validEnd: now.addingTimeInterval(3600))

        ctx.insert(active)
        ctx.insert(expired)
        ctx.insert(upcoming)
        try ctx.save()

        let hits = try await repo.active(county: "ALC013", zone: "ALC013", fireZone: "COZ245", on: now)
        let ids = Set(hits.map { $0.id })

        #expect(ids.contains("1\(tag)"))
        #expect(!ids.contains("2\(tag)"))
        #expect(!ids.contains("3\(tag)"))
    }
}
