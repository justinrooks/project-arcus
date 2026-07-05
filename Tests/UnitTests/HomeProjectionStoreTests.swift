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
        #expect(projection.stormSetupProfileAnalysisPayload == nil)
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

    @Test("updating Storm Setup profile analysis stores the envelope and touch time")
    func updateStormSetupProfileAnalysis_persistsEnvelopeAndUpdatedAt() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let loadedAt = Date(timeIntervalSince1970: 610)
        let envelope = makeStormSetupProfileAnalysisPayload()

        let updated = try await store.updateStormSetupProfileAnalysis(
            envelope,
            for: context,
            loadedAt: loadedAt
        )

        #expect(updated.stormSetupProfileAnalysisPayload == envelope)
        #expect(updated.updatedAt == loadedAt)

        let persisted = try #require(await store.projection(for: context))
        #expect(persisted.stormSetupProfileAnalysisPayload == envelope)
        #expect(persisted.updatedAt == loadedAt)
        #expect(envelopeFieldLabels(persisted.stormSetupProfileAnalysisPayload) == [
            "response",
            "modelRunTime",
            "validTime",
            "forecastHour",
            "fetchedAt",
            "expiresAt"
        ])
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
        let profileAnalysis = makeStormSetupProfileAnalysisPayload()

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
        _ = try await store.updateStormSetupProfileAnalysis(
            profileAnalysis,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 525)
        )

        let updated = try await store.updateStormSetup(dto, for: context, loadedAt: stormLoadedAt)

        #expect(updated.weather == weather)
        #expect(updated.stormRisk == StormRiskLevel.slight)
        #expect(updated.severeRisk == SevereWeatherThreat.tornado(probability: 0.10))
        #expect(updated.fireRisk == FireRiskLevel.critical)
        #expect(updated.activeAlerts == [alert])
        #expect(updated.activeMesos == [meso])
        #expect(updated.stormSetup == dto)
        #expect(updated.stormSetupProfileAnalysisPayload == profileAnalysis)
        #expect(updated.lastWeatherLoadAt == Date(timeIntervalSince1970: 300))
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 400))
        #expect(updated.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 500))
        #expect(updated.updatedAt == stormLoadedAt)
        #expect(updated.lastStormSetupLoadAt == stormLoadedAt)
    }

    @Test("weather, slow products, and hot alerts preserve Storm Setup profile analysis")
    func updateNonStormSetupSlices_preserveStormSetupProfileAnalysis() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let dto = makeStormSetupDTO()
        let profileAnalysis = makeStormSetupProfileAnalysisPayload()
        let stormLoadedAt = Date(timeIntervalSince1970: 700)
        let analysisLoadedAt = Date(timeIntervalSince1970: 705)
        let weatherLoadedAt = Date(timeIntervalSince1970: 710)
        let slowLoadedAt = Date(timeIntervalSince1970: 720)
        let hotLoadedAt = Date(timeIntervalSince1970: 730)
        let alert = Watch.sampleWatchRows[1]
        let meso = MD.sampleDiscussionDTOs[1]

        _ = try await store.updateStormSetup(dto, for: context, loadedAt: stormLoadedAt)
        _ = try await store.updateStormSetupProfileAnalysis(
            profileAnalysis,
            for: context,
            loadedAt: analysisLoadedAt
        )

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
        #expect(weatherUpdated.stormSetupProfileAnalysisPayload == profileAnalysis)
        #expect(weatherUpdated.lastStormSetupLoadAt == stormLoadedAt)
        #expect(weatherUpdated.updatedAt == weatherLoadedAt)
        #expect(slowUpdated.stormSetup == dto)
        #expect(slowUpdated.stormSetupProfileAnalysisPayload == profileAnalysis)
        #expect(slowUpdated.lastStormSetupLoadAt == stormLoadedAt)
        #expect(slowUpdated.updatedAt == slowLoadedAt)
        #expect(hotUpdated.stormSetup == dto)
        #expect(hotUpdated.stormSetupProfileAnalysisPayload == profileAnalysis)
        #expect(hotUpdated.lastStormSetupLoadAt == stormLoadedAt)
        #expect(hotUpdated.updatedAt == hotLoadedAt)
    }

    @Test("profile analysis updates preserve weather, risks, alerts, mesos, and Storm Setup")
    func updateStormSetupProfileAnalysis_preservesExistingSlices() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let weather = makeWeather()
        let alert = Watch.sampleWatchRows[0]
        let meso = MD.sampleDiscussionDTOs[0]
        let stormSetup = makeStormSetupDTO()
        let firstEnvelope = makeStormSetupProfileAnalysisPayload(
            fetchedAt: Date(timeIntervalSince1970: 810),
            expiresAt: Date(timeIntervalSince1970: 900)
        )
        let secondEnvelope = makeStormSetupProfileAnalysisPayload(
            response: .init(
                mlcape: 2_100,
                mucape: 2_400,
                mlcin: -35,
                mllclMetersAgl: 900,
                scp: 4.4,
                stpFixed: 1.7,
                stpCin: 2.1,
                ship: 1.2,
                effectiveSrh: 170,
                effectiveBulkShearMs: 18,
                effectiveLayer: .init(
                    status: "available",
                    basePressureMb: 875,
                    topPressureMb: 712,
                    baseMetersAgl: 550,
                    topMetersAgl: 5_500
                ),
                stormMotion: .init(
                    status: "available",
                    bunkersRight: .init(
                        uMs: 5.5,
                        vMs: 2.0,
                        speedMs: 5.9,
                        uKt: 10.7,
                        vKt: 3.9,
                        speedKt: 11.5,
                        directionTowardDeg: 67
                    ),
                    uMs: 5.5,
                    vMs: 2.0,
                    speedMs: 5.9,
                    uKt: 10.7,
                    vKt: 3.9,
                    speedKt: 11.5,
                    directionTowardDeg: 67
                ),
                quality: .init(profileLevelCount: 5, warnings: ["sample"])
            ),
            modelRunTime: Date(timeIntervalSince1970: 820),
            validTime: Date(timeIntervalSince1970: 830),
            forecastHour: 4,
            fetchedAt: Date(timeIntervalSince1970: 840),
            expiresAt: Date(timeIntervalSince1970: 930)
        )

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
        _ = try await store.updateStormSetup(
            stormSetup,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 600)
        )
        let updated = try await store.updateStormSetupProfileAnalysis(
            firstEnvelope,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 700)
        )

        #expect(updated.weather == weather)
        #expect(updated.stormRisk == .slight)
        #expect(updated.severeRisk == .tornado(probability: 0.10))
        #expect(updated.fireRisk == .critical)
        #expect(updated.activeAlerts == [alert])
        #expect(updated.activeMesos == [meso])
        #expect(updated.stormSetup == stormSetup)
        #expect(updated.stormSetupProfileAnalysisPayload == firstEnvelope)
        #expect(updated.lastWeatherLoadAt == Date(timeIntervalSince1970: 300))
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 400))
        #expect(updated.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 500))
        #expect(updated.lastStormSetupLoadAt == Date(timeIntervalSince1970: 600))

        let reopened = try #require(await store.projection(for: context))
        #expect(reopened.stormSetupProfileAnalysisPayload == firstEnvelope)

        let refreshed = try await store.updateStormSetupProfileAnalysis(
            secondEnvelope,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 710)
        )

        #expect(refreshed.weather == weather)
        #expect(refreshed.stormRisk == .slight)
        #expect(refreshed.severeRisk == .tornado(probability: 0.10))
        #expect(refreshed.fireRisk == .critical)
        #expect(refreshed.activeAlerts == [alert])
        #expect(refreshed.activeMesos == [meso])
        #expect(refreshed.stormSetup == stormSetup)
        #expect(refreshed.stormSetupProfileAnalysisPayload == secondEnvelope)
        #expect(refreshed.lastWeatherLoadAt == Date(timeIntervalSince1970: 300))
        #expect(refreshed.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 400))
        #expect(refreshed.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 500))
        #expect(refreshed.lastStormSetupLoadAt == Date(timeIntervalSince1970: 600))
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
        let firstProfileAnalysis = makeStormSetupProfileAnalysisPayload(
            fetchedAt: Date(timeIntervalSince1970: 805),
            expiresAt: Date(timeIntervalSince1970: 905)
        )
        let secondProfileAnalysis = makeStormSetupProfileAnalysisPayload(
            response: .init(
                mlcape: 1_420,
                mucape: 1_760,
                mlcin: -31,
                mllclMetersAgl: 1_050,
                scp: 2.4,
                stpFixed: 0.9,
                stpCin: 1.2,
                ship: 0.6,
                effectiveSrh: 98,
                effectiveBulkShearMs: 17,
                effectiveLayer: .init(
                    status: "available",
                    basePressureMb: 892,
                    topPressureMb: 726,
                    baseMetersAgl: 680,
                    topMetersAgl: 4_980
                ),
                stormMotion: .init(
                    status: "available",
                    bunkersRight: .init(
                        uMs: 4.1,
                        vMs: 1.2,
                        speedMs: 4.3,
                        uKt: 8.0,
                        vKt: 2.3,
                        speedKt: 8.4,
                        directionTowardDeg: 72
                    ),
                    uMs: 4.1,
                    vMs: 1.2,
                    speedMs: 4.3,
                    uKt: 8.0,
                    vKt: 2.3,
                    speedKt: 8.4,
                    directionTowardDeg: 72
                ),
                quality: .init(profileLevelCount: 2, warnings: ["second"])
            ),
            fetchedAt: Date(timeIntervalSince1970: 905),
            expiresAt: Date(timeIntervalSince1970: 1_005)
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
        _ = try await store.updateStormSetupProfileAnalysis(
            firstProfileAnalysis,
            for: firstContext,
            loadedAt: Date(timeIntervalSince1970: 810)
        )
        _ = try await store.updateStormSetupProfileAnalysis(
            secondProfileAnalysis,
            for: secondContext,
            loadedAt: Date(timeIntervalSince1970: 910)
        )

        let firstProjection = try #require(await store.projection(for: firstContext))
        let secondProjection = try #require(await store.projection(for: secondContext))

        #expect(firstProjection.projectionKey == HomeProjection.projectionKey(for: firstContext))
        #expect(secondProjection.projectionKey == HomeProjection.projectionKey(for: secondContext))
        #expect(firstProjection.stormSetup == firstDTO)
        #expect(secondProjection.stormSetup == secondDTO)
        #expect(firstProjection.stormSetup != secondProjection.stormSetup)
        #expect(firstProjection.stormSetupProfileAnalysisPayload == firstProfileAnalysis)
        #expect(secondProjection.stormSetupProfileAnalysisPayload == secondProfileAnalysis)
        #expect(firstProjection.stormSetupProfileAnalysisPayload != secondProjection.stormSetupProfileAnalysisPayload)
    }

    @Test("a new store over the same container reads persisted Storm Setup")
    func updateStormSetup_newStoreReadsPersistedPayload() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let context = makeContext()
        let dto = makeStormSetupDTO()
        let loadedAt = Date(timeIntervalSince1970: 950)
        let profileAnalysis = makeStormSetupProfileAnalysisPayload()

        do {
            let store = HomeProjectionStore(modelContainer: container)
            _ = try await store.updateStormSetup(dto, for: context, loadedAt: loadedAt)
            _ = try await store.updateStormSetupProfileAnalysis(
                profileAnalysis,
                for: context,
                loadedAt: Date(timeIntervalSince1970: 960)
            )
        }

        let reopenedStore = HomeProjectionStore(modelContainer: container)
        let persisted = try #require(await reopenedStore.projection(for: context))

        #expect(persisted.stormSetup == dto)
        #expect(persisted.stormSetupProfileAnalysisPayload == profileAnalysis)
        #expect(persisted.lastStormSetupLoadAt == loadedAt)
    }

    @Test("an on-disk pre-Storm-Setup container migrates and retains existing data")
    func updateStormSetup_diskContainerMigratesFromPreStormSetupSchema() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let legacySchema = Schema(versionedSchema: HomeProjectionSchemaV1.self)
        let currentSchema = Schema([HomeProjection.self])
        let storeURL = root.appendingPathComponent("SkyAware_Data.sqlite")
        let legacyConfiguration = ModelConfiguration(
            "SkyAware_Data",
            schema: legacySchema,
            url: storeURL
        )
        let currentConfiguration = ModelConfiguration(
            "SkyAware_Data",
            schema: currentSchema,
            url: storeURL
        )
        let context = makeContext()
        let loadedAt = Date(timeIntervalSince1970: 1_000)

        do {
            let container = try ModelContainer(for: legacySchema, configurations: legacyConfiguration)
            let modelContext = ModelContext(container)
            let projection = HomeProjectionSchemaV1.HomeProjection(context: context, createdAt: loadedAt, lastViewedAt: nil)
            modelContext.insert(projection)
            try modelContext.save()
        }

        let reopenedContainer = try ModelContainer(for: currentSchema, configurations: currentConfiguration)
        let reopenedStore = HomeProjectionStore(modelContainer: reopenedContainer)
        let persisted = try #require(await reopenedStore.projection(for: context))

        #expect(persisted.projectionKey == HomeProjection.projectionKey(for: context))
        #expect(persisted.locationTimestamp == context.snapshot.timestamp)
        #expect(persisted.createdAt == loadedAt)
        #expect(persisted.updatedAt == loadedAt)
        #expect(persisted.weather == nil)
        #expect(persisted.stormSetup == nil)
        #expect(persisted.stormSetupProfileAnalysisPayload == nil)
        #expect(persisted.lastStormSetupLoadAt == nil)
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

    private func makeStormSetupProfileAnalysisPayload(
        response: StormSetupProfileAnalysisDTO.Response? = nil,
        modelRunTime: Date = Date(timeIntervalSince1970: 1_717_270_400),
        validTime: Date = Date(timeIntervalSince1970: 1_717_281_600),
        forecastHour: Int = 3,
        fetchedAt: Date = Date(timeIntervalSince1970: 1_717_281_780),
        expiresAt: Date = Date(timeIntervalSince1970: 1_717_284_000)
    ) -> HomeProjectionStormSetupProfileAnalysisPayload {
        let resolvedResponse = response ?? .init(
            mlcape: 1_850,
            mucape: 2_200.5,
            mlcin: -42,
            mllclMetersAgl: 980,
            scp: 3.2,
            stpFixed: 1.4,
            stpCin: 1.8,
            ship: 0.9,
            effectiveSrh: 125.5,
            effectiveBulkShearMs: 21.5,
            effectiveLayer: .init(
                status: "available",
                basePressureMb: 887,
                topPressureMb: 715,
                baseMetersAgl: 600,
                topMetersAgl: 5_100
            ),
            stormMotion: .init(
                status: "available",
                bunkersRight: .init(
                    uMs: 4.8,
                    vMs: 1.6,
                    speedMs: 5.1,
                    uKt: 9.3,
                    vKt: 3.1,
                    speedKt: 9.9,
                    directionTowardDeg: 65
                ),
                uMs: 4.8,
                vMs: 1.6,
                speedMs: 5.1,
                uKt: 9.3,
                vKt: 3.1,
                speedKt: 9.9,
                directionTowardDeg: 65
            ),
            quality: .init(profileLevelCount: 4, warnings: ["sample"])
        )

        return HomeProjectionStormSetupProfileAnalysisPayload(
            response: resolvedResponse,
            modelRunTime: modelRunTime,
            validTime: validTime,
            forecastHour: forecastHour,
            fetchedAt: fetchedAt,
            expiresAt: expiresAt
        )
    }

    private func envelopeFieldLabels(
        _ envelope: HomeProjectionStormSetupProfileAnalysisPayload?
    ) -> [String] {
        guard let envelope else {
            return []
        }

        return Mirror(reflecting: envelope).children.compactMap(\.label)
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

enum HomeProjectionSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] { [HomeProjection.self] }

    @Model
    final class HomeProjection {
        var id: UUID
        var projectionKey: String

        var latitude: Double
        var longitude: Double
        var h3Cell: Int64
        var countyCode: String
        var forecastZone: String?
        var fireZone: String
        var placemarkSummary: String?
        var timeZoneId: String?

        var locationTimestamp: Date
        var createdAt: Date
        var updatedAt: Date
        var lastViewedAt: Date?

        var weatherPayload: HomeProjectionWeatherPayload?
        var stormRisk: StormRiskLevel?
        var severeRisk: SevereWeatherThreat?
        var fireRisk: FireRiskLevel?
        var activeAlerts: [AlertDTO]
        var activeMesos: [MdDTO]

        var lastHotAlertsLoadAt: Date?
        var lastSlowProductsLoadAt: Date?
        var lastWeatherLoadAt: Date?

        init(context: LocationContext, createdAt: Date = .now, lastViewedAt: Date? = nil) {
            id = UUID()
            projectionKey = SkyAware.HomeProjection.projectionKey(for: context)
            latitude = context.snapshot.coordinates.latitude
            longitude = context.snapshot.coordinates.longitude
            h3Cell = context.h3Cell
            countyCode = context.grid.countyCode ?? ""
            forecastZone = context.grid.forecastZone
            fireZone = context.grid.fireZone ?? ""
            placemarkSummary = context.snapshot.placemarkSummary
            timeZoneId = context.grid.timeZoneId
            locationTimestamp = context.snapshot.timestamp
            self.createdAt = createdAt
            updatedAt = createdAt
            self.lastViewedAt = lastViewedAt
            weatherPayload = nil
            stormRisk = nil
            severeRisk = nil
            fireRisk = nil
            activeAlerts = []
            activeMesos = []
            lastHotAlertsLoadAt = nil
            lastSlowProductsLoadAt = nil
            lastWeatherLoadAt = nil
        }
    }
}
}
