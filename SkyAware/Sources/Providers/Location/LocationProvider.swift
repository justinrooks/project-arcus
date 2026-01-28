//
//  LocationProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/6/25.
//

import Foundation
import CoreLocation
import OSLog

// MARK: - Geocoding Abstraction
protocol LocationGeocoding: Sendable {
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String
}

actor CoreLocationGeocoder: LocationGeocoding {
    private let geocoder = CLGeocoder()

    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let places = try await geocoder.reverseGeocodeLocation(location)
        guard let p = places.first else { throw GeocodeError.noResults }
        return [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
    }
}

// MARK: Supporting Structs
struct LocationUpdate: Sendable {
    let coordinates: CLLocationCoordinate2D
    let timestamp: Date
    let accuracy: CLLocationAccuracy
}

struct LocationSnapshot: Sendable {
    let coordinates: CLLocationCoordinate2D
    let timestamp: Date
    let accuracy: CLLocationAccuracy
    /// “City, ST” or “County, ST” etc. Keep it short and cached.
    var placemarkSummary: String?
}

typealias LocationSink = @Sendable (LocationUpdate) async -> Void

struct LocationClient: Sendable {
    let snapshot: @Sendable () async -> LocationSnapshot?
    let updates: @Sendable () async-> AsyncStream<LocationSnapshot>
}

func makeLocationClient(provider: LocationProvider) -> LocationClient {
    .init(
        snapshot: { await provider.snapshot() },
        updates: { await provider.updates() })
}

// MARK: LocationProvider Actor

actor LocationProvider {
    private var lastSnapshot: LocationSnapshot?
    private var continuations: [UUID: AsyncStream<LocationSnapshot>.Continuation] = [:]

    private let geocoder: LocationGeocoding
    private let logger = Logger.locationProvider
    
    // Throttling
    private let throttle = LocationThrottleConfig()
    private lazy var distancePolicy = DistancePolicy(baseMeters: throttle.baseMeters)
    
    // Throttle metrics
    private var totalStreamEvents = 0
    private var acceptedCount = 0
    private var suppressedCount = 0
    
    init(geocoder: LocationGeocoding = CoreLocationGeocoder()) {
        self.geocoder = geocoder
    }

    func snapshot() async -> LocationSnapshot? { lastSnapshot }
    func updates() -> AsyncStream<LocationSnapshot> {
        AsyncStream { cont in
            if let lastSnapshot { cont.yield(lastSnapshot) }
            let id = UUID()
            continuations[id] = cont
            cont.onTermination = { @Sendable _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }
    
    /// Consumes both streaming and SLC delegate events
    func send(update: LocationUpdate) {
        totalStreamEvents &+= 1
        // 1) Accuracy Gate - drop any updates that are less accurate than we desire
        guard update.accuracy > 0, update.accuracy <= throttle.minAccuracy else {
            suppressedCount &+= 1
            logger.trace("Location accuracy too low: \(update.accuracy)")
            return
        }
        
        // 2) Check accept & update snapshot and task the placemark update
        let now = update.timestamp
        if shouldAccept(update, now: now) {
            acceptedCount &+= 1
            let snap = LocationSnapshot(coordinates: update.coordinates,
                                        timestamp: update.timestamp,
                                        accuracy: update.accuracy,
                                        placemarkSummary: lastSnapshot?.placemarkSummary)
            saveAndYieldSnapshot(snap)
            
            // 3) Reverse geocode – fire-and-forget
            Task { await updatePlacemarkIfNeeded(for: update.coordinates, timestamp: update.timestamp) }
        } else {
            suppressedCount &+= 1
        }
    }
    
    // MARK: - Placemark/Geocoding
    
    /// Entry point for the BackgroundOrchestrator to get a fresh placemark. This gets used in the notifications
    /// - Parameters:
    ///   - coord: coordinates to reverse geocode
    ///   - timeout: timeout so we don't consume all our background budget
    /// - Returns: updated location snap
    func ensurePlacemark(for coord: CLLocationCoordinate2D, timeout: Double = 8) async -> LocationSnapshot {
        logger.debug("Updating placemark for background task")
        do {
            let place = try await withTimeout(timeout: timeout) {
                return try await self.geocoder.reverseGeocode(coord)
            }
            let base = lastSnapshot ?? LocationSnapshot(coordinates: coord, timestamp: Date(), accuracy: kCLLocationAccuracyThreeKilometers, placemarkSummary: nil)
            let updated = LocationSnapshot(coordinates: base.coordinates,
                                           timestamp: base.timestamp,
                                           accuracy: base.accuracy,
                                           placemarkSummary: place)
            saveAndYieldSnapshot(updated)
            return updated
        } catch {
            logger.info("Failed to update placemark, falling back to last snapshot")
            // On failure or timeout, return the most recent snapshot if available, otherwise create a minimal one without a placemark.
            if let snap = lastSnapshot { return snap }
            let snap = LocationSnapshot(coordinates: coord, timestamp: Date(), accuracy: kCLLocationAccuracyThreeKilometers, placemarkSummary: nil)
            saveAndYieldSnapshot(snap)
            return snap
        }
    }
    
    // MARK: Placemark Helpers
    private func updatePlacemarkIfNeeded(for coord: CLLocationCoordinate2D, timestamp: Date) async {
        logger.debug("Starting reverse geocoding")
        do {
            let summary = try await geocoder.reverseGeocode(coord)
            
            // Update snapshot and notify
            if var snap = lastSnapshot {
                guard snap.placemarkSummary != summary else { return }
                
                snap = LocationSnapshot(coordinates: snap.coordinates,
                                        timestamp: snap.timestamp,
                                        accuracy: snap.accuracy,
                                        placemarkSummary: summary)
                saveAndYieldSnapshot(snap)
            }
        } catch {
            logger.error("Reverse geocoding failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: Snapshot Validation
    private func shouldAccept(_ u: LocationUpdate, now: Date) -> Bool {
        // If we don't have a previous snapshot, just take the first
        guard let last = lastSnapshot, let lastAt = lastSnapshot?.timestamp else { return true }
        
        let dt = now.timeIntervalSince(lastAt)
        if dt < throttle.minSeconds {
            // Too soon, drop it. But not forever
            return dt >= throttle.maxSilenceSeconds
        }
        
        let dMeters = haversine(last.coordinates, u.coordinates)
        
        let estSpeed = dt > 0 ? dMeters / dt : nil
        var threshold = distancePolicy.thresholdMeters(speedMps: estSpeed)
        
        threshold = min(max(threshold, throttle.clampForeground.lowerBound),
                        throttle.clampForeground.upperBound)
        
        // Accept the update if we've moved far enough or its been too long
        if dMeters >= threshold { return true }
        if dt >= throttle.maxSilenceSeconds { return true }
        
        return false
    }
    
    // Simple haversine (meters)
    private func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6_371_000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let x = sin(dLat/2) * sin(dLat/2) + cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(x), sqrt(1 - x))
        return R * c
    }
    
    // MARK: Helpers
    private func saveAndYieldSnapshot(_ snap: LocationSnapshot) {
        lastSnapshot = snap
        logger.debug("New location snapshot saved: \(self.lastSnapshot?.coordinates.latitude ?? 0.0, privacy: .public), \(self.lastSnapshot?.coordinates.longitude ?? 0.0, privacy: .public), \(self.lastSnapshot?.placemarkSummary ?? "unknown", privacy: .public)")
        continuations.values.forEach { $0.yield(snap) }
    }
    
    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
}
