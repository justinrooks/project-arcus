import Testing
@testable import SkyAware
import SwiftData
import Foundation
import ArcusCore

private struct UnavailableArcusClient: ArcusClient {
    func fetchActiveAlerts(for county: String, and fire: String, and forecast: String, in cell: Int64?) async throws -> Data {
        throw ArcusError.networkError(status: 503)
    }

    func fetchAlert(id: String, revisionSent: Date?) async throws -> Data {
        throw ArcusError.networkError(status: 503)
    }
}

private struct MalformedArcusClient: ArcusClient {
    func fetchActiveAlerts(for county: String, and fire: String, and forecast: String, in cell: Int64?) async throws -> Data {
        Data("not-json".utf8)
    }

    func fetchAlert(id: String, revisionSent: Date?) async throws -> Data {
        Data("not-json".utf8)
    }
}

private struct FallbackArcusClient: ArcusClient {
    func fetchActiveAlerts(for county: String, and fire: String, and forecast: String, in cell: Int64?) async throws -> Data {
        Data("[]".utf8)
    }

    func fetchAlert(id: String, revisionSent: Date?) async throws -> Data {
        Data("[]".utf8)
    }

    func fetchAlertResponse(id: String, revisionSent: Date?) async throws -> HTTPResponse {
        .init(status: 200, headers: [:], data: Data("[]".utf8), source: .cacheFallback)
    }
}

private struct ResponseArcusClient: ArcusClient {
    let source: HTTPResponse.Source
    let payload: Data

    init(source: HTTPResponse.Source, payload: Data = Data("[]".utf8)) {
        self.source = source
        self.payload = payload
    }

    func fetchActiveAlerts(for county: String, and fire: String, and forecast: String, in cell: Int64?) async throws -> Data {
        payload
    }

    func fetchAlert(id: String, revisionSent: Date?) async throws -> Data {
        payload
    }

    func fetchActiveAlertsResponse(
        for county: String,
        and fire: String,
        and forecast: String,
        in cell: Int64?
    ) async throws -> HTTPResponse {
        .init(status: 200, headers: [:], data: payload, source: source)
    }

    func fetchAlertResponse(id: String, revisionSent: Date?) async throws -> HTTPResponse {
        .init(status: 200, headers: [:], data: payload, source: source)
    }
}

@Suite("AlertRepo active()")
struct AlertRepoActiveTests {
    let container: ModelContainer
    let repo: AlertRepo

    init() throws {
        let schema = Schema([Watch.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        repo = AlertRepo(modelContainer: container)
    }

    private func makeAlert(
        number: String,
        issued: Date,
        effective: Date,
        validEnd: Date,
        expires: Date? = nil,
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
            expires: expires ?? validEnd,
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

    @Test("Filters out expired and not-yet-effective alerts")
    func filtersByValidityWindow() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let tag = "-E"

        let active = makeAlert(number: "1\(tag)", issued: now.addingTimeInterval(-3600), effective: now.addingTimeInterval(-300), validEnd: now.addingTimeInterval(600))
        let expired = makeAlert(number: "2\(tag)", issued: now.addingTimeInterval(-7200), effective: now.addingTimeInterval(-7200), validEnd: now.addingTimeInterval(-10))
        let upcoming = makeAlert(number: "3\(tag)", issued: now.addingTimeInterval(-600), effective: now.addingTimeInterval(600), validEnd: now.addingTimeInterval(3600))
        let expiresElapsed = makeAlert(number: "4\(tag)", issued: now.addingTimeInterval(-7200), effective: now.addingTimeInterval(-7200), validEnd: now.addingTimeInterval(600), expires: now)
        let endsElapsed = makeAlert(number: "5\(tag)", issued: now.addingTimeInterval(-7200), effective: now.addingTimeInterval(-7200), validEnd: now, expires: now.addingTimeInterval(600))

        ctx.insert(active)
        ctx.insert(expired)
        ctx.insert(upcoming)
        ctx.insert(expiresElapsed)
        ctx.insert(endsElapsed)
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
        #expect(!ids.contains("4\(tag)"))
        #expect(!ids.contains("5\(tag)"))
    }

    @Test("Keeps cell-based matches even when UGC metadata is absent")
    func matchesCellOnlyAlert() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let cell: Int64 = 613725958748241919
        let tag = "-C"

        let cellOnly = makeAlert(
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

        let activeAlert = makeAlert(
            number: "active",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert"
        )
        let cancelled = makeAlert(
            number: "cancelled",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Cancelled",
            messageType: "Cancel"
        )
        let superseded = makeAlert(
            number: "superseded",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Superseded",
            messageType: "Update"
        )

        ctx.insert(activeAlert)
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

    @Test("Geometry-backed alert excludes UGC-only matches when H3 cell does not match")
    func geometryBackedAlert_excludesUGCOnlyMatch() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let tag = "-G1"

        let alert = makeAlert(
            number: "1\(tag)",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            ugcZones: ["ALC013"],
            cells: [613725958748241919],
            geometry: testPolygonGeometry()
        )

        ctx.insert(alert)
        try ctx.save()

        let hits = try await repo.active(
            countyCode: "ALC013",
            fireZone: "ZZZ000",
            forecastZone: "ZZZ001",
            cell: 613725958748241920,
            on: now
        )

        #expect(hits.isEmpty)
    }

    @Test("Geometry-backed alert includes H3 cell matches even when UGC does not match")
    func geometryBackedAlert_includesCellMatchWithoutUGCMatch() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let tag = "-G2"
        let cell: Int64 = 613725958748241919

        let alert = makeAlert(
            number: "1\(tag)",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            ugcZones: ["ALC013"],
            cells: [cell],
            geometry: testPolygonGeometry()
        )

        ctx.insert(alert)
        try ctx.save()

        let hits = try await repo.active(
            countyCode: "ZZZ000",
            fireZone: "ZZZ001",
            forecastZone: "ZZZ002",
            cell: cell,
            on: now
        )

        #expect(hits.map(\.id) == ["1\(tag)"])
    }

    @Test("Geometry-less alert keeps UGC fallback matching")
    func geometryLessAlert_keepsUGCFallback() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let tag = "-G3"

        let alert = makeAlert(
            number: "1\(tag)",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            ugcZones: ["ALC013"],
            cells: []
        )

        ctx.insert(alert)
        try ctx.save()

        let hits = try await repo.active(
            countyCode: "ALC013",
            fireZone: "ZZZ000",
            forecastZone: "ZZZ001",
            cell: nil,
            on: now
        )

        #expect(hits.map(\.id) == ["1\(tag)"])
    }

    @Test("Matches forecast-zone UGCs when county and fire zones do not match")
    func matchesForecastZoneUGC() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let tag = "-F"

        let forecastOnly = makeAlert(
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

        let tornado = makeAlert(
            number: "warning-tor",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let severe = makeAlert(
            number: "warning-svr",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Update",
            event: "Severe Thunderstorm Warning",
            geometry: geometry
        )
        let flood = makeAlert(
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

    @Test("Active warning geometry excludes alerts unsupported events and nil geometry")
    func activeWarningGeometries_excludesUnsupportedAndNilGeometry() async throws {
        let ctx = ModelContext(container)
        let now = ISO8601DateFormatter().date(from: "2025-09-20T00:00:00Z")!
        let geometry = testPolygonGeometry()

        let watch = makeAlert(
            number: "watch",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Watch",
            geometry: geometry
        )
        let unsupported = makeAlert(
            number: "unsupported",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Alert",
            event: "Special Weather Statement",
            geometry: geometry
        )
        let missingGeometry = makeAlert(
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

        let expired = makeAlert(
            number: "expired",
            issued: now.addingTimeInterval(-7200),
            effective: now.addingTimeInterval(-7200),
            validEnd: now.addingTimeInterval(-10),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let expiresElapsed = makeAlert(
            number: "expires-elapsed",
            issued: now.addingTimeInterval(-7200),
            effective: now.addingTimeInterval(-7200),
            validEnd: now.addingTimeInterval(600),
            expires: now,
            status: "Active",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let canceledMessage = makeAlert(
            number: "canceled-message",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Active",
            messageType: "Cancel",
            event: "Tornado Warning",
            geometry: geometry
        )
        let cancelledState = makeAlert(
            number: "cancelled-state",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Cancelled",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let nonActiveState = makeAlert(
            number: "expired-state",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(600),
            status: "Expired",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let futureEffective = makeAlert(
            number: "future-effective",
            issued: now.addingTimeInterval(-60),
            effective: now.addingTimeInterval(600),
            validEnd: now.addingTimeInterval(1200),
            status: "Active",
            messageType: "Alert",
            event: "Tornado Warning",
            geometry: geometry
        )
        let supersededState = makeAlert(
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
        ctx.insert(expiresElapsed)
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

        let alert = makeAlert(
            number: "latest-warning",
            issued: now.addingTimeInterval(-3600),
            effective: now.addingTimeInterval(-300),
            validEnd: now.addingTimeInterval(900),
            status: "Active",
            messageType: "Update",
            event: "Tornado Warning",
            geometry: initialGeometry
        )

        ctx.insert(alert)
        try ctx.save()

        alert.messageId = "urn:test:latest"
        alert.currentRevisionSent = now.addingTimeInterval(120)
        alert.geometry = latestGeometry
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
        let warning = makeAlert(
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

        let provider = ArcusAlertProvider(alertRepo: repo, client: UnavailableArcusClient())
        let geometries = try await provider.getActiveWarningGeometries(on: now)

        #expect(geometries.map(\.id) == ["provider-warning"])
        #expect(geometries.first?.geometry == geometry)
    }

    @Test("Notification cache accepts a matching or newer revision without HTTP", arguments: [0.0, 60.0])
    func notificationCacheHit(newerBy: Double) async throws {
        let revision = Date(timeIntervalSince1970: 1_800_000_000)
        try seedNotificationAlert(revision: revision.addingTimeInterval(newerBy))
        let client = NotificationAlertClient(payload: Data("[]".utf8))
        let provider = ArcusAlertProvider(alertRepo: repo, client: client)

        let alert = try await provider.resolveNotificationAlert(.init(alertID: notificationID.lowercased(), revisionSent: revision))

        #expect(alert?.currentRevisionSent == revision.addingTimeInterval(newerBy))
        #expect(await client.callCount == 0)
    }

    @Test("Missing, older, and unknown revisions fetch the target and accept a newer current record", arguments: ["missing", "older", "unknown"])
    func notificationTargetedFetch(cache: String) async throws {
        let revision = Date(timeIntervalSince1970: 1_800_000_000)
        if cache != "missing" {
            try seedNotificationAlert(revision: cache == "unknown" ? nil : revision.addingTimeInterval(-60))
        }
        let client = NotificationAlertClient(payload: try notificationPayload(revision: revision.addingTimeInterval(60)))
        let provider = ArcusAlertProvider(alertRepo: repo, client: client)

        let alert = try await provider.resolveNotificationAlert(.init(alertID: notificationID, revisionSent: revision))

        #expect(alert?.currentRevisionSent == revision.addingTimeInterval(60))
        #expect(try await repo.alert(id: notificationID) == alert)
        #expect(await client.callCount == 1)
        #expect(await client.requestedID == notificationID)
        #expect(await client.requestedRevision == revision)
    }

    @Test("Failed, removed, terminal, and too-old targets never present stale content as current", arguments: ["failure", "removed", "terminal", "older"])
    func notificationUnavailable(outcome: String) async throws {
        let revision = Date(timeIntervalSince1970: 1_800_000_000)
        try seedNotificationAlert(revision: revision.addingTimeInterval(-60))
        let payload = outcome == "removed" ? Data("[]".utf8) : try notificationPayload(
            revision: outcome == "older" ? revision.addingTimeInterval(-30) : revision,
            state: outcome == "terminal" ? "expired" : "active"
        )
        let client = NotificationAlertClient(payload: payload, fails: outcome == "failure")
        let provider = ArcusAlertProvider(alertRepo: repo, client: client)

        #expect(try await provider.resolveNotificationAlert(.init(alertID: notificationID, revisionSent: revision)) == nil)
        #expect(try await repo.alert(id: notificationID) != nil)
        #expect(await client.callCount == 1)
    }

    @Test("Concurrent receipt and open share targeted HTTP work")
    func notificationReceiptAndOpenCoalesce() async throws {
        let revision = Date(timeIntervalSince1970: 1_800_000_000)
        let client = NotificationAlertClient(payload: try notificationPayload(revision: revision), blocked: true)
        let provider = ArcusAlertProvider(alertRepo: repo, client: client)
        let receipt = Task { await provider.syncRemoteAlert(id: notificationID, revisionSent: revision) }
        await client.waitUntilStarted()
        let open = Task { try await provider.resolveNotificationAlert(.init(alertID: notificationID.lowercased(), revisionSent: revision)) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while await provider.coalescedRemoteSyncCount == 0, ContinuousClock.now < deadline {
            await Task.yield()
        }
        let joined = await provider.coalescedRemoteSyncCount
        await client.release()
        #expect(joined == 1)
        #expect(await receipt.value == .live)
        #expect(try await open.value?.currentRevisionSent == revision)
        #expect(await client.callCount == 1)
    }

    @Test("Delayed location or targeted responses cannot replace a newer accepted revision", arguments: ["location-active", "location-terminal", "targeted-active", "targeted-terminal"])
    func notificationRevisionNeverRegresses(path: String) async throws {
        let revision = Date(timeIntervalSince1970: 1_800_000_000)
        let oldClient = NotificationAlertClient(
            payload: try notificationPayload(revision: revision, state: path.hasSuffix("terminal") ? "expired" : "active"),
            blocked: true
        )
        let oldRequest = Task {
            if path.hasPrefix("location") {
                return try await repo.refresh(using: oldClient, for: "", and: "", and: "", in: nil)
            }
            return try await repo.refreshAlert(using: oldClient, id: notificationID, revisionSent: revision)
        }
        await oldClient.waitUntilStarted()
        let newer = revision.addingTimeInterval(60)
        let provider = ArcusAlertProvider(
            alertRepo: repo, client: NotificationAlertClient(payload: try notificationPayload(revision: newer))
        )
        let resolved = try await provider.resolveNotificationAlert(.init(alertID: notificationID, revisionSent: newer))
        await oldClient.release()
        _ = try await oldRequest.value

        #expect(resolved?.currentRevisionSent == newer)
        #expect(try await repo.notificationAlert(id: notificationID)?.currentRevisionSent == newer)
    }

    @Test("Notification reads reject terminal and invalid validity windows", arguments: ["expired", "cancelled", "future", "ends", "expires"])
    func notificationLifecycle(state: String) async throws {
        let revision = Date(timeIntervalSince1970: 1_800_000_000)
        let ctx = ModelContext(container)
        let watch = makeAlert(
            number: notificationID,
            issued: revision,
            effective: state == "future" ? revision.addingTimeInterval(60) : revision.addingTimeInterval(-60),
            validEnd: state == "ends" ? revision : revision.addingTimeInterval(600),
            expires: state == "expires" ? revision : revision.addingTimeInterval(600),
            status: state == "expired" ? "expired" : "actual",
            messageType: state == "cancelled" ? "Cancel" : "Alert"
        )
        ctx.insert(watch)
        try ctx.save()
        #expect(try await repo.notificationAlert(id: notificationID, on: revision) == nil)
    }

    private var notificationID: String { "123E4567-E89B-12D3-A456-426614174000" }

    private func seedNotificationAlert(revision: Date?) throws {
        let ctx = ModelContext(container)
        let watch = makeAlert(
            number: notificationID,
            issued: Date(timeIntervalSince1970: 1_700_000_000),
            effective: Date(timeIntervalSince1970: 1_700_000_000),
            validEnd: Date(timeIntervalSince1970: 4_000_000_000)
        )
        watch.currentRevisionSent = revision
        ctx.insert(watch)
        try ctx.save()
    }

    private func notificationPayload(revision: Date, state: String = "active") throws -> Data {
        try JSONSerialization.data(withJSONObject: [[
            "id": notificationID, "currentRevisionUrn": "urn:notification-test",
            "currentRevisionSent": revision.ISO8601Format(), "messageType": "Alert", "state": state,
            "event": "Tornado Warning", "created": "2025-01-01T00:00:00Z",
            "updated": "2025-01-01T00:00:00Z", "lastSeenActive": "2025-01-01T00:00:00Z",
            "sent": "2025-01-01T00:00:00Z", "effective": "2025-01-01T00:00:00Z",
            "onset": "2025-01-01T00:00:00Z", "expires": "2100-01-01T00:00:00Z",
            "severity": "Extreme", "urgency": "Immediate", "certainty": "Observed",
            "description": "Test warning", "ugc": [], "h3Cells": []
        ]])
    }

    @Test("Targeted provider sync reports rejected, failed, and fallback outcomes")
    func targetedProviderSync_reportsTypedOutcomes() async {
        let unavailableProvider = ArcusAlertProvider(alertRepo: repo, client: UnavailableArcusClient())
        let malformedProvider = ArcusAlertProvider(alertRepo: repo, client: MalformedArcusClient())
        let fallbackProvider = ArcusAlertProvider(alertRepo: repo, client: FallbackArcusClient())

        let unavailableOutcome = await unavailableProvider.syncRemoteAlert(id: "test", revisionSent: nil)
        let malformedOutcome = await malformedProvider.syncRemoteAlert(id: "test", revisionSent: nil)
        let fallbackOutcome = await fallbackProvider.syncRemoteAlert(id: "test", revisionSent: nil)

        #expect(unavailableOutcome == .failed)
        #expect(malformedOutcome == .rejected)
        #expect(fallbackOutcome == .errorFallback)
    }

    @Test("Targeted provider sync preserves every accepted transport source")
    func targetedProviderSync_preservesTransportSource() async {
        let cases: [(HTTPResponse.Source, ArcusRemoteAlertSyncOutcome)] = [
            (.live, .live),
            (.cacheRevalidated304, .revalidated),
            (.localCache, .localCache),
            (.cacheFallback, .errorFallback)
        ]

        for (source, expected) in cases {
            let provider = ArcusAlertProvider(alertRepo: repo, client: ResponseArcusClient(source: source))
            #expect(await provider.syncRemoteAlert(id: "test", revisionSent: nil) == expected)
        }
    }

    @Test("Provider records fallback provenance without advancing network success")
    func provider_recordsFallbackProvenance() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcusAlertProviderTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = FeedStateStore(directoryURL: directory)
        let provider = ArcusAlertProvider(
            alertRepo: repo,
            client: ResponseArcusClient(source: .cacheFallback),
            feedStateStore: store
        )

        #expect(await provider.syncRemoteAlert(id: "test", revisionSent: nil) == .errorFallback)

        let record = try #require(await store.record(for: "arcus.alert"))
        #expect(record.lastTransportSource == .errorFallback)
        #expect(record.lastNetworkSuccessAt == nil)
        #expect(record.lastCanonicalAcceptanceAt != nil)
        #expect(record.lastFailure == .transport)
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

private actor NotificationAlertClient: ArcusClient {
    let payload: Data
    let fails: Bool
    private var blocked: Bool
    private var startedWaiter: CheckedContinuation<Void, Never>?
    private var responseWaiter: CheckedContinuation<Void, Never>?
    private(set) var callCount = 0
    private(set) var requestedID: String?
    private(set) var requestedRevision: Date?

    init(payload: Data, fails: Bool = false, blocked: Bool = false) {
        self.payload = payload
        self.fails = fails
        self.blocked = blocked
    }

    func waitUntilStarted() async {
        if callCount == 0 { await withCheckedContinuation { startedWaiter = $0 } }
    }

    func release() {
        blocked = false
        responseWaiter?.resume()
        responseWaiter = nil
    }

    func fetchActiveAlerts(for county: String, and fire: String, and forecast: String, in cell: Int64?) async throws -> Data {
        try await fetchAlert(id: "location-collection", revisionSent: nil)
    }

    func fetchAlert(id: String, revisionSent: Date?) async throws -> Data {
        callCount += 1
        requestedID = id
        requestedRevision = revisionSent
        startedWaiter?.resume()
        startedWaiter = nil
        if blocked { await withCheckedContinuation { responseWaiter = $0 } }
        if fails { throw ArcusError.networkError(status: 503) }
        return payload
    }
}
