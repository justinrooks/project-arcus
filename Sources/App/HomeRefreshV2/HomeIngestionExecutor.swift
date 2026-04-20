//
//  HomeIngestionExecutor.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import CoreLocation
import Foundation
import OSLog

struct HomeIngestionRunProgress: Sendable {
    let markHotAlertsCompleted: @Sendable () async -> Void

    static let none = HomeIngestionRunProgress(markHotAlertsCompleted: {})
}

@MainActor
protocol HomeContextPreparing: AnyObject, Sendable {
    func prepareCurrentLocationContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
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
    struct Environment {
        let logger: Logger
        let spcSync: any SpcSyncing
        let arcusAlertSync: any ArcusAlertSyncing
        let weatherClient: any HomeWeatherQuerying
        let locationSession: any HomeContextPreparing
        let snapshotStore: any HomeSnapshotReading
        let projectionStore: HomeProjectionStore?
    }

    private let environment: Environment
    private let alertRefreshPolicy: AlertRefreshPolicy
    private let mapProductRefreshPolicy: MapProductRefreshPolicy
    private let outlookRefreshPolicy: OutlookRefreshPolicy
    private let weatherKitRefreshPolicy: WeatherKitRefreshPolicy

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
    }

    func run(plan: HomeIngestionPlan, progress: HomeIngestionRunProgress = .none) async throws -> HomeSnapshot {
        let startedAt = Date()
        environment.logger.info("Executing home ingestion plan={\(plan.logDescription)}")
        let context = await resolveContext(for: plan.locationRequest, using: environment.locationSession)
        let now = Date()
        let executionMode = httpExecutionMode(for: plan)
        environment.logger.debug(
            "Home ingestion context resolution finished available=\((context != nil), privacy: .public) mode=\(executionMode.logName, privacy: .public)"
        )

        if shouldSyncHotFeeds(plan: plan, now: now) {
            environment.logger.info("Running home ingestion hot-alert sync mode=\(executionMode.logName, privacy: .public)")
            await syncHotFeeds(plan: plan, context: context, executionMode: executionMode)
            freshness.lastHotFeedSyncAt = now
            environment.logger.debug("Finished home ingestion hot-alert sync")
        } else {
            environment.logger.debug("Skipping home ingestion hot-alert sync reason=freshness")
        }

        await progress.markHotAlertsCompleted()

        if shouldSyncSlowFeeds(plan: plan, now: now) {
            environment.logger.info("Running home ingestion slow-product sync mode=\(executionMode.logName, privacy: .public)")
            await syncSlowFeeds(executionMode: executionMode)
            freshness.lastSlowFeedSyncAt = now
            environment.logger.debug("Finished home ingestion slow-product sync")
        } else {
            environment.logger.debug("Skipping home ingestion slow-product sync reason=freshness")
        }

        let weather = await refreshWeatherIfNeeded(
            plan: plan,
            context: context,
            now: now
        )

        let snapshot = try await environment.snapshotStore.loadSnapshot(
            for: context,
            weather: weather,
            freshness: freshness
        )

        if let context {
            await persistProjection(
                for: plan,
                context: context,
                snapshot: snapshot,
                weather: weather,
                loadedAt: now
            )
        }

        freshness.lastResolvedRefreshKey = snapshot.refreshKey
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        environment.logger.info(
            "Completed home ingestion plan={\(plan.logDescription)} result=success durationMs=\(durationMs, privacy: .public) hasLocationSnapshot=\((snapshot.locationSnapshot != nil), privacy: .public) watches=\(snapshot.watches.count, privacy: .public) mesos=\(snapshot.mesos.count, privacy: .public) outlooks=\(snapshot.outlooks.count, privacy: .public) weather=\((snapshot.weather != nil), privacy: .public)"
        )
        return snapshot
    }

    private func resolveContext(
        for request: HomeIngestionLocationRequest,
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
                authorizationTimeout: 30,
                locationTimeout: 12,
                maximumAcceptedLocationAge: 5 * 60,
                placemarkTimeout: 8
            )
        case .prepare(let requiresFreshLocation, let showsAuthorizationPrompt):
            return await locationSession.prepareCurrentLocationContext(
                requiresFreshLocation: requiresFreshLocation,
                showsAuthorizationPrompt: showsAuthorizationPrompt,
                authorizationTimeout: 30,
                locationTimeout: 12,
                maximumAcceptedLocationAge: 5 * 60,
                placemarkTimeout: 8
            )
        case .explicit(let context):
            return context
        }
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

    private func syncSlowFeeds(executionMode: HTTPExecutionMode) async {
        await HTTPExecutionMode.$current.withValue(executionMode) {
            await environment.spcSync.syncMapProducts()
            await environment.spcSync.syncConvectiveOutlooks()
        }
    }

    private func refreshWeatherIfNeeded(
        plan: HomeIngestionPlan,
        context: LocationContext?,
        now: Date
    ) async -> SummaryWeather? {
        guard plan.lanes.contains(.weather) else {
            environment.logger.debug("Skipping home ingestion weather refresh reason=lane-not-requested")
            return nil
        }
        guard let context else {
            environment.logger.debug("Skipping home ingestion weather refresh reason=no-location-context")
            return nil
        }
        guard weatherKitRefreshPolicy.shouldSync(
            now: now,
            lastSync: freshness.lastWeatherSyncAt,
            force: plan.forcedLanes.contains(.weather)
        ) else {
            environment.logger.debug("Skipping home ingestion weather refresh reason=freshness")
            return nil
        }

        let location = CLLocation(
            latitude: context.snapshot.coordinates.latitude,
            longitude: context.snapshot.coordinates.longitude
        )
        environment.logger.info("Running home ingestion weather refresh")
        let weather = await environment.weatherClient.currentWeather(for: location)
        if weather != nil {
            freshness.lastWeatherSyncAt = now
            environment.logger.debug("Finished home ingestion weather refresh result=success")
        } else {
            environment.logger.debug("Finished home ingestion weather refresh result=empty")
        }
        return weather
    }

    private func persistProjection(
        for plan: HomeIngestionPlan,
        context: LocationContext,
        snapshot: HomeSnapshot,
        weather: SummaryWeather?,
        loadedAt: Date
    ) async {
        guard let projectionStore = environment.projectionStore else { return }

        do {
            if plan.lanes.contains(.weather), let weather {
                _ = try await projectionStore.updateWeather(
                    weather,
                    for: context,
                    loadedAt: loadedAt
                )
            }

            if plan.lanes.contains(.slowProducts) || plan.isLocationBearing {
                _ = try await projectionStore.updateSlowProducts(
                    stormRisk: snapshot.stormRisk,
                    severeRisk: snapshot.severeRisk,
                    fireRisk: snapshot.fireRisk,
                    for: context,
                    loadedAt: loadedAt
                )
            }

            if plan.lanes.contains(.hotAlerts) {
                _ = try await projectionStore.updateHotAlerts(
                    watches: snapshot.watches,
                    mesos: snapshot.mesos,
                    for: context,
                    loadedAt: loadedAt
                )
            }
        } catch {
            environment.logger.error(
                "Failed to persist home projection during ingestion: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func httpExecutionMode(for plan: HomeIngestionPlan) -> HTTPExecutionMode {
        if plan.provenance.contains(.background) {
            return .background
        }
        return .foreground
    }
}
