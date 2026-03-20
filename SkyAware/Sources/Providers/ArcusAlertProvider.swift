//
//  ArcusAlertProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation
import CoreLocation
import OSLog

actor ArcusAlertProvider {
    let logger = Logger.providersArcus
    let client: ArcusClient
    let watchRepo: WatchRepo
    let metadataRepo: NwsMetadataRepo
    let gridPointProvider: GridPointProvider
    private var inFlightWatchSyncTasks: [GridRefreshKey: Task<Bool, Never>] = [:]
    private var lastWatchSyncAtByLocation: [GridRefreshKey: Date] = [:]
    private let watchSyncCooldownSeconds: TimeInterval = 30
    
    init(watchRepo: WatchRepo, metadataRepo: NwsMetadataRepo, gridMetadataProvider: GridPointProvider, client: ArcusClient) {
        self.client = client
        self.watchRepo = watchRepo
        self.metadataRepo = metadataRepo
        self.gridPointProvider = gridMetadataProvider
    }
}

extension ArcusAlertProvider: ArcusAlertSyncing {
    func sync(h3Cell: Int64?) async {
        guard let gridMetadata = await gridPointProvider.currentGridPointMetadata() else {
            logger.warning("No grid metadata available")
            return
        }
        guard let countyCode = gridMetadata.countyCode, let fireZone = gridMetadata.fireZone else {
            logger.warning("No county code or fire zone data available")
            return
        }
        
        let watchRepo = self.watchRepo
        let client = self.client
        let logger = self.logger
        do {
            try await watchRepo.refresh(using: client, for: countyCode, and: fireZone, in: h3Cell)
        } catch {
            logger.error("Error syncing Arcus alerts: \(error, privacy: .public)")
        }
    }
}

extension ArcusAlertProvider: ArcusAlertQuerying {
    func getActiveWatches() async throws -> [WatchRowDTO] {
        guard let gridMetadata = await gridPointProvider.currentGridPointMetadata() else {
            logger.warning("No grid metadata available")
            return []
        }
        
        guard let county = gridMetadata.countyCode, let fireZone = gridMetadata.fireZone else {
            logger.warning("No county or fire zone data available")
            return []
        }
        
        //COZ246
        // TODO: Get the h3 cell here as a new filter
        return try await watchRepo.active(countyCode: county, fireZone: fireZone)
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
