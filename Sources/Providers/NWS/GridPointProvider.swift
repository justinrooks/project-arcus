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
            let snapshot = GridPointSnapshot(from: decoded, with: coordinates)
            lastSnapshot = snapshot
            await publish(snapshot)
            Task { await self.resolveLabels(for: decoded, coordinates: coordinates, snapshot: snapshot) }

            logger.info(
                "Resolved NWS grid point metadata hasCounty=\((snapshot.countyCode?.isEmpty == false), privacy: .public) hasFireZone=\((snapshot.fireZone?.isEmpty == false), privacy: .public)"
            )
            return snapshot
        } catch {
            logger.error("Failed to fetch gridpoint metadata: \(error, privacy: .public)")
            return nil
        }
    }
    private func publish(_ snapshot: GridPointSnapshot) async {
        await metadataRepo.updateCurrentRegionContext(
            countyCode: snapshot.countyCode, forecastZone: snapshot.forecastZone,
            fireZone: snapshot.fireZone, countyLabel: snapshot.countyLabel, fireZoneLabel: snapshot.fireZoneLabel
        )
    }

    private func resolveLabels(for decoded: NWSGridPoint, coordinates: Coordinate2D,
                               snapshot: GridPointSnapshot) async {
        guard let (county, fire) = try? await metadataRepo.getLocationLabels(
            using: client, for: snapshot.countyCode, and: snapshot.fireZone
        ), lastSnapshot == snapshot else { return }
        let enriched = GridPointSnapshot(from: decoded, with: coordinates, countyLabel: county, fireZoneLabel: fire)
        lastSnapshot = enriched
        await publish(enriched)
    }

}
