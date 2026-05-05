import Testing
@testable import SkyAware
import SwiftData
import Foundation

private struct UnavailableArcusClient: ArcusClient {
    func fetchActiveAlerts(for county: String, and fire: String, and forecast: String, in cell: Int64?) async throws -> Data {
        throw ArcusError.networkError(status: 503)
    }

    func fetchAlert(id: String, revisionSent: Date?) async throws -> Data {
        throw ArcusError.networkError(status: 503)
    }
}

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

    private func makeWatch(
        number: String,
        issued: Date,
        effective: Date,
        validEnd: Date,
        ugcZones: [String] = ["ALC013", "ALC025", "ALC035", "ALC041", "ALC099", "ALC129", "ALC131"],
        cells: [Int64] = [],
        status: String = "Actual",
        messageType: String = "Update",
        event: String = "Tornado Watch",
        geometry: DeviceAlertGeometry? = nil
    ) -> Watch {
        let iso = ISO8601DateFormatter()
        return Watch(
            nwsId: number,
            messageId: number,
            areaDesc: "Butler, AL; Clarke, AL; Conecuh, AL; Crenshaw, AL; Monroe, AL; Washington, AL; Wilcox, AL",
            ugcZones: ugcZones,
            sent: issued,
            effective: effective,
            onset: iso.date(from: "2025-11-25T22:20:00Z")!,
            expires: validEnd,
            ends: validEnd,
            status: status,
            messageType: messageType,
            severity: "Extreme",
            certainty: "Possible",
            urgency: "Future",
            event: event,
            headline: "Tornado Watch issued Nov 25 at 4:20 PM CST until Nov 25 at 6:00 PM CST by NWS Mobile AL",
            watchDescription: "TORNADO WATCH remains valid until 6 PM CST this evening. Primary threats include a couple tornadoes possible and damaging winds.",
            sender: "w-nws.webmaster@noaa.gov",
            instruction: "Take shelter in an interior room. Avoid windows. If in a mobile home, move to a sturdier shelter.",
            response: "Monitor",
            cells: cells,
            geometry: geometry,
            tornadoDetection: nil,
            tornadoDamageThreat: nil,
            maxWindGust: nil,
            maxHailSize: nil,
            windThreat: nil,
            hailThreat: nil,
            thunderstormDamageThreat: nil,
            flashFloodDetection: nil,
            flashFloodDamageThreat : nil
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

        let hits = try await repo.active(
            countyCode: "ALC013",
            fireZone: "COZ245",
            forecastZone: "COZ245",
            cell: nil,
            on: now
        )
        let ids = Set(hits.map { $0.id })

        #expect(ids.contains("1\(tag)"))
        #expect(!ids.contains("2\(tag)"))
        #expect(!ids.contains("3\(tag)"))
    }

    @Test("Keeps cell-based matches even when UGC metadata is absent")
    func matchesCellOnlyWatch() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let cell: Int64 = 613725958748241919
        let tag = "-C"

        let cellOnly = makeWatch(
            number: "1\(tag)",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            ugcZones: [],
            cells: [cell]
        )

        ctx.insert(cellOnly)
        try ctx.save()

        let hits = try await repo.active(
            countyCode: "ZZZ000",
            fireZone: "ZZZ000",
            forecastZone: "ZZZ000",
            cell: cell,
            on: now
        )

        #expect(hits.map(\.id) == ["1\(tag)"])
    }

    @Test("active excludes non-renderable lifecycle rows")
    func active_excludesTerminalLifecycleRows() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!

        let activeWatch = makeWatch(
            number: "active",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert"
        )
        let cancelled = makeWatch(
            number: "cancelled",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Cancelled",
            messageType: "Cancel"
        )
        let superseded = makeWatch(
            number: "superseded",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Superseded",
            messageType: "Update"
        )

        ctx.insert(activeWatch)
        ctx.insert(cancelled)
        ctx.insert(superseded)
        try ctx.save()

        let hits = try await repo.active(
            countyCode: "ALC013",
            fireZone: "COZ245",
            forecastZone: "COZ245",
            cell: nil,
            on: now
        )

        #expect(hits.map(\.id) == ["active"])
    }

    @Test("Matches forecast-zone UGCs when county and fire zones do not match")
    func matchesForecastZoneUGC() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let tag = "-F"

        let forecastOnly = makeWatch(
            number: "1\(tag)",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            ugcZones: ["COZ245"]
        )

        ctx.insert(forecastOnly)
        try ctx.save()

        let hits = try await repo.active(
            countyCode: "ZZZ000",
            fireZone: "ZZZ001",
            forecastZone: "COZ245",
            cell: nil,
            on: now
        )

        #expect(hits.map(\.id) == ["1\(tag)"])
    }

    @Test("Active warning geometry includes supported warnings with geometry")
    func activeWarningGeometries_includesSupportedWarningsWithGeometry() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let geometry = testPolygonGeometry()

        let tornado = makeWatch(
            number: "warning-tor",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let severe = makeWatch(
            number: "warning-svr",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Update",
            event: "Severe Thunderstorm Warning",
            geometry: geometry
        )
        let flood = makeWatch(
            number: "warning-ffw",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert",
            event: "Flash Flood Warning",
            geometry: geometry
        )

        ctx.insert(tornado)
        ctx.insert(severe)
        ctx.insert(flood)
        try ctx.save()

        let geometries = try await repo.activeWarningGeometries(on: now)
        let ids = Set(geometries.map(\.id))

        #expect(ids == Set(["warning-ffw", "warning-svr", "warning-tor"]))
        #expect(geometries.allSatisfy { $0.geometry == geometry })
    }

    @Test("Active warning geometry excludes watches unsupported events and nil geometry")
    func activeWarningGeometries_excludesUnsupportedAndNilGeometry() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let geometry = testPolygonGeometry()

        let watch = makeWatch(
            number: "watch",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Watch",
            geometry: geometry
        )
        let unsupported = makeWatch(
            number: "unsupported",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert",
            event: "Special Weather Statement",
            geometry: geometry
        )
        let missingGeometry = makeWatch(
            number: "nil-geometry",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Warning"
        )

        ctx.insert(watch)
        ctx.insert(unsupported)
        ctx.insert(missingGeometry)
        try ctx.save()

        let geometries = try await repo.activeWarningGeometries(on: now)

        #expect(geometries.isEmpty)
    }

    @Test("Active warning geometry excludes expired canceled and non-active warnings")
    func activeWarningGeometries_excludesInactiveLifecycle() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let geometry = testPolygonGeometry()

        let expired = makeWatch(
            number: "expired",
            issued: now.addingTimeInterval(-7200),
            effective: now.addingTimeInterval(-7200),
            validEnd: now.addingTimeInterval(-10),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let canceledMessage = makeWatch(
            number: "canceled-message",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Cancel",
            event: "Tornado Warning",
            geometry: geometry
        )
        let cancelledState = makeWatch(
            number: "cancelled-state",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Cancelled",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let nonActiveState = makeWatch(
            number: "expired-state",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Expired",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let futureEffective = makeWatch(
            number: "future-effective",
            issued: now.addingTimeInterval(-60),
            effective: now.addingTimeInterval(600),
            validEnd: now.addingTimeInterval(1200),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let supersededState = makeWatch(
            number: "superseded-state",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Superseded",
            messageType: "Update",
            event: "Tornado Warning",
            geometry: geometry
        )

        ctx.insert(expired)
        ctx.insert(canceledMessage)
        ctx.insert(cancelledState)
        ctx.insert(nonActiveState)
        ctx.insert(futureEffective)
        ctx.insert(supersededState)
        try ctx.save()

        let geometries = try await repo.activeWarningGeometries(on: now)

        #expect(geometries.isEmpty)
    }

    @Test("Active warning geometry query returns latest stored geometry from SwiftData")
    func activeWarningGeometries_returnsLatestStoredGeometry() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let initialGeometry = testPolygonGeometry()
        let latestGeometry: DeviceAlertGeometry = .polygon(
            rings: [
                [
                    DeviceAlertCoordinate(longitude: -105.0200, latitude: 39.7000),
                    DeviceAlertCoordinate(longitude: -104.7000, latitude: 39.7000),
                    DeviceAlertCoordinate(longitude: -104.7000, latitude: 39.9500),
                    DeviceAlertCoordinate(longitude: -105.0200, latitude: 39.9500),
                    DeviceAlertCoordinate(longitude: -105.0200, latitude: 39.7000)
                ]
            ]
        )

        let watch = makeWatch(
            number: "latest-warning",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(900),
            status: "Active",
            messageType: "Update",
            event: "Tornado Warning",
            geometry: initialGeometry
        )

        ctx.insert(watch)
        try ctx.save()

        watch.messageId = "urn:test:latest"
        watch.currentRevisionSent = now.addingTimeInterval(120)
        watch.geometry = latestGeometry
        try ctx.save()

        let geometries = try await repo.activeWarningGeometries(on: now)
        let warning = try #require(geometries.first(where: { $0.id == "latest-warning" }))

        #expect(geometries.count == 1)
        #expect(warning.messageId == "urn:test:latest")
        #expect(warning.currentRevisionSent == now.addingTimeInterval(120))
        #expect(warning.geometry == latestGeometry)
    }

    @Test("Provider active warning geometry query reads local SwiftData without network")
    func providerActiveWarningGeometries_usesLocalRepoWithoutNetwork() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let geometry = testPolygonGeometry()
        let warning = makeWatch(
            number: "provider-warning",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )

        ctx.insert(warning)
        try ctx.save()

        let provider = ArcusAlertProvider(watchRepo: repo, client: UnavailableArcusClient())
        let geometries = try await provider.getActiveWarningGeometries(on: now)

        #expect(geometries.map(\.id) == ["provider-warning"])
        #expect(geometries.first?.geometry == geometry)
    }

    private func testPolygonGeometry() -> DeviceAlertGeometry {
        .polygon(
            rings: [
                [
                    DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.7392),
                    DeviceAlertCoordinate(longitude: -104.8200, latitude: 39.7392),
                    DeviceAlertCoordinate(longitude: -104.8200, latitude: 39.8800),
                    DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.8800),
                    DeviceAlertCoordinate(longitude: -104.9903, latitude: 39.7392)
                ]
            ]
        )
    }
}
