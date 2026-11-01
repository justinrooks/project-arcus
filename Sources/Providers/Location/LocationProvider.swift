//
//  LocationProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/6/25.
//

import Foundation
import CoreLocation
import OSLog

// MARK: Supporting Structs
struct LocationUpdate: Sendable {
    let coordinates: CLLocationCoordinate2D
    let timestamp: Date
    let accuracy: CLLocationAccuracy
    let forceAcceptance: Bool

    init(
        coordinates: CLLocationCoordinate2D,
        timestamp: Date,
        accuracy: CLLocationAccuracy,
        forceAcceptance: Bool = false
    ) {
        self.coordinates = coordinates
        self.timestamp = timestamp
        self.accuracy = accuracy
        self.forceAcceptance = forceAcceptance
    }
}

struct LocationSnapshot: Sendable, Equatable {
    let coordinates: CLLocationCoordinate2D
    let timestamp: Date
    let accuracy: CLLocationAccuracy
    /// “City, ST” or “County, ST” etc. Keep it short and cached.
    var placemarkSummary: String?
    /// Hex-encoded H3 cell id used for coarse server-side location bucketing.
    var h3Cell: Int64?

    static func == (lhs: LocationSnapshot, rhs: LocationSnapshot) -> Bool {
        lhs.coordinates.latitude == rhs.coordinates.latitude &&
        lhs.coordinates.longitude == rhs.coordinates.longitude &&
        lhs.timestamp == rhs.timestamp &&
        lhs.accuracy == rhs.accuracy &&
        lhs.placemarkSummary == rhs.placemarkSummary &&
        lhs.h3Cell == rhs.h3Cell
    }
}

enum LocationAcceptance: Sendable, Equatable {
    case accepted
    /// Duplicate or intentionally throttled by the movement/time policy; no new evidence was stored.
    case redundant
    case rejected
}

typealias LocationSink = @Sendable (LocationUpdate) async -> LocationAcceptance

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
    private static let cachedSnapshotMaxAge: TimeInterval = 60 * 60

    private var lastSnapshot: LocationSnapshot?
    private var continuations: [UUID: AsyncStream<LocationSnapshot>.Continuation] = [:]

    private let geocoder: LocationGeocoding
    private let hasher: LocationHashing
    private let snapshotCache: LocationSnapshotCaching
    private let nowProvider: @Sendable () -> Date
    private let logger = Logger.locationProvider
    
    // Throttling
    private let throttle = LocationThrottleConfig()
    private lazy var distancePolicy = DistancePolicy(baseMeters: throttle.baseMeters)
    
    // Throttle metrics
    private var totalStreamEvents = 0
    private var acceptedCount = 0
    private var suppressedCount = 0
    
    init(
        geocoder: LocationGeocoding = CoreLocationGeocoder(),
        hasher: LocationHashing = SwiftyH3Hasher(),
        snapshotCache: LocationSnapshotCaching = NoOpLocationSnapshotCache(),
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.geocoder = geocoder
        self.hasher = hasher
        self.snapshotCache = snapshotCache
        self.nowProvider = nowProvider
        lastSnapshot = Self.restoredSnapshotIfFresh(snapshotCache.load(), hasher: hasher, nowProvider: nowProvider)
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
    @discardableResult
    func send(update: LocationUpdate) -> LocationAcceptance {
        totalStreamEvents &+= 1
        // Force bypasses throttling only; it never bypasses observation validity or ordering.
        guard CLLocationCoordinate2DIsValid(update.coordinates),
              update.accuracy.isFinite, update.accuracy > 0,
              update.accuracy <= throttle.minAccuracy,
              update.timestamp.timeIntervalSince1970.isFinite,
              update.timestamp <= nowProvider(),
              lastSnapshot.map({ update.timestamp >= $0.timestamp }) ?? true,
              let resolvedH3Cell = resolveH3Cell(for: update.coordinates) else {
            suppressedCount &+= 1
            return .rejected
        }
        if let lastSnapshot, update.timestamp == lastSnapshot.timestamp {
            suppressedCount &+= 1
            return update.coordinates.latitude == lastSnapshot.coordinates.latitude &&
                update.coordinates.longitude == lastSnapshot.coordinates.longitude &&
                update.accuracy == lastSnapshot.accuracy ? .redundant : .rejected
        }

        // 2) Check accept & update snapshot and task the placemark update
        let now = update.timestamp
        if update.forceAcceptance || shouldAccept(update, now: now) {
            acceptedCount &+= 1
            let snap = LocationSnapshot(coordinates: update.coordinates,
                                        timestamp: update.timestamp,
                                        accuracy: update.accuracy,
                                        placemarkSummary: lastSnapshot?.coordinates.latitude == update.coordinates.latitude &&
                                            lastSnapshot?.coordinates.longitude == update.coordinates.longitude
                                            ? lastSnapshot?.placemarkSummary
                                            : nil,
                                        h3Cell: resolvedH3Cell)
            saveAndYieldSnapshot(snap, reason: "accepted-update")
            
            // 3) Reverse geocode – fire-and-forget
            Task { await updatePlacemarkIfNeeded(for: update.coordinates, timestamp: update.timestamp) }
            return .accepted
        } else {
            suppressedCount &+= 1
            return .redundant
        }
    }
    
    // MARK: - Placemark/Geocoding
    
    /// Entry point for the BackgroundOrchestrator to get a fresh placemark. This gets used in the notifications
    /// - Parameters:
    ///   - coord: coordinates to reverse geocode
    ///   - timeout: timeout so we don't consume all our background budget
    /// - Returns: updated location snap
    func ensurePlacemark(for coord: CLLocationCoordinate2D, timeout: Double = 8) async -> LocationSnapshot {
        if let lastSnapshot,
           lastSnapshot.coordinates.latitude == coord.latitude,
           lastSnapshot.coordinates.longitude == coord.longitude,
           lastSnapshot.placemarkSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
           lastSnapshot.h3Cell != nil {
            logger.debug("Reusing cached placemark for unchanged location context")
            return lastSnapshot
        }

        // Geocoding enriches accepted evidence; it cannot create a location observation.
        guard let base = lastSnapshot,
              base.coordinates.latitude == coord.latitude,
              base.coordinates.longitude == coord.longitude else {
            return lastSnapshot ?? LocationSnapshot(
                coordinates: coord, timestamp: .distantPast,
                accuracy: kCLLocationAccuracyThreeKilometers,
                placemarkSummary: nil, h3Cell: nil
            )
        }
        do {
            let place = try await withTimeout(timeout: timeout) {
                try await self.geocoder.reverseGeocode(coord)
            }
            guard var current = lastSnapshot,
                  current.timestamp == base.timestamp,
                  current.coordinates.latitude == coord.latitude,
                  current.coordinates.longitude == coord.longitude else {
                return lastSnapshot ?? base
            }
            if current.placemarkSummary != place {
                current.placemarkSummary = place
                saveAndYieldSnapshot(current, reason: "placemark-resolved")
            }
            return current
        } catch {
            return lastSnapshot ?? base
        }
    }

    // MARK: Placemark Helpers
    private func updatePlacemarkIfNeeded(for coord: CLLocationCoordinate2D, timestamp: Date) async {
        logger.debug("Resolving placemark for accepted location update")
        do {
            let summary = try await geocoder.reverseGeocode(coord)
            
            // Update snapshot and notify
            if var snap = lastSnapshot {
                // Ignore late geocoder completions that would regress snapshot recency.
                guard timestamp >= snap.timestamp else { return }
                guard snap.placemarkSummary != summary else { return }
                
                snap = LocationSnapshot(coordinates: snap.coordinates,
                                        timestamp: snap.timestamp,
                                        accuracy: snap.accuracy,
                                        placemarkSummary: summary,
                                        h3Cell: snap.h3Cell)
                saveAndYieldSnapshot(snap, reason: "placemark-enriched")
            }
        } catch {
            logger.error("Reverse geocoding failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func resolveH3Cell(for coord: CLLocationCoordinate2D) -> Int64? {
        do {
            return try hasher.h3Cell(for: coord)
        } catch {
            logger.error("H3 indexing failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func restoredSnapshotIfFresh(
        _ snapshot: LocationSnapshot?,
        hasher: LocationHashing,
        nowProvider: @Sendable () -> Date
    ) -> LocationSnapshot? {
        guard let snapshot,
              CLLocationCoordinate2DIsValid(snapshot.coordinates),
              snapshot.accuracy.isFinite, snapshot.accuracy > 0,
              snapshot.accuracy <= LocationThrottleConfig().minAccuracy,
              let storedCell = snapshot.h3Cell,
              let derivedCell = try? hasher.h3Cell(for: snapshot.coordinates),
              storedCell == derivedCell else { return nil }

        let age = nowProvider().timeIntervalSince(snapshot.timestamp)
        guard age >= 0, age <= Self.cachedSnapshotMaxAge else {
            Logger.locationProvider.notice("Ignoring stale cached location snapshot with age \(age, privacy: .public)s")
            return nil
        }

        return snapshot
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
    private func saveAndYieldSnapshot(_ snap: LocationSnapshot, reason: String) {
        lastSnapshot = snap
        snapshotCache.save(snap)
        logger.debug(
            "Saved location snapshot reason=\(reason, privacy: .public) hasPlacemark=\((snap.placemarkSummary != nil), privacy: .public) hasH3=\((snap.h3Cell != nil), privacy: .public)"
        )
        continuations.values.forEach { $0.yield(snap) }
    }
    
    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
}
