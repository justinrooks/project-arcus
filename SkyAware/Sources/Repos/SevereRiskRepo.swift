//
//  SpcRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation
import OSLog
import SwiftData
import CoreLocation

@ModelActor
actor SevereRiskRepo {
    private let logger = Logger.severeRiskRepo

    func refreshHailRisk(using client: any SpcClient) async throws {
        let data = try await client.fetchGeoJsonData(for: .hail)
        guard let data else {
            logger.warning("No hail risk data returned")
            return
        } // if we don't have any items, just return
        
        let decoded = GeoJsonParser.decode(from: data)
        
        if decoded.features.count == 0 {
            logger.debug("No hail risk features to parse")
            return
        }
        
        let dtos = decoded.features.compactMap {
            makeSevereRisk(for: .hail, with: $0)
        }
        
        try upsert(dtos)
        logger.debug("Updated \(dtos.count) hail risk feature\(dtos.count > 1 ? "s" : "")")
    }
    
    func refreshWindRisk(using client: any SpcClient) async throws {
        let data = try await client.fetchGeoJsonData(for: .wind)
        guard let data else {
            logger.warning("No wind risk data returned")
            return
        } // if we don't have any items, just return
        
        let decoded = GeoJsonParser.decode(from: data)
        
        if decoded.features.count == 0 {
            logger.debug("No wind risk features to parse")
            return
        }
        
        let dtos = decoded.features.compactMap {
            makeSevereRisk(for: .wind, with: $0)
        }
        
        try upsert(dtos)
        logger.debug("Updated \(dtos.count) wind risk feature\(dtos.count > 1 ? "s" : "")")
    }
    
    /// Testable overload that allows injecting a client
    func refreshTornadoRisk(using client: any SpcClient) async throws {
        let data = try await client.fetchGeoJsonData(for: .tornado)
        guard let data else {
            logger.warning("No tornado risk data returned")
            return
        } // if we don't have any items, just return
        
        let decoded = GeoJsonParser.decode(from: data)
        
        if decoded.features.count == 0 {
            logger.debug("No tornado risk features to parse")
            return
        }
        
        let dtos = decoded.features.compactMap {
            makeSevereRisk(for: .tornado, with: $0)
        }
        
        try upsert(dtos)
        logger.debug("Updated \(dtos.count) tornado risk feature\(dtos.count > 1 ? "s" : "")")
    }
    
    /// Returns the strongest storm risk level whose polygon contains the given point, as of `date`.
    func active(asOf date: Date = .init(), for point: CLLocationCoordinate2D) throws -> SevereWeatherThreat {
        // 1) Fetch only risks that are currently valid
        let pred = #Predicate<SevereRisk> { date >= $0.valid && date <= $0.expires }
        let risks = try modelContext.fetch(FetchDescriptor<SevereRisk>(predicate: pred))
        
        // 2) Sort by descending risk so we can early-exit on first hit
        let bySeverity = risks.sorted { $0.threatLevel.priority > $1.threatLevel.priority }

        // 3) For each risk, check polygons with optional bbox prefilter, then precise hit test
        for risk in bySeverity {
            for poly in risk.polygons {
                // Coarse bbox prefilter if available
                if let bbox = poly.bbox, bbox.contains(point) == false { continue }
                
                // Precise hit test on ring coordinates
                let ring = poly.ringCoordinates
                guard !ring.isEmpty else { continue }
                if MesoGeometry.contains(point, inRing: ring) {
                    return risk.threatLevel
                }
            }
        }
        
        return .allClear
    }
    
    func getSevereRiskShapes(asOf date: Date = .init()) throws -> [SevereRiskShapeDTO]{
        // Can't use an enum in a predicate, so need to find a different way.
        // For now, I'm just going to return an array of the DTO's shaped in
        // a way that's easier to use downstream. Then we'll just use the View
        // layer to put the shapes in their respective buckets.
        
        // Targeting only those items that are both valid and not expired
        let desc = FetchDescriptor<SevereRisk>(
            predicate: #Predicate<SevereRisk> {
                $0.valid <= date && date < $0.expires
            })
        
        // We'll dedupe by risk level based on the latest `valid` date, so no sort needed here
        let risks = try modelContext.fetch(desc)

        // 2) For each risk level, keep the record with the most recent `valid` date
        let mostRecentByLevel: [String: SevereRisk] = Dictionary(
            risks.map { ($0.type.rawValue, $0) },
            uniquingKeysWith: { lhs, rhs in
                // choose the record with the later `valid` date
                return lhs.valid >= rhs.valid ? lhs : rhs
            }
        )
        var result: [SevereRiskShapeDTO] = []
        
        for (_, data) in mostRecentByLevel {
            result.append(SevereRiskShapeDTO(type: data.type,
                                             probabilities: data.probability,
                                             polygons: data.polygons)
            )
        }

        return result
        
    }
    
    func purge(asOf now: Date = .init()) throws {
        logger.info("Purging expired severe risk geometry")
        
        // Fetch in batches to avoid large in-memory sets
        let predicate = #Predicate<SevereRisk> { $0.expires < now }
        var desc = FetchDescriptor<SevereRisk>(predicate: predicate)
        desc.fetchLimit = 50
        
        while true {
            let batch = try modelContext.fetch(desc)
            if batch.isEmpty { break }
            logger.debug("Found \(batch.count) to purge")
            
            for obj in batch { modelContext.delete(obj) }
            
            try modelContext.save()
        }
        
        logger.info("Purged old severe risk geometry")
    }
    
    
    
    private func makeSevereRisk(for threat: ThreatType, with feature: GeoJSONFeature) -> SevereRisk {
        let props = feature.properties
        let parsedProbability = getProbability(from: props)
        
        return SevereRisk(type: threat,
                             probability: parsedProbability,
                             threatLevel: getThreatLevel(from: threat, probability: parsedProbability.decimalValue),
                             issued: props.ISSUE.asUTCDate() ?? Date(),
                             valid: props.VALID.asUTCDate() ?? Date(),
                             expires: props.EXPIRE.asUTCDate() ?? Date(),
                             dn: props.DN,
                             polygons: feature.createPolygonEntities(polyTitle: props.LABEL2),
                             label: props.LABEL
                             )
    }
    
    private func getProbability(from properties: GeoJSONProperties) -> ThreatProbability {
        // Content comes in from both label and label2
        // When its significant label has "SIGN" and label2 has something like "10% Significant Hail Risk"
        // When its not significant then label has the percentage like "0.05" as a string
        // This is where we would possibly need to tweak that probability calculation/display
        
        if let parsedDouble = Double(properties.LABEL) {
            return .percent(parsedDouble)
        } else {
            if properties.LABEL == "SIGN" {
                let cleaned = properties.LABEL2.split(separator: "%").first?.trimmingCharacters(in: .whitespaces)
                
                if let intPercent = Int(cleaned ?? "0") {
                    return .significant(intPercent)
                }
            }
            
            return .percent(0) // shouldn't really get here, but need to cover the case.
        }
    }
    
    private func getThreatLevel(from threat: ThreatType, probability: Double) -> SevereWeatherThreat {
        switch threat {
        case .wind:
            return .wind(probability: probability)
        case .hail:
            return .hail(probability: probability)
        case .tornado:
            return .tornado(probability: probability)
        default:
            return .allClear
        }
    }
    
    private func upsert(_ items: [any PersistentModel]) throws {
        for item in items {
            modelContext.insert(item)
        }
        try modelContext.save()
    }
}

