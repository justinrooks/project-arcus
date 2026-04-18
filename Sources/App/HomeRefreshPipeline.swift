//
//  HomeRefreshPipeline.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import CoreLocation
import Observation
import OSLog
import SwiftUI

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

struct HomeRiskSnapshot {
    var stormRisk: StormRiskLevel?
    var severeRisk: SevereWeatherThreat?
    var fireRisk: FireRiskLevel?
}

struct HomeAlertSnapshot {
    var mesos: [MdDTO] = []
    var watches: [WatchRowDTO] = []
}

struct HomeOutlookSnapshot {
    var outlooks: [ConvectiveOutlookDTO] = []
    var outlook: ConvectiveOutlookDTO?
}

@MainActor
@Observable
final class HomeRefreshPipeline {
    struct Environment {
        let logger: Logger
        let sync: any SpcSyncing
        let outlooks: any SpcOutlookQuerying
        let coordinator: any HomeIngestionCoordinating
        let locationSession: any HomeLocationContextPreparing
    }

    private let foregroundTimerInterval: Duration

    private var environment: Environment?
    private(set) var lastResolvedLocationScopedRefreshKey: LocationContext.RefreshKey?
    private var foregroundTimerTask: Task<Void, Never>?
    private var lastHandledScenePhase: ScenePhase?
    private var deferredContextRefreshKey: LocationContext.RefreshKey?
    private var activeRefreshCount = 0

    var snap: LocationSnapshot?
    var summaryWeather: SummaryWeather?
    private(set) var riskSnapshot: HomeRiskSnapshot
    private(set) var alertSnapshot: HomeAlertSnapshot
    private(set) var outlookSnapshot: HomeOutlookSnapshot
    var resolutionState = SummaryResolutionState()

    var stormRisk: StormRiskLevel? { riskSnapshot.stormRisk }
    var severeRisk: SevereWeatherThreat? { riskSnapshot.severeRisk }
    var fireRisk: FireRiskLevel? { riskSnapshot.fireRisk }
    var mesos: [MdDTO] { alertSnapshot.mesos }
    var watches: [WatchRowDTO] { alertSnapshot.watches }
    var outlooks: [ConvectiveOutlookDTO] { outlookSnapshot.outlooks }
    var outlook: ConvectiveOutlookDTO? { outlookSnapshot.outlook }

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
        self.riskSnapshot = HomeRiskSnapshot(
            stormRisk: initialStormRisk,
            severeRisk: initialSevereRisk,
            fireRisk: initialFireRisk
        )
        self.alertSnapshot = HomeAlertSnapshot(
            mesos: initialMesos,
            watches: initialWatches
        )
        self.outlookSnapshot = HomeOutlookSnapshot(
            outlooks: initialOutlooks,
            outlook: initialOutlook
        )
        self.foregroundTimerInterval = foregroundTimerInterval
    }

    func updateEnvironment(_ environment: Environment) {
        self.environment = environment
    }

    func resetLocationRefreshContext() {
        deferredContextRefreshKey = nil
    }

    func handleScenePhaseChange(_ newPhase: ScenePhase, environment: Environment) async {
        updateEnvironment(environment)

        if lastHandledScenePhase == newPhase {
            if newPhase == .active {
                startForegroundTimerIfNeeded()
            }
            environment.logger.debug(
                "Ignoring duplicate home refresh scene phase change phase=\(newPhase.logName, privacy: .public)"
            )
            return
        }
        lastHandledScenePhase = newPhase

        if newPhase == .active {
            startForegroundTimerIfNeeded()
            environment.logger.info(
                "Scheduling foreground refresh trigger=\(HomeRefreshTrigger.foregroundActivate.logName, privacy: .public)"
            )
            await submit(.sceneActive, waitsForCompletion: false)
            return
        }

        environment.logger.debug("Stopping foreground refresh timer phase=\(newPhase.logName, privacy: .public)")
        foregroundTimerTask?.cancel()
        foregroundTimerTask = nil
    }

    func forceRefreshCurrentContext(showsLoading: Bool, environment: Environment) async {
        updateEnvironment(environment)
        await submit(.manual, waitsForCompletion: showsLoading)
    }

    func refreshOutlooksManually(environment: Environment) async {
        updateEnvironment(environment)

        await HTTPExecutionMode.$current.withValue(.foreground) {
            await environment.sync.syncConvectiveOutlooks()
        }
        await refreshOutlooks(using: environment.outlooks)
    }

    func enqueueRefresh(_ trigger: HomeView.RefreshTrigger, environment: Environment) async {
        updateEnvironment(environment)
        await submit(trigger, waitsForCompletion: false)
    }

    func handleContextRefreshKeyChange(
        _ newKey: LocationContext.RefreshKey?,
        scenePhase: ScenePhase,
        environment: Environment
    ) async {
        updateEnvironment(environment)
        guard scenePhase == .active, let newKey else { return }

        if activeRefreshCount > 0 {
            environment.logger.debug(
                "Deferring foreground refresh trigger=\(HomeRefreshTrigger.foregroundLocationChange.logName, privacy: .public) while activeRefreshCount=\(self.activeRefreshCount, privacy: .public)"
            )
            deferredContextRefreshKey = newKey
            return
        }

        guard newKey != lastResolvedLocationScopedRefreshKey else {
            environment.logger.debug(
                "Skipping foreground refresh trigger=\(HomeRefreshTrigger.foregroundLocationChange.logName, privacy: .public) because the location scope is already resolved"
            )
            return
        }

        environment.logger.info(
            "Scheduling foreground refresh trigger=\(HomeRefreshTrigger.foregroundLocationChange.logName, privacy: .public)"
        )
        await submit(.contextChanged, waitsForCompletion: false)
    }

    func waitForIdle() async {
        while activeRefreshCount > 0 {
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
            await submit(.timer, waitsForCompletion: false)
        }
    }

    private func submit(_ trigger: HomeView.RefreshTrigger, waitsForCompletion: Bool) async {
        guard let environment else { return }

        environment.logger.info(
            "Foreground refresh started trigger=\(trigger.logName, privacy: .public) waitsForCompletion=\(waitsForCompletion, privacy: .public)"
        )
        beginForegroundRefresh()

        if waitsForCompletion {
            await runRefresh(trigger, environment: environment)
            finishForegroundRefresh()
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runRefresh(trigger, environment: environment)
            self.finishForegroundRefresh()
        }
    }

    private func runRefresh(
        _ trigger: HomeView.RefreshTrigger,
        environment: Environment
    ) async {
        let startedAt = Date()
        do {
            let snapshot = try await environment.coordinator.enqueueAndWait(
                makeRequest(for: trigger, using: environment.locationSession)
            )
            apply(snapshot)
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            environment.logger.info(
                "Foreground refresh finished trigger=\(trigger.logName, privacy: .public) result=success durationMs=\(durationMs, privacy: .public) hasLocationSnapshot=\((snapshot.locationSnapshot != nil), privacy: .public) watches=\(snapshot.watches.count, privacy: .public) mesos=\(snapshot.mesos.count, privacy: .public) outlooks=\(snapshot.outlooks.count, privacy: .public) weather=\((snapshot.weather != nil), privacy: .public)"
            )
        } catch {
            if let refreshKey = environment.locationSession.currentContext?.refreshKey {
                lastResolvedLocationScopedRefreshKey = refreshKey
            }
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            environment.logger.error(
                "Foreground refresh finished trigger=\(trigger.logName, privacy: .public) result=failure durationMs=\(durationMs, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func refreshOutlooks(using outlooksService: any SpcOutlookQuerying) async {
        let startedAt = Date()
        do {
            let dtos = try await outlooksService.getConvectiveOutlooks()
            let latest = dtos.max(by: { $0.published < $1.published })
            outlookSnapshot = HomeOutlookSnapshot(outlooks: dtos, outlook: latest)
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            environment?.logger.info(
                "Manual convective outlook refresh finished result=success durationMs=\(durationMs, privacy: .public) outlooks=\(dtos.count, privacy: .public)"
            )
        } catch {
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            environment?.logger.error(
                "Manual convective outlook refresh finished result=failure durationMs=\(durationMs, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func beginForegroundRefresh() {
        activeRefreshCount += 1
        if activeRefreshCount == 1 {
            resolutionState.begin(task: .finalizing, sections: [])
        }
    }

    private func finishForegroundRefresh() {
        guard activeRefreshCount > 0 else { return }
        activeRefreshCount -= 1
        if activeRefreshCount == 0 {
            resolutionState.finish(task: .finalizing, resolvedSections: [])
            let deferredContextRefreshKey = self.deferredContextRefreshKey
            self.deferredContextRefreshKey = nil
            guard
                lastHandledScenePhase == .active,
                deferredContextRefreshKey != nil,
                deferredContextRefreshKey != lastResolvedLocationScopedRefreshKey
            else {
                return
            }

            environment?.logger.info(
                "Submitting deferred foreground refresh trigger=\(HomeRefreshTrigger.foregroundLocationChange.logName, privacy: .public)"
            )
            Task { @MainActor [weak self] in
                await self?.submit(.contextChanged, waitsForCompletion: false)
            }
        }
    }

    private func makeRequest(
        for trigger: HomeView.RefreshTrigger,
        using locationSession: any HomeLocationContextPreparing
    ) -> HomeIngestionRequest {
        HomeIngestionRequest(
            trigger: trigger.ingestionTrigger,
            locationContext: trigger == .contextChanged ? locationSession.currentContext : nil
        )
    }

    private func apply(_ snapshot: HomeSnapshot) {
        if let locationSnapshot = snapshot.locationSnapshot {
            snap = locationSnapshot
            lastResolvedLocationScopedRefreshKey = snapshot.refreshKey
            riskSnapshot = HomeRiskSnapshot(
                stormRisk: snapshot.stormRisk,
                severeRisk: snapshot.severeRisk,
                fireRisk: snapshot.fireRisk
            )
            alertSnapshot = HomeAlertSnapshot(
                mesos: snapshot.mesos,
                watches: snapshot.watches
            )
        }

        if let weather = snapshot.weather {
            summaryWeather = weather
        }

        outlookSnapshot = HomeOutlookSnapshot(
            outlooks: snapshot.outlooks,
            outlook: snapshot.latestOutlook
        )
    }
}

extension HomeView {
    enum RefreshTrigger: Equatable {
        case sceneActive
        case manual
        case contextChanged
        case timer

        var ingestionTrigger: HomeRefreshTrigger {
            switch self {
            case .sceneActive:
                return .foregroundActivate
            case .manual:
                return .manualRefresh
            case .contextChanged:
                return .foregroundLocationChange
            case .timer:
                return .sessionTick
            }
        }

        var logName: String {
            switch self {
            case .sceneActive:
                return "sceneActive"
            case .manual:
                return "manual"
            case .contextChanged:
                return "contextChanged"
            case .timer:
                return "timer"
            }
        }
    }
}

private extension ScenePhase {
    var logName: String {
        switch self {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}
