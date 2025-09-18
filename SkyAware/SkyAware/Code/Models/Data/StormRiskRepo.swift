//
//  StormRiskRepo.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/18/25.
//

import Foundation
import SwiftData
import OSLog

@ModelActor
actor StormRiskRepo {
    private var context: ModelContext { modelExecutor.modelContext }
    private let logger = Logger.stormRiskRepo
    
    func refreshStormRisk() async throws {
        let client = SpcClient()
        let risk = try await client.fetchStormRisk()
        
        guard let risk else { return } // if we don't have any items, just return
        
        let dto = risk.featureCollection.features.compactMap {
            let props = $0.properties

            return StormRiskDTO(riskLevel: StormRiskLevel(abbreviation: props.LABEL),
                                issued: props.ISSUE.asUTCDate() ?? Date(),
                                validUntil: props.VALID.asUTCDate() ?? Date(),
                                polygons: $0.createPolygonEntities(polyTitle: props.LABEL2)
            )
        }
        
        try await upsertStormRisk(dto)
        logger.debug("Updated \(dto.count) categorical storm risk feature\(dto.count > 1 ? "s" : "")")
    }
    
    
    private func upsertStormRisk(_ risks: [StormRiskDTO]) async throws {
        _ = try risks.map {
            guard let w = StormRisk(from: $0) else { throw OtherErrors.contextSaveError }
            context.insert(w)
        }
        
        try context.save()
    }
}
