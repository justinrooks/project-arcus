//
//  HomeRefreshPipeline.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI
import CoreLocation
import OSLog
import Observation

protocol HomeWeatherQuerying: Sendable {
    func currentWeather(for location: CLLocation) async -> SummaryWeather?
}

@MainActor
protocol HomeLocationContextPreparing: AnyObject {
    var currentContext: LocationContext? { get }

    func prepareCurrentLocationContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async -> LocationContext?
}

extension WeatherClient: HomeWeatherQuerying {}
extension LocationSession: HomeLocationContextPreparing {}

@MainActor
@Observable
final class HomeRefreshPipeline {
    struct Environment {
        let logger: Logger
        let sync: any SpcSyncing
        let spcRisk: any SpcRiskQuerying
        let outlooks: any SpcOutlookQuerying
        let arcusAlerts: any ArcusAlertQuerying
        let arcusAlertSync: any ArcusAlertSyncing
        let weatherClient: any HomeWeatherQuerying
        let locationSession: any HomeLocationContextPreparing
    }

    private let minimumForegroundRefreshInterval: TimeInterval
    private let minimumRefreshDistanceMeters: CLLocationDistance
    private let foregroundTimerInterval: Duration
    private let alertRefreshPolicy: AlertRefreshPolicy
    private let mapProductRefreshPolicy: MapProductRefreshPolicy
    private let outlookRefreshPolicy: OutlookRefreshPolicy
    private let weatherKitRefreshPolicy: WeatherKitRefreshPolicy

    private var environment: Environment?
    private var lastRefreshContext: RefreshContext?
    private var lastHotFeedSyncAt: Date?
    private var lastMapProductSyncAt: Date?
    private var lastOutlookSyncAt: Date?
    private var lastWeatherKitSyncAt: Date?
    private var activeRefreshTrigger: HomeView.RefreshTrigger?
    private var activeRefreshTask: Task<Void, Never>?
    private var pendingRefreshTrigger: HomeView.RefreshTrigger?
    private var foregroundTimerTask: Task<Void, Never>?

    var snap: LocationSnapshot?
    var summaryWeather: SummaryWeather?
    var stormRisk: StormRiskLevel?
    var severeRisk: SevereWeatherThreat?
    var fireRisk: FireRiskLevel?
    var mesos: [MdDTO]
    var watches: [WatchRowDTO]
    var outlooks: [ConvectiveOutlookDTO]
    var outlook: ConvectiveOutlookDTO?
    var loadingState = HomeView.LoadingOverlayState()

    init(
        initialSnap: LocationSnapshot? = nil,
        initialStormRisk: StormRiskLevel? = nil,
        initialSevereRisk: SevereWeatherThreat? = nil,
        initialFireRisk: FireRiskLevel? = nil,
        initialMesos: [MdDTO] = [],
        initialWatches: [WatchRowDTO] = [],
        initialOutlooks: [ConvectiveOutlookDTO] = [],
        initialOutlook: ConvectiveOutlookDTO? = nil,
        minimumForegroundRefreshInterval: TimeInterval = 3 * 60,
        minimumRefreshDistanceMeters: CLLocationDistance = 800,
        foregroundTimerInterval: Duration = .seconds(120),
        alertRefreshPolicy: AlertRefreshPolicy = AlertRefreshPolicy(),
        mapProductRefreshPolicy: MapProductRefreshPolicy = MapProductRefreshPolicy(),
        outlookRefreshPolicy: OutlookRefreshPolicy = OutlookRefreshPolicy(),
        weatherKitRefreshPolicy: WeatherKitRefreshPolicy = WeatherKitRefreshPolicy()
    ) {
        self.snap = initialSnap
        self.stormRisk = initialStormRisk
        self.severeRisk = initialSevereRisk
        self.fireRisk = initialFireRisk
        self.mesos = initialMesos
        self.watches = initialWatches
        self.outlooks = initialOutlooks
        self.outlook = initialOutlook
        self.minimumForegroundRefreshInterval = minimumForegroundRefreshInterval
        self.minimumRefreshDistanceMeters = minimumRefreshDistanceMeters
        self.foregroundTimerInterval = foregroundTimerInterval
        self.alertRefreshPolicy = alertRefreshPolicy
        self.mapProductRefreshPolicy = mapProductRefreshPolicy
        self.outlookRefreshPolicy = outlookRefreshPolicy
        self.weatherKitRefreshPolicy = weatherKitRefreshPolicy
    }

    func updateEnvironment(_ environment: Environment) {
        self.environment = environment
    }

    func resetLocationRefreshContext() {
        lastRefreshContext = nil
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase, environment: Environment) async {
        updateEnvironment(environment)

        if newPhase == .active {
            startForegroundTimerIfNeeded()
            await enqueueRefresh(.sceneActive)
            return
        }

        foregroundTimerTask?.cancel()
        foregroundTimerTask = nil
    }

    func forceRefreshCurrentContext(showsLoading: Bool, environment: Environment) async {
        updateEnvironment(environment)

        if showsLoading {
            await enqueueRefreshAndWait(.manual)
        } else {
            await enqueueRefresh(.manual)
        }
    }

    func refreshOutlooksManually(environment: Environment) async {
        updateEnvironment(environment)

        await withLoading(message: "Syncing outlooks...") {
            let now = Date()
            _ = self.markOutlookSyncIfNeeded(force: true, now: now)
            await HTTPExecutionMode.$current.withValue(.foreground) {
                await environment.sync.syncConvectiveOutlooks()
            }
            await self.refreshOutlooks(using: environment.outlooks)
        }
    }

    func enqueueRefresh(_ trigger: HomeView.RefreshTrigger, environment: Environment) async {
        updateEnvironment(environment)
        await enqueueRefresh(trigger)
    }

    func waitForIdle() async {
        while activeRefreshTask != nil || pendingRefreshTrigger != nil {
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func startForegroundTimerIfNeeded() {
        guard foregroundTimerTask == nil else { return }

        foregroundTimerTask = Task { @MainActor [weak self] in
            await self?.runForegroundTimerLoop()
        }
    }

    private func runForegroundTimerLoop() async {
        while Task.isCancelled == false {
            try? await Task.sleep(for: foregroundTimerInterval)
            if Task.isCancelled { return }
            await enqueueRefresh(.timer)
        }
    }

    private func enqueueRefresh(_ trigger: HomeView.RefreshTrigger) async {
        if let activeRefreshTrigger, activeRefreshTrigger.absorbs(trigger) {
            return
        }

        if activeRefreshTask != nil {
            pendingRefreshTrigger = pendingRefreshTrigger.map { HomeView.RefreshTrigger.merge($0, trigger) } ?? trigger
            return
        }

        startRefreshTask(for: trigger)
    }

    private func enqueueRefreshAndWait(_ trigger: HomeView.RefreshTrigger) async {
        await enqueueRefresh(trigger)
        while activeRefreshTask != nil || pendingRefreshTrigger != nil {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func startRefreshTask(for trigger: HomeView.RefreshTrigger) {
        activeRefreshTrigger = trigger
        activeRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runRefreshPipeline(trigger)
            self.activeRefreshTask = nil
            self.activeRefreshTrigger = nil

            if let pendingRefreshTrigger = self.pendingRefreshTrigger {
                self.pendingRefreshTrigger = nil
                self.startRefreshTask(for: pendingRefreshTrigger)
            }
        }
    }

    private func runRefreshPipeline(_ trigger: HomeView.RefreshTrigger) async {
        guard let environment else { return }

        let now = Date()
        let shouldSyncMapProducts = trigger.supportsSlowFeeds
            ? markMapProductSyncIfNeeded(force: trigger.bypassesThrottles, now: now)
            : false
        let shouldSyncOutlookNow = trigger.supportsSlowFeeds
            ? markOutlookSyncIfNeeded(force: trigger.bypassesThrottles, now: now)
            : false
        let shouldSyncWeatherKitNow = trigger.isHotFeedsOnly
            ? false
            : shouldSyncWeatherKit(force: trigger.bypassesThrottles, now: now)
        let shouldSyncHotFeeds = markHotFeedSyncIfNeeded(force: trigger.bypassesThrottles, now: now)

        if trigger.showsLoading {
            startRefresh(message: "Preparing location context...")
        }

        let slowSyncTask = Task {
            await syncSlowFeeds(
                shouldSyncMapProducts: shouldSyncMapProducts,
                shouldSyncOutlooks: shouldSyncOutlookNow,
                sync: environment.sync
            )
        }

        let context = await resolveContext(for: trigger, locationSession: environment.locationSession)

        if trigger.supportsSlowFeeds {
            if trigger.showsLoading {
                updateRefreshMessage("Syncing slower SPC feeds...")
            }
            await slowSyncTask.value
            await refreshOutlooks(using: environment.outlooks)
        } else {
            slowSyncTask.cancel()
        }

        guard let context else {
            environment.logger.notice("Skipping foreground ingest because no location context is available for trigger=\(String(describing: trigger), privacy: .public)")
            if trigger.showsLoading {
                endRefresh()
            }
            return
        }

        snap = context.snapshot

        if trigger.isHotFeedsOnly == false {
            let shouldProceed = shouldRefresh(for: context.snapshot, force: trigger.bypassesThrottles)
            guard shouldProceed else {
                environment.logger.debug("Skipping local reads because location-scoped refresh gate denied trigger=\(String(describing: trigger), privacy: .public)")
                if trigger.showsLoading {
                    endRefresh()
                }
                return
            }
        }

        if shouldSyncHotFeeds {
            if trigger.showsLoading {
                updateRefreshMessage("Syncing hot feeds...")
            }
            await HTTPExecutionMode.$current.withValue(.foreground) {
                await IngestionSupport.syncHotFeeds(
                    spcSync: environment.sync,
                    arcusSync: environment.arcusAlertSync,
                    context: context
                )
            }
        } else {
            environment.logger.debug("Skipping hot feed sync due to refresh throttle")
        }

        if trigger.isHotFeedsOnly {
            await readAndApplyHotFeedSnapshot(
                for: context,
                logger: environment.logger,
                spcRisk: environment.spcRisk,
                arcusQuery: environment.arcusAlerts
            )
        } else {
            if trigger.showsLoading {
                updateRefreshMessage("Reading local data...")
            }
            await readAndApplyLocationScopedSnapshot(
                for: context,
                logger: environment.logger,
                spcRisk: environment.spcRisk,
                arcusQuery: environment.arcusAlerts
            )
        }

        if trigger.isHotFeedsOnly == false {
            if shouldSyncWeatherKitNow {
                if trigger.showsLoading {
                    updateRefreshMessage("Updating current weather...")
                }
                let didRefreshWeather = await refreshWeather(
                    for: context.snapshot.coordinates,
                    weatherClient: environment.weatherClient
                )
                if didRefreshWeather {
                    lastWeatherKitSyncAt = now
                }
            } else {
                environment.logger.debug("Skipping WeatherKit refresh due to refresh throttle")
            }
        }

        if trigger.showsLoading {
            endRefresh()
        }
    }

    private func refreshWeather(
        for coordinates: CLLocationCoordinate2D,
        weatherClient: any HomeWeatherQuerying
    ) async -> Bool {
        if Task.isCancelled { return false }
        let weather = await weatherClient.currentWeather(
            for: CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        )
        if Task.isCancelled { return false }
        guard let weather else { return false }
        summaryWeather = weather
        return true
    }

    private func refreshOutlooks(using outlooksService: any SpcOutlookQuerying) async {
        do {
            let dtos = try await outlooksService.getConvectiveOutlooks()
            let latest = dtos.max(by: { $0.published < $1.published })
            if Task.isCancelled { return }
            outlooks = dtos
            outlook = latest
        } catch {
            // Swallow for now; consider logging.
        }
    }

    private func shouldRefresh(for snapshot: LocationSnapshot, force: Bool = false) -> Bool {
        guard HomeView.shouldPerformLocationRefresh(
            lastRefreshContext: lastRefreshContext,
            snapshot: snapshot,
            force: force,
            minimumForegroundRefreshInterval: minimumForegroundRefreshInterval,
            minimumRefreshDistanceMeters: minimumRefreshDistanceMeters
        ) else {
            return false
        }

        lastRefreshContext = RefreshContext(
            coordinates: snapshot.coordinates,
            refreshedAt: snapshot.timestamp
        )
        return true
    }

    private func resolveContext(
        for trigger: HomeView.RefreshTrigger,
        locationSession: any HomeLocationContextPreparing
    ) async -> LocationContext? {
        switch trigger {
        case .sceneActive, .manual:
            return await locationSession.prepareCurrentLocationContext(
                requiresFreshLocation: trigger.requiresFreshLocation,
                showsAuthorizationPrompt: trigger.showsAuthorizationPrompt,
                authorizationTimeout: 30,
                locationTimeout: 12,
                maximumAcceptedLocationAge: 5 * 60,
                placemarkTimeout: 8
            )
        case .contextChanged:
            return locationSession.currentContext
        case .timer:
            if let currentContext = locationSession.currentContext {
                return currentContext
            }

            return await locationSession.prepareCurrentLocationContext(
                requiresFreshLocation: false,
                showsAuthorizationPrompt: false,
                authorizationTimeout: 30,
                locationTimeout: 12,
                maximumAcceptedLocationAge: 5 * 60,
                placemarkTimeout: 8
            )
        }
    }

    private func markHotFeedSyncIfNeeded(force: Bool, now: Date) -> Bool {
        let shouldSync = alertRefreshPolicy.shouldSync(
            now: now,
            lastSync: lastHotFeedSyncAt,
            force: force
        )
        if shouldSync {
            lastHotFeedSyncAt = now
        }
        return shouldSync
    }

    private func markMapProductSyncIfNeeded(force: Bool, now: Date) -> Bool {
        let shouldSync = mapProductRefreshPolicy.shouldSync(
            now: now,
            lastSync: lastMapProductSyncAt,
            force: force
        )
        if shouldSync {
            lastMapProductSyncAt = now
        }
        return shouldSync
    }

    private func markOutlookSyncIfNeeded(force: Bool, now: Date) -> Bool {
        let shouldSync = outlookRefreshPolicy.shouldSync(
            now: now,
            lastSync: lastOutlookSyncAt,
            force: force
        )
        if shouldSync {
            lastOutlookSyncAt = now
        }
        return shouldSync
    }

    private func shouldSyncWeatherKit(force: Bool, now: Date) -> Bool {
        weatherKitRefreshPolicy.shouldSync(
            now: now,
            lastSync: lastWeatherKitSyncAt,
            force: force
        )
    }

    private func syncSlowFeeds(
        shouldSyncMapProducts: Bool,
        shouldSyncOutlooks: Bool,
        sync: any SpcSyncing
    ) async {
        guard shouldSyncMapProducts || shouldSyncOutlooks else { return }

        await HTTPExecutionMode.$current.withValue(.foreground) {
            await withTaskGroup(of: Void.self) { group in
                if shouldSyncMapProducts {
                    group.addTask { await sync.syncMapProducts() }
                }
                if shouldSyncOutlooks {
                    group.addTask { await sync.syncConvectiveOutlooks() }
                }
                await group.waitForAll()
            }
        }
    }

    private func readAndApplyLocationScopedSnapshot(
        for context: LocationContext,
        logger: Logger,
        spcRisk: any SpcRiskQuerying,
        arcusQuery: any ArcusAlertQuerying
    ) async {
        do {
            let snapshot = try await IngestionSupport.readLocationScopedSnapshot(
                spcRisk: spcRisk,
                arcusQuery: arcusQuery,
                context: context
            )
            if Task.isCancelled { return }
            stormRisk = snapshot.stormRisk
            severeRisk = snapshot.severeRisk
            fireRisk = snapshot.fireRisk
            mesos = snapshot.mesos
            watches = snapshot.watches
        } catch {
            logger.error("Failed to read location-scoped data snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func readAndApplyHotFeedSnapshot(
        for context: LocationContext,
        logger: Logger,
        spcRisk: any SpcRiskQuerying,
        arcusQuery: any ArcusAlertQuerying
    ) async {
        do {
            let snapshot = try await IngestionSupport.readHotFeedSnapshot(
                spcRisk: spcRisk,
                arcusQuery: arcusQuery,
                context: context
            )
            if Task.isCancelled { return }
            snap = context.snapshot
            mesos = snapshot.mesos
            watches = snapshot.watches
        } catch {
            logger.error("Failed to read hot feed snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func withLoading(message: String, operation: @escaping () async -> Void) async {
        startRefresh(message: message)
        await operation()
        endRefresh()
    }

    private func startRefresh(message: String) {
        loadingState.begin(message: message)
    }

    private func updateRefreshMessage(_ message: String) {
        loadingState.setMessage(message)
    }

    private func endRefresh() {
        loadingState.end()
    }
}

extension HomeView {
    struct LoadingOverlayState {
        private(set) var activeRefreshes: Int = 0
        private(set) var message: String?

        var isVisible: Bool { activeRefreshes > 0 }
        var displayMessage: String { message ?? "Refreshing data..." }

        mutating func begin(message: String) {
            self.message = message
            activeRefreshes += 1
        }

        mutating func setMessage(_ message: String) {
            self.message = message
        }

        mutating func end() {
            activeRefreshes = max(0, activeRefreshes - 1)
            if activeRefreshes == 0 {
                message = nil
            }
        }
    }

    enum RefreshTrigger: Equatable {
        case sceneActive
        case manual
        case contextChanged
        case timer

        var showsLoading: Bool {
            switch self {
            case .sceneActive, .manual:
                return true
            case .contextChanged, .timer:
                return false
            }
        }

        var requiresFreshLocation: Bool {
            switch self {
            case .sceneActive, .manual:
                return true
            case .contextChanged, .timer:
                return false
            }
        }

        var showsAuthorizationPrompt: Bool {
            self == .sceneActive
        }

        var bypassesThrottles: Bool {
            switch self {
            case .sceneActive, .manual, .contextChanged:
                return true
            case .timer:
                return false
            }
        }

        var supportsSlowFeeds: Bool {
            self != .timer
        }

        var isHotFeedsOnly: Bool {
            self == .timer
        }

        func absorbs(_ other: RefreshTrigger) -> Bool {
            switch (self, other) {
            case (.manual, _), (.sceneActive, .contextChanged), (.sceneActive, .timer), (.contextChanged, .timer):
                return true
            default:
                return self == other
            }
        }

        static func merge(_ lhs: RefreshTrigger, _ rhs: RefreshTrigger) -> RefreshTrigger {
            [lhs, rhs].max(by: { $0.priority < $1.priority }) ?? lhs
        }

        private var priority: Int {
            switch self {
            case .manual:
                return 3
            case .sceneActive:
                return 2
            case .contextChanged:
                return 1
            case .timer:
                return 0
            }
        }
    }
}
