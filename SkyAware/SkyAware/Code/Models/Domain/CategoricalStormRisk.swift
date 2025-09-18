//
//  CategoricalStormRisk.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/5/25.
//

import Foundation
import MapKit

@available(*, deprecated, message: "StormRisk instead", renamed: "StormRisk()")
struct CategoricalStormRisk {
    let id: UUID = UUID()
    let riskLevel: StormRiskLevel
    let issued: Date
    let validUntil: Date
    let polygons: [MKPolygon]
}

extension CategoricalStormRisk {
    static func from(feature: GeoJSONFeature) -> CategoricalStormRisk? {
        let props = feature.properties
        
        return CategoricalStormRisk(
            riskLevel: StormRiskLevel(abbreviation: props.LABEL),
            issued: props.ISSUE.asUTCDate() ?? Date(),
            validUntil: props.VALID.asUTCDate() ?? Date(),
            polygons: feature.createPolygons(polyTitle: props.LABEL2)
        )
    }
}
