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
    let logger = Logger.nwsProvider
    let client: NwsClient
    let watchRepo: WatchRepo
    
    init(watchRepo: WatchRepo, client: NwsClient) {
        self.client = client
        self.watchRepo = watchRepo
    }
    
    
}

extension NwsProvider: NwsSyncing {
    func sync(for point: CLLocationCoordinate2D) async {
        do {
            let coordinates:Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
            try await watchRepo.refreshWatchesNws(using: client, for: coordinates)
        }
        catch {
            logger.error("Error syncing NWS Watches: \(error)")
        }
    }
    
    func fetchPointMetadata(for point: CLLocationCoordinate2D) async {
        let coordinates:Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
        do {
            try await watchRepo.getPointMetadata(using: client, for: coordinates)
        }
        catch {
            logger.error("Error fetching point metadata: \(error)")
        }
    }
}

extension NwsProvider: NwsRiskQuerying {
    func getActiveWatches(for point: CLLocationCoordinate2D) async throws -> [WatchDTO] {
        let coordinates:Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
        try await watchRepo.refreshWatchesNws(using: client, for: coordinates)
        
        
        
        return []
    }
}
