import Foundation
import Testing
import SwiftData
import CoreLocation
import OSLog
import ArcusCore
@testable import SkyAware

@Suite("BackgroundScheduler replacement policy", .serialized)
struct BackgroundSchedulerReplacementPolicyTests {
    @Test("Replaces pending request when requested run is materially earlier")
    func replaceWhenRequestedIsEarlier() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(60 * 60)
        let requested = base.addingTimeInterval(20 * 60)
        
        #expect(
            BackgroundScheduler.decision(
                for: .at(existing),
                requested: requested,
                intent: .authoritative,
                minimumDifference: 120
            ) == .replace(existing: existing)
        )
    }
    
    @Test("Replaces pending request when requested run is materially later")
    func replaceWhenRequestedIsLater() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(20 * 60)
        let requested = base.addingTimeInterval(60 * 60)
        
        #expect(
            BackgroundScheduler.decision(
                for: .at(existing),
                requested: requested,
                intent: .authoritative,
                minimumDifference: 120
            ) == .replace(existing: existing)
        )
    }
    
    @Test("Ensure-only scheduling preserves an existing request")
    func ensureOnlyPreservesExistingRequest() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(20 * 60)
        let requested = base.addingTimeInterval(60 * 60)
        
        #expect(
            BackgroundScheduler.decision(
                for: .at(existing),
                requested: requested,
                intent: .ensure,
                minimumDifference: 120
            ) == .keepExisting
        )
    }

    @Test("Keeps requests within the two-minute replacement tolerance")
    func keepsRequestsWithinTwoMinuteTolerance() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(60 * 60)
        let requested = existing.addingTimeInterval(-120)

        #expect(
            BackgroundScheduler.decision(
                for: .at(existing),
                requested: requested,
                intent: .authoritative,
                minimumDifference: 120
            ) == .keepExisting
        )
    }

    @Test("Preserves immediate pending requests")
    func preservesImmediatePendingRequests() {
        let requested = Date(timeIntervalSince1970: 0).addingTimeInterval(20 * 60)

        #expect(
            BackgroundScheduler.decision(
                for: .immediate,
                requested: requested,
                intent: .authoritative,
                minimumDifference: 120
            ) == .keepImmediate
        )
    }
}

@Suite("BackgroundOrchestrator Cadence", .serialized)
struct BackgroundOrchestratorCadenceTests {
    @Test("Every storm risk level maps to the evaluated cadence band")
    func everyStormRiskLevel_mapsToExpectedCadenceBand() {
        let policy = CadencePolicy()
        let cases: [(StormRiskLevel, Cadence)] = [
            (.allClear, .long),
            (.thunderstorm, .normal),
            (.marginal, .short),
            (.slight, .short),
            (.enhanced, .short),
            (.moderate, .short),
            (.high, .short)
        ]

        for (risk, expected) in cases {
            let result = policy.decide(
                for: .init(
                    categorical: risk,
                    inMeso: false,
                    inAlert: false
                )
            )

            #expect(result.cadence == expected)
            #expect(result.reason.contains(risk.abbreviation))
        }
    }

    @Test("Alert and meso precedence wins over categorical cadence")
    func alertAndMesoPrecedenceWinsOverCategoricalCadence() {
        let policy = CadencePolicy()
        let result = policy.decide(
            for: .init(
                categorical: .allClear,
                inMeso: true,
                inAlert: true
            )
        )

        #expect(result.cadence == .short)
        #expect(result.reason == "gate=watch,meso")
    }

    @Test("Fresh location request updates provider before risk queries")
    func freshLocationRequest_updatesProviderBeforeRiskQueries() async throws {
        let refreshed = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: refreshed,
            refreshSucceeds: true,
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        _ = await setup.orchestrator.run()

        let points = await setup.spc.queriedPoints()
        #expect(points.isEmpty == false)
        #expect(points.allSatisfy { $0.latitude == refreshed.latitude && $0.longitude == refreshed.longitude })
    }

    @Test("Failed fresh location request uses recent cached snapshot")
    func failedFreshLocationRequest_usesRecentCachedSnapshot() async throws {
        let cached = CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395)
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            refreshSucceeds: false,
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        _ = await setup.orchestrator.run()

        let points = await setup.spc.queriedPoints()
        #expect(points.isEmpty == false)
        #expect(points.allSatisfy { $0.latitude == cached.latitude && $0.longitude == cached.longitude })
    }

    @Test("Stale cached snapshot skips location-dependent work when refresh fails")
    func staleCachedSnapshot_skipsLocationDependentWorkWhenRefreshFails() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            refreshSucceeds: false,
            cachedSnapshotTimestamp: Date().addingTimeInterval(-(6 * 60)),
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        let outcome = await setup.orchestrator.run()

        let points = await setup.spc.queriedPoints()
        #expect(points.isEmpty)
        #expect(outcome.result == .skipped)
    }

    @Test("Global SPC sync still runs when location context is unavailable")
    func globalSpcSync_runsBeforeLocationContext() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: nil,
            refreshSucceeds: false,
            cachedSnapshotTimestamp: Date().addingTimeInterval(-(6 * 60)),
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        _ = await setup.orchestrator.run()

        #expect(await setup.spc.syncMapProductsCount() == 1)
        #expect(await setup.spc.syncConvectiveOutlooksCount() == 1)
        #expect(await setup.spc.syncExecutionModes().allSatisfy { $0 == .background })
        #expect((await setup.spc.queriedPoints()).isEmpty)
    }

    @Test("Background refresh drains pending uploads before unified ingestion starts")
    func backgroundRefresh_drainsPendingUploadsBeforeUnifiedIngestionStarts() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        try await MainActor.run { try TestStore.reset(BgRunSnapshot.self, in: container) }

        let gate = AsyncGate()
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let coordinator = RecordingHomeIngestionCoordinator(
            snapshot: HomeSnapshot(
                locationSnapshot: context.snapshot,
                refreshKey: context.refreshKey,
                stormRisk: .allClear,
                severeRisk: .allClear,
                fireRisk: .clear
            ),
            runGate: gate
        )
        let uploadDrainer = RecordingPendingUploadDrainer()
        let orchestrator = BackgroundOrchestrator(
            coordinator: coordinator,
            policy: RefreshPolicy(),
            engine: MorningEngine(
                rule: NoopMorningRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender()
            ),
            mesoEngine: MesoEngine(
                rule: NoopMesoRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender(),
                spc: FakeSpcProvider(activeMesos: [])
            ),
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            health: BgHealthStore(modelContainer: container),
            cadence: CadencePolicy(),
            notificationSettingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
            ),
            pendingUploadDrainer: uploadDrainer
        )
        let completion = CompletionFlag()

        let runTask = Task {
            _ = await orchestrator.run()
            await completion.markFinished()
        }

        let requestStarted = await waitUntil {
            await coordinator.requestCount() == 1
        }
        #expect(requestStarted)
        #expect(await completion.isFinished() == false)
        #expect(await uploadDrainer.drainCount() == 1)

        let request = try #require(await coordinator.requests().first)
        #expect(request.trigger == .backgroundRefresh)

        await gate.open()
        await runTask.value

        #expect(await completion.isFinished())
        #expect(await uploadDrainer.drainCount() == 1)
    }

    @Test("Background refresh still drains pending uploads when it exits early")
    func backgroundRefresh_drainsPendingUploadsOnEarlyExit() async throws {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        try await MainActor.run { try TestStore.reset(BgRunSnapshot.self, in: container) }

        let coordinator = RecordingHomeIngestionCoordinator(snapshot: HomeSnapshot())
        let uploadDrainer = RecordingPendingUploadDrainer()
        let orchestrator = BackgroundOrchestrator(
            coordinator: coordinator,
            policy: RefreshPolicy(),
            engine: MorningEngine(
                rule: NoopMorningRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender()
            ),
            mesoEngine: MesoEngine(
                rule: NoopMesoRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender(),
                spc: FakeSpcProvider(activeMesos: [])
            ),
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            health: BgHealthStore(modelContainer: container),
            cadence: CadencePolicy(),
            notificationSettingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
            ),
            pendingUploadDrainer: uploadDrainer
        )

        let outcome = await orchestrator.run()

        #expect(outcome.result == .skipped)
        #expect(await uploadDrainer.drainCount() == 1)
    }

    @Test("Active meso tightens cadence to short")
    func activeMeso_tightensCadenceToShort() async throws {
        let setup = try await makeSystem(
            activeMesos: [Self.makeMeso()],
            activeAlerts: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )
        _ = await setup.orchestrator.run()

        let cadence = try await setup.latestCadence()
        #expect(cadence == Cadence.short.minutes)
    }

    @Test("Active alert tightens cadence to short")
    func activeAlert_tightensCadenceToShort() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [Self.makeAlert()],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )
        _ = await setup.orchestrator.run()

        let cadence = try await setup.latestCadence()
        #expect(cadence == Cadence.short.minutes)
    }

    @Test("No active meso/alert keeps all-clear cadence long")
    func noActiveHazards_keepsLongCadenceForAllClear() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )
        _ = await setup.orchestrator.run()

        let cadence = try await setup.latestCadence()
        #expect(cadence == Cadence.long.minutes)
    }

    @Test("Background refresh sends one risk notification and marks didNotify")
    func backgroundRefresh_sendsRiskNotificationAndMarksDidNotify() async throws {
        let sender = RecordingRiskSender()
        let settingsProvider = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: true
            )
        )
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let system = try await makeRiskSystem(
            snapshot: snapshot,
            riskChangeEngine: makeRiskChangeEngine(sender: sender),
            settingsProvider: settingsProvider
        )

        let outcome = await system.orchestrator.run()
        let health = try #require(await system.latestHealthRecord())

        #expect(outcome.didNotify)
        #expect(health.didNotify)
        #expect(await sender.sent().count == 1)
    }

    @Test("Background refresh records disabled risk change no-notify reason")
    func backgroundRefresh_recordsDisabledRiskChangeNoNotifyReason() async throws {
        let sender = RecordingRiskSender()
        let settingsProvider = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: false
            )
        )
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let unchangedSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: nil
        )
        let system = try await makeRiskSystem(
            snapshots: [snapshot, unchangedSnapshot],
            riskChangeEngine: makeRiskChangeEngine(sender: sender),
            settingsProvider: settingsProvider
        )

        let outcome = await system.orchestrator.run()
        let health = try #require(await system.latestHealthRecord())

        #expect(outcome.didNotify == false)
        #expect(await sender.sent().isEmpty)
        #expect(health.didNotify == false)
        #expect(health.reasonNoNotify?.contains("Risk change notifications disabled") == true)
    }

    @Test("Background refresh records missing risk change no-notify reason")
    func backgroundRefresh_recordsMissingRiskChangeNoNotifyReason() async throws {
        let sender = RecordingRiskSender()
        let settingsProvider = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: true
            )
        )
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: nil
        )
        let system = try await makeRiskSystem(
            snapshot: snapshot,
            riskChangeEngine: makeRiskChangeEngine(sender: sender),
            settingsProvider: settingsProvider
        )

        let outcome = await system.orchestrator.run()
        let health = try #require(await system.latestHealthRecord())

        #expect(outcome.didNotify == false)
        #expect(await sender.sent().isEmpty)
        #expect(health.didNotify == false)
        #expect(health.reasonNoNotify?.contains("Risk change notification skipped (no change)") == true)
    }

    @Test("Disabled risk changes remain pending after a normal morning summary")
    func disabledRiskChangeRemainsPendingAfterNormalMorningSummary() async throws {
        let morningSender = RecordingRiskSender()
        let riskSender = RecordingRiskSender()
        let settingsProvider = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: true,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: false
            )
        )
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let unchangedSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .allClear,
            fireRisk: .clear,
            riskProfileChange: nil
        )
        let system = try await makeRiskSystem(
            snapshots: [snapshot, unchangedSnapshot],
            morningEngine: makeMorningEngine(sender: morningSender),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: settingsProvider
        )

        let firstOutcome = await system.orchestrator.run()
        #expect(firstOutcome.didNotify)
        let firstMorning = try #require(await morningSender.sent().first)
        #expect(firstMorning.body.contains("Risk Update") == false)
        #expect(await riskSender.sent().isEmpty)

        await settingsProvider.update(
            .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: true
            )
        )

        let secondOutcome = await system.orchestrator.run()
        let health = try #require(await system.latestHealthRecord())

        #expect(secondOutcome.didNotify)
        #expect(await riskSender.sent().count == 1)
        #expect(health.didNotify)
    }

    @Test("Morning success coalesces the current snapshot risk change")
    func morningSuccessCoalescesCurrentSnapshotRiskChange() async throws {
        let morningSender = RecordingRiskSender()
        let riskSender = RecordingRiskSender()
        let settings = StaticSettingsProvider(
            settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
        )
        let snapshot = Self.makeRiskSnapshot(
            change: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let system = try await makeRiskSystem(
            snapshot: snapshot,
            morningEngine: makeMorningEngine(sender: morningSender),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: settings
        )

        #expect((await system.orchestrator.run()).didNotify)
        #expect((await morningSender.sent()).count == 1)
        #expect((await riskSender.sent()).isEmpty)
    }

    @Test("Morning scheduling failure falls back to the current snapshot risk change")
    func morningSchedulingFailureFallsBackToRiskChange() async throws {
        let riskSender = RecordingRiskSender()
        let snapshot = Self.makeRiskSnapshot(
            change: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let system = try await makeRiskSystem(
            snapshot: snapshot,
            morningEngine: makeMorningEngine(sender: FailingNotificationSender()),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
            )
        )

        #expect((await system.orchestrator.run()).didNotify)
        #expect((await riskSender.sent()).count == 1)
    }

    @Test("Later risk transition remains independent after a coalesced morning")
    func laterRiskTransitionRemainsIndependentAfterCoalescedMorning() async throws {
        let morningSender = RecordingRiskSender()
        let riskSender = RecordingRiskSender()
        let first = Self.makeRiskSnapshot(
            change: makeRiskChange(
                projectionKey: "projection:one",
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let second = Self.makeRiskSnapshot(
            change: makeRiskChange(
                projectionKey: "projection:two",
                previous: makeRiskProfile(storm: .allClear, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .slight, severe: .allClear, fire: .clear)
            )
        )
        let system = try await makeRiskSystem(
            snapshots: [first, second],
            morningEngine: makeMorningEngine(sender: morningSender, gate: FirstMorningOnlyGate()),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: true, mesoNotificationsEnabled: false)
            )
        )

        _ = await system.orchestrator.run()
        _ = await system.orchestrator.run()

        #expect((await morningSender.sent()).count == 1)
        #expect((await riskSender.sent()).count == 1)
    }

    @Test("Morning without a current change still delivers an older pending risk change")
    func morningWithoutCurrentChangeDeliversOlderPendingRiskChange() async throws {
        let morningSender = RecordingRiskSender()
        let riskSender = RecordingRiskSender()
        let settings = MutableSettingsProvider(
            settings: .init(
                morningSummariesEnabled: false,
                mesoNotificationsEnabled: false,
                riskChangeNotificationsEnabled: false
            )
        )
        let first = Self.makeRiskSnapshot(
            change: makeRiskChange(
                previous: makeRiskProfile(storm: .marginal, severe: .allClear, fire: .clear),
                current: makeRiskProfile(storm: .enhanced, severe: .allClear, fire: .clear)
            )
        )
        let second = Self.makeRiskSnapshot(change: nil)
        let system = try await makeRiskSystem(
            snapshots: [first, second],
            morningEngine: makeMorningEngine(sender: morningSender),
            riskChangeEngine: makeRiskChangeEngine(sender: riskSender),
            settingsProvider: settings
        )

        _ = await system.orchestrator.run()
        await settings.update(.init(morningSummariesEnabled: true, mesoNotificationsEnabled: false))
        _ = await system.orchestrator.run()

        #expect((await morningSender.sent()).count == 1)
        #expect((await riskSender.sent()).count == 1)
    }

    @Test("Missing location context records recovery cadence 20")
    func missingLocationContext_recordsRecoveryCadenceTwenty() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeAlerts: [],
            refreshedLocation: nil,
            refreshSucceeds: false,
            cachedSnapshotTimestamp: Date().addingTimeInterval(-(6 * 60)),
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
        )

        let outcome = await setup.orchestrator.run()
        let cadence = try await setup.latestCadence()

        #expect(outcome.result == .skipped)
        #expect(cadence == 20)
    }

    @Test("Failure to all-clear recovery records 20 then 60")
    func failureToAllClearRecovery_recordsTwentyThenSixty() async throws {
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let successSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .allClear,
            severeRisk: .allClear,
            fireRisk: .clear
        )
        let coordinator = ScriptedHomeIngestionCoordinator(
            responses: [
                .failure(.failed),
                .snapshot(successSnapshot)
            ]
        )
        let system = try await makeRiskSystem(
            coordinator: coordinator,
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            settingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
            )
        )

        let firstOutcome = await system.orchestrator.run()
        let secondOutcome = await system.orchestrator.run()
        let cadences = try await system.recordedCadences()

        #expect(firstOutcome.result == .failed)
        #expect(secondOutcome.result == .success)
        #expect(cadences == [20, 60])
    }

    @Test("Failure to thunderstorm recovery records 20 then 40")
    func failureToThunderstormRecovery_recordsTwentyThenForty() async throws {
        let context = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        let successSnapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .thunderstorm,
            severeRisk: .allClear,
            fireRisk: .clear
        )
        let coordinator = ScriptedHomeIngestionCoordinator(
            responses: [
                .failure(.failed),
                .snapshot(successSnapshot)
            ]
        )
        let system = try await makeRiskSystem(
            coordinator: coordinator,
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            settingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
            )
        )

        let firstOutcome = await system.orchestrator.run()
        let secondOutcome = await system.orchestrator.run()
        let cadences = try await system.recordedCadences()

        #expect(firstOutcome.result == .failed)
        #expect(secondOutcome.result == .success)
        #expect(cadences == [20, 40])
    }
}

private extension BackgroundOrchestratorCadenceTests {
    struct SystemUnderTest {
        let orchestrator: BackgroundOrchestrator
        let modelContainer: ModelContainer
        let spc: FakeSpcProvider

        func latestCadence() async throws -> Int? {
            try await MainActor.run {
                let context = ModelContext(modelContainer)
                var descriptor = FetchDescriptor<BgRunSnapshot>(
                    sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
                )
                descriptor.fetchLimit = 1
                return try context.fetch(descriptor).first?.cadence
            }
        }
    }

    func makeSystem(
        activeMesos: [MdDTO],
        activeAlerts: [AlertDTO],
        refreshedLocation: CLLocationCoordinate2D? = nil,
        refreshSucceeds: Bool = false,
        cachedSnapshotTimestamp: Date = Date(),
        settings: NotificationSettings,
        pendingUploadDrainer: any PendingLocationUploadDraining = NoOpLocationUploadCoordinator()
    ) async throws -> SystemUnderTest {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        try await MainActor.run { try TestStore.reset(BgRunSnapshot.self, in: container) }

        let healthStore = BgHealthStore(modelContainer: container)
        let spc = FakeSpcProvider(activeMesos: activeMesos)
        let alertProvider = FakeAlertProvider(activeAlerts: activeAlerts)
        let cachedContext = Self.makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
            timestamp: cachedSnapshotTimestamp,
            placemarkSummary: "Norman, OK"
        )
        let resolvedContext: LocationContext? = if refreshSucceeds, let refreshedLocation {
            Self.makeContext(
                coordinates: refreshedLocation,
                timestamp: Date(),
                placemarkSummary: "Denver, CO"
            )
        } else if Date().timeIntervalSince(cachedSnapshotTimestamp) <= 5 * 60 {
            cachedContext
        } else {
            nil
        }
        let locationSession = await MainActor.run {
            FakeLocationSession(
                currentContext: nil,
                preparedContext: resolvedContext
            )
        }

        let morningEngine = MorningEngine(
            rule: NoopMorningRule(),
            gate: AllowAllGate(),
            composer: NoopComposer(),
            sender: NoopSender()
        )
        let mesoEngine = MesoEngine(
            rule: NoopMesoRule(),
            gate: AllowAllGate(),
            composer: NoopComposer(),
            sender: NoopSender(),
            spc: spc
        )
        let snapshotStore = HomeSnapshotStore(
            spcRisk: spc,
            spcOutlook: spc,
            arcusAlerts: alertProvider
        )
        let coordinator = HomeIngestionCoordinator(
            executor: HomeIngestionExecutor(
                environment: .init(
                    logger: Logger(subsystem: "SkyAwareTests", category: "BackgroundOrchestratorCadenceTests"),
                    spcSync: spc,
                    arcusAlertSync: alertProvider,
                    weatherClient: FakeWeatherClient(),
                    locationSession: locationSession,
                    snapshotStore: snapshotStore,
                    projectionStore: nil,
                    widgetSnapshotRefresher: nil
                )
            )
        )

        let orchestrator = BackgroundOrchestrator(
            coordinator: coordinator,
            policy: RefreshPolicy(),
            engine: morningEngine,
            mesoEngine: mesoEngine,
            riskChangeEngine: makeRiskChangeEngine(sender: NoopSender()),
            health: healthStore,
            cadence: CadencePolicy(),
            notificationSettingsProvider: StaticSettingsProvider(settings: settings),
            pendingUploadDrainer: pendingUploadDrainer
        )

        return .init(orchestrator: orchestrator, modelContainer: container, spc: spc)
    }

    static func makeMeso() -> MdDTO {
        let now = Date()
        return MdDTO(
            number: 1001,
            title: "Mesoscale Discussion",
            link: URL(string: "https://www.spc.noaa.gov/products/md/1001.html")!,
            issued: now.addingTimeInterval(-3_600),
            validStart: now.addingTimeInterval(-3_600),
            validEnd: now.addingTimeInterval(3_600),
            areasAffected: "Central Oklahoma",
            summary: "Strong to severe storms possible.",
            watchProbability: "40",
            threats: nil,
            coordinates: []
        )
    }

    static func makeAlert() -> AlertDTO {
        let now = Date()
        return AlertDTO(
            id: "watch-1001",
            messageId: "watch-1001",
            title: "Tornado Watch",
            headline: "Tornadoes possible in the watch area",
            issued: now.addingTimeInterval(-3_600),
            expires: now.addingTimeInterval(3_600),
            ends: now.addingTimeInterval(3_600),
            messageType: "Alert",
            sender: "NWS Norman",
            severity: "Severe",
            urgency: "Immediate",
            certainty: "Observed",
            description: "A tornado watch has been issued.",
            instruction: nil,
            response: nil,
            areaSummary: "Central Oklahoma",
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

    static func makeContext(
        coordinates: CLLocationCoordinate2D,
        timestamp: Date,
        placemarkSummary: String
    ) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: coordinates,
            timestamp: timestamp,
            accuracy: 10,
            placemarkSummary: placemarkSummary,
            h3Cell: 0x882681b485fffff
        )
        return LocationContext(
            snapshot: snapshot,
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/\(coordinates.latitude),\(coordinates.longitude)",
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
                gridId: "OUN",
                gridX: 34,
                gridY: 74,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Norman",
                state: "OK",
                timeZoneId: "America/Chicago",
                radarStationId: "KTLX",
                forecastZone: "OKZ025",
                countyCode: "OKC109",
                fireZone: "OKZ025",
                countyLabel: "Oklahoma County",
                fireZoneLabel: "Central Oklahoma"
            )
        )
    }
}

private actor FakeSpcProvider: SpcSyncing, SpcRiskQuerying, SpcOutlookQuerying {
    private var recordedPoints: [CLLocationCoordinate2D] = []
    private var syncCalls = 0
    private var syncMapProductsCalls = 0
    private var syncConvectiveOutlooksCalls = 0
    private var syncExecutionModeValues: [HTTPExecutionMode] = []

    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> SkyAware.FireRiskLevel {
        recordedPoints.append(point)
        return .clear
    }
    
    private let activeMesos: [MdDTO]

    init(activeMesos: [MdDTO]) {
        self.activeMesos = activeMesos
    }

    func sync() async { syncCalls += 1 }
    func syncMapProducts() async {
        syncMapProductsCalls += 1
        syncExecutionModeValues.append(HTTPExecutionMode.current)
    }
    func syncMapProductsOutcome() async -> SpcMapSyncOutcome {
        syncMapProductsCalls += 1
        syncExecutionModeValues.append(HTTPExecutionMode.current)
        return .accepted
    }
    func syncTextProducts() async {}
    func syncConvectiveOutlooks() async {
        syncConvectiveOutlooksCalls += 1
        syncExecutionModeValues.append(HTTPExecutionMode.current)
    }
    func syncMesoscaleDiscussions() async {
        syncExecutionModeValues.append(HTTPExecutionMode.current)
    }

    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        recordedPoints.append(point)
        return .allClear
    }

    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        recordedPoints.append(point)
        return .allClear
    }

    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] {
        recordedPoints.append(point)
        return activeMesos
    }

    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        nil
    }

    func getConvectiveOutlooks() async throws -> [ConvectiveOutlookDTO] {
        []
    }

    func queriedPoints() -> [CLLocationCoordinate2D] {
        recordedPoints
    }

    func syncCount() -> Int {
        syncCalls
    }

    func syncMapProductsCount() -> Int {
        syncMapProductsCalls
    }

    func syncConvectiveOutlooksCount() -> Int {
        syncConvectiveOutlooksCalls
    }

    func syncExecutionModes() -> [HTTPExecutionMode] {
        syncExecutionModeValues
    }
}

private actor FakeAlertProvider: ArcusAlertSyncing, ArcusAlertQuerying {
    private let activeAlerts: [AlertDTO]

    init(activeAlerts: [AlertDTO]) {
        self.activeAlerts = activeAlerts
    }

    func sync(context: LocationContext) async {}

    func syncRemoteAlert(id: String, revisionSent: Date?) async {}

    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO] {
        activeAlerts
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        []
    }

    func getAlert(id: String) async throws -> AlertDTO? {
        activeAlerts.first(where: { $0.id == id })
    }
}

@MainActor
private final class FakeLocationSession: HomeContextPreparing {
    var currentContext: LocationContext?
    var preparedContext: LocationContext?

    init(
        currentContext: LocationContext?,
        preparedContext: LocationContext?
    ) {
        self.currentContext = currentContext
        self.preparedContext = preparedContext
    }

    func prepareCurrentLocationContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async -> LocationContext? {
        preparedContext
    }

    func currentPreparedContext() async -> LocationContext? {
        currentContext
    }
}

private actor FakeWeatherClient: HomeWeatherQuerying {
    func currentWeather(for location: CLLocation) async -> HomeWeatherRefreshResult {
        .success(nil)
    }
}

private actor RecordingHomeIngestionCoordinator: HomeIngestionCoordinating {
    private let snapshot: HomeSnapshot
    private let runGate: AsyncGate?
    private var submittedRequests: [HomeIngestionRequest] = []

    init(
        snapshot: HomeSnapshot = .empty,
        runGate: AsyncGate? = nil
    ) {
        self.snapshot = snapshot
        self.runGate = runGate
    }

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {
        submittedRequests.append(
            HomeIngestionRequest(
                trigger: trigger,
                locationContext: locationContext,
                remoteAlertContext: remoteAlertContext
            )
        )
    }

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) async throws -> HomeSnapshot {
        let request = HomeIngestionRequest(
            trigger: trigger,
            locationContext: locationContext,
            remoteAlertContext: remoteAlertContext
        )
        return try await enqueueAndWait(request)
    }

    func enqueue(_ request: HomeIngestionRequest) {
        submittedRequests.append(request)
    }

    func enqueueAndWait(_ request: HomeIngestionRequest) async throws -> HomeSnapshot {
        submittedRequests.append(request)
        if let runGate {
            await runGate.wait()
        }
        return snapshot
    }

    func requests() -> [HomeIngestionRequest] {
        submittedRequests
    }

    func requestCount() -> Int {
        submittedRequests.count
    }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen {
            return
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private actor CompletionFlag {
    private var finished = false

    func markFinished() {
        finished = true
    }

    func isFinished() -> Bool {
        finished
    }
}

private actor RecordingPendingUploadDrainer: PendingLocationUploadDraining {
    private var count = 0

    func drainPendingUploads() async {
        count += 1
    }

    func drainCount() -> Int {
        count
    }
}

private struct StaticSettingsProvider: NotificationSettingsProviding {
    let settings: NotificationSettings

    func current() async -> NotificationSettings {
        settings
    }
}

private actor MutableSettingsProvider: NotificationSettingsProviding {
    private var settings: NotificationSettings

    init(settings: NotificationSettings) {
        self.settings = settings
    }

    func current() async -> NotificationSettings {
        settings
    }

    func update(_ settings: NotificationSettings) {
        self.settings = settings
    }
}

private actor RecordingRiskSender: NotificationSending {
    struct SentNotification: Sendable {
        let title: String
        let body: String
        let subtitle: String
        let id: String
    }

    private var notifications: [SentNotification] = []

    func send(title: String, body: String, subtitle: String, id: String) async -> Bool {
        notifications.append(.init(title: title, body: body, subtitle: subtitle, id: id))
        return true
    }

    func sent() -> [SentNotification] {
        notifications
    }
}

private actor InMemoryRiskChangeStore: NotificationStateStoring {
    private var stamp: String?

    init(stamp: String? = nil) {
        self.stamp = stamp
    }

    func lastStamp() async -> String? {
        stamp
    }

    func setLastStamp(_ stamp: String) async {
        self.stamp = stamp
    }
}

private actor SequentialHomeIngestionCoordinator: HomeIngestionCoordinating {
    private var snapshots: [HomeSnapshot]
    private var lastSnapshot: HomeSnapshot

    init(snapshots: [HomeSnapshot]) {
        self.snapshots = snapshots
        self.lastSnapshot = snapshots.last ?? .empty
    }

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {}

    func enqueue(_ request: HomeIngestionRequest) {}

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) async throws -> HomeSnapshot {
        try await enqueueAndWait(.init(trigger: trigger, locationContext: locationContext, remoteAlertContext: remoteAlertContext))
    }

    func enqueueAndWait(_ request: HomeIngestionRequest) async throws -> HomeSnapshot {
        guard snapshots.isEmpty == false else { return lastSnapshot }
        let snapshot = snapshots.removeFirst()
        lastSnapshot = snapshot
        return snapshot
    }
}

private enum ScriptedCoordinatorError: Error {
    case failed
}

private actor ScriptedHomeIngestionCoordinator: HomeIngestionCoordinating {
    enum Response: Sendable {
        case snapshot(HomeSnapshot)
        case failure(ScriptedCoordinatorError)
    }

    private var responses: [Response]

    init(responses: [Response]) {
        self.responses = responses
    }

    func enqueue(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) {}

    func enqueue(_ request: HomeIngestionRequest) {}

    func enqueueAndWait(
        _ trigger: HomeRefreshTrigger,
        locationContext: LocationContext? = nil,
        remoteAlertContext: HomeRemoteAlertContext? = nil
    ) async throws -> HomeSnapshot {
        try await enqueueAndWait(.init(trigger: trigger, locationContext: locationContext, remoteAlertContext: remoteAlertContext))
    }

    func enqueueAndWait(_ request: HomeIngestionRequest) async throws -> HomeSnapshot {
        guard responses.isEmpty == false else { return .empty }
        switch responses.removeFirst() {
        case .snapshot(let snapshot):
            return snapshot
        case .failure(let error):
            throw error
        }
    }
}

private extension BackgroundOrchestratorCadenceTests {
    struct RiskSystem {
        let orchestrator: BackgroundOrchestrator
        let modelContainer: ModelContainer

        struct HealthRecord: Sendable {
            let didNotify: Bool
            let reasonNoNotify: String?
        }

        func latestHealthRecord() async throws -> HealthRecord? {
            try await MainActor.run {
                let context = ModelContext(modelContainer)
                var descriptor = FetchDescriptor<BgRunSnapshot>(
                    sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
                )
                descriptor.fetchLimit = 1
                guard let health = try context.fetch(descriptor).first else {
                    return nil
                }
                return HealthRecord(didNotify: health.didNotify, reasonNoNotify: health.reasonNoNotify)
            }
        }

        func recordedCadences() async throws -> [Int] {
            try await MainActor.run {
                let context = ModelContext(modelContainer)
                let descriptor = FetchDescriptor<BgRunSnapshot>(
                    sortBy: [SortDescriptor(\.endedAt, order: .forward)]
                )
                return try context.fetch(descriptor).map(\.cadence)
            }
        }
    }

    func makeRiskSystem<Settings: NotificationSettingsProviding>(
        coordinator: any HomeIngestionCoordinating,
        morningEngine: MorningEngine? = nil,
        riskChangeEngine: RiskChangeEngine,
        settingsProvider: Settings
    ) async throws -> RiskSystem {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        try await MainActor.run { try TestStore.reset(BgRunSnapshot.self, in: container) }

        let healthStore = BgHealthStore(modelContainer: container)
        let orchestrator = BackgroundOrchestrator(
            coordinator: coordinator,
            policy: RefreshPolicy(),
            engine: morningEngine ?? MorningEngine(
                rule: NoopMorningRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender()
            ),
            mesoEngine: MesoEngine(
                rule: NoopMesoRule(),
                gate: AllowAllGate(),
                composer: NoopComposer(),
                sender: NoopSender(),
                spc: FakeSpcProvider(activeMesos: [])
            ),
            riskChangeEngine: riskChangeEngine,
            health: healthStore,
            cadence: CadencePolicy(),
            notificationSettingsProvider: settingsProvider,
            pendingUploadDrainer: NoOpLocationUploadCoordinator()
        )

        return .init(orchestrator: orchestrator, modelContainer: container)
    }

    func makeRiskSystem<Settings: NotificationSettingsProviding>(
        snapshot: HomeSnapshot? = nil,
        snapshots: [HomeSnapshot]? = nil,
        morningEngine: MorningEngine? = nil,
        riskChangeEngine: RiskChangeEngine,
        settingsProvider: Settings
    ) async throws -> RiskSystem {
        let coordinator: any HomeIngestionCoordinating
        if let snapshots {
            coordinator = SequentialHomeIngestionCoordinator(snapshots: snapshots)
        } else {
            coordinator = RecordingHomeIngestionCoordinator(snapshot: snapshot ?? .empty)
        }
        return try await makeRiskSystem(
            coordinator: coordinator,
            morningEngine: morningEngine,
            riskChangeEngine: riskChangeEngine,
            settingsProvider: settingsProvider
        )
    }

    func makeRiskChangeEngine<Sender: NotificationSending>(
        sender: Sender,
        store: any NotificationStateStoring = InMemoryRiskChangeStore()
    ) -> RiskChangeEngine {
        RiskChangeEngine(
            rule: RiskChangeRule(),
            gate: RiskChangeGate(store: store),
            composer: RiskChangeComposer(),
            sender: sender
        )
    }

    func makeRiskChange(
        projectionKey: String = "projection:alpha",
        previous: RiskProfile,
        current: RiskProfile,
        locationSummary: String = "Denver, CO"
    ) -> RiskProfileChange {
        RiskProfileChange(
            previous: previous,
            current: current,
            projectionKey: projectionKey,
            locationSummary: locationSummary
        )!
    }

    func makeRiskProfile(
        storm: StormRiskLevel,
        severe: SevereWeatherThreat,
        fire: FireRiskLevel
    ) -> RiskProfile {
        RiskProfile(stormRisk: storm, severeRisk: severe, fireRisk: fire)
    }

    func makeMorningEngine<Sender: NotificationSending>(
        sender: Sender,
        gate: any NotificationGating = AllowAllGate()
    ) -> MorningEngine {
        MorningEngine(
            rule: AmRangeLocalRule(window: 0..<24),
            gate: gate,
            composer: MorningComposer(),
            sender: sender
        )
    }

    static func makeRiskSnapshot(change: RiskProfileChange?) -> HomeSnapshot {
        let context = makeContext(
            coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            timestamp: Date(),
            placemarkSummary: "Denver, CO"
        )
        return HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: change?.current.stormRisk ?? .enhanced,
            severeRisk: change?.current.severeRisk ?? .allClear,
            fireRisk: change?.current.fireRisk ?? .clear,
            riskProfileChange: change
        )
    }
}

private struct NoopMorningRule: NotificationRuleEvaluating {
    func evaluate(_ ctx: MorningContext) -> NotificationEvent? {
        nil
    }
}

private struct NoopMesoRule: MesoNotificationRuleEvaluating {
    func evaluate(_ ctx: MesoContext) -> NotificationEvent? {
        nil
    }
}

private struct AllowAllGate: NotificationGating {
    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        true
    }
}

private struct NoopComposer: NotificationComposing {
    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String) {
        ("", "", "")
    }
}

private struct NoopSender: NotificationSending {
    func send(title: String, body: String, subtitle: String, id: String) async -> Bool { true }
}

private struct FailingNotificationSender: NotificationSending {
    func send(title: String, body: String, subtitle: String, id: String) async -> Bool { false }
}

private actor FirstMorningOnlyGate: NotificationGating {
    private var hasAllowed = false

    func allow(_ event: NotificationEvent, now: Date) async -> Bool {
        defer { hasAllowed = true }
        return hasAllowed == false
    }
}

private func waitUntil(
    timeout: Duration = .seconds(1),
    interval: Duration = .milliseconds(20),
    _ condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: interval)
    }
    return await condition()
}
