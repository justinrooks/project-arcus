import Foundation
import CoreLocation
import Testing
@testable import SkyAware

@Suite("LocationProvider")
struct LocationProviderTests {
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
