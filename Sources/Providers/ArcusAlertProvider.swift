//
//  ArcusAlertProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation
import OSLog

actor ArcusAlertProvider {
    let logger = Logger.providersArcus
    let client: ArcusClient
    let alertRepo: AlertRepo
    let feedStateStore: FeedStateStore?
    private var inFlightSyncs: [LocationContext.RefreshKey: Task<ArcusLocationSyncOutcome, Never>] = [:]
    private struct RemoteSyncKey: Hashable {
        let id: String
        let revisionSent: Date?
    }
    private var inFlightRemoteSyncs: [RemoteSyncKey: Task<ArcusRemoteAlertSyncOutcome, Never>] = [:]
    private(set) var coalescedRemoteSyncCount = 0
    
    init(alertRepo: AlertRepo, client: ArcusClient, feedStateStore: FeedStateStore? = nil) {
        self.client = client
        self.alertRepo = alertRepo
        self.feedStateStore = feedStateStore
    }
}

extension ArcusAlertProvider: ArcusAlertSyncing {
    func sync(context: LocationContext) async -> ArcusLocationSyncOutcome {
        let key = context.refreshKey
        if let inFlight = inFlightSyncs[key] {
            logger.debug("Arcus alert sync already in-flight for current location scope; joining existing task")
            let outcome = await inFlight.value
            return Task.isCancelled ? .cancelled : outcome
        }

        let alertRepo = self.alertRepo
        let client = self.client
        let logger = self.logger
        logger.info("Arcus alert sync started scope=location-context")
        let task = Task { () -> ArcusLocationSyncOutcome in
            do {
                let source = try await alertRepo.refresh(
                    using: client,
                    for: context.grid.countyCode ?? "",
                    and: context.grid.fireZone ?? "",
                    and: context.grid.forecastZone ?? "",
                    in: context.h3Cell
                )
                let outcome = Self.outcome(for: source)
                await record(source: source)
                return outcome
            } catch is CancellationError {
                logger.notice("Arcus alert sync cancelled scope=location-context")
                await record(failure: .cancelled)
                return .cancelled
            } catch ArcusError.parsingError {
                logger.error("Arcus alert sync rejected scope=location-context")
                await record(failure: .rejected)
                return .rejected
            } catch {
                logger.error("Error syncing Arcus alerts: \(error, privacy: .public)")
                await record(failure: .transport)
                return .failed
            }
        }

        inFlightSyncs[key] = task
        let outcome = await task.value
        inFlightSyncs[key] = nil
        logger.info("Arcus alert sync finished scope=location-context outcome=\(String(describing: outcome), privacy: .public)")
        return Task.isCancelled ? .cancelled : outcome
    }

    func syncRemoteAlert(id: String, revisionSent: Date?) async -> ArcusRemoteAlertSyncOutcome {
        let key = RemoteSyncKey(id: ArcusAlertIdentifier.canonical(id), revisionSent: revisionSent)
        if let task = inFlightRemoteSyncs[key] {
            coalescedRemoteSyncCount += 1
            logger.debug("Targeted alert sync joined existing request count=\(self.coalescedRemoteSyncCount, privacy: .public)")
            let outcome = await task.value
            return Task.isCancelled ? .cancelled : outcome
        }
        let task = Task { await performRemoteAlertSync(id: key.id, revisionSent: revisionSent) }
        inFlightRemoteSyncs[key] = task
        let outcome = await task.value
        inFlightRemoteSyncs[key] = nil
        return Task.isCancelled ? .cancelled : outcome
    }

    private func performRemoteAlertSync(id: String, revisionSent: Date?) async -> ArcusRemoteAlertSyncOutcome {
        logger.info("Arcus alert sync started scope=targeted-alert")
        do {
            let source = try await alertRepo.refreshAlert(using: client, id: id, revisionSent: revisionSent)
            let outcome = Self.remoteOutcome(for: source)
            await record(source: source, feedID: "arcus.alert")
            logger.info("Arcus alert sync finished scope=targeted-alert outcome=\(String(describing: outcome), privacy: .public)")
            return outcome
        } catch is CancellationError {
            logger.notice("Arcus alert sync cancelled scope=targeted-alert")
            await record(failure: .cancelled, feedID: "arcus.alert")
            return .cancelled
        } catch ArcusError.parsingError {
            logger.error("Arcus alert sync rejected scope=targeted-alert")
            await record(failure: .rejected, feedID: "arcus.alert")
            return .rejected
        } catch {
            logger.error("Error syncing targeted Arcus alert: \(error, privacy: .public)")
            await record(failure: .transport, feedID: "arcus.alert")
            return .failed
        }
    }

    private static func outcome(for source: HTTPResponse.Source) -> ArcusLocationSyncOutcome {
        switch source {
        case .live, .cacheRevalidated304:
            source == .live ? .live : .revalidated
        case .localCache:
            .localCache
        case .cacheFallback:
            .errorFallback
        }
    }

    private static func remoteOutcome(for source: HTTPResponse.Source) -> ArcusRemoteAlertSyncOutcome {
        switch source {
        case .live, .cacheRevalidated304:
            source == .live ? .live : .revalidated
        case .localCache:
            .localCache
        case .cacheFallback:
            .errorFallback
        }
    }

    private func record(
        source: HTTPResponse.Source? = nil,
        failure: FeedStateFailureClassification? = nil,
        feedID: String = "arcus.alerts"
    ) async {
        guard let feedStateStore else { return }
        let now = Date.now
        let transportSource = source.map(Self.feedStateTransportSource(for:))
        let networkSucceeded = source == .live || source == .cacheRevalidated304
        let canonicalAccepted = source != nil
        do {
            _ = try await feedStateStore.update(
                .init(
                    feedID: feedID,
                    attemptedAt: now,
                    networkSucceededAt: networkSucceeded ? now : nil,
                    canonicalAcceptedAt: canonicalAccepted ? now : nil,
                    validAt: canonicalAccepted ? now : nil,
                    transportSource: transportSource,
                    failure: failure ?? (source == .cacheFallback ? .transport : nil)
                )
            )
        } catch {
            logger.error("Unable to record Arcus feed state feed=\(feedID, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }
    private static func feedStateTransportSource(for source: HTTPResponse.Source) -> FeedStateTransportSource {
        switch source {
        case .live:
            .live
        case .cacheRevalidated304:
            .revalidated
        case .localCache:
            .localCache
        case .cacheFallback:
            .errorFallback
        }
    }
}

extension ArcusAlertProvider: RemoteAlertResolving {
    func resolveNotificationAlert(_ context: HomeRemoteAlertContext) async throws -> AlertDTO? {
        let startedAt = ContinuousClock.now
        let cached = try await alertRepo.notificationAlert(id: context.alertID)
        if let cached, cached.satisfiesNotificationRevision(context) {
            logger.info("Notification open cache hit elapsed=\(String(describing: startedAt.duration(to: .now)), privacy: .public)")
            return cached
        }
        logger.info("Notification open cache miss elapsed=\(String(describing: startedAt.duration(to: .now)), privacy: .public)")
        try Task.checkCancellation()
        _ = await syncRemoteAlert(id: context.alertID, revisionSent: context.revisionSent)
        try Task.checkCancellation()
        let accepted = try await alertRepo.notificationAlert(id: context.alertID)
        let resolved = accepted.flatMap { $0.satisfiesNotificationRevision(context) ? $0 : nil }
        logger.info("Notification open repository resolved available=\(resolved != nil, privacy: .public) elapsed=\(String(describing: startedAt.duration(to: .now)), privacy: .public)")
        return resolved
    }
}

extension AlertDTO {
    func satisfiesNotificationRevision(_ context: HomeRemoteAlertContext) -> Bool {
        guard ArcusAlertIdentifier.canonical(id) == ArcusAlertIdentifier.canonical(context.alertID),
              let currentRevisionSent else { return false }
        return context.revisionSent.map { currentRevisionSent >= $0 } ?? true
    }
}

extension ArcusAlertProvider: ArcusAlertQuerying {
    func getActiveAlerts(context: LocationContext) async throws -> [AlertDTO] {
        try await alertRepo.active(
            countyCode: context.grid.countyCode ?? "",
            fireZone: context.grid.fireZone ?? "",
            forecastZone: context.grid.forecastZone ?? "",
            cell: context.h3Cell
        )
    }

    func getActiveWarningGeometries(on date: Date) async throws -> [ActiveWarningGeometry] {
        try await alertRepo.activeWarningGeometries(on: date)
    }

    func getAlert(id: String) async throws -> AlertDTO? {
        try await alertRepo.alert(id: id)
    }
}

extension ArcusAlertProvider: Cleaning {
    func cleanup(daysToKeep: Int = 3) async {
        do {
            try await alertRepo.purge()
        } catch {
            logger.error("Error cleaning up Arcus-backed alert data: \(error.localizedDescription, privacy: .public)")
        }
    }
}
