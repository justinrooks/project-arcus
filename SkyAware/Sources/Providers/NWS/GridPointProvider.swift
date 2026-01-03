//
//  GridPointProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/23/25.
//

import Foundation
import CoreLocation
import OSLog

// TODO: Create a stream like the location provider for grid point metadata changes. may be able to fuse these
actor GridPointProvider {
    let logger = Logger.nwsGridProvider
    private let client: NwsClient
    private let metadataRepo: NwsMetadataRepo
    private var lastSnapshot: GridPointSnapshot?
    private let locationProvider: LocationProvider
    private var lastRefreshKey: GridRefreshKey?

    init(client: NwsClient, locationProvider: LocationProvider, repo: NwsMetadataRepo) {
        self.client = client
        self.locationProvider = locationProvider
        metadataRepo = repo
        
        Task { [weak self] in
            guard let self else { return }
            await self.startListening()
        }
    }
    
    func resolveGridPoint(for point: CLLocationCoordinate2D) async -> GridPointSnapshot?{
        do {
            let coordinates:Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
            let decoded = try await metadataRepo.getPointMetadata(using: client, for: coordinates)
            let snapshot = GridPointSnapshot(from: decoded, with: coordinates)
            lastSnapshot = snapshot
            
            return snapshot
        } catch {
            logger.error("Failed to fetch gridpoint metadata: \(error)")
            return nil
        }
    }

    func currentGridPointMetadata() -> GridPointSnapshot? {
        lastSnapshot
    }
    
    private func shouldRefresh(for snap: CLLocationCoordinate2D) -> Bool {
        let key = GridRefreshKey(coord: snap)
        guard key != lastRefreshKey else { return false }
        lastRefreshKey = key
        return true
    }
    
    private func startListening() async {
        let stream = await locationProvider.updates()
        for await s in stream {
            if Task.isCancelled { break }
            await handleLocation(s)
        }
    }
    
    private func handleLocation(_ snapshot: LocationSnapshot) async {
        guard shouldRefresh(for: snapshot.coordinates) else {
            return
        }
        _ = await resolveGridPoint(for: snapshot.coordinates)
    }
}
