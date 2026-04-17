//
//  HomeIngestionExecutor.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import CoreLocation
import Foundation
import OSLog

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
    func run(plan: HomeIngestionPlan) async throws -> HomeSnapshot
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

    func run(plan: HomeIngestionPlan) async throws -> HomeSnapshot {
        let context = await resolveContext(for: plan.locationRequest, using: environment.locationSession)
        let now = Date()
        let executionMode = httpExecutionMode(for: plan)

        if shouldSyncHotFeeds(plan: plan, now: now) {
            await syncHotFeeds(context: context, executionMode: executionMode)
            freshness.lastHotFeedSyncAt = now
        }

        if shouldSyncSlowFeeds(plan: plan, now: now) {
            await syncSlowFeeds(executionMode: executionMode)
            freshness.lastSlowFeedSyncAt = now
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
        context: LocationContext?,
        executionMode: HTTPExecutionMode
    ) async {
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
        guard plan.lanes.contains(.weather) else { return nil }
        guard let context else { return nil }
        guard weatherKitRefreshPolicy.shouldSync(
            now: now,
            lastSync: freshness.lastWeatherSyncAt,
            force: plan.forcedLanes.contains(.weather)
        ) else {
            return nil
        }

        let location = CLLocation(
            latitude: context.snapshot.coordinates.latitude,
            longitude: context.snapshot.coordinates.longitude
        )
        let weather = await environment.weatherClient.currentWeather(for: location)
        if weather != nil {
            freshness.lastWeatherSyncAt = now
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
