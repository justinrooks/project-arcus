import Foundation
import CoreLocation
import Testing
import ArcusCore
@testable import SkyAware

private struct OfflineSnapshotUploader: LocationSnapshotUploading {
    func upload(_ payload: LocationSnapshotPushPayload) async throws { throw URLError(.notConnectedToInternet) }
}
private struct OfflinePreferenceUploader: DevicePreferenceSyncUploading {
    func upload(_ payload: DevicePreferenceSyncPayload) async throws { throw URLError(.notConnectedToInternet) }
}

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

    private actor CountingGeocoder: LocationGeocoding {
        private var reverseGeocodeCallCount = 0

        func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
            reverseGeocodeCallCount += 1
            return "Denver, CO"
        }

        func callCount() -> Int {
            reverseGeocodeCallCount
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

    private actor MockPreferenceUploader: DevicePreferenceSyncUploading {
        private var payloads: [DevicePreferenceSyncPayload] = []

        func upload(_ payload: DevicePreferenceSyncPayload) async throws {
            payloads.append(payload)
        }

        func uploadedPayloads() -> [DevicePreferenceSyncPayload] {
            payloads
        }
    }

    private actor FailFirstThenSucceedSnapshotUploader: LocationSnapshotUploading {
        private var payloads: [LocationSnapshotPushPayload] = []
        private var shouldFailNext: Bool

        init(shouldFailFirst: Bool = true) {
            self.shouldFailNext = shouldFailFirst
        }

        func upload(_ payload: LocationSnapshotPushPayload) async throws {
            payloads.append(payload)
            if shouldFailNext {
                shouldFailNext = false
                throw LocationPushError.invalidResponseStatus(503)
            }
        }

        func uploadedPayloads() -> [LocationSnapshotPushPayload] {
            payloads
        }
    }

    private actor FailFirstThenSucceedPreferenceUploader: DevicePreferenceSyncUploading {
        private var payloads: [DevicePreferenceSyncPayload] = []
        private var shouldFailNext: Bool

        init(shouldFailFirst: Bool = true) {
            self.shouldFailNext = shouldFailFirst
        }

        func upload(_ payload: DevicePreferenceSyncPayload) async throws {
            payloads.append(payload)
            if shouldFailNext {
                shouldFailNext = false
                throw LocationPushError.invalidResponseStatus(503)
            }
        }

        func uploadedPayloads() -> [DevicePreferenceSyncPayload] {
            payloads
        }
    }

    private actor CompatibilitySnapshotUploader: LocationSnapshotUploading {
        private var payloads: [LocationSnapshotPushPayload] = []
        private let failingStatus: Int
        private let fallbackSource: String

        init(failingStatus: Int, fallbackSource: String = "unknown") {
            self.failingStatus = failingStatus
            self.fallbackSource = fallbackSource
        }

        func upload(_ payload: LocationSnapshotPushPayload) async throws {
            payloads.append(payload)
            if payload.source != fallbackSource {
                throw LocationPushError.invalidResponseStatus(failingStatus)
            }
        }

        func uploadedPayloads() -> [LocationSnapshotPushPayload] {
            payloads
        }
    }

    private actor BackoffCancellingUploader: LocationSnapshotUploading {
        private var payloads: [LocationSnapshotPushPayload] = []
        private var firstAttemptContinuation: CheckedContinuation<Void, Never>?

        func upload(_ payload: LocationSnapshotPushPayload) async throws {
            payloads.append(payload)
            if payloads.count == 1 {
                firstAttemptContinuation?.resume()
                firstAttemptContinuation = nil
                throw LocationPushError.invalidResponseStatus(503)
            }
        }

        func waitForFirstAttempt() async {
            if payloads.isEmpty == false { return }
            await withCheckedContinuation { continuation in
                firstAttemptContinuation = continuation
            }
        }

        func attemptCount() -> Int {
            payloads.count
        }
    }

    private actor GateableSnapshotUploader: LocationSnapshotUploading {
        private let failFirst: Bool
        init(failFirst: Bool = false) { self.failFirst = failFirst }
        private var payloads: [LocationSnapshotPushPayload] = []
        private var isBlocked = true
        private var firstAttemptContinuation: CheckedContinuation<Void, Never>?
        private var unblockContinuation: CheckedContinuation<Void, Never>?

        func upload(_ payload: LocationSnapshotPushPayload) async throws {
            payloads.append(payload)
            if payloads.count == 1 {
                firstAttemptContinuation?.resume()
                firstAttemptContinuation = nil
            }
            while isBlocked {
                await withCheckedContinuation { continuation in
                    unblockContinuation = continuation
                }
            }
            if failFirst && payloads.count == 1 { throw LocationPushError.invalidResponseStatus(503) }
        }

        func waitForFirstAttempt() async {
            if payloads.isEmpty == false { return }
            await withCheckedContinuation { continuation in
                firstAttemptContinuation = continuation
            }
        }

        func unblock() {
            isBlocked = false
            unblockContinuation?.resume()
            unblockContinuation = nil
        }

        func attemptCount() -> Int {
            payloads.count
        }

        func waitForAttemptCount(atLeast count: Int) async -> Bool {
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(5))
            while payloads.count < count, clock.now < deadline {
                do {
                    try await Task.sleep(for: .milliseconds(1))
                } catch {
                    return false
                }
            }
            return payloads.count >= count
        }
    }

    private actor GateablePreferenceUploader: DevicePreferenceSyncUploading {
        private var payloads: [DevicePreferenceSyncPayload] = []
        private var isBlocked = true
        private var firstAttemptContinuation: CheckedContinuation<Void, Never>?
        private var unblockContinuation: CheckedContinuation<Void, Never>?

        func upload(_ payload: DevicePreferenceSyncPayload) async throws {
            payloads.append(payload)
            if payloads.count == 1 {
                firstAttemptContinuation?.resume()
                firstAttemptContinuation = nil
            }
            while isBlocked {
                await withCheckedContinuation { continuation in
                    unblockContinuation = continuation
                }
            }
        }

        func waitForFirstAttempt() async {
            if payloads.isEmpty == false { return }
            await withCheckedContinuation { continuation in
                firstAttemptContinuation = continuation
            }
        }

        func unblock() {
            isBlocked = false
            unblockContinuation?.resume()
            unblockContinuation = nil
        }

        func uploadedPayloads() -> [DevicePreferenceSyncPayload] { payloads }

        func attemptCount() -> Int {
            payloads.count
        }
    }

    private actor SteppedPreferenceUploader: DevicePreferenceSyncUploading {
        private var payloads: [DevicePreferenceSyncPayload] = []
        private var releases: [Int: CheckedContinuation<Void, Never>] = [:]

        func upload(_ payload: DevicePreferenceSyncPayload) async throws {
            payloads.append(payload)
            let index = payloads.count
            await withCheckedContinuation { releases[index] = $0 }
        }

        func waitForAttempt(_ count: Int) async -> Bool {
            let deadline = ContinuousClock().now.advanced(by: .seconds(5))
            while payloads.count < count, ContinuousClock().now < deadline {
                try? await Task.sleep(for: .milliseconds(1))
            }
            return payloads.count >= count
        }

        func release(_ index: Int) { releases.removeValue(forKey: index)?.resume() }
        func subscriptions() -> [Bool] { payloads.map(\.isSubscribed) }
    }

    private actor RevokingSnapshotUploader: LocationSnapshotUploading {
        let sharing: BoolBox
        let status: Int
        private var count = 0

        init(sharing: BoolBox, status: Int) {
            self.sharing = sharing
            self.status = status
        }

        func upload(_ payload: LocationSnapshotPushPayload) async throws {
            count += 1
            sharing.set(false)
            throw LocationPushError.invalidResponseStatus(status)
        }

        func attemptCount() -> Int { count }
    }

    private actor InMemoryUploadQueueStore: LocationUploadQueueStoring {
        private var pending: [PersistedLocationUploadRequest]

        init(seed: [PersistedLocationUploadRequest] = []) {
            self.pending = seed
        }

        func loadPendingRequests() async -> [PersistedLocationUploadRequest] {
            pending
        }

        func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async {
            pending = requests
        }

        func current() async -> [PersistedLocationUploadRequest] {
            pending
        }

        func waitForEmpty() async -> Bool {
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(5))
            while pending.isEmpty == false, clock.now < deadline {
                try? await Task.sleep(for: .milliseconds(1))
            }
            return pending.isEmpty
        }
    }

    private func persistedUploadRequest(
        requestedAt: Date,
        isSubscribed: Bool = true,
        forceUpload: Bool = false
    ) -> PersistedLocationUploadRequest {
        PersistedLocationUploadRequest(
            source: .manualRefresh,
            reason: .locationResolved,
            forceUpload: forceUpload,
            installationId: "install-abc-123",
            requestedAt: requestedAt,
            isSubscribed: isSubscribed,
            authorizationState: "always",
            apnsToken: "",
            operation: .locationSnapshot(context: PersistedLocationContext(makeContext()))
        )
    }
    
    private final class MockSnapshotCache: @unchecked Sendable, LocationSnapshotCaching {
        private(set) var storedSnapshot: LocationSnapshot?
        private(set) var saveCount = 0
        
        init(storedSnapshot: LocationSnapshot? = nil) {
            self.storedSnapshot = storedSnapshot
        }
        
        func load() -> LocationSnapshot? {
            storedSnapshot
        }
        
        func save(_ snapshot: LocationSnapshot) {
            saveCount += 1
            storedSnapshot = snapshot
        }
    }

    private final class TokenBox: @unchecked Sendable {
        private let lock = NSLock()
        private var token: String

        init(_ token: String) {
            self.token = token
        }

        func value() -> String {
            lock.lock()
            defer { lock.unlock() }
            return token
        }

        func set(_ newValue: String) {
            lock.lock()
            token = newValue
            lock.unlock()
        }
    }

    private final class ClockBox: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Date

        init(_ date: Date) {
            self.current = date
        }

        func now() -> Date {
            lock.lock()
            defer { lock.unlock() }
            return current
        }

        func advance(by seconds: TimeInterval) {
            lock.lock()
            current = current.addingTimeInterval(seconds)
            lock.unlock()
        }
    }

    private final class BoolBox: @unchecked Sendable {
        private let lock = NSLock()
        private var current: Bool

        init(_ value: Bool) {
            self.current = value
        }

        func value() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return current
        }

        func set(_ newValue: Bool) {
            lock.lock()
            current = newValue
            lock.unlock()
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

    private actor CoordinateGateGeocoder: LocationGeocoding {
        private var callCount = 0
        private var firstContinuation: CheckedContinuation<String, Never>?

        func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
            callCount += 1
            firstCallContinuation?.resume()
            firstCallContinuation = nil
            if callCount == 1 {
                return await withCheckedContinuation { continuation in
                    firstContinuation = continuation
                }
            }
            return "B City"
        }

        func waitForFirstCall() async {
            if callCount > 0 { return }
            await withCheckedContinuation { continuation in
                firstCallContinuation = continuation
            }
        }

        private var firstCallContinuation: CheckedContinuation<Void, Never>?

        func releaseFirst() {
            firstContinuation?.resume(returning: "B City")
            firstContinuation = nil
        }

        func callCountValue() -> Int { callCount }
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
        let second = first.addingTimeInterval(6)

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
    
    private struct UnavailableContextResolver: LocationContextResolving {
        func prepareCurrentContext(
            requiresFreshLocation: Bool, showsAuthorizationPrompt: Bool,
            authorizationTimeout: Double, locationTimeout: Double,
            maximumAcceptedLocationAge: TimeInterval, placemarkTimeout: Double
        ) async throws -> LocationContext { throw LocationContextError.locationUnavailable }

        func resolveContext(
            from snapshot: LocationSnapshot, maximumAcceptedLocationAge: TimeInterval?, placemarkTimeout: Double
        ) async throws -> LocationContext { throw LocationContextError.locationUnavailable }
    }

    @MainActor
    @Test("startup and token drain advertise meso preference without location or Settings")
    func mesoPreference_sessionDrainSynchronizesWithoutLocation() async throws {
        let preferences = MockPreferenceUploader()
        let snapshots = MockSnapshotUploader()
        let token = TokenBox("")
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: snapshots, preferenceUploader: preferences,
            apnsTokenProvider: { token.value() }, installationIdProvider: { "meso-install" },
            subscriptionStatusProvider: { false }, mesoNotificationEnabledProvider: { false },
            locationUploadEnabledProvider: { false }, authorizationStatusProvider: { .denied },
            retryDelaysSeconds: [0], queueStore: store
        )
        let provider = LocationProvider(snapshotCache: NoOpLocationSnapshotCache())
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: LocationManager(onUpdate: { _ in }),
            locationContextResolver: UnavailableContextResolver(), locationUploadCoordinator: pusher
        )
        await session.drainPendingLocationUploads()
        #expect(await store.current().isEmpty)
        #expect(await preferences.uploadedPayloads().count == 1)
        token.set("token")
        await session.drainPendingLocationUploads()
        let payload = try #require(await preferences.uploadedPayloads().last)
        #expect(payload.mesoNotificationsEnabled == false)
        #expect(payload.isSubscribed == false)
        #expect(await snapshots.uploadedPayloads().isEmpty)
    }

    @Test("in-flight meso toggle round trip sends current consent last")
    func mesoPreference_inFlightRoundTrip() async throws {
        let state = TokenBox("true")
        let uploader = GateablePreferenceUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(), preferenceUploader: uploader,
            apnsTokenProvider: { "token" }, installationIdProvider: { "meso-install" },
            mesoNotificationEnabledProvider: { state.value() == "true" },
            authorizationStatusProvider: { .authorizedAlways }, retryDelaysSeconds: [0],
            queueStore: InMemoryUploadQueueStore()
        )
        let first = Task {
            await pusher.enqueuePreferenceSync(
                source: .settingsPreference, requestReason: .preferenceChanged,
                forceUpload: true, detail: "meso-notification"
            )
        }
        await uploader.waitForFirstAttempt()
        state.set("false")
        await pusher.enqueuePreferenceSync(
            source: .settingsPreference, requestReason: .preferenceChanged,
            forceUpload: true, detail: "meso-notification"
        )
        state.set("true")
        await pusher.enqueuePreferenceSync(
            source: .settingsPreference, requestReason: .preferenceChanged,
            forceUpload: true, detail: "meso-notification"
        )
        await uploader.unblock()
        await first.value
        #expect(await uploader.uploadedPayloads().map(\.mesoNotificationsEnabled) == [true, true])
    }

    @Test("legacy and explicit meso pending keys stay stable across preference changes")
    func mesoPreference_legacyPendingKeysAreStable() async throws {
        let suite = "meso-legacy-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        await store.savePendingRequests([persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10))])
        let state = TokenBox("true")
        let first = LocationSnapshotPusher(
            locationUploader: OfflineSnapshotUploader(), preferenceUploader: OfflinePreferenceUploader(),
            apnsTokenProvider: { "" }, installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            mesoNotificationEnabledProvider: { state.value() == "true" },
            locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedAlways }, retryDelaysSeconds: [0], queueStore: store
        )
        await first.drainPendingUploads()
        state.set("false")
        await first.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        let reopened = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        let snapshots = MockSnapshotUploader()
        let second = LocationSnapshotPusher(
            locationUploader: snapshots, preferenceUploader: MockPreferenceUploader(),
            apnsTokenProvider: { "token" }, mesoNotificationEnabledProvider: { false },
            authorizationStatusProvider: { .authorizedAlways }, retryDelaysSeconds: [0], queueStore: reopened
        )
        await second.drainPendingUploads()
        #expect(await reopened.loadPendingRequests().isEmpty)
        let payloads = await snapshots.uploadedPayloads()
        #expect(payloads.count == 2)
        #expect(payloads.allSatisfy { $0.mesoNotificationsEnabled == false })
    }

    @Test("meso preference survives a durable queue reopen and bounded drain", arguments: [false, true])
    func mesoPreference_survivesQueueReopen(enabled: Bool) async throws {
        let suite = "meso-queue-\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        let first = LocationSnapshotPusher(
            locationUploader: OfflineSnapshotUploader(),
            preferenceUploader: OfflinePreferenceUploader(),
            apnsTokenProvider: { "" },
            installationIdProvider: { "meso-install" },
            subscriptionStatusProvider: { false },
            mesoNotificationEnabledProvider: { enabled },
            locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )
        await first.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        await first.enqueuePreferenceSync(
            source: .settingsPreference, requestReason: .preferenceChanged,
            forceUpload: true, detail: "meso-notification"
        )
        let reopened = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        let requests = await reopened.loadPendingRequests()
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.mesoNotificationsEnabled == enabled })
        let snapshots = MockSnapshotUploader()
        let preferences = MockPreferenceUploader()
        let second = LocationSnapshotPusher(
            locationUploader: snapshots, preferenceUploader: preferences,
            apnsTokenProvider: { "new-token" },
            subscriptionStatusProvider: { false },
            mesoNotificationEnabledProvider: { !enabled },
            locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0], queueStore: reopened
        )
        let outcome = await second.drainPendingUploads(
            using: .init(uploadQuota: 2, deadline: .now.advanced(by: .seconds(10)))
        )
        #expect(outcome == .drained)
        let snapshot = try #require(await snapshots.uploadedPayloads().first)
        let preference = try #require(await preferences.uploadedPayloads().first)
        #expect(snapshot.mesoNotificationsEnabled == !enabled)
        #expect(preference.mesoNotificationsEnabled == !enabled)
        #expect(snapshot.isSubscribed == false)
        #expect(preference.isSubscribed == false)
    }

    @Test("meso preference change bypasses semantic deduplication")
    func mesoPreference_changeSynchronizes() async throws {
        let state = TokenBox("true")
        let uploader = MockPreferenceUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(), preferenceUploader: uploader,
            apnsTokenProvider: { "token" }, installationIdProvider: { "meso-install" },
            mesoNotificationEnabledProvider: { state.value() == "true" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0], queueStore: InMemoryUploadQueueStore()
        )
        await pusher.enqueuePreferenceSync(
            source: .settingsPreference, requestReason: .preferenceChanged,
            forceUpload: true, detail: "meso-notification"
        )
        state.set("false")
        await pusher.enqueuePreferenceSync(
            source: .settingsPreference, requestReason: .preferenceChanged,
            forceUpload: true, detail: "meso-notification"
        )
        state.set("true")
        await pusher.enqueuePreferenceSync(
            source: .settingsPreference, requestReason: .preferenceChanged,
            forceUpload: true, detail: "meso-notification"
        )
        #expect(await uploader.uploadedPayloads().map(\.mesoNotificationsEnabled) == [true, false, true])
    }

    @Test("location context pusher payload includes timestamp and apns token")
    func locationContextPusher_includesTimestampAndApnsToken() async throws {
        let uploader = MockSnapshotUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { false },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0]
        )

        let context = makeContext()
        await pusher.enqueue(context, source: .manualRefresh, reason: .locationResolved)
        
        let payloads = await uploader.uploadedPayloads()
        let payload = try #require(payloads.first)
        #expect(payload.capturedAt == context.snapshot.timestamp)
        #expect(payload.installationId == "install-abc-123")
        #expect(payload.apnsDeviceToken == "apns-token-123")
        #expect(payload.county == "OKC109")
        #expect(payload.zone == "OKZ025")
        #expect(payload.fireZone == "OKZ025")
        #expect(payload.h3Cell == sampleH3Cell)
        #expect(payload.isSubscribed == false)
        #expect(payload.source == LocationUploadSource.manualRefresh.rawValue)
        #expect(payload.auth == "always")
    }

    @Test("location context pusher permits upload without APNs")
    func locationContextPusher_skipsUploadWithoutApnsToken() async {
        let uploader = MockSnapshotUploader()
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { " " },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.count == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("location sends without an APNs token")
    func locationContextPusher_missingTokenPersistsAndDrainsOnRetry() async throws {
        let uploader = MockSnapshotUploader()
        let store = InMemoryUploadQueueStore()
        let tokenState = TokenBox("")
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { tokenState.value() },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )
        let context = makeContext()

        await pusher.enqueue(context, source: .manualRefresh, reason: .locationResolved)
        #expect(await store.current().isEmpty)
        tokenState.set("apns-token-123")
        await pusher.drainPendingUploads()

        #expect(await uploader.uploadedPayloads().count == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("opt-out preference sync sends without location or APNs")
    func locationContextPusher_preferenceSyncWithoutContext_missingTokenPersists() async throws {
        let locationUploader = MockSnapshotUploader()
        let preferenceUploader = MockPreferenceUploader()
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: locationUploader,
            preferenceUploader: preferenceUploader,
            apnsTokenProvider: { "" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { false },
            locationUploadEnabledProvider: { false },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "location-sharing"
        )

        #expect(await locationUploader.uploadedPayloads().isEmpty)
        let payload = try #require(await preferenceUploader.uploadedPayloads().first)
        #expect(payload.isSubscribed == false)
        #expect(payload.apnsDeviceToken.isEmpty)
        #expect(await store.current().isEmpty)
    }

    @Test("opt-out preference sync without location context drains when APNs token arrives")
    func locationContextPusher_preferenceSyncWithoutContext_drainsOnTokenArrival() async throws {
        let locationUploader = MockSnapshotUploader()
        let preferenceUploader = MockPreferenceUploader()
        let store = InMemoryUploadQueueStore()
        let tokenState = TokenBox("")
        let pusher = LocationSnapshotPusher(
            locationUploader: locationUploader,
            preferenceUploader: preferenceUploader,
            apnsTokenProvider: { tokenState.value() },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { false },
            locationUploadEnabledProvider: { false },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )
        #expect(await store.current().isEmpty)

        tokenState.set("apns-token-123")
        await pusher.drainPendingUploads()

        #expect(await locationUploader.uploadedPayloads().isEmpty)
        let payload = try #require(await preferenceUploader.uploadedPayloads().first)
        #expect(payload.source == LocationUploadSource.settingsPreference.rawValue)
        #expect(payload.isSubscribed == false)
        #expect(payload.reason == LocationUploadReason.preferenceChanged.rawValue)
        #expect(await store.current().isEmpty)
    }

    @Test("reopened queues suppress revoked location on ordinary and bounded token drains",
          arguments: [false, true], [false, true])
    func consentReplay_revokedLocation(bounded: Bool, denied: Bool) async throws {
        let suite = "revoked-reopen-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        await UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
            .savePendingRequests([persistedUploadRequest(requestedAt: .now)])
        let store = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        let token = TokenBox("")
        let locations = MockSnapshotUploader()
        let preferences = MockPreferenceUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: locations, preferenceUploader: preferences,
            apnsTokenProvider: { token.value() }, installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { false }, locationUploadEnabledProvider: { denied },
            authorizationStatusProvider: { denied ? .denied : .authorizedAlways },
            retryDelaysSeconds: [0], queueStore: store
        )
        await pusher.drainPendingUploads()
        #expect(await store.loadPendingRequests().isEmpty)
        token.set("new-token")
        if bounded {
            let outcome = await pusher.drainPendingUploads(using: .init(uploadQuota: 1, deadline: .now.advanced(by: .seconds(5))))
            #expect(outcome == .drained)
        } else {
            await pusher.drainPendingUploads()
        }
        #expect(await locations.uploadedPayloads().isEmpty)
        #expect(await store.loadPendingRequests().isEmpty)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "opt-out")
        let payload = try #require(await preferences.uploadedPayloads().last)
        #expect(payload.isSubscribed == false)
        #expect(payload.apnsDeviceToken == "new-token")
    }

    @Test("queued preferences use current consent and permit later re-enablement")
    func consentReplay_preferenceReenable() async throws {
        let subscribed = BoolBox(true)
        let token = TokenBox("")
        let store = InMemoryUploadQueueStore()
        let preferences = MockPreferenceUploader()
        func reopened() -> LocationSnapshotPusher {
            LocationSnapshotPusher(
                locationUploader: MockSnapshotUploader(), preferenceUploader: preferences,
                apnsTokenProvider: { token.value() }, installationIdProvider: { "install-abc-123" },
                subscriptionStatusProvider: { subscribed.value() }, mesoNotificationEnabledProvider: { false },
                locationUploadEnabledProvider: { true }, authorizationStatusProvider: { .denied },
                retryDelaysSeconds: [0], queueStore: store
            )
        }
        await reopened().enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                               forceUpload: true, detail: "old-opt-in")
        await store.savePendingRequests([PersistedLocationUploadRequest(
            source: .settingsPreference, reason: .preferenceChanged, forceUpload: true,
            installationId: "install-abc-123", requestedAt: .distantPast, isSubscribed: true,
            authorizationState: "always", apnsToken: "", operation: .preferenceSync)])
        subscribed.set(false)
        token.set("current-token")
        let pusher = reopened()
        await pusher.drainPendingUploads()
        let optOut = try #require(await preferences.uploadedPayloads().last)
        #expect(optOut.isSubscribed == false)
        #expect(optOut.auth == "denied")
        #expect(optOut.mesoNotificationsEnabled == false)
        subscribed.set(true)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "reenable", isSubscribedOverride: true)
        #expect(await preferences.uploadedPayloads().last?.isSubscribed == true)
    }

    @Test("revocation after handoff prevents retries and legacy-source fallback", arguments: [503, 422])
    func consentReplay_retryAndFallback(status: Int) async {
        let sharing = BoolBox(true)
        let uploader = RevokingSnapshotUploader(sharing: sharing, status: status)
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader, preferenceUploader: MockPreferenceUploader(),
            apnsTokenProvider: { "token" }, installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true }, locationUploadEnabledProvider: { sharing.value() },
            authorizationStatusProvider: { .authorizedAlways }, retryDelaysSeconds: [0, 1], queueStore: store
        )
        await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        #expect(await uploader.attemptCount() == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("an in-flight old location cannot cause a further transfer after opt-out")
    func consentReplay_inFlightBoundary() async throws {
        let sharing = BoolBox(true)
        let subscribed = BoolBox(true)
        let locations = GateableSnapshotUploader(failFirst: true)
        let preferences = MockPreferenceUploader()
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: locations, preferenceUploader: preferences,
            apnsTokenProvider: { "token" }, installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { subscribed.value() }, locationUploadEnabledProvider: { sharing.value() },
            authorizationStatusProvider: { .authorizedAlways }, retryDelaysSeconds: [0], queueStore: store
        )
        let old = Task { await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved) }
        await locations.waitForFirstAttempt()
        sharing.set(false)
        subscribed.set(false)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "opt-out", isSubscribedOverride: false)
        await locations.unblock()
        await old.value
        await pusher.drainPendingUploads()
        #expect(await locations.attemptCount() == 1)
        #expect(await preferences.uploadedPayloads().last?.isSubscribed == false)
        // The first request already crossed handoff. Signal #379 owns its commit ordering.
    }

    @Test("explicit subscription intent survives token delay and reversal with lagging defaults")
    func consentReplay_delayedOverride() async throws {
        let token = TokenBox("")
        let subscribed = BoolBox(true)
        let preferences = MockPreferenceUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(), preferenceUploader: preferences,
            apnsTokenProvider: { token.value() }, installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { subscribed.value() }, locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedAlways }, retryDelaysSeconds: [0], queueStore: InMemoryUploadQueueStore()
        )
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "opt-out", isSubscribedOverride: false)
        token.set("token")
        await pusher.drainPendingUploads()
        #expect(await preferences.uploadedPayloads().last?.isSubscribed == false)
        subscribed.set(false)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "defaults-caught-up")
        subscribed.set(true)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "reenable", isSubscribedOverride: true)
        #expect(await preferences.uploadedPayloads().map(\.isSubscribed) == [false, false, true])
    }

    @Test("changed replay consent cannot coalesce away a newer opt-out", arguments: [false, true])
    func consentReplay_preservesFollowup(bounded: Bool) async throws {
        let subscribed = BoolBox(true)
        let preferences = GateablePreferenceUploader()
        let request = PersistedLocationUploadRequest(
            source: .settingsPreference, reason: .preferenceChanged, forceUpload: true,
            installationId: "install-abc-123", requestedAt: .distantPast, isSubscribed: false,
            authorizationState: "always", apnsToken: "token", operation: .preferenceSync
        )
        let store = InMemoryUploadQueueStore(seed: [request])
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(), preferenceUploader: preferences,
            apnsTokenProvider: { "token" }, installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { subscribed.value() }, locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedAlways }, retryDelaysSeconds: [0], queueStore: store
        )
        let drain = Task {
            if bounded {
                _ = await pusher.drainPendingUploads(using: .init(uploadQuota: 1, deadline: .now.advanced(by: .seconds(5))))
            } else {
                await pusher.drainPendingUploads()
            }
        }
        await preferences.waitForFirstAttempt()
        subscribed.set(false)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "opt-out", isSubscribedOverride: false)
        await preferences.unblock()
        await drain.value
        #expect(await store.waitForEmpty())
        #expect(await preferences.uploadedPayloads().map(\.isSubscribed) == [true, false])
    }

    @Test("consent reversals during a follow-up cannot be deduped", arguments: [false, true])
    func consentReplay_roundTrip(initial: Bool) async throws {
        let subscribed = BoolBox(initial)
        let preferences = SteppedPreferenceUploader()
        let request = PersistedLocationUploadRequest(
            source: .settingsPreference, reason: .preferenceChanged, forceUpload: true,
            installationId: "install-abc-123", requestedAt: .distantPast, isSubscribed: !initial,
            authorizationState: "always", apnsToken: "token", operation: .preferenceSync
        )
        let store = InMemoryUploadQueueStore(seed: [request])
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(), preferenceUploader: preferences,
            apnsTokenProvider: { "token" }, installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { subscribed.value() }, locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedAlways }, retryDelaysSeconds: [0], queueStore: store
        )
        let drain = Task { await pusher.drainPendingUploads() }
        #expect(await preferences.waitForAttempt(1))
        subscribed.set(!initial)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "reverse", isSubscribedOverride: !initial)
        await preferences.release(1)
        #expect(await preferences.waitForAttempt(2))
        subscribed.set(initial)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "restore", isSubscribedOverride: initial)
        await preferences.release(2)
        #expect(await preferences.waitForAttempt(3))
        await preferences.release(3)
        await drain.value
        #expect(await preferences.subscriptions() == [initial, !initial, initial])
        #expect(await store.current().isEmpty)
    }

    @Test("a delayed enable callback cannot override the current opt-out", arguments: [false, true], [false, true])
    func consentReplay_outOfOrderSettingsCallbacks(delayedToken: Bool, laggingDefaults: Bool) async throws {
        let subscribed = BoolBox(laggingDefaults)
        let token = TokenBox(delayedToken ? "" : "token")
        let locations = MockSnapshotUploader()
        let preferences = MockPreferenceUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: locations, preferenceUploader: preferences,
            apnsTokenProvider: { token.value() }, installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { subscribed.value() }, locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedAlways }, retryDelaysSeconds: [0], queueStore: InMemoryUploadQueueStore()
        )
        // The user enabled, then disabled. Deliver the newer disable callback first.
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "new-disable", isSubscribedOverride: false)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "old-enable", isSubscribedOverride: true)
        token.set("token")
        await pusher.drainPendingUploads()
        await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        let sentPreferences = await preferences.uploadedPayloads()
        let sentLocations = await locations.uploadedPayloads()
        #expect(!sentPreferences.isEmpty)
        #expect(!sentLocations.isEmpty)
        #expect(sentPreferences.allSatisfy { !$0.isSubscribed })
        #expect(sentLocations.allSatisfy { $0.isSubscribed == false })

        // A genuine enable may also precede its defaults write. Stay opted out
        // until the authoritative setting catches up, including future uploads.
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "lagging-enable", isSubscribedOverride: true)
        #expect(await preferences.uploadedPayloads().allSatisfy { !$0.isSubscribed })
        subscribed.set(false)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "confirmed-disable")
        subscribed.set(true)
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "confirmed-enable", isSubscribedOverride: true)
        await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        #expect(await preferences.uploadedPayloads().last?.isSubscribed == true)
        #expect(await locations.uploadedPayloads().last?.isSubscribed == true)
    }

    @Test("preference sync uses explicit subscription override instead of provider value")
    func preferenceSync_usesExplicitSubscriptionOverride() async throws {
        let locationUploader = MockSnapshotUploader()
        let preferenceUploader = MockPreferenceUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: locationUploader,
            preferenceUploader: preferenceUploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0]
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification",
            isSubscribedOverride: false
        )

        let payload = try #require(await preferenceUploader.uploadedPayloads().first)
        #expect(payload.isSubscribed == false)
        #expect(await locationUploader.uploadedPayloads().isEmpty)
    }

    @Test("onboarding upload survives delayed APNs token and drains deterministically")
    func locationContextPusher_onboardingDelayedToken_drainUsesOnboardingSource() async throws {
        let uploader = MockSnapshotUploader()
        let store = InMemoryUploadQueueStore()
        let tokenState = TokenBox("")
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { tokenState.value() },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedWhenInUse },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.enqueue(makeContext(), source: .onboarding, reason: .locationResolved)
        #expect(await store.current().isEmpty)

        tokenState.set("apns-token-123")
        await pusher.drainPendingUploads()

        let payload = try #require(await uploader.uploadedPayloads().first)
        #expect(payload.source == LocationUploadSource.onboarding.rawValue)
        #expect(payload.auth == "whenInUse")
        #expect(await store.current().isEmpty)
    }

    @Test("snapshot pusher persists pending request when upload fails after retry budget")
    func snapshotPusher_persistsOnRetryExhaustion() async throws {
        struct AlwaysFailingUploader: LocationSnapshotUploading {
            func upload(_ payload: LocationSnapshotPushPayload) async throws {
                throw LocationPushError.invalidResponseStatus(503)
            }
        }
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: AlwaysFailingUploader(),
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        #expect(await store.current().count == 1)
    }

    @Test("snapshot pusher persists pending request when upload is cancelled")
    func snapshotPusher_persistsOnCancellation() async throws {
        struct CancellingUploader: LocationSnapshotUploading {
            func upload(_ payload: LocationSnapshotPushPayload) async throws {
                throw CancellationError()
            }
        }
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: CancellingUploader(),
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        #expect(await store.current().count == 1)
    }

    @Test("preference sync persists pending request when upload fails after retry budget")
    func preferenceSync_persistsOnRetryExhaustion() async throws {
        struct AlwaysFailingPreferenceUploader: DevicePreferenceSyncUploading {
            func upload(_ payload: DevicePreferenceSyncPayload) async throws {
                throw LocationPushError.invalidResponseStatus(503)
            }
        }

        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(),
            preferenceUploader: AlwaysFailingPreferenceUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )
        #expect(await store.current().count == 1)
    }

    @Test("preference sync persists pending request when upload is cancelled")
    func preferenceSync_persistsOnCancellation() async throws {
        struct CancellingPreferenceUploader: DevicePreferenceSyncUploading {
            func upload(_ payload: DevicePreferenceSyncPayload) async throws {
                throw CancellationError()
            }
        }

        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(),
            preferenceUploader: CancellingPreferenceUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )
        #expect(await store.current().count == 1)
    }

    @Test("preference sync failed upload remains pending across immediate drain inside dedupe window")
    func preferenceSync_failedUploadImmediateDrain_doesNotDropPending() async throws {
        struct AlwaysFailingPreferenceUploader: DevicePreferenceSyncUploading {
            func upload(_ payload: DevicePreferenceSyncPayload) async throws {
                throw LocationPushError.invalidResponseStatus(503)
            }
        }

        let clock = ClockBox(Date(timeIntervalSince1970: 20_000))
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(),
            preferenceUploader: AlwaysFailingPreferenceUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15,
            queueStore: store
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )
        #expect(await store.current().count == 1)

        await pusher.drainPendingUploads()
        #expect(await store.current().count == 1)
    }

    @Test("snapshot failed upload remains pending across immediate drain inside dedupe window")
    func snapshotPusher_failedUploadImmediateDrain_doesNotDropPending() async throws {
        struct AlwaysFailingUploader: LocationSnapshotUploading {
            func upload(_ payload: LocationSnapshotPushPayload) async throws {
                throw LocationPushError.invalidResponseStatus(503)
            }
        }

        let clock = ClockBox(Date(timeIntervalSince1970: 21_000))
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: AlwaysFailingUploader(),
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15,
            queueStore: store
        )

        await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        #expect(await store.current().count == 1)

        await pusher.drainPendingUploads()
        #expect(await store.current().count == 1)
    }

    @Test("preference sync failed upload retries on immediate drain and clears pending only after success")
    func preferenceSync_failOnceThenDrainSuccess_clearsPendingAfterSuccess() async throws {
        let uploader = FailFirstThenSucceedPreferenceUploader()
        let clock = ClockBox(Date(timeIntervalSince1970: 22_000))
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(),
            preferenceUploader: uploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15,
            queueStore: store
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )
        #expect(await store.current().count == 1)

        await pusher.drainPendingUploads()
        #expect(await store.current().isEmpty)
        #expect(await uploader.uploadedPayloads().count == 2)
    }

    @Test("snapshot failed upload retries on immediate drain and clears pending only after success")
    func snapshotPusher_failOnceThenDrainSuccess_clearsPendingAfterSuccess() async throws {
        let uploader = FailFirstThenSucceedSnapshotUploader()
        let clock = ClockBox(Date(timeIntervalSince1970: 23_000))
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15,
            queueStore: store
        )

        await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        #expect(await store.current().count == 1)

        await pusher.drainPendingUploads()
        #expect(await store.current().isEmpty)
        #expect(await uploader.uploadedPayloads().count == 2)
    }

    @Test("preference sync drain removes persisted request on success")
    func preferenceSync_drainRemovesPersistedRequestOnSuccess() async throws {
        let uploader = MockPreferenceUploader()
        let persisted = PersistedLocationUploadRequest(
            source: .settingsPreference,
            reason: .preferenceChanged,
            forceUpload: true,
            installationId: "install-abc-123",
            requestedAt: Date(timeIntervalSince1970: 10_000),
            isSubscribed: false,
            authorizationState: "always",
            apnsToken: "",
            operation: .preferenceSync
        )
        let store = InMemoryUploadQueueStore(seed: [persisted])
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(),
            preferenceUploader: uploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.drainPendingUploads()
        #expect(await uploader.uploadedPayloads().count == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("snapshot pusher cancels retry during backoff and preserves pending request")
    func snapshotPusher_cancellationDuringBackoffStopsRetryAndPersistsPending() async throws {
        let uploader = BackoffCancellingUploader()
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0, 1],
            queueStore: store
        )

        let enqueueTask = Task {
            await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        }
        await uploader.waitForFirstAttempt()
        enqueueTask.cancel()
        await enqueueTask.value

        #expect(await uploader.attemptCount() == 1)
        #expect(await store.current().count == 1)
    }

    @Test("drain removes persisted request on successful upload")
    func snapshotPusher_drainRemovesPersistedRequestOnSuccess() async throws {
        let uploader = MockSnapshotUploader()
        let persisted = PersistedLocationUploadRequest(
            source: .manualRefresh,
            reason: .locationResolved,
            forceUpload: false,
            installationId: "install-abc-123",
            requestedAt: Date(timeIntervalSince1970: 10_000),
            isSubscribed: true,
            authorizationState: "always",
            apnsToken: "",
            operation: .locationSnapshot(context: PersistedLocationContext(makeContext()))
        )
        let store = InMemoryUploadQueueStore(seed: [persisted])
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.drainPendingUploads()
        #expect(await uploader.uploadedPayloads().count == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("bounded drain reports completion after uploading durable work")
    func snapshotPusher_boundedDrainReportsCompletionAfterSuccess() async {
        let uploader = MockSnapshotUploader()
        let store = InMemoryUploadQueueStore(seed: [
            persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10_000))
        ])
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        let outcome = await pusher.drainPendingUploads(
            using: .init(uploadQuota: 1, deadline: .now.advanced(by: .seconds(10)))
        )

        #expect(outcome == .drained)
        #expect(await uploader.uploadedPayloads().count == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("bounded drain preserves and later drains quota remainder")
    func snapshotPusher_boundedDrainPreservesQuotaRemainder() async {
        let uploader = MockSnapshotUploader()
        let first = persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10_000))
        let second = persistedUploadRequest(
            requestedAt: Date(timeIntervalSince1970: 10_001),
            isSubscribed: false
        )
        let third = persistedUploadRequest(
            requestedAt: Date(timeIntervalSince1970: 10_002),
            forceUpload: true
        )
        let store = InMemoryUploadQueueStore(seed: [first, second, third])
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        let firstOutcome = await pusher.drainPendingUploads(
            using: .init(uploadQuota: 2, deadline: .now.advanced(by: .seconds(10)))
        )

        #expect(firstOutcome == .remaining)
        #expect(await uploader.uploadedPayloads().count == 2)
        #expect(await store.current() == [third])

        let secondOutcome = await pusher.drainPendingUploads(
            using: .init(uploadQuota: 1, deadline: .now.advanced(by: .seconds(10)))
        )

        #expect(secondOutcome == .drained)
        #expect(await uploader.uploadedPayloads().count == 3)
        #expect(await store.current().isEmpty)
    }

    @Test("expired bounded drain starts no upload and reports durable remainder")
    func snapshotPusher_expiredBoundedDrainPreservesPendingRequest() async {
        let uploader = MockSnapshotUploader()
        let pending = persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10_000))
        let store = InMemoryUploadQueueStore(seed: [pending])
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        let outcome = await pusher.drainPendingUploads(
            using: .init(uploadQuota: 1, deadline: .now.advanced(by: .seconds(-1)))
        )

        #expect(outcome == .remaining)
        #expect(await uploader.uploadedPayloads().isEmpty)
        #expect(await store.current() == [pending])
    }

    @Test("bounded drain permits work without APNs")
    func snapshotPusher_boundedDrainMissingTokenReportsRemaining() async {
        let uploader = MockSnapshotUploader()
        let pending = persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10_000))
        let store = InMemoryUploadQueueStore(seed: [pending])
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { " " },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        let outcome = await pusher.drainPendingUploads(
            using: .init(uploadQuota: 1, deadline: .now.advanced(by: .seconds(10)))
        )

        #expect(outcome == .drained)
        #expect(await uploader.uploadedPayloads().count == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("bounded drain retains retry exhaustion and reports remaining")
    func snapshotPusher_boundedDrainRetryExhaustionReportsRemaining() async {
        struct AlwaysFailingUploader: LocationSnapshotUploading {
            func upload(_ payload: LocationSnapshotPushPayload) async throws {
                throw LocationPushError.invalidResponseStatus(503)
            }
        }
        let pending = persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10_000))
        let store = InMemoryUploadQueueStore(seed: [pending])
        let pusher = LocationSnapshotPusher(
            locationUploader: AlwaysFailingUploader(),
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0, 0],
            queueStore: store
        )

        let outcome = await pusher.drainPendingUploads(
            using: .init(uploadQuota: 1, deadline: .now.advanced(by: .seconds(10)))
        )

        #expect(outcome == .remaining)
        #expect(await store.current() == [pending])
    }

    @Test("bounded drain stops at its deadline during retry backoff")
    func snapshotPusher_boundedDrainDeadlineDuringBackoffPreservesPendingRequest() async {
        struct AlwaysFailingUploader: LocationSnapshotUploading {
            func upload(_ payload: LocationSnapshotPushPayload) async throws {
                throw LocationPushError.invalidResponseStatus(503)
            }
        }
        let pending = persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10_000))
        let store = InMemoryUploadQueueStore(seed: [pending])
        let pusher = LocationSnapshotPusher(
            locationUploader: AlwaysFailingUploader(),
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0, 5],
            queueStore: store
        )

        let outcome = await pusher.drainPendingUploads(
            using: .init(uploadQuota: 1, deadline: .now.advanced(by: .milliseconds(100)))
        )

        #expect(outcome == .remaining)
        #expect(await store.current() == [pending])
    }

    @Test("bounded drain cancellation preserves current and unattempted pending work")
    func snapshotPusher_boundedDrainCancellationPreservesPendingRequests() async {
        let uploader = BackoffCancellingUploader()
        let first = persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10_000))
        let second = persistedUploadRequest(
            requestedAt: Date(timeIntervalSince1970: 10_001),
            isSubscribed: false
        )
        let store = InMemoryUploadQueueStore(seed: [first, second])
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0, 5],
            queueStore: store
        )

        let drainTask = Task {
            await pusher.drainPendingUploads(
                using: .init(uploadQuota: 2, deadline: .now.advanced(by: .seconds(10)))
            )
        }
        await uploader.waitForFirstAttempt()
        drainTask.cancel()
        let outcome = await drainTask.value

        #expect(outcome == .remaining)
        #expect(await uploader.attemptCount() == 1)
        #expect(await store.current() == [first, second])
    }

    @Test("persisted queued upload encodes the current operation shape and round trips")
    func persistedQueuedUpload_currentPayloadRoundTrips() throws {
        let persisted = PersistedLocationUploadRequest(
            source: .manualRefresh,
            reason: .locationResolved,
            forceUpload: false,
            installationId: "install-abc-123",
            requestedAt: Date(timeIntervalSince1970: 1_780_358_400),
            isSubscribed: true,
            authorizationState: "always",
            apnsToken: "apns-token-123",
            operation: .locationSnapshot(context: PersistedLocationContext(makeContext()))
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(persisted)

        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == [
            "source",
            "reason",
            "forceUpload",
            "installationId",
            "requestedAt",
            "isSubscribed",
            "authorizationState",
            "apnsToken",
            "operation"
        ])
        let operation = try #require(json["operation"] as? [String: Any])
        #expect(operation["kind"] as? String == "locationSnapshot")
        #expect(operation["context"] is [String: Any])
        #expect(json["context"] == nil)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(PersistedLocationUploadRequest.self, from: data) == persisted)
    }

    @Test("legacy queued upload payloads decode without a persisted operation key")
    func persistedQueuedUpload_legacyPayloadsDecodeWithoutOperationKey() throws {
        let json = #"""
        [
          {
            "source": "manualRefresh",
            "reason": "locationResolved",
            "forceUpload": false,
            "installationId": "install-abc-123",
            "requestedAt": "2026-06-02T00:00:00Z",
            "isSubscribed": true,
            "authorizationState": "always",
            "apnsToken": "apns-token-123",
            "context": {
              "capturedAt": "2026-06-02T00:00:00Z",
              "horizontalAccuracyMeters": 42,
              "h3Cell": \#(sampleH3Cell),
              "county": "OKC109",
              "fireZone": "OKZ025",
              "forecastZone": "OKZ055",
              "countyLabel": "Oklahoma County",
              "fireZoneLabel": "Central Oklahoma"
            }
          },
          {
            "source": "settingsPreference",
            "reason": "preferenceChanged",
            "forceUpload": true,
            "installationId": "install-abc-123",
            "requestedAt": "2026-06-02T00:00:00Z",
            "isSubscribed": false,
            "authorizationState": "whenInUse",
            "apnsToken": "apns-token-123"
          }
        ]
        """#

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let requests = try decoder.decode([PersistedLocationUploadRequest].self, from: Data(json.utf8))

        let snapshotRequest = try #require(requests.first)
        switch snapshotRequest.operation {
        case .locationSnapshot(let context):
            #expect(context.capturedAt == Date(timeIntervalSince1970: 1_780_358_400))
            #expect(context.horizontalAccuracyMeters == 42)
            #expect(context.h3Cell == sampleH3Cell)
            #expect(context.county == "OKC109")
            #expect(context.fireZone == "OKZ025")
            #expect(context.forecastZone == "OKZ055")
            #expect(context.countyLabel == "Oklahoma County")
            #expect(context.fireZoneLabel == "Central Oklahoma")
        case .preferenceSync:
            Issue.record("Expected legacy snapshot payload to decode as a location snapshot")
        }

        let preferenceRequest = try #require(requests.last)
        switch preferenceRequest.operation {
        case .preferenceSync:
            #expect(preferenceRequest.source == .settingsPreference)
            #expect(preferenceRequest.reason == .preferenceChanged)
            #expect(preferenceRequest.forceUpload == true)
        case .locationSnapshot:
            Issue.record("Expected legacy preference payload to decode as a preference sync")
        }
    }

    @Test("snapshot pusher skips upload when location-to-signal is disabled")
    func snapshotPusher_skipsUploadWhenLocationSharingDisabled() async {
        let uploader = MockSnapshotUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            locationUploadEnabledProvider: { false },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0]
        )

        let context = makeContext(
            timestamp: Date(timeIntervalSince1970: 1_234_567),
            placemark: "OKC, OK",
            h3Cell: sampleH3Cell
        )

        await pusher.enqueue(context, source: .manualRefresh, reason: .locationResolved)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.isEmpty)
    }

    @Test("forced snapshot cannot bypass revoked location sharing")
    func snapshotPusher_forceUploadWhenLocationSharingDisabled() async throws {
        let uploader = MockSnapshotUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { false },
            locationUploadEnabledProvider: { false },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0]
        )

        let context = makeContext(
            timestamp: Date(timeIntervalSince1970: 1_234_567),
            placemark: "OKC, OK",
            h3Cell: sampleH3Cell
        )

        await pusher.enqueue(context, source: .settingsPreference, reason: .preferenceChanged, forceUpload: true)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.isEmpty)
    }

    @Test("snapshot pusher syncs consent while location sharing is disabled")
    func snapshotPusher_skipsNonForcedPreferenceSyncWhenLocationSharingDisabled() async throws {
        let locationUploader = MockSnapshotUploader()
        let preferenceUploader = MockPreferenceUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: locationUploader,
            preferenceUploader: preferenceUploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { false },
            locationUploadEnabledProvider: { false },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0]
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: false,
            detail: "notification"
        )

        #expect(await locationUploader.uploadedPayloads().isEmpty)
        #expect(await preferenceUploader.uploadedPayloads().count == 1)
    }

    @Test("snapshot pusher dedupes identical non-forced uploads inside the dedupe window")
    func snapshotPusher_dedupesIdenticalNonForcedUploads() async throws {
        let uploader = MockSnapshotUploader()
        let store = InMemoryUploadQueueStore()
        let clock = ClockBox(Date(timeIntervalSince1970: 10_000))
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15,
            queueStore: store
        )
        let context = makeContext()

        await pusher.enqueue(context, source: .foregroundPrime, reason: .locationResolved)
        await pusher.enqueue(context, source: .foregroundLocationChange, reason: .locationChanged)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.count == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("snapshot pusher coalesces identical upload while first matching upload is in flight")
    func snapshotPusher_coalescesInFlightIdenticalUpload() async throws {
        let uploader = GateableSnapshotUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse },
            retryDelaysSeconds: [0]
        )
        let context = makeContext()

        let firstTask = Task {
            await pusher.enqueue(context, source: .foregroundPrime, reason: .locationResolved)
        }
        await uploader.waitForFirstAttempt()
        await pusher.enqueue(context, source: .foregroundLocationChange, reason: .locationChanged)
        await uploader.unblock()
        await firstTask.value

        #expect(await uploader.attemptCount() == 1)
    }

    @Test("bounded upload drain preserves work queued while it is processing")
    func snapshotPusher_boundedDrainPreservesQueuedWork() async throws {
        let uploader = GateableSnapshotUploader()
        let store = InMemoryUploadQueueStore(seed: [
            persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10_000))
        ])
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse },
            retryDelaysSeconds: [0],
            queueStore: store
        )
        let secondContext = makeContext(h3Cell: sampleH3Cell + 1)
        let drainTask = Task {
            await pusher.drainPendingUploads(
                using: PendingLocationUploadDrainBudget(
                    uploadQuota: 1,
                    deadline: ContinuousClock().now.advanced(by: .seconds(5))
                )
            )
        }

        await uploader.waitForFirstAttempt()
        await pusher.enqueue(secondContext, source: .foregroundLocationChange, reason: .locationChanged)
        await uploader.unblock()

        #expect(await drainTask.value == .remaining)
        #expect(await uploader.waitForAttemptCount(atLeast: 2))
        #expect(await store.waitForEmpty())
    }

    @Test("bounded upload drain defers to an active ordinary processor")
    func snapshotPusher_boundedDrainDefersToActiveProcessor() async throws {
        let uploader = GateableSnapshotUploader()
        let store = InMemoryUploadQueueStore(seed: [
            persistedUploadRequest(requestedAt: Date(timeIntervalSince1970: 10_000))
        ])
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )
        let ordinaryTask = Task {
            await pusher.enqueue(makeContext(), source: .manualRefresh, reason: .locationResolved)
        }

        await uploader.waitForFirstAttempt()
        let outcome = await pusher.drainPendingUploads(
            using: PendingLocationUploadDrainBudget(
                uploadQuota: 1,
                deadline: ContinuousClock().now.advanced(by: .seconds(5))
            )
        )
        #expect(outcome == .remaining)

        await uploader.unblock()
        await ordinaryTask.value
        #expect(await uploader.attemptCount() == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("pending queue coalesces duplicate semantic keys deterministically")
    func snapshotPusher_pendingQueueCoalescesDuplicates() async throws {
        let uploader = OfflineSnapshotUploader()
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )
        let context = makeContext()

        await pusher.enqueue(context, source: .manualRefresh, reason: .locationResolved)
        await pusher.enqueue(context, source: .manualRefresh, reason: .locationResolved)

        #expect(await store.current().count == 1)
    }

    @Test("persisted empty-token request coalesces with same semantic request after APNs token becomes available")
    func snapshotPusher_coalescesPersistedRequestAcrossApnsTokenTransition() async throws {
        let uploader = MockSnapshotUploader()
        let context = makeContext()
        let persisted = PersistedLocationUploadRequest(
            source: .manualRefresh,
            reason: .locationResolved,
            forceUpload: false,
            installationId: "install-abc-123",
            requestedAt: Date(timeIntervalSince1970: 10_000),
            isSubscribed: true,
            authorizationState: "always",
            apnsToken: "",
            operation: .locationSnapshot(context: PersistedLocationContext(context))
        )
        let store = InMemoryUploadQueueStore(seed: [persisted])
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            locationUploadEnabledProvider: { true },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )

        await pusher.enqueue(context, source: .manualRefresh, reason: .locationResolved)
        await pusher.drainPendingUploads()

        #expect(await uploader.uploadedPayloads().count == 1)
        #expect(await store.current().isEmpty)
    }

    @Test("pending queue preserves distinct semantic keys")
    func snapshotPusher_pendingQueuePreservesDistinctKeys() async throws {
        let uploader = OfflineSnapshotUploader()
        let store = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "" },
            installationIdProvider: { "install-abc-123" },
            authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0],
            queueStore: store
        )
        let first = makeContext(
            h3Cell: sampleH3Cell,
            grid: makeGridSnapshot(countyCode: "OKC109", fireZone: "OKZ025")
        )
        let second = makeContext(
            h3Cell: sampleH3Cell + 1,
            grid: makeGridSnapshot(countyCode: "OKC017", fireZone: "OKZ030")
        )

        await pusher.enqueue(first, source: .manualRefresh, reason: .locationResolved)
        await pusher.enqueue(second, source: .manualRefresh, reason: .locationResolved)

        #expect(await store.current().count == 2)
    }

    @Test("snapshot pusher does not dedupe when location scope changes")
    func snapshotPusher_doesNotDedupeScopeChanges() async throws {
        let uploader = MockSnapshotUploader()
        let store = InMemoryUploadQueueStore()
        let clock = ClockBox(Date(timeIntervalSince1970: 12_000))
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15,
            queueStore: store
        )

        let first = makeContext(
            h3Cell: sampleH3Cell,
            grid: makeGridSnapshot(
                countyCode: "OKC109",
                fireZone: "OKZ025"
            )
        )
        let second = makeContext(
            h3Cell: sampleH3Cell + 1,
            grid: makeGridSnapshot(
                countyCode: "OKC017",
                fireZone: "OKZ030"
            )
        )

        await pusher.enqueue(first, source: .foregroundPrime, reason: .locationResolved)
        await pusher.enqueue(second, source: .foregroundLocationChange, reason: .locationChanged)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.count == 2)
        #expect(await store.current().isEmpty)
    }

    @Test("snapshot pusher does not dedupe preference state changes")
    func snapshotPusher_doesNotDedupePreferenceStateChanges() async throws {
        let uploader = MockPreferenceUploader()
        let clock = ClockBox(Date(timeIntervalSince1970: 13_000))
        let subscribed = BoolBox(true)
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(),
            preferenceUploader: uploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { subscribed.value() },
            authorizationStatusProvider: { .authorizedWhenInUse },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )
        subscribed.set(false)
        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.count == 2)
        #expect(payloads.map(\.isSubscribed) == [true, false])
    }

    @Test("preference sync coalesces identical upload while first matching upload is in flight")
    func preferenceSync_coalescesInFlightIdenticalUpload() async throws {
        let uploader = GateablePreferenceUploader()
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(),
            preferenceUploader: uploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse },
            retryDelaysSeconds: [0]
        )

        let firstTask = Task {
            await pusher.enqueuePreferenceSync(
                source: .settingsPreference,
                requestReason: .preferenceChanged,
                forceUpload: true,
                detail: "notification"
            )
        }
        await uploader.waitForFirstAttempt()
        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )
        await uploader.unblock()
        await firstTask.value

        #expect(await uploader.attemptCount() == 1)
    }

    @Test("snapshot pusher dedupes identical forced uploads inside the dedupe window")
    func snapshotPusher_dedupesIdenticalForcedUploads() async throws {
        let uploader = MockSnapshotUploader()
        let clock = ClockBox(Date(timeIntervalSince1970: 14_000))
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { false },
            authorizationStatusProvider: { .authorizedAlways },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15
        )
        let context = makeContext()

        await pusher.enqueue(context, source: .settingsPreference, reason: .preferenceChanged, forceUpload: true)
        await pusher.enqueue(context, source: .settingsPreference, reason: .preferenceChanged, forceUpload: true)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.count == 1)
    }

    @Test("preference sync dedupes identical successful uploads inside the dedupe window")
    func preferenceSync_dedupesIdenticalSuccessfulUploads() async throws {
        let uploader = MockPreferenceUploader()
        let clock = ClockBox(Date(timeIntervalSince1970: 24_000))
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(),
            preferenceUploader: uploader,
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15
        )

        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )
        await pusher.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: true,
            detail: "notification"
        )

        #expect(await uploader.uploadedPayloads().count == 1)
    }

    @Test("snapshot pusher allows identical upload after dedupe window elapses")
    func snapshotPusher_allowsUploadAfterDedupeWindow() async throws {
        let uploader = MockSnapshotUploader()
        let clock = ClockBox(Date(timeIntervalSince1970: 15_000))
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse },
            nowProvider: { clock.now() },
            retryDelaysSeconds: [0],
            dedupeWindowSeconds: 15
        )
        let context = makeContext()

        await pusher.enqueue(context, source: .foregroundPrime, reason: .locationResolved)
        clock.advance(by: 16)
        await pusher.enqueue(context, source: .foregroundLocationChange, reason: .locationChanged)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.count == 2)
    }

    @Test("snapshot pusher retries with legacy source when server rejects explicit source")
    func snapshotPusher_retriesWithLegacySourceForCompatibility() async throws {
        let uploader = CompatibilitySnapshotUploader(failingStatus: 400)
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse },
            retryDelaysSeconds: [0]
        )

        await pusher.enqueue(makeContext(), source: .foregroundPrime, reason: .locationResolved)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.count == 2)
        #expect(payloads.map(\.source) == [LocationUploadSource.foregroundPrime.rawValue, "unknown"])
    }

    @Test("snapshot pusher does not use legacy fallback for non-compat response statuses")
    func snapshotPusher_doesNotFallbackForNonCompatStatus() async throws {
        let uploader = CompatibilitySnapshotUploader(failingStatus: 409)
        let pusher = LocationSnapshotPusher(
            locationUploader: uploader,
            preferenceUploader: NoOpDevicePreferenceSyncUploader(),
            apnsTokenProvider: { "apns-token-123" },
            installationIdProvider: { "install-abc-123" },
            subscriptionStatusProvider: { true },
            authorizationStatusProvider: { .authorizedWhenInUse },
            retryDelaysSeconds: [0]
        )

        await pusher.enqueue(makeContext(), source: .foregroundPrime, reason: .locationResolved)

        let payloads = await uploader.uploadedPayloads()
        #expect(payloads.count == 1)
        #expect(payloads.first?.source == LocationUploadSource.foregroundPrime.rawValue)
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
        let provider = LocationProvider(
            geocoder: MockGeocoder(mode: .delay(seconds: 10.0, then: .success("Late City")))
        )
        let coord = CLLocationCoordinate2D(latitude: 39.0, longitude: -104.0)

        let snap = await provider.ensurePlacemark(for: coord, timeout: 0.1)
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

    @Test("ensurePlacemark does not rewrite an unchanged snapshot")
    func ensurePlacemark_doesNotRewriteUnchangedSnapshot() async {
        let coord = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let timestamp = Date()
        let snapshot = LocationSnapshot(
            coordinates: coord,
            timestamp: timestamp,
            accuracy: 25,
            placemarkSummary: "Denver, CO",
            h3Cell: sampleH3Cell
        )
        let cache = MockSnapshotCache(storedSnapshot: snapshot)
        let geocoder = CountingGeocoder()
        let provider = LocationProvider(
            geocoder: geocoder,
            hasher: MockHasher(mode: .success(sampleH3Cell)),
            snapshotCache: cache,
            nowProvider: { timestamp }
        )

        let resolved = await provider.ensurePlacemark(for: coord, timeout: 1)

        #expect(resolved == snapshot)
        #expect(cache.saveCount == 0)
        #expect(await geocoder.callCount() == 0)
    }

    @Test("send clears a cached placemark when accepted coordinates change")
    func send_clearsCachedPlacemarkWhenCoordinatesChange() async throws {
        let coordA = CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)
        let coordB = CLLocationCoordinate2D(latitude: 40.0150, longitude: -105.2705)
        let timestamp = Date(timeIntervalSince1970: 3_000)
        let cached = LocationSnapshot(
            coordinates: coordA,
            timestamp: timestamp,
            accuracy: 25,
            placemarkSummary: "A City",
            h3Cell: sampleH3Cell
        )
        let geocoder = CoordinateGateGeocoder()
        let provider = LocationProvider(
            geocoder: geocoder,
            hasher: MockHasher(mode: .success(sampleH3Cell)),
            snapshotCache: MockSnapshotCache(storedSnapshot: cached)
        )

        await provider.send(update: makeUpdate(
            lat: coordB.latitude,
            lon: coordB.longitude,
            timestamp: timestamp.addingTimeInterval(1),
            accuracy: 25,
            forceAcceptance: true
        ))
        await geocoder.waitForFirstCall()

        let accepted = try #require(await provider.snapshot())
        #expect(accepted.coordinates.latitude == coordB.latitude)
        #expect(accepted.coordinates.longitude == coordB.longitude)
        #expect(accepted.placemarkSummary == nil)

        let resolved = await provider.ensurePlacemark(for: coordB, timeout: 1)
        #expect(resolved.placemarkSummary == "B City")
        #expect(await geocoder.callCountValue() == 2)

        await geocoder.releaseFirst()
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

        let afterReady = await waitUntilLocationSnapshot(timeout: .seconds(1)) {
            if let snapshot = await provider.snapshot() {
                snapshot.placemarkSummary == "Denver, CO"
            } else {
                false
            }
        }
        #expect(afterReady == true)
        let after = await provider.snapshot()
        #expect(after?.placemarkSummary == "Denver, CO")
    }

    @Test("updatePlacemarkIfNeeded ignores geocoding failures")
    func updatePlacemark_handlesFailure() async throws {
        let provider = LocationProvider(geocoder: MockGeocoder(mode: .failure(GeocodeError.noResults)))
        let t0 = Date()
        await provider.send(update: makeUpdate(lat: 40.0, lon: -105.0, timestamp: t0, accuracy: 50))

        let snapshotReady = await waitUntilLocationSnapshot(timeout: .seconds(1)) {
            if let snapshot = await provider.snapshot() {
                snapshot.placemarkSummary == nil
            } else {
                false
            }
        }
        #expect(snapshotReady == true)
        let snap = await provider.snapshot()
        #expect(snap?.placemarkSummary == nil)
    }

    @Test("forced update is ignored when it duplicates a recent accepted snapshot")
    func send_skipsRedundantForcedUpdate() async throws {
        let provider = LocationProvider(
            geocoder: MockGeocoder(mode: .failure(GeocodeError.noResults)),
            hasher: MockHasher(mode: .success(sampleH3Cell))
        )
        let t0 = Date(timeIntervalSince1970: 4_000)
        let t1 = t0.addingTimeInterval(1)

        await provider.send(update: makeUpdate(lat: 39.7392, lon: -104.9903, timestamp: t0, accuracy: 25))
        let first = try #require(await provider.snapshot())

        await provider.send(
            update: makeUpdate(
                lat: 39.73925,
                lon: -104.99025,
                timestamp: t1,
                accuracy: 20,
                forceAcceptance: true
            )
        )

        let final = try #require(await provider.snapshot())
        #expect(final == first)
    }

    @Test("late geocode completion does not regress snapshot recency")
    func lateGeocodeCompletion_doesNotRegressSnapshotRecency() async throws {
        let geocoder = RacingGeocoder()
        let provider = LocationProvider(geocoder: geocoder)
        let t0 = Date()
        let t1 = t0.addingTimeInterval(70)

        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: t0, accuracy: 50))

        await provider.send(update: makeUpdate(lat: 39.0, lon: -104.0, timestamp: t1, accuracy: 50))

        let afterSecondReady = await waitUntilLocationSnapshot(timeout: .seconds(1)) {
            if let snapshot = await provider.snapshot() {
                snapshot.timestamp == t1 && snapshot.placemarkSummary == "Latest City"
            } else {
                false
            }
        }
        #expect(afterSecondReady == true)

        let afterSecond = try #require(await provider.snapshot())
        #expect(afterSecond.timestamp == t1)
        #expect(afterSecond.placemarkSummary == "Latest City")

        await geocoder.resolveFirst(with: "Old City")

        let finalReady = await waitUntilLocationSnapshot(timeout: .seconds(1)) {
            if let snapshot = await provider.snapshot() {
                snapshot.timestamp == t1 && snapshot.placemarkSummary == "Latest City"
            } else {
                false
            }
        }
        #expect(finalReady == true)

        let final = try #require(await provider.snapshot())
        #expect(final.timestamp == t1)
        #expect(final.placemarkSummary == "Latest City")
    }
}

private func waitUntilLocationSnapshot(
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

extension LocationProviderTests {
    @Test("nonaccepted v3 presence clears pending work without successful-transfer deduplication",
          arguments: ["accepted", "ignored", "stale"])
    func v3PresenceAcknowledgment(status: String) async throws {
        let http = ConsentHTTP()
        await http.presenceResponse(status)
        let consent = isolatedConsentStore()
        let enrollment = enrolledTestCoordinator()
        let base = URL(string: "https://arcus.example.com")!
        let pending = InMemoryUploadQueueStore()
        let pusher = LocationSnapshotPusher(
            locationUploader: HTTPLocationSnapshotUploader(baseURL: base, http: http, enrollment: enrollment, consent: consent),
            preferenceUploader: HTTPDevicePreferenceSyncUploader(baseURL: base, http: http, enrollment: enrollment, consent: consent),
            apnsTokenProvider: { "" }, installationIdProvider: { "f0465f55-f0a2-48a0-aac0-6a5c48a95891" },
            subscriptionStatusProvider: { true }, mesoNotificationEnabledProvider: { true },
            locationUploadEnabledProvider: { true }, authorizationStatusProvider: { .authorizedWhenInUse },
            retryDelaysSeconds: [0], dedupeWindowSeconds: 60, queueStore: pending
        )
        let context = makeContext()
        await pusher.enqueue(context, source: .manualRefresh, reason: .locationResolved)
        #expect(await pending.current().isEmpty)
        await pusher.enqueue(context, source: .manualRefresh, reason: .locationResolved)
        let presence = await http.recorded().filter { $0.path == "/v3/devices/location-snapshots" }
        #expect(presence.count == (status == "accepted" ? 1 : 2))
        #expect(await pending.current().isEmpty)
    }
}

extension LocationProviderTests {
    @MainActor
    @Test("captured settings intents preserve rapid reversal despite inverted transport callbacks",
          arguments: [true, false])
    func orderedNotificationIntents(finalEnabled: Bool) async throws {
        let suite = "ordered-subscription-intents-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let id = "f0465f55-f0a2-48a0-aac0-6a5c48a95891"
        // Model both defaults writes completing before either async callback can sample
        // the intermediate value. Only the synchronous captures retain intent order.
        let consent = InstallationConsentStore(suiteName: suite, settings: {
            .init(isSubscribed: finalEnabled, mesoNotificationsEnabled: true,
                  locationSharingEnabled: true, locationAuthorization: .always)
        }, markerExists: { false }, createMarker: {})
        #expect(try await consent.current(installationId: id).revision == 1)
        let http = ConsentHTTP()
        let pusher = LocationSnapshotPusher(
            locationUploader: MockSnapshotUploader(),
            preferenceUploader: HTTPDevicePreferenceSyncUploader(baseURL: URL(string: "https://arcus.example.com")!,
                http: http, enrollment: enrolledTestCoordinator(), consent: consent),
            apnsTokenProvider: { "" }, installationIdProvider: { id },
            subscriptionStatusProvider: { finalEnabled }, mesoNotificationEnabledProvider: { true },
            locationUploadEnabledProvider: { true }, authorizationStatusProvider: { .authorizedAlways },
            retryDelaysSeconds: [0], queueStore: InMemoryUploadQueueStore()
        )
        let provider = LocationProvider(snapshotCache: NoOpLocationSnapshotCache())
        let session = LocationSession(locationClient: makeLocationClient(provider: provider),
            locationManager: LocationManager(onUpdate: { _ in }), locationContextResolver: UnavailableContextResolver(),
            locationUploadCoordinator: pusher)
        let older = session.captureNotificationPreferenceChange(enabled: !finalEnabled)
        let newer = session.captureNotificationPreferenceChange(enabled: finalEnabled)
        await session.syncNotificationPreference(after: newer)
        await session.syncNotificationPreference(after: older)
        let current = try await consent.current(installationId: id)
        #expect(current.revision == 3)
        #expect(current.consent.isSubscribed == finalEnabled)
        let sent = try await http.recorded().map { try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: $0.body!) }
        #expect(!sent.isEmpty)
        #expect(sent.allSatisfy { $0.consentRevision == 3 && $0.consent.isSubscribed == finalEnabled })
    }
}

extension LocationProviderTests {
    @Test("v3 consent conflict preserves queued work and blocks ordinary/budgeted replay across reopen",
          arguments: [false, true])
    func consentConflictBlocksAutomaticReplay(bounded: Bool) async throws {
        let suite = "consent-conflict-queue-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let id = "f0465f55-f0a2-48a0-aac0-6a5c48a95891"
        let http = ConsentHTTP()
        await http.reject(409)
        let queue = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        func reopened() -> LocationSnapshotPusher {
            let consent = isolatedConsentStore(suiteName: suite)
            let base = URL(string: "https://arcus.example.com")!
            let enrollment = enrolledTestCoordinator()
            return LocationSnapshotPusher(
                locationUploader: HTTPLocationSnapshotUploader(baseURL: base, http: http, enrollment: enrollment, consent: consent),
                preferenceUploader: HTTPDevicePreferenceSyncUploader(baseURL: base, http: http, enrollment: enrollment, consent: consent),
                apnsTokenProvider: { "" }, installationIdProvider: { id },
                subscriptionStatusProvider: { true }, mesoNotificationEnabledProvider: { true },
                locationUploadEnabledProvider: { true }, authorizationStatusProvider: { .authorizedWhenInUse },
                retryDelaysSeconds: [0, 0, 0], queueStore: queue
            )
        }
        let pusher = reopened()
        await pusher.enqueuePreferenceSync(source: .settingsPreference, requestReason: .preferenceChanged,
                                           forceUpload: true, detail: "initial-consent")
        let original = await queue.loadPendingRequests()
        #expect(original.count == 1)
        for coordinator in [pusher, reopened()] {
            if bounded {
                let outcome = await coordinator.drainPendingUploads(using: .init(uploadQuota: 3, deadline: .now.advanced(by: .seconds(5))))
                #expect(outcome == .remaining)
            } else {
                await coordinator.drainPendingUploads()
            }
            #expect(await queue.loadPendingRequests() == original)
        }
        #expect(await http.recorded().map(\.path) == ["/v3/devices/preferences"])
    }
}
