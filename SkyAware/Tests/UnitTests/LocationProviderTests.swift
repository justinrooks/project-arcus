import Foundation
import CoreLocation
import Testing
@testable import SkyAware

@Suite("LocationProvider")
struct LocationProviderTests {
    private let sampleH3Cell: Int64 = 0x872681364FFFFFF

    private indirect enum GeocoderMode: Sendable {
        case success(String)
        case failure(any Error & Sendable)
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
        enum Mode: Sendable {
            case success(Int64)
            case failure(any Error & Sendable)
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

    private func makeUpdate(
        lat: Double,
        lon: Double,
        timestamp: Date,
        accuracy: CLLocationAccuracy,
        forceAcceptance: Bool = false
    ) -> LocationUpdate {
        LocationUpdate(
            coordinates: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            timestamp: timestamp,
            accuracy: accuracy,
            forceAcceptance: forceAcceptance
        )
    }

    private func makeGridSnapshot(
        countyCode: String? = "OKC109",
        fireZone: String? = "OKZ025",
        countyLabel: String? = "Oklahoma County",
        fireZoneLabel: String? = "Central Oklahoma"
    ) -> GridPointSnapshot {
        GridPointSnapshot(
            nwsId: "https://api.weather.gov/points/35.4676,-97.5164",
            latitude: 35.4676,
            longitude: -97.5164,
            gridId: "OUN",
            gridX: 34,
            gridY: 74,
            forecastURL: nil,
            forecastHourlyURL: nil,
            forecastGridDataURL: nil,
            observationStationsURL: nil,
            city: "Oklahoma City",
            state: "OK",
            timeZoneId: "America/Chicago",
            radarStationId: "KTLX",
            forecastZone: "OKZ025",
            countyCode: countyCode,
            fireZone: fireZone,
            countyLabel: countyLabel,
            fireZoneLabel: fireZoneLabel
        )
    }

    private func makeContext(
        timestamp: Date = Date(timeIntervalSince1970: 1_234_567),
        placemark: String? = "OKC, OK",
        h3Cell: Int64? = nil,
        grid: GridPointSnapshot? = nil
    ) -> LocationContext {
        let h3Cell = h3Cell ?? sampleH3Cell
        let snapshot = LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
            timestamp: timestamp,
            accuracy: 42,
            placemarkSummary: placemark,
            h3Cell: h3Cell
        )
        return LocationContext(
            snapshot: snapshot,
            h3Cell: h3Cell,
            grid: grid ?? makeGridSnapshot()
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
        let provider = LocationProvider(snapshotCache: cache, nowProvider: { now })
        
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

    @Test("send accepts explicit refresh even when throttle would normally suppress it")
    func send_acceptsExplicitRefreshWhenStationary() async throws {
        let provider = LocationProvider()
        let first = Date(timeIntervalSince1970: 1_000)
        let second = first.addingTimeInterval(1)

        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: first, accuracy: 50))
        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: second, accuracy: 50, forceAcceptance: true))

        let snapshot = try #require(await provider.snapshot())
        #expect(snapshot.timestamp == second)
        #expect(snapshot.coordinates.latitude == 39.0)
        #expect(snapshot.coordinates.longitude == -104.0)
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
    
    @Test("location context pusher payload includes timestamp and apns token")
    func locationContextPusher_includesTimestampAndApnsToken() async throws {
        let uploader = MockSnapshotUploader()
        let pusher = LocationSnapshotPusher(
            uploader: uploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { false },
            retryDelaysSeconds: [0]
        )

        let context = makeContext()
        await pusher.enqueue(context)
        
        let payloads = await uploader.uploadedPayloads()
        let payload = try #require(payloads.first)
        #expect(payload.capturedAt == context.snapshot.timestamp)
        #expect(payload.installationId == "install-abc-123")
        #expect(payload.apnsDeviceToken == "apns-token-123")
        #expect(payload.countyCode == "OKC109")
        #expect(payload.forecastZone == "OKZ025")
        #expect(payload.fireZone == "OKZ025")
        #expect(payload.h3Cell == sampleH3Cell)
        #expect(payload.isSubscribed == false)
    }

    @Test("location context pusher skips upload when APNs token is missing")
    func locationContextPusher_skipsUploadWithoutApnsToken() async {
        let uploader = MockSnapshotUploader()
        let pusher = LocationSnapshotPusher(
            uploader: uploader,
            apnsTokenProvider: { " " },
            installationIdProvider: { "install-abc-123" },
            retryDelaysSeconds: [0]
        )

        await pusher.enqueue(makeContext())

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.isEmpty)
    }

    @Test("snapshot pusher skips upload when location-to-signal is disabled")
    func snapshotPusher_skipsUploadWhenLocationSharingDisabled() async {
        let uploader = MockSnapshotUploader()
        let pusher = LocationSnapshotPusher(
            uploader: uploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            locationUploadEnabledProvider: { false },
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

    @Test("pushLatestSnapshotWhenAvailable replays cached snapshot immediately")
    func pushLatestSnapshotWhenAvailable_replaysCachedSnapshot() async throws {
        let now = Date(timeIntervalSince1970: 1_234_567)
        let cached = LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164),
            timestamp: now,
            accuracy: 42,
            placemarkSummary: "OKC, OK",
            h3Cell: sampleH3Cell
        )
        let cache = MockSnapshotCache(storedSnapshot: cached)
        let pusher = MockSnapshotPusher()
        let provider = LocationProvider(snapshotPusher: pusher, snapshotCache: cache, nowProvider: { now })

        let didPush = await provider.pushLatestSnapshotWhenAvailable(timeout: 0.01)

        #expect(didPush)
        let pushed = await pusher.allSnapshots()
        let first = try #require(pushed.first)
        #expect(first.timestamp == now)
        #expect(first.h3Cell == sampleH3Cell)
    }

    @Test("pushLatestSnapshotWhenAvailable waits for a new snapshot")
    func pushLatestSnapshotWhenAvailable_waitsForNextSnapshot() async throws {
        let pusher = MockSnapshotPusher()
        let provider = LocationProvider(
            geocoder: MockGeocoder(mode: .failure(GeocodeError.noResults)),
            hasher: MockHasher(mode: .success(sampleH3Cell)),
            snapshotPusher: pusher
        )

        let pushTask = Task {
            await provider.pushLatestSnapshotWhenAvailable(timeout: 0.5)
        }

        try await Task.sleep(for: .milliseconds(50))
        await provider.send(
            update: makeUpdate(
                lat: 39.0,
                lon: -104.0,
                timestamp: Date(timeIntervalSince1970: 1_234_600),
                accuracy: 25
            )
        )

        let didPush = await pushTask.value
        #expect(didPush)

        let pushed = await waitForSnapshots(from: pusher)
        #expect(pushed.count == 1)
    }

    @Test("pushLatestSnapshotWhenAvailable times out when no snapshot is available")
    func pushLatestSnapshotWhenAvailable_timesOutWithoutSnapshot() async {
        let pusher = MockSnapshotPusher()
        let provider = LocationProvider(snapshotPusher: pusher)

        let didPush = await provider.pushLatestSnapshotWhenAvailable(timeout: 0.01)

        #expect(!didPush)
        let pushed = await pusher.allSnapshots()
        #expect(pushed.isEmpty)
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

@Suite("LocationContextResolver")
struct LocationContextResolverTests {
    private let sampleH3Cell: Int64 = 0x882681b485fffff

    private enum TestError: Error, Sendable {
        case geocodeFailed
    }

    private actor AuthorizationState {
        private var status: CLAuthorizationStatus

        init(status: CLAuthorizationStatus) {
            self.status = status
        }

        func current() -> CLAuthorizationStatus {
            status
        }

        func set(_ status: CLAuthorizationStatus) {
            self.status = status
        }
    }

    private struct TestGeocoder: LocationGeocoding {
        let result: Result<String, TestError>

        func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
            switch result {
            case .success(let summary):
                return summary
            case .failure(let error):
                throw error
            }
        }
    }

    private struct TestHasher: LocationHashing {
        let h3Cell: Int64?

        func h3Cell(for coord: CLLocationCoordinate2D) throws -> Int64 {
            guard let h3Cell else {
                throw TestError.geocodeFailed
            }
            return h3Cell
        }
    }

    private actor RecordingContextPusher: LocationContextPushing {
        private var contexts: [LocationContext] = []

        func enqueue(_ context: LocationContext) async {
            contexts.append(context)
        }

        func count() -> Int {
            contexts.count
        }
    }

    private actor ResolverNwsClient: NwsClient {
        let pointPayload: Data
        let countyName: String?
        let fireZoneName: String?

        init(pointPayload: Data, countyName: String?, fireZoneName: String?) {
            self.pointPayload = pointPayload
            self.countyName = countyName
            self.fireZoneName = fireZoneName
        }

        func fetchActiveAlertsJsonData(for location: Coordinate2D) async throws -> Data {
            Data()
        }

        func fetchPointMetadata(for location: Coordinate2D) async throws -> Data {
            pointPayload
        }

        func fetchZoneMetadata(for zoneType: NwsZoneType, and zone: String) async throws -> Data {
            let name = switch zoneType {
            case .county:
                countyName ?? ""
            case .fire:
                fireZoneName ?? ""
            }
            let type = switch zoneType {
            case .county:
                "county"
            case .fire:
                "fire"
            }
            return Data(
                """
                {
                  "properties": {
                    "type": "\(type)",
                    "name": "\(name)"
                  }
                }
                """.utf8
            )
        }
    }

    @Test("waits for authorization result before preparing a ready context")
    func waitsForAuthorizationResult() async throws {
        let authorizationState = AuthorizationState(status: .notDetermined)
        let pusher = RecordingContextPusher()
        let locationProvider = LocationProvider(
            geocoder: TestGeocoder(result: .success("Norman, OK")),
            hasher: TestHasher(h3Cell: sampleH3Cell)
        )
        let gridPointProvider = GridPointProvider(
            client: ResolverNwsClient(
                pointPayload: makePointPayload(includeCounty: true, includeFireZone: true),
                countyName: "Oklahoma County",
                fireZoneName: "Central Oklahoma"
            ),
            repo: NwsMetadataRepo()
        )
        let resolver = LocationContextResolver(
            locationClient: makeLocationClient(provider: locationProvider),
            locationProvider: locationProvider,
            gridPointProvider: gridPointProvider,
            contextPusher: pusher,
            authorizationStatusProvider: { await authorizationState.current() },
            authorizationRequester: { _ in
                Task.detached {
                    try? await Task.sleep(for: .milliseconds(20))
                    await authorizationState.set(.authorizedWhenInUse)
                }
            },
            refreshCurrentLocation: { _ in
                await locationProvider.send(update: .init(
                    coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
                    timestamp: Date(),
                    accuracy: 15,
                    forceAcceptance: true
                ))
                return true
            }
        )

        let context = try await resolver.prepareCurrentContext(
            requiresFreshLocation: true,
            showsAuthorizationPrompt: true,
            authorizationTimeout: 1,
            locationTimeout: 0.5,
            maximumAcceptedLocationAge: 300,
            placemarkTimeout: 0.1
        )

        #expect(context.h3Cell == sampleH3Cell)
        #expect(context.grid.countyCode == "OKC109")
        #expect(context.grid.fireZone == "OKZ025")
        #expect(await pusher.count() == 1)
    }

    @Test("times out cleanly while waiting for authorization resolution")
    func authorizationTimeoutIsReported() async {
        let authorizationState = AuthorizationState(status: .notDetermined)
        let locationProvider = LocationProvider(
            geocoder: TestGeocoder(result: .success("Norman, OK")),
            hasher: TestHasher(h3Cell: sampleH3Cell)
        )
        let gridPointProvider = GridPointProvider(
            client: ResolverNwsClient(
                pointPayload: makePointPayload(includeCounty: true, includeFireZone: true),
                countyName: "Oklahoma County",
                fireZoneName: "Central Oklahoma"
            ),
            repo: NwsMetadataRepo()
        )
        let resolver = LocationContextResolver(
            locationClient: makeLocationClient(provider: locationProvider),
            locationProvider: locationProvider,
            gridPointProvider: gridPointProvider,
            authorizationStatusProvider: { await authorizationState.current() },
            authorizationRequester: { _ in },
            refreshCurrentLocation: { _ in false }
        )

        do {
            _ = try await resolver.prepareCurrentContext(
                requiresFreshLocation: false,
                showsAuthorizationPrompt: true,
                authorizationTimeout: 0.01,
                locationTimeout: 0.01,
                maximumAcceptedLocationAge: 300,
                placemarkTimeout: 0.1
            )
            Issue.record("Expected authorization timeout")
        } catch {
            #expect((error as? LocationContextError) == .authorizationTimeout)
        }
    }

    @Test("does not produce a ready context without h3")
    func missingH3PreventsReadyContext() async {
        let authorizationState = AuthorizationState(status: .authorizedWhenInUse)
        let locationProvider = LocationProvider(
            geocoder: TestGeocoder(result: .success("Norman, OK")),
            hasher: TestHasher(h3Cell: nil)
        )
        let gridPointProvider = GridPointProvider(
            client: ResolverNwsClient(
                pointPayload: makePointPayload(includeCounty: true, includeFireZone: true),
                countyName: "Oklahoma County",
                fireZoneName: "Central Oklahoma"
            ),
            repo: NwsMetadataRepo()
        )
        let resolver = LocationContextResolver(
            locationClient: makeLocationClient(provider: locationProvider),
            locationProvider: locationProvider,
            gridPointProvider: gridPointProvider,
            authorizationStatusProvider: { await authorizationState.current() },
            authorizationRequester: { _ in },
            refreshCurrentLocation: { _ in
                await locationProvider.send(update: .init(
                    coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
                    timestamp: Date(),
                    accuracy: 15,
                    forceAcceptance: true
                ))
                return true
            }
        )

        do {
            _ = try await resolver.prepareCurrentContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false,
                authorizationTimeout: 0.1,
                locationTimeout: 0.5,
                maximumAcceptedLocationAge: 300,
                placemarkTimeout: 0.1
            )
            Issue.record("Expected missingH3Cell")
        } catch {
            #expect((error as? LocationContextError) == .missingH3Cell)
        }
    }

    @Test("does not produce a ready context without county and fire zone")
    func missingRegionMetadataPreventsReadyContext() async {
        let authorizationState = AuthorizationState(status: .authorizedWhenInUse)
        let locationProvider = LocationProvider(
            geocoder: TestGeocoder(result: .success("Norman, OK")),
            hasher: TestHasher(h3Cell: sampleH3Cell)
        )
        let gridPointProvider = GridPointProvider(
            client: ResolverNwsClient(
                pointPayload: makePointPayload(includeCounty: false, includeFireZone: false),
                countyName: nil,
                fireZoneName: nil
            ),
            repo: NwsMetadataRepo()
        )
        let resolver = LocationContextResolver(
            locationClient: makeLocationClient(provider: locationProvider),
            locationProvider: locationProvider,
            gridPointProvider: gridPointProvider,
            authorizationStatusProvider: { await authorizationState.current() },
            authorizationRequester: { _ in },
            refreshCurrentLocation: { _ in
                await locationProvider.send(update: .init(
                    coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
                    timestamp: Date(),
                    accuracy: 15,
                    forceAcceptance: true
                ))
                return true
            }
        )

        do {
            _ = try await resolver.prepareCurrentContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false,
                authorizationTimeout: 0.1,
                locationTimeout: 0.5,
                maximumAcceptedLocationAge: 300,
                placemarkTimeout: 0.1
            )
            Issue.record("Expected missingRegionContext")
        } catch {
            #expect((error as? LocationContextError) == .missingRegionContext)
        }
    }

    @Test("allows a ready context when placemark resolution fails")
    func missingPlacemarkDoesNotBlockReadyContext() async throws {
        let authorizationState = AuthorizationState(status: .authorizedWhenInUse)
        let pusher = RecordingContextPusher()
        let locationProvider = LocationProvider(
            geocoder: TestGeocoder(result: .failure(.geocodeFailed)),
            hasher: TestHasher(h3Cell: sampleH3Cell)
        )
        let gridPointProvider = GridPointProvider(
            client: ResolverNwsClient(
                pointPayload: makePointPayload(includeCounty: true, includeFireZone: true),
                countyName: "Oklahoma County",
                fireZoneName: "Central Oklahoma"
            ),
            repo: NwsMetadataRepo()
        )
        let resolver = LocationContextResolver(
            locationClient: makeLocationClient(provider: locationProvider),
            locationProvider: locationProvider,
            gridPointProvider: gridPointProvider,
            contextPusher: pusher,
            authorizationStatusProvider: { await authorizationState.current() },
            authorizationRequester: { _ in },
            refreshCurrentLocation: { _ in
                await locationProvider.send(update: .init(
                    coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
                    timestamp: Date(),
                    accuracy: 15,
                    forceAcceptance: true
                ))
                return true
            }
        )

        let context = try await resolver.prepareCurrentContext(
            requiresFreshLocation: true,
            showsAuthorizationPrompt: false,
            authorizationTimeout: 0.1,
            locationTimeout: 0.5,
            maximumAcceptedLocationAge: 300,
            placemarkTimeout: 0.1
        )

        #expect(context.snapshot.placemarkSummary == nil)
        #expect(await pusher.count() == 1)
    }

    private func makePointPayload(includeCounty: Bool, includeFireZone: Bool) -> Data {
        let countyEntry = includeCounty
            ? #""county": "https://api.weather.gov/zones/county/OKC109","# 
            : ""
        let fireZoneEntry = includeFireZone
            ? #""fireWeatherZone": "https://api.weather.gov/zones/fire/OKZ025","# 
            : ""

        return Data(
            """
            {
              "id": "https://api.weather.gov/points/35.2226,-97.4395",
              "type": "Feature",
              "geometry": null,
              "properties": {
                "gridId": "OUN",
                "gridX": 34,
                "gridY": 74,
                "forecast": "https://api.weather.gov/gridpoints/OUN/34,74/forecast",
                "forecastHourly": "https://api.weather.gov/gridpoints/OUN/34,74/forecast/hourly",
                "forecastGridData": "https://api.weather.gov/gridpoints/OUN/34,74",
                "observationStations": "https://api.weather.gov/gridpoints/OUN/34,74/stations",
                "relativeLocation": {
                  "type": "Feature",
                  "geometry": null,
                  "properties": {
                    "city": "Norman",
                    "state": "OK"
                  }
                },
                "forecastZone": "https://api.weather.gov/zones/forecast/OKZ025",
                \(countyEntry)
                \(fireZoneEntry)
                "timeZone": "America/Chicago",
                "radarStation": "KTLX"
              }
            }
            """.utf8
        )
    }
}
