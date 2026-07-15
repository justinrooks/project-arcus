//
//  HomeIngestionExecutor.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import CoreLocation
import Foundation
import OSLog
import ArcusCore

enum HomeIngestionProgressScope: Sendable, Equatable {
    case location(HomeIngestionLane)
    case lane(HomeIngestionLane)
}

enum HomeIngestionProgressEvent: Sendable, Equatable {
    case started(HomeIngestionProgressScope)
    case completed(HomeIngestionProgressScope)
    case skipped(HomeIngestionProgressScope)
}

typealias HomeIngestionProgressHandler = @Sendable (HomeIngestionProgressEvent) async -> Void

struct HomeIngestionRunProgress: Sendable {
    let markHotAlertsCompleted: @Sendable () async -> Void
    let report: HomeIngestionProgressHandler

    static let none = HomeIngestionRunProgress(
        markHotAlertsCompleted: {},
        report: { _ in }
    )
}

@MainActor
protocol HomeContextPreparing: AnyObject, Sendable {
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

    func currentPreparedContext() async -> LocationContext?
}

extension LocationSession: HomeContextPreparing {
    func currentPreparedContext() async -> LocationContext? {
        currentContext
    }
}

protocol HomeIngestionExecuting: Sendable {
    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress) async throws -> HomeSnapshot
}

actor HomeIngestionExecutor: HomeIngestionExecuting {
    private struct SlowProductPersistenceDecision: Sendable {
        let shouldUpdateProjection: Bool
        let shouldRefreshRiskWidgets: Bool
    }

    struct Environment: Sendable {
        let logger: Logger
        let spcSync: any SpcSyncing
        let arcusAlertSync: any ArcusAlertSyncing
        let weatherClient: any HomeWeatherQuerying
        let locationSession: any HomeContextPreparing
        let snapshotStore: any HomeSnapshotReading
        let projectionStore: (any HomeProjectionPersisting)?
        let widgetSnapshotRefresher: (any WidgetSnapshotRefreshing)?
        let stormSetupQuerying: (any StormSetupQuerying)?
        let airQualityQuerying: (any AirQualityQuerying)?
        let stormSetupPreferencesReader: @Sendable () async -> StormSetupPreferences
        let stormSetupCurrentDate: @Sendable () -> Date
        let stormSetupForegroundTimeout: TimeInterval
        let stormSetupFailedAttemptBackoff: TimeInterval

        init(
            logger: Logger,
            spcSync: any SpcSyncing,
            arcusAlertSync: any ArcusAlertSyncing,
            weatherClient: any HomeWeatherQuerying,
            locationSession: any HomeContextPreparing,
            snapshotStore: any HomeSnapshotReading,
            projectionStore: (any HomeProjectionPersisting)?,
            widgetSnapshotRefresher: (any WidgetSnapshotRefreshing)?,
            stormSetupQuerying: (any StormSetupQuerying)? = nil,
            airQualityQuerying: (any AirQualityQuerying)? = nil,
            stormSetupPreferencesReader: @escaping @Sendable () async -> StormSetupPreferences = { StormSetupPreferences() },
            stormSetupCurrentDate: @escaping @Sendable () -> Date = { Date() },
            stormSetupForegroundTimeout: TimeInterval = 5,
            stormSetupFailedAttemptBackoff: TimeInterval = 5 * 60
        ) {
            self.logger = logger
            self.spcSync = spcSync
            self.arcusAlertSync = arcusAlertSync
            self.weatherClient = weatherClient
            self.locationSession = locationSession
            self.snapshotStore = snapshotStore
            self.projectionStore = projectionStore
            self.widgetSnapshotRefresher = widgetSnapshotRefresher
            self.stormSetupQuerying = stormSetupQuerying
            self.airQualityQuerying = airQualityQuerying
            self.stormSetupPreferencesReader = stormSetupPreferencesReader
            self.stormSetupCurrentDate = stormSetupCurrentDate
            self.stormSetupForegroundTimeout = stormSetupForegroundTimeout
            self.stormSetupFailedAttemptBackoff = stormSetupFailedAttemptBackoff
        }
    }

    private let environment: Environment
    private let alertRefreshPolicy: AlertRefreshPolicy
    private let mapProductRefreshPolicy: MapProductRefreshPolicy
    private let outlookRefreshPolicy: OutlookRefreshPolicy
    private let weatherKitRefreshPolicy: WeatherKitRefreshPolicy
    private let stormSetupIngestion: HomeStormSetupIngestion

    private var freshness = HomeFreshnessState()

    init(
        environment: Environment,
        alertRefreshPolicy: AlertRefreshPolicy = .init(),
        mapProductRefreshPolicy: MapProductRefreshPolicy = .init(),
        outlookRefreshPolicy: OutlookRefreshPolicy = .init(),
        weatherKitRefreshPolicy: WeatherKitRefreshPolicy = .init()
    ) {
        self.environment = environment
        self.alertRefreshPolicy = alertRefreshPolicy
        self.mapProductRefreshPolicy = mapProductRefreshPolicy
        self.outlookRefreshPolicy = outlookRefreshPolicy
        self.weatherKitRefreshPolicy = weatherKitRefreshPolicy
        self.stormSetupIngestion = HomeStormSetupIngestion(
            logger: environment.logger,
            querying: environment.stormSetupQuerying,
            projectionStore: environment.projectionStore,
            preferencesReader: environment.stormSetupPreferencesReader,
            currentDate: environment.stormSetupCurrentDate,
            foregroundTimeout: environment.stormSetupForegroundTimeout,
            failedAttemptBackoff: environment.stormSetupFailedAttemptBackoff
        )
    }

    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress = .none) async throws -> HomeSnapshot {
        let startedAt = Date()
        environment.logger.info("Executing home ingestion plan={\(plan.logDescription)}")
        await progress.report(.started(.location(plan.lanes)))
        let context = await resolveContext(
            for: plan.locationRequest,
            uploadSource: uploadSource(for: plan),
            uploadReason: uploadReason(for: plan),
            using: environment.locationSession
        )
        await progress.report(context == nil ? .skipped(.location(plan.lanes)) : .completed(.location(plan.lanes)))
        let now = Date()
        let executionMode = httpExecutionMode(for: plan)
        environment.logger.debug(
            "Home ingestion context resolution finished available=\((context != nil), privacy: .public) mode=\(executionMode.logName, privacy: .public)"
        )

        if plan.lanes.contains(.hotAlerts) {
            if shouldSyncHotFeeds(plan: plan, now: now) {
                await progress.report(.started(.lane(.hotAlerts)))
                environment.logger.info("Running home ingestion hot-alert sync mode=\(executionMode.logName, privacy: .public)")
                await syncHotFeeds(plan: plan, context: context, executionMode: executionMode)
                freshness.lastHotFeedSyncAt = now
                await progress.report(.completed(.lane(.hotAlerts)))
                environment.logger.debug("Finished home ingestion hot-alert sync")
            } else {
                await progress.report(.skipped(.lane(.hotAlerts)))
                environment.logger.debug("Skipping home ingestion hot-alert sync reason=freshness")
            }
        }

        await progress.markHotAlertsCompleted()

        var slowProductMapSyncOutcome: SpcMapSyncOutcome?
        if plan.lanes.contains(.slowProducts) {
            if shouldSyncSlowFeeds(plan: plan, now: now) {
                await progress.report(.started(.lane(.slowProducts)))
                environment.logger.info("Running home ingestion slow-product sync mode=\(executionMode.logName, privacy: .public)")
                slowProductMapSyncOutcome = await syncSlowFeeds(executionMode: executionMode)
                if slowProductMapSyncOutcome == .accepted {
                    freshness.lastSlowFeedSyncAt = now
                }
                await progress.report(.completed(.lane(.slowProducts)))
                environment.logger.debug("Finished home ingestion slow-product sync")
            } else {
                await progress.report(.skipped(.lane(.slowProducts)))
                slowProductMapSyncOutcome = .skipped
                environment.logger.debug("Skipping home ingestion slow-product sync reason=freshness")
            }
        }

        let weatherRefresh = await refreshWeatherIfNeeded(
            plan: plan,
            context: context,
            now: now,
            progress: progress
        )

        var snapshot = try await environment.snapshotStore.loadSnapshot(
            for: context,
            weather: weatherRefresh.weather,
            freshness: freshness
        )
        snapshot.weatherRefreshResult = weatherRefresh
        let stormSetupRefresh = await stormSetupIngestion.refresh(
            context: context,
            snapshot: snapshot,
            plan: plan,
            executionMode: executionMode
        )
        snapshot.stormSetupRefreshResult = stormSetupRefresh.result
        snapshot.stormSetupCurrentResponse = stormSetupRefresh.currentResponse
        snapshot.stormSetup = stormSetupRefresh.stormSetup
        snapshot.airQuality = await refreshAirQuality(
            context: context,
            plan: plan,
            executionMode: executionMode
        )

        if let context {
            let slowProductDecision = slowProductPersistenceDecision(
                plan: plan,
                mapSyncOutcome: slowProductMapSyncOutcome
            )
            let riskProfileChange = await persistProjection(
                for: plan,
                context: context,
                snapshot: snapshot,
                weatherRefreshResult: weatherRefresh,
                loadedAt: now,
                slowProductDecision: slowProductDecision
            )
            snapshot.riskProfileChange = riskProfileChange
        }

        freshness.lastResolvedRefreshKey = snapshot.refreshKey
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        environment.logger.info(
            "Completed home ingestion plan={\(plan.logDescription)} result=success durationMs=\(durationMs, privacy: .public) hasLocationSnapshot=\((snapshot.locationSnapshot != nil), privacy: .public) alerts=\(snapshot.alerts.count, privacy: .public) mesos=\(snapshot.mesos.count, privacy: .public) outlooks=\(snapshot.outlooks.count, privacy: .public) weather=\((snapshot.weather != nil), privacy: .public)"
        )
        return snapshot
    }

    private func resolveContext(
        for request: HomeIngestionLocationRequest,
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
        using locationSession: any HomeContextPreparing
    ) async -> LocationContext? {
        switch request {
        case .currentPrepared:
            if let current = await locationSession.currentPreparedContext() {
                return current
            }
            return await locationSession.prepareCurrentLocationContext(
                requiresFreshLocation: false,
                showsAuthorizationPrompt: false,
                uploadSource: uploadSource,
                uploadReason: uploadReason,
                authorizationTimeout: 30,
                locationTimeout: 12,
                maximumAcceptedLocationAge: 5 * 60,
                placemarkTimeout: 8
            )
        case .latestAcceptedSnapshotPrepared:
            return await locationSession.prepareCurrentLocationContext(
                requiresFreshLocation: false,
                showsAuthorizationPrompt: false,
                uploadSource: uploadSource,
                uploadReason: uploadReason,
                authorizationTimeout: 30,
                locationTimeout: 12,
                maximumAcceptedLocationAge: 5 * 60,
                placemarkTimeout: 8
            )
        case .prepare(let requiresFreshLocation, let showsAuthorizationPrompt):
            return await locationSession.prepareCurrentLocationContext(
                requiresFreshLocation: requiresFreshLocation,
                showsAuthorizationPrompt: showsAuthorizationPrompt,
                uploadSource: uploadSource,
                uploadReason: uploadReason,
                authorizationTimeout: 30,
                locationTimeout: 12,
                maximumAcceptedLocationAge: 5 * 60,
                placemarkTimeout: 8
            )
        case .explicit(let context):
            return context
        }
    }

    private func uploadSource(for plan: HomeIngestionPlan) -> LocationUploadSource? {
        if plan.provenance.contains(.background), plan.provenance.contains(.locationChange) {
            return .backgroundLocationChange
        }
        if plan.provenance.contains(.background) {
            return .backgroundRefresh
        }
        if plan.provenance.contains(.manualRefresh) {
            return .manualRefresh
        }
        if plan.provenance.contains(.locationChange) {
            return .foregroundLocationChange
        }
        if plan.provenance.contains(.foregroundActivate), plan.lanes == [.hotAlerts] {
            return .foregroundPrime
        }
        if plan.provenance.contains(.foregroundActivate) {
            return .foregroundActivate
        }

        switch plan.locationRequest {
        case .latestAcceptedSnapshotPrepared:
            return .backgroundLocationChange
        case .prepare(let requiresFreshLocation, let showsAuthorizationPrompt):
            if requiresFreshLocation, showsAuthorizationPrompt {
                return .foregroundActivate
            }
            if requiresFreshLocation {
                return .manualRefresh
            }
            return nil
        case .currentPrepared, .explicit:
            return nil
        }
    }

    private func uploadReason(for plan: HomeIngestionPlan) -> LocationUploadReason? {
        guard uploadSource(for: plan) != nil else { return nil }
        if plan.provenance.contains(.locationChange) {
            return .locationChanged
        }
        return .locationResolved
    }

    private func shouldSyncHotFeeds(plan: HomeIngestionPlan, now: Date) -> Bool {
        guard plan.lanes.contains(.hotAlerts) else { return false }
        return alertRefreshPolicy.shouldSync(
            now: now,
            lastSync: freshness.lastHotFeedSyncAt,
            force: plan.forcedLanes.contains(.hotAlerts)
        )
    }

    private func shouldSyncSlowFeeds(plan: HomeIngestionPlan, now: Date) -> Bool {
        guard plan.lanes.contains(.slowProducts) else { return false }

        let forceSlowProducts = plan.forcedLanes.contains(.slowProducts)
        let shouldSyncMaps = mapProductRefreshPolicy.shouldSync(
            now: now,
            lastSync: freshness.lastSlowFeedSyncAt,
            force: forceSlowProducts
        )
        let shouldSyncOutlooks = outlookRefreshPolicy.shouldSync(
            now: now,
            lastSync: freshness.lastSlowFeedSyncAt,
            force: forceSlowProducts
        )
        return shouldSyncMaps || shouldSyncOutlooks
    }

    private func syncHotFeeds(
        plan: HomeIngestionPlan,
        context: LocationContext?,
        executionMode: HTTPExecutionMode
    ) async {
        if let remoteAlertContext = plan.remoteAlertContext {
            await HTTPExecutionMode.$current.withValue(executionMode) {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await self.environment.spcSync.syncMesoscaleDiscussions() }
                    group.addTask {
                        await self.environment.arcusAlertSync.syncRemoteAlert(
                            id: remoteAlertContext.alertID,
                            revisionSent: remoteAlertContext.revisionSent
                        )
                    }

                    if plan.lanes != [.hotAlerts], let context {
                        group.addTask { await self.environment.arcusAlertSync.sync(context: context) }
                    }

                    await group.waitForAll()
                }
            }
            return
        }

        guard let context else { return }
        await HTTPExecutionMode.$current.withValue(executionMode) {
            await environment.spcSync.syncMesoscaleDiscussions()
            await environment.arcusAlertSync.sync(context: context)
        }
    }

    private func syncSlowFeeds(executionMode: HTTPExecutionMode) async -> SpcMapSyncOutcome {
        await HTTPExecutionMode.$current.withValue(executionMode) {
            let mapSyncOutcome = await environment.spcSync.syncMapProductsOutcome()
            await environment.spcSync.syncConvectiveOutlooks()
            return mapSyncOutcome
        }
    }

    private func refreshWeatherIfNeeded(
        plan: HomeIngestionPlan,
        context: LocationContext?,
        now: Date,
        progress: HomeIngestionRunProgress
    ) async -> HomeWeatherRefreshResult {
        guard plan.lanes.contains(.weather) else {
            environment.logger.debug("Skipping home ingestion weather refresh reason=lane-not-requested")
            return .skipped
        }
        guard let context else {
            await progress.report(.skipped(.lane(.weather)))
            environment.logger.debug("Skipping home ingestion weather refresh reason=no-location-context")
            return .skipped
        }
        guard weatherKitRefreshPolicy.shouldSync(
            now: now,
            lastSync: freshness.lastWeatherSyncAt,
            force: plan.forcedLanes.contains(.weather)
        ) else {
            await progress.report(.skipped(.lane(.weather)))
            environment.logger.debug("Skipping home ingestion weather refresh reason=freshness")
            return .skipped
        }

        let location = CLLocation(
            latitude: context.snapshot.coordinates.latitude,
            longitude: context.snapshot.coordinates.longitude
        )
        await progress.report(.started(.lane(.weather)))
        environment.logger.info("Running home ingestion weather refresh")
        let weatherResult = await environment.weatherClient.currentWeather(for: location)
        switch weatherResult {
        case .success(let weather):
            freshness.lastWeatherSyncAt = now
            if weather != nil {
                environment.logger.debug("Finished home ingestion weather refresh result=success")
            } else {
                environment.logger.debug("Finished home ingestion weather refresh result=empty")
            }
        case .failure:
            environment.logger.debug("Finished home ingestion weather refresh result=failure")
        case .skipped:
            environment.logger.debug("Finished home ingestion weather refresh result=skipped")
        }
        await progress.report(.completed(.lane(.weather)))
        return weatherResult
    }

    private func refreshAirQuality(
        context: LocationContext?,
        plan: HomeIngestionPlan,
        executionMode: HTTPExecutionMode
    ) async -> AirQualityCurrentResponse? {
        guard let context, let querying = environment.airQualityQuerying else { return nil }
        guard shouldRefreshAirQuality(for: plan) else { return nil }

        do {
            return try await HTTPExecutionMode.$current.withValue(executionMode) {
                try await querying.fetchCurrentAirQuality(h3Cell: context.h3Cell)
            }
        } catch is CancellationError {
            return nil
        } catch {
            environment.logger.debug("AQI refresh unavailable; continuing home refresh error=\(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func shouldRefreshAirQuality(for plan: HomeIngestionPlan) -> Bool {
        plan.lanes.contains(.weather)
    }

    private func persistProjection(
        for plan: HomeIngestionPlan,
        context: LocationContext,
        snapshot: HomeSnapshot,
        weatherRefreshResult: HomeWeatherRefreshResult,
        loadedAt: Date,
        slowProductDecision: SlowProductPersistenceDecision
    ) async -> RiskProfileChange? {
        guard let projectionStore = environment.projectionStore else { return nil }
        var riskProfileChange: RiskProfileChange?

        do {
            if plan.lanes.contains(.weather) {
                switch weatherRefreshResult {
                case .success(let weather):
                    _ = try await projectionStore.updateWeather(
                        weather,
                        for: context,
                        loadedAt: loadedAt
                    )
                case .skipped, .failure:
                    break
                }
            }

            if slowProductDecision.shouldUpdateProjection {
                riskProfileChange = try await projectionStore.updateSlowProducts(
                    stormRisk: snapshot.stormRisk,
                    severeRisk: snapshot.severeRisk,
                    fireRisk: snapshot.fireRisk,
                    for: context,
                    loadedAt: loadedAt
                )
            }

            if plan.lanes.contains(.hotAlerts) {
                _ = try await projectionStore.updateHotAlerts(
                    alerts: snapshot.alerts,
                    mesos: snapshot.mesos,
                    for: context,
                    loadedAt: loadedAt
                )
            }

            guard let widgetSnapshotRefresher = environment.widgetSnapshotRefresher else {
                return riskProfileChange
            }
            if let scope = homeWidgetRefreshScope(for: plan) {
                if case .riskOrLocationProjection = scope, slowProductDecision.shouldRefreshRiskWidgets == false {
                    return riskProfileChange
                }
                try widgetSnapshotRefresher.refresh(
                    scope: scope,
                    input: .init(
                        generatedAt: loadedAt,
                        stormRisk: snapshot.stormRisk,
                        severeRisk: snapshot.severeRisk,
                        alerts: snapshot.alerts,
                        mesos: snapshot.mesos,
                        locationSummary: snapshot.locationSnapshot?.placemarkSummary
                    )
                )
            }
        } catch {
            environment.logger.error(
                "Failed to persist home projection during ingestion: \(error.localizedDescription, privacy: .public)"
            )
        }

        return riskProfileChange
    }

    private func httpExecutionMode(for plan: HomeIngestionPlan) -> HTTPExecutionMode {
        if plan.provenance.contains(.background) {
            return .background
        }
        return .foreground
    }

    private func slowProductPersistenceDecision(
        plan: HomeIngestionPlan,
        mapSyncOutcome: SpcMapSyncOutcome?
    ) -> SlowProductPersistenceDecision {
        let shouldUpdateSlowProjection = plan.lanes.contains(.slowProducts) || plan.isLocationBearing
        guard shouldUpdateSlowProjection else {
            let decision = SlowProductPersistenceDecision(
                shouldUpdateProjection: false,
                shouldRefreshRiskWidgets: true
            )
            logSlowProductPersistenceDecision(
                mapSyncOutcome: mapSyncOutcome,
                decision: decision,
                reason: "lane_not_requested"
            )
            return decision
        }

        guard plan.lanes.contains(.slowProducts) else {
            let decision = SlowProductPersistenceDecision(
                shouldUpdateProjection: true,
                shouldRefreshRiskWidgets: true
            )
            logSlowProductPersistenceDecision(
                mapSyncOutcome: mapSyncOutcome,
                decision: decision,
                reason: "location_only_refresh"
            )
            return decision
        }

        guard let mapSyncOutcome else {
            let decision = SlowProductPersistenceDecision(
                shouldUpdateProjection: true,
                shouldRefreshRiskWidgets: true
            )
            logSlowProductPersistenceDecision(
                mapSyncOutcome: nil,
                decision: decision,
                reason: "sync_outcome_unavailable"
            )
            return decision
        }

        let decision: SlowProductPersistenceDecision
        let reason: String
        switch mapSyncOutcome {
        case .accepted, .skipped:
            decision = .init(shouldUpdateProjection: true, shouldRefreshRiskWidgets: true)
            reason = mapSyncOutcome == .accepted ? "map_sync_accepted" : "map_sync_skipped"
        case .rejected, .failed:
            decision = .init(shouldUpdateProjection: false, shouldRefreshRiskWidgets: false)
            reason = mapSyncOutcome == .rejected ? "map_sync_rejected" : "map_sync_failed"
        }
        logSlowProductPersistenceDecision(
            mapSyncOutcome: mapSyncOutcome,
            decision: decision,
            reason: reason
        )
        return decision
    }

    private func logSlowProductPersistenceDecision(
        mapSyncOutcome: SpcMapSyncOutcome?,
        decision: SlowProductPersistenceDecision,
        reason: String
    ) {
        let outcome = mapSyncOutcome.map(Self.logName(for:)) ?? "none"
        environment.logger.info(
            "spc_map_persistence_projection_decision mapSyncOutcome=\(outcome, privacy: .public) reason=\(reason, privacy: .public) projection=\(decision.shouldUpdateProjection ? "updated" : "preserved", privacy: .public) widgets=\(decision.shouldRefreshRiskWidgets ? "updated" : "preserved", privacy: .public)"
        )
    }

    private static func logName(for outcome: SpcMapSyncOutcome) -> String {
        switch outcome {
        case .accepted:
            return "accepted"
        case .rejected:
            return "rejected"
        case .skipped:
            return "skipped"
        case .failed:
            return "failed"
        }
    }

}

func homeWidgetRefreshScope(for plan: HomeIngestionPlan) -> WidgetSnapshotChangeScope? {
    if plan.provenance.contains(.remoteHotAlertReceived) || plan.provenance.contains(.remoteHotAlertOpened) {
        return nil
    }

    if plan.lanes.contains(.slowProducts) || plan.isLocationBearing {
        return .riskOrLocationProjection
    }

    if plan.lanes.contains(.hotAlerts) {
        return .activeAlertProjection
    }

    return nil
}
