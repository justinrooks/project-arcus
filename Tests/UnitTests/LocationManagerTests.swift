import Foundation
import CoreLocation
import Testing
@testable import SkyAware

@Suite("LocationManager")
struct LocationManagerTests {
    fileprivate final class StubAuthorizationManager: CLLocationManager {
        var stubStatus: CLAuthorizationStatus
        var stubAccuracy: CLAccuracyAuthorization
        private(set) var requestWhenInUseCount = 0
        private(set) var requestAlwaysCount = 0

        init(status: CLAuthorizationStatus, accuracy: CLAccuracyAuthorization = .fullAccuracy) {
            self.stubStatus = status
            self.stubAccuracy = accuracy
            super.init()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var authorizationStatus: CLAuthorizationStatus { stubStatus }
        override var accuracyAuthorization: CLAccuracyAuthorization { stubAccuracy }

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
    @Test("authorization callback updates cached accuracyAuthorization")
    func locationManagerDidChangeAuthorization_updatesAccuracyAuthorization() async throws {
        let manager = StubAuthorizationManager(status: .authorizedWhenInUse, accuracy: .fullAccuracy)
        let sut = LocationManager(manager: manager, onUpdate: { _ in })
        #expect(sut.accuracyAuthorization == .fullAccuracy)

        manager.stubAccuracy = .reducedAccuracy
        sut.locationManagerDidChangeAuthorization(manager)
        try await Task.sleep(for: .milliseconds(20))

        #expect(sut.accuracyAuthorization == .reducedAccuracy)
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
        private var enqueueCount = 0
        private var lastForceUpload: Bool?

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

        func enqueueForPush(_ context: LocationContext, forceUpload: Bool) async {
            enqueueCount += 1
            lastForceUpload = forceUpload
        }

        func recordedEnqueueCount() -> Int {
            enqueueCount
        }

        func recordedLastForceUpload() -> Bool? {
            lastForceUpload
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

    @MainActor
    @Test("pushServerNotificationPreferenceUpdate forwards current context for upload")
    func pushServerNotificationPreferenceUpdate_forwardsCurrentContext() async throws {
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
        let resolver = StubResolver(context: context, error: nil)
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver
        )
        _ = await session.prepareCurrentLocationContext(
            requiresFreshLocation: false,
            showsAuthorizationPrompt: false
        )

        await session.pushServerNotificationPreferenceUpdate()

        #expect(await resolver.recordedEnqueueCount() == 1)
        #expect(await resolver.recordedLastForceUpload() == false)
        #expect(session.currentContext == context)
    }

    @MainActor
    @Test("pushServerNotificationPreferenceUpdate resolves missing context and enqueues with force flag")
    func pushServerNotificationPreferenceUpdate_resolvesMissingContext_andEnqueuesWithForceFlag() async throws {
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
        let resolver = StubResolver(context: context, error: nil)
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver
        )

        // Let initialization tasks settle, then set deterministic test state.
        try await Task.sleep(for: .milliseconds(20))
        session.currentSnapshot = context.snapshot
        session.currentContext = nil

        await session.pushServerNotificationPreferenceUpdate(forceUpload: true)

        #expect(await resolver.recordedEnqueueCount() == 1)
        #expect(await resolver.recordedLastForceUpload() == true)
        #expect(session.currentContext == context)
        #expect(session.currentSnapshot == context.snapshot)
    }

    @MainActor
    @Test("reliability state reflects authorization and accuracy updates")
    func reliabilityState_reflectsAuthorizationAndAccuracy() async throws {
        let provider = LocationProvider()
        let manager = LocationManagerTests.StubAuthorizationManager(
            status: .authorizedWhenInUse,
            accuracy: .reducedAccuracy
        )
        let locationManager = LocationManager(manager: manager, onUpdate: { _ in })
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: locationManager,
            locationContextResolver: StubResolver(context: nil, error: .locationUnavailable)
        )

        #expect(session.authorizationStatus == .authorizedWhenInUse)
        #expect(session.accuracyAuthorization == .reducedAccuracy)
        #expect(session.reliabilityState.authorization == .whileUsing)
        #expect(session.reliabilityState.accuracy == .reduced)

        manager.stubStatus = .authorizedAlways
        manager.stubAccuracy = .fullAccuracy
        locationManager.locationManagerDidChangeAuthorization(manager)
        try await Task.sleep(for: .milliseconds(20))

        #expect(session.authorizationStatus == .authorizedAlways)
        #expect(session.accuracyAuthorization == .fullAccuracy)
        #expect(session.reliabilityState.authorization == .always)
        #expect(session.reliabilityState.accuracy == .precise)
    }
}

@Suite("LocationReliabilityState")
struct LocationReliabilityStateTests {
    @Test("maps while-using plus precise accuracy")
    func mapsWhileUsingPrecise() {
        let state = LocationReliabilityState(
            authorizationStatus: .authorizedWhenInUse,
            accuracyAuthorization: .fullAccuracy
        )

        #expect(state.authorization == .whileUsing)
        #expect(state.accuracy == .precise)
        #expect(state.nextAction == .requestAlwaysUpgrade)
    }

    @Test("maps always plus reduced accuracy")
    func mapsAlwaysReducedAccuracy() {
        let state = LocationReliabilityState(
            authorizationStatus: .authorizedAlways,
            accuracyAuthorization: .reducedAccuracy
        )

        #expect(state.authorization == .always)
        #expect(state.accuracy == .reduced)
        #expect(state.nextAction == .openSettings)
    }

    @Test("maps missing accuracy as unknown")
    func mapsMissingAccuracyAsUnknown() {
        let state = LocationReliabilityState(
            authorizationStatus: .denied,
            accuracyAuthorization: nil
        )

        #expect(state.authorization == .denied)
        #expect(state.accuracy == .unknown)
        #expect(state.nextAction == .openSettings)
    }

    @Test("settings copy and action for always plus precise")
    func settingsPresentation_alwaysPrecise() {
        let state = LocationReliabilityState(authorization: .always, accuracy: .precise)

        #expect(state.settingsAuthorizationText == "Always")
        #expect(state.settingsAccuracyText == "Precise")
        #expect(state.settingsReliabilityCopy == "Background alerts are set up for the best reliability.")
        #expect(state.settingsAction == .none)
        #expect(state.settingsActionTitle == nil)
    }

    @Test("settings copy and action for always plus reduced accuracy")
    func settingsPresentation_alwaysReduced() {
        let state = LocationReliabilityState(authorization: .always, accuracy: .reduced)

        #expect(state.settingsAuthorizationText == "Always")
        #expect(state.settingsAccuracyText == "Reduced")
        #expect(state.settingsReliabilityCopy == "Background alerts are enabled. Precise Location can make alerts more accurate for your area.")
        #expect(state.settingsAction == .openSettings)
        #expect(state.settingsActionTitle == "Open Settings")
    }

    @Test("settings copy and action for while using plus precise")
    func settingsPresentation_whileUsingPrecise() {
        let state = LocationReliabilityState(authorization: .whileUsing, accuracy: .precise)

        #expect(state.settingsAuthorizationText == "While Using")
        #expect(state.settingsAccuracyText == "Precise")
        #expect(state.settingsReliabilityCopy == "SkyAware can alert while you are using the app. Enable Always for more reliable background alerts.")
        #expect(state.settingsAction == .requestAlwaysUpgrade)
        #expect(state.settingsActionTitle == "Enable Always")
    }

    @Test("settings copy and action for while using plus reduced accuracy")
    func settingsPresentation_whileUsingReduced() {
        let state = LocationReliabilityState(authorization: .whileUsing, accuracy: .reduced)

        #expect(state.settingsAuthorizationText == "While Using")
        #expect(state.settingsAccuracyText == "Reduced")
        #expect(state.settingsReliabilityCopy == "SkyAware can alert while you are using the app. Enable Always and Precise Location for more reliable alerts.")
        #expect(state.settingsAction == .requestAlwaysUpgrade)
        #expect(state.settingsActionTitle == "Enable Always")
    }

    @Test("settings copy and action for denied and restricted")
    func settingsPresentation_deniedAndRestricted() {
        let denied = LocationReliabilityState(authorization: .denied, accuracy: .unknown)
        let restricted = LocationReliabilityState(authorization: .restricted, accuracy: .unknown)

        #expect(denied.settingsAuthorizationText == "Off")
        #expect(restricted.settingsAuthorizationText == "Restricted")
        #expect(denied.settingsReliabilityCopy == "Location is off for SkyAware. Enable location to receive alerts for your area.")
        #expect(restricted.settingsReliabilityCopy == "Location is off for SkyAware. Enable location to receive alerts for your area.")
        #expect(denied.settingsAction == .openSettings)
        #expect(restricted.settingsAction == .openSettings)
        #expect(denied.settingsActionTitle == "Open Settings")
    }

    @Test("settings copy and action for not determined")
    func settingsPresentation_notDetermined() {
        let state = LocationReliabilityState(authorization: .notDetermined, accuracy: .unknown)

        #expect(state.settingsAuthorizationText == "Not Set")
        #expect(state.settingsAccuracyText == "Unknown")
        #expect(state.settingsReliabilityCopy == "Choose how SkyAware can use location to send alerts for your area.")
        #expect(state.settingsAction == .requestWhenInUse)
        #expect(state.settingsActionTitle == "Enable Location")
    }
}
