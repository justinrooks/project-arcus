//
//  SevereThreat.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/5/25.
//

import Foundation
import MapKit

struct SevereThreat {
    let id: UUID = UUID()
    let type: ThreatType
    let probability: ThreatProbability
    let threatLevel: SevereWeatherThreat
    let issued: Date
    let validUntil: Date
    let polygons: [MKPolygon]
}

enum ThreatType: String, CaseIterable {
    case wind
    case hail
    case tornado
    case unknown
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum ThreatProbability: Equatable, Hashable {
    case percent(Double)   // e.g., 2, 5, 15, 30
    case significant(Int)    // SIGN
    
    var description: String {
        switch self {
        case .percent(let value): return "\(value * 100)%"
        case .significant(let value): return "\(value)% Significant Risk"
        }
    }
    
    var intValue: Int {
        switch self {
        case .percent(let value): return Int(value * 100)
        case .significant(let value): return value
        }
    }
    
    var decimalValue: Double {
        switch self {
        case .percent(let value): return value
        case .significant(let value): return Double(value) / 100.0
        }
    }
}

extension SevereThreat {
    static func from(feature: GeoJSONFeature) -> SevereThreat? {
        let props = feature.properties
        
        let parsedThreat = ThreatType(rawValue: props.LABEL2.lowercased()) ?? .unknown
        let parsedProbability = getProbability(from: props)
        
        return SevereThreat(
            type: parsedThreat,
            probability: parsedProbability,
            threatLevel: getThreatLevel(from: parsedThreat, probability: parsedProbability.decimalValue),
            issued: props.ISSUE.asUTCDate() ?? Date(),
            validUntil: props.VALID.asUTCDate() ?? Date(),
            polygons: feature.createPolygons(polyTitle: props.LABEL2) // createMultiPolygon(from: feature.geometry, polyTitle: props.LABEL2)
        )
    }
    
    private static func getProbability(from properties: GeoJSONProperties) -> ThreatProbability {
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
    
    // TODO: Eventually want to sync this up so that we don't even need to convert.
    private static func getThreatLevel(from threat: ThreatType, probability: Double) -> SevereWeatherThreat {
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
}
