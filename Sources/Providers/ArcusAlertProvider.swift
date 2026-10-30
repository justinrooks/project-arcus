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
    private struct LocationSyncKey: Hashable {
        let location: LocationContext.RefreshKey
        let deadline: ContinuousClock.Instant?
    }
    private struct SyncRun<Outcome: Sendable> {
        let task: Task<Outcome, Never>
        var owners: Set<UUID>
    }
    private var inFlightSyncs: [LocationSyncKey: SyncRun<ArcusLocationSyncOutcome>] = [:]
    private struct RemoteSyncKey: Hashable {
        let id: String
        let revisionSent: Date?
        let deadline: ContinuousClock.Instant?
    }
    private struct RemoteAcceptance { let alert: AlertDTO? }
    private struct RemoteSyncRun {
        let task: Task<ArcusRemoteAlertSyncOutcome, Never>
        var owners: Set<UUID>
        var observers: [UUID: @Sendable (AlertDTO?) async -> Void]
        var acceptance: RemoteAcceptance?
    }
    private var inFlightRemoteSyncs: [RemoteSyncKey: RemoteSyncRun] = [:]
    private(set) var coalescedRemoteSyncCount = 0
    
    init(alertRepo: AlertRepo, client: ArcusClient, feedStateStore: FeedStateStore? = nil) {
        self.client = client
        self.alertRepo = alertRepo
        self.feedStateStore = feedStateStore
    }
}

extension ArcusAlertProvider: ArcusAlertSyncing {
    func sync(context: LocationContext) async -> ArcusLocationSyncOutcome {
        let key = LocationSyncKey(location: context.refreshKey,
            deadline: BackgroundRefreshExecutionContext.current?.budget.workDeadline)
        let owner = UUID()
        if var inFlight = inFlightSyncs[key] {
            inFlight.owners.insert(owner)
            inFlightSyncs[key] = inFlight
            defer { removeLocationOwner(owner, key: key) }
            logger.debug("Arcus alert sync already in-flight for current location scope; joining existing task")
            let joinedTask = inFlight.task
            let outcome = await withTaskCancellationHandler {
                await joinedTask.value
            } onCancel: {
                Task { await self.removeLocationOwner(owner, key: key) }
            }
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

        inFlightSyncs[key] = SyncRun(task: task, owners: [owner])
        defer { removeLocationOwner(owner, key: key) }
        let outcome = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { await self.removeLocationOwner(owner, key: key) }
        }
        logger.info("Arcus alert sync finished scope=location-context outcome=\(String(describing: outcome), privacy: .public)")
        return Task.isCancelled ? .cancelled : outcome
    }

    func syncRemoteAlert(id: String, revisionSent: Date?) async -> ArcusRemoteAlertSyncOutcome {
        guard !Task.isCancelled else { return .cancelled }
        let key = RemoteSyncKey(id: ArcusAlertIdentifier.canonical(id), revisionSent: revisionSent,
            deadline: BackgroundRefreshExecutionContext.current?.budget.workDeadline)
        let owner = UUID()
        let task: Task<ArcusRemoteAlertSyncOutcome, Never>
        if var run = inFlightRemoteSyncs[key] {
            coalescedRemoteSyncCount += 1
            run.owners.insert(owner)
            run.observers[owner] = RemoteAlertAcceptance.observer
            inFlightRemoteSyncs[key] = run
            task = run.task
            if let acceptance = run.acceptance, let observer = RemoteAlertAcceptance.observer {
                await observer(acceptance.alert)
            }
        } else {
            task = Task { await performRemoteAlertSync(key: key) }
            var observers: [UUID: @Sendable (AlertDTO?) async -> Void] = [:]
            observers[owner] = RemoteAlertAcceptance.observer
            inFlightRemoteSyncs[key] = RemoteSyncRun(task: task, owners: [owner], observers: observers)
        }
        defer { removeRemoteOwner(owner, key: key) }
        let outcome = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { await self.removeRemoteOwner(owner, key: key) }
        }
        return Task.isCancelled ? .cancelled : outcome
    }

    private func removeRemoteOwner(_ owner: UUID, key: RemoteSyncKey) {
        guard var run = inFlightRemoteSyncs[key], run.owners.remove(owner) != nil else { return }
        run.observers[owner] = nil
        if run.owners.isEmpty {
            if key.deadline != nil { run.task.cancel() }
            inFlightRemoteSyncs[key] = nil
        } else { inFlightRemoteSyncs[key] = run }
    }

    private func removeLocationOwner(_ owner: UUID, key: LocationSyncKey) {
        guard var run = inFlightSyncs[key], run.owners.remove(owner) != nil else { return }
        if run.owners.isEmpty {
            if key.deadline != nil { run.task.cancel() }
            inFlightSyncs[key] = nil
        } else { inFlightSyncs[key] = run }
    }

    private func performRemoteAlertSync(key: RemoteSyncKey) async -> ArcusRemoteAlertSyncOutcome {
        let id = key.id
        let revisionSent = key.revisionSent
        logger.info("Arcus alert sync started scope=targeted-alert")
        do {
            let source = try await alertRepo.refreshAlert(using: client, id: id, revisionSent: revisionSent)
            let outcome = Self.remoteOutcome(for: source)
            let accepted = try await alertRepo.notificationAlert(id: id)
            if var run = inFlightRemoteSyncs[key] {
                run.acceptance = RemoteAcceptance(alert: accepted)
                inFlightRemoteSyncs[key] = run
                for observer in run.observers.values { await observer(accepted) }
            }
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
