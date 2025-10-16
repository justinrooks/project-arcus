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
    
    func send(update: LocationUpdate) {
        // 1) Gates (distance/time/accuracy/hysteresis). Example stubs:
//        guard update.accuracy <= 1000 else { return }
//        if let prev = lastSnapshot, update.timestamp.timeIntervalSince(prev.timestamp) < 30 { /* maybe bail unless moved far */ }
        
        // 2) Accept & update snapshot (placemark can follow)
        let snap = LocationSnapshot(coordinates: update.coordinates,
                                    timestamp: update.timestamp,
                                    accuracy: update.accuracy,
                                    placemarkSummary: lastSnapshot?.placemarkSummary)
        saveAndYieldSnapshot(snap)
        
        // 3) Reverse geocode (throttled) – fire-and-forget
        Task { await updatePlacemarkIfNeeded(for: update.coordinates, timestamp: update.timestamp) }
    }
    
    func ensurePlacemark(for coord: CLLocationCoordinate2D, timeout: Double = 3) async -> LocationSnapshot {
        do {
            let place = try await withTimeout(timeout: timeout) {
                return try await self.reverseGeocode(coord)
            }
            let base = lastSnapshot ?? LocationSnapshot(coordinates: coord, timestamp: Date(), accuracy: kCLLocationAccuracyThreeKilometers, placemarkSummary: nil)
            let updated = LocationSnapshot(coordinates: base.coordinates,
                                           timestamp: base.timestamp,
                                           accuracy: base.accuracy,
                                           placemarkSummary: place)
            saveAndYieldSnapshot(updated)
            return updated
        } catch {
            // On failure or timeout, return the most recent snapshot if available, otherwise create a minimal one without a placemark.
            if let snap = lastSnapshot { return snap }
            let snap = LocationSnapshot(coordinates: coord, timestamp: Date(), accuracy: kCLLocationAccuracyThreeKilometers, placemarkSummary: nil)
            saveAndYieldSnapshot(snap)
            return snap
        }
    }
    
    // MARK: - Placemark
    private func updatePlacemarkIfNeeded(for coord: CLLocationCoordinate2D, timestamp: Date) async {
        // Throttle: only when city likely changed or distance > 10km, etc.
        //        if let prev = lastSnapshot {
        //            let dist = haversine(prev.coordinates, coord)
        //            guard dist >= 10_000 else { return }
        //        }
        
        do {
            let summary = try await reverseGeocode(coord)
            
            // Update snapshot and notify
            if var snap = lastSnapshot {
                snap = LocationSnapshot(coordinates: snap.coordinates,
                                        timestamp: snap.timestamp,
                                        accuracy: snap.accuracy,
                                        placemarkSummary: summary)
                saveAndYieldSnapshot(snap)
            }
        } catch {
            logger.error("Reverse geocoding failed: \(error.localizedDescription)")
        }
    }
    
    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let places = try await geocoder.reverseGeocodeLocation(location)
        guard let p = places.first else { throw GeocodeError.noResults }
        return [p.locality, p.administrativeArea].compactMap{$0}.joined(separator: ", ")
    }
    
    private func saveAndYieldSnapshot(_ snap: LocationSnapshot) {
        lastSnapshot = snap
        logger.debug("New location snapshot saved: \(self.lastSnapshot?.coordinates.latitude ?? 0.0), \(self.lastSnapshot?.coordinates.longitude ?? 0.0), \(self.lastSnapshot?.placemarkSummary ?? "unknown")")
        continuations.values.forEach { $0.yield(snap) }
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
    
    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
    
    private func withTimeout<T: Sendable>(
        timeout: Double,
        _ task: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await task() }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw GeocodeError.noResults
            }
            let result = try await group.next()!
            group.cancelAll()
            
            return result
        }
    }
    
//    private func withTimeout<T>(_ d: Duration, _ op: @escaping @Sendable () async throws -> T) async throws -> T {
//        try await withThrowingTaskGroup(of: T.self) { group in
//            group.addTask { try await op() }
//            group.addTask {
//                try await Task.sleep(for: d)
//                throw GeocodeError.noResults
//            }
//            let result = try await group.next()!
//            group.cancelAll()
//            
//            return result
//        }
//    }
}

