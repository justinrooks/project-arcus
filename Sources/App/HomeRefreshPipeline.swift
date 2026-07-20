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
import ArcusCore

protocol HomeWeatherQuerying: Sendable {
    func currentWeather(for location: CLLocation) async -> HomeWeatherRefreshResult
}

enum HomeWeatherRefreshResult: Sendable, Equatable {
    case skipped
    case success(SummaryWeather?)
    case failure

    var weather: SummaryWeather? {
        if case .success(let weather) = self {
            return weather
        }
        return nil
    }
}

@MainActor
protocol HomeLocationContextPreparing: AnyObject {
    var currentContext: LocationContext? { get }

    func prepareCurrentLocationContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
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

struct HomeAlertSnapshot: Equatable {
    var refreshKey: LocationContext.RefreshKey?
    var mesos: [MdDTO] = []
    var alerts: [AlertDTO] = []
}

struct HomeOutlookSnapshot {
    var outlooks: [ConvectiveOutlookDTO] = []
    var outlook: ConvectiveOutlookDTO?
}

@MainActor
@Observable
final class HomeRefreshPipeline {
    private struct AcceptedCorePublication: Equatable {
        let submissionID: UUID
        let runID: UUID
        let refreshKey: LocationContext.RefreshKey?
    }

    struct Environment {
        let logger: Logger
        let sync: any SpcSyncing
        let outlooks: any SpcOutlookQuerying
        let coordinator: any HomeIngestionCoordinating
        let locationSession: any HomeLocationContextPreparing
    }

    private let foregroundTimerInterval: Duration
    private let performanceSignposter = OSSignposter(logger: Logger.appHomeRefresh)

    private var environment: Environment?
    private(set) var lastResolvedLocationScopedRefreshKey: LocationContext.RefreshKey?
    private(set) var stormSetupRefreshKey: LocationContext.RefreshKey?
    private(set) var alertSnapshotRefreshKey: LocationContext.RefreshKey?
    private var airQualityRefreshKey: LocationContext.RefreshKey?
    private var foregroundTimerTask: Task<Void, Never>?
    private var lastHandledScenePhase: ScenePhase?
    private var deferredContextRefreshKey: LocationContext.RefreshKey?
    private var activeRefreshCount = 0
    private var followUpRefreshCount = 0
    private var latestVisibleSubmissionID: UUID?
    private var acceptedCorePublication: AcceptedCorePublication?

    var snap: LocationSnapshot?
    var summaryWeather: SummaryWeather?
    var stormSetup: StormSetupDTO?
    var stormSetupCurrentResponse: StormSetupCurrentResponse?
    var airQuality: AirQualityCurrentResponse?
    private(set) var riskSnapshot: HomeRiskSnapshot
    private(set) var alertSnapshot: HomeAlertSnapshot
    private(set) var outlookSnapshot: HomeOutlookSnapshot
    private(set) var outlookRefreshStatus: ConvectiveOutlookRefreshStatus
    var resolutionState = SummaryResolutionState()

    var stormRisk: StormRiskLevel? { riskSnapshot.stormRisk }
    var severeRisk: SevereWeatherThreat? { riskSnapshot.severeRisk }
    var fireRisk: FireRiskLevel? { riskSnapshot.fireRisk }
    var mesos: [MdDTO] { alertSnapshot.mesos }
    var alerts: [AlertDTO] { alertSnapshot.alerts }
    var outlooks: [ConvectiveOutlookDTO] { outlookSnapshot.outlooks }
    var outlook: ConvectiveOutlookDTO? { outlookSnapshot.outlook }
    var isRefreshInFlight: Bool {
        activeRefreshCount > 0 || followUpRefreshCount > 0
    }

    init(
        initialSnap: LocationSnapshot? = nil,
        initialStormRisk: StormRiskLevel? = nil,
        initialSevereRisk: SevereWeatherThreat? = nil,
        initialFireRisk: FireRiskLevel? = nil,
        initialStormSetup: StormSetupDTO? = nil,
        initialStormSetupCurrentResponse: StormSetupCurrentResponse? = nil,
        initialStormSetupRefreshKey: LocationContext.RefreshKey? = nil,
        initialAlertSnapshotRefreshKey: LocationContext.RefreshKey? = nil,
        initialMesos: [MdDTO] = [],
        initialAlerts: [AlertDTO] = [],
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
        self.stormSetup = initialStormSetup
        self.stormSetupCurrentResponse = initialStormSetupCurrentResponse
        self.stormSetupRefreshKey = initialStormSetupRefreshKey
        self.alertSnapshotRefreshKey = initialAlertSnapshotRefreshKey
        self.riskSnapshot = HomeRiskSnapshot(
            stormRisk: initialStormRisk,
            severeRisk: initialSevereRisk,
            fireRisk: initialFireRisk
        )
        self.alertSnapshot = HomeAlertSnapshot(
            refreshKey: initialAlertSnapshotRefreshKey,
            mesos: initialMesos,
            alerts: initialAlerts
        )
        self.outlookSnapshot = HomeOutlookSnapshot(
            outlooks: initialOutlooks,
            outlook: initialOutlook
        )
        self.outlookRefreshStatus = initialOutlooks.isEmpty && initialOutlook == nil ? .loading : .success(hasContent: true)
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

        if isRefreshInFlight {
            environment.logger.debug(
                "Deferring foreground refresh trigger=\(HomeRefreshTrigger.foregroundLocationChange.logName, privacy: .public) while activeRefreshCount=\(self.activeRefreshCount, privacy: .public) followUpRefreshCount=\(self.followUpRefreshCount, privacy: .public)"
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
        while activeRefreshCount > 0 || followUpRefreshCount > 0 {
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
        let previousResolvedRefreshKey = lastResolvedLocationScopedRefreshKey
        do {
            let request = makeRequest(for: trigger, using: environment.locationSession)
            let snapshot: HomeSnapshot
            if shouldPrimeSummary(for: trigger) {
                snapshot = try await environment.coordinator.enqueueAndWait(
                    makePrimeRequest(for: trigger, using: environment.locationSession)
                )
                if trigger == .sceneActive, snapshot.locationSnapshot != nil {
                    lastResolvedLocationScopedRefreshKey = snapshot.refreshKey
                }
                scheduleFollowUpRefresh(request, environment: environment)
            } else {
                snapshot = try await enqueueVisibleSnapshot(request, environment: environment)
            }
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            environment.logger.info(
                "Foreground refresh finished trigger=\(trigger.logName, privacy: .public) result=success durationMs=\(durationMs, privacy: .public) hasLocationSnapshot=\((snapshot.locationSnapshot != nil), privacy: .public) alertss=\(snapshot.alerts.count, privacy: .public) mesos=\(snapshot.mesos.count, privacy: .public) outlooks=\(snapshot.outlooks.count, privacy: .public) weather=\((snapshot.weather != nil), privacy: .public)"
            )
        } catch {
            if shouldPrimeSummary(for: trigger) {
                lastResolvedLocationScopedRefreshKey = previousResolvedRefreshKey
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
            outlookRefreshStatus = .success(hasContent: dtos.isEmpty == false)
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            environment?.logger.info(
                "Manual convective outlook refresh finished result=success durationMs=\(durationMs, privacy: .public) outlooks=\(dtos.count, privacy: .public)"
            )
        } catch {
            if case .loading = outlookRefreshStatus {
                outlookRefreshStatus = .failed
            }
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
        finalizeForegroundRefreshIfNeeded()
    }

    private func handleIngestionProgress(_ event: HomeIngestionProgressEvent) async {
        let update = summaryResolutionUpdate(for: event)
        guard update.sections.isEmpty == false else { return }

        switch event {
        case .started:
            resolutionState.begin(task: update.task, sections: update.sections)
        case .completed, .skipped:
            resolutionState.finish(task: update.task, resolvedSections: update.sections)
        }
    }

    private func summaryResolutionUpdate(
        for event: HomeIngestionProgressEvent
    ) -> (task: SummaryProviderTask, sections: [SummarySection]) {
        let scope: HomeIngestionProgressScope
        switch event {
        case .started(let eventScope), .completed(let eventScope), .skipped(let eventScope):
            scope = eventScope
        }

        switch scope {
        case .location(let lanes):
            return (
                .location,
                summarySections(for: lanes)
            )
        case .lane(.hotAlerts):
            return (.alerts, [.alerts])
        case .lane(.slowProducts):
            return (.stormRisk, [.stormRisk, .severeRisk, .fireRisk, .outlook])
        case .lane(.weather):
            return (.weather, [.conditions, .atmosphere])
        default:
            return (.finalizing, [])
        }
    }

    private func summarySections(for lanes: HomeIngestionLane) -> [SummarySection] {
        var sections: [SummarySection] = []
        if lanes.contains(.weather) {
            sections.append(contentsOf: [.conditions, .atmosphere])
        }
        if lanes.contains(.slowProducts) {
            sections.append(contentsOf: [.stormRisk, .severeRisk, .fireRisk])
        }
        if lanes.contains(.hotAlerts) {
            sections.append(.alerts)
        }
        return sections
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

    private func makePrimeRequest(
        for trigger: HomeView.RefreshTrigger,
        using locationSession: any HomeLocationContextPreparing
    ) -> HomeIngestionRequest {
        HomeIngestionRequest(
            trigger: .foregroundPrime,
            locationContext: trigger == .contextChanged ? locationSession.currentContext : nil
        )
    }

    private func shouldPrimeSummary(for trigger: HomeView.RefreshTrigger) -> Bool {
        switch trigger {
        case .sceneActive, .contextChanged:
            return true
        case .manual, .timer:
            return false
        }
    }

    private func scheduleFollowUpRefresh(
        _ request: HomeIngestionRequest,
        environment: Environment
    ) {
        followUpRefreshCount += 1
        environment.logger.debug(
            "Scheduling non-blocking follow-up refresh trigger=\(request.trigger.logName, privacy: .public)"
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.followUpRefreshCount -= 1
                self.finalizeForegroundRefreshIfNeeded()
            }
            do {
                _ = try await self.enqueueVisibleSnapshot(request, environment: environment)
                environment.logger.debug(
                    "Finished non-blocking follow-up refresh trigger=\(request.trigger.logName, privacy: .public) result=success"
                )
            } catch {
                environment.logger.error(
                    "Non-blocking follow-up refresh failed trigger=\(request.trigger.logName, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func finalizeForegroundRefreshIfNeeded() {
        guard activeRefreshCount == 0, followUpRefreshCount == 0 else {
            return
        }

        resolutionState.finishAll(completedTask: .finalizing)
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

    private func enqueueVisibleSnapshot(
        _ request: HomeIngestionRequest,
        environment: Environment
    ) async throws -> HomeSnapshot {
        let submissionID = UUID()
        let previousResolvedRefreshKey = lastResolvedLocationScopedRefreshKey
        latestVisibleSubmissionID = submissionID
        defer {
            if latestVisibleSubmissionID == submissionID {
                latestVisibleSubmissionID = nil
            }
        }

        do {
            let snapshot = try await environment.coordinator.enqueueAndWait(
                request,
                progress: { [weak self] event in
                    await self?.handleIngestionProgress(event)
                },
                publication: { [weak self] publication in
                    await self?.handle(publication, submissionID: submissionID)
                }
            )
            applyFinalSnapshotIfNeeded(snapshot, submissionID: submissionID)
            return snapshot
        } catch {
            if latestVisibleSubmissionID == submissionID,
               acceptedCorePublication?.submissionID != submissionID {
                lastResolvedLocationScopedRefreshKey = previousResolvedRefreshKey
            }
            throw error
        }
    }

    private func handle(_ publication: HomeIngestionPublication, submissionID: UUID) {
        guard latestVisibleSubmissionID == submissionID else { return }

        switch publication.stage {
        case .core(let core):
            guard acceptedCorePublication?.submissionID != submissionID else { return }
            applyCore(core)
            acceptedCorePublication = AcceptedCorePublication(
                submissionID: submissionID,
                runID: publication.runID,
                refreshKey: core.refreshKey
            )
        case .enrichment(let enrichment):
            guard acceptedCorePublication == AcceptedCorePublication(
                submissionID: submissionID,
                runID: publication.runID,
                refreshKey: enrichment.refreshKey
            ) else {
                return
            }
            applyEnrichment(enrichment)
        }
    }

    private func applyFinalSnapshotIfNeeded(_ snapshot: HomeSnapshot, submissionID: UUID) {
        guard latestVisibleSubmissionID == submissionID else { return }
        guard acceptedCorePublication?.submissionID != submissionID else { return }

        applyCore(.init(snapshot: snapshot))
        applyEnrichment(.init(snapshot: snapshot))
    }

    private func applyCore(_ core: HomeIngestionCorePublication) {
        let locationChanged = core.locationSnapshot != nil
            && lastResolvedLocationScopedRefreshKey != nil
            && core.refreshKey != lastResolvedLocationScopedRefreshKey

        if let locationSnapshot = core.locationSnapshot {
            snap = locationSnapshot
            lastResolvedLocationScopedRefreshKey = core.refreshKey
            riskSnapshot = HomeRiskSnapshot(
                stormRisk: core.stormRisk,
                severeRisk: core.severeRisk,
                fireRisk: core.fireRisk
            )
            commitAlertSnapshotIfChanged(
                HomeAlertSnapshot(
                    refreshKey: core.refreshKey,
                    mesos: core.mesos,
                    alerts: core.alerts
                )
            )

            if core.refreshKey != stormSetupRefreshKey {
                stormSetup = nil
                stormSetupCurrentResponse = nil
                stormSetupRefreshKey = core.refreshKey
            }
            if core.refreshKey != airQualityRefreshKey {
                airQuality = nil
                airQualityRefreshKey = core.refreshKey
            }
        }

        switch core.weatherRefreshResult {
        case .success(let weather):
            summaryWeather = weather
        case .skipped, .failure:
            if locationChanged {
                summaryWeather = nil
            }
            break
        }

        outlookSnapshot = HomeOutlookSnapshot(
            outlooks: core.outlooks,
            outlook: core.latestOutlook
        )
        outlookRefreshStatus = .success(hasContent: core.outlooks.isEmpty == false)
        performanceSignposter.emitEvent("Today Visible Commit")
    }

    private func applyEnrichment(_ enrichment: HomeIngestionEnrichmentPublication) {
        applyStormSetup(enrichment)
        airQuality = enrichment.airQuality
        airQualityRefreshKey = enrichment.refreshKey
    }

    private func applyStormSetup(_ enrichment: HomeIngestionEnrichmentPublication) {
        guard let snapshotRefreshKey = enrichment.refreshKey else {
            stormSetup = nil
            stormSetupRefreshKey = nil
            return
        }

        guard let resolvedStormSetup = enrichment.stormSetup else {
            guard snapshotRefreshKey != stormSetupRefreshKey else {
                return
            }

            self.stormSetup = nil
            stormSetupCurrentResponse = nil
            stormSetupRefreshKey = snapshotRefreshKey
            return
        }

        self.stormSetup = resolvedStormSetup
        stormSetupCurrentResponse = enrichment.stormSetupCurrentResponse
        stormSetupRefreshKey = snapshotRefreshKey
    }

    @discardableResult
    func commitAlertSnapshotIfChanged(_ proposedSnapshot: HomeAlertSnapshot) -> Bool {
        guard alertSnapshot != proposedSnapshot else {
            return false
        }

        alertSnapshot = proposedSnapshot
        if alertSnapshotRefreshKey != proposedSnapshot.refreshKey {
            alertSnapshotRefreshKey = proposedSnapshot.refreshKey
        }
        return true
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
