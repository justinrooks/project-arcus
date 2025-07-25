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
final class SummaryViewModel: ObservableObject {
    //        private let userLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 45.01890187118621, longitude: -104.41476597508318)
    private let userLocation = CLLocationCoordinate2D(latitude: 39.75288661683443, longitude: -104.44886203922174) // Bennett, CO
    //        private let userLocation = CLLocationCoordinate2D(latitude: 44.95871621867224, longitude: -89.6297215778462) // Wausau, WI
    //    private let userLocation = CLLocationCoordinate2D(latitude: 39.141082435056475, longitude: -94.94050397438647)
    //    private let userLocation = CLLocationCoordinate2D(latitude: 40.59353588092804, longitude: -74.63735052368774)
    
    @Published var errorMessage: String?
    @Published var isLoading: Bool = true
    
    // Badges
    @Published var stormRisk: StormRiskLevel = .allClear
    @Published var severeRisk: SevereWeatherThreat = .allClear
    @Published var nearestTown: String = "Locating..."
    
    private var cancellables = Set<AnyCancellable>()
    
    private let pointsProvider: PointsProvider
    
    init(pointsProvider: PointsProvider) {
        self.pointsProvider = pointsProvider
        
        getWeatherStatus()
    }
    
    /// Fetches the weather status. It includes based on user location their
    /// current convective category, torn, hail, wind, watches, mesos
    func getWeatherStatus() {
        isLoading = true
        
        Task {
            getNearestTown(from: userLocation) { town, state in
                if let town = town, let state = state {
                    self.nearestTown = "\(town), \(state)"
                } else {
                    print("Could not determine location.")
                }
            }
            
            observeAllConvectiveCategories()
            observeSevereThreats()
            
            self.isLoading = false
        }
    }
    
    private func observeAllConvectiveCategories() {
        Publishers.CombineLatest3(
            pointsProvider.$marginal,
            pointsProvider.$slight,
            pointsProvider.$enhanced
        )
        .combineLatest(
            Publishers.CombineLatest(pointsProvider.$moderate, pointsProvider.$high)
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] base, highRisk in
            let (marginal, slight, enhanced) = base
            let (moderate, high) = highRisk
            self?.handleAllConvectiveRisk(marginal, slight, enhanced, moderate, high)
        }
        .store(in: &cancellables)
    }
    
    private func observeSevereThreats() {
        Publishers.CombineLatest3(
            pointsProvider.$wind,
            pointsProvider.$hail,
            pointsProvider.$tornado
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
                let (isInPolygon, probability) = isUserIn(user: userLocation, mkPolygons: polygons.polygons)
                return isInPolygon ? baseThreat.with(probability: probability) : nil
            }
            .max(by: { $0.priority < $1.priority }) ?? .allClear
        
        self.severeRisk = threat
    }
    
    /// Determines how the Categorical badge will be displayed. It evaluates the highest category the user is in and prepares the appropriate badge configuration
    /// - Parameters:
    ///   - marginal: MKMultiPolygon object containing all the marginal category polygons
    ///   - slight: MKMultiPolygon object containing all the slight category polygons
    ///   - enhanced: MKMultiPolygon object containing all the enhanced category polygons
    ///   - moderate: MKMultiPolygon object containing all the moderate category polygons
    ///   - high: MKMultiPolygon object containing all the high category polygons
    private func handleAllConvectiveRisk(
        _ marginal: MKMultiPolygon,
        _ slight: MKMultiPolygon,
        _ enhanced: MKMultiPolygon,
        _ moderate: MKMultiPolygon,
        _ high: MKMultiPolygon
    ) {
        let riskPolygons: [(StormRiskLevel, MKMultiPolygon)] = [
            (.high, high),
            (.moderate, moderate),
            (.enhanced, enhanced),
            (.slight, slight),
            (.marginal, marginal)
        ]
        
        let risk = riskPolygons
            .filter {
                let (userIn, probability) = isUserIn(user: userLocation, mkPolygons: $0.1.polygons)
                return userIn
            }
            .map { $0.0 }
            .max() ?? .allClear
        
        self.stormRisk = risk
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
                   let valueString = title.split(separator: ":").last?.trimmingCharacters(in: .whitespaces),
                   let value = Double(valueString) {
                    maxProbability = max(maxProbability, value)
                }
            }
        }
        
        return (isInsideAny, maxProbability)
    }
    
    
    /// Reverse geocodes the provided location into city and state
    /// - Parameters:
    ///   - coordinate: coordinates to reverse encode
    ///   - completion: tuple with city and state
    private func getNearestTown(from coordinate: CLLocationCoordinate2D, completion: @escaping (String?, String?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            
            if let placemark = placemarks?.first {
                let town = placemark.locality ?? placemark.subAdministrativeArea
                let state = placemark.administrativeArea
                completion(town, state)
            } else {
                completion(nil, nil)
            }
        }
    }
}
