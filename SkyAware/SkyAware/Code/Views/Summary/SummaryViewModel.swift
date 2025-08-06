//
//  SummaryViewModel.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/22/25.
//

import Foundation
import Observation
import MapKit

// Location Reference
// latitude: 45.01890187118621,  longitude: -104.41476597508318)
// latitude: 39.75288661683443,  longitude: -104.44886203922174) // Bennett, CO
// latitude: 43.546155601038905, longitude: -96.73048523568963) // Sioux Falls, SD
// latitude: 39.141082435056475, longitude: -94.94050397438647)
// latitude: 40.59353588092804,  longitude: -74.63735052368774)
//           40.63805277084582,            -102.62175635050521 //Haxtun, CO
// 43.49080559901152, -97.38563534330301 // Dolton, SD

@MainActor
@Observable
final class SummaryViewModel {
    private var userLocation: CLLocationCoordinate2D?
    private var resolvedUserLocation: CLLocationCoordinate2D {
        locationProvider.userLocation?.coordinate ?? CLLocationCoordinate2D(
            latitude: 39.75288661683443,
            longitude: -104.44886203922174
        )
    }
    
    var errorMessage: String?
    var isLoading: Bool = true
    var nearestTown: String? {
        locationProvider.locale
    }
    
    var provider: SpcProvider
    var locationProvider: LocationManager
    
    init(provider: SpcProvider, locationProvider: LocationManager) {
        self.provider = provider
        self.locationProvider = locationProvider
    }
    
    var stormRisk: StormRiskLevel {
        handleConvectiveRisk(MKMultiPolygon(
            provider.categorical.flatMap{$0.polygons}
        ))
    }
    
    var severeRisk: SevereWeatherThreat {
        handleSevereRisk(
            MKMultiPolygon(provider.wind.flatMap {$0.polygons}),
            MKMultiPolygon(provider.hail.flatMap {$0.polygons}),
            MKMultiPolygon(provider.tornado.flatMap {$0.polygons})
        )
    }
    
    /// Determine how the Severe badge will be displayed. It evaluates the wind, hail, and tornado based on users location and prepares the appropriate
    /// badge configuration
    /// - Parameters:
    ///   - wind: MKMultiPolygon object containing all the wind polygons
    ///   - hail: MKMultiPolygon object containing all the hail polygons
    ///   - tornado: MKMultiPolygon object containing all the tornado polygons
    private func handleSevereRisk(
        _ wind: MKMultiPolygon,
        _ hail: MKMultiPolygon,
        _ tornado: MKMultiPolygon
    ) -> SevereWeatherThreat {
        let severePolygons: [(SevereWeatherThreat, MKMultiPolygon)] = [
            (.wind(probability: 0), wind),
            (.hail(probability: 0), hail),
            (.tornado(probability: 0), tornado),
        ]
        
        return severePolygons
            .compactMap { baseThreat, polygon in
                let (isInPolygon, probability) =
                isUserIn(user: resolvedUserLocation, mkPolygons: polygon.polygons)
                return isInPolygon ? baseThreat.with(probability: probability) : nil
            }
            .max(by: {$0.priority < $1.priority}) ?? .allClear
    }
    
    /// Determines how the Categorical badge will be displayed. It evaluates the highest category the user is in and prepares the appropriate badge configuration
    /// - Parameters:
    ///   - convective: MKMultiPolygon object containing all the categorical risk polygons
    private func handleConvectiveRisk(_ convective: MKMultiPolygon) -> StormRiskLevel {
        let titleToRisk: [String: StormRiskLevel] = [
            "GENERAL THUNDERSTORMS RISK": .thunderstorm,
            "MARGINAL RISK": .marginal,
            "SLIGHT RISK": .slight,
            "ENHANCED RISK": .enhanced,
            "MODERATE RISK": .moderate,
            "HIGH RISK": .high
        ]
        
        let matchingPolygons: [(StormRiskLevel, MKPolygon)] = convective.polygons.compactMap { polygon in
            guard let title = polygon.title?.uppercased(),
                  let risk = titleToRisk[title] else { return nil }
            
            return (risk, polygon)
        }
        
        return matchingPolygons
            .filter { isUserIn(user: resolvedUserLocation, mkPolygons: [$0.1]).0 }
            .map { $0.0 }
            .max() ?? .allClear
    }
    
    /// Determine if the user is in any of the provided polygons
    /// - Parameters:
    ///   - user: the users location
    ///   - mkPolygons: array of polygons to check
    /// - Returns: true if user is in any of the provided polygons, false otherwise
    private func isUserIn(user: CLLocationCoordinate2D, mkPolygons: [MKPolygon]) -> (Bool, Double) {
        let userMapPoint = MKMapPoint(user)
        var maxProbability: Double = 0.0
        var isInsideAny = false
        
        for polygon in mkPolygons {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.createPath()
            let cgPoint = renderer.point(for: userMapPoint)
            
            if renderer.path.contains(cgPoint) {
                isInsideAny = true
                
                if let title = polygon.title,
                   let valueString = title.split(separator: "%").first?.trimmingCharacters(in: .whitespaces),
                   let value = Double(valueString) {
                    maxProbability = max(maxProbability, value)
                }
            }
        }
        
        return (isInsideAny, maxProbability)
    }
    
}
