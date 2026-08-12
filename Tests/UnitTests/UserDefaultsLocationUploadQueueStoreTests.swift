import Foundation
import CoreLocation
import Testing
import ArcusCore
@testable import SkyAware

@Suite("UserDefaultsLocationUploadQueueStore")
struct UserDefaultsLocationUploadQueueStoreTests {
    @Test("round-trips durable operations and clears an empty queue")
    func saveLoadAndClear_roundTripsDurableOperations() async {
        let suiteName = "UserDefaultsLocationUploadQueueStoreTests.\(UUID().uuidString)"
        let key = "pending-requests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let requestedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let capturedAt = Date(timeIntervalSince1970: 1_699_999_900)
        let context = PersistedLocationContext(
            LocationContext(
                snapshot: LocationSnapshot(
                    coordinates: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
                    timestamp: capturedAt,
                    accuracy: 12.5,
                    placemarkSummary: "Denver, CO",
                    h3Cell: 0x872681364FFFFFF
                ),
                h3Cell: 0x872681364FFFFFF,
                grid: GridPointSnapshot(
                    nwsId: "KBOU",
                    latitude: 39.7392,
                    longitude: -104.9903,
                    gridId: "BOU",
                    gridX: 50,
                    gridY: 99,
                    forecastURL: nil,
                    forecastHourlyURL: nil,
                    forecastGridDataURL: nil,
                    observationStationsURL: nil,
                    city: "Denver",
                    state: "CO",
                    timeZoneId: "America/Denver",
                    radarStationId: "KFTG",
                    forecastZone: "COZ040",
                    countyCode: "08031",
                    fireZone: "COZ040",
                    countyLabel: "Denver",
                    fireZoneLabel: "Northeast Colorado"
                )
            )
        )
        let requests = [
            PersistedLocationUploadRequest(
                source: .manualRefresh,
                reason: .locationResolved,
                forceUpload: false,
                installationId: "install-location",
                requestedAt: requestedAt,
                isSubscribed: true,
                authorizationState: "authorizedAlways",
                apnsToken: "token-location",
                operation: .locationSnapshot(context: context)
            ),
            PersistedLocationUploadRequest(
                source: .settingsPreference,
                reason: .preferenceChanged,
                forceUpload: true,
                installationId: "install-preference",
                requestedAt: requestedAt.addingTimeInterval(60),
                isSubscribed: false,
                authorizationState: "authorizedWhenInUse",
                apnsToken: "token-preference",
                operation: .preferenceSync
            )
        ]

        let store = UserDefaultsLocationUploadQueueStore(suiteName: suiteName, key: key)
        await store.savePendingRequests(requests)

        let reinitializedStore = UserDefaultsLocationUploadQueueStore(suiteName: suiteName, key: key)
        #expect(await reinitializedStore.loadPendingRequests() == requests)

        await reinitializedStore.savePendingRequests([])
        let clearedStore = UserDefaultsLocationUploadQueueStore(suiteName: suiteName, key: key)
        #expect(await clearedStore.loadPendingRequests().isEmpty)
    }
}
