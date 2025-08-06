//
//  CategoricalStormRisk.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/5/25.
//

import Foundation
import MapKit

struct CategoricalStormRisk {
    let id: UUID = UUID()
    let category: StormRiskCategory
    let riskLevel: StormRiskLevel
    let issued: Date
    let validUntil: Date
    let polygons: [MKPolygon]
}

enum StormRiskCategory: String, CaseIterable {
    case tstm  // General thunderstorms
    case mrgl  // Marginal
    case slgt  // Slight
    case enh   // Enhanced
    case mdt   // Moderate
    case high  // High
    case unknown //Unknown or unable to parse
    
    var displayName: String {
        switch self {
        case .tstm: return "Thunderstorms"
        case .mrgl: return "Marginal Risk"
        case .slgt: return "Slight Risk"
        case .enh:  return "Enhanced Risk"
        case .mdt:  return "Moderate Risk"
        case .high: return "High Risk"
        case .unknown: return "Unknown"
        }
    }
}

extension CategoricalStormRisk {
    static func from(feature: GeoJSONFeature) -> CategoricalStormRisk? {
        let props = feature.properties
        
        return CategoricalStormRisk(
            category: StormRiskCategory(rawValue: props.LABEL.lowercased()) ?? .unknown,
            riskLevel: getStormRiskLevel(from: props.LABEL),
            issued: props.ISSUE.asUTCDate() ?? Date(),
            validUntil: props.VALID.asUTCDate() ?? Date(),
            polygons: feature.createPolygons(polyTitle: props.LABEL2)
        )
    }
    
    // TODO: Eventually want to sync this up so that we don't even need to convert.
    private static func getStormRiskLevel(from riskLevelString: String?) -> StormRiskLevel {
        let level = riskLevelString?.lowercased() ?? "unknown"
        
        switch level {
        case "tstm":
            return .allClear
        case "mrgl":
            return .marginal
        case "slgt":
            return .slight
        case "enh":
            return .enhanced
        case "mdt":
            return .moderate
        case "high":
            return .high
        default:
            return .allClear
        }
    }
}
