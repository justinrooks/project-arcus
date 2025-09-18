//
//  SpcRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/16/25.
//

import Foundation
import OSLog
import SwiftData

@ModelActor
actor SevereRiskRepo {
    private var context: ModelContext { modelExecutor.modelContext }
    private let logger = Logger.severeRiskRepo

    func refreshHailRisk() async throws {
        let client = SpcClient()
        let risk = try await client.fetchHailRisk()
        
        guard let risk else { return } // if we don't have any items, just return
        
        let dto = risk.featureCollection.features.compactMap {
            makeSevereRiskDTO(for: .hail, with: $0)
        }

        try await upsertHailRisk(dto)
        logger.debug("Updated \(dto.count) hail risk feature\(dto.count > 1 ? "s" : "")")
    }
    
    func refreshWindRisk() async throws {
        let client = SpcClient()
        let risk = try await client.fetchWindRisk()
        
        guard let risk else { return } // if we don't have any items, just return
        
        let dto = risk.featureCollection.features.compactMap {
            makeSevereRiskDTO(for: .wind, with: $0)
        }
        
        try await upsertWindRisk(dto)
        logger.debug("Updated \(dto.count) wind risk feature\(dto.count > 1 ? "s" : "")")
    }
    
    func refreshTornadoRisk() async throws {
        let client = SpcClient()
        let risk = try await client.fetchTornadoRisk()
        
        guard let risk else { return } // if we don't have any items, just return
        
        let dto = risk.featureCollection.features.compactMap {
            makeSevereRiskDTO(for: .tornado, with: $0)
        }
        
        try await upsertTornadoRisk(dto)
        logger.debug("Updated \(dto.count) tornado risk feature\(dto.count > 1 ? "s" : "")")
    }
    
    private func makeSevereRiskDTO(for threat: ThreatType, with feature: GeoJSONFeature) -> SevereRiskDTO {
        let props = feature.properties
        let parsedProbability = getProbability(from: props)
        
        return SevereRiskDTO(type: threat,
                             probability: parsedProbability,
                             threatLevel: getThreatLevel(from: threat, probability: parsedProbability.decimalValue),
                             issued: props.ISSUE.asUTCDate() ?? Date(),
                             validUntil: props.VALID.asUTCDate() ?? Date(),
                             polygons: feature.createPolygonEntities(polyTitle: props.LABEL2)
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
    
    private func upsertHailRisk(_ risks: [SevereRiskDTO]) async throws {
        _ = try risks.map {
            guard let w = SevereRisk(from: $0) else { throw OtherErrors.contextSaveError }
            context.insert(w)
        }
        
        try context.save()
    }
    
    private func upsertWindRisk(_ risks: [SevereRiskDTO]) async throws {
        _ = try risks.map {
            guard let w = SevereRisk(from: $0) else { throw OtherErrors.contextSaveError }
            context.insert(w)
        }
        
        try context.save()
    }
    
    private func upsertTornadoRisk(_ risks: [SevereRiskDTO]) async throws {
        _ = try risks.map {
            guard let w = SevereRisk(from: $0) else { throw OtherErrors.contextSaveError }
            context.insert(w)
        }
        
        try context.save()
    }
}
