import Foundation
import SwiftData
import Testing
@testable import SkyAware

@Suite("Home Projection Store")
@MainActor
struct HomeProjectionStoreTests {
    @Test("projection keys are deterministic for the same resolved location context")
    func projectionKey_isDeterministicForResolvedContext() {
        let first = makeContext(latitude: 39.7500, longitude: -104.4400, timestamp: 100)
        let second = makeContext(latitude: 39.7509, longitude: -104.4409, timestamp: 200)

        #expect(HomeProjection.projectionKey(for: first) == HomeProjection.projectionKey(for: second))
    }

    @Test("fetch or create reuses an existing projection for the same key")
    func fetchOrCreate_reusesExistingProjection() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)

        let firstContext = makeContext(timestamp: 100, placemarkSummary: "Bennett, CO")
        let secondContext = makeContext(timestamp: 200, placemarkSummary: "Byers, CO")

        let first = try await store.fetchOrCreateProjection(
            for: firstContext,
            viewedAt: Date(timeIntervalSince1970: 500)
        )
        let second = try await store.fetchOrCreateProjection(
            for: secondContext,
            viewedAt: Date(timeIntervalSince1970: 700)
        )

        #expect(first.id == second.id)
        #expect(second.locationTimestamp == secondContext.snapshot.timestamp)
        #expect(second.placemarkSummary == "Byers, CO")
        #expect(second.lastViewedAt == Date(timeIntervalSince1970: 700))

        let count = try ModelContext(container).fetchCount(FetchDescriptor<HomeProjection>())
        #expect(count == 1)
    }

    @Test("updating slow products keeps existing weather and alert slices")
    func updateSlowProducts_preservesExistingWeatherAndAlerts() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let watch = Watch.sampleWatchRows[0]
        let meso = MD.sampleDiscussionDTOs[0]

        _ = try await store.updateWeather(
            makeWeather(),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 300)
        )
        _ = try await store.updateHotAlerts(
            watches: [watch],
            mesos: [meso],
            for: context,
            loadedAt: Date(timeIntervalSince1970: 400)
        )

        let updated = try await store.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 500)
        )

        #expect(updated.weather == makeWeather())
        #expect(updated.activeAlerts == [watch])
        #expect(updated.activeMesos == [meso])
        #expect(updated.stormRisk == .slight)
        #expect(updated.severeRisk == .tornado(probability: 0.10))
        #expect(updated.fireRisk == .critical)
        #expect(updated.lastWeatherLoadAt == Date(timeIntervalSince1970: 300))
        #expect(updated.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 400))
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 500))
    }

    @Test("updating weather keeps the existing risk and alert slices intact")
    func updateWeather_preservesExistingRiskAndAlertSlices() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let watch = Watch.sampleWatchRows[1]
        let meso = MD.sampleDiscussionDTOs[1]

        _ = try await store.updateSlowProducts(
            stormRisk: .enhanced,
            severeRisk: .wind(probability: 0.30),
            fireRisk: .elevated,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 350)
        )
        _ = try await store.updateHotAlerts(
            watches: [watch],
            mesos: [meso],
            for: context,
            loadedAt: Date(timeIntervalSince1970: 360)
        )

        let updated = try await store.updateWeather(
            makeWeather(temperature: 68, asOf: 900),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 370)
        )

        #expect(updated.weather == makeWeather(temperature: 68, asOf: 900))
        #expect(updated.stormRisk == .enhanced)
        #expect(updated.severeRisk == .wind(probability: 0.30))
        #expect(updated.fireRisk == .elevated)
        #expect(updated.activeAlerts == [watch])
        #expect(updated.activeMesos == [meso])
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 350))
        #expect(updated.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 360))
        #expect(updated.lastWeatherLoadAt == Date(timeIntervalSince1970: 370))
    }

    private func makeContext(
        latitude: Double = 39.75,
        longitude: Double = -104.44,
        timestamp: TimeInterval = 100,
        placemarkSummary: String = "Bennett, CO"
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: latitude, longitude: longitude),
            timestamp: Date(timeIntervalSince1970: timestamp),
            accuracy: 25,
            placemarkSummary: placemarkSummary,
            h3Cell: 123_456
        )
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20",
            latitude: latitude,
            longitude: longitude,
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
            countyCode: "COC005",
            fireZone: "COZ214",
            countyLabel: "Arapahoe",
            fireZoneLabel: "Front Range"
        )
        return LocationContext(snapshot: snapshot, h3Cell: snapshot.h3Cell ?? 123_456, grid: grid)
    }

    private func makeWeather(
        temperature: Double = 72,
        asOf: TimeInterval = 200
    ) -> SummaryWeather {
        SummaryWeather(
            temperature: .init(value: temperature, unit: .fahrenheit),
            symbolName: "sun.max.fill",
            conditionText: "Clear",
            asOf: Date(timeIntervalSince1970: asOf),
            dewPoint: .init(value: 54, unit: .fahrenheit),
            humidity: 0.45,
            windSpeed: .init(value: 15, unit: .milesPerHour),
            windGust: .init(value: 24, unit: .milesPerHour),
            windDirection: "NW",
            pressure: .init(value: 29.92, unit: .inchesOfMercury),
            pressureTrend: "steady"
        )
    }
}
