//
//  GridPointProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 12/23/25.
//

import Foundation
import CoreLocation
import OSLog

struct GridPointSnapshot {
    let nwsId: String
    let latitude: Double
    let longitude: Double
    let gridId: String
    let gridX: Int
    let gridY: Int
    let forecastURL: URL?
    let forecastHourlyURL: URL?
    let forecastGridDataURL: URL?
    let observationStationsURL: URL?
    let city: String?
    let state: String?
    let timeZoneId: String?
    let radarStationId: String?
    let zone: String?
    let county: String?
    
    init(from: NWSGridPoint, with coordinates: Coordinate2D) {
        let props = from.properties
        
        self.nwsId                  = props.id ?? ""
        self.latitude               = coordinates.latitude
        self.longitude              = coordinates.longitude
        self.gridId                 = props.gridId
        self.gridX                  = props.gridX
        self.gridY                  = props.gridY
        self.forecastURL            = props.forecast
        self.forecastHourlyURL      = props.forecastHourly
        self.forecastGridDataURL    = props.forecastGridData
        self.observationStationsURL = props.observationStations
        self.city                   = props.relativeLocation?.properties.city
        self.state                  = props.relativeLocation?.properties.state
        self.timeZoneId             = props.timeZone
        self.radarStationId         = props.radarStation
        self.zone                   = props.forecastZone?.lastPathComponent
        self.county                 = props.county?.lastPathComponent
    }
}

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
