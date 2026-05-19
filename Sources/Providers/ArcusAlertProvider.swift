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
    private var inFlightSyncs: [LocationContext.RefreshKey: Task<Void, Never>] = [:]
    
    init(alertRepo: AlertRepo, client: ArcusClient) {
        self.client = client
        self.alertRepo = alertRepo
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

        let alertRepo = self.alertRepo
        let client = self.client
        let logger = self.logger
        logger.info("Arcus alert sync started scope=location-context")
        let task = Task {
            do {
                try await alertRepo.refresh(
                    using: client,
                    for: context.grid.countyCode ?? "",
                    and: context.grid.fireZone ?? "",
                    and: context.grid.forecastZone ?? "",
                    in: context.h3Cell
                )
            } catch {
                logger.error("Error syncing Arcus alerts: \(error, privacy: .public)")
            }
        }

        inFlightSyncs[key] = task
        await task.value
        inFlightSyncs[key] = nil
        logger.info("Arcus alert sync finished scope=location-context")
    }

    func syncRemoteAlert(id: String, revisionSent: Date?) async {
        logger.info("Arcus alert sync started scope=targeted-alert")
        do {
            try await alertRepo.refreshAlert(using: client, id: id, revisionSent: revisionSent)
            logger.info("Arcus alert sync finished scope=targeted-alert")
        } catch {
            logger.error("Error syncing targeted Arcus alert: \(error, privacy: .public)")
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
