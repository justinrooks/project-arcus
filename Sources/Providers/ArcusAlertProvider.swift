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
    private var inFlightSyncs: [LocationContext.RefreshKey: Task<ArcusLocationSyncOutcome, Never>] = [:]
    
    init(alertRepo: AlertRepo, client: ArcusClient) {
        self.client = client
        self.alertRepo = alertRepo
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
                return Self.outcome(for: source)
            } catch is CancellationError {
                logger.notice("Arcus alert sync cancelled scope=location-context")
                return .cancelled
            } catch ArcusError.parsingError {
                logger.error("Arcus alert sync rejected scope=location-context")
                return .rejected
            } catch {
                logger.error("Error syncing Arcus alerts: \(error, privacy: .public)")
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
        logger.info("Arcus alert sync started scope=targeted-alert")
        do {
            let source = try await alertRepo.refreshAlert(using: client, id: id, revisionSent: revisionSent)
            let outcome = Self.remoteOutcome(for: source)
            logger.info("Arcus alert sync finished scope=targeted-alert outcome=\(String(describing: outcome), privacy: .public)")
            return outcome
        } catch is CancellationError {
            logger.notice("Arcus alert sync cancelled scope=targeted-alert")
            return .cancelled
        } catch ArcusError.parsingError {
            logger.error("Arcus alert sync rejected scope=targeted-alert")
            return .rejected
        } catch {
            logger.error("Error syncing targeted Arcus alert: \(error, privacy: .public)")
            return .failed
        }
    }

    private static func outcome(for source: HTTPResponse.Source) -> ArcusLocationSyncOutcome {
        switch source {
        case .live, .cacheRevalidated304:
            .accepted
        case .localCache, .cacheFallback:
            .fallback
        }
    }

    private static func remoteOutcome(for source: HTTPResponse.Source) -> ArcusRemoteAlertSyncOutcome {
        switch source {
        case .live, .cacheRevalidated304:
            .accepted
        case .localCache, .cacheFallback:
            .fallback
        }
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
