//
//  NwsProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/30/25.
//

import Foundation
import CoreLocation
import OSLog

protocol NwsRiskQuerying: Sendable {
    func getActiveWatches(for point: CLLocationCoordinate2D) async throws -> [WatchDTO]
}

protocol NwsSyncing: Sendable {
    func sync() async
}

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
    func sync() async {
        
    }
}

extension NwsProvider: NwsRiskQuerying {
    func getActiveWatches(for point: CLLocationCoordinate2D) async throws -> [WatchDTO] {
        
        
        
        return []
    }
}
