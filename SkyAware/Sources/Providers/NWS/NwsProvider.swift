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
            logger.error("Error fetching point metadata: \(error)")
        }
    }
}

extension NwsProvider: NwsSyncing {
    func sync(for point: CLLocationCoordinate2D) async {
        do {
            let coordinates:Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
            try await watchRepo.refresh(using: client, for: coordinates)
        }
        catch {
            logger.error("Error syncing NWS Watches: \(error)")
        }
    }
}

extension NwsProvider: NwsRiskQuerying {
    func getActiveWatches(for point: CLLocationCoordinate2D) async throws -> [WatchRowDTO] {
        guard let gridMetadata = await gridPointProvider.currentGridPointMetadata() else {
            logger.error("No grid metadata available")
            return []
        }
        
        guard let county = gridMetadata.county, let zone = gridMetadata.zone else {
            logger.error("No county or zone data available")
            return []
        }
        print("*****Testing Grid Values: \(county), \(zone)*****")
        
        //COZ246
        let watches = try await watchRepo.active(county: county, zone: zone)
        
        return watches
    }
}
