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
    private struct RequestKey: Hashable {
        let coordinate: Coordinate2D
        let capturedAt: Date?
    }
    private var inFlight: [RequestKey: Task<GridPointSnapshot?, Never>] = [:]
    private var completed: (key: RequestKey, snapshot: GridPointSnapshot)?
    private var publicationID = UUID()
    private var latestCapturedAt: Date?


    init(client: NwsClient, repo: NwsMetadataRepo) {
        self.client = client
        metadataRepo = repo
    }
    
    func resolveGridPoint(for point: CLLocationCoordinate2D, capturedAt: Date? = nil) async -> GridPointSnapshot? {
        let key = RequestKey(coordinate: Coordinate2D(point), capturedAt: capturedAt)
        if capturedAt != nil, completed?.key == key { return completed?.snapshot }
        if let task = inFlight[key] { return await task.value }
        let task = Task { await self.loadGridPoint(for: point, capturedAt: capturedAt) }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result, let capturedAt, capturedAt >= (completed?.key.capturedAt ?? .distantPast) {
            completed = (key, result)
        }
        return result
    }

    private func loadGridPoint(for point: CLLocationCoordinate2D, capturedAt: Date?) async -> GridPointSnapshot? {
        let id = UUID()
        if capturedAt.map({ $0 >= (latestCapturedAt ?? .distantPast) }) ?? true {
            publicationID = id
            latestCapturedAt = capturedAt
        }
        let trace = LocationEnrichmentDiagnostics.token(coordinate: Coordinate2D(point), capturedAt: capturedAt)
        LocationEnrichmentDiagnostics.record("points_started", token: trace)
        logger.info("Resolving NWS grid point metadata")
        do {
            let coordinates:Coordinate2D = .init(latitude: point.latitude, longitude: point.longitude)
            let decoded = try await LocationEnrichmentDiagnostics.$pointTrace.withValue(trace) {
                try await metadataRepo.getPointMetadata(using: client, for: coordinates)
            }
            let snapshot = GridPointSnapshot(from: decoded, with: coordinates)
            LocationEnrichmentDiagnostics.record("codes_ready", token: trace,
                shape: LocationEnrichmentDiagnostics.shape(county: snapshot.countyCode,
                    forecast: snapshot.forecastZone, fire: snapshot.fireZone))
            if publicationID == id {
                lastSnapshot = snapshot
                await publish(snapshot)
                Task { await self.resolveLabels(for: decoded, coordinates: coordinates, snapshot: snapshot, id: id) }
            }

            logger.info(
                "Resolved NWS grid point metadata hasCounty=\((snapshot.countyCode?.isEmpty == false), privacy: .public) hasFireZone=\((snapshot.fireZone?.isEmpty == false), privacy: .public)"
            )
            return snapshot
        } catch {
            LocationEnrichmentDiagnostics.record(error is CancellationError ? "points_cancelled" : "points_failed", token: trace)
            logger.error("Failed to fetch gridpoint metadata")
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
                               snapshot: GridPointSnapshot, id: UUID) async {
        guard let (county, fire) = try? await metadataRepo.getLocationLabels(
            using: client, for: snapshot.countyCode, and: snapshot.fireZone
        ), publicationID == id else { return }
        let enriched = GridPointSnapshot(from: decoded, with: coordinates, countyLabel: county, fireZoneLabel: fire)
        lastSnapshot = enriched
        await publish(enriched)
    }

}

extension GridPointSnapshot {
    /// Operational completeness is independent of optional human-readable labels.
    var hasCompleteTargetingSignature: Bool {
        [countyCode, forecastZone, fireZone].allSatisfy {
            $0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }
}
