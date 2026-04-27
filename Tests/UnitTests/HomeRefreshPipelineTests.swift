import CoreLocation
import Foundation
import OSLog
import Testing
@testable import SkyAware

@Suite("Home Refresh Pipeline")
@MainActor
struct HomeRefreshPipelineTests {
    @Test("scene active submits foreground activate to the unified queue")
    func sceneActive_submitsForegroundActivate() async throws {
        let context = makeContext()
        let coordinator = RecordingHomeIngestionCoordinator()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()

        await pipeline.handleScenePhaseChange(
            .active,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        let requests = await coordinator.requests()
        #expect(requests.count == 2)
        #expect(requests[0].trigger == .foregroundPrime)
        #expect(requests[0].locationContext == nil)
        #expect(requests[1].trigger == .foregroundActivate)
        #expect(requests[1].locationContext == nil)
    }

    @Test("context change forwards the current resolved context to the unified queue")
    func contextChanged_submitsExplicitLocationContext() async throws {
        let context = makeContext()
        let coordinator = RecordingHomeIngestionCoordinator()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()

        await pipeline.enqueueRefresh(
            .contextChanged,
            environment: makeEnvironment(
                coordinator: coordinator,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        let requests = await coordinator.requests()
        #expect(requests.count == 2)
        #expect(requests[0].trigger == .foregroundPrime)
        #expect(requests[0].locationContext == context)
        #expect(requests[1].trigger == .foregroundLocationChange)
        #expect(requests[1].locationContext == context)
    }

    @Test("initial context publication during startup does not queue a second refresh")
    func startupContextPublication_doesNotQueueFollowUpRefresh() async throws {
        let context = makeContext()
        let gate = AsyncGate()
        let snapshot = HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .hail(probability: 0.30),
            fireRisk: .elevated,
            outlooks: sampleOutlooks(),
            latestOutlook: sampleOutlooks().first
        )
        let coordinator = RecordingHomeIngestionCoordinator(snapshot: snapshot, runGate: gate)
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let pipeline = HomeRefreshPipeline()
        let environment = makeEnvironment(
            coordinator: coordinator,
            locationSession: locationSession
        )

        Task {
            await pipeline.handleScenePhaseChange(.active, environment: environment)
        }

        let requestStarted = await waitUntil {
            await coordinator.requestCount() == 1
        }
        #expect(requestStarted)

        await pipeline.handleContextRefreshKeyChange(
            context.refreshKey,
            scenePhase: .active,
            environment: environment
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(await coordinator.requestCount() == 1)

        await gate.open()
        await pipeline.waitForIdle()

        #expect(await coordinator.requestCount() == 2)
    }

    @Test("force refresh waits for unified queue completion when loading is shown")
    func forceRefresh_waitsUntilCoordinatorCompletes() async {
        let gate = AsyncGate()
        let coordinator = RecordingHomeIngestionCoordinator(runGate: gate)
        let locationSession = FakeLocationSession(currentContext: makeContext(), preparedContext: makeContext())
        let pipeline = HomeRefreshPipeline()
        let completion = CompletionFlag()

        let refreshTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(
                showsLoading: true,
                environment: makeEnvironment(
                    coordinator: coordinator,
                    locationSession: locationSession
                )
            )
            await completion.markFinished()
        }

        let requestStarted = await waitUntil {
            await coordinator.requestCount() == 1
        }
        #expect(requestStarted)
        #expect(pipeline.resolutionState.isRefreshing)
        #expect(await completion.isFinished() == false)

        await gate.open()
        await refreshTask.value

        #expect(await completion.isFinished())
        #expect(pipeline.resolutionState.isRefreshing == false)
    }

    @Test("timer refresh keeps sync work on the hot-alert lane")
    func timerRefresh_syncsHotFeedsOnly() async {
        let context = makeContext()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: nil)
        let spc = FakeSpcProvider(outlooks: sampleOutlooks())
        let watches = FakeWatchProvider()
        let weather = FakeWeatherClient()
        let pipeline = HomeRefreshPipeline()

        await pipeline.enqueueRefresh(
            .timer,
            environment: makeEnvironment(
                spc: spc,
                watches: watches,
                weather: weather,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        #expect(locationSession.prepareCalls.isEmpty)
        #expect(await spc.syncMesoscaleDiscussionsCount() == 1)
        #expect(await watches.syncCount() == 1)
        #expect(await spc.syncMapProductsCount() == 0)
        #expect(await spc.syncConvectiveOutlooksCount() == 0)
        #expect(await weather.callCount() == 0)
    }

    @Test("scene active refresh persists projection slices through the unified flow")
    func sceneActiveRefresh_persistsProjectionSlices() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let weatherValue = sampleWeather()
        let meso = MD.sampleDiscussionDTOs[1]
        let watch = Watch.sampleWatchRows[1]
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(activeMesos: [meso], outlooks: sampleOutlooks())
        let watches = FakeWatchProvider(activeWatches: [watch])
        let weather = FakeWeatherClient(weather: weatherValue)
        let pipeline = HomeRefreshPipeline()

        await pipeline.handleScenePhaseChange(
            .active,
            environment: makeEnvironment(
                spc: spc,
                watches: watches,
                weather: weather,
                locationSession: locationSession,
                homeProjectionStore: projectionStore
            )
        )
        await pipeline.waitForIdle()

        let projection = try await projectionStore.projection(for: context)
        let stored = try #require(projection)

        #expect(stored.weather == weatherValue)
        #expect(stored.stormRisk == .enhanced)
        #expect(stored.severeRisk == .hail(probability: 0.30))
        #expect(stored.fireRisk == .elevated)
        #expect(stored.activeMesos == [meso])
        #expect(stored.activeAlerts == [watch])
    }

    @Test("scene active refresh persists empty alert slices for the resolved context")
    func sceneActiveRefresh_persistsEmptyAlertSlices() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(outlooks: sampleOutlooks())
        let watches = FakeWatchProvider(activeWatches: [])
        let weather = FakeWeatherClient()
        let pipeline = HomeRefreshPipeline()

        await pipeline.handleScenePhaseChange(
            .active,
            environment: makeEnvironment(
                spc: spc,
                watches: watches,
                weather: weather,
                locationSession: locationSession,
                homeProjectionStore: projectionStore
            )
        )
        await pipeline.waitForIdle()

        let projection = try #require(await projectionStore.projection(for: context))
//        #expect(projection.activeMesos.isEmpty)
        #expect(projection.activeAlerts.isEmpty)
        #expect(projection.lastHotAlertsLoadAt != nil)
        #expect(pipeline.lastResolvedLocationScopedRefreshKey == context.refreshKey)
    }

    @Test("failed location-scoped reads keep the existing cached projection without marking the context resolved")
    func locationScopedReadFailure_preservesExistingProjection() async throws {
        let container = try TestStore.container(for: [HomeProjection.self])
        let projectionStore = HomeProjectionStore(modelContainer: container)
        let context = makeContext()
        let weatherValue = sampleWeather()
        let originalWatch = Watch.sampleWatchRows[0]
        let originalMeso = MD.sampleDiscussionDTOs[0]

        _ = try await projectionStore.updateWeather(
            weatherValue,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 200)
        )
        _ = try await projectionStore.updateSlowProducts(
            stormRisk: .slight,
            severeRisk: .wind(probability: 0.15),
            fireRisk: .critical,
            for: context,
            loadedAt: Date(timeIntervalSince1970: 210)
        )
        _ = try await projectionStore.updateHotAlerts(
            watches: [originalWatch],
            mesos: [originalMeso],
            for: context,
            loadedAt: Date(timeIntervalSince1970: 220)
        )

        let pipeline = HomeRefreshPipeline(
            initialStormRisk: .slight,
            initialSevereRisk: .wind(probability: 0.15),
            initialFireRisk: .critical,
            initialMesos: [originalMeso],
            initialWatches: [originalWatch]
        )
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(outlooks: sampleOutlooks(), locationReadError: TestFailure.failedRead)
        let watches = FakeWatchProvider(activeWatches: [Watch.sampleWatchRows[1]])
        let weather = FakeWeatherClient()

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                spc: spc,
                watches: watches,
                weather: weather,
                locationSession: locationSession,
                homeProjectionStore: projectionStore
            )
        )

        let projection = try await projectionStore.projection(for: context)
        let stored = try #require(projection)

        #expect(stored.weather == weatherValue)
        #expect(stored.stormRisk == .slight)
        #expect(stored.severeRisk == .wind(probability: 0.15))
        #expect(stored.fireRisk == .critical)
        #expect(stored.activeAlerts == [originalWatch])
        #expect(stored.activeMesos == [originalMeso])
        #expect(pipeline.stormRisk == .slight)
        #expect(pipeline.severeRisk == .wind(probability: 0.15))
        #expect(pipeline.fireRisk == .critical)
        #expect(pipeline.mesos == [originalMeso])
        #expect(pipeline.watches == [originalWatch])
        #expect(pipeline.lastResolvedLocationScopedRefreshKey == nil)
    }

    @Test("refresh failures preserve the previously resolved location scope key")
    func refreshFailure_preservesPreviousResolvedLocationScopeKey() async {
        let originalContext = makeContext(timestamp: 100)
        let changedContext = makeContext(timestamp: 200)
        let successSnapshot = HomeSnapshot(
            locationSnapshot: originalContext.snapshot,
            refreshKey: originalContext.refreshKey,
            stormRisk: .enhanced,
            severeRisk: .hail(probability: 0.30),
            fireRisk: .elevated,
            outlooks: sampleOutlooks(),
            latestOutlook: sampleOutlooks().first
        )
        let coordinator = RecordingHomeIngestionCoordinator(
            results: [
                .success(successSnapshot),
                .failure(TestFailure.failedRead)
            ]
        )
        let locationSession = FakeLocationSession(currentContext: originalContext, preparedContext: originalContext)
        let pipeline = HomeRefreshPipeline()
        let environment = makeEnvironment(coordinator: coordinator, locationSession: locationSession)

        await pipeline.handleScenePhaseChange(.active, environment: environment)
        await pipeline.waitForIdle()

        #expect(pipeline.lastResolvedLocationScopedRefreshKey == originalContext.refreshKey)

        locationSession.currentContext = changedContext
        await pipeline.enqueueRefresh(.contextChanged, environment: environment)
        await pipeline.waitForIdle()

        #expect(pipeline.lastResolvedLocationScopedRefreshKey == originalContext.refreshKey)
    }

    @Test("manual outlook refresh only touches outlook sync and query paths")
    func refreshOutlooksManually_onlyTouchesOutlookPaths() async {
        let coordinator = RecordingHomeIngestionCoordinator()
        let spc = FakeSpcProvider(outlooks: sampleOutlooks())
        let locationSession = FakeLocationSession(currentContext: makeContext(), preparedContext: makeContext())
        let pipeline = HomeRefreshPipeline()

        await pipeline.refreshOutlooksManually(
            environment: makeEnvironment(
                spc: spc,
                coordinator: coordinator,
                locationSession: locationSession
            )
        )

        #expect(await spc.syncConvectiveOutlooksCount() == 1)
        #expect(await spc.outlookQueryCount() == 1)
        #expect(await spc.syncMapProductsCount() == 0)
        #expect(await spc.syncMesoscaleDiscussionsCount() == 0)
        #expect(await coordinator.requestCount() == 0)
        #expect(pipeline.outlooks.map(\.title) == sampleOutlooks().map(\.title))
        #expect(pipeline.outlook?.title == "Day 2 Convective Outlook")
    }

    private func makeEnvironment(
        spc: FakeSpcProvider = FakeSpcProvider(),
        watches: FakeWatchProvider = FakeWatchProvider(),
        weather: FakeWeatherClient = FakeWeatherClient(),
        coordinator: (any HomeIngestionCoordinating)? = nil,
        locationSession: FakeLocationSession,
        homeProjectionStore: HomeProjectionStore? = nil
    ) -> HomeRefreshPipeline.Environment {
        .init(
            logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
            sync: spc,
            outlooks: spc,
            coordinator: coordinator ?? makeCoordinator(
                spc: spc,
                watches: watches,
                weather: weather,
                locationSession: locationSession,
                homeProjectionStore: homeProjectionStore
            ),
            locationSession: locationSession
        )
    }

    private func makeCoordinator(
        spc: FakeSpcProvider,
        watches: FakeWatchProvider,
        weather: FakeWeatherClient,
        locationSession: FakeLocationSession,
        homeProjectionStore: HomeProjectionStore?
    ) -> any HomeIngestionCoordinating {
        let snapshotStore = HomeSnapshotStore(
            spcRisk: spc,
            spcOutlook: spc,
            arcusAlerts: watches
        )
        let executor = HomeIngestionExecutor(
            environment: .init(
                logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
                spcSync: spc,
                arcusAlertSync: watches,
                weatherClient: weather,
                locationSession: locationSession,
                snapshotStore: snapshotStore,
                projectionStore: homeProjectionStore
            )
        )
        return HomeIngestionCoordinator(executor: executor)
    }

    private func makeContext(timestamp: TimeInterval = 100) -> LocationContext {
        let snapshot = LocationSnapshot(
            coordinates: .init(latitude: 39.75, longitude: -104.44),
            timestamp: Date(timeIntervalSince1970: timestamp),
            accuracy: 25,
            placemarkSummary: "Bennett, CO",
            h3Cell: 123_456
        )
        let grid = GridPointSnapshot(
            nwsId: "BOU/10,20",
            latitude: snapshot.coordinates.latitude,
            longitude: snapshot.coordinates.longitude,
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

    private func sampleWeather() -> SummaryWeather {
        SummaryWeather(
            temperature: .init(value: 72, unit: .fahrenheit),
            symbolName: "sun.max.fill",
            conditionText: "Clear",
            asOf: Date(timeIntervalSince1970: 200),
            dewPoint: .init(value: 54, unit: .fahrenheit),
            humidity: 0.45,
            windSpeed: .init(value: 15, unit: .milesPerHour),
            windGust: .init(value: 24, unit: .milesPerHour),
            windDirection: "NW",
            pressure: .init(value: 29.92, unit: .inchesOfMercury),
            pressureTrend: "steady"
        )
    }

    private func sampleOutlooks() -> [ConvectiveOutlookDTO] {
        [
            ConvectiveOutlookDTO(
                title: "Day 1 Convective Outlook",
                link: URL(string: "https://example.com/day1")!,
                published: Date(timeIntervalSince1970: 100),
                summary: "Earlier outlook",
                fullText: "Earlier full text",
                day: 1,
                riskLevel: "SLGT",
                issued: Date(timeIntervalSince1970: 100),
                validUntil: Date(timeIntervalSince1970: 500)
            ),
            ConvectiveOutlookDTO(
                title: "Day 2 Convective Outlook",
                link: URL(string: "https://example.com/day2")!,
                published: Date(timeIntervalSince1970: 200),
                summary: "Latest outlook",
                fullText: "Latest full text",
                day: 2,
                riskLevel: "ENH",
                issued: Date(timeIntervalSince1970: 200),
                validUntil: Date(timeIntervalSince1970: 600)
            )
        ]
    }
}

private actor RecordingHomeIngestionCoordinator: HomeIngestionCoordinating {
    private let snapshot: HomeSnapshot
    private var results: [Result<HomeSnapshot, Error>]
    private let runGate: AsyncGate?
    private var submittedRequests: [HomeIngestionRequest] = []

    init(
        snapshot: HomeSnapshot = .empty,
        results: [Result<HomeSnapshot, Error>] = [],
        runGate: AsyncGate? = nil
    ) {
        self.snapshot = snapshot
        self.results = results
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
        if results.isEmpty == false {
            let result = results.removeFirst()
            return try result.get()
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

private enum TestFailure: Error {
    case failedRead
}

@MainActor
private final class FakeLocationSession: HomeLocationContextPreparing, HomeContextPreparing {
    struct PrepareCall: Equatable {
        let requiresFreshLocation: Bool
        let showsAuthorizationPrompt: Bool
    }

    var currentContext: LocationContext?
    var preparedContext: LocationContext?
    var prepareCalls: [PrepareCall] = []

    private let prepareGate: AsyncGate?

    init(
        currentContext: LocationContext?,
        preparedContext: LocationContext?,
        prepareGate: AsyncGate? = nil
    ) {
        self.currentContext = currentContext
        self.preparedContext = preparedContext
        self.prepareGate = prepareGate
    }

    func prepareCurrentLocationContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async -> LocationContext? {
        prepareCalls.append(
            .init(
                requiresFreshLocation: requiresFreshLocation,
                showsAuthorizationPrompt: showsAuthorizationPrompt
            )
        )
        if let prepareGate {
            await prepareGate.wait()
        }
        return preparedContext
    }

    func currentPreparedContext() async -> LocationContext? {
        currentContext
    }
}

private actor FakeWeatherClient: HomeWeatherQuerying {
    private let weather: SummaryWeather?
    private var calls: [CLLocation] = []

    init(weather: SummaryWeather? = nil) {
        self.weather = weather
    }

    func currentWeather(for location: CLLocation) async -> SummaryWeather? {
        calls.append(location)
        return weather
    }

    func callCount() -> Int {
        calls.count
    }
}

private actor FakeSpcProvider: SpcSyncing, SpcRiskQuerying, SpcOutlookQuerying {
    private let activeMesos: [MdDTO]
    private let outlookValues: [ConvectiveOutlookDTO]
    private let locationReadError: Error?
    private let syncMesoscaleGate: AsyncGate?

    private var syncMapProductsCalls = 0
    private var syncConvectiveOutlooksCalls = 0
    private var syncMesoscaleCalls = 0
    private var stormRiskQueries = 0
    private var severeRiskQueries = 0
    private var fireRiskQueries = 0
    private var activeMesosQueries = 0
    private var outlookQueries = 0

    init(
        activeMesos: [MdDTO] = [MD.sampleDiscussionDTOs[0]],
        outlooks: [ConvectiveOutlookDTO] = [],
        locationReadError: Error? = nil,
        syncMesoscaleGate: AsyncGate? = nil
    ) {
        self.activeMesos = activeMesos
        self.outlookValues = outlooks
        self.locationReadError = locationReadError
        self.syncMesoscaleGate = syncMesoscaleGate
    }

    func sync() async {}

    func syncMapProducts() async {
        syncMapProductsCalls += 1
    }

    func syncTextProducts() async {}

    func syncConvectiveOutlooks() async {
        syncConvectiveOutlooksCalls += 1
    }

    func syncMesoscaleDiscussions() async {
        syncMesoscaleCalls += 1
        if let syncMesoscaleGate {
            await syncMesoscaleGate.wait()
        }
    }

    func getStormRisk(for point: CLLocationCoordinate2D) async throws -> StormRiskLevel {
        stormRiskQueries += 1
        if let locationReadError {
            throw locationReadError
        }
        return .enhanced
    }

    func getSevereRisk(for point: CLLocationCoordinate2D) async throws -> SevereWeatherThreat {
        severeRiskQueries += 1
        if let locationReadError {
            throw locationReadError
        }
        return .hail(probability: 0.30)
    }

    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] {
        activeMesosQueries += 1
        if let locationReadError {
            throw locationReadError
        }
        return activeMesos
    }

    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> FireRiskLevel {
        fireRiskQueries += 1
        if let locationReadError {
            throw locationReadError
        }
        return .elevated
    }

    func getLatestConvectiveOutlook() async throws -> ConvectiveOutlookDTO? {
        outlookQueries += 1
        return outlookValues.max(by: { $0.published < $1.published })
    }

    func getConvectiveOutlooks() async throws -> [ConvectiveOutlookDTO] {
        outlookQueries += 1
        return outlookValues
    }

    func syncMapProductsCount() -> Int { syncMapProductsCalls }
    func syncConvectiveOutlooksCount() -> Int { syncConvectiveOutlooksCalls }
    func syncMesoscaleDiscussionsCount() -> Int { syncMesoscaleCalls }
    func stormRiskQueryCount() -> Int { stormRiskQueries }
    func severeRiskQueryCount() -> Int { severeRiskQueries }
    func fireRiskQueryCount() -> Int { fireRiskQueries }
    func activeMesosQueryCount() -> Int { activeMesosQueries }
    func outlookQueryCount() -> Int { outlookQueries }
}

private actor FakeWatchProvider: ArcusAlertSyncing, ArcusAlertQuerying {
    private let activeWatches: [WatchRowDTO]
    private var syncCalls = 0
    private var queryCalls = 0

    init(activeWatches: [WatchRowDTO] = [Watch.sampleWatchRows[0]]) {
        self.activeWatches = activeWatches
    }

    func sync(context: LocationContext) async {
        syncCalls += 1
    }

    func syncRemoteAlert(id: String, revisionSent: Date?) async {
        syncCalls += 1
    }

    func getActiveWatches(context: LocationContext) async throws -> [WatchRowDTO] {
        queryCalls += 1
        return activeWatches
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        []
    }

    func getWatch(id: String) async throws -> WatchRowDTO? {
        activeWatches.first(where: { $0.id == id })
    }

    func syncCount() -> Int { syncCalls }
    func queryCount() -> Int { queryCalls }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @escaping @MainActor () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}
