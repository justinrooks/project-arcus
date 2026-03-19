import Foundation
import Testing
import SwiftData
import CoreLocation
@testable import SkyAware

@Suite("BackgroundScheduler replacement policy", .serialized)
struct BackgroundSchedulerReplacementPolicyTests {
    @Test("Replaces pending request when requested run is materially earlier")
    func replaceWhenRequestedIsEarlier() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(60 * 60)
        let requested = base.addingTimeInterval(20 * 60)
        
        #expect(
            BackgroundScheduler.shouldReplace(
                existing: existing,
                requested: requested,
                minimumAdvance: 120
            )
        )
    }
    
    @Test("Does not replace when requested run is later")
    func doNotReplaceWhenRequestedIsLater() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(20 * 60)
        let requested = base.addingTimeInterval(60 * 60)
        
        #expect(
            BackgroundScheduler.shouldReplace(
                existing: existing,
                requested: requested,
                minimumAdvance: 120
            ) == false
        )
    }
    
    @Test("Does not replace when request is only slightly earlier than pending")
    func doNotReplaceForTinyTimingDifference() {
        let base = Date(timeIntervalSince1970: 0)
        let existing = base.addingTimeInterval(60 * 60)
        let requested = base.addingTimeInterval((60 * 60) - 60)
        
        #expect(
            BackgroundScheduler.shouldReplace(
                existing: existing,
                requested: requested,
                minimumAdvance: 120
            ) == false
        )
    }
}

@Suite("BackgroundOrchestrator Cadence", .serialized)
struct BackgroundOrchestratorCadenceTests {
    @Test("Fresh location request updates provider before risk queries")
    func freshLocationRequest_updatesProviderBeforeRiskQueries() async throws {
        let refreshed = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let setup = try await makeSystem(
            activeMesos: [],
            activeWatches: [],
            refreshedLocation: refreshed,
            refreshSucceeds: true,
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false, watchNotificationsEnabled: false)
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
            activeWatches: [],
            refreshedLocation: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            refreshSucceeds: false,
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false, watchNotificationsEnabled: false)
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
            activeWatches: [],
            refreshedLocation: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
            refreshSucceeds: false,
            cachedSnapshotTimestamp: Date().addingTimeInterval(-(6 * 60)),
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false, watchNotificationsEnabled: false)
        )

        let outcome = await setup.orchestrator.run()

        let points = await setup.spc.queriedPoints()
        #expect(points.isEmpty)
        #expect(outcome.result == .skipped)
    }

    @Test("Active meso tightens cadence to short")
    func activeMeso_tightensCadenceToShort() async throws {
        let setup = try await makeSystem(
            activeMesos: [Self.makeMeso()],
            activeWatches: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false, watchNotificationsEnabled: false)
        )
        _ = await setup.orchestrator.run()

        let cadence = try await setup.latestCadence()
        #expect(cadence == Cadence.defaultShort)
    }

    @Test("Active watch tightens cadence to short")
    func activeWatch_tightensCadenceToShort() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeWatches: [Self.makeWatch()],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false, watchNotificationsEnabled: false)
        )
        _ = await setup.orchestrator.run()

        let cadence = try await setup.latestCadence()
        #expect(cadence == Cadence.defaultShort)
    }

    @Test("No active meso/watch keeps all-clear cadence long")
    func noActiveHazards_keepsLongCadenceForAllClear() async throws {
        let setup = try await makeSystem(
            activeMesos: [],
            activeWatches: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false, watchNotificationsEnabled: false)
        )
        _ = await setup.orchestrator.run()

        let cadence = try await setup.latestCadence()
        #expect(cadence == Cadence.defaultLong)
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
        activeWatches: [WatchRowDTO],
        refreshedLocation: CLLocationCoordinate2D? = nil,
        refreshSucceeds: Bool = false,
        cachedSnapshotTimestamp: Date = Date(),
        settings: NotificationSettings
    ) async throws -> SystemUnderTest {
        let container = try await MainActor.run { try TestStore.container(for: [BgRunSnapshot.self]) }
        try await MainActor.run { try TestStore.reset(BgRunSnapshot.self, in: container) }

        let healthStore = BgHealthStore(modelContainer: container)
        let spc = FakeSpcProvider(activeMesos: activeMesos)
        let watchProvider = FakeWatchProvider(activeWatches: activeWatches)
        let locationProvider = LocationProvider(geocoder: ConstantGeocoder(summary: "Norman, OK"))
        await locationProvider.send(update: .init(
            coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
            timestamp: cachedSnapshotTimestamp,
            accuracy: 10
        ))

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
        let watchEngine = WatchEngine(
            rule: NoopWatchRule(),
            gate: AllowAllGate(),
            composer: NoopComposer(),
            sender: NoopSender(),
            nws: watchProvider
        )

        let orchestrator = BackgroundOrchestrator(
            spcProvider: spc,
            arcusProvider: watchProvider,
            locationProvider: locationProvider,
            refreshCurrentLocation: { _ in
                guard refreshSucceeds, let refreshedLocation else { return false }
                await locationProvider.send(update: .init(
                    coordinates: refreshedLocation,
                    timestamp: Date(),
                    accuracy: 10,
                    forceAcceptance: true
                ))
                return true
            },
            policy: RefreshPolicy(),
            engine: morningEngine,
            mesoEngine: mesoEngine,
            watchEngine: watchEngine,
            health: healthStore,
            cadence: CadencePolicy(),
            notificationSettingsProvider: StaticSettingsProvider(settings: settings)
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

    static func makeWatch() -> WatchRowDTO {
        let now = Date()
        return WatchRowDTO(
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
            areaSummary: "Central Oklahoma"
        )
    }
}

private actor FakeSpcProvider: SpcSyncing, SpcRiskQuerying, SpcOutlookQuerying {
    private var recordedPoints: [CLLocationCoordinate2D] = []

    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> SkyAware.FireRiskLevel {
        recordedPoints.append(point)
        return .clear
    }
    
    private let activeMesos: [MdDTO]

    init(activeMesos: [MdDTO]) {
        self.activeMesos = activeMesos
    }

    func sync() async {}
    func syncMapProducts() async {}
    func syncTextProducts() async {}
    func syncConvectiveOutlooks() async {}
    func syncMesoscaleDiscussions() async {}

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
}

private actor FakeWatchProvider: ArcusAlertSyncing, ArcusAlertQuerying, NwsRiskQuerying {
    private let activeWatches: [WatchRowDTO]

    init(activeWatches: [WatchRowDTO]) {
        self.activeWatches = activeWatches
    }

    func sync(h3Cell: Int64?) async {}

    func getActiveWatches() async throws -> [WatchRowDTO] {
        activeWatches
    }

    func getActiveWatches(for point: CLLocationCoordinate2D) async throws -> [WatchRowDTO] {
        activeWatches
    }
}

private struct ConstantGeocoder: LocationGeocoding {
    let summary: String

    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        summary
    }
}

private struct StaticSettingsProvider: NotificationSettingsProviding {
    let settings: NotificationSettings

    func current() async -> NotificationSettings {
        settings
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

private struct NoopWatchRule: WatchNotificationRuleEvaluating {
    func evaluate(_ ctx: WatchContext) -> NotificationEvent? {
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
    func send(title: String, body: String, subtitle: String, id: String) async {}
}
