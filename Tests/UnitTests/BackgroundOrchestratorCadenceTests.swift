import Foundation
import Testing
import SwiftData
import CoreLocation
import OSLog
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
            activeWatches: [],
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
            activeWatches: [],
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
            activeWatches: [],
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

    @Test("Background refresh waits for unified ingestion before finishing")
    func backgroundRefresh_waitsForUnifiedIngestionBeforeFinishing() async throws {
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
            health: BgHealthStore(modelContainer: container),
            cadence: CadencePolicy(),
            notificationSettingsProvider: StaticSettingsProvider(
                settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
            )
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

        let request = try #require(await coordinator.requests().first)
        #expect(request.trigger == .backgroundRefresh)

        await gate.open()
        await runTask.value

        #expect(await completion.isFinished())
    }

    @Test("Active meso tightens cadence to short")
    func activeMeso_tightensCadenceToShort() async throws {
        let setup = try await makeSystem(
            activeMesos: [Self.makeMeso()],
            activeWatches: [],
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
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
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
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
            settings: .init(morningSummariesEnabled: false, mesoNotificationsEnabled: false)
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
            arcusAlerts: watchProvider
        )
        let coordinator = HomeIngestionCoordinator(
            executor: HomeIngestionExecutor(
                environment: .init(
                    logger: Logger(subsystem: "SkyAwareTests", category: "BackgroundOrchestratorCadenceTests"),
                    spcSync: spc,
                    arcusAlertSync: watchProvider,
                    weatherClient: FakeWeatherClient(),
                    locationSession: locationSession,
                    snapshotStore: snapshotStore,
                    projectionStore: nil
                )
            )
        )

        let orchestrator = BackgroundOrchestrator(
            coordinator: coordinator,
            policy: RefreshPolicy(),
            engine: morningEngine,
            mesoEngine: mesoEngine,
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

private actor FakeWatchProvider: ArcusAlertSyncing, ArcusAlertQuerying {
    private let activeWatches: [WatchRowDTO]

    init(activeWatches: [WatchRowDTO]) {
        self.activeWatches = activeWatches
    }

    func sync(context: LocationContext) async {}

    func syncRemoteAlert(id: String, revisionSent: Date?) async {}

    func getActiveWatches(context: LocationContext) async throws -> [WatchRowDTO] {
        activeWatches
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        []
    }

    func getWatch(id: String) async throws -> WatchRowDTO? {
        activeWatches.first(where: { $0.id == id })
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
    func currentWeather(for location: CLLocation) async -> SummaryWeather? {
        nil
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
