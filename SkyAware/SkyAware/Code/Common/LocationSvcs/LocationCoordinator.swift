//
//  LocationCoordinator.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/6/25.
//

import SwiftUI
import CoreLocation

@MainActor
@Observable
final class LocationCoordinator {
    private var active: LocationService
    private var current: LocationService?
    
    private(set) var authStatus: CLAuthorizationStatus = .notDetermined

    
    init(active: LocationService = ForegroundLocationSvc(),
         onUpdate: @escaping (CLLocationCoordinate2D, Date, CLLocationAccuracy) -> Void) {
        self.active = active
        self.active.onUpdate = onUpdate
        
        let authHandler: @Sendable (CLAuthorizationStatus) -> Void = { [weak self] status in
            Task { @MainActor in self?.handleAuthChange(status) }
        }
        self.active.onAuthChange = authHandler
    }
    
    func setForeground() {
        current?.stop()
        current = active
        current?.start()
    }
    
    func setBackground() {
        print("Background this")
    }
    
    // ---- Your policy, centralized here ----
    private func handleAuthChange(_ status: CLAuthorizationStatus) {
        authStatus = status
        evaluatePolicy()
    }
    
    private func evaluatePolicy() {
        switch authStatus {
        case .notDetermined:
            // Prompt only from a user action or obvious entry point:
            CLLocationManager().requestWhenInUseAuthorization()

            // Do NOT start any service yet; we’ll get a new callback.

        case .restricted, .denied:
            stopAll()
        case .authorizedWhenInUse:
            // Foreground allowed; background SC may work only while app stays alive.
            self.setForeground()
//            switch mode {
//            case .foreground: start(fg)
//            case .background: stopAll() /* or start(bg) if you accept “while-resident only” */
//            }
        case .authorizedAlways:
            // Both modes are fine
            self.setForeground()
//            switch mode {
//            case .foreground: start(fg)
//            case .background: start(bg)
//            }
        @unknown default:
            stopAll()
        }
    }
    
    private func stopAll() {
        current?.stop()
        current = nil
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
