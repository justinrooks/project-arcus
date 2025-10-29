//
//  SevereRiskMapDTO.swift
//  SkyAware
//
//  Created by Justin Rooks on 9/25/25.
//

import Foundation

struct SevereRiskShapeDTO: Sendable {
    let type: ThreatType
    let probabilities: ThreatProbability
    let polygons: [GeoPolygonEntity]
}
