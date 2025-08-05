//
//  SummaryViewModel.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/22/25.
//

import Foundation
import Observation
import MapKit
import Combine

@MainActor
@Observable
final class SummaryViewModel: ObservableObject {
    // latitude: 45.01890187118621,  longitude: -104.41476597508318)
    // latitude: 39.75288661683443,  longitude: -104.44886203922174) // Bennett, CO
    // latitude: 43.546155601038905, longitude: -96.73048523568963) // Sioux Falls, SD
    // latitude: 39.141082435056475, longitude: -94.94050397438647)
    // latitude: 40.59353588092804,  longitude: -74.63735052368774)
    //           40.63805277084582,            -102.62175635050521 //Haxtun, CO
    
    @ObservationIgnored private var userLocation: CLLocationCoordinate2D?
    @ObservationIgnored private var resolvedUserLocation: CLLocationCoordinate2D {
        userLocation ?? CLLocationCoordinate2D(latitude: 39.75288661683443, longitude: -104.44886203922174) // Bennett, CO
    }
    var errorMessage: String?
    var isLoading: Bool = true
    
    // Badges
    var stormRisk: StormRiskLevel = .allClear
    var severeRisk: SevereWeatherThreat = .allClear
    var nearestTown: String?
    
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    
    @ObservationIgnored private let provider: SpcProvider
    @ObservationIgnored private let locationProvider: LocationManager
    
    init(provider: SpcProvider, locationProvider: LocationManager) {
        self.provider = provider
        self.locationProvider = locationProvider
        
        getWeatherStatus()
    }
    
    /// Fetches the weather status. It includes based on user location their
    /// current convective category, torn, hail, wind, watches, mesos
    func getWeatherStatus() {
        isLoading = true
        
        Task {
            observeLocation()
            
            self.isLoading = false
        }
    }
    
    private func observeLocation() {
        Publishers.CombineLatest(locationProvider.$userLocation, locationProvider.$locale)
            .receive(on: RunLoop.main)
            .sink { [weak self] loc, town in
                guard let coords = loc?.coordinate else {
                    self?.userLocation = CLLocationCoordinate2D(latitude: 39.75288661683443, longitude: -104.44886203922174) // Bennett, CO
                    print("Location unavailable. Using default location")
                    return
                }
                
                self?.nearestTown = town
                self?.userLocation = coords
                print("Location: \(coords.latitude), \(coords.longitude)")
                
                self?.observeAllConvectiveCategories()
                self?.observeSevereThreats()
            }
            .store(in: &cancellables)
    }
    
    private func observeAllConvectiveCategories() {
        provider.$categorical
            .receive(on: RunLoop.main)
            .sink { [weak self] categorical in
                self?.handleConvectiveRisk(categorical)
            }.store(in: &cancellables)
    }
    
    private func observeSevereThreats() {
        Publishers.CombineLatest3(
            provider.$wind,
            provider.$hail,
            provider.$tornado
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] wind, hail, tornado in
            self?.handleSevereRisk(wind, hail, tornado)
        }
        .store(in: &cancellables)
    }
    
    
    /// Determine how the Severe badge will be displayed. It evaluates the wind, hail, and tornado based on users location and prepares the appropriate
    /// badge configuration
    /// - Parameters:
    ///   - wind: MKMultiPolygon object containing all the wind polygons
    ///   - hail: MKMultiPolygon object containing all the hail polygons
    ///   - tornado: MKMultiPolygon object containing all the tornado polygons
    private func handleSevereRisk(_ wind: MKMultiPolygon, _ hail: MKMultiPolygon, _ tornado: MKMultiPolygon) {
        let severePolygons: [(SevereWeatherThreat, MKMultiPolygon)] = [
            (.wind(probability: 0), wind),
            (.hail(probability: 0), hail),
            (.tornado(probability: 0), tornado)
        ]

        let threat = severePolygons
            .compactMap { baseThreat, polygons in
                let (isInPolygon, probability) = isUserIn(user: resolvedUserLocation, mkPolygons: polygons.polygons)
                return isInPolygon ? baseThreat.with(probability: probability) : nil
            }
            .max(by: { $0.priority < $1.priority }) ?? .allClear
        
        self.severeRisk = threat
    }
    
    /// Determines how the Categorical badge will be displayed. It evaluates the highest category the user is in and prepares the appropriate badge configuration
    /// - Parameters:
    ///   - convective: MKMultiPolygon object containing all the categorical risk polygons
    private func handleConvectiveRisk(_ convective: MKMultiPolygon) {
        let titleToRisk: [String: StormRiskLevel] = [
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
        
        let highest = matchingPolygons
            .filter { isUserIn(user: resolvedUserLocation, mkPolygons: [$0.1]).0 }
            .map { $0.0 }
            .max() ?? .allClear
        
        self.stormRisk = highest
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
