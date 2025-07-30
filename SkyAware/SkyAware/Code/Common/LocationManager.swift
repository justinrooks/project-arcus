//
//  LocationManager.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/28/25.
//

import Foundation
import CoreLocation


final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    @Published var isAuthorized = false
    @Published var locale: String = "Locating..."
    @Published var userLocation: CLLocation?
    
    override init()
    {
        super.init()
        manager.delegate = self
    }
    
    
    func checkLocationAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted:
            print("Location Services are restricted.")
        case .denied:
            print("You've denied SkyAware access to your location. Please enable in settings.")
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            isAuthorized = true
            
        @unknown default:
            print("Unknown authorization status.")
            break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }
        
        userLocation = currentLocation
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(currentLocation) { placemarks, error in
            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first {
                let town = placemark.locality ?? placemark.subAdministrativeArea
                let state = placemark.administrativeArea
                
                if let town = town, let state = state {
                    self.locale = "\(town), \(state)"
                }
                
            } else {
                return
            }
        }
    }
}
