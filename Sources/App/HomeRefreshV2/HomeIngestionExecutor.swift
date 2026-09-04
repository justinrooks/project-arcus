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

struct HomeIngestionCorePublication: Sendable, Equatable {
    let locationSnapshot: LocationSnapshot?
    let refreshKey: LocationContext.RefreshKey?
    let weatherRefreshResult: HomeWeatherRefreshResult
    let stormRisk: StormRiskLevel?
    let severeRisk: SevereWeatherThreat?
    let fireRisk: FireRiskLevel?
    let mesos: [MdDTO]
    let alerts: [AlertDTO]
    let outlooks: [ConvectiveOutlookDTO]
    let latestOutlook: ConvectiveOutlookDTO?

    init(snapshot: HomeSnapshot) {
        locationSnapshot = snapshot.locationSnapshot
        refreshKey = snapshot.refreshKey
        weatherRefreshResult = snapshot.weatherRefreshResult
        stormRisk = snapshot.stormRisk
        severeRisk = snapshot.severeRisk
        fireRisk = snapshot.fireRisk
        mesos = snapshot.mesos
        alerts = snapshot.alerts
        outlooks = snapshot.outlooks
        latestOutlook = snapshot.latestOutlook
    }
}

enum HomeAirQualityPublicationOutcome: Sendable, Equatable {
    case replace(AirQualityCurrentResponse)
    case preserve

    var replacement: AirQualityCurrentResponse? {
        guard case .replace(let response) = self else { return nil }
        return response
    }
}

struct HomeIngestionEnrichmentPublication: Sendable, Equatable {
    let refreshKey: LocationContext.RefreshKey?
    let stormSetup: StormSetupDTO?
    let stormSetupCurrentResponse: StormSetupCurrentResponse?
    let airQualityOutcome: HomeAirQualityPublicationOutcome

    init(
        snapshot: HomeSnapshot,
        airQualityOutcome: HomeAirQualityPublicationOutcome? = nil
    ) {
        refreshKey = snapshot.refreshKey
        stormSetup = snapshot.stormSetup
        stormSetupCurrentResponse = snapshot.stormSetupCurrentResponse
        self.airQualityOutcome = airQualityOutcome ?? snapshot.airQuality.map(HomeAirQualityPublicationOutcome.replace) ?? .preserve
    }
}

struct HomeIngestionPublication: Sendable, Equatable {
    enum Stage: Sendable, Equatable {
        case core(HomeIngestionCorePublication)
        case enrichment(HomeIngestionEnrichmentPublication)
    }

    let runID: UUID
    let stage: Stage
}

typealias HomeIngestionPublicationHandler = @Sendable (HomeIngestionPublication) async -> Void

struct HomeIngestionRunProgress: Sendable {
    let runID: UUID
    let markHotAlertsCompleted: @Sendable () async -> Void
    let report: HomeIngestionProgressHandler
    let publish: HomeIngestionPublicationHandler

    init(
        runID: UUID = UUID(),
        markHotAlertsCompleted: @escaping @Sendable () async -> Void,
        report: @escaping HomeIngestionProgressHandler,
        publish: @escaping HomeIngestionPublicationHandler = { _ in }
    ) {
        self.runID = runID
        self.markHotAlertsCompleted = markHotAlertsCompleted
        self.report = report
        self.publish = publish
    }

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
    func prepareScheduledBackgroundLocationContext(
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async -> LocationContext?
}

extension HomeContextPreparing {
    func prepareScheduledBackgroundLocationContext(
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async -> LocationContext? {
        await prepareCurrentLocationContext(
            requiresFreshLocation: true,
            showsAuthorizationPrompt: false,
            uploadSource: uploadSource,
            uploadReason: uploadReason,
            authorizationTimeout: authorizationTimeout,
            locationTimeout: locationTimeout,
            maximumAcceptedLocationAge: maximumAcceptedLocationAge,
            placemarkTimeout: placemarkTimeout
        )
    }
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
    private enum HotFeedSyncOutcome: Sendable, Equatable {
        case completeLocationScopedAcceptance
        case incomplete
        case targeted

        var advancesFreshness: Bool {
            self == .completeLocationScopedAcceptance
        }

        var invalidatesFreshness: Bool {
            self == .incomplete
        }
    }

    private struct SlowProductPersistenceDecision: Sendable {
        let updatesConvective: Bool
        let updatesFire: Bool
        let convectiveSource: SpcMapSourceIdentity?
        let fireSource: SpcMapSourceIdentity?
        let reconcilesRejectedDomains: Bool
        let shouldRefreshRiskWidgets: Bool

        var shouldUpdateProjection: Bool {
            updatesConvective || updatesFire
        }
    }

    private struct SlowFeedSyncOutcome: Sendable {
        let map: SpcMapSyncOutcome?
        let outlook: SpcOutlookSyncOutcome?
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
            isScheduledBackgroundRefresh: plan.isScheduledBackgroundRefresh,
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

        var hotFeedSyncOutcome: HotFeedSyncOutcome?
        if plan.lanes.contains(.hotAlerts) {
            if shouldSyncHotFeeds(plan: plan, now: now) {
                await progress.report(.started(.lane(.hotAlerts)))
                environment.logger.info("Running home ingestion hot-alert sync mode=\(executionMode.logName, privacy: .public)")
                hotFeedSyncOutcome = await syncHotFeeds(plan: plan, context: context, executionMode: executionMode)
                try await throwIfBackgroundDeadlineExceeded()
                if hotFeedSyncOutcome?.advancesFreshness == true {
                    freshness.lastHotFeedSyncAt = now
                } else if hotFeedSyncOutcome?.invalidatesFreshness == true {
                    freshness.lastHotFeedSyncAt = nil
                }
                await progress.report(.completed(.lane(.hotAlerts)))
                environment.logger.debug("Finished home ingestion hot-alert sync")
            } else {
                await progress.report(.skipped(.lane(.hotAlerts)))
                environment.logger.debug("Skipping home ingestion hot-alert sync reason=freshness")
            }
        }

        await progress.markHotAlertsCompleted()

        var slowFeedSyncOutcome: SlowFeedSyncOutcome?
        if plan.lanes.contains(.slowProducts) {
            let slowFeedAdmission = slowFeedAdmission(plan: plan, now: now)
            if slowFeedAdmission.maps || slowFeedAdmission.outlooks {
                await progress.report(.started(.lane(.slowProducts)))
                environment.logger.info("Running home ingestion slow-product sync mode=\(executionMode.logName, privacy: .public)")
                slowFeedSyncOutcome = await syncSlowFeeds(
                    maps: slowFeedAdmission.maps,
                    outlooks: slowFeedAdmission.outlooks,
                    executionMode: executionMode
                )
                try await throwIfBackgroundDeadlineExceeded()
                if let mapOutcome = slowFeedSyncOutcome?.map {
                    if mapOutcome.isFullyAccepted {
                        freshness.lastMapProductSyncAt = now
                    } else if mapOutcome != .skipped {
                        freshness.lastMapProductSyncAt = nil
                    }
                }
                if let outlookOutcome = slowFeedSyncOutcome?.outlook {
                    freshness.lastOutlookSyncAt = outlookOutcome == .accepted ? now : nil
                }
                await progress.report(.completed(.lane(.slowProducts)))
                environment.logger.debug("Finished home ingestion slow-product sync")
            } else {
                await progress.report(.skipped(.lane(.slowProducts)))
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
        if let context {
            snapshot.riskComparisonLocationKey = HomeProjection.riskComparisonLocationKey(for: context)
            let slowProductDecision = slowProductPersistenceDecision(
                plan: plan,
                mapSyncOutcome: slowFeedSyncOutcome?.map
            )
            snapshot = await reconcilingRejectedRiskDomains(
                in: snapshot,
                for: context,
                decision: slowProductDecision
            )
            let riskProfileChange = await persistProjection(
                for: plan,
                context: context,
                snapshot: snapshot,
                weatherRefreshResult: weatherRefresh,
                loadedAt: now,
                slowProductDecision: slowProductDecision,
                acceptsHotFeedSnapshot: hotFeedSyncOutcome?.advancesFreshness == true
            )
            snapshot.riskProfileChange = riskProfileChange
        }

        freshness.lastResolvedRefreshKey = snapshot.refreshKey
        await progress.publish(
            HomeIngestionPublication(
                runID: progress.runID,
                stage: .core(.init(snapshot: snapshot))
            )
        )

        let coreSnapshot = snapshot
        guard try await shouldAdmitStormSetupEnrichment(executionMode: executionMode) else {
            return coreSnapshot
        }
        async let stormSetupRefreshTask = stormSetupIngestion.refresh(
            context: context,
            snapshot: coreSnapshot,
            plan: plan,
            executionMode: executionMode
        )
        async let airQualityTask = refreshAirQuality(
            context: context,
            plan: plan,
            executionMode: executionMode
        )
        let (stormSetupRefresh, airQualityOutcome) = await (stormSetupRefreshTask, airQualityTask)
        try await throwIfBackgroundEnrichmentCancelled(executionMode: executionMode)
        snapshot.stormSetupRefreshResult = stormSetupRefresh.result
        snapshot.stormSetupCurrentResponse = stormSetupRefresh.currentResponse
        snapshot.stormSetup = stormSetupRefresh.stormSetup
        snapshot.airQuality = airQualityOutcome.replacement
        await progress.publish(
            HomeIngestionPublication(
                runID: progress.runID,
                stage: .enrichment(.init(snapshot: snapshot, airQualityOutcome: airQualityOutcome))
            )
        )
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        environment.logger.info(
            "Completed home ingestion plan={\(plan.logDescription)} result=success durationMs=\(durationMs, privacy: .public) hasLocationSnapshot=\((snapshot.locationSnapshot != nil), privacy: .public) alerts=\(snapshot.alerts.count, privacy: .public) mesos=\(snapshot.mesos.count, privacy: .public) outlooks=\(snapshot.outlooks.count, privacy: .public) weather=\((snapshot.weather != nil), privacy: .public)"
        )
        return snapshot
    }

    private func resolveContext(
        for request: HomeIngestionLocationRequest,
        isScheduledBackgroundRefresh: Bool,
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
        using locationSession: any HomeContextPreparing
    ) async -> LocationContext? {
        if isScheduledBackgroundRefresh {
            return await locationSession.prepareScheduledBackgroundLocationContext(
                uploadSource: uploadSource,
                uploadReason: uploadReason,
                authorizationTimeout: 30,
                locationTimeout: 12,
                maximumAcceptedLocationAge: 5 * 60,
                placemarkTimeout: 8
            )
        }
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

    private func slowFeedAdmission(plan: HomeIngestionPlan, now: Date) -> (maps: Bool, outlooks: Bool) {
        guard plan.lanes.contains(.slowProducts) else { return (false, false) }

        let forceSlowProducts = plan.forcedLanes.contains(.slowProducts)
        let maps = mapProductRefreshPolicy.shouldSync(
            now: now,
            lastSync: freshness.lastMapProductSyncAt,
            force: forceSlowProducts
        )
        let outlooks = outlookRefreshPolicy.shouldSync(
            now: now,
            lastSync: freshness.lastOutlookSyncAt,
            force: forceSlowProducts
        )
        return (maps, outlooks)
    }

    private func syncHotFeeds(
        plan: HomeIngestionPlan,
        context: LocationContext?,
        executionMode: HTTPExecutionMode
    ) async -> HotFeedSyncOutcome {
        if let remoteAlertContext = plan.remoteAlertContext {
            await HTTPExecutionMode.$current.withValue(executionMode) {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { _ = await self.environment.spcSync.syncMesoscaleDiscussions() }
                    group.addTask {
                        _ = await self.environment.arcusAlertSync.syncRemoteAlert(
                            id: remoteAlertContext.alertID,
                            revisionSent: remoteAlertContext.revisionSent
                        )
                    }

                    if plan.lanes != [.hotAlerts], let context {
                        group.addTask { _ = await self.environment.arcusAlertSync.sync(context: context) }
                    }

                    await group.waitForAll()
                }
            }
            return .targeted
        }

        guard let context else { return .incomplete }
        return await HTTPExecutionMode.$current.withValue(executionMode) {
            async let mesoSync = environment.spcSync.syncMesoscaleDiscussions()
            async let alertSync = environment.arcusAlertSync.sync(context: context)
            let (mesoOutcome, alertOutcome) = await (mesoSync, alertSync)
            return mesoOutcome == .accepted && alertOutcome == .accepted
                ? .completeLocationScopedAcceptance
                : .incomplete
        }
    }

    private func syncSlowFeeds(
        maps: Bool,
        outlooks: Bool,
        executionMode: HTTPExecutionMode
    ) async -> SlowFeedSyncOutcome {
        await HTTPExecutionMode.$current.withValue(executionMode) {
            async let mapOutcome = maps ? environment.spcSync.syncMapProductsOutcome() : nil
            async let outlookOutcome = outlooks ? environment.spcSync.syncConvectiveOutlooks() : nil
            return await .init(map: mapOutcome, outlook: outlookOutcome)
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
    ) async -> HomeAirQualityPublicationOutcome {
        guard shouldRefreshAirQuality(for: plan, executionMode: executionMode) else { return .preserve }
        guard let context, let querying = environment.airQualityQuerying else { return .preserve }

        do {
            let response = try await HTTPExecutionMode.$current.withValue(executionMode) {
                try await querying.fetchCurrentAirQuality(h3Cell: context.h3Cell)
            }
            guard let response else {
                return .preserve
            }
            guard let projectionStore = environment.projectionStore else {
                environment.logger.error("AQI persistence unavailable; publishing live response")
                return .replace(response)
            }

            do {
                let accepted = try await projectionStore.updateAirQuality(
                    response,
                    for: context,
                    loadedAt: .now
                )
                guard let acceptedAirQuality = accepted.airQuality else {
                    environment.logger.error(
                        "AQI persistence returned no accepted response; publishing live response"
                    )
                    return .replace(response)
                }
                return .replace(acceptedAirQuality)
            } catch is CancellationError {
                return .preserve
            } catch {
                environment.logger.error(
                    "AQI persistence unavailable; publishing live response error=\(String(describing: error), privacy: .public)"
                )
                return .replace(response)
            }
        } catch is CancellationError {
            return .preserve
        } catch {
            environment.logger.debug("AQI refresh unavailable; continuing home refresh error=\(String(describing: error), privacy: .public)")
            return .preserve
        }
    }

    private func shouldRefreshAirQuality(
        for plan: HomeIngestionPlan,
        executionMode: HTTPExecutionMode
    ) -> Bool {
        plan.lanes.contains(.weather) && executionMode == .foreground
    }

    private func persistProjection(
        for plan: HomeIngestionPlan,
        context: LocationContext,
        snapshot: HomeSnapshot,
        weatherRefreshResult: HomeWeatherRefreshResult,
        loadedAt: Date,
        slowProductDecision: SlowProductPersistenceDecision,
        acceptsHotFeedSnapshot: Bool
    ) async -> RiskProfileChange? {
        guard let projectionStore = environment.projectionStore else { return nil }
        var riskProfileChange: RiskProfileChange?
        var committedProjection: HomeProjectionRecord?

        do {
            let weather: SummaryWeather??
            if case .success(let refreshedWeather) = weatherRefreshResult {
                weather = .some(refreshedWeather)
            } else {
                weather = nil
            }
            let slowProducts = slowProductDecision.shouldUpdateProjection
                ? (
                    stormRisk: snapshot.stormRisk,
                    severeRisk: snapshot.severeRisk,
                    fireRisk: snapshot.fireRisk
                )
                : nil
            let hotAlerts = acceptsHotFeedSnapshot
                ? (alerts: snapshot.alerts, mesos: snapshot.mesos)
                : nil

            if weather != nil || slowProducts != nil || hotAlerts != nil {
                let acknowledgement = try await projectionStore.commitCore(
                    .init(
                        weather: weather,
                        slowProducts: slowProducts,
                        updatesConvectiveRisk: slowProductDecision.updatesConvective,
                        updatesFireRisk: slowProductDecision.updatesFire,
                        convectiveSource: slowProductDecision.convectiveSource,
                        fireSource: slowProductDecision.fireSource,
                        hotAlerts: hotAlerts
                    ),
                    for: context,
                    loadedAt: loadedAt
                )
                riskProfileChange = acknowledgement.riskProfileChange
                committedProjection = acknowledgement.record
            }

            guard let widgetSnapshotRefresher = environment.widgetSnapshotRefresher else {
                return riskProfileChange
            }
            if let scope = homeWidgetRefreshScope(for: plan) {
                if case .riskOrLocationProjection = scope, slowProductDecision.shouldRefreshRiskWidgets == false {
                    return riskProfileChange
                }
                if case .activeAlertProjection = scope, acceptsHotFeedSnapshot == false {
                    return riskProfileChange
                }
                let projection: HomeProjectionRecord?
                if let committedProjection {
                    projection = committedProjection
                } else {
                    projection = try await projectionStore.projection(for: context)
                }
                guard let projection,
                      let hotSnapshotTimestamp = projection.lastHotAlertsLoadAt else {
                    return riskProfileChange
                }
                try widgetSnapshotRefresher.refresh(
                    scope: scope,
                    input: .init(
                        generatedAt: loadedAt,
                        snapshotTimestamp: hotSnapshotTimestamp,
                        stormRisk: snapshot.stormRisk,
                        severeRisk: snapshot.severeRisk,
                        alerts: projection.activeAlerts,
                        mesos: projection.activeMesos,
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

    private func reconcilingRejectedRiskDomains(
        in snapshot: HomeSnapshot,
        for context: LocationContext,
        decision: SlowProductPersistenceDecision
    ) async -> HomeSnapshot {
        guard decision.reconcilesRejectedDomains else { return snapshot }

        var reconciled = snapshot
        let projection: HomeProjectionRecord?
        do {
            projection = try await environment.projectionStore?.projection(for: context)
        } catch {
            projection = nil
            environment.logger.error(
                "Failed to load prior home projection while preserving rejected SPC domains: \(error.localizedDescription, privacy: .public)"
            )
        }

        if decision.updatesConvective == false {
            reconciled.stormRisk = projection?.stormRisk
            reconciled.severeRisk = projection?.severeRisk
        }
        if decision.updatesFire == false {
            reconciled.fireRisk = projection?.fireRisk
        }
        return reconciled
    }

    private func httpExecutionMode(for plan: HomeIngestionPlan) -> HTTPExecutionMode {
        if plan.provenance.contains(.background) {
            return .background
        }
        return .foreground
    }

    private func throwIfBackgroundDeadlineExceeded() async throws {
        try await BackgroundRefreshExecutionContext.current?.deadlineState.throwIfExceeded()
    }

    private func shouldAdmitStormSetupEnrichment(executionMode: HTTPExecutionMode) async throws -> Bool {
        guard executionMode == .background, let executionContext = BackgroundRefreshExecutionContext.current else {
            return true
        }

        let admission = executionContext.budget.admission(
            for: .seconds(environment.stormSetupForegroundTimeout),
            at: ContinuousClock().now,
            isCancelled: Task.isCancelled
        )
        switch admission {
        case .admitted:
            return true
        case .cancelled:
            throw CancellationError()
        case .workDeadlineReached, .insufficientTime:
            return false
        }
    }

    private func throwIfBackgroundEnrichmentCancelled(executionMode: HTTPExecutionMode) async throws {
        guard executionMode == .background else { return }
        try Task.checkCancellation()
        try await throwIfBackgroundDeadlineExceeded()
    }

    private func slowProductPersistenceDecision(
        plan: HomeIngestionPlan,
        mapSyncOutcome: SpcMapSyncOutcome?
    ) -> SlowProductPersistenceDecision {
        let shouldUpdateSlowProjection = plan.lanes.contains(.slowProducts) || plan.isLocationBearing
        guard shouldUpdateSlowProjection else {
            let decision = SlowProductPersistenceDecision(
                updatesConvective: false,
                updatesFire: false,
                convectiveSource: nil,
                fireSource: nil,
                reconcilesRejectedDomains: false,
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
                updatesConvective: true,
                updatesFire: true,
                convectiveSource: nil,
                fireSource: nil,
                reconcilesRejectedDomains: false,
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
                updatesConvective: true,
                updatesFire: true,
                convectiveSource: nil,
                fireSource: nil,
                reconcilesRejectedDomains: false,
                shouldRefreshRiskWidgets: true
            )
            logSlowProductPersistenceDecision(
                mapSyncOutcome: nil,
                decision: decision,
                reason: "sync_outcome_unavailable"
            )
            return decision
        }

        let updatesConvective = mapSyncOutcome.convective.authorizesProjection
        let updatesFire = mapSyncOutcome.fire.authorizesProjection
        let decision = SlowProductPersistenceDecision(
            updatesConvective: updatesConvective,
            updatesFire: updatesFire,
            convectiveSource: mapSyncOutcome.convective == .accepted ? mapSyncOutcome.convectiveSource : nil,
            fireSource: mapSyncOutcome.fire == .accepted ? mapSyncOutcome.fireSource : nil,
            reconcilesRejectedDomains: updatesConvective == false || updatesFire == false,
            shouldRefreshRiskWidgets: updatesConvective || updatesFire
        )
        logSlowProductPersistenceDecision(
            mapSyncOutcome: mapSyncOutcome,
            decision: decision,
            reason: "map_sync_domain_authority"
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
            "spc_map_persistence_projection_decision mapSyncOutcome=\(outcome, privacy: .public) reason=\(reason, privacy: .public) convective=\(decision.updatesConvective ? "updated" : "preserved", privacy: .public) fire=\(decision.updatesFire ? "updated" : "preserved", privacy: .public) widgets=\(decision.shouldRefreshRiskWidgets ? "updated" : "preserved", privacy: .public)"
        )
    }

    private static func logName(for outcome: SpcMapSyncOutcome) -> String {
        "convective=\(logName(for: outcome.convective)),fire=\(logName(for: outcome.fire))"
    }

    private static func logName(for outcome: SpcMapSyncDomainOutcome) -> String {
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
