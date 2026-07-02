import Foundation
import ArcusCore
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

    @Test("new projections start with nil Storm Setup fields")
    func fetchOrCreate_newProjectionStartsWithNilStormSetup() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()

        let projection = try await store.fetchOrCreateProjection(for: context)

        #expect(projection.stormSetup == nil)
        #expect(projection.lastStormSetupLoadAt == nil)
    }

    @Test("updating Storm Setup stores the payload and load timestamp")
    func updateStormSetup_persistsPayloadAndLoadTimestamp() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let loadedAt = Date(timeIntervalSince1970: 600)
        let dto = makeStormSetupDTO()

        let updated = try await store.updateStormSetup(dto, for: context, loadedAt: loadedAt)

        #expect(updated.stormSetup == dto)
        #expect(updated.lastStormSetupLoadAt == loadedAt)
        #expect(updated.updatedAt == loadedAt)

        let persisted = try #require(await store.projection(for: context))
        #expect(persisted.stormSetup == dto)
        #expect(persisted.lastStormSetupLoadAt == loadedAt)
    }

    @Test("updating Storm Setup preserves weather, risks, alerts, mesos, and timestamps")
    func updateStormSetup_preservesExistingSlicesAndTimestamps() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let weather = makeWeather()
        let alert = Watch.sampleWatchRows[0]
        let meso = MD.sampleDiscussionDTOs[0]
        let stormLoadedAt = Date(timeIntervalSince1970: 650)
        let dto = makeStormSetupDTO()

        _ = try await store.updateWeather(weather, for: context, loadedAt: Date(timeIntervalSince1970: 300))
        _ = try await store.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 400)
        )
        _ = try await store.updateHotAlerts(
            alerts: [alert],
            mesos: [meso],
            for: context,
            loadedAt: Date(timeIntervalSince1970: 500)
        )

        let updated = try await store.updateStormSetup(dto, for: context, loadedAt: stormLoadedAt)

        #expect(updated.weather == weather)
        #expect(updated.stormRisk == StormRiskLevel.slight)
        #expect(updated.severeRisk == SevereWeatherThreat.tornado(probability: 0.10))
        #expect(updated.fireRisk == FireRiskLevel.critical)
        #expect(updated.activeAlerts == [alert])
        #expect(updated.activeMesos == [meso])
        #expect(updated.stormSetup == dto)
        #expect(updated.lastWeatherLoadAt == Date(timeIntervalSince1970: 300))
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 400))
        #expect(updated.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 500))
        #expect(updated.lastStormSetupLoadAt == stormLoadedAt)
    }

    @Test("weather, slow products, and hot alerts preserve Storm Setup")
    func updateNonStormSetupSlices_preserveStormSetup() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let dto = makeStormSetupDTO()
        let stormLoadedAt = Date(timeIntervalSince1970: 700)
        let weatherLoadedAt = Date(timeIntervalSince1970: 710)
        let slowLoadedAt = Date(timeIntervalSince1970: 720)
        let hotLoadedAt = Date(timeIntervalSince1970: 730)
        let alert = Watch.sampleWatchRows[1]
        let meso = MD.sampleDiscussionDTOs[1]

        _ = try await store.updateStormSetup(dto, for: context, loadedAt: stormLoadedAt)

        let weatherUpdated = try await store.updateWeather(
            makeWeather(temperature: 68, asOf: 900),
            for: context,
            loadedAt: weatherLoadedAt
        )
        let slowUpdated = try await store.updateSlowProducts(
            stormRisk: .moderate,
            severeRisk: .wind(probability: 0.20),
            fireRisk: .elevated,
            for: context,
            loadedAt: slowLoadedAt
        )
        let hotUpdated = try await store.updateHotAlerts(
            alerts: [alert],
            mesos: [meso],
            for: context,
            loadedAt: hotLoadedAt
        )

        #expect(weatherUpdated.stormSetup == dto)
        #expect(weatherUpdated.lastStormSetupLoadAt == stormLoadedAt)
        #expect(slowUpdated.stormSetup == dto)
        #expect(slowUpdated.lastStormSetupLoadAt == stormLoadedAt)
        #expect(hotUpdated.stormSetup == dto)
        #expect(hotUpdated.lastStormSetupLoadAt == stormLoadedAt)
    }

    @Test("different projection keys keep independent Storm Setup payloads")
    func updateStormSetup_keepsProjectionKeysIndependent() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let firstContext = makeContext(
            latitude: 39.75,
            longitude: -104.44,
            timestamp: 100,
            placemarkSummary: "Bennett, CO",
            countyCode: "COC005",
            forecastZone: "COZ038",
            fireZone: "COZ214",
            h3Cell: 123_456
        )
        let secondContext = makeContext(
            latitude: 40.02,
            longitude: -104.87,
            timestamp: 120,
            placemarkSummary: "Brighton, CO",
            countyCode: "COC007",
            forecastZone: "COZ041",
            fireZone: "COZ217",
            h3Cell: 654_321
        )
        let firstDTO = makeStormSetupDTO(h3Cell: 123_456, surfaceHeightMslM: 1_100)
        let secondDTO = makeStormSetupDTO(
            h3Cell: 654_321,
            surfaceHeightMslM: 1_240,
            summary: "Second location"
        )

        _ = try await store.updateStormSetup(
            firstDTO,
            for: firstContext,
            loadedAt: Date(timeIntervalSince1970: 800)
        )
        _ = try await store.updateStormSetup(
            secondDTO,
            for: secondContext,
            loadedAt: Date(timeIntervalSince1970: 900)
        )

        let firstProjection = try #require(await store.projection(for: firstContext))
        let secondProjection = try #require(await store.projection(for: secondContext))

        #expect(firstProjection.projectionKey == HomeProjection.projectionKey(for: firstContext))
        #expect(secondProjection.projectionKey == HomeProjection.projectionKey(for: secondContext))
        #expect(firstProjection.stormSetup == firstDTO)
        #expect(secondProjection.stormSetup == secondDTO)
        #expect(firstProjection.stormSetup != secondProjection.stormSetup)
    }

    @Test("a new store over the same container reads persisted Storm Setup")
    func updateStormSetup_newStoreReadsPersistedPayload() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let context = makeContext()
        let dto = makeStormSetupDTO()
        let loadedAt = Date(timeIntervalSince1970: 950)

        do {
            let store = HomeProjectionStore(modelContainer: container)
            _ = try await store.updateStormSetup(dto, for: context, loadedAt: loadedAt)
        }

        let reopenedStore = HomeProjectionStore(modelContainer: container)
        let persisted = try #require(await reopenedStore.projection(for: context))

        #expect(persisted.stormSetup == dto)
        #expect(persisted.lastStormSetupLoadAt == loadedAt)
    }

    @Test("an on-disk container survives reopen with Storm Setup intact")
    func updateStormSetup_diskContainerRetainsPayloadAfterReopen() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let schema = Schema([HomeProjection.self])
        let storeURL = root.appendingPathComponent("SkyAware_Data.sqlite")
        let configuration = ModelConfiguration(
            "SkyAware_Data",
            schema: schema,
            url: storeURL
        )
        let context = makeContext()
        let dto = makeStormSetupDTO()
        let loadedAt = Date(timeIntervalSince1970: 1_000)

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            let store = HomeProjectionStore(modelContainer: container)
            _ = try await store.updateStormSetup(dto, for: context, loadedAt: loadedAt)
        }

        let reopenedContainer = try ModelContainer(for: schema, configurations: configuration)
        let reopenedStore = HomeProjectionStore(modelContainer: reopenedContainer)
        let persisted = try #require(await reopenedStore.projection(for: context))

        #expect(persisted.stormSetup == dto)
        #expect(persisted.lastStormSetupLoadAt == loadedAt)
    }

    @Test("updating slow products keeps existing weather and alert slices")
    func updateSlowProducts_preservesExistingWeatherAndAlerts() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let alert = Watch.sampleWatchRows[0]
        let meso = MD.sampleDiscussionDTOs[0]

        _ = try await store.updateWeather(
            makeWeather(),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 300)
        )
        _ = try await store.updateHotAlerts(
            alerts: [alert],
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
        #expect(updated.activeAlerts == [alert])
        #expect(updated.activeMesos == [meso])
        #expect(updated.stormRisk == .slight)
        #expect(updated.severeRisk == .tornado(probability: 0.10))
        #expect(updated.fireRisk == .critical)
        #expect(updated.lastWeatherLoadAt == Date(timeIntervalSince1970: 300))
        #expect(updated.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 400))
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 500))
    }

    @Test("updating slow products overwrites stale severe risk with all clear")
    func updateSlowProducts_overwritesStaleSevereRiskWithAllClear() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()

        _ = try await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .tornado(probability: 0.02),
            fireRisk: .clear,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 500)
        )

        let updated = try await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .allClear,
            fireRisk: .clear,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 560)
        )

        #expect(updated.severeRisk == .allClear)
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 560))
    }

    @Test("updating weather keeps the existing risk and alert slices intact")
    func updateWeather_preservesExistingRiskAndAlertSlices() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let alert = Watch.sampleWatchRows[1]
        let meso = MD.sampleDiscussionDTOs[1]

        _ = try await store.updateSlowProducts(
            stormRisk: .enhanced,
            severeRisk: .wind(probability: 0.30),
            fireRisk: .elevated,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 350)
        )
        _ = try await store.updateHotAlerts(
            alerts: [alert],
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
        #expect(updated.activeAlerts == [alert])
        #expect(updated.activeMesos == [meso])
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 350))
        #expect(updated.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 360))
        #expect(updated.lastWeatherLoadAt == Date(timeIntervalSince1970: 370))
    }

    @Test("updating hot alerts with empty arrays still creates a projection snapshot")
    func updateHotAlerts_emptySlicesStillCreateProjection() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let loadedAt = Date(timeIntervalSince1970: 450)

        let updated = try await store.updateHotAlerts(
            alerts: [],
            mesos: [],
            for: context,
            loadedAt: loadedAt
        )

        #expect(updated.activeAlerts.isEmpty)
        #expect(updated.activeMesos.isEmpty)
        #expect(updated.lastHotAlertsLoadAt == loadedAt)

        let persisted = try #require(await store.projection(for: context))
        #expect(persisted.activeAlerts.isEmpty)
        #expect(persisted.activeMesos.isEmpty)
        #expect(persisted.lastHotAlertsLoadAt == loadedAt)
    }

    @Test("updating hot alerts preserves warning geometry in the cached projection")
    func updateHotAlerts_preservesWarningGeometry() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        var alert = Watch.sampleWatchRows[0]
        alert.geometry = .polygon(
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

        let updated = try await store.updateHotAlerts(
            alerts: [alert],
            mesos: [],
            for: context,
            loadedAt: Date(timeIntervalSince1970: 460)
        )

        #expect(updated.activeAlerts.first?.geometry == alert.geometry)

        let persisted = try #require(await store.projection(for: context))
        #expect(persisted.activeAlerts.first?.geometry == alert.geometry)
    }

    @Test("latest widget fallback selects deterministically when timestamps tie")
    func latestProjectionForWidgetSnapshotRefresh_isDeterministicOnTimestampTie() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let tieTimestamp = Date(timeIntervalSince1970: 600)
        let alphaContext = makeContext(
            latitude: 39.75,
            longitude: -104.44,
            timestamp: 100,
            placemarkSummary: "Alpha",
            countyCode: "COC001",
            forecastZone: "COZ001",
            fireZone: "COZ101",
            h3Cell: 1
        )
        let zuluContext = makeContext(
            latitude: 39.70,
            longitude: -104.10,
            timestamp: 100,
            placemarkSummary: "Zulu",
            countyCode: "COC999",
            forecastZone: "COZ999",
            fireZone: "COZ999",
            h3Cell: 9
        )

        _ = try await store.updateSlowProducts(
            stormRisk: .enhanced,
            severeRisk: .wind(probability: 0.30),
            fireRisk: .critical,
            for: zuluContext,
            loadedAt: tieTimestamp
        )
        _ = try await store.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .hail(probability: 0.15),
            fireRisk: .elevated,
            for: alphaContext,
            loadedAt: tieTimestamp
        )

        let latest = try #require(await store.latestProjectionForWidgetSnapshotRefresh())
        let expectedProjectionKey = min(
            HomeProjection.projectionKey(for: alphaContext),
            HomeProjection.projectionKey(for: zuluContext)
        )
        #expect(latest.projectionKey == expectedProjectionKey)
    }

    @Test("latest widget fallback does not disturb context-specific projection reads")
    func latestProjectionForWidgetSnapshotRefresh_preservesContextSpecificReads() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)

        let olderContext = makeContext(
            latitude: 39.60,
            longitude: -104.20,
            timestamp: 100,
            placemarkSummary: "Older",
            countyCode: "COC010",
            forecastZone: "COZ010",
            fireZone: "COZ210",
            h3Cell: 10
        )
        let currentContext = makeContext(
            latitude: 39.90,
            longitude: -104.80,
            timestamp: 200,
            placemarkSummary: "Current",
            countyCode: "COC011",
            forecastZone: "COZ011",
            fireZone: "COZ211",
            h3Cell: 11
        )

        _ = try await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .wind(probability: 0.10),
            fireRisk: .elevated,
            for: olderContext,
            loadedAt: Date(timeIntervalSince1970: 500)
        )
        _ = try await store.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.15),
            fireRisk: .critical,
            for: currentContext,
            loadedAt: Date(timeIntervalSince1970: 700)
        )

        let contextProjection = try #require(await store.projection(for: olderContext))
        #expect(contextProjection.projectionKey == HomeProjection.projectionKey(for: olderContext))
        #expect(contextProjection.stormRisk == .marginal)

        let latestProjection = try #require(await store.latestProjectionForWidgetSnapshotRefresh())
        #expect(latestProjection.projectionKey == HomeProjection.projectionKey(for: currentContext))
        #expect(latestProjection.stormRisk == .slight)
    }

    private func makeContext(
        latitude: Double = 39.75,
        longitude: Double = -104.44,
        timestamp: TimeInterval = 100,
        placemarkSummary: String = "Bennett, CO",
        countyCode: String = "COC005",
        forecastZone: String = "COZ038",
        fireZone: String = "COZ214",
        h3Cell: Int64 = 123_456
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: latitude, longitude: longitude),
            timestamp: Date(timeIntervalSince1970: timestamp),
            accuracy: 25,
            placemarkSummary: placemarkSummary,
            h3Cell: h3Cell
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
            forecastZone: forecastZone,
            countyCode: countyCode,
            fireZone: fireZone,
            countyLabel: "Arapahoe",
            fireZoneLabel: "Front Range"
        )
        return LocationContext(snapshot: snapshot, h3Cell: snapshot.h3Cell ?? h3Cell, grid: grid)
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

    private func makeStormSetupDTO(
        h3Cell: Int64 = 123_456,
        surfaceHeightMslM: Double = 1_132.4,
        summary: String = "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation."
    ) -> StormSetupDTO {
        StormSetupDTO(
            h3Cell: h3Cell,
            freshness: .init(
                isStale: false,
                isDegraded: false,
                modelRunTime: Date(timeIntervalSince1970: 1_717_270_400),
                sourceValidTime: Date(timeIntervalSince1970: 1_717_281_600),
                forecastHour: 3,
                fetchedAt: Date(timeIntervalSince1970: 1_717_281_780),
                expiresAt: Date(timeIntervalSince1970: 1_717_284_000)
            ),
            source: .init(
                model: "HRRR",
                product: "Storm Setup",
                domain: "severe",
                fieldSetVersion: "1",
                sourceKind: "production",
                runTime: Date(timeIntervalSince1970: 1_717_270_400),
                validTime: Date(timeIntervalSince1970: 1_717_281_600),
                forecastHour: 3,
                bbox: .init(
                    toplat: 41.5,
                    leftlon: -104.3,
                    rightlon: -96.2,
                    bottomlat: 36.8
                ),
                primaryDownloadURL: "https://example.invalid/storm-setup"
            ),
            raw: .init(
                mlcapeJkg: 1_850,
                mucapeJkg: 2_200.5,
                sbcapeJkg: 1_700,
                mlcinJkg: -42,
                srh01kmM2s2: 125.5,
                srh03kmM2s2: 175,
                shear06kmKt: 42,
                mllclM: 980,
                tempDewPtDeltaF: 4.5,
                threeCapeJkg: 95
            ),
            assessment: .init(
                overall: "strong",
                summary: summary,
                instability: "supportive",
                moisture: "supportive",
                lowLevelRotation: "conditional",
                deepShear: "strong",
                cloudBase: "weak",
                capInhibition: "weak",
                limitingFactors: ["capping"],
                confidence: "high",
                primaryDrivers: ["instability", "shear"],
                stormMode: "supportive",
                stormModeHint: "supportive",
                trend: "conditional",
                compositeSignal: "strong"
            ),
            anvilEvidence: .init(
                status: "available",
                scp: .init(support: "supportive"),
                stp: .init(support: "conditional"),
                ship: .init(support: "weak"),
                diagnostics: .init(
                    hasEffectiveLayer: true,
                    hasStormMotion: false,
                    qualityProfileLevelCount: 3,
                    warnings: ["watch heating"]
                )
            ),
            centroid: .init(latitude: 39.5, longitude: -100.0),
            surfaceHeightMslM: surfaceHeightMslM
        )
    }
}
