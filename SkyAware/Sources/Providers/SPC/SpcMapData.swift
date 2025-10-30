//
//  SpcMapData.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation

protocol SpcMapData: Sendable {
    func getSevereRiskShapes() async throws -> [SevereRiskShapeDTO]
    func getStormRiskMapData() async throws -> [StormRiskDTO]
    func getMesoMapData() async throws -> [MdDTO]
}

extension SpcProvider: SpcMapData {}
