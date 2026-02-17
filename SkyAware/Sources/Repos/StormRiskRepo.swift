//
//  StormRiskRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import SwiftData
import CoreLocation
import OSLog

@ModelActor
actor StormRiskRepo {
    private let logger = Logger.reposStormRisk
    
    func refreshStormRisk(using client: any SpcClient) async throws {
        let data = try await client.fetchGeoJsonData(for: .categorical)
        
        let decoded = GeoJsonParser.decode(from: data)
        
        let dtos = decoded.features.compactMap {
            let props = $0.properties
            
            return StormRisk(riskLevel: StormRiskLevel(abbreviation: props.LABEL),
                             issued: props.ISSUE.asUTCDate() ?? Date(),
                             expires: props.EXPIRE.asUTCDate() ?? Date(),
                             valid: props.VALID.asUTCDate() ?? Date(),
                             stroke: props.stroke,
                             fill: props.fill,
                             polygons: $0.createPolygonEntities(polyTitle: props.LABEL2)
            )
        }
        
        try upsert(dtos)
        logger.debug("Updated \(dtos.count, privacy: .public) categorical storm risk feature\(dtos.count > 1 ? "s" : "", privacy: .public)")
    }
    
    /// Returns the strongest storm risk level whose polygon contains the given point, as of `date`.
    func active(asOf date: Date = .init(), for point: CLLocationCoordinate2D) throws -> StormRiskLevel {
        // 1) Fetch only risks that are currently valid
        let pred = #Predicate<StormRisk> { date >= $0.valid && date <= $0.expires }
        let risks = try modelContext.fetch(FetchDescriptor<StormRisk>(predicate: pred))
        
        // 2) Sort by descending risk so we can early-exit on first hit
        let bySeverity = risks.sorted { $0.riskLevel > $1.riskLevel }
    
//         3) For each risk, check polygons with optional bbox prefilter, then precise hit test
        for risk in bySeverity {
            for poly in risk.polygons {
                // Coarse bbox prefilter if available
                if let bbox = poly.bbox, bbox.contains(point) == false { continue }
                
                // Precise hit test on ring coordinates
                let ring = poly.ringCoordinates
                guard !ring.isEmpty else { continue }
                if MesoGeometry.contains(point, inRing: ring) {
                    return risk.riskLevel
                }
            }
        }
        
        return .allClear
    }
    
    func getLatestMapData(asOf date: Date = .init()) throws -> [StormRiskDTO] {
        // 1) Fetch only risks that are currently valid
        let pred = #Predicate<StormRisk> { $0.valid <= date && date < $0.expires }
        let desc = FetchDescriptor<StormRisk>(predicate: pred)
        // We'll dedupe by risk level based on the latest `valid` date, so no sort needed here
        let risks = try modelContext.fetch(desc)

        // 2) For each risk level, keep the record with the most recent `valid` date
        let mostRecentByLevel: [Int: StormRisk] = Dictionary(
            risks.map { ($0.riskLevel.rawValue, $0) },
            uniquingKeysWith: { lhs, rhs in
                // choose the record with the later `valid` date
                return lhs.valid >= rhs.valid ? lhs : rhs
            }
        )

        // 3) Sort the selected items by descending risk severity for a stable output order
        let selected = mostRecentByLevel.values.sorted { $0.riskLevel > $1.riskLevel }

        // 4) Map to DTOs
        return selected.map {
            StormRiskDTO(riskLevel: $0.riskLevel,
                         issued: $0.issued,
                         expires: $0.expires,
                         valid: $0.valid,
                         stroke: $0.stroke,
                         fill: $0.fill,
                         polygons: $0.polygons)
        }
    }
    
    func purge(asOf now: Date = .init()) throws {
        logger.info("Purging expired storm risk geometry")
        
        // Fetch in batches to avoid large in-memory sets
        let predicate = #Predicate<StormRisk> { $0.expires < now }
        var desc = FetchDescriptor<StormRisk>(predicate: predicate)
        desc.fetchLimit = 50
        
        while true {
            let batch = try modelContext.fetch(desc)
            if batch.isEmpty { break }
            logger.debug("Found \(batch.count, privacy: .public) to purge")
            
            for obj in batch { modelContext.delete(obj) }
            
            try modelContext.save()
        }
        
        logger.info("Purged old storm risk geometry")
    }
    
    private func upsert(_ items: [StormRisk]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
}
