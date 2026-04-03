import Foundation
import CoreLocation
import Testing
@testable import SkyAware

@Suite("LocationManager")
struct LocationManagerTests {
    fileprivate final class StubAuthorizationManager: CLLocationManager {
        var stubStatus: CLAuthorizationStatus
        private(set) var requestWhenInUseCount = 0
        private(set) var requestAlwaysCount = 0

        init(status: CLAuthorizationStatus) {
            self.stubStatus = status
            super.init()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var authorizationStatus: CLAuthorizationStatus { stubStatus }

        override func requestWhenInUseAuthorization() {
            requestWhenInUseCount += 1
        }

        override func requestAlwaysAuthorization() {
            requestAlwaysCount += 1
        }
    }

    @MainActor
    @Test("authorization callback updates cached authStatus")
    func locationManagerDidChangeAuthorization_updatesAuthStatus() async throws {
        let sut = LocationManager(onUpdate: { _ in })
        #expect(sut.authStatus == .notDetermined)

        let manager = StubAuthorizationManager(status: .authorizedAlways)
        sut.locationManagerDidChangeAuthorization(manager)
        try await Task.sleep(for: .milliseconds(20))

        #expect(sut.authStatus == .authorizedAlways)
    }

    @MainActor
    @Test("requestAlwaysAuthorizationUpgradeIfNeeded requests always when currently authorized while in use")
    func requestAlwaysAuthorizationUpgradeIfNeeded_requestsAlwaysAuthorization() {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse)
        let sut = LocationManager(manager: manager, onUpdate: { _ in })

        let didRequestUpgrade = sut.requestAlwaysAuthorizationUpgradeIfNeeded()

        #expect(didRequestUpgrade)
        #expect(manager.requestAlwaysCount == 1)
    }

    @MainActor
    @Test("requestAlwaysAuthorizationUpgradeIfNeeded skips when current auth is not while in use")
    func requestAlwaysAuthorizationUpgradeIfNeeded_skipsOtherStates() {
        let manager = StubAuthorizationManager(status: .authorizedAlways)
        let sut = LocationManager(manager: manager, onUpdate: { _ in })

        let didRequestUpgrade = sut.requestAlwaysAuthorizationUpgradeIfNeeded()

        #expect(didRequestUpgrade == false)
        #expect(manager.requestAlwaysCount == 0)
    }
}

@Suite("LocationSession")
struct LocationSessionTests {
    private actor StubResolver: LocationContextResolving {
        let context: LocationContext?
        let error: LocationContextError?

        init(context: LocationContext?, error: LocationContextError?) {
            self.context = context
            self.error = error
        }

        func prepareCurrentContext(
            requiresFreshLocation: Bool,
            showsAuthorizationPrompt: Bool,
            authorizationTimeout: Double,
            locationTimeout: Double,
            maximumAcceptedLocationAge: TimeInterval,
            placemarkTimeout: Double
        ) async throws -> LocationContext {
            if let context {
                return context
            }
            throw error ?? LocationContextError.locationTimeout
        }

        func resolveContext(
            from snapshot: LocationSnapshot,
            maximumAcceptedLocationAge: TimeInterval?,
            placemarkTimeout: Double
        ) async throws -> LocationContext {
            if let context {
                return context
            }
            throw error ?? LocationContextError.locationTimeout
        }
    }

    @MainActor
    @Test("stores a ready context returned by the resolver")
    func storesReadyContextFromResolver() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(onUpdate: { _ in })
        manager.locationManagerDidChangeAuthorization(
            LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse)
        )
        try await Task.sleep(for: .milliseconds(20))

        let context = LocationContext(
            snapshot: LocationSnapshot(
                coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
                timestamp: Date(timeIntervalSince1970: 1_234_567),
                accuracy: 20,
                placemarkSummary: "Denver, CO",
                h3Cell: 0x882681b485fffff
            ),
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/39.7392,-104.9903",
                latitude: 39.7392,
                longitude: -104.9903,
                gridId: "BOU",
                gridX: 56,
                gridY: 66,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Denver",
                state: "CO",
                timeZoneId: "America/Denver",
                radarStationId: "KFTG",
                forecastZone: "COZ039",
                countyCode: "COC031",
                fireZone: "COZ246",
                countyLabel: "Denver County",
                fireZoneLabel: "East Central Colorado"
            )
        )
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: StubResolver(context: context, error: nil)
        )

        let result = await session.prepareCurrentLocationContext(
            requiresFreshLocation: false,
            showsAuthorizationPrompt: false
        )

        #expect(result == context)
        #expect(session.currentContext == context)
        #expect(session.currentSnapshot == context.snapshot)
        #expect(session.startupState == .ready)
    }

    @MainActor
    @Test("maps resolver failures into startup state")
    func mapsResolverFailuresIntoStartupState() async throws {
        let provider = LocationProvider()
        let manager = LocationManager(onUpdate: { _ in })
        manager.locationManagerDidChangeAuthorization(
            LocationManagerTests.StubAuthorizationManager(status: .authorizedWhenInUse)
        )
        try await Task.sleep(for: .milliseconds(20))

        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: StubResolver(context: nil, error: .missingRegionContext)
        )

        let result = await session.prepareCurrentLocationContext(
            requiresFreshLocation: false,
            showsAuthorizationPrompt: false
        )

        #expect(result == nil)
        #expect(session.currentContext == nil)
        #expect(session.startupState == .failed("location-missing-region-context"))
    }
}
