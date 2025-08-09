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
// latitude: 39.75288661683443,  longitude: -104.44886203922174) // Bennett, CO
// latitude: 43.546155601038905, longitude: -96.73048523568963) // Sioux Falls, SD
// latitude: 43.83334367563072,  longitude: -96.01419655189608) // NE SD somewhere

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
    
    /// Provides a filtered list of mesoscale discussions for the current user's location
    /// meso's get coordinates, so we build a polygon and then use the existing poly
    /// check to see if it affects the current user based on location.
    var mesosNearby: [MesoscaleDiscussion] {
        #warning("TODO: Remove this if check eventually")
        if (provider.meso.count > 0) {
            return provider.meso.filter {
                let poly = MKPolygon(coordinates: $0.coordinates, count: $0.coordinates.count)
                return inPoly(user: resolvedUserLocation, polygon: poly)
            }
        } else {
            return [
                MesoscaleDiscussion(
                    id: UUID(),
                    number: 1893,
                    title: "test",
                    link: URL(string:"https://www.spc.noaa.gov/products/md/md1893.html")!,
                    issued: Date(),
                    validStart: Calendar.current.date(byAdding: .minute, value: 60, to: Date())!,
                    validEnd: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                    areasAffected: "Western SD, northeast WY, far southeast MT",
                    summary: "test",
                    concerning: "Concerning...Severe Thunderstorm Watch 580...",
                    watchProbability: .percent(5),
                    threats: MDThreats(peakWindMPH: 65, hailRangeInches: 1.5...2.5, tornadoStrength: "Not expected"),
                    coordinates: MesoGeometry.coordinates(from: """
                       ATTN...WFO...BYZ...GGW...TFX...

                       LAT...LON   46441136 46761221 47041239 47441240 47691208 47991054
                                   48011017 48080908 47980781 47500689 46800636 46110655
                                   45890673 45420788 45690939 45951005 46201081 46441136 

                       MOST PROBABLE PEAK WIND GUST...55-70 MPH
                       MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
""") ?? [],
                    alertType: .mesoscale
                ),
                MesoscaleDiscussion(
                    id: UUID(),
                    number: 1894,
                    title: "test",
                    link: URL(string:"https://www.spc.noaa.gov/products/md/md1894.html")!,
                    issued: Date(),
                    validStart: Calendar.current.date(byAdding: .minute, value: 90, to: Date())!,
                    validEnd: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!,
                    areasAffected: "Western ID, northwest WY, far southwest MT",
                    summary: "test",
                    concerning: "Severe potential… Watch likely",
                    watchProbability: .percent(5),
                    threats: MDThreats(peakWindMPH: 60, hailRangeInches: 1.5...5.5, tornadoStrength: "95 MPH"),
                    coordinates: MesoGeometry.coordinates(from: """
                        ATTN...WFO...UNR...BYZ...

                        LAT...LON   44640241 44240268 44030332 44140411 44370500 44480533
                                    44700555 44990556 45370523 45570470 45590413 45440325
                                    45220265 44970240 44640241 

                        MOST PROBABLE PEAK WIND GUST...UP TO 60 MPH
                        MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN
""") ?? [],
                    alertType: .mesoscale
                ),
                MesoscaleDiscussion(
                    id: UUID(),
                    number: 1895,
                    title: "test",
                    link: URL(string:"https://www.spc.noaa.gov/products/md/md1895.html")!,
                    issued: Date(),
                    validStart: Calendar.current.date(byAdding: .minute, value: 120, to: Date())!,
                    validEnd: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!,
                    areasAffected: "Western SD, northeast WY, far southeast MT",
                    summary: "test",
                    concerning: "Severe potential… Watch unlikely",
                    watchProbability: .percent(15),
                    threats: MDThreats(peakWindMPH: nil, hailRangeInches: 1.0...4.5, tornadoStrength: nil),
                    coordinates: MesoGeometry.coordinates(from: """
                   ATTN...WFO...FSD...ABR...LBF...UNR...

                   LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
                               42500075 43370091 

                   MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
                   MOST PROBABLE PEAK WIND GUST...65-80 MPH
                   MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN                                          
""") ?? [],
                    alertType: .mesoscale
                ),
                MesoscaleDiscussion(
                    id: UUID(),
                    number: 1896,
                    title: "test",
                    link: URL(string:"https://www.spc.noaa.gov/products/md/md1896.html")!,
                    issued: Date(),
                    validStart: Calendar.current.date(byAdding: .minute, value: 120, to: Date())!,
                    validEnd: Calendar.current.date(byAdding: .hour, value: 4, to: Date())!,
                    areasAffected: "Western SD, northeast WY, far southeast MT",
                    summary: "test",
                    concerning: "Severe potential… Watch unlikely",
                    watchProbability: .percent(45),
                    threats: MDThreats(peakWindMPH: 63, hailRangeInches: nil, tornadoStrength: "Not expected"),
                    coordinates: MesoGeometry.coordinates(from: """
                   ATTN...WFO...FSD...ABR...LBF...UNR...

                   LAT...LON   43370091 44049966 44449790 43689659 43239776 42699886
                               42500075 43370091 

                   MOST PROBABLE PEAK TORNADO INTENSITY...UP TO 95 MPH
                   MOST PROBABLE PEAK WIND GUST...65-80 MPH
                   MOST PROBABLE PEAK HAIL SIZE...1.50-2.50 IN                                          
""") ?? [],
                    alertType: .mesoscale
                )
            ]
        }
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
        var maxProbability: Double = 0.0
        var isInsideAny = false
        
        for polygon in mkPolygons {
            let isInside = inPoly(user: user, polygon: polygon)

            if isInside {
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
    
    
    /// Determines if a location is inside a single polygon
    /// - Parameters:
    ///   - user: the users CLLocationCoordinate
    ///   - polygon: Polygon to check
    /// - Returns: true if location is within the provided polygon, false otherwise
    private func inPoly(user: CLLocationCoordinate2D, polygon: MKPolygon) -> Bool {
        let userMapPoint = MKMapPoint(user)
        var isInsideAny = false
        
        let renderer = MKPolygonRenderer(polygon: polygon)
        renderer.createPath()
        let cgPoint = renderer.point(for: userMapPoint)
        
        if renderer.path.contains(cgPoint) {
            isInsideAny = true
         }
        
        return isInsideAny
    }
}
