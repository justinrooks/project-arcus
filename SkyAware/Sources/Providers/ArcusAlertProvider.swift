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
//        let coordinates: Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
        guard let gridMetadata = await gridPointProvider.currentGridPointMetadata() else {
            logger.warning("No grid metadata available")
            return
        }
        guard let countyCode = gridMetadata.countyCode, let fireZone = gridMetadata.fireZone else {
            logger.warning("No county code or fire zone data available")
            return
        }
//        let refreshKey = GridRefreshKey(coord: point)
//
//        if let inFlight = inFlightWatchSyncTasks[refreshKey] {
//            logger.debug("Arcus watch sync already in-flight; joining existing task")
//            await inFlight.value
//            return
//        }
//
//        if shouldSkipWatchSync(for: refreshKey) {
//            logger.debug("Skipping Arcus watch sync due to same-location cooldown")
//            return
//        }
//
        let watchRepo = self.watchRepo
        let client = self.client
        let logger = self.logger
//        let task = Task { () -> Bool in
            do {
                try await watchRepo.refresh(using: client, for: countyCode, and: fireZone, in: h3Cell)
//                return true
            } catch {
                logger.error("Error syncing Arcus alerts: \(error, privacy: .public)")
//                return false
            }
//        }
//        inFlightWatchSyncTasks[refreshKey] = task

//        let succeeded = await task.value
//        inFlightWatchSyncTasks[refreshKey] = nil
//        if !Task.isCancelled && succeeded {
//            lastWatchSyncAtByLocation[refreshKey] = Date()
//        }
    }
}

extension ArcusAlertProvider: ArcusAlertQuerying {
    func getActiveWatches() async throws -> [WatchRowDTO] {
        try await watchRepo.active()
    }
}
