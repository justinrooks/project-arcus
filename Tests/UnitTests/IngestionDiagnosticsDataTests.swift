import Foundation
import Testing
@testable import SkyAware

@Suite("Ingestion Diagnostics Data")
@MainActor
struct IngestionDiagnosticsDataTests {
    @Test("current context projection is preferred over a newer unrelated cached projection")
    func resolve_prefersCurrentContextProjection() {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let matching = makeProjectionRecord(
            context: currentContext,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newerFallback = makeProjectionRecord(
            context: makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200"),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let diagnostics = DiagnosticsView.resolveIngestionDiagnostics(
            from: [newerFallback, matching],
            currentContext: currentContext
        )

        #expect(diagnostics?.projectionSource == .currentContext)
        #expect(diagnostics?.projection == matching)
    }

    @Test("newest cached projection is used when the current context projection is unavailable")
    func resolve_fallsBackToNewestCachedProjection() {
        let currentContext = makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214")
        let older = makeProjectionRecord(
            context: makeContext(h3Cell: 222, countyCode: "COC001", fireZone: "COZ200"),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = makeProjectionRecord(
            context: makeContext(h3Cell: 333, countyCode: "COC013", fireZone: "COZ222"),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        let diagnostics = DiagnosticsView.resolveIngestionDiagnostics(
            from: [older, newer],
            currentContext: currentContext
        )

        #expect(diagnostics?.projectionSource == .latestCached)
        #expect(diagnostics?.projection == newer)
    }

    @Test("no diagnostics are available without cached projections")
    func resolve_returnsNilWithoutCachedProjection() {
        let diagnostics = DiagnosticsView.resolveIngestionDiagnostics(
            from: [],
            currentContext: nil
        )

        #expect(diagnostics == nil)
    }

    @Test("lane statuses surface the persisted ingestion timestamps")
    func laneStatuses_surfacePersistedTimestamps() {
        let projection = makeProjectionRecord(
            context: makeContext(h3Cell: 111, countyCode: "COC005", fireZone: "COZ214"),
            updatedAt: Date(timeIntervalSince1970: 400),
            lastHotAlertsLoadAt: Date(timeIntervalSince1970: 100),
            lastSlowProductsLoadAt: Date(timeIntervalSince1970: 200),
            lastWeatherLoadAt: Date(timeIntervalSince1970: 300)
        )

        let diagnostics = DiagnosticsView.IngestionDiagnosticsData(
            projectionSource: .currentContext,
            projection: projection
        )

        #expect(diagnostics.laneStatuses.map(\.title) == [
            "Hot Alerts",
            "Slow Products",
            "Weather",
            "Projection Update"
        ])
        #expect(diagnostics.laneStatuses.map(\.lastSuccessfulLoadAt) == [
            Date(timeIntervalSince1970: 100),
            Date(timeIntervalSince1970: 200),
            Date(timeIntervalSince1970: 300),
            Date(timeIntervalSince1970: 400)
        ])
    }

    private func makeContext(
        h3Cell: Int64,
        countyCode: String,
        fireZone: String
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: 39.75, longitude: -104.44),
            timestamp: Date(timeIntervalSince1970: 100),
            accuracy: 25,
            placemarkSummary: "Bennett, CO",
            h3Cell: h3Cell
        )
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20",
            latitude: 39.75,
            longitude: -104.44,
            gridId: "BOU",
            gridX: 10,
            gridY: 20,
            forecastURL: nil,
            forecastHourlyURL: nil,
            forecastGridDataURL: nil,
            observationStationsURL: nil,
            city: "Bennett",
            state: "CO",
            timeZoneId: "America/Denver",
            radarStationId: nil,
            forecastZone: "COZ038",
            countyCode: countyCode,
            fireZone: fireZone,
            countyLabel: "Arapahoe",
            fireZoneLabel: "Front Range"
        )
        return LocationContext(snapshot: snapshot, h3Cell: h3Cell, grid: grid)
    }

    private func makeProjectionRecord(
        context: LocationContext,
        updatedAt: Date,
        lastHotAlertsLoadAt: Date? = nil,
        lastSlowProductsLoadAt: Date? = nil,
        lastWeatherLoadAt: Date? = nil
    ) -> HomeProjectionRecord {
        HomeProjectionRecord(
            id: UUID(),
            projectionKey: HomeProjection.projectionKey(for: context),
            latitude: context.snapshot.coordinates.latitude,
            longitude: context.snapshot.coordinates.longitude,
            h3Cell: context.h3Cell,
            countyCode: context.grid.countyCode ?? "",
            forecastZone: context.grid.forecastZone,
            fireZone: context.grid.fireZone ?? "",
            placemarkSummary: context.snapshot.placemarkSummary,
            timeZoneId: context.grid.timeZoneId,
            locationTimestamp: context.snapshot.timestamp,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            lastViewedAt: updatedAt,
            weather: nil,
            stormRisk: nil,
            severeRisk: nil,
            fireRisk: nil,
            activeAlerts: [],
            activeMesos: [],
            lastHotAlertsLoadAt: lastHotAlertsLoadAt,
            lastSlowProductsLoadAt: lastSlowProductsLoadAt,
            lastWeatherLoadAt: lastWeatherLoadAt
        )
    }
}
