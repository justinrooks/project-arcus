import Foundation
import Testing
import SwiftData
import CoreLocation
@testable import SkyAware

private actor CountingNwsClient: NwsClient {
    private let delayNanoseconds: UInt64
    private(set) var activeAlertsCalls = 0

    init(delayNanoseconds: UInt64 = 0) {
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchActiveAlertsJsonData(for location: Coordinate2D) async throws -> Data {
        activeAlertsCalls += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return Data(#"{"type":"FeatureCollection","features":[]}"#.utf8)
    }

    func fetchPointMetadata(for location: Coordinate2D) async throws -> Data {
        Data(#"{"properties":{}}"#.utf8)
    }

    func fetchZoneMetadata(for zoneType: NwsZoneType, and zone: String) async throws -> Data {
        Data(#"{"properties":{}}"#.utf8)
    }

    func activeAlertsCallCount() -> Int {
        activeAlertsCalls
    }
}

private struct StubGeocoder: LocationGeocoding {
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        "Testville, CO"
    }
}
