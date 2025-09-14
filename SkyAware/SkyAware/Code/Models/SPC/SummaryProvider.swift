//
//  SummaryProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/28/25.
//

import Foundation
import MapKit
import OSLog

@Observable
@MainActor
final class SummaryProvider {
    @ObservationIgnored private let provider: SpcProvider
    @ObservationIgnored private let location: LocationManager
    @ObservationIgnored private let logger = Logger.summaryProvider
    
    init(provider: SpcProvider, location: LocationManager) {
        self.provider = provider
        self.location = location
    }

    
    func getStormRisk() -> StormRiskLevel {
        let titleToRisk: [String: StormRiskLevel] = [
            "GENERAL THUNDERSTORMS RISK": .thunderstorm,
            "MARGINAL RISK": .marginal,
            "SLIGHT RISK": .slight,
            "ENHANCED RISK": .enhanced,
            "MODERATE RISK": .moderate,
            "HIGH RISK": .high
        ]
        
        let matchingPolygons: [(StormRiskLevel, MKPolygon)] = provider.categorical.flatMap{$0.polygons}.compactMap { polygon in
            guard let title = polygon.title?.uppercased(),
                  let risk = titleToRisk[title] else { return nil }
            
            return (risk, polygon)
        }
        
        return matchingPolygons
            .filter { PolygonHelpers.isUserIn(user: location.resolvedUserLocation, mkPolygons: [$0.1]).0 }
            .map { $0.0 }
            .max() ?? .allClear
    }
    

    func getSevereRisk() -> SevereWeatherThreat {
        let severePolygons: [(SevereWeatherThreat, MKMultiPolygon)] = [
            (.wind(probability: 0), MKMultiPolygon(provider.wind.flatMap {$0.polygons})),
            (.hail(probability: 0), MKMultiPolygon(provider.hail.flatMap {$0.polygons})),
            (.tornado(probability: 0), MKMultiPolygon(provider.tornado.flatMap {$0.polygons})),
        ]
        
        return severePolygons
            .compactMap { baseThreat, polygon in
                let (isInPolygon, probability) =
                PolygonHelpers.isUserIn(user: location.resolvedUserLocation, mkPolygons: polygon.polygons)
                return isInPolygon ? baseThreat.with(probability: probability) : nil
            }
            .max(by: {$0.priority < $1.priority}) ?? .allClear
    }
}
