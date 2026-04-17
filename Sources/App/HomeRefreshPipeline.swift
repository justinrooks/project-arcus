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

    func resetLocationRefreshContext() {}

    func handleScenePhaseChange(_ newPhase: ScenePhase, environment: Environment) async {
        updateEnvironment(environment)

        if newPhase == .active {
            startForegroundTimerIfNeeded()
            await submit(.sceneActive, waitsForCompletion: false)
            return
        }

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
        do {
            let snapshot = try await environment.coordinator.enqueueAndWait(
                makeRequest(for: trigger, using: environment.locationSession)
            )
            apply(snapshot)
        } catch {
            if let refreshKey = environment.locationSession.currentContext?.refreshKey {
                lastResolvedLocationScopedRefreshKey = refreshKey
            }
            environment.logger.error(
                "Foreground refresh failed for trigger=\(String(describing: trigger), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func refreshOutlooks(using outlooksService: any SpcOutlookQuerying) async {
        do {
            let dtos = try await outlooksService.getConvectiveOutlooks()
            let latest = dtos.max(by: { $0.published < $1.published })
            outlookSnapshot = HomeOutlookSnapshot(outlooks: dtos, outlook: latest)
        } catch {
            environment?.logger.error(
                "Manual outlook refresh failed: \(error.localizedDescription, privacy: .public)"
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
    }
}
