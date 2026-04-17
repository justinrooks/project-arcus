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
    let watchRepo: WatchRepo
    private var inFlightSyncs: [LocationContext.RefreshKey: Task<Void, Never>] = [:]
    
    init(watchRepo: WatchRepo, client: ArcusClient) {
        self.client = client
        self.watchRepo = watchRepo
    }
}

extension ArcusAlertProvider: ArcusAlertSyncing {
    func sync(context: LocationContext) async {
        let key = context.refreshKey
        if let inFlight = inFlightSyncs[key] {
            logger.debug("Arcus alert sync already in-flight for current location scope; joining existing task")
            await inFlight.value
            return
        }

        let watchRepo = self.watchRepo
        let client = self.client
        let logger = self.logger
        let task = Task {
            do {
                try await watchRepo.refresh(
                    using: client,
                    for: context.grid.countyCode ?? "",
                    and: context.grid.fireZone ?? "",
                    in: context.h3Cell
                )
            } catch {
                logger.error("Error syncing Arcus alerts: \(error, privacy: .public)")
            }
        }

        inFlightSyncs[key] = task
        await task.value
        inFlightSyncs[key] = nil
    }

    func syncRemoteAlert(id: String, revisionSent: Date?) async {
        do {
            try await watchRepo.refreshAlert(using: client, id: id, revisionSent: revisionSent)
        } catch {
            logger.error("Error syncing targeted Arcus alert: \(error, privacy: .public)")
        }
    }
}

extension ArcusAlertProvider: ArcusAlertQuerying {
    func getActiveWatches(context: LocationContext) async throws -> [WatchRowDTO] {
        try await watchRepo.active(
            countyCode: context.grid.countyCode ?? "",
            fireZone: context.grid.fireZone ?? "",
            cell: context.h3Cell
        )
    }

    func getWatch(id: String) async throws -> WatchRowDTO? {
        try await watchRepo.watch(id: id)
    }
}

extension ArcusAlertProvider: Cleaning {
    func cleanup(daysToKeep: Int = 3) async {
        do {
            try await watchRepo.purge()
        } catch {
            logger.error("Error cleaning up old NWS data: \(error.localizedDescription, privacy: .public)")
        }
    }
}
