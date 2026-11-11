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

    /// Derived display metadata is deliberately excluded from observation identity.
    func hasSameObservation(as other: LocationSnapshot) -> Bool {
        coordinates.latitude == other.coordinates.latitude &&
        coordinates.longitude == other.coordinates.longitude &&
        timestamp == other.timestamp && accuracy == other.accuracy && h3Cell == other.h3Cell
    }

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

    private var placemarkWork: (id: UUID, observation: LocationSnapshot, task: Task<String, Error>)?
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
        logger.debug("Presence stage=received")
        var outcome = "rejected"
        var reason = "invalid_or_out_of_order_observation"
        defer {
            logger.debug("Presence stage=\(outcome, privacy: .public) reason=\(reason, privacy: .public)")
        }
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
            let identical = update.coordinates.latitude == lastSnapshot.coordinates.latitude &&
                update.coordinates.longitude == lastSnapshot.coordinates.longitude &&
                update.accuracy == lastSnapshot.accuracy
            outcome = identical ? "suppressed" : "rejected"
            reason = identical ? "duplicate_observation" : "conflicting_timestamp"
            return identical ? .redundant : .rejected
        }

        // 2) Check accept & update snapshot and task the placemark update
        let now = update.timestamp
        if update.forceAcceptance || shouldAccept(update, now: now) {
            outcome = "accepted"
            reason = "canonical_observation"
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
            Task { _ = await ensurePlacemark(for: snap) }
            return .accepted
        } else {
            outcome = "suppressed"
            reason = "observation_throttle"
            suppressedCount &+= 1
            return .redundant
        }
    }
    
    // MARK: - Placemark/Geocoding
    
    /// Enrich only the supplied observation; a newer accepted fix remains independently owned.
    func ensurePlacemark(for observation: LocationSnapshot, timeout: Double = 8, refreshDisplay: Bool = false) async -> LocationSnapshot {
        guard let current = lastSnapshot, current.hasSameObservation(as: observation) else {
            return observation
        }
        if !refreshDisplay, current.placemarkSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return current
        }

        do {
            let work: (id: UUID, observation: LocationSnapshot, task: Task<String, Error>)
            if let pending = placemarkWork, pending.observation.hasSameObservation(as: observation) {
                work = pending
            } else {
                placemarkWork?.task.cancel()
                let geocoder = self.geocoder
                work = (UUID(), observation, Task {
                    try await withTimeout(timeout: timeout) {
                        try await geocoder.reverseGeocode(observation.coordinates)
                    }
                })
                placemarkWork = work
            }
            defer { if placemarkWork?.id == work.id { placemarkWork = nil } }
            let place = try await work.task.value
            return applyPlacemark(place, to: observation)
        } catch {
            // Keep any display metadata that another matching request already resolved.
            return lastSnapshot.flatMap { $0.hasSameObservation(as: observation) ? $0 : nil } ?? observation
        }
    }

    // MARK: Placemark Helpers
    func updatePlacemarkIfNeeded(for observation: LocationSnapshot) async {
        _ = await ensurePlacemark(for: observation, refreshDisplay: true)
    }

    private func applyPlacemark(_ summary: String, to observation: LocationSnapshot) -> LocationSnapshot {
        guard var current = lastSnapshot, current.hasSameObservation(as: observation) else {
            return observation
        }
        // An empty response is not useful enrichment and must not erase a known display name.
        guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return current }
        if current.placemarkSummary != summary {
            current.placemarkSummary = summary
            saveAndYieldSnapshot(current, reason: "placemark-enriched")
        }
        return current
    }

    private func resolveH3Cell(for coord: CLLocationCoordinate2D) -> Int64? {
        do {
            return try hasher.h3Cell(for: coord)
        } catch {
            logger.error("Presence stage=rejected reason=spatial_index_failure")
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
