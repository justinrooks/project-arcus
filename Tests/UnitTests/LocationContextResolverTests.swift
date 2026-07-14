import Foundation
import CoreLocation
import Testing
import ArcusCore
@testable import SkyAware

@Suite("LocationContextResolver", .serialized)
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

    private actor AuthorizationRequestState {
        private var requested = false

        func markRequested() {
            requested = true
        }

        func wasRequested() -> Bool {
            requested
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

    private func waitUntil(
        timeout: Duration = .seconds(1),
        interval: Duration = .milliseconds(10),
        _ condition: @escaping @Sendable () async -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if await condition() {
                return true
            }
            try? await Task.sleep(for: interval)
        }
        return await condition()
    }

    private actor RefreshRequestTracker {
        private var count = 0

        func record() {
            count += 1
        }

        func value() -> Int {
            count
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
        let requestState = AuthorizationRequestState()
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
            authorizationRequester: { _ in
                await requestState.markRequested()
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

        let contextTask = Task {
            try await resolver.prepareCurrentContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: true,
                authorizationTimeout: 3,
                locationTimeout: 2,
                maximumAcceptedLocationAge: 300,
                placemarkTimeout: 0.1
            )
        }

        let authorizationRequested = await waitUntil(timeout: .seconds(1)) {
            await requestState.wasRequested()
        }
        #expect(authorizationRequested)

        await authorizationState.set(.authorizedWhenInUse)

        let context = try await contextTask.value

        #expect(context.h3Cell == sampleH3Cell)
        #expect(context.grid.countyCode == "OKC109")
        #expect(context.grid.fireZone == "OKZ025")
    }

    @Test("uses the current snapshot immediately when one is already available")
    func usesCurrentSnapshotImmediatelyWhenAvailable() async throws {
        let authorizationState = AuthorizationState(status: .authorizedWhenInUse)
        let timestamp = Date()
        let cached = LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
            timestamp: timestamp,
            accuracy: 15,
            placemarkSummary: "Norman, OK",
            h3Cell: sampleH3Cell
        )
        let locationProvider = LocationProvider(
            geocoder: TestGeocoder(result: .failure(.geocodeFailed)),
            hasher: TestHasher(h3Cell: sampleH3Cell),
            snapshotCache: MockSnapshotCache(storedSnapshot: cached)
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

        let context = try await resolver.prepareCurrentContext(
            requiresFreshLocation: false,
            showsAuthorizationPrompt: false,
            authorizationTimeout: 0.1,
            locationTimeout: 0.1,
            maximumAcceptedLocationAge: 300,
            placemarkTimeout: 0.1
        )

        #expect(context.snapshot.timestamp == timestamp)
        #expect(context.h3Cell == sampleH3Cell)
        #expect(context.grid.countyCode == "OKC109")
    }

    @Test("reuses a recent snapshot when fresh location is requested")
    func reusesRecentSnapshotWhenFreshLocationIsRequested() async throws {
        let authorizationState = AuthorizationState(status: .authorizedWhenInUse)
        let refreshTracker = RefreshRequestTracker()
        let timestamp = Date()
        let cached = LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
            timestamp: timestamp,
            accuracy: 15,
            placemarkSummary: "Norman, OK",
            h3Cell: sampleH3Cell
        )
        let locationProvider = LocationProvider(
            geocoder: TestGeocoder(result: .failure(.geocodeFailed)),
            hasher: TestHasher(h3Cell: sampleH3Cell),
            snapshotCache: MockSnapshotCache(storedSnapshot: cached)
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
                await refreshTracker.record()
                return false
            }
        )

        let context = try await resolver.prepareCurrentContext(
            requiresFreshLocation: true,
            showsAuthorizationPrompt: false,
            authorizationTimeout: 0.1,
            locationTimeout: 0.1,
            maximumAcceptedLocationAge: 300,
            placemarkTimeout: 0.1
        )

        #expect(context.snapshot.timestamp == timestamp)
        #expect(context.h3Cell == sampleH3Cell)
        #expect(await refreshTracker.value() == 0)
    }

    @Test("requests a fresh location when the available snapshot is older than the startup reuse window")
    func requestsFreshLocationWhenAvailableSnapshotIsOlderThanReuseWindow() async throws {
        let authorizationState = AuthorizationState(status: .authorizedWhenInUse)
        let refreshTracker = RefreshRequestTracker()
        let staleTimestamp = Date().addingTimeInterval(-60)
        let refreshedTimestamp = Date()
        let cached = LocationSnapshot(
            coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
            timestamp: staleTimestamp,
            accuracy: 15,
            placemarkSummary: "Norman, OK",
            h3Cell: sampleH3Cell
        )
        let locationProvider = LocationProvider(
            geocoder: TestGeocoder(result: .failure(.geocodeFailed)),
            hasher: TestHasher(h3Cell: sampleH3Cell),
            snapshotCache: MockSnapshotCache(storedSnapshot: cached)
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
                await refreshTracker.record()
                await locationProvider.send(update: .init(
                    coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
                    timestamp: refreshedTimestamp,
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

        #expect(context.snapshot.timestamp == refreshedTimestamp)
        #expect(await refreshTracker.value() == 1)
    }

    @Test("waits for a streamed snapshot when none is immediately available")
    func waitsForStreamedSnapshotWhenUnavailable() async throws {
        let authorizationState = AuthorizationState(status: .authorizedWhenInUse)
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
            authorizationStatusProvider: { await authorizationState.current() },
            authorizationRequester: { _ in },
            refreshCurrentLocation: { _ in false }
        )

        let timestamp = Date()
        let contextTask = Task {
            try await resolver.prepareCurrentContext(
                requiresFreshLocation: false,
                showsAuthorizationPrompt: false,
                authorizationTimeout: 0.1,
                locationTimeout: 2,
                maximumAcceptedLocationAge: 300,
                placemarkTimeout: 0.1
            )
        }

        try await Task.sleep(for: .milliseconds(50))
        await locationProvider.send(update: .init(
            coordinates: CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395),
            timestamp: timestamp,
            accuracy: 15,
            forceAcceptance: true
        ))

        let context = try await contextTask.value
        #expect(context.snapshot.timestamp == timestamp)
        #expect(context.h3Cell == sampleH3Cell)
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

    @Test("times out when no accepted snapshot becomes available")
    func locationTimeoutIsReported() async {
        let authorizationState = AuthorizationState(status: .authorizedWhenInUse)
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
                showsAuthorizationPrompt: false,
                authorizationTimeout: 0.1,
                locationTimeout: 0.01,
                maximumAcceptedLocationAge: 300,
                placemarkTimeout: 0.1
            )
            Issue.record("Expected locationTimeout")
        } catch {
            #expect((error as? LocationContextError) == .locationTimeout)
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
