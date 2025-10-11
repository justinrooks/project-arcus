//
//  LocationManager.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/28/25.
//

import Foundation
import CoreLocation
import OSLog

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
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let logger = Logger.locationMgr
    private let onUpdate: LocationSink
    private(set) var authStatus: CLAuthorizationStatus = .notDetermined

    init(onUpdate: @escaping LocationSink) {
        self.onUpdate = onUpdate
        
        super.init()
        manager.delegate = self
        //        manager.allowsBackgroundLocationUpdates = true
        //        manager.showsBackgroundLocationIndicator = true
        manager.distanceFilter = 1650 // causes the manager to not report location changes less than 1650m
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func checkLocationAuthorization() {
        self.authStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted:
            logger.warning("Location Services are restricted.")
        case .denied:
            logger.critical("You've denied SkyAware access to your location. Please enable in settings.")
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        @unknown default:
            logger.error("Unknown authorization status.")
            break
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Explicitly ensure we remain on the MainActor even if Core Location calls off-main.
        Task { @MainActor in
            self.checkLocationAuthorization()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = manager.location else { return }
        
        Task {
            await onUpdate(.init(coordinates: loc.coordinate, timestamp: loc.timestamp, accuracy: loc.horizontalAccuracy))
        }
    }
}
