import CoreLocation
import Foundation
import OSLog
import Testing
@testable import SkyAware

@Suite("Home Refresh Pipeline")
@MainActor
struct HomeRefreshPipelineTests {
    @Test("scene active absorbs a follow-up context change while work is in flight")
    func sceneActive_absorbsContextChangedWhileRefreshing() async {
        let gate = AsyncGate()
        let context = makeContext()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context, prepareGate: gate)
        let spc = FakeSpcProvider()
        let watches = FakeWatchProvider()
        let weather = FakeWeatherClient()
        let pipeline = HomeRefreshPipeline()
        let environment = makeEnvironment(
            spc: spc,
            watches: watches,
            weather: weather,
            locationSession: locationSession
        )

        let sceneActiveTask = Task { @MainActor in
            await pipeline.enqueueRefresh(.sceneActive, environment: environment)
        }

        let prepareStarted = await waitUntil {
            locationSession.prepareCalls.count == 1
        }
        #expect(prepareStarted)

        await pipeline.enqueueRefresh(.contextChanged, environment: environment)
        await gate.open()
        await sceneActiveTask.value
        await pipeline.waitForIdle()

        #expect(locationSession.prepareCalls.count == 1)
        #expect(await spc.syncMapProductsCount() == 1)
        #expect(await spc.syncConvectiveOutlooksCount() == 1)
        #expect(await spc.syncMesoscaleDiscussionsCount() == 1)
        #expect(await spc.stormRiskQueryCount() == 1)
        #expect(await spc.severeRiskQueryCount() == 1)
        #expect(await spc.fireRiskQueryCount() == 1)
        #expect(await spc.activeMesosQueryCount() == 1)
        #expect(await watches.syncCount() == 1)
        #expect(await watches.queryCount() == 1)
    }

    @Test("timer refresh only syncs hot feeds when a current context already exists")
    func timerRefresh_usesCurrentContextAndSkipsSlowFeedsAndWeather() async {
        let context = makeContext()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: nil)
        let spc = FakeSpcProvider()
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
        #expect(await spc.activeMesosQueryCount() == 1)
        #expect(await watches.queryCount() == 1)
        #expect(await spc.syncMapProductsCount() == 0)
        #expect(await spc.syncConvectiveOutlooksCount() == 0)
        #expect(await spc.outlookQueryCount() == 0)
        #expect(await spc.stormRiskQueryCount() == 0)
        #expect(await spc.severeRiskQueryCount() == 0)
        #expect(await spc.fireRiskQueryCount() == 0)
        #expect(await weather.callCount() == 0)
    }

    @Test("timer refresh falls back to preparing context without prompting or requiring fresh location")
    func timerRefresh_preparesContextWhenCurrentContextMissing() async {
        let context = makeContext()
        let locationSession = FakeLocationSession(currentContext: nil, preparedContext: context)
        let spc = FakeSpcProvider()
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

        #expect(locationSession.prepareCalls.count == 1)
        #expect(locationSession.prepareCalls[0] == .init(requiresFreshLocation: false, showsAuthorizationPrompt: false))
        #expect(await spc.syncMesoscaleDiscussionsCount() == 1)
        #expect(await weather.callCount() == 0)
    }

    @Test("force refresh waits for the full refresh to finish when loading is shown")
    func forceRefresh_waitsUntilWorkCompletes() async {
        let gate = AsyncGate()
        let context = makeContext()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context, prepareGate: gate)
        let spc = FakeSpcProvider()
        let watches = FakeWatchProvider()
        let weather = FakeWeatherClient()
        let pipeline = HomeRefreshPipeline()
        let environment = makeEnvironment(
            spc: spc,
            watches: watches,
            weather: weather,
            locationSession: locationSession
        )
        let completion = CompletionFlag()

        let refreshTask = Task { @MainActor in
            await pipeline.forceRefreshCurrentContext(showsLoading: true, environment: environment)
            await completion.markFinished()
        }

        let prepareStarted = await waitUntil {
            locationSession.prepareCalls.count == 1
        }
        #expect(prepareStarted)
        #expect(pipeline.resolutionState.isRefreshing)
        #expect(await completion.isFinished() == false)

        await gate.open()
        await refreshTask.value

        #expect(await completion.isFinished())
        #expect(pipeline.resolutionState.isRefreshing == false)
        #expect(locationSession.prepareCalls.count == 1)
    }

    @Test("manual refresh supersedes a pending timer refresh")
    func manualRefresh_supersedesPendingTimerRefresh() async {
        let gate = AsyncGate()
        let currentContext = makeContext()
        let preparedContext = makeContext(timestamp: 200)
        let locationSession = FakeLocationSession(currentContext: currentContext, preparedContext: preparedContext)
        let spc = FakeSpcProvider(syncMesoscaleGate: gate)
        let watches = FakeWatchProvider()
        let weather = FakeWeatherClient(weather: sampleWeather())
        let pipeline = HomeRefreshPipeline()
        let environment = makeEnvironment(
            spc: spc,
            watches: watches,
            weather: weather,
            locationSession: locationSession
        )

        let timerTask = Task { @MainActor in
            await pipeline.enqueueRefresh(.timer, environment: environment)
        }

        let timerStarted = await waitUntil {
            await spc.syncMesoscaleDiscussionsCount() == 1
        }
        #expect(timerStarted)

        await pipeline.enqueueRefresh(.manual, environment: environment)
        await gate.open()
        await timerTask.value
        await pipeline.waitForIdle()

        #expect(locationSession.prepareCalls.count == 1)
        #expect(locationSession.prepareCalls[0] == .init(requiresFreshLocation: true, showsAuthorizationPrompt: false))
        #expect(await spc.syncMesoscaleDiscussionsCount() == 2)
        #expect(await watches.syncCount() == 2)
        #expect(await spc.syncMapProductsCount() == 1)
        #expect(await spc.syncConvectiveOutlooksCount() == 1)
        #expect(await spc.outlookQueryCount() == 1)
        #expect(await spc.stormRiskQueryCount() == 1)
        #expect(await spc.severeRiskQueryCount() == 1)
        #expect(await spc.fireRiskQueryCount() == 1)
        #expect(await weather.callCount() == 1)
        #expect(pipeline.summaryWeather == sampleWeather())
    }

    @Test("failed location-scoped reads preserve existing displayed state")
    func locationScopedReadFailure_preservesExistingState() async {
        let initialMesos = [MD.sampleDiscussionDTOs[0]]
        let initialWatches = [Watch.sampleWatchRows[0]]
        let pipeline = HomeRefreshPipeline(
            initialStormRisk: .slight,
            initialSevereRisk: .wind(probability: 0.15),
            initialFireRisk: .critical,
            initialMesos: initialMesos,
            initialWatches: initialWatches
        )
        let context = makeContext()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider(locationReadError: TestFailure.failedRead)
        let watches = FakeWatchProvider(activeWatches: [Watch.sampleWatchRows[1]])
        let weather = FakeWeatherClient()

        await pipeline.forceRefreshCurrentContext(
            showsLoading: true,
            environment: makeEnvironment(
                spc: spc,
                watches: watches,
                weather: weather,
                locationSession: locationSession
            )
        )

        #expect(pipeline.stormRisk == .slight)
        #expect(pipeline.severeRisk == .wind(probability: 0.15))
        #expect(pipeline.fireRisk == .critical)
        #expect(pipeline.mesos == initialMesos)
        #expect(pipeline.watches == initialWatches)
    }

    @Test("manual outlook refresh only touches outlook sync and query paths")
    func refreshOutlooksManually_onlyTouchesOutlookPaths() async {
        let spc = FakeSpcProvider(outlooks: sampleOutlooks())
        let watches = FakeWatchProvider()
        let weather = FakeWeatherClient()
        let locationSession = FakeLocationSession(currentContext: makeContext(), preparedContext: makeContext())
        let pipeline = HomeRefreshPipeline()

        await pipeline.refreshOutlooksManually(
            environment: makeEnvironment(
                spc: spc,
                watches: watches,
                weather: weather,
                locationSession: locationSession
            )
        )

        #expect(await spc.syncConvectiveOutlooksCount() == 1)
        #expect(await spc.outlookQueryCount() == 1)
        #expect(await spc.syncMapProductsCount() == 0)
        #expect(await spc.syncMesoscaleDiscussionsCount() == 0)
        #expect(await spc.stormRiskQueryCount() == 0)
        #expect(await spc.severeRiskQueryCount() == 0)
        #expect(await spc.fireRiskQueryCount() == 0)
        #expect(await watches.syncCount() == 0)
        #expect(await watches.queryCount() == 0)
        #expect(locationSession.prepareCalls.isEmpty)
        #expect(await weather.callCount() == 0)
        #expect(pipeline.resolutionState.isRefreshing == false)
        #expect(pipeline.outlooks.map(\.title) == sampleOutlooks().map(\.title))
        #expect(pipeline.outlooks.map(\.published) == sampleOutlooks().map(\.published))
        #expect(pipeline.outlook?.title == "Day 2 Convective Outlook")
    }

    @Test("scene active refresh updates summary weather from the weather client")
    func sceneActiveRefresh_updatesSummaryWeather() async {
        let context = makeContext()
        let weatherValue = sampleWeather()
        let locationSession = FakeLocationSession(currentContext: context, preparedContext: context)
        let spc = FakeSpcProvider()
        let watches = FakeWatchProvider()
        let weather = FakeWeatherClient(weather: weatherValue)
        let pipeline = HomeRefreshPipeline()

        await pipeline.enqueueRefresh(
            .sceneActive,
            environment: makeEnvironment(
                spc: spc,
                watches: watches,
                weather: weather,
                locationSession: locationSession
            )
        )
        await pipeline.waitForIdle()

        #expect(await weather.callCount() == 1)
        #expect(pipeline.summaryWeather == weatherValue)
    }

    private func makeEnvironment(
        spc: FakeSpcProvider,
        watches: FakeWatchProvider,
        weather: FakeWeatherClient,
        locationSession: FakeLocationSession
    ) -> HomeRefreshPipeline.Environment {
        .init(
            logger: Logger(subsystem: "SkyAwareTests", category: "HomeRefreshPipelineTests"),
            sync: spc,
            spcRisk: spc,
            outlooks: spc,
            arcusAlerts: watches,
            arcusAlertSync: watches,
            weatherClient: weather,
            locationSession: locationSession
        )
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

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
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
private final class FakeLocationSession: HomeLocationContextPreparing {
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
        return .hail(probability: 0.30)
    }

    func getActiveMesos(at time: Date, for point: CLLocationCoordinate2D) async throws -> [MdDTO] {
        activeMesosQueries += 1
        return activeMesos
    }

    func getFireRisk(for point: CLLocationCoordinate2D) async throws -> FireRiskLevel {
        fireRiskQueries += 1
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

    func getActiveWatches(context: LocationContext) async throws -> [WatchRowDTO] {
        queryCalls += 1
        return activeWatches
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
