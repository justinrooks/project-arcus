//
//  SpcProvider+SpcMapData.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/1/25.
//

import Foundation
import ArcusCore

// MARK: SpcMapData
extension SpcProvider: SpcMapData {
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO] {
        try await severeRiskRepo.getSevereRiskShapes()
    }
    
    func getStormRiskMapData() async throws -> [StormRiskDTO] {
        try await stormRiskRepo.getLatestMapData()
    }
    
    func getMesoMapData() async throws -> [MdDTO] {
        try await mesoRepo.getLatestMapData().map(MdDTO.init(payload:))
    }
    
    func getFireRisk() async throws -> [FireRiskDTO] {
        try await fireRiskRepo.getLatestMapData()
    }
}
