//
//  LocationPipeline.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/6/25.
//

import Foundation
import CoreLocation
import OSLog

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
    let placemarkSummary: String?
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

actor LocationProvider {
    private var lastSnapshot: LocationSnapshot?
    private var continuations: [UUID: AsyncStream<LocationSnapshot>.Continuation] = [:]
    
    private let geocoder = CLGeocoder()
    private let logger = Logger.locationPipeline
    
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
    
    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
    
    func send(update: LocationUpdate) {
        // 1) Gates (distance/time/accuracy/hysteresis). Example stubs:
        guard update.accuracy <= 1000 else { return }
        if let prev = lastSnapshot, update.timestamp.timeIntervalSince(prev.timestamp) < 30 { /* maybe bail unless moved far */ }
        
        // 2) Accept & update snapshot (placemark can follow)
        let snap = LocationSnapshot(coordinates: update.coordinates,
                                    timestamp: update.timestamp,
                                    accuracy: update.accuracy,
                                    placemarkSummary: lastSnapshot?.placemarkSummary)
        lastSnapshot = snap
        continuations.values.forEach { $0.yield(snap) }
        
        // 3) Reverse geocode (throttled) – fire-and-forget
        Task { await updatePlacemarkIfNeeded(for: update.coordinates, timestamp: update.timestamp) }
    }
    
    // MARK: - Placemark
    private func updatePlacemarkIfNeeded(for coord: CLLocationCoordinate2D, timestamp: Date) async {
        // Throttle: only when city likely changed or distance > 10km, etc.
//        if let prev = lastSnapshot {
//            let dist = haversine(prev.coordinates, coord)
//            guard dist >= 10_000 else { return }
//        }
        
        // Geocode on main thread? CLGeocoder is main-thread-oriented; wrap carefully.
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let pm = placemarks.first {
                let city = pm.locality ?? pm.subAdministrativeArea ?? pm.name
                let admin = pm.administrativeArea ?? pm.country
                let summary = [city, admin].compactMap { $0 }.joined(separator: ", ")
                
                // Update snapshot and notify
                if var snap = lastSnapshot {
                    snap = LocationSnapshot(coordinates: snap.coordinates,
                                            timestamp: snap.timestamp,
                                            accuracy: snap.accuracy,
                                            placemarkSummary: summary)
                    lastSnapshot = snap
                    continuations.values.forEach { $0.yield(snap) }
                }
            }
        } catch {
            self.logger.error("Reverse geocoding failed: \(error.localizedDescription, privacy: .public)")
        }
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
}

