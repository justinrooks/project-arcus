//
//  NwsProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/30/25.
//

import Foundation
import CoreLocation
import OSLog

actor NwsProvider {
    let logger = Logger.providersNws
    let client: NwsClient
    let watchRepo: WatchRepo
    let metadataRepo: NwsMetadataRepo
    let gridPointProvider: GridPointProvider
    private var inFlightWatchSyncTasks: [GridRefreshKey: Task<Bool, Never>] = [:]
    private var lastWatchSyncAtByLocation: [GridRefreshKey: Date] = [:]
    private let watchSyncCooldownSeconds: TimeInterval = 30
    
    init(watchRepo: WatchRepo, metadataRepo: NwsMetadataRepo, gridMetadataProvider: GridPointProvider, client: NwsClient) {
        self.client = client
        self.watchRepo = watchRepo
        self.metadataRepo = metadataRepo
        self.gridPointProvider = gridMetadataProvider
    }
}

extension NwsProvider: NwsMetadataProviding {
    func fetchPointMetadata(for point: CLLocationCoordinate2D) async {
        let coordinates:Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
        do {
            _ = try await metadataRepo.getPointMetadata(using: client, for: coordinates)
        }
        catch {
            logger.error("Error fetching point metadata: \(error, privacy: .public)")
        }
    }
}

extension NwsProvider: NwsSyncing {
    func sync(for point: CLLocationCoordinate2D) async {
        let coordinates: Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
        let refreshKey = GridRefreshKey(coord: point)

        if let inFlight = inFlightWatchSyncTasks[refreshKey] {
            logger.debug("NWS watch sync already in-flight; joining existing task")
            await inFlight.value
            return
        }

        if shouldSkipWatchSync(for: refreshKey) {
            logger.debug("Skipping NWS watch sync due to same-location cooldown")
            return
        }

        let watchRepo = self.watchRepo
        let client = self.client
        let logger = self.logger
        let task = Task { () -> Bool in
            do {
                try await watchRepo.refresh(using: client, for: coordinates)
                return true
            } catch {
                logger.error("Error syncing NWS Watches: \(error, privacy: .public)")
                return false
            }
        }
        inFlightWatchSyncTasks[refreshKey] = task

        let succeeded = await task.value
        inFlightWatchSyncTasks[refreshKey] = nil
        if !Task.isCancelled && succeeded {
            lastWatchSyncAtByLocation[refreshKey] = Date()
        }
    }
}

extension NwsProvider: NwsRiskQuerying {
    func getActiveWatches(for point: CLLocationCoordinate2D) async throws -> [WatchRowDTO] {
        guard let gridMetadata = await gridPointProvider.currentGridPointMetadata() else {
            logger.warning("No grid metadata available")
            return []
        }
        
        guard let county = gridMetadata.county, let zone = gridMetadata.zone, let fireZone = gridMetadata.fireZone else {
            logger.warning("No county, zone, or fire zone data available")
            return []
        }
        
        //COZ246
        let watches = try await watchRepo.active(county: county, zone: zone, fireZone: fireZone)
        
        return watches
    }
}

private extension NwsProvider {
    func shouldSkipWatchSync(for key: GridRefreshKey, now: Date = .now) -> Bool {
        guard let lastSyncAt = lastWatchSyncAtByLocation[key] else { return false }
        return now.timeIntervalSince(lastSyncAt) < watchSyncCooldownSeconds
    }
}
