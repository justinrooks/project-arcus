//
//  LocationProvider.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/6/25.
//

import Foundation
import CoreLocation
import OSLog
import SwiftyH3
import UIKit

// MARK: - Geocoding Abstraction
protocol LocationGeocoding: Sendable {
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String
}

protocol LocationHashing: Sendable {
    func h3Cell(for coord: CLLocationCoordinate2D) throws -> Int64
}

protocol LocationSnapshotUploading: Sendable {
    func upload(_ payload: LocationSnapshotPushPayload) async throws
}

protocol LocationSnapshotPushing: Sendable {
    func enqueue(_ snapshot: LocationSnapshot) async
}

actor CoreLocationGeocoder: LocationGeocoding {
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        // Use a request-scoped geocoder to avoid overlapping operations on a shared
        // CLGeocoder instance, which can cancel in-flight requests unexpectedly.
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let places = try await geocoder.reverseGeocodeLocation(location)
        guard let p = places.first else { throw GeocodeError.noResults }
        return [p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
    }
}

struct SwiftyH3Hasher: LocationHashing {
    let resolution: H3Cell.Resolution

    init(resolution: H3Cell.Resolution = .res8) {
        self.resolution = resolution
    }

    func h3Cell(for coord: CLLocationCoordinate2D) throws -> Int64 {
        let cell = try H3LatLng(coord).cell(at: resolution)
        
        return Int64(bitPattern: cell.id)
//        return cell.description
    }
}

enum LocationPushError: Error {
    case invalidResponseStatus(Int)
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
    /// Hex-encoded H3 cell id used for coarse server-side location bucketing.
    var h3Cell: Int64?
}

struct LocationSnapshotPushPayload: Codable, Equatable, Sendable {
    let capturedAt: Date
    let locationAgeSeconds: Double
    let horizontalAccuracyMeters: Double
    let cellScheme: String
    let h3Cell: Int64?
    let h3Resolution: Int?
    let county: String?
    let zone: String?
    let fireZone: String?
    let apnsDeviceToken: String
    let installationId: String
    let source: String
    let auth: String
    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String
    let apnsEnvironment: String
    
}

actor HTTPLocationSnapshotUploader: LocationSnapshotUploading {
    private let endpoint: URL
    private let http: HTTPClient
    private let encoder: JSONEncoder
    private let logger = Logger.locationPushUploader

    init(endpoint: URL, http: HTTPClient = URLSessionHTTPClient()) {
        self.endpoint = endpoint
        self.http = http
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func upload(_ payload: LocationSnapshotPushPayload) async throws {
        let body = try encoder.encode(payload)
        let response = try await http.post(endpoint, headers: requestHeaders, body: body)
        guard (200...299).contains(response.status) else {
            logger.error("Location snapshot upload failed status=\(response.status, privacy: .public)")
            throw LocationPushError.invalidResponseStatus(response.status)
        }
        logger.info("Location snapshot uploaded cell=\(String(payload.h3Cell ?? 0), privacy: .public)")
    }

    private var requestHeaders: [String: String] {
        [
            "User-Agent": HTTPRequestHeaders.userAgent(),
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
    }
}

struct NoOpLocationSnapshotPusher: LocationSnapshotPushing {
    func enqueue(_ snapshot: LocationSnapshot) async {}
}

actor LocationSnapshotPusher: LocationSnapshotPushing {
    typealias APNsTokenProvider = @Sendable () -> String
    typealias InstallationIDProvider = @Sendable () async -> String
    typealias GridRegionContextProvider = @Sendable () async -> NwsGridRegionContext?

    private let uploader: any LocationSnapshotUploading
    private let apnsTokenProvider: APNsTokenProvider
    private let installationIdProvider: InstallationIDProvider
    private let gridRegionContextProvider: GridRegionContextProvider
    private let retryDelaysSeconds: [UInt64]
    private let logger = Logger.locationPushPusher

    private var queue: [LocationSnapshotPushPayload] = []
    private var isProcessing = false

    init(
        uploader: any LocationSnapshotUploading,
        apnsTokenProvider: @escaping APNsTokenProvider = {
            UserDefaults(suiteName: "com.justinrooks.skyaware")?
                .string(forKey: RemoteNotificationRegistrar.apnsDeviceTokenKey) ?? ""
        },
        installationIdProvider: @escaping InstallationIDProvider = {
            InstallationIdentityStore.shared.installationId()
        },
        gridRegionContextProvider: @escaping GridRegionContextProvider = { nil },
        retryDelaysSeconds: [UInt64] = [0, 5, 15]
    ) {
        self.uploader = uploader
        self.apnsTokenProvider = apnsTokenProvider
        self.installationIdProvider = installationIdProvider
        self.gridRegionContextProvider = gridRegionContextProvider
        self.retryDelaysSeconds = retryDelaysSeconds
    }

    func enqueue(_ snapshot: LocationSnapshot) async {
        let regionContext = await gridRegionContextProvider()
        let installationId = await installationIdProvider()
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apnsToken.isEmpty else {
            logger.debug("Skipping location snapshot upload; APNs token unavailable")
            return
        }
        let payload = LocationSnapshotPushPayload(
            capturedAt: snapshot.timestamp,
            locationAgeSeconds: Date().timeIntervalSince(snapshot.timestamp),
            horizontalAccuracyMeters: snapshot.accuracy,
            cellScheme: snapshot.h3Cell == nil ? "ugc-only" : "h3",
            h3Cell: snapshot.h3Cell,
            h3Resolution: 8, // TODO: Make this global someday
            county: regionContext?.county,
            zone: regionContext?.zone,
            fireZone: regionContext?.fireZone,
            apnsDeviceToken: apnsToken,
            installationId: installationId,
            source: "unknown",
            auth: {
                switch CLLocationManager().authorizationStatus {
                case .authorizedAlways: return "always"
                case .authorizedWhenInUse: return "whenInUse"
                case .denied: return "denied"
                case .restricted: return "restricted"
                case .notDetermined: return "notDetermined"
                @unknown default: return "unknown"
                }
            }(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            platform: "iOS",
            osVersion: await UIDevice.current.systemVersion,
            apnsEnvironment: {
                #if DEBUG
                return "sandbox"
                #else
                return "prod"
                #endif
            }()
        )

        queue.append(payload)

        guard !isProcessing else { return }
        isProcessing = true
        await drainQueue()
        isProcessing = false
    }

    private func drainQueue() async {
        while !queue.isEmpty {
            let payload = queue.removeFirst()
            _ = await uploadWithRetry(payload)
        }
    }

    private func uploadWithRetry(_ payload: LocationSnapshotPushPayload) async -> Bool {
        for (index, delay) in retryDelaysSeconds.enumerated() {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(Int(delay)))
            }
            do {
                try await uploader.upload(payload)
                return true
            } catch is CancellationError {
                logger.debug("Location snapshot upload cancelled")
                return false
            } catch {
                let isFinalAttempt = index == retryDelaysSeconds.count - 1
                if isFinalAttempt {
                    logger.error("Location snapshot upload failed after retries: \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.warning("Location snapshot upload attempt failed; retrying")
                }
            }
        }

        return false
    }
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
    private let hasher: LocationHashing
    private let snapshotPusher: LocationSnapshotPushing
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
        snapshotPusher: LocationSnapshotPushing = NoOpLocationSnapshotPusher()
    ) {
        self.geocoder = geocoder
        self.hasher = hasher
        self.snapshotPusher = snapshotPusher
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
                                        placemarkSummary: lastSnapshot?.placemarkSummary,
                                        h3Cell: resolveH3Cell(for: update.coordinates) ?? lastSnapshot?.h3Cell)
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
            let base = lastSnapshot ?? LocationSnapshot(
                coordinates: coord,
                timestamp: Date(),
                accuracy: kCLLocationAccuracyThreeKilometers,
                placemarkSummary: nil,
                h3Cell: resolveH3Cell(for: coord)
            )
            let coordChanged = base.coordinates.latitude != coord.latitude || base.coordinates.longitude != coord.longitude
            let updated = LocationSnapshot(coordinates: coord,
                                           timestamp: coordChanged ? Date() : base.timestamp,
                                           accuracy: base.accuracy,
                                           placemarkSummary: place,
                                           h3Cell: resolveH3Cell(for: coord) ?? base.h3Cell)
            saveAndYieldSnapshot(updated)
            return updated
        } catch {
            logger.info("Failed to update placemark, falling back to last snapshot")
            // On failure or timeout, return the most recent snapshot if available, otherwise create a minimal one without a placemark.
            if let snap = lastSnapshot { return snap }
            let snap = LocationSnapshot(
                coordinates: coord,
                timestamp: Date(),
                accuracy: kCLLocationAccuracyThreeKilometers,
                placemarkSummary: nil,
                h3Cell: resolveH3Cell(for: coord)
            )
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
                // Ignore late geocoder completions that would regress snapshot recency.
                guard timestamp >= snap.timestamp else { return }
                guard snap.placemarkSummary != summary else { return }
                
                snap = LocationSnapshot(coordinates: snap.coordinates,
                                        timestamp: snap.timestamp,
                                        accuracy: snap.accuracy,
                                        placemarkSummary: summary,
                                        h3Cell: snap.h3Cell)
                saveAndYieldSnapshot(snap)
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
        Task(priority: .utility) { [snapshotPusher] in
            await snapshotPusher.enqueue(snap)
        }
    }
    
    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
}
