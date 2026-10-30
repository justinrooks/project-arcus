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
//38.037293, -84.896337  38.032732, -85.341293
@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate {
    enum Mode { case stopped, foreground, background }
    private var currentMode: Mode = .stopped
    private var lastPhase: ScenePhase = .inactive
    
    private let manager: CLLocationManager
    private let authorizationOverride: CLAuthorizationStatus?
    private let logger = Logger.locationManager
    private let onUpdate: LocationSink
    private var onBackgroundLocationChange: (@Sendable () async -> Void)?
    private var onAuthorizationChange: (@MainActor @Sendable (CLAuthorizationStatus, CLAccuracyAuthorization?) -> Void)?
    private var streamTask: Task<Void, Never>?
    private struct RefreshLocationWaiter {
        let continuation: CheckedContinuation<Bool, Never>
        let timeoutTask: Task<Void, Never>
    }
    // Waiters leave this set when delivery starts, but remain pending through acceptance.
    private var awaitingRefreshLocationIDs: Set<UUID> = []
    private var pendingRefreshLocationContinuations: [UUID: RefreshLocationWaiter] = [:]
    private let oneShotTimeoutSleep: @MainActor @Sendable (Duration) async throws -> Void
    private(set) var authStatus: CLAuthorizationStatus = .notDetermined
    private(set) var accuracyAuthorization: CLAccuracyAuthorization?
    
    init(
        manager: CLLocationManager = CLLocationManager(),
        onUpdate: @escaping LocationSink,
        oneShotTimeoutSleep: @escaping @MainActor @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        }
    ) {
        self.manager = manager
        self.authorizationOverride = Self.authorizationOverrideFromEnvironment()
        self.onUpdate = onUpdate
        self.oneShotTimeoutSleep = oneShotTimeoutSleep
        
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        //        manager.showsBackgroundLocationIndicator = true
        manager.distanceFilter = 1650 // causes the manager to not report location changes less than 1650m
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authStatus = currentAuthorizationStatus()
        accuracyAuthorization = currentAccuracyAuthorization()
    }
    
    
    func checkLocationAuthorization(isActive: Bool) {
        self.authStatus = currentAuthorizationStatus()
        self.accuracyAuthorization = currentAccuracyAuthorization()
        onAuthorizationChange?(authStatus, accuracyAuthorization)
        guard isActive else { return } // never prompt in background
        
        switch authStatus {
        case .notDetermined:
            guard authorizationOverride == nil else { return }
            logger.notice("Requesting when-in-use location authorization")
            manager.requestWhenInUseAuthorization()
        case .restricted:
            stopAll()
            logger.warning("Location Services are restricted. All services stopped")
        case .denied:
            stopAll()
            logger.critical("You've denied SkyAware access to your location. Please enable in settings. All services stopped")
        case .authorizedAlways:
            logger.debug("Location authorization available status=authorizedAlways")
        case .authorizedWhenInUse:
            logger.debug("Location authorization available status=authorizedWhenInUse")
        @unknown default:
            stopAll()
            logger.error("Unknown authorization status. All services stopped")
            break
        }
    }

    @discardableResult
    func requestAlwaysAuthorizationUpgradeIfNeeded() -> Bool {
        let status = currentAuthorizationStatus()
        let accuracy = currentAccuracyAuthorization()
        authStatus = status
        accuracyAuthorization = accuracy
        onAuthorizationChange?(status, accuracy)

        guard authorizationOverride == nil else {
            logger.debug("Skipping always-authorization upgrade due to UI test authorization override")
            return false
        }

        guard status == .authorizedWhenInUse else {
            logger.debug("Skipping always-authorization upgrade; current status=\(status.logName, privacy: .public)")
            return false
        }

        logger.notice(
            "Requesting location always authorization upgrade accuracy=\(accuracy.logName, privacy: .public)"
        )
        manager.requestAlwaysAuthorization()
        return true
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func setAuthorizationChangeHandler(
        _ handler: (@MainActor @Sendable (CLAuthorizationStatus, CLAccuracyAuthorization?) -> Void)?
    ) {
        onAuthorizationChange = handler
    }

    func setBackgroundLocationChangeHandler(
        _ handler: (@Sendable () async -> Void)?
    ) {
        onBackgroundLocationChange = handler
    }

    func refreshCurrentLocation(timeout: Double = 12) async -> Bool {
        let status = currentAuthorizationStatus()
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            logger.notice("Skipping one-shot location refresh due to auth status=\(status.logName, privacy: .public)")
            return false
        }

        let success = await awaitFreshLocationRequest(timeout: timeout)
        return success && !Task.isCancelled
    }
    
    // MARK: - Mode management
    func updateMode(for phase: ScenePhase) {
        lastPhase = phase
        let status = currentAuthorizationStatus()
        
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
        logger.debug(
            "Updated location manager mode phase=\(phase.logName, privacy: .public) auth=\(status.logName, privacy: .public) mode=\(desired.logName, privacy: .public)"
        )
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
            let effectiveStatus = currentAuthorizationStatus()
            let effectiveAccuracy = currentAccuracyAuthorization()
            authStatus = effectiveStatus
            accuracyAuthorization = effectiveAccuracy
            logger.info(
                "Location authorization changed status=\(effectiveStatus.logName, privacy: .public) accuracy=\(effectiveAccuracy.logName, privacy: .public)"
            )
            onAuthorizationChange?(effectiveStatus, effectiveAccuracy)
            updateMode(for: lastPhase)
        }
    }
    
    
    /// Delegate location change path. Only intended for Significant Location Change, or legacy live updates
    /// - Parameters:
    ///   - manager: self
    ///   - locations: array of locations from the system
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor [weak self, onUpdate] in
            let shouldHandleBackgroundLocationChange = self?.currentMode == .background
            // Snapshot ownership before acceptance suspends: later callers need a later delivery.
            let waiterIDs = self.map { Array($0.awaitingRefreshLocationIDs) } ?? []
            self?.awaitingRefreshLocationIDs.removeAll()
            let update = LocationUpdate(
                coordinates: loc.coordinate,
                timestamp: loc.timestamp,
                accuracy: loc.horizontalAccuracy,
                forceAcceptance: !waiterIDs.isEmpty
            )
            await onUpdate(update)

            if update.forceAcceptance {
                self?.resolvePendingRefreshLocationContinuations(ids: waiterIDs, with: true)
            }

            if shouldHandleBackgroundLocationChange {
                await self?.onBackgroundLocationChange?()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.logger.error("Location manager failed with error: \(error.localizedDescription, privacy: .public)")
            guard let self else { return }
            resolvePendingRefreshLocationContinuations(ids: Array(awaitingRefreshLocationIDs), with: false)
        }
    }
    
    private func startForegroundStreaming() {
        guard streamTask == nil else { return }
        logger.debug("Starting CLLocation live update stream")
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
            logger.debug("Stopping CLLocation live update stream")
            task.cancel()
            streamTask = nil
        }
    }

    private func awaitFreshLocationRequest(timeout: Double) async -> Bool {
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // onCancel can run before registration; do not leave a waiter behind in that case.
                guard !Task.isCancelled else {
                    continuation.resume(returning: false)
                    return
                }
                let shouldStartRequest = awaitingRefreshLocationIDs.isEmpty
                let timeoutTask = Task { [weak self, oneShotTimeoutSleep] in
                    do {
                        try await oneShotTimeoutSleep(.seconds(timeout))
                        self?.resolvePendingRefreshLocationContinuations(ids: [id], with: false)
                    } catch {
                        // Completion or cancellation retired this waiter's deadline.
                    }
                }
                pendingRefreshLocationContinuations[id] = RefreshLocationWaiter(
                    continuation: continuation,
                    timeoutTask: timeoutTask
                )
                awaitingRefreshLocationIDs.insert(id)
                if shouldStartRequest {
                    logger.debug("Requesting one-shot current location")
                    manager.requestLocation()
                } else {
                    logger.debug("Joining in-flight one-shot location request")
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.resolvePendingRefreshLocationContinuations(ids: [id], with: false)
            }
        }
    }

    private func resolvePendingRefreshLocationContinuations(ids: [UUID], with success: Bool) {
        for id in ids {
            guard let waiter = pendingRefreshLocationContinuations.removeValue(forKey: id) else { continue }
            awaitingRefreshLocationIDs.remove(id)
            waiter.timeoutTask.cancel()
            waiter.continuation.resume(returning: success)
        }
    }

    private func currentAuthorizationStatus() -> CLAuthorizationStatus {
        authorizationOverride ?? manager.authorizationStatus
    }

    private func currentAccuracyAuthorization() -> CLAccuracyAuthorization? {
        authorizationOverride == nil ? manager.accuracyAuthorization : nil
    }

    private static func authorizationOverrideFromEnvironment() -> CLAuthorizationStatus? {
        switch ProcessInfo.processInfo.environment["UI_TESTS_LOCATION_AUTH_MODE"] {
        case "restricted":
            return .denied
        case "authorized":
            return .authorizedWhenInUse
        default:
            return nil
        }
    }
}

private extension LocationManager.Mode {
    var logName: String {
        switch self {
        case .stopped:
            return "stopped"
        case .foreground:
            return "foreground"
        case .background:
            return "background"
        }
    }
}

private extension ScenePhase {
    var logName: String {
        switch self {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}

private extension CLAuthorizationStatus {
    var logName: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        @unknown default:
            return "unknown"
        }
    }
}

private extension CLAccuracyAuthorization {
    var logName: String {
        switch self {
        case .fullAccuracy:
            return "fullAccuracy"
        case .reducedAccuracy:
            return "reducedAccuracy"
        @unknown default:
            return "unknown"
        }
    }
}

private extension Optional where Wrapped == CLAccuracyAuthorization {
    var logName: String {
        switch self {
        case .some(let accuracy):
            return accuracy.logName
        case .none:
            return "unknown"
        }
    }
}
