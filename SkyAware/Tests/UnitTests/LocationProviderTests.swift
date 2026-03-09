import Foundation
import CoreLocation
import Testing
@testable import SkyAware

@Suite("LocationProvider")
struct LocationProviderTests {
    private let sampleH3Cell: Int64 = 0x872681364FFFFFF

    private indirect enum GeocoderMode {
        case success(String)
        case failure(Error)
        case delay(seconds: Double, then: GeocoderMode)
    }

    private struct MockGeocoder: LocationGeocoding {
        let mode: GeocoderMode

        func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
            switch mode {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            case .delay(let seconds, let then):
                try await Task.sleep(for: .seconds(seconds))
                return try await MockGeocoder(mode: then).reverseGeocode(coord)
            }
        }
    }
    
    private struct MockHasher: LocationHashing {
        enum Mode {
            case success(Int64)
            case failure(Error)
        }
        
        let mode: Mode
        
        func h3Cell(for coord: CLLocationCoordinate2D) throws -> Int64 {
            switch mode {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
    }
    
    private actor MockSnapshotPusher: LocationSnapshotPushing {
        private var snapshots: [LocationSnapshot] = []
        
        func enqueue(_ snapshot: LocationSnapshot) async {
            snapshots.append(snapshot)
        }
        
        func allSnapshots() -> [LocationSnapshot] {
            snapshots
        }
    }
    
    private actor MockSnapshotUploader: LocationSnapshotUploading {
        private var payloads: [LocationSnapshotPushPayload] = []
        
        func upload(_ payload: LocationSnapshotPushPayload) async throws {
            payloads.append(payload)
        }
        
        func uploadedPayloads() -> [LocationSnapshotPushPayload] {
            payloads
        }
    }
    
    private final class MockSnapshotCache: @unchecked Sendable, LocationSnapshotCaching {
        private(set) var storedSnapshot: LocationSnapshot?
        
        init(storedSnapshot: LocationSnapshot? = nil) {
            self.storedSnapshot = storedSnapshot
        }
        
        func load() -> LocationSnapshot? {
            storedSnapshot
        }
        
        func save(_ snapshot: LocationSnapshot) {
            storedSnapshot = snapshot
        }
    }

    private actor RacingGeocoder: LocationGeocoding {
        private var callCount = 0
        private var firstContinuation: CheckedContinuation<String, Never>?

        func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
            callCount += 1
            if callCount == 1 {
                return await withCheckedContinuation { continuation in
                    firstContinuation = continuation
                }
            }
            return "Latest City"
        }

        func resolveFirst(with value: String) {
            firstContinuation?.resume(returning: value)
            firstContinuation = nil
        }
    }

    private func makeUpdate(lat: Double, lon: Double, timestamp: Date, accuracy: CLLocationAccuracy) -> LocationUpdate {
        LocationUpdate(
            coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            timestamp: timestamp,
            accuracy: accuracy
        )
    }

    @Test("snapshot is nil before any updates")
    func snapshot_isNilInitially() async {
        let provider = LocationProvider()
        let snapshot = await provider.snapshot()
        #expect(snapshot == nil)
    }
    
    @Test("snapshot restores from cache at startup")
    func snapshot_restoresFromCacheAtStartup() async throws {
        let now = Date(timeIntervalSince1970: 1_234_500)
        let cached = LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
            timestamp: now,
            accuracy: 42,
            placemarkSummary: "Oklahoma City, OK",
            h3Cell: sampleH3Cell
        )
        let cache = MockSnapshotCache(storedSnapshot: cached)
        let provider = LocationProvider(snapshotCache: cache)
        
        let snapshot = try #require(await provider.snapshot())
        #expect(snapshot.coordinates.latitude == cached.coordinates.latitude)
        #expect(snapshot.coordinates.longitude == cached.coordinates.longitude)
        #expect(snapshot.timestamp == now)
        #expect(snapshot.placemarkSummary == "Oklahoma City, OK")
        #expect(snapshot.h3Cell == sampleH3Cell)
    }

    @Test("snapshot ignores stale cached snapshot at startup")
    func snapshot_ignoresStaleCacheAtStartup() async {
        let now = Date(timeIntervalSince1970: 20_000)
        let staleTimestamp = now.addingTimeInterval(-(60 * 60 + 1))
        let cached = LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
            timestamp: staleTimestamp,
            accuracy: 42,
            placemarkSummary: "Oklahoma City, OK",
            h3Cell: sampleH3Cell
        )
        let cache = MockSnapshotCache(storedSnapshot: cached)
        let provider = LocationProvider(snapshotCache: cache, nowProvider: { now })

        let snapshot = await provider.snapshot()
        #expect(snapshot == nil)
    }

    @Test("send rejects updates with low accuracy")
    func send_rejectsLowAccuracy() async {
        let provider = LocationProvider()
        let now = Date()
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: now, accuracy: 150))

        let snapshot = await provider.snapshot()
        #expect(snapshot == nil)
    }

    @Test("send accepts first update and stores snapshot")
    func send_acceptsFirstUpdate() async throws {
        let provider = LocationProvider()
        let now = Date()
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: now, accuracy: 50))

        let snapshot = await provider.snapshot()
        let value = try #require(snapshot)
        #expect(value.coordinates.latitude == 39.0)
        #expect(value.coordinates.longitude == -104.0)
        #expect(value.timestamp == now)
        #expect(value.accuracy == 50)
    }
    
    @Test("send persists accepted snapshot to cache")
    func send_persistsAcceptedSnapshotToCache() async throws {
        let cache = MockSnapshotCache()
        let provider = LocationProvider(snapshotCache: cache)
        let now = Date(timeIntervalSince1970: 1_234_560)
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: now, accuracy: 50))
        
        let cached = try #require(cache.storedSnapshot)
        #expect(cached.coordinates.latitude == 39.0)
        #expect(cached.coordinates.longitude == -104.0)
        #expect(cached.timestamp == now)
    }
    
    @Test("send stores h3 hash when hasher succeeds")
    func send_storesH3Hash() async throws {
        let provider = LocationProvider(
            geocoder: MockGeocoder(mode: .failure(GeocodeError.noResults)),
            hasher: MockHasher(mode: .success(sampleH3Cell))
        )
        let now = Date()
        
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: now, accuracy: 25))
        
        let snapshot = try #require(await provider.snapshot())
        #expect(snapshot.h3Cell == sampleH3Cell)
    }
    
    @Test("send pushes accepted snapshot to location snapshot pusher")
    func send_pushesAcceptedSnapshot() async throws {
        let pusher = MockSnapshotPusher()
        let provider = LocationProvider(
            geocoder: MockGeocoder(mode: .failure(GeocodeError.noResults)),
            hasher: MockHasher(mode: .success(sampleH3Cell)),
            snapshotPusher: pusher
        )
        let now = Date()
        
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: now, accuracy: 25))

        let pushed = await waitForSnapshots(from: pusher)
        let first = try #require(pushed.first)
        #expect(pushed.count == 1)
        #expect(first.timestamp == now)
        #expect(first.h3Cell == sampleH3Cell)
    }

    @Test("snapshot pusher payload includes timestamp and apns token")
    func snapshotPusher_includesTimestampAndApnsToken() async throws {
        let uploader = MockSnapshotUploader()
        let pusher = LocationSnapshotPusher(
            uploader: uploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            gridRegionContextProvider: {
                NwsGridRegionContext(county: "OKC109", zone: "OKZ025", fireZone: "OKZ025")
            },
            retryDelaysSeconds: [0]
        )
        
        let ts = Date(timeIntervalSince1970: 1_234_567)
        let snap = LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
            timestamp: ts,
            accuracy: 42,
            placemarkSummary: "OKC, OK",
            h3Cell: sampleH3Cell
        )
        
        await pusher.enqueue(snap)
        
        let payloads = await uploader.uploadedPayloads()
        let payload = try #require(payloads.first)
        #expect(payload.capturedAt == ts)
        #expect(payload.installationId == "install-abc-123")
        #expect(payload.apnsDeviceToken == "apns-token-123")
        #expect(payload.county == "OKC109")
        #expect(payload.zone == "OKZ025")
        #expect(payload.fireZone == "OKZ025")
        #expect(payload.h3Cell == sampleH3Cell)
    }

    @Test("snapshot pusher skips upload when APNs token is missing")
    func snapshotPusher_skipsUploadWithoutApnsToken() async {
        let uploader = MockSnapshotUploader()
        let pusher = LocationSnapshotPusher(
            uploader: uploader,
            apnsTokenProvider: { " " },
            installationIdProvider: { "install-abc-123" },
            retryDelaysSeconds: [0]
        )

        let snap = LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
            timestamp: Date(timeIntervalSince1970: 1_234_567),
            accuracy: 42,
            placemarkSummary: "OKC, OK",
            h3Cell: sampleH3Cell
        )

        await pusher.enqueue(snap)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.isEmpty)
    }

    private func waitForSnapshots(
        from pusher: MockSnapshotPusher,
        timeoutMs: Int = 500,
        pollMs: Int = 10
    ) async -> [LocationSnapshot] {
        let maxAttempts = max(1, timeoutMs / pollMs)
        for _ in 0..<maxAttempts {
            let snapshots = await pusher.allSnapshots()
            if !snapshots.isEmpty {
                return snapshots
            }
            try? await Task.sleep(for: .milliseconds(pollMs))
        }

        return await pusher.allSnapshots()
    }

    @Test("send suppresses rapid updates inside minSeconds window")
    func send_suppressesBurstingUpdates() async throws {
        let provider = LocationProvider()
        let t0 = Date()
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: t0, accuracy: 50))

        let t1 = t0.addingTimeInterval(1)
        await provider.send(update: makeUpdate(lat: 39.1, lon: -104.1, timestamp: t1, accuracy: 50))

        let snapshot = await provider.snapshot()
        let value = try #require(snapshot)
        #expect(value.coordinates.latitude == 39.0)
        #expect(value.coordinates.longitude == -104.0)
        #expect(value.timestamp == t0)
    }

    @Test("send accepts update after maxSilenceSeconds even without movement")
    func send_acceptsAfterMaxSilence() async throws {
        let provider = LocationProvider()
        let t0 = Date()
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: t0, accuracy: 50))

        let t1 = t0.addingTimeInterval(70)
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: t1, accuracy: 50))

        let snapshot = await provider.snapshot()
        let value = try #require(snapshot)
        #expect(value.timestamp == t1)
    }

    @Test("send accepts movement beyond distance threshold")
    func send_acceptsLargeMovement() async throws {
        let provider = LocationProvider()
        let t0 = Date()
        await provider.send(update: makeUpdate(lat: 0.0, lon: 0.0, timestamp: t0, accuracy: 50))

        let t1 = t0.addingTimeInterval(10)
        // ~2.2km move north, should exceed clamped threshold (<= 2000m)
        await provider.send(update: makeUpdate(lat: 0.02, lon: 0.0, timestamp: t1, accuracy: 50))

        let snapshot = await provider.snapshot()
        let value = try #require(snapshot)
        #expect(value.coordinates.latitude == 0.02)
        #expect(value.coordinates.longitude == 0.0)
        #expect(value.timestamp == t1)
    }

    @Test("updates stream yields last snapshot then subsequent accepted updates")
    func updates_streamYieldsSnapshots() async throws {
        let provider = LocationProvider()
        let t0 = Date()
        await provider.send(update: makeUpdate(lat: 40.0, lon: -105.0, timestamp: t0, accuracy: 50))

        let stream = await provider.updates()
        var iterator = stream.makeAsyncIterator()

        let first = await iterator.next()
        let firstSnap = try #require(first)
        #expect(firstSnap.coordinates.latitude == 40.0)
        #expect(firstSnap.coordinates.longitude == -105.0)

        let t1 = t0.addingTimeInterval(10)
        await provider.send(update: makeUpdate(lat: 40.02, lon: -105.0, timestamp: t1, accuracy: 50))

        let second = await iterator.next()
        let secondSnap = try #require(second)
        #expect(secondSnap.timestamp == t1)
        #expect(secondSnap.coordinates.latitude == 40.02)
    }

    @Test("ensurePlacemark updates placemark on success")
    func ensurePlacemark_updatesPlacemarkOnSuccess() async throws {
        let provider = LocationProvider(geocoder: MockGeocoder(mode: .success("Denver, CO")))
        let coord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)

        let snap = await provider.ensurePlacemark(for: coord, timeout: 1)
        #expect(snap.placemarkSummary == "Denver, CO")
    }

    @Test("ensurePlacemark returns last snapshot when geocoding fails")
    func ensurePlacemark_returnsLastSnapshotOnFailure() async throws {
        let provider = LocationProvider(geocoder: MockGeocoder(mode: .failure(GeocodeError.noResults)))
        let coord = CLLocationCoordinate2D(latitude: 39.0, longitude: -104.0)
        let t0 = Date()
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: t0, accuracy: 50))

        let snap = await provider.ensurePlacemark(for: coord, timeout: 1)
        #expect(snap.timestamp == t0)
        #expect(snap.placemarkSummary == nil)
    }

    @Test("ensurePlacemark falls back when timeout elapses")
    func ensurePlacemark_timesOutAndFallsBack() async {
        let provider = LocationProvider(geocoder: MockGeocoder(mode: .delay(seconds: 1.0, then: .success("Late City"))))
        let coord = CLLocationCoordinate2D(latitude: 39.0, longitude: -104.0)

        let snap = await provider.ensurePlacemark(for: coord, timeout: 0.005)
        #expect(snap.placemarkSummary == nil)
    }

    @Test("ensurePlacemark aligns snapshot to requested coordinates and refreshes timestamp when coordinate changes")
    func ensurePlacemark_alignsCoordinatesAndRefreshesTimestampOnCoordinateChange() async throws {
        let provider = LocationProvider(geocoder: MockGeocoder(mode: .success("Yukon, OK")))
        let t0 = Date(timeIntervalSince1970: 1_000)

        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: t0, accuracy: 50))

        let requested = CLLocationCoordinate2D(latitude: 35.506, longitude: -97.762)
        let snap = await provider.ensurePlacemark(for: requested, timeout: 1)

        #expect(snap.coordinates.latitude == requested.latitude)
        #expect(snap.coordinates.longitude == requested.longitude)
        #expect(snap.timestamp > t0)
        #expect(snap.placemarkSummary == "Yukon, OK")

        let stored = try #require(await provider.snapshot())
        #expect(stored.coordinates.latitude == requested.latitude)
        #expect(stored.coordinates.longitude == requested.longitude)
        #expect(stored.timestamp == snap.timestamp)
    }

    @Test("ensurePlacemark preserves timestamp when coordinate does not change")
    func ensurePlacemark_preservesTimestampWhenCoordinateUnchanged() async throws {
        let provider = LocationProvider(geocoder: MockGeocoder(mode: .success("Bennett, CO")))
        let coord = CLLocationCoordinate2D(latitude: 39.7529, longitude: -104.4489)
        let t0 = Date(timeIntervalSince1970: 2_000)

        await provider.send(update: makeUpdate(lat: coord.latitude, lon: coord.longitude, timestamp: t0, accuracy: 50))

        let snap = await provider.ensurePlacemark(for: coord, timeout: 1)
        #expect(snap.coordinates.latitude == coord.latitude)
        #expect(snap.coordinates.longitude == coord.longitude)
        #expect(snap.timestamp == t0)
        #expect(snap.placemarkSummary == "Bennett, CO")
    }

    @Test("updatePlacemarkIfNeeded updates snapshot when summary changes")
    func updatePlacemark_updatesWhenSummaryChanges() async throws {
        let provider = LocationProvider(geocoder: MockGeocoder(mode: .success("Boulder, CO")))
        let stream = await provider.updates()
        var iterator = stream.makeAsyncIterator()

        let t0 = Date()
        await provider.send(update: makeUpdate(lat: 40.0, lon: -105.0, timestamp: t0, accuracy: 50))

        let first = await iterator.next()
        let firstSnap = try #require(first)
        #expect(firstSnap.placemarkSummary == nil)

        let second = await iterator.next()
        let secondSnap = try #require(second)
        #expect(secondSnap.placemarkSummary == "Boulder, CO")
    }

    @Test("updatePlacemarkIfNeeded does not change summary when it matches")
    func updatePlacemark_noChangeWhenSameSummary() async throws {
        let provider = LocationProvider(geocoder: MockGeocoder(mode: .success("Denver, CO")))
        let coord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let seeded = await provider.ensurePlacemark(for: coord, timeout: 1)

        let stream = await provider.updates()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        // Force acceptance via maxSilenceSeconds by advancing time past 60s.
        let t1 = seeded.timestamp.addingTimeInterval(70)
        await provider.send(update: makeUpdate(lat: 39.7392, lon: -104.9903, timestamp: t1, accuracy: 50))

        let next = await iterator.next()
        let snap = try #require(next)
        #expect(snap.placemarkSummary == "Denver, CO")

        try await Task.sleep(for: .milliseconds(20))
        let after = await provider.snapshot()
        #expect(after?.placemarkSummary == "Denver, CO")
    }

    @Test("updatePlacemarkIfNeeded ignores geocoding failures")
    func updatePlacemark_handlesFailure() async throws {
        let provider = LocationProvider(geocoder: MockGeocoder(mode: .failure(GeocodeError.noResults)))
        let t0 = Date()
        await provider.send(update: makeUpdate(lat: 40.0, lon: -105.0, timestamp: t0, accuracy: 50))

        try await Task.sleep(for: .milliseconds(20))
        let snap = await provider.snapshot()
        #expect(snap?.placemarkSummary == nil)
    }

    @Test("late geocode completion does not regress snapshot recency")
    func lateGeocodeCompletion_doesNotRegressSnapshotRecency() async throws {
        let geocoder = RacingGeocoder()
        let provider = LocationProvider(geocoder: geocoder)
        let t0 = Date()
        let t1 = t0.addingTimeInterval(70)

        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: t0, accuracy: 50))
        try await Task.sleep(for: .milliseconds(10))

        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: t1, accuracy: 50))
        try await Task.sleep(for: .milliseconds(20))

        let afterSecond = try #require(await provider.snapshot())
        #expect(afterSecond.timestamp == t1)
        #expect(afterSecond.placemarkSummary == "Latest City")

        await geocoder.resolveFirst(with: "Old City")
        try await Task.sleep(for: .milliseconds(20))

        let final = try #require(await provider.snapshot())
        #expect(final.timestamp == t1)
        #expect(final.placemarkSummary == "Latest City")
    }
}
