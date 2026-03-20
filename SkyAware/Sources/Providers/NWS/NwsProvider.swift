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

private extension NwsProvider {
    func shouldSkipWatchSync(for key: GridRefreshKey, now: Date = .now) -> Bool {
        guard let lastSyncAt = lastWatchSyncAtByLocation[key] else { return false }
        return now.timeIntervalSince(lastSyncAt) < watchSyncCooldownSeconds
    }
}
