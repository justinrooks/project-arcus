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
    let logger = Logger.providersNwsGrid
    private let client: NwsClient
    private let metadataRepo: NwsMetadataRepo
    private var lastSnapshot: GridPointSnapshot?

    init(client: NwsClient, repo: NwsMetadataRepo) {
        self.client = client
        metadataRepo = repo
    }
    
    func resolveGridPoint(for point: CLLocationCoordinate2D) async -> GridPointSnapshot?{
        logger.info("Resolving NWS grid point metadata")
        do {
            let coordinates:Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
            let decoded = try await metadataRepo.getPointMetadata(using: client, for: coordinates)
            let (
                countyLabel,
                fireZoneLabel
            ) = try await metadataRepo.getLocationLabels(
                using: client,
                for: decoded.properties.county?.lastPathComponent,
                and: decoded.properties.fireWeatherZone?.lastPathComponent
            )

            let snapshot = GridPointSnapshot(
                from: decoded,
                with: coordinates,
                countyLabel: countyLabel,
                fireZoneLabel: fireZoneLabel
            )
            lastSnapshot = snapshot
            
            await metadataRepo.updateCurrentRegionContext(
                countyCode: snapshot.countyCode,
                forecastZone: snapshot.forecastZone,
                fireZone: snapshot.fireZone,
                countyLabel: countyLabel,
                fireZoneLabel: fireZoneLabel
            )

            logger.info(
                "Resolved NWS grid point metadata hasCounty=\((snapshot.countyCode?.isEmpty == false), privacy: .public) hasFireZone=\((snapshot.fireZone?.isEmpty == false), privacy: .public)"
            )
            return snapshot
        } catch {
            logger.error("Failed to fetch gridpoint metadata: \(error, privacy: .public)")
            return nil
        }
    }

    func currentGridPointMetadata() -> GridPointSnapshot? {
        lastSnapshot
    }
}
