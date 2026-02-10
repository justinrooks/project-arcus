import CoreLocation
import Testing
@testable import SkyAware

@Suite("LocationManager")
struct LocationManagerTests {
    private final class StubAuthorizationManager: CLLocationManager {
        private let stubStatus: CLAuthorizationStatus

        init(status: CLAuthorizationStatus) {
            self.stubStatus = status
            super.init()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var authorizationStatus: CLAuthorizationStatus { stubStatus }
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
}
