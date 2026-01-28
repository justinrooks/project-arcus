//
//  LocationManager.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/28/25.
//

import Foundation
import SwiftUI
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
    enum Mode { case stopped, foreground, background }
    private var currentMode: Mode = .stopped
    private var lastPhase: ScenePhase = .inactive
    
    private let manager = CLLocationManager()
    private let logger = Logger.locationManager
    private let onUpdate: LocationSink
    private var streamTask: Task<Void, Never>?
    private(set) var authStatus: CLAuthorizationStatus = .notDetermined
    
    init(onUpdate: @escaping LocationSink) {
        self.onUpdate = onUpdate
        
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        //        manager.showsBackgroundLocationIndicator = true
        manager.distanceFilter = 1650 // causes the manager to not report location changes less than 1650m
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    
    func checkLocationAuthorization(isActive: Bool) {
        self.authStatus = manager.authorizationStatus
        guard isActive else { return } // never prompt in background
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted:
            stopAll()
            logger.warning("Location Services are restricted. All services stopped")
        case .denied:
            stopAll()
            logger.critical("You've denied SkyAware access to your location. Please enable in settings. All services stopped")
        case .authorizedAlways:
            logger.debug("Location always is authorized")
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            logger.debug("Location when in use is authorized")
        @unknown default:
            stopAll()
            logger.error("Unknown authorization status. All services stopped")
            break
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Mode management
    func updateMode(for phase: ScenePhase) {
        lastPhase = phase
        let status = manager.authorizationStatus
        
        if phase == .inactive { return }
        
        let desired: Mode = {
            switch (phase, status) {
            case (.active, .authorizedAlways), (.active, .authorizedWhenInUse): return .foreground
            case (.background, .authorizedAlways):                              return .background
            default:                                                            return .stopped
            }
        }()
        
        guard desired != currentMode else { return }
        
        switch desired {
        case .foreground:
            logger.debug("Starting foreground location services")
            manager.stopMonitoringSignificantLocationChanges()
            startForegroundStreaming()
        case .background:
            logger.debug("Starting background significant location changes")
            stopForegroundStreaming()
            manager.startMonitoringSignificantLocationChanges()
        case .stopped:
            logger.debug("Stopping location services")
            stopAll()
        }
        logger.debug("Phase = \(String(describing: phase), privacy: .public) auth = \(status.rawValue, privacy: .public) -> mode = \(String(describing: desired), privacy: .public)")
        currentMode = desired
    }
    
    func stopAll() {
        stopForegroundStreaming()
        manager.stopMonitoringSignificantLocationChanges()
        logger.debug("Location services stopped")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Explicitly ensure we remain on the MainActor even if Core Location calls off-main.
        Task { @MainActor in
            updateMode(for: lastPhase)
        }
    }
    
    
    /// Delegate location change path. Only intended for Significant Location Change, or legacy live updates
    /// - Parameters:
    ///   - manager: self
    ///   - locations: array of locations from the system
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        Task {
            await onUpdate(
                .init(
                    coordinates: loc.coordinate,
                    timestamp: loc.timestamp,
                    accuracy: loc.horizontalAccuracy
                )
            )
        }
    }
    
    private func startForegroundStreaming() {
        guard streamTask == nil else { return }
        logger.debug("Starting CLLocationupdate live update stream")
        streamTask = Task { [weak self] in
            do{
                let updates = CLLocationUpdate.liveUpdates(.otherNavigation)
                for try await update in updates {
                    guard let loc = update.location else { continue }
                    await self?.onUpdate(.init(
                        coordinates: loc.coordinate,
                        timestamp: loc.timestamp,
                        accuracy: loc.horizontalAccuracy
                    ))
                }
            } catch {
                await MainActor.run {
                    self?.logger.error("Streaming ended with error: \(String(describing: error), privacy: .public)")
                }
            }
            
            await MainActor.run {
                self?.streamTask = nil
            }
        }
    }
    
    private func stopForegroundStreaming() {
        if let task = streamTask {
            logger.debug("Stopping CLLOcation live updates stream")
            task.cancel()
            streamTask = nil
        }
    }
}
