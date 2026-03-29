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

@Suite("NwsProvider.sync", .serialized)
struct NwsProviderSyncTests {
//    @Test("Concurrent sync requests do not hit the NWS alerts endpoint while watch refresh is disabled")
//    func concurrentSameLocationDoesNotHitAlertsEndpoint() async throws {
//        let client = CountingNwsClient()
//        let provider = try await makeProvider(client: client)
//        let point = CLLocationCoordinate2D(latitude: 35.2226, longitude: -97.4395)
//
//        await withTaskGroup(of: Void.self) { group in
//            group.addTask { await provider.sync(for: point) }
//            group.addTask { await provider.sync(for: point) }
//            await group.waitForAll()
//        }
//
//        #expect(await client.activeAlertsCallCount() == 0)
//    }
//
//    @Test("Same-grid repeat sync does not hit the NWS alerts endpoint while watch refresh is disabled")
//    func repeatSameGridDoesNotHitAlertsEndpoint() async throws {
//        let client = CountingNwsClient()
//        let provider = try await makeProvider(client: client)
//        let first = CLLocationCoordinate2D(latitude: 35.123456, longitude: -97.123456)
//        let drifted = CLLocationCoordinate2D(latitude: 35.123499, longitude: -97.123499)
//
//        await provider.sync(for: first)
//        await provider.sync(for: drifted)
//
//        #expect(await client.activeAlertsCallCount() == 0)
//    }

    private func makeProvider(client: any NwsClient) async throws -> NwsProvider {
        let container = try await MainActor.run { try TestStore.container(for: [Watch.self]) }
        try await MainActor.run { try TestStore.reset(Watch.self, in: container) }

        let watchRepo = WatchRepo(modelContainer: container)
        let metadataRepo = NwsMetadataRepo()
        let gridPointProvider = GridPointProvider(
            client: client,
            repo: metadataRepo
        )

        return NwsProvider(
            watchRepo: watchRepo,
            metadataRepo: metadataRepo,
            gridMetadataProvider: gridPointProvider,
            client: client
        )
    }
}
