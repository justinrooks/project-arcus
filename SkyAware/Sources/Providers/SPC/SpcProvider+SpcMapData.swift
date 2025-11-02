//
//  SpcProvider+SpcMapData.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/1/25.
//

import Foundation

// MARK: SpcMapData
extension SpcProvider: SpcMapData {
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        try await severeRiskRepo.getSevereRiskShapes()
    }
    
    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        try await stormRiskRepo.getLatestMapData()
    }
    
    func getMesoMapData() async throws -> [MdDTO] {
        try await mesoRepo.getLatestMapData()
    }
}
