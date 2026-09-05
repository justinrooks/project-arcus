import ArcusCore
import CoreData
import Foundation
import SwiftData
import Testing
@testable import SkyAware

@Suite("Home Projection Store")
@MainActor
struct HomeProjectionStoreTests {
    @Test("build 113 upgrades use an isolated versioned store and leave the legacy cache untouched")
    func productionStoreFixture_opensIsolatedVersionedStore() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let fixtureURL = try #require(
            Bundle(for: HomeProjectionFixtureBundleLocator.self).url(
                forResource: "SkyAware_Data_v1_1_0_113",
                withExtension: "sqlite"
            )
        )
        let legacyStoreURL = root.appendingPathComponent("SkyAware_Data.store")
        try FileManager.default.copyItem(at: fixtureURL, to: legacyStoreURL)
        let legacyStoreData = try Data(contentsOf: legacyStoreURL)

        let storeURL = SkyAwarePersistentStoreBootstrap.storeURL(applicationSupportDirectory: root)
        #expect(storeURL != legacyStoreURL)
        let schema = productionSchema()
        let configuration = ModelConfiguration(
            SkyAwarePersistentStoreBootstrap.storeName,
            schema: schema,
            url: storeURL
        )
        let result = try SkyAwarePersistentStoreBootstrap.open(
            schema: schema,
            configuration: configuration,
            migrationPlan: SkyAwarePersistenceMigrationPlan.self,
            isProtectedDataAvailable: true
        )

        #expect(result.mode == .persistent)
        #expect(FileManager.default.fileExists(atPath: storeURL.path))
        #expect(try Data(contentsOf: legacyStoreURL) == legacyStoreData)
        #expect(FileManager.default.fileExists(atPath: storeURL.path + "-wal"))

        let reopened = try SkyAwarePersistentStoreBootstrap.open(
            schema: schema,
            configuration: configuration,
            migrationPlan: SkyAwarePersistenceMigrationPlan.self,
            isProtectedDataAvailable: true
        )
        #expect(reopened.mode == .persistent)
    }

    @Test("a healthy versioned store reopens even when protected data is locked", arguments: [true, false])
    func currentStore_reopensWithoutQuarantineOrDataLoss(isProtectedDataAvailable: Bool) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = SkyAwarePersistentStoreBootstrap.storeURL(applicationSupportDirectory: root)
        let schema = productionSchema()
        let configuration = ModelConfiguration(
            SkyAwarePersistentStoreBootstrap.storeName,
            schema: schema,
            url: storeURL
        )
        try createCurrentStore(schema: schema, configuration: configuration)

        let opened = try SkyAwarePersistentStoreBootstrap.open(
            schema: schema,
            configuration: configuration,
            migrationPlan: SkyAwarePersistenceMigrationPlan.self,
            isProtectedDataAvailable: isProtectedDataAvailable
        )

        #expect(opened.mode == .persistent)
        #expect(try ModelContext(opened.container).fetchCount(FetchDescriptor<SevereRisk>()) == 1)
        for suffix in ["", "-wal", "-shm"] {
            #expect(FileManager.default.fileExists(atPath: storeURL.path + suffix))
            // Simulator files have no Data Protection attribute; verify the actual class on device.
#if !targetEnvironment(simulator)
            let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path + suffix)
            #expect(
                attributes[.protectionKey] as? String == FileProtectionType.completeUntilFirstUserAuthentication.rawValue
            )
#endif
        }
        let context = ModelContext(opened.container)
        context.insert(BgRunSnapshot(runId: "background-write", startedAt: .now))
        try context.save()
        let reopened = try ModelContainer(for: schema, configurations: configuration)
        #expect(try ModelContext(reopened).fetchCount(FetchDescriptor<BgRunSnapshot>()) == 1)
        #expect(
            FileManager.default.fileExists(
                atPath: SkyAwarePersistentStoreBootstrap.quarantineRootURL(for: storeURL).path
            ) == false
        )
    }

    @Test("an opaque SwiftData open failure does not quarantine a healthy store")
    func opaqueOpenFailure_preservesHealthyStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storeURL = SkyAwarePersistentStoreBootstrap.storeURL(applicationSupportDirectory: root)
        let schema = productionSchema()
        let configuration = ModelConfiguration(
            SkyAwarePersistentStoreBootstrap.storeName,
            schema: schema,
            url: storeURL
        )
        try createCurrentStore(schema: schema, configuration: configuration)

        #expect(throws: (any Error).self) {
            _ = try SkyAwarePersistentStoreBootstrap.open(
                schema: schema,
                configuration: configuration,
                migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                isProtectedDataAvailable: true,
                makeContainer: failingPersistentContainerFactory(error: SwiftDataError.loadIssueModelContainer)
            )
        }

        let reopened = try ModelContainer(for: schema, configurations: configuration)
        #expect(try ModelContext(reopened).fetchCount(FetchDescriptor<SevereRisk>()) == 1)
        #expect(FileManager.default.fileExists(
            atPath: SkyAwarePersistentStoreBootstrap.quarantineRootURL(for: storeURL).path
        ) == false)
    }

    @Test("access and ambiguous failures preserve the store whether locked or unlocked", arguments: [true, false], [
        NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError),
        NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)),
        NSError(domain: NSSQLiteErrorDomain, code: 5), // SQLITE_BUSY
        NSError(domain: NSSQLiteErrorDomain, code: 10), // SQLITE_IOERR
        NSError(domain: NSSQLiteErrorDomain, code: 13), // SQLITE_FULL
        NSError(domain: NSSQLiteErrorDomain, code: 23), // SQLITE_AUTH
        NSError(domain: NSCocoaErrorDomain, code: NSPersistentStoreIncompatibleVersionHashError, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        ]),
        NSError(domain: "UnknownStoreError", code: 1)
    ])
    func unavailableStore_preservesStoreAndThrows(
        isProtectedDataAvailable: Bool,
        openError: NSError
    ) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = SkyAwarePersistentStoreBootstrap.storeURL(applicationSupportDirectory: root)
        let originalData = Data("protected-store".utf8)
        for suffix in ["", "-wal", "-shm"] {
            try originalData.write(to: URL(fileURLWithPath: storeURL.path + suffix))
        }
        let schema = productionSchema()
        let configuration = ModelConfiguration(
            SkyAwarePersistentStoreBootstrap.storeName,
            schema: schema,
            url: storeURL
        )
        var persistentAttempts = 0

        #expect(throws: (any Error).self) {
            _ = try SkyAwarePersistentStoreBootstrap.open(
                schema: schema,
                configuration: configuration,
                migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                isProtectedDataAvailable: isProtectedDataAvailable,
                makeContainer: { schema, configuration, migrationPlan in
                    if configuration.isStoredInMemoryOnly == false {
                        persistentAttempts += 1
                        throw openError
                    }
                    return try ModelContainer(
                        for: schema,
                        migrationPlan: migrationPlan,
                        configurations: configuration
                    )
                }
            )
        }

        #expect(persistentAttempts == 1)
        for suffix in ["", "-wal", "-shm"] {
            #expect(try Data(contentsOf: URL(fileURLWithPath: storeURL.path + suffix)) == originalData)
        }
        #expect(
            FileManager.default.fileExists(
                atPath: SkyAwarePersistentStoreBootstrap.quarantineRootURL(for: storeURL).path
            ) == false
        )
    }

    @Test("an unreadable current store is quarantined and recreated persistently")
    func unreadableCurrentStore_isQuarantinedAndRecreated() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = SkyAwarePersistentStoreBootstrap.storeURL(applicationSupportDirectory: root)
        let originalData = Data("unreadable-store".utf8)
        try originalData.write(to: storeURL)
        let schema = productionSchema()
        let configuration = ModelConfiguration(
            SkyAwarePersistentStoreBootstrap.storeName,
            schema: schema,
            url: storeURL
        )
        var persistentAttempts = 0

        let result = try SkyAwarePersistentStoreBootstrap.open(
            schema: schema,
            configuration: configuration,
            migrationPlan: SkyAwarePersistenceMigrationPlan.self,
            isProtectedDataAvailable: true
        ) { schema, configuration, migrationPlan in
            if configuration.isStoredInMemoryOnly == false {
                persistentAttempts += 1
            }
            return try ModelContainer(
                for: schema,
                migrationPlan: migrationPlan,
                configurations: configuration
            )
        }

        #expect(result.mode == .persistent)
        #expect(persistentAttempts == 2)
        let quarantineRoot = SkyAwarePersistentStoreBootstrap.quarantineRootURL(for: storeURL)
        let backup = try #require(
            FileManager.default.contentsOfDirectory(at: quarantineRoot, includingPropertiesForKeys: nil).first
        )
        #expect(try Data(contentsOf: backup.appendingPathComponent(storeURL.lastPathComponent)) == originalData)
        #expect(FileManager.default.fileExists(atPath: storeURL.path))
    }

    @Test("persistent recovery failure preserves the quarantine and defers startup")
    func persistentRecoveryFailure_preservesQuarantineAndThrows() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = SkyAwarePersistentStoreBootstrap.storeURL(applicationSupportDirectory: root)
        try Data("unreadable-store".utf8).write(to: storeURL)
        let schema = productionSchema()
        let configuration = ModelConfiguration(
            SkyAwarePersistentStoreBootstrap.storeName,
            schema: schema,
            url: storeURL
        )

        #expect(throws: (any Error).self) {
            _ = try SkyAwarePersistentStoreBootstrap.open(
                schema: schema,
                configuration: configuration,
                migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                isProtectedDataAvailable: true,
                makeContainer: failingPersistentContainerFactory()
            )
        }

        let quarantineRoot = SkyAwarePersistentStoreBootstrap.quarantineRootURL(for: storeURL)
        let backup = try #require(
            FileManager.default.contentsOfDirectory(at: quarantineRoot, includingPropertiesForKeys: nil).first
        )
        #expect(try Data(contentsOf: backup.appendingPathComponent(storeURL.lastPathComponent)) ==
                Data("unreadable-store".utf8))
    }

    @Test("quarantine failure preserves the store and defers startup")
    func quarantineFailure_preservesStoreAndThrows() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = SkyAwarePersistentStoreBootstrap.storeURL(applicationSupportDirectory: root)
        let originalData = Data("unreadable-store".utf8)
        try originalData.write(to: storeURL)
        try Data("blocks-quarantine-directory".utf8).write(
            to: SkyAwarePersistentStoreBootstrap.quarantineRootURL(for: storeURL)
        )
        let schema = productionSchema()
        let configuration = ModelConfiguration(
            SkyAwarePersistentStoreBootstrap.storeName,
            schema: schema,
            url: storeURL
        )

        #expect(throws: (any Error).self) {
            _ = try SkyAwarePersistentStoreBootstrap.open(
                schema: schema,
                configuration: configuration,
                migrationPlan: SkyAwarePersistenceMigrationPlan.self,
                isProtectedDataAvailable: true,
                makeContainer: failingPersistentContainerFactory()
            )
        }

        #expect(try Data(contentsOf: storeURL) == originalData)
    }

    @Test("an incomplete quarantine rollback retains every component that could not be restored")
    func quarantineRollbackFailure_preservesMovedStoreComponent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = root.appendingPathComponent("SkyAware_Data_v3.store")
        let sharedMemoryURL = URL(fileURLWithPath: storeURL.path + "-shm")
        try Data("store".utf8).write(to: storeURL)
        try Data("shared-memory".utf8).write(to: sharedMemoryURL)

        var moveAttempt = 0
        do {
            _ = try SkyAwarePersistentStoreBootstrap.quarantineStore(
                at: storeURL,
                fileManager: .default
            ) { sourceURL, destinationURL in
                moveAttempt += 1
                if moveAttempt == 2 {
                    throw QuarantineTestError.forwardMove
                }
                if moveAttempt == 3 {
                    throw QuarantineTestError.rollbackMove
                }
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            }
            Issue.record("Expected quarantine rollback to fail")
        } catch let error as SkyAwarePersistentStoreBootstrap.QuarantineError {
            #expect(error.rollbackErrors.count == 1)
            #expect(error.moveError is QuarantineTestError)
            #expect(FileManager.default.fileExists(atPath: storeURL.path) == false)
            #expect(FileManager.default.fileExists(atPath: sharedMemoryURL.path))
            #expect(
                FileManager.default.fileExists(
                    atPath: error.backupURL.appendingPathComponent(storeURL.lastPathComponent).path
                )
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("quarantine maintenance excludes backups and retains only one recent diagnostic store")
    func quarantineMaintenance_excludesAndBoundsRetention() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = SkyAwarePersistentStoreBootstrap.storeURL(applicationSupportDirectory: root)
        let quarantineRoot = SkyAwarePersistentStoreBootstrap.quarantineRootURL(for: storeURL)
        try FileManager.default.createDirectory(at: quarantineRoot, withIntermediateDirectories: true)
        let now = Date(timeIntervalSince1970: 2_000_000)
        let candidates = [
            (name: "expired", modifiedAt: now.addingTimeInterval(-8 * 24 * 60 * 60)),
            (name: "recent", modifiedAt: now.addingTimeInterval(-2 * 24 * 60 * 60)),
            (name: "newest", modifiedAt: now.addingTimeInterval(-1 * 24 * 60 * 60))
        ]
        for candidate in candidates {
            let candidateURL = quarantineRoot.appendingPathComponent(candidate.name, isDirectory: true)
            try FileManager.default.createDirectory(at: candidateURL, withIntermediateDirectories: false)
            try Data(candidate.name.utf8).write(to: candidateURL.appendingPathComponent(storeURL.lastPathComponent))
            try FileManager.default.setAttributes(
                [.modificationDate: candidate.modifiedAt],
                ofItemAtPath: candidateURL.path
            )
        }

        try SkyAwarePersistentStoreBootstrap.pruneQuarantines(
            for: storeURL,
            fileManager: .default,
            now: now
        )

        let retained = try FileManager.default.contentsOfDirectory(
            at: quarantineRoot,
            includingPropertiesForKeys: nil
        )
        let newestURL = quarantineRoot.appendingPathComponent("newest", isDirectory: true)
        #expect(retained == [newestURL])
        #expect(
            try quarantineRoot.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true
        )
        #expect(try newestURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

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

        #expect(projection.stormSetupCurrentResponse == nil)
        #expect(projection.stormSetup == nil)
        #expect(projection.lastStormSetupLoadAt == nil)
        #expect(projection.airQuality == nil)
        #expect(projection.lastAirQualityLoadAt == nil)
    }

    @Test("updating AQI reconstructs every response field and rejects older observations")
    func updateAirQuality_persistsResponseAndRejectsOlderObservation() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let newer = makeAirQualityResponse(
            aqi: 121,
            categoryIdentifier: 3,
            categoryName: "Unhealthy for Sensitive Groups",
            primaryPollutant: "PM2.5",
            observedAt: 900,
            sourceIdentifier: "airnow"
        )
        let older = makeAirQualityResponse(
            aqi: 42,
            categoryIdentifier: nil,
            categoryName: nil,
            primaryPollutant: nil,
            observedAt: 800,
            sourceIdentifier: "older-source"
        )

        _ = try await store.updateAirQuality(newer, for: context, loadedAt: Date(timeIntervalSince1970: 950))
        let rejected = try await store.updateAirQuality(older, for: context, loadedAt: Date(timeIntervalSince1970: 960))

        #expect(rejected.airQuality == newer)
        #expect(rejected.lastAirQualityLoadAt == Date(timeIntervalSince1970: 950))
        #expect(rejected.updatedAt == Date(timeIntervalSince1970: 950))
    }

    @Test("equal AQI observations replace the cached payload")
    func updateAirQuality_equalObservationReplacesCachedPayload() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let observedAt = Date(timeIntervalSince1970: 900)
        let first = AirQualityCurrentResponse(
            aqi: 50, category: nil, primaryPollutant: "O3", observedAt: observedAt, sourceIdentifier: "first"
        )
        let replacement = AirQualityCurrentResponse(
            aqi: 125, category: .init(identifier: 3, name: "Unhealthy for Sensitive Groups"),
            primaryPollutant: "PM2.5", observedAt: observedAt, sourceIdentifier: "replacement"
        )

        _ = try await store.updateAirQuality(first, for: context, loadedAt: Date(timeIntervalSince1970: 950))
        let updated = try await store.updateAirQuality(replacement, for: context, loadedAt: Date(timeIntervalSince1970: 960))

        #expect(updated.airQuality == replacement)
        #expect(updated.lastAirQualityLoadAt == Date(timeIntervalSince1970: 960))
        #expect(updated.updatedAt == Date(timeIntervalSince1970: 960))
    }

    @Test("AQI preserves optional category presence through disk reopen")
    func updateAirQuality_preservesOptionalCategoryPresence() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let schema = Schema([HomeProjection.self])
        let configuration = ModelConfiguration("SkyAware_Data", schema: schema, url: root.appendingPathComponent("SkyAware_Data.sqlite"))
        let absentContext = makeContext(h3Cell: 1)
        let emptyContext = makeContext(h3Cell: 2)
        let populatedContext = makeContext(h3Cell: 3)
        let responses = [
            (absentContext, AirQualityCurrentResponse(aqi: 50, category: nil, primaryPollutant: nil, observedAt: .now, sourceIdentifier: "airnow")),
            (emptyContext, AirQualityCurrentResponse(aqi: 75, category: .init(identifier: nil, name: nil), primaryPollutant: "O3", observedAt: .now, sourceIdentifier: "airnow")),
            (populatedContext, makeAirQualityResponse(aqi: 125, observedAt: 900))
        ]

        do {
            let store = HomeProjectionStore(modelContainer: try ModelContainer(for: schema, configurations: configuration))
            for (context, response) in responses {
                _ = try await store.updateAirQuality(response, for: context)
            }
        }

        let store = HomeProjectionStore(modelContainer: try ModelContainer(for: schema, configurations: configuration))
        for (context, response) in responses {
            #expect(try #require(await store.projection(for: context)).airQuality == response)
        }
    }

    @Test("updating AQI preserves all non-AQI projection slices and timestamps")
    func updateAirQuality_preservesExistingSlicesAndTimestamps() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let alert = Watch.sampleWatchRows[0]
        let meso = MD.sampleDiscussionDTOs[0]
        let stormSetup = makeStormSetupCurrentResponse()

        _ = try await store.updateWeather(makeWeather(), for: context, loadedAt: Date(timeIntervalSince1970: 300))
        _ = try await store.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 400)
        )
        _ = try await store.updateHotAlerts(alerts: [alert], mesos: [meso], for: context, loadedAt: Date(timeIntervalSince1970: 500))
        _ = try await store.updateStormSetup(stormSetup, for: context, loadedAt: Date(timeIntervalSince1970: 600))

        let updated = try await store.updateAirQuality(
            makeAirQualityResponse(observedAt: 700),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 800)
        )

        #expect(updated.weather == makeWeather())
        #expect(updated.stormRisk == .slight)
        #expect(updated.severeRisk == .tornado(probability: 0.10))
        #expect(updated.fireRisk == .critical)
        #expect(updated.activeAlerts == [alert])
        #expect(updated.activeMesos == [meso])
        #expect(updated.stormSetupCurrentResponse == stormSetup)
        #expect(updated.lastWeatherLoadAt == Date(timeIntervalSince1970: 300))
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 400))
        #expect(updated.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 500))
        #expect(updated.lastStormSetupLoadAt == Date(timeIntervalSince1970: 600))
        #expect(updated.lastAirQualityLoadAt == Date(timeIntervalSince1970: 800))
    }

    @Test("AQI survives an on-disk current-schema reopen for independent projection keys")
    func updateAirQuality_diskContainerReopensIndependentProjections() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let schema = Schema([HomeProjection.self])
        let configuration = ModelConfiguration("SkyAware_Data", schema: schema, url: root.appendingPathComponent("SkyAware_Data.sqlite"))
        let first = makeContext(h3Cell: 123_456)
        let second = makeContext(h3Cell: 654_321)
        let firstResponse = makeAirQualityResponse(aqi: 52, observedAt: 700)
        let secondResponse = makeAirQualityResponse(aqi: 152, observedAt: 800)

        do {
            let store = HomeProjectionStore(modelContainer: try ModelContainer(for: schema, configurations: configuration))
            _ = try await store.updateAirQuality(firstResponse, for: first, loadedAt: Date(timeIntervalSince1970: 900))
            _ = try await store.updateAirQuality(secondResponse, for: second, loadedAt: Date(timeIntervalSince1970: 950))
        }

        let reopenedStore = HomeProjectionStore(modelContainer: try ModelContainer(for: schema, configurations: configuration))
        #expect(try #require(await reopenedStore.projection(for: first)).airQuality == firstResponse)
        #expect(try #require(await reopenedStore.projection(for: second)).airQuality == secondResponse)
    }

    @Test("updating Storm Setup stores the aggregate payload and load timestamp")
    func updateStormSetup_persistsAggregatePayloadAndLoadTimestamp() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let loadedAt = Date(timeIntervalSince1970: 600)
        let response = makeStormSetupCurrentResponse(profileAnalysis: makeAnvilAnalyzeProfileResponse())

        let updated = try await store.updateStormSetup(response, for: context, loadedAt: loadedAt)

        #expect(updated.stormSetupCurrentResponse == response)
        #expect(updated.stormSetup == StormSetupDTO(response: response))
        #expect(updated.lastStormSetupLoadAt == loadedAt)
        #expect(updated.updatedAt == loadedAt)

        let persisted = try #require(await store.projection(for: context))
        #expect(persisted.stormSetupCurrentResponse == response)
        #expect(persisted.stormSetup == StormSetupDTO(response: response))
        #expect(persisted.lastStormSetupLoadAt == loadedAt)
    }

    @Test("updating Storm Setup clears older profile analysis when the aggregate omits it")
    func updateStormSetup_clearsOlderProfileAnalysisWhenAggregateIsNil() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let firstLoadedAt = Date(timeIntervalSince1970: 600)
        let secondLoadedAt = Date(timeIntervalSince1970: 650)
        let firstResponse = makeStormSetupCurrentResponse(profileAnalysis: makeAnvilAnalyzeProfileResponse())
        let secondResponse = makeStormSetupCurrentResponse(summary: "Newer aggregate", profileAnalysis: nil)

        _ = try await store.updateStormSetup(firstResponse, for: context, loadedAt: firstLoadedAt)
        let updated = try await store.updateStormSetup(secondResponse, for: context, loadedAt: secondLoadedAt)

        #expect(updated.stormSetupCurrentResponse == secondResponse)
        #expect(updated.stormSetup == StormSetupDTO(response: secondResponse))
        #expect(updated.lastStormSetupLoadAt == secondLoadedAt)

        let persisted = try #require(await store.projection(for: context))
        #expect(persisted.stormSetupCurrentResponse == secondResponse)
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
        let response = makeStormSetupCurrentResponse(profileAnalysis: makeAnvilAnalyzeProfileResponse())

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

        let updated = try await store.updateStormSetup(response, for: context, loadedAt: stormLoadedAt)

        #expect(updated.weather == weather)
        #expect(updated.stormRisk == StormRiskLevel.slight)
        #expect(updated.severeRisk == SevereWeatherThreat.tornado(probability: 0.10))
        #expect(updated.fireRisk == FireRiskLevel.critical)
        #expect(updated.activeAlerts == [alert])
        #expect(updated.activeMesos == [meso])
        #expect(updated.stormSetupCurrentResponse == response)
        #expect(updated.stormSetup == StormSetupDTO(response: response))
        #expect(updated.lastWeatherLoadAt == Date(timeIntervalSince1970: 300))
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 400))
        #expect(updated.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 500))
        #expect(updated.updatedAt == stormLoadedAt)
        #expect(updated.lastStormSetupLoadAt == stormLoadedAt)
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
        let firstResponse = makeStormSetupCurrentResponse(
            h3Cell: 123_456,
            surfaceHeightMslM: 1_100,
            profileAnalysis: makeAnvilAnalyzeProfileResponse()
        )
        let secondResponse = makeStormSetupCurrentResponse(
            h3Cell: 654_321,
            surfaceHeightMslM: 1_240,
            summary: "Second location",
            profileAnalysis: nil
        )

        _ = try await store.updateStormSetup(
            firstResponse,
            for: firstContext,
            loadedAt: Date(timeIntervalSince1970: 800)
        )
        _ = try await store.updateStormSetup(
            secondResponse,
            for: secondContext,
            loadedAt: Date(timeIntervalSince1970: 900)
        )

        let firstProjection = try #require(await store.projection(for: firstContext))
        let secondProjection = try #require(await store.projection(for: secondContext))

        #expect(firstProjection.projectionKey == HomeProjection.projectionKey(for: firstContext))
        #expect(secondProjection.projectionKey == HomeProjection.projectionKey(for: secondContext))
        #expect(firstProjection.stormSetupCurrentResponse == firstResponse)
        #expect(secondProjection.stormSetupCurrentResponse == secondResponse)
        #expect(firstProjection.stormSetup == StormSetupDTO(response: firstResponse))
        #expect(secondProjection.stormSetup == StormSetupDTO(response: secondResponse))
        #expect(firstProjection.stormSetup != secondProjection.stormSetup)
    }

    @Test("a new store over the same container reads persisted Storm Setup")
    func updateStormSetup_newStoreReadsPersistedAggregate() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let context = makeContext()
        let response = makeStormSetupCurrentResponse(profileAnalysis: makeAnvilAnalyzeProfileResponse())
        let loadedAt = Date(timeIntervalSince1970: 950)

        do {
            let store = HomeProjectionStore(modelContainer: container)
            _ = try await store.updateStormSetup(response, for: context, loadedAt: loadedAt)
        }

        let reopenedStore = HomeProjectionStore(modelContainer: container)
        let persisted = try #require(await reopenedStore.projection(for: context))

        #expect(persisted.stormSetupCurrentResponse == response)
        #expect(persisted.stormSetup == StormSetupDTO(response: response))
        #expect(persisted.lastStormSetupLoadAt == loadedAt)
    }

    @Test("an on-disk current-schema container survives a process-style reopen")
    func updateStormSetup_diskContainerReopensWithPersistedAggregate() async throws {
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
        let stormLoadedAt = Date(timeIntervalSince1970: 950)
        let coreLoadedAt = Date(timeIntervalSince1970: 900)
        let response = makeStormSetupCurrentResponse(profileAnalysis: makeAnvilAnalyzeProfileResponse())

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            let store = HomeProjectionStore(modelContainer: container)
            _ = try await store.commitCore(
                .init(
                    weather: makeWeather(),
                    slowProducts: (.slight, .wind(probability: 0.15), .critical),
                    hotAlerts: (alerts: [], mesos: [])
                ),
                for: context,
                loadedAt: coreLoadedAt
            )
            _ = try await store.updateStormSetup(response, for: context, loadedAt: stormLoadedAt)
        }

        let reopenedContainer = try ModelContainer(for: schema, configurations: configuration)
        let reopenedStore = HomeProjectionStore(modelContainer: reopenedContainer)
        let persisted = try #require(await reopenedStore.projection(for: context))

        #expect(persisted.stormSetupCurrentResponse == response)
        #expect(persisted.stormSetup == StormSetupDTO(response: response))
        #expect(persisted.lastStormSetupLoadAt == stormLoadedAt)
        #expect(persisted.weather == makeWeather())
        #expect(persisted.lastWeatherLoadAt == coreLoadedAt)
        #expect(persisted.lastSlowProductsLoadAt == coreLoadedAt)
        #expect(persisted.lastHotAlertsLoadAt == coreLoadedAt)
        #expect(HomeView.selectProjection(from: [persisted], currentContext: context) == persisted)
    }

    @Test("a corrupt Storm Setup cache is treated as a cache miss")
    func projection_corruptStormSetupPayloadPreservesOtherSlices() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let weather = makeWeather()
        let response = makeStormSetupCurrentResponse()

        _ = try await store.updateWeather(weather, for: context, loadedAt: Date(timeIntervalSince1970: 300))
        _ = try await store.updateStormSetup(response, for: context, loadedAt: Date(timeIntervalSince1970: 600))

        let contextForCorruption = ModelContext(container)
        let projection = try #require(contextForCorruption.fetch(FetchDescriptor<HomeProjection>()).first)
        projection.stormSetupCurrentResponseData = Data("corrupt".utf8)
        try contextForCorruption.save()

        let reopenedStore = HomeProjectionStore(modelContainer: container)
        let persisted = try #require(await reopenedStore.projection(for: context))

        #expect(persisted.stormSetupCurrentResponse == nil)
        #expect(persisted.stormSetup == nil)
        #expect(persisted.airQuality == nil)
        #expect(persisted.lastAirQualityLoadAt == nil)
        #expect(persisted.weather == weather)
        #expect(persisted.lastWeatherLoadAt == Date(timeIntervalSince1970: 300))
        #expect(persisted.lastStormSetupLoadAt == Date(timeIntervalSince1970: 600))
    }

    @Test("the immediate pre-AQI store migrates without losing unrelated projection data")
    func projection_immediatePreAQIStoreMigratesWithoutAirQualityCache() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let storeURL = root.appendingPathComponent("SkyAware_Data.sqlite")
        let context = makeContext()
        let weather = makeWeather()
        let createdAt = Date(timeIntervalSince1970: 100)
        let fixtureURL = try #require(
            Bundle(for: HomeProjectionFixtureBundleLocator.self).url(
                forResource: "SkyAware_Data",
                withExtension: "sqlite"
            )
        )
        try FileManager.default.copyItem(at: fixtureURL, to: storeURL)

        let schema = Schema([HomeProjection.self])
        let configuration = ModelConfiguration("SkyAware_Data", schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let store = HomeProjectionStore(modelContainer: container)
        let persisted = try #require(await store.projection(for: context))

        #expect(persisted.weather == weather)
        #expect(persisted.createdAt == createdAt)
        #expect(persisted.stormSetupCurrentResponse == nil)
        #expect(persisted.stormSetup == nil)
        #expect(persisted.airQuality == nil)
        #expect(persisted.lastAirQualityLoadAt == nil)
        let migratedModel = try #require(ModelContext(container).fetch(FetchDescriptor<HomeProjection>()).first)
        #expect(migratedModel.convectiveRiskComparisonLocationKey == nil)
        #expect(migratedModel.convectiveRiskComparisonSourceKey == nil)
        #expect(migratedModel.fireRiskComparisonLocationKey == nil)
        #expect(migratedModel.fireRiskComparisonSourceKey == nil)
    }


    @Test("updating slow products seeds a baseline without a change and preserves existing slices")
    func updateSlowProducts_seedsBaselineWithoutChangeAndPreservesExistingSlices() async throws {
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

        let change = try await store.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.10),
            fireRisk: .critical,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 500)
        )

        #expect(change == nil)

        let updated = try #require(await store.projection(for: context))
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

    @Test("updating slow products seeds incomplete baselines without a change")
    func updateSlowProducts_seedsIncompleteBaselineWithoutChange() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let loadedAt = Date(timeIntervalSince1970: 505)

        let change = try await store.updateSlowProducts(
            stormRisk: .high,
            severeRisk: nil,
            fireRisk: .critical,
            for: context,
            loadedAt: loadedAt
        )

        #expect(change == nil)

        let updated = try #require(await store.projection(for: context))
        #expect(updated.stormRisk == .high)
        #expect(updated.severeRisk == nil)
        #expect(updated.fireRisk == .critical)
        #expect(updated.lastSlowProductsLoadAt == loadedAt)
    }

    @Test("updating slow products overwrites stale severe risk with all clear")
    func updateSlowProducts_detectsRiskProfileChangesAtomically() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()

        _ = try await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .tornado(probability: 0.02),
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 1),
            fireSource: makeSource(revision: 1),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 500)
        )

        let change = try #require(await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 2),
            fireSource: makeSource(revision: 2),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 560)
        ))

        #expect(change.projectionKey == HomeProjection.projectionKey(for: context))
        #expect(change.locationSummary == context.snapshot.placemarkSummary)
        #expect(change.changedDimensions == [.severe])
        #expect(change.previous == RiskProfile(
            stormRisk: .marginal,
            severeRisk: .tornado(probability: 0.02),
            fireRisk: .clear
        ))
        #expect(change.current == RiskProfile(
            stormRisk: .marginal,
            severeRisk: .allClear,
            fireRisk: .clear
        ))
        #expect(change.previousFingerprint == "storm=2|severe=tornado:2|fire=0")
        #expect(change.currentFingerprint == "storm=2|severe=allClear|fire=0")

        let updated = try #require(await store.projection(for: context))
        #expect(updated.severeRisk == .allClear)
        #expect(updated.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 560))
    }

    @Test("coordinate movement within one projection rebases unchanged-source risk without a change")
    func updateSlowProducts_sameProjectionMovementDoesNotCreateRiskChange() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let first = makeContext(latitude: 39.7500, longitude: -104.4400, timestamp: 100)
        let moved = makeContext(latitude: 39.7509, longitude: -104.4409, timestamp: 200)
        let source = makeSource(revision: 1)

        #expect(HomeProjection.projectionKey(for: first) == HomeProjection.projectionKey(for: moved))
        _ = try await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: source,
            fireSource: source,
            for: first
        )

        let movedChange = try await store.updateSlowProducts(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: source,
            fireSource: source,
            for: moved
        )
        let revisitChange = try await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: source,
            fireSource: source,
            for: first
        )

        #expect(movedChange == nil)
        #expect(revisitChange == nil)
    }

    @Test("stable comparison location emits a change for a newer accepted source")
    func updateSlowProducts_stableLocationWithNewSourceCreatesRiskChange() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()

        _ = try await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 1),
            fireSource: makeSource(revision: 1),
            for: context
        )
        let sameSourceChange = try await store.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 1),
            fireSource: makeSource(revision: 1),
            for: context
        )
        let change = try #require(await store.updateSlowProducts(
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 2),
            fireSource: makeSource(revision: 2),
            for: context
        ))

        #expect(sameSourceChange == nil)
        #expect(change.changedDimensions == [.storm])
        #expect(change.previous.stormRisk == .slight)
        #expect(change.current.stormRisk == .enhanced)
    }

    @Test("leaving and revisiting a projection seeds before later accepted changes")
    func updateSlowProducts_revisitedProjectionDoesNotUseHistoricalBaseline() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let first = makeContext(h3Cell: 123_456)
        let second = makeContext(
            latitude: 40.02,
            longitude: -104.87,
            timestamp: 200,
            countyCode: "COC007",
            forecastZone: "COZ041",
            fireZone: "COZ217",
            h3Cell: 654_321
        )

        _ = try await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 1),
            fireSource: makeSource(revision: 1),
            for: first
        )
        let newLocation = try await store.updateSlowProducts(
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 1),
            fireSource: makeSource(revision: 1),
            for: second
        )
        let revisit = try await store.updateSlowProducts(
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 2),
            fireSource: makeSource(revision: 2),
            for: first
        )
        let stableChange = try #require(await store.updateSlowProducts(
            stormRisk: .moderate,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 3),
            fireSource: makeSource(revision: 3),
            for: first
        ))

        #expect(newLocation == nil)
        #expect(revisit == nil)
        #expect(stableChange.changedDimensions == [.storm])
    }

    @Test("accepted source clears every other active or partial comparison baseline")
    func updateSlowProducts_acceptedSourceClearsCorruptComparisonBaselines() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let target = makeContext(h3Cell: 123_456)
        let locationOnly = makeContext(h3Cell: 654_321)
        let sourceOnly = makeContext(h3Cell: 987_654)
        let modelContext = ModelContext(container)
        let targetProjection = HomeProjection(context: target, createdAt: Date(timeIntervalSince1970: 100))
        let locationProjection = HomeProjection(context: locationOnly, createdAt: Date(timeIntervalSince1970: 101))
        let sourceProjection = HomeProjection(context: sourceOnly, createdAt: Date(timeIntervalSince1970: 102))
        let source = makeSource(revision: 1).persistenceToken

        locationProjection.convectiveRiskComparisonLocationKey = HomeProjection.riskComparisonLocationKey(for: locationOnly)
        sourceProjection.convectiveRiskComparisonSourceKey = source
        modelContext.insert(targetProjection)
        modelContext.insert(locationProjection)
        modelContext.insert(sourceProjection)
        try modelContext.save()

        let store = HomeProjectionStore(modelContainer: container)
        _ = try await store.commitCore(
            .init(
                slowProducts: (.slight, .allClear, nil),
                updatesConvectiveRisk: true,
                updatesFireRisk: false,
                convectiveSource: makeSource(revision: 2)
            ),
            for: target,
            loadedAt: Date(timeIntervalSince1970: 200)
        )

        let projections = try ModelContext(container).fetch(FetchDescriptor<HomeProjection>())
        let current = try #require(projections.first { $0.projectionKey == targetProjection.projectionKey })
        #expect(current.convectiveRiskComparisonLocationKey == HomeProjection.riskComparisonLocationKey(for: target))
        #expect(current.convectiveRiskComparisonSourceKey == makeSource(revision: 2).persistenceToken)
        #expect(projections.filter { $0.id != current.id }.allSatisfy {
            $0.convectiveRiskComparisonLocationKey == nil && $0.convectiveRiskComparisonSourceKey == nil
        })
    }

    @Test("domain-local changes do not require the other domain to be available")
    func updateSlowProducts_partialProfilesEmitForAuthoritativeDomain() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let convectiveContext = makeContext()
        let fireContext = makeContext(h3Cell: 654_321)

        _ = try await store.commitCore(
            .init(
                slowProducts: (.marginal, .allClear, nil),
                updatesConvectiveRisk: true,
                updatesFireRisk: false,
                convectiveSource: makeSource(revision: 1)
            ),
            for: convectiveContext
        )
        let convectiveChange = try #require(await store.commitCore(
            .init(
                slowProducts: (.slight, .wind(probability: 0.15), nil),
                updatesConvectiveRisk: true,
                updatesFireRisk: false,
                convectiveSource: makeSource(revision: 2)
            ),
            for: convectiveContext
        ))

        _ = try await store.commitCore(
            .init(
                slowProducts: (nil, nil, .clear),
                updatesConvectiveRisk: false,
                updatesFireRisk: true,
                fireSource: makeSource(revision: 1)
            ),
            for: fireContext
        )
        let fireChange = try #require(await store.commitCore(
            .init(
                slowProducts: (nil, nil, .critical),
                updatesConvectiveRisk: false,
                updatesFireRisk: true,
                fireSource: makeSource(revision: 2)
            ),
            for: fireContext
        ))

        #expect(try #require(convectiveChange.riskProfileChange).changedDimensions == [.storm, .severe])
        #expect(try #require(fireChange.riskProfileChange).changedDimensions == [.fire])
    }

    @Test("failed saves roll back risk values and comparison metadata")
    func updateSlowProducts_failedSaveRollsBackBaseline() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()

        _ = try await store.updateSlowProducts(
            stormRisk: .marginal,
            severeRisk: .allClear,
            fireRisk: .clear,
            convectiveSource: makeSource(revision: 1),
            fireSource: makeSource(revision: 1),
            for: context
        )
        await store.failNextSaveForTesting()
        await #expect(throws: (any Error).self) {
            try await store.updateSlowProducts(
                stormRisk: .enhanced,
                severeRisk: .tornado(probability: 0.30),
                fireRisk: .critical,
                convectiveSource: makeSource(revision: 2),
                fireSource: makeSource(revision: 2),
                for: context
            )
        }
        _ = try await store.updateWeather(makeWeather(), for: context)

        let change = try #require(await store.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .allClear,
            fireRisk: .elevated,
            convectiveSource: makeSource(revision: 2),
            fireSource: makeSource(revision: 2),
            for: context
        ))

        #expect(change.previous.stormRisk == .marginal)
        #expect(change.previous.severeRisk == .allClear)
        #expect(change.previous.fireRisk == .clear)
        #expect(change.changedDimensions == [.storm, .fire])
    }

    @Test("risk profile fingerprints normalize severe probabilities to whole percentages")
    func riskProfile_normalizesSevereProbabilitiesToWholePercentFingerprints() {
        let first = RiskProfile(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.1041),
            fireRisk: .critical
        )
        let second = RiskProfile(
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.1049),
            fireRisk: .critical
        )

        #expect(first == second)
        #expect(first.fingerprint == second.fingerprint)
        #expect(first.fingerprint == "storm=3|severe=tornado:10|fire=8")
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

    @Test("projections save and reopen every severe risk variant")
    func updateSlowProducts_savesAndReopensEverySevereRiskVariant() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let schema = Schema([HomeProjection.self])
        let storeURL = root.appendingPathComponent("SkyAware_Data.sqlite")
        let configuration = ModelConfiguration("SkyAware_Data", schema: schema, url: storeURL)
        let values: [SevereWeatherThreat] = [
            .allClear,
            .wind(probability: 0.20),
            .hail(probability: 0.35),
            .tornado(probability: 0.70)
        ]
        let updatedValues: [SevereWeatherThreat] = [
            .wind(probability: 0.15),
            .hail(probability: 0.25),
            .tornado(probability: 0.05),
            .allClear
        ]

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            let store = HomeProjectionStore(modelContainer: container)

            for (index, value) in values.enumerated() {
                let context = makeContext(h3Cell: Int64(123_456 + index))
                _ = try await store.updateSlowProducts(
                    stormRisk: .slight,
                    severeRisk: value,
                    fireRisk: .critical,
                    for: context,
                    loadedAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
                )
            }

            for (index, value) in values.enumerated() {
                let context = makeContext(h3Cell: Int64(123_456 + index))
                let persisted = try #require(await store.projection(for: context))
                #expect(persisted.severeRisk == value)
            }
        }

        do {
            let reopenedContainer = try ModelContainer(for: schema, configurations: configuration)
            let reopenedStore = HomeProjectionStore(modelContainer: reopenedContainer)

            for (index, value) in updatedValues.enumerated() {
                let context = makeContext(h3Cell: Int64(123_456 + index))
                let persisted = try #require(await reopenedStore.projection(for: context))
                #expect(persisted.severeRisk == values[index])
                _ = try await reopenedStore.updateSlowProducts(
                    stormRisk: persisted.stormRisk,
                    severeRisk: value,
                    fireRisk: persisted.fireRisk,
                    for: context,
                    loadedAt: Date(timeIntervalSince1970: TimeInterval(200 + index))
                )
            }
        }

        let updatedContainer = try ModelContainer(for: schema, configurations: configuration)
        let updatedStore = HomeProjectionStore(modelContainer: updatedContainer)

        for (index, value) in updatedValues.enumerated() {
            let context = makeContext(h3Cell: Int64(123_456 + index))
            let persisted = try #require(await updatedStore.projection(for: context))
            #expect(persisted.severeRisk == value)
        }
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

    @Test("disk-reopened partial accepted projections remain available to Today")
    func partialAcceptedProjections_reopenAsDisplayReady() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeProjectionStoreTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let schema = Schema([HomeProjection.self])
        let storeURL = root.appendingPathComponent("SkyAware_Data.sqlite")
        let configuration = ModelConfiguration("SkyAware_Data", schema: schema, url: storeURL)
        let weatherContext = makeContext(h3Cell: 123_456)
        let alertsContext = makeContext(h3Cell: 654_321)
        let partialRiskContext = makeContext(h3Cell: 456_789)
        let completeContext = makeContext(h3Cell: 789_123)

        func todayContentState(for projection: HomeProjectionRecord?) -> TodayContentState {
            TodayContentState.from(
                readinessState: .loadingLocalData,
                hasCachedContent: projection != nil,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: false
            )
        }

        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            let store = HomeProjectionStore(modelContainer: container)
            _ = try await store.commitCore(
                .init(weather: makeWeather()),
                for: weatherContext,
                loadedAt: Date(timeIntervalSince1970: 450)
            )
            _ = try await store.updateHotAlerts(
                alerts: [],
                mesos: [],
                for: alertsContext,
                loadedAt: Date(timeIntervalSince1970: 460)
            )
            _ = try await store.commitCore(
                .init(
                    slowProducts: (.slight, nil, nil),
                    updatesConvectiveRisk: true,
                    updatesFireRisk: false
                ),
                for: partialRiskContext,
                loadedAt: Date(timeIntervalSince1970: 470)
            )
            _ = try await store.commitCore(
                .init(
                    weather: makeWeather(),
                    slowProducts: (.slight, .wind(probability: 0.15), .critical),
                    hotAlerts: (alerts: [], mesos: [])
                ),
                for: completeContext,
                loadedAt: Date(timeIntervalSince1970: 480)
            )

            let preCloseWeather = try #require(await store.projection(for: weatherContext))
            let preCloseAlerts = try #require(await store.projection(for: alertsContext))
            let preClosePartialRisk = try #require(await store.projection(for: partialRiskContext))
            let preCloseComplete = try #require(await store.projection(for: completeContext))
            #expect(todayContentState(for: HomeView.selectProjection(from: [preCloseWeather], currentContext: weatherContext)) == .cachedRefreshing)
            #expect(todayContentState(for: HomeView.selectProjection(from: [preCloseAlerts], currentContext: alertsContext)) == .cachedRefreshing)
            #expect(todayContentState(for: HomeView.selectProjection(from: [preClosePartialRisk], currentContext: partialRiskContext)) == .cachedRefreshing)
            #expect(todayContentState(for: HomeView.selectProjection(from: [preCloseComplete], currentContext: completeContext)) == .cachedRefreshing)
        }

        let reopenedContainer = try ModelContainer(for: schema, configurations: configuration)
        let reopenedStore = HomeProjectionStore(modelContainer: reopenedContainer)
        let weatherProjection = try #require(await reopenedStore.projection(for: weatherContext))
        let alertsProjection = try #require(await reopenedStore.projection(for: alertsContext))
        let partialRiskProjection = try #require(await reopenedStore.projection(for: partialRiskContext))
        let completeProjection = try #require(await reopenedStore.projection(for: completeContext))

        #expect(HomeView.selectProjection(from: [weatherProjection], currentContext: weatherContext) == weatherProjection)
        #expect(HomeView.selectProjection(from: [alertsProjection], currentContext: alertsContext) == alertsProjection)
        #expect(HomeView.selectProjection(from: [partialRiskProjection], currentContext: partialRiskContext) == partialRiskProjection)
        #expect(HomeView.selectProjection(from: [completeProjection], currentContext: completeContext) == completeProjection)
        #expect(todayContentState(for: HomeView.selectProjection(from: [weatherProjection], currentContext: weatherContext)) == .cachedRefreshing)
        #expect(todayContentState(for: HomeView.selectProjection(from: [alertsProjection], currentContext: alertsContext)) == .cachedRefreshing)
        #expect(todayContentState(for: HomeView.selectProjection(from: [partialRiskProjection], currentContext: partialRiskContext)) == .cachedRefreshing)
        #expect(todayContentState(for: HomeView.selectProjection(from: [completeProjection], currentContext: completeContext)) == .cachedRefreshing)

        let emptyProjection = HomeProjection(context: makeContext(h3Cell: 999_999)).record
        #expect(HomeView.selectProjection(from: [emptyProjection], currentContext: nil) == nil)
    }

    @Test("a severe-weather core commit is display-ready when WeatherKit is unavailable")
    func coreCommit_withoutWeatherIsDisplayReady() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()

        _ = try await store.commitCore(
            .init(
                slowProducts: (.slight, .wind(probability: 0.15), .critical),
                hotAlerts: (alerts: [Watch.sampleWatchRows[0]], mesos: [])
            ),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 500)
        )

        let committed = try #require(await store.projection(for: context))
        #expect(committed.lastWeatherLoadAt == nil)
        #expect(committed.lastSlowProductsLoadAt != nil)
        #expect(committed.lastHotAlertsLoadAt != nil)
        #expect(HomeView.selectProjection(from: [committed], currentContext: context) == committed)
        #expect(HomeView.selectProjection(from: [committed], currentContext: nil) == committed)

        let modelContext = ModelContext(container)
        let model = try #require(modelContext.fetch(FetchDescriptor<HomeProjection>()).first)
        #expect(HomeView.selectProjection(from: [model], currentContext: context)?.record == committed)
        #expect(HomeView.selectProjection(from: [model], currentContext: nil)?.record == committed)
    }

    @Test("core commit saves authorized slices together and derives the risk delta from persisted state")
    func coreCommit_persistsAuthorizedSlicesAndUsesPersistedRiskProfile() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let originalAlert = Watch.sampleWatchRows[0]

        _ = try await store.commitCore(
            .init(
                weather: makeWeather(),
                slowProducts: (.slight, .wind(probability: 0.15), .critical),
                convectiveSource: makeSource(revision: 1),
                fireSource: makeSource(revision: 1),
                hotAlerts: (alerts: [originalAlert], mesos: [MD.sampleDiscussionDTOs[0]])
            ),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 500)
        )
        let change = try await store.commitCore(
            .init(
                slowProducts: (.enhanced, .tornado(probability: 0.30), .elevated),
                convectiveSource: makeSource(revision: 2),
                fireSource: makeSource(revision: 2)
            ),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 600)
        )
        let riskProfileChange = try #require(change.riskProfileChange)

        #expect(riskProfileChange.previous == RiskProfile(
            stormRisk: .slight,
            severeRisk: .wind(probability: 0.15),
            fireRisk: .critical
        ))
        #expect(riskProfileChange.current == RiskProfile(
            stormRisk: .enhanced,
            severeRisk: .tornado(probability: 0.30),
            fireRisk: .elevated
        ))
        let committed = try #require(await store.projection(for: context))
        #expect(committed.weather == makeWeather())
        #expect(committed.activeAlerts == [originalAlert])
        #expect(committed.lastWeatherLoadAt == Date(timeIntervalSince1970: 500))
        #expect(committed.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 500))
        #expect(committed.lastSlowProductsLoadAt == Date(timeIntervalSince1970: 600))
        #expect(change.record == committed)
    }

    @Test("core commit preserves skipped slices and persists authoritative empty alerts")
    func coreCommit_preservesSkippedSlicesAndPersistsAuthoritativeEmptyAlerts() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let store = HomeProjectionStore(modelContainer: container)
        let context = makeContext()

        _ = try await store.commitCore(
            .init(
                weather: makeWeather(),
                slowProducts: (.slight, .wind(probability: 0.15), .critical),
                hotAlerts: (alerts: [Watch.sampleWatchRows[0]], mesos: [MD.sampleDiscussionDTOs[0]])
            ),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 500)
        )
        _ = try await store.commitCore(
            .init(hotAlerts: (alerts: [], mesos: [])),
            for: context,
            loadedAt: Date(timeIntervalSince1970: 600)
        )

        let committed = try #require(await store.projection(for: context))
        #expect(committed.weather == makeWeather())
        #expect(committed.stormRisk == .slight)
        #expect(committed.severeRisk == .wind(probability: 0.15))
        #expect(committed.fireRisk == .critical)
        #expect(committed.activeAlerts.isEmpty)
        #expect(committed.activeMesos.isEmpty)
        #expect(committed.lastHotAlertsLoadAt == Date(timeIntervalSince1970: 600))
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

    private func productionSchema() -> Schema {
        Schema(versionedSchema: SkyAwarePersistenceSchema.self)
    }

    private func createCurrentStore(
        schema: Schema,
        configuration: ModelConfiguration
    ) throws {
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        context.insert(makeCurrentSevereRisk())
        try context.save()
    }

    private func makeCurrentSevereRisk() -> SevereRisk {
        SevereRisk(
            type: .tornado,
            probability: .percent(0.10),
            threatLevel: .tornado(probability: 0.10),
            issued: Date(timeIntervalSince1970: 100),
            valid: Date(timeIntervalSince1970: 100),
            expires: Date(timeIntervalSince1970: 200),
            dn: 10,
            stroke: nil,
            fill: nil,
            polygons: [],
            label: "0.10"
        )
    }

    private func failingPersistentContainerFactory(
        error: any Error = NSError(domain: NSSQLiteErrorDomain, code: 26) // SQLITE_NOTADB
    ) -> SkyAwarePersistentStoreBootstrap.ContainerFactory {
        { _, configuration, _ in
            #expect(configuration.isStoredInMemoryOnly == false)
            throw error
        }
    }

    private enum QuarantineTestError: Error {
        case forwardMove
        case rollbackMove
    }

    private func makeSource(revision: TimeInterval) -> SpcMapSourceIdentity {
        .forecast(
            issued: Date(timeIntervalSince1970: revision * 100),
            valid: Date(timeIntervalSince1970: revision * 100 + 10),
            expires: Date(timeIntervalSince1970: revision * 100 + 90)
        )
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

    private func makeAirQualityResponse(
        aqi: Int = 121,
        categoryIdentifier: Int? = 3,
        categoryName: String? = "Unhealthy for Sensitive Groups",
        primaryPollutant: String? = "PM2.5",
        observedAt: TimeInterval = 700,
        sourceIdentifier: String = "airnow"
    ) -> AirQualityCurrentResponse {
        AirQualityCurrentResponse(
            aqi: aqi,
            category: .init(identifier: categoryIdentifier, name: categoryName),
            primaryPollutant: primaryPollutant,
            observedAt: Date(timeIntervalSince1970: observedAt),
            sourceIdentifier: sourceIdentifier
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

    private func makeStormSetupCurrentResponse(
        h3Cell: Int64 = 123_456,
        surfaceHeightMslM: Double = 1_132.4,
        summary: String = "The setup is strongly supportive. Multiple ingredients line up, including instability, deep shear, and low-level rotation.",
        profileAnalysis: AnvilAnalyzeProfileResponse? = nil
    ) -> StormSetupCurrentResponse {
        let modelRunTime = Date(timeIntervalSince1970: 1_717_270_400)
        let validTime = Date(timeIntervalSince1970: 1_717_281_600)
        let freshness = IngredientFreshness(
            sourceValidTime: validTime,
            modelRunTime: modelRunTime,
            forecastHour: 3,
            fetchedAt: Date(timeIntervalSince1970: 1_717_281_780),
            expiresAt: Date(timeIntervalSince1970: 1_717_284_000),
            isStale: false,
            isDegraded: false
        )

        return StormSetupCurrentResponse(
            setup: .init(
                h3Cell: h3Cell,
                centroid: .init(latitude: 39.5, longitude: -100.0),
                source: .init(
                    model: .hrrr,
                    product: .wrfsfc,
                    domain: .conus,
                    runTime: modelRunTime,
                    forecastHour: 3,
                    validTime: validTime,
                    fieldSetVersion: .tornadoV1,
                    bbox: .init(
                        leftlon: -104.3,
                        rightlon: -96.2,
                        toplat: 41.5,
                        bottomlat: 36.8
                    ),
                    nomadsURL: URL(string: "https://example.invalid/storm-setup")
                ),
                surfaceHeightMslM: surfaceHeightMslM,
                freshness: freshness
            ),
            ingredients: .init(
                canonical: makeTornadoRawParameters(),
                diagnostics: makeTornadoRawParameters()
            ),
            profileAnalysis: profileAnalysis,
            tornadoViability: .init(
                overall: .strong,
                realization: .unknown,
                primaryFailureMode: .none,
                confidence: .high,
                summary: summary,
                details: .init(
                    stormViability: .conditional,
                    supercellViability: .supportive,
                    tornadoEfficiency: .unknown,
                    inhibition: .weak,
                    instability: .supportive,
                    moisture: .supportive,
                    cloudBase: .weak,
                    deepShear: .strong,
                    lowLevelRotation: .conditional,
                    lowLevelStretching: .unknown,
                    cloudBaseEfficiency: .unknown,
                    supercellComposite: .unknown,
                    tornadoComposite: .unknown,
                    stormMode: .supportive
                ),
                limitingFactors: []
            )
        )
    }

    private func makeAnvilAnalyzeProfileResponse() -> AnvilAnalyzeProfileResponse {
        AnvilAnalyzeProfileResponse(
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
                    uKt: 9.3,
                    vKt: 3.1,
                    speedKt: 9.9,
                    directionTowardDeg: 65,
                    uMs: 4.8,
                    vMs: 1.6,
                    speedMs: 5.1
                )
            ),
            mucape: 2_200.5,
            mlcape: 1_850,
            mlcin: -42,
            mllclMetersAgl: 980,
            effectiveSrh: 125.5,
            effectiveBulkShearMs: 21.5,
            scp: 3.2,
            stpCin: 1.8,
            stpFixed: 1.4,
            ship: 0.9,
            srh01km: 125.5,
            srh03km: 175,
            sbcape: 1_700,
            sbcin: nil,
            bulkShear06kmMs: 21.5,
            lapserate03km: nil,
            threeCapeJkg: 95,
            quality: .init(profileLevelCount: 4, warnings: ["sample"])
        )
    }

    private func makeTornadoRawParameters() -> TornadoRawParameters {
        TornadoRawParameters(
            sbcapeJkg: 1_700,
            mlcapeJkg: 1_850,
            mucapeJkg: 2_200.5,
            mlcinJkg: -42,
            dcapeJkg: nil,
            mllclM: 980,
            tempDewPtDeltaF: 4.5,
            threeCapeJkg: 95,
            lclLfcSeparationM: nil,
            lapseRate03kmCkm: nil,
            lapseRate700500mbCkm: nil,
            shear06kmKt: 42,
            shear03kmKt: nil,
            shear01kmKt: nil,
            effectiveShearKt: nil,
            srh01kmM2s2: 125.5,
            srh03kmM2s2: 175,
            effectiveSrhM2s2: nil,
            supercellComposite: nil,
            significantTornadoFixed: nil,
            significantTornadoEffective: nil,
            significantHail: nil,
            bunkersRightMotion: nil,
            bunkersLeftMotion: nil,
            stormRelativeWind46km: nil,
            meanWind850300mb: nil,
            diagnostics: nil,
            effectiveBulkShearMs: nil,
            effectiveLayer: nil,
            stormMotion: nil
        )
}

private final class HomeProjectionFixtureBundleLocator {}
}
