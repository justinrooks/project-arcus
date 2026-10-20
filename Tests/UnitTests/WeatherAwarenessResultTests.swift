import Foundation
import SwiftData
import Testing
@testable import SkyAware

@Suite("Accepted weather awareness contract")
struct WeatherAwarenessResultTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Cold file reads preserve last-assessed location, source age and event expiry")
    func persistedRead() async throws {
        let store = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: store.directoryURL) }
        try store.write(.init(accepted: record(alerts: [alert("warning")])))
        let reopened = WeatherAwarenessSnapshotStore(directoryURL: store.directoryURL)
        let current = try #require(assessment(await reopened.read(now: now)))
        #expect(current.events.map(\.id) == ["warning"])
        #expect(current.location.assessedAt == now.addingTimeInterval(-600))
        let expired = try #require(assessment(await reopened.read(now: now.addingTimeInterval(30))))
        #expect(expired.hasCurrentQuietAlerts)
        let stale = try #require(assessment(await reopened.read(now: now.addingTimeInterval(30_000))))
        #expect(stale.riskFreshness == .stale)
        #expect(stale.alertFreshness == .stale)
        #expect(!stale.hasCurrentQuietAlerts)
        #expect(await reopened.read(expectedProjectionKey: "new-location", now: now) == .unavailable(.locationMismatch))
    }

    @Test("Missing, corrupt, oversized and unreadable files have explicit results")
    func fileFailures() async throws {
        let store = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: store.directoryURL) }
        #expect(await store.read(now: now) == .unavailable(.noCache))
        try FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: store.fileURL)
        #expect(await store.read(now: now) == .unavailable(.corruptCache))
        try Data(repeating: 0, count: WeatherAwarenessSnapshotStore.maximumBytes + 1).write(to: store.fileURL)
        #expect(await store.read(now: now) == .unavailable(.corruptCache))
        try FileManager.default.removeItem(at: store.fileURL)
        try Data("unreadable".utf8).write(to: store.fileURL)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: store.fileURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: store.fileURL.path) }
        let unreadable = await store.read(now: now)
        #expect(unreadable == .unavailable(.readFailure))
    }

    @Test("Only saved slices publish; failed commits retain the prior accepted file")
    @MainActor
    func acceptedCommitPublication() async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        let container = try TestStore.container(for: [HomeProjection.self])
        let home = HomeProjectionStore(modelContainer: container)
        let context = awarenessContext()
        await home.configureAwarenessSnapshots(file)
        #expect(await file.read(now: now) == .unavailable(.noCache))
        _ = try await home.commitCore(.init(slowProducts: (.slight, .allClear, .clear)),
                                      for: context, loadedAt: now)
        let initial = try #require(assessment(await file.read(now: now)))
        #expect(initial.risks.storm == .slight)
        #expect(initial.alertFreshness == .unavailable)
        await home.failNextSaveForTesting()
        await #expect(throws: (any Error).self) {
            try await home.commitCore(.init(slowProducts: (.high, .allClear, .critical),
                                            hotAlerts: ([], [])), for: context, loadedAt: now)
        }
        #expect(assessment(await file.read(now: now)) == initial)
        _ = try await home.updateHotAlerts(alerts: [alert("live")], mesos: [meso(1)],
                                          for: context, loadedAt: now.addingTimeInterval(1))
        let hot = try #require(assessment(await file.read(now: now.addingTimeInterval(1))))
        #expect(hot.events.map(\.id) == ["live", "1"])
        #expect(hot.risks.assessedAt == initial.risks.assessedAt)
        _ = try await home.commitCore(.init(slowProducts: (.enhanced, .allClear, .elevated)),
                                      for: context, loadedAt: now.addingTimeInterval(2))
        let risk = try #require(assessment(await file.read(now: now.addingTimeInterval(2))))
        #expect(risk.risks.storm == .enhanced)
        #expect(risk.alertsAssessedAt == hot.alertsAssessedAt)
        _ = try await home.updateHotAlerts(alerts: [], mesos: [], for: context, loadedAt: now)
        #expect(assessment(await file.read(now: now))?.hasCurrentQuietAlerts == true)
    }

    @Test("Weather-only core commits preserve published awareness while genuine domains can still replace it",
          arguments: [false, true])
    @MainActor
    func weatherOnlyCoreCommitPreservesAwareness(includesIgnoredRiskValues: Bool) async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        let container = try TestStore.container(for: [HomeProjection.self])
        let home = HomeProjectionStore(modelContainer: container)
        #expect(HomeProjectionRetentionCoordinator.forStore(container).currentActiveProjectionKey() == nil)
        await home.configureAwarenessSnapshots(file)
        let first = awarenessContext()
        let second = awarenessContext(cell: 2)
        _ = try await home.commitCore(.init(slowProducts: (.allClear, .allClear, .clear), hotAlerts: ([], [])),
                                      for: first, loadedAt: now)
        _ = try await home.commitCore(.init(slowProducts: (.slight, .allClear, .elevated),
                                            hotAlerts: ([alert("B-warning")], [])),
                                      for: second, loadedAt: now.addingTimeInterval(1))
        let before = try #require(assessment(await file.read(now: now.addingTimeInterval(2))))
        #expect(before.location.projectionKey == HomeProjection.projectionKey(for: second))
        let weather = SummaryWeather(
            temperature: .init(value: 72, unit: .fahrenheit), symbolName: "sun.max.fill",
            conditionText: "Clear", asOf: now, dewPoint: .init(value: 54, unit: .fahrenheit),
            humidity: 0.45, windSpeed: .init(value: 15, unit: .milesPerHour), windGust: nil,
            windDirection: "NW", pressure: .init(value: 29.92, unit: .inchesOfMercury),
            pressureTrend: "steady", visibility: nil
        )
        let weatherCommit = HomeProjectionCoreCommit(
            weather: .some(weather),
            slowProducts: includesIgnoredRiskValues ? (.high, .allClear, .critical) : nil,
            updatesConvectiveRisk: false, updatesFireRisk: false
        )
        let saved = try await home.commitCore(weatherCommit, for: first, loadedAt: now.addingTimeInterval(2))
        let persisted = try #require(await home.projection(for: first))
        #expect(saved.record == persisted)
        #expect(persisted.weather == weather)
        #expect(persisted.lastWeatherLoadAt == now.addingTimeInterval(2))
        #expect(persisted.stormRisk == .allClear)
        #expect(persisted.fireRisk == .clear)
        #expect(assessment(await file.read(now: now.addingTimeInterval(2))) == before)
        _ = try await home.commitCore(.init(slowProducts: (.enhanced, .allClear, .critical), updatesFireRisk: false),
                                      for: first, loadedAt: now.addingTimeInterval(3))
        let risk = try #require(assessment(await file.read(now: now.addingTimeInterval(3))))
        #expect(risk.location.projectionKey == HomeProjection.projectionKey(for: first))
        #expect(risk.risks.storm == .enhanced)
        #expect(risk.risks.fire == .clear)
        _ = try await home.commitCore(.init(slowProducts: (.high, .allClear, .critical), updatesConvectiveRisk: false),
                                      for: second, loadedAt: now.addingTimeInterval(4))
        let fire = try #require(assessment(await file.read(now: now.addingTimeInterval(4))))
        #expect(fire.location.projectionKey == HomeProjection.projectionKey(for: second))
        #expect(fire.risks.storm == .slight)
        #expect(fire.risks.fire == .critical)
        _ = try await home.commitCore(.init(hotAlerts: ([], [])), for: first, loadedAt: now.addingTimeInterval(5))
        let quiet = try #require(assessment(await file.read(now: now.addingTimeInterval(5))))
        #expect(quiet.location.projectionKey == HomeProjection.projectionKey(for: first))
        #expect(quiet.hasCurrentQuietAlerts)
        #expect(quiet.alertsAssessedAt == now.addingTimeInterval(5))
    }

    @Test("Changed location never inherits the previous location's risks or alerts")
    @MainActor
    func locationPublication() async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        try FileManager.default.createDirectory(at: file.directoryURL, withIntermediateDirectories: true)
        let schema = Schema([HomeProjection.self])
        let config = ModelConfiguration(schema: schema, url: file.directoryURL.appending(path: "Home.sqlite"))
        let container = try ModelContainer(for: schema, configurations: config)
        let retention = HomeProjectionRetentionCoordinator.forStore(container)
        defer { retention.setActiveProjectionKey(nil) }
        let home = HomeProjectionStore(modelContainer: container)
        await home.configureAwarenessSnapshots(file)
        _ = try await home.commitCore(.init(slowProducts: (.high, .allClear, .critical),
                                            hotAlerts: ([alert("old")], [])),
                                      for: awarenessContext(), loadedAt: now)
        let first = awarenessContext()
        let second = awarenessContext(cell: 2)
        retention.setActiveProjectionKey(HomeProjection.projectionKey(for: first))
        _ = try await home.commitCore(.init(slowProducts: (.slight, .allClear, .clear), hotAlerts: ([], [])),
                                      for: second, loadedAt: now.addingTimeInterval(-600))
        #expect(assessment(await file.read(now: now))?.location.projectionKey == HomeProjection.projectionKey(for: first))
        let session = LocationSession(
            locationClient: .init(snapshot: { nil }, updates: { AsyncStream { $0.finish() } }),
            locationManager: LocationManager(onUpdate: { _ in }),
            locationContextResolver: AwarenessLocationResolver(context: second),
            locationUploadCoordinator: NoOpLocationUploadCoordinator(), retentionCoordinator: retention,
            onContextPublished: { await home.publishAcceptedAwareness() }
        )
        await session.publishCurrentContext(second)
        let changed = try #require(assessment(await file.read(now: now)))
        #expect(changed.location.projectionKey == HomeProjection.projectionKey(for: second))
        #expect(changed.risks.storm == .slight)
        #expect(changed.risks.assessedAt == now.addingTimeInterval(-600))
        #expect(changed.events.isEmpty)
        // A refresh failure after switching must retain B's accepted assessment.
        await home.failNextSaveForTesting()
        await #expect(throws: (any Error).self) {
            try await home.commitCore(.init(slowProducts: (.high, .allClear, .critical)),
                                      for: second, loadedAt: now)
        }
        #expect(assessment(await file.read(now: now)) == changed)
        // A late accepted update for the previous context cannot switch publication back to it.
        _ = try await home.updateHotAlerts(alerts: [alert("late")], mesos: [],
                                          for: awarenessContext(), loadedAt: now.addingTimeInterval(1))
        #expect(assessment(await file.read(now: now)) == changed)
        let third = awarenessContext(cell: 3)
        _ = try await home.fetchOrCreateProjection(for: third, viewedAt: now.addingTimeInterval(60))
        await session.publishCurrentContext(third)
        // An existing location-only row is still unassessed; retain explicitly last-assessed B.
        #expect(assessment(await file.read(now: now))?.location.projectionKey == HomeProjection.projectionKey(for: second))
        _ = try await home.commitCore(.init(hotAlerts: ([], [])), for: third, loadedAt: now)
        let partial = try #require(assessment(await file.read(now: now)))
        #expect(partial.location.projectionKey == HomeProjection.projectionKey(for: third))
        #expect(partial.riskFreshness == .unavailable)
        #expect(partial.hasCurrentQuietAlerts)
    }

    @Test("Startup restores committed state and file-write failures cannot roll back Home")
    @MainActor
    func restoreAndWriteFailure() async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        try FileManager.default.createDirectory(at: file.directoryURL, withIntermediateDirectories: true)
        let schema = Schema([HomeProjection.self])
        let config = ModelConfiguration(schema: schema, url: file.directoryURL.appending(path: "Home.sqlite"))
        do {
            let home = HomeProjectionStore(modelContainer: try ModelContainer(for: schema, configurations: config))
            // A directory at the file path forces atomic replacement to fail.
            try FileManager.default.createDirectory(at: file.fileURL, withIntermediateDirectories: true)
            await home.configureAwarenessSnapshots(file)
            let accepted = try await home.commitCore(.init(slowProducts: (.enhanced, .allClear, .clear),
                                                          hotAlerts: ([], [])),
                                                    for: awarenessContext(), loadedAt: now)
            #expect(accepted.record.stormRisk == .enhanced)
            #expect(try await home.projection(for: awarenessContext())?.lastHotAlertsLoadAt == now)
        }
        try FileManager.default.removeItem(at: file.fileURL)
        let reopened = HomeProjectionStore(modelContainer: try ModelContainer(for: schema, configurations: config))
        await reopened.configureAwarenessSnapshots(file)
        let restored = try #require(assessment(await file.read(now: now.addingTimeInterval(30_000))))
        #expect(restored.risks.storm == .enhanced)
        #expect(restored.risks.assessedAt == now)
        #expect(restored.alertFreshness == .stale)
    }

    @Test("Newer unassessed rows preserve last-assessed awareness across restart until first domain acceptance",
          arguments: [true, false], [true, false])
    @MainActor
    func unassessedRowsPreserveAcceptedAwareness(acceptsRiskFirst: Bool, hasWeatherUpdate: Bool) async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        try FileManager.default.createDirectory(at: file.directoryURL, withIntermediateDirectories: true)
        let schema = Schema([HomeProjection.self])
        let config = ModelConfiguration(schema: schema, url: file.directoryURL.appending(path: "Home.sqlite"))
        let first = awarenessContext()
        let second = awarenessContext(cell: 2)
        do {
            let home = HomeProjectionStore(modelContainer: try ModelContainer(for: schema, configurations: config))
            await home.configureAwarenessSnapshots(file)
            _ = try await home.commitCore(.init(slowProducts: (.enhanced, .allClear, .clear), hotAlerts: ([], [])),
                                          for: first, loadedAt: now)
            _ = try await home.fetchOrCreateProjection(for: second, viewedAt: now.addingTimeInterval(60))
            if hasWeatherUpdate {
                let weather = SummaryWeather(
                    temperature: .init(value: 72, unit: .fahrenheit), symbolName: "sun.max.fill",
                    conditionText: "Clear", asOf: now, dewPoint: .init(value: 54, unit: .fahrenheit),
                    humidity: 0.45, windSpeed: .init(value: 15, unit: .milesPerHour), windGust: nil,
                    windDirection: "NW", pressure: .init(value: 29.92, unit: .inchesOfMercury),
                    pressureTrend: "steady", visibility: nil
                )
                let weatherOnly = try await home.updateWeather(weather, for: second,
                                                               loadedAt: now.addingTimeInterval(120))
                #expect(weatherOnly.isDisplayReady) // Generic Home readiness is deliberately insufficient.
            }
        }
        let container = try ModelContainer(for: schema, configurations: config)
        let reopened = HomeProjectionStore(modelContainer: container)
        let retention = HomeProjectionRetentionCoordinator.forStore(container)
        defer { retention.setActiveProjectionKey(nil) }
        await reopened.configureAwarenessSnapshots(file)
        let retained = try #require(assessment(await file.read(now: now.addingTimeInterval(120))))
        #expect(retained.location.projectionKey == HomeProjection.projectionKey(for: first))
        #expect(retained.risks.assessedAt == now)
        #expect(retained.risks.storm == .enhanced)
        // Also prove startup rebuilds A, rather than merely leaving an existing file alone.
        try FileManager.default.removeItem(at: file.fileURL)
        let recovery = HomeProjectionStore(modelContainer: container)
        await recovery.configureAwarenessSnapshots(file)
        #expect(assessment(await file.read(now: now.addingTimeInterval(120))) == retained)
        // The same existing B row must not replace A during a location transition.
        retention.setActiveProjectionKey(HomeProjection.projectionKey(for: second))
        await reopened.publishAcceptedAwareness()
        #expect(assessment(await file.read(now: now.addingTimeInterval(120))) == retained)
        #expect(await file.read(expectedProjectionKey: HomeProjection.projectionKey(for: second), now: now)
                == .unavailable(.locationMismatch))
        let acceptedAt = now.addingTimeInterval(180)
        let commit = acceptsRiskFirst
            ? HomeProjectionCoreCommit(slowProducts: (.slight, .allClear, .clear))
            : HomeProjectionCoreCommit(hotAlerts: ([], []))
        _ = try await reopened.commitCore(commit, for: second, loadedAt: acceptedAt)
        let replacement = try #require(assessment(await file.read(now: acceptedAt)))
        #expect(replacement.location.projectionKey == HomeProjection.projectionKey(for: second))
        #expect(replacement.riskFreshness == (acceptsRiskFirst ? .current : .unavailable))
        #expect(replacement.alertFreshness == (acceptsRiskFirst ? .unavailable : .current))
        #expect(replacement.hasCurrentQuietAlerts == !acceptsRiskFirst)
        #expect(replacement.risks.assessedAt == (acceptsRiskFirst ? acceptedAt : nil))
        #expect(replacement.alertsAssessedAt == (acceptsRiskFirst ? nil : acceptedAt))
    }

    @Test("Restart preserves the published location and reconstructs from independent awareness timestamps",
          arguments: [true, false], [true, false])
    @MainActor
    func startupAwarenessOrdering(keepsFile: Bool, latestDomainIsRisk: Bool) async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        try FileManager.default.createDirectory(at: file.directoryURL, withIntermediateDirectories: true)
        let schema = Schema([HomeProjection.self])
        let config = ModelConfiguration(schema: schema, url: file.directoryURL.appending(path: "Home.sqlite"))
        let first = awarenessContext()
        let second = awarenessContext(cell: 2)
        do {
            let home = HomeProjectionStore(modelContainer: try ModelContainer(for: schema, configurations: config))
            await home.configureAwarenessSnapshots(file)
            _ = try await home.commitCore(.init(slowProducts: (.enhanced, .allClear, .clear), hotAlerts: ([], [])),
                                          for: first, loadedAt: now)
            let oppositeDomain = latestDomainIsRisk ? HomeProjectionCoreCommit(hotAlerts: ([], []))
                : HomeProjectionCoreCommit(slowProducts: (.enhanced, .allClear, .clear))
            _ = try await home.commitCore(oppositeDomain, for: first, loadedAt: now.addingTimeInterval(90))
            _ = try await home.commitCore(.init(slowProducts: (.slight, .allClear, .clear), hotAlerts: ([], [])),
                                          for: second, loadedAt: now.addingTimeInterval(60))
            let latestDomain = latestDomainIsRisk ? HomeProjectionCoreCommit(slowProducts: (.slight, .allClear, .clear))
                : HomeProjectionCoreCommit(hotAlerts: ([], []))
            _ = try await home.commitCore(latestDomain, for: second, loadedAt: now.addingTimeInterval(120))
            _ = try await home.updateWeather(nil, for: first, loadedAt: now.addingTimeInterval(180))
        }
        if !keepsFile { try FileManager.default.removeItem(at: file.fileURL) }
        let reopened = HomeProjectionStore(modelContainer: try ModelContainer(for: schema, configurations: config))
        await reopened.configureAwarenessSnapshots(file)
        let result = try #require(assessment(await file.read(now: now.addingTimeInterval(180))))
        #expect(result.location.projectionKey == HomeProjection.projectionKey(for: second))
        #expect(result.risks.storm == .slight)
        #expect(result.risks.assessedAt == now.addingTimeInterval(latestDomainIsRisk ? 120 : 60))
        #expect(result.alertsAssessedAt == now.addingTimeInterval(latestDomainIsRisk ? 60 : 120))
    }

    @Test("Startup validates the saved location against canonical state before preferring its identity",
          arguments: [true, false])
    @MainActor
    func startupValidatesPublishedIdentity(cachedKeyIsValid: Bool) async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        try FileManager.default.createDirectory(at: file.directoryURL, withIntermediateDirectories: true)
        let schema = Schema([HomeProjection.self])
        let config = ModelConfiguration(schema: schema, url: file.directoryURL.appending(path: "Home.sqlite"))
        let container = try ModelContainer(for: schema, configurations: config)
        let retention = HomeProjectionRetentionCoordinator.forStore(container)
        defer { retention.setActiveProjectionKey(nil) }
        let first = awarenessContext()
        let second = awarenessContext(cell: 2)
        let home = HomeProjectionStore(modelContainer: container)
        await home.configureAwarenessSnapshots(file)
        _ = try await home.commitCore(.init(slowProducts: (.enhanced, .allClear, .clear)), for: first, loadedAt: now)
        _ = try await home.commitCore(.init(slowProducts: (.slight, .allClear, .clear)),
                                      for: second, loadedAt: now.addingTimeInterval(60))
        retention.setActiveProjectionKey(HomeProjection.projectionKey(for: second))
        _ = try await home.commitCore(.init(slowProducts: (.high, .allClear, .clear)),
                                      for: first, loadedAt: now.addingTimeInterval(120))
        retention.setActiveProjectionKey(nil)
        if !cachedKeyIsValid { try file.write(.init(accepted: record(key: "missing-canonical-location"))) }
        let reopened = HomeProjectionStore(modelContainer: container)
        await reopened.configureAwarenessSnapshots(file)
        let result = try #require(assessment(await file.read(now: now.addingTimeInterval(120))))
        #expect(result.location.projectionKey == HomeProjection.projectionKey(for: cachedKeyIsValid ? second : first))
        #expect(result.risks.storm == (cachedKeyIsValid ? .slight : .high))
    }

    @Test("A startup cache read cannot override a Home commit completed while restoration was suspended")
    @MainActor
    func startupCannotOverrideConcurrentCommit() async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        let container = try TestStore.container(for: [HomeProjection.self])
        let original = HomeProjectionStore(modelContainer: container)
        await original.configureAwarenessSnapshots(file)
        _ = try await original.commitCore(.init(slowProducts: (.enhanced, .allClear, .clear)),
                                          for: awarenessContext(), loadedAt: now)
        let reopened = HomeProjectionStore(modelContainer: container)
        let gate = AwarenessPublicationGate()
        await reopened.setAwarenessRestoreCheckpointForTesting { await gate.wait() }
        let restoration = Task { await reopened.configureAwarenessSnapshots(file) }
        await gate.waitUntilWaiting()
        let second = awarenessContext(cell: 2)
        _ = try await reopened.commitCore(.init(slowProducts: (.slight, .allClear, .clear)),
                                          for: second, loadedAt: now.addingTimeInterval(60))
        await gate.open()
        await restoration.value
        let result = try #require(assessment(await file.read(now: now.addingTimeInterval(60))))
        #expect(result.location.projectionKey == HomeProjection.projectionKey(for: second))
        #expect(result.risks.storm == .slight)
        await reopened.setAwarenessRestoreCheckpointForTesting(nil)
    }

    @Test("A gated old publisher cannot replace a newer location or revision")
    func outOfOrderPublication() async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        let publisher = WeatherAwarenessSnapshotPublisher(store: file)
        let gate = AwarenessPublicationGate()
        let old = WeatherAwarenessSnapshot(accepted: record(key: "old", storm: .high))
        let delayed = Task {
            await gate.wait()
            await publisher.publish(old, revision: 1)
        }
        let newer = WeatherAwarenessSnapshot(accepted: record(key: "new", storm: .slight, alertAge: nil))
        await publisher.publish(newer, revision: 2)
        await gate.open()
        await delayed.value
        let result = try #require(assessment(await file.read(now: now)))
        #expect(result.location.projectionKey == "new")
        #expect(result.risks.storm == .slight)
        #expect(result.alertFreshness == .unavailable)
        await publisher.publish(old, revision: 2)
        #expect(assessment(await file.read(now: now)) == result)
        try FileManager.default.removeItem(at: file.fileURL)
        try FileManager.default.createDirectory(at: file.fileURL, withIntermediateDirectories: true)
        await publisher.publish(old, revision: 4) // forced write failure still fences revision 3
        try FileManager.default.removeItem(at: file.fileURL)
        try file.write(newer)
        await publisher.publish(old, revision: 3)
        #expect(assessment(await file.read(now: now)) == result)
        await publisher.publish(old, revision: 5)
        #expect(assessment(await file.read(now: now))?.location.projectionKey == "old")
    }

    @Test("Overlapping Home commits reserve revisions before suspension and preserve acknowledgement identity")
    @MainActor
    func overlappingHomePublication() async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        let home = HomeProjectionStore(modelContainer: try TestStore.container(for: [HomeProjection.self]))
        await home.configureAwarenessSnapshots(file)
        let gate = AwarenessPublicationGate()
        await home.setAwarenessPublicationCheckpointForTesting { revision in
            if revision == 1 { await gate.wait() }
        }
        let older = Task {
            try await home.commitCore(.init(slowProducts: (.high, .allClear, .critical),
                                            hotAlerts: ([alert("old")], [])),
                                      for: awarenessContext(), loadedAt: now)
        }
        await gate.waitUntilWaiting()
        let second = awarenessContext(cell: 2)
        let newer = try await home.commitCore(.init(slowProducts: (.slight, .allClear, .clear), hotAlerts: ([], [])),
                                              for: second, loadedAt: now)
        await gate.open()
        let oldAcknowledgement = try await older.value
        let result = try #require(assessment(await file.read(now: now)))
        #expect(oldAcknowledgement.record.stormRisk == .high)
        #expect(newer.record.stormRisk == .slight)
        #expect(result.location.projectionKey == newer.record.projectionKey)
        #expect(result.risks.storm == .slight)
        #expect(result.hasCurrentQuietAlerts)
        await home.setAwarenessPublicationCheckpointForTesting(nil)
    }

    private func temporarySnapshotStore() -> WeatherAwarenessSnapshotStore {
        .init(directoryURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
    }

    @Test("Remote hot-alert completion publishes only the converged accepted Home collection")
    @MainActor
    func remoteCompletion() async throws {
        let file = temporarySnapshotStore()
        defer { try? FileManager.default.removeItem(at: file.directoryURL) }
        let home = HomeProjectionStore(modelContainer: try TestStore.container(for: [HomeProjection.self]))
        await home.configureAwarenessSnapshots(file)
        let gate = AwarenessPublicationGate()
        let coordinator = AwarenessRemoteCoordinator(home: home, context: awarenessContext(),
                                                     alert: alert("remote"), now: now, gate: gate)
        let handler = RemoteHotAlertHandler(coordinator: coordinator, arcusAlerts: AwarenessRemoteAlerts(),
                                            presentationState: RemoteAlertPresentationState())
        let receipt = Task { await handler.handleRemoteNotification(HomeRemoteAlertContext(alertID: "remote")) }
        #expect(await file.read(now: now) == .unavailable(.noCache))
        await gate.open()
        _ = await receipt.value
        let accepted = try #require(assessment(await file.read(now: now)))
        #expect(accepted.events.map(\.id) == ["remote"])
        #expect(accepted.riskFreshness == .unavailable)
        #expect(accepted.alertsAssessedAt == now)
    }

    private func awarenessContext(cell: Int64 = 1) -> LocationContext {
        let snapshot = LocationSnapshot(coordinates: .init(latitude: 39, longitude: -104),
                                        timestamp: now, accuracy: 25, placemarkSummary: "Bennett, CO", h3Cell: cell)
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20", latitude: 39, longitude: -104, gridId: "BOU", gridX: 10, gridY: 20,
            forecastURL: nil, forecastHourlyURL: nil, forecastGridDataURL: nil, observationStationsURL: nil,
            city: "Bennett", state: "CO", timeZoneId: "America/Denver", radarStationId: nil,
            forecastZone: "COZ038", countyCode: "COC005", fireZone: "COZ214", countyLabel: nil, fireZoneLabel: nil
        )
        return LocationContext(snapshot: snapshot, h3Cell: cell, grid: grid)
    }

    @Test("Accepted quiet risks and alerts differ from missing values")
    func quietAndUnavailable() throws {
        let quiet = try assessment(record())
        #expect(quiet.risks.storm == .allClear)
        #expect(quiet.risks.severe == .allClear)
        #expect(quiet.risks.fire == .clear)
        #expect(quiet.riskFreshness == .current)
        #expect(quiet.hasCurrentQuietAlerts)

        let missing = try assessment(record(storm: nil, severe: nil, fire: nil, alertAge: nil))
        #expect(missing.riskFreshness == .unavailable)
        #expect(missing.risks.storm == nil)
        #expect(missing.alertFreshness == .unavailable)
        #expect(!missing.hasCurrentQuietAlerts)
    }

    @Test("Risk and alert freshness age independently at exact boundaries", arguments: [true, false])
    func independentFreshness(staleRisk: Bool) throws {
        let result = try assessment(record(
            riskAge: staleRisk ? WeatherAwarenessResult.riskMaximumAge : 0,
            alertAge: staleRisk ? 0 : WeatherAwarenessResult.alertMaximumAge
        ))
        #expect(result.riskFreshness == (staleRisk ? .stale : .current))
        #expect(result.alertFreshness == (staleRisk ? .current : .stale))
        #expect(result.hasCurrentQuietAlerts == staleRisk)
        #expect(result.risks.assessedAt == now.addingTimeInterval(
            staleRisk ? -WeatherAwarenessResult.riskMaximumAge : 0
        ))
    }

    @Test("Partial risk preserves canonical categories and missing domains")
    func partialRisk() throws {
        let result = try assessment(record(storm: .enhanced, severe: .tornado(probability: 0.15), fire: nil))
        #expect(result.risks.storm == .enhanced)
        #expect(result.risks.severe == .tornado(probability: 0.15))
        #expect(result.risks.fire == nil)
        #expect(result.risks.source == .stormPredictionCenter)
        #expect(result.risks.convectiveSourceToken == "accepted-source")
    }

    @Test("Missing or future acceptance times never inherit the record update time", arguments: [nil, -60.0])
    func invalidAcceptanceTimes(age: Double?) throws {
        let result = try assessment(record(riskAge: age, alertAge: age, alerts: [alert("live")]))
        #expect(result.riskFreshness == .unavailable)
        #expect(result.alertFreshness == .unavailable)
        #expect(result.events.isEmpty)
        #expect(!result.hasCurrentQuietAlerts)
    }

    @Test("Expiry, future starts and official alert hierarchy are evaluated at read time")
    func eventSelection() throws {
        let snapshot = WeatherAwarenessSnapshot(accepted: record(alerts: [
            alert("watch", title: "Tornado Watch"),
            alert("expired", endOffset: 0),
            alert("future", startOffset: 60),
            alert("warning", title: "Tornado Warning")
        ], mesos: [meso(2, endOffset: 0), meso(1), meso(3, startOffset: 60)]))
        let result = try #require(assessment(WeatherAwarenessResult.select(snapshot, now: now)))
        #expect(result.events.map(\.id) == ["warning", "watch", "1"])
        #expect(result.events.map(\.source) == [.nationalWeatherService, .nationalWeatherService, .stormPredictionCenter])
        #expect(!result.hasCurrentQuietAlerts)
        #expect(result.events.first?.issuedAt == now.addingTimeInterval(-60))

        let later = try #require(assessment(WeatherAwarenessResult.select(
            snapshot, now: now.addingTimeInterval(WeatherAwarenessResult.alertMaximumAge)
        )))
        #expect(later.events.isEmpty)
        #expect(later.alertFreshness == .stale)
        #expect(!later.hasCurrentQuietAlerts)
    }

    @Test("Stale alerts retain time-valid events without claiming current quiet")
    func stalePopulatedAlerts() throws {
        let result = try assessment(record(alertAge: 1_800, alerts: [alert("warning")]))
        #expect(result.alertFreshness == .stale)
        #expect(result.events.map(\.id) == ["warning"])
        #expect(!result.hasCurrentQuietAlerts)
    }

    @Test("NWS activity ends at the earlier CAP expiration or event end; quiet requires current coverage",
          arguments: [true, false], [Optional(0.0), Optional(1_800.0), nil])
    func nwsTerminalBoundary(expiresFirst: Bool, alertAge: Double?) throws {
        let snapshot = WeatherAwarenessSnapshot(accepted: record(
            alertAge: alertAge,
            alerts: [alert("warning", endOffset: expiresFirst ? 600 : 30,
                           expiresOffset: expiresFirst ? 30 : 600)]
        ))
        for offset in [29.0, 30.0, 31.0] {
            let result = try #require(assessment(.select(snapshot, now: now.addingTimeInterval(offset))))
            let isActive = alertAge != nil && offset < 30
            #expect(result.events.map(\.id) == (isActive ? ["warning"] : []))
            #expect(result.hasCurrentQuietAlerts == (alertAge == 0 && offset >= 30))
        }
    }

    @Test("Missing cache, corrupt cache, missing location and scope mismatch are explicit")
    func unavailableResults() {
        #expect(WeatherAwarenessResult.select(nil, now: now) == .unavailable(.noCache))
        #expect(WeatherAwarenessResult.unavailable(.corruptCache) != .unavailable(.noCache))
        #expect(WeatherAwarenessResult.select(
            WeatherAwarenessSnapshot(accepted: record(key: " ")), now: now
        ) == .unavailable(.missingAssessedLocation))
        #expect(WeatherAwarenessResult.select(
            WeatherAwarenessSnapshot(accepted: record()), expectedProjectionKey: "other-location", now: now
        ) == .unavailable(.locationMismatch))
    }

    @Test("Snapshot survives Codable and actor transfer without geometry or coordinate fields")
    func valueBoundary() async throws {
        let snapshot = WeatherAwarenessSnapshot(accepted: record(label: "  Bennett, CO  "))
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WeatherAwarenessSnapshot.self, from: encoded)
        let transferred = await Task.detached { WeatherAwarenessResult.select(decoded, now: now) }.value
        let result = try #require(assessment(transferred))
        #expect(decoded == snapshot)
        #expect(result.location.displayLabel == "Bennett, CO")
        #expect(result.location.projectionKey == "assessed-location")
        #expect(result.location.assessedAt == now.addingTimeInterval(-600))
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(!json.contains("latitude"))
        #expect(!json.contains("longitude"))
        #expect(!json.contains("geometry"))
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(WeatherAwarenessSnapshot.self, from: Data("{}".utf8))
        }
        #expect(WeatherAwarenessSnapshot(accepted: record(label: " ")).location?.displayLabel == nil)
    }

    private func assessment(_ record: HomeProjectionRecord) throws -> WeatherAwarenessResult.Assessment {
        try #require(assessment(.select(WeatherAwarenessSnapshot(accepted: record), now: now)))
    }

    private func assessment(_ result: WeatherAwarenessResult) -> WeatherAwarenessResult.Assessment? {
        guard case .assessment(let value) = result else { return nil }
        return value
    }

    private func record(
        key: String = "assessed-location", label: String? = "Bennett, CO",
        storm: StormRiskLevel? = .allClear, severe: SevereWeatherThreat? = .allClear,
        fire: FireRiskLevel? = .clear, riskAge: Double? = 0, alertAge: Double? = 0,
        alerts: [AlertDTO] = [], mesos: [MdDTO] = []
    ) -> HomeProjectionRecord {
        .init(
            id: UUID(), projectionKey: key, latitude: 39, longitude: -104, h3Cell: 1,
            countyCode: "CO001", forecastZone: nil, fireZone: "COZ001", placemarkSummary: label,
            timeZoneId: nil, locationTimestamp: now.addingTimeInterval(-600),
            createdAt: now, updatedAt: now, lastViewedAt: nil, weather: nil,
            stormRisk: storm, severeRisk: severe, fireRisk: fire, activeAlerts: alerts, activeMesos: mesos,
            lastHotAlertsLoadAt: alertAge.map { now.addingTimeInterval(-$0) },
            lastSlowProductsLoadAt: riskAge.map { now.addingTimeInterval(-$0) }, lastWeatherLoadAt: now,
            convectiveSourceToken: "accepted-source"
        )
    }

    private func alert(
        _ id: String, title: String = "Severe Thunderstorm Warning",
        startOffset: Double = -60, endOffset: Double = 600, expiresOffset: Double = 30
    ) -> AlertDTO {
        .init(
            id: id, messageId: nil, title: title, headline: title,
            issued: now.addingTimeInterval(startOffset), expires: now.addingTimeInterval(expiresOffset),
            ends: now.addingTimeInterval(endOffset), messageType: "Alert", sender: nil,
            severity: "Severe", urgency: "Immediate", certainty: "Observed", description: "",
            instruction: nil, response: nil, areaSummary: "", tornadoDetection: nil,
            tornadoDamageThreat: nil, maxWindGust: nil, maxHailSize: nil, windThreat: nil,
            hailThreat: nil, thunderstormDamageThreat: nil, flashFloodDetection: nil, flashFloodDamageThreat: nil
        )
    }

    private func meso(_ number: Int, startOffset: Double = -60, endOffset: Double = 600) -> MdDTO {
        .init(
            number: number, title: "SPC MD \(number)", link: URL(fileURLWithPath: "/unused"),
            issued: now.addingTimeInterval(-60), validStart: now.addingTimeInterval(startOffset),
            validEnd: now.addingTimeInterval(endOffset), areasAffected: "", summary: "",
            watchProbability: "Unknown", threats: nil, coordinates: []
        )
    }
}

private actor AwarenessPublicationGate {
    private var isOpen = false
    private var hasArrived = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var arrivalWaiter: CheckedContinuation<Void, Never>?

    func wait() async {
        hasArrived = true
        arrivalWaiter?.resume()
        arrivalWaiter = nil
        if !isOpen { await withCheckedContinuation { waiter = $0 } }
    }

    func waitUntilWaiting() async {
        if !hasArrived { await withCheckedContinuation { arrivalWaiter = $0 } }
    }

    func open() {
        isOpen = true
        waiter?.resume()
        waiter = nil
    }
}

private actor AwarenessRemoteCoordinator: HomeIngestionCoordinating {
    let home: HomeProjectionStore
    let context: LocationContext
    let alert: AlertDTO
    let now: Date
    let gate: AwarenessPublicationGate

    init(home: HomeProjectionStore, context: LocationContext, alert: AlertDTO, now: Date,
         gate: AwarenessPublicationGate) {
        self.home = home
        self.context = context
        self.alert = alert
        self.now = now
        self.gate = gate
    }

    func enqueueAndWait(_ request: HomeIngestionRequest, progress: HomeIngestionProgressHandler?,
                        publication: HomeIngestionPublicationHandler?) async throws -> HomeSnapshot {
        #expect(request.trigger == .remoteHotAlertReceived)
        await gate.wait()
        _ = try await home.commitCore(.init(hotAlerts: ([alert], [])), for: context, loadedAt: now)
        return .empty
    }
}

private struct AwarenessRemoteAlerts: RemoteAlertResolving {
    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO] { [] }
    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] { [] }
    func getAlert(id: String) async throws -> AlertDTO? { nil }
    func resolveNotificationAlert(_ context: HomeRemoteAlertContext) async throws -> AlertDTO? { nil }
}

private struct AwarenessLocationResolver: LocationContextResolving {
    let context: LocationContext

    func prepareCurrentContext(requiresFreshLocation: Bool, showsAuthorizationPrompt: Bool,
                               authorizationTimeout: Double, locationTimeout: Double,
                               maximumAcceptedLocationAge: TimeInterval, placemarkTimeout: Double) async throws -> LocationContext {
        context
    }

    func resolveContext(from snapshot: LocationSnapshot, maximumAcceptedLocationAge: TimeInterval?,
                        placemarkTimeout: Double) async throws -> LocationContext {
        context
    }
}
