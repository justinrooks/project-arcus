import ArcusCore
import Foundation
import Synchronization
import Testing
@testable import SkyAware

func isolatedConsentStore(
    suiteName: String = "consent-test-\(UUID())",
    consent: DeviceConsentSnapshotV3 = .init(isSubscribed: true, mesoNotificationsEnabled: true,
        locationSharingEnabled: true, locationAuthorization: .whenInUse)
) -> InstallationConsentStore {
    InstallationConsentStore(suiteName: suiteName, settings: { consent },
                             markerExists: { false }, createMarker: {})
}

@Suite("Installation consent revisions")
struct InstallationConsentTests {
    let id = "f0465f55-f0a2-48a0-aac0-6a5c48a95891"

    @Test("atomic revisions survive restart and change only with the four consent values")
    func revisions() async throws {
        let suite = "consent-revisions-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let settings = Mutex(DeviceConsentSnapshotV3(isSubscribed: true, mesoNotificationsEnabled: true,
            locationSharingEnabled: true, locationAuthorization: .whenInUse))
        let marker = Mutex(false)
        func store() -> InstallationConsentStore {
            InstallationConsentStore(suiteName: suite, settings: { settings.withLock { $0 } },
                markerExists: { marker.withLock { $0 } }, createMarker: { marker.withLock { $0 = true } })
        }
        let first = try await store().current(installationId: id)
        #expect(first.revision == 1)
        #expect(try await store().current(installationId: id) == first)
        let variants: [DeviceConsentSnapshotV3] = [
            .init(isSubscribed: false, mesoNotificationsEnabled: true, locationSharingEnabled: true, locationAuthorization: .whenInUse),
            .init(isSubscribed: false, mesoNotificationsEnabled: false, locationSharingEnabled: true, locationAuthorization: .whenInUse),
            .init(isSubscribed: false, mesoNotificationsEnabled: false, locationSharingEnabled: false, locationAuthorization: .whenInUse),
            .init(isSubscribed: false, mesoNotificationsEnabled: false, locationSharingEnabled: false, locationAuthorization: .denied),
            first.consent
        ]
        for (index, snapshot) in variants.enumerated() {
            settings.withLock { $0 = snapshot }
            let record = try await store().current(installationId: id)
            #expect(record.revision == Int64(index + 2))
            #expect(record.consent == snapshot)
            #expect(try await store().current(installationId: id) == record)
        }
        UserDefaults(suiteName: suite)?.removeObject(forKey: InstallationConsentStore.recordKey)
        await #expect(throws: InstallationConsentStore.Failure.unavailable) {
            try await store().current(installationId: id)
        }
    }

    @Test("corruption, identity mismatch and overflow fail closed", arguments: [0, 1, 2])
    func invalidState(kind: Int) async throws {
        let suite = "consent-invalid-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let snapshot = DeviceConsentSnapshotV3(isSubscribed: false, mesoNotificationsEnabled: true,
            locationSharingEnabled: true, locationAuthorization: .always)
        let record = InstallationConsentStore.Record(installationId: kind == 1 ? UUID().uuidString : id,
            revision: kind == 2 ? .max : 1, consent: snapshot)
        UserDefaults(suiteName: suite)?.set(kind == 0 ? Data([0]) : try JSONEncoder().encode(record),
                                          forKey: InstallationConsentStore.recordKey)
        let store = InstallationConsentStore(suiteName: suite, settings: {
            .init(isSubscribed: true, mesoNotificationsEnabled: true, locationSharingEnabled: true, locationAuthorization: .always)
        }, markerExists: { true }, createMarker: {})
        await #expect(throws: (any Error).self) { try await store.current(installationId: id) }
    }

    @Test("delayed enable cannot lift an opt-out until disabled is observed")
    func restrictiveOverride() async throws {
        let enabled = Mutex(true)
        let store = InstallationConsentStore(suiteName: "consent-restriction-\(UUID())", settings: {
            .init(isSubscribed: enabled.withLock { $0 }, mesoNotificationsEnabled: true,
                  locationSharingEnabled: true, locationAuthorization: .always)
        }, markerExists: { false }, createMarker: {})
        await store.restrictSubscription()
        #expect(try await store.current(installationId: id).consent.isSubscribed == false)
        #expect(try await store.current(installationId: id).revision == 1)
        enabled.withLock { $0 = false }
        #expect(try await store.current(installationId: id).revision == 1)
        enabled.withLock { $0 = true }
        #expect(try await store.current(installationId: id).revision == 2)
    }
}

actor ConsentHTTP: HTTPClient {
    struct Request: Sendable {
        let url: URL
        let headers: [String: String]
        let body: Data?
        var path: String { url.path }
        var method: String { "POST" }
    }
    private var requests: [Request] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var paused = false
    var failNext = false
    var ahead = false
    private var firstOnly = false
    private var rejection: Int?
    private var stale = false
    private var presenceStatus = "accepted"
    private var tokenDeterminesOwnership = false

    func pause() { paused = true }
    func pauseFirst() { paused = true; firstOnly = true }
    func reject(_ status: Int) { rejection = status }
    func reportStale() { stale = true }
    func presenceResponse(_ status: String) { presenceStatus = status }
    func ownershipDependsOnToken() { tokenDeterminesOwnership = true }
    func release() {
        paused = false
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
    func recorded() -> [Request] { requests }
    func failOnce() { failNext = true }
    func reportAhead() { ahead = true }
    func get(_ url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy) async throws -> HTTPResponse {
        throw URLError(.unsupportedURL)
    }
    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse {
        requests.append(Request(url: url, headers: headers, body: body))
        if url.path == ArcusSignalConfiguration.devicePreferencesPath {
            let request = try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: body!)
            if paused && (!firstOnly || requests.count == 1) { await withCheckedContinuation { waiters.append($0) } }
            if let rejection { return HTTPResponse(status: rejection, headers: [:], data: nil) }
            if failNext { failNext = false; throw URLError(.networkConnectionLost) }
            let ack = try DevicePreferencesV3AcceptedResponse(status: stale ? .stale : .accepted,
                acceptedConsentRevision: request.consentRevision + (ahead ? 1 : 0), receivedAt: Date(),
                serverOwnsMesoNotificationDelivery: request.consent.isSubscribed && (!tokenDeterminesOwnership || request.apnsDeviceToken != nil))
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return HTTPResponse(status: 200, headers: [:], data: try encoder.encode(ack))
        }
        if url.path == ArcusSignalConfiguration.locationSnapshotsPath {
            return HTTPResponse(status: 200, headers: [:], data: Data("{\"status\":\"\(presenceStatus)\",\"receivedAt\":\"2026-10-29T00:00:00Z\"}".utf8))
        }
        return HTTPResponse(status: 204, headers: [:], data: nil)
    }
    nonisolated func clearCache() {}
}

extension InstallationConsentTests {
    @Test("lost consent response and token rotation reuse the durable snapshot and revision")
    func lostResponseAndTokenRotation() async throws {
        let store = isolatedConsentStore()
        let http = ConsentHTTP()
        await http.failOnce()
        let base = URL(string: "https://arcus.example.com")!
        await #expect(throws: URLError.self) {
            try await store.synchronize(installationId: id, baseURL: base, http: http, credential: "test", token: "old")
        }
        try await store.synchronize(installationId: id, baseURL: base, http: http, credential: "test", token: "new")
        try await store.synchronize(installationId: id, baseURL: base, http: http, credential: "test", token: "")
        let requests = try await http.recorded().map { try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: $0.body!) }
        #expect(requests.map(\.consentRevision) == [1, 1, 1])
        #expect(requests.map(\.apnsDeviceToken) == ["old", "new", nil])
        #expect(requests.allSatisfy { $0.consent == requests[0].consent })
    }

    @Test("server-ahead revision fails without counter invention or downgrade")
    func serverAhead() async throws {
        let store = isolatedConsentStore()
        let http = ConsentHTTP()
        await http.reportAhead()
        await #expect(throws: InstallationConsentStore.Failure.inconsistentAcknowledgment) {
            try await store.synchronize(installationId: id, baseURL: URL(string: "https://arcus.example.com")!,
                                        http: http, credential: "test")
        }
        #expect(try await store.current(installationId: id).revision == 1)
        #expect(await http.recorded().map(\.path) == ["/v3/devices/preferences"])
    }

    @Test("concurrent activity and location wait for accepted consent and location stays presence-only")
    func concurrentAdmission() async throws {
        let store = isolatedConsentStore()
        let http = ConsentHTTP()
        await http.pause()
        let base = URL(string: "https://arcus.example.com")!
        let activity = HTTPForegroundActivityUploader(baseURL: base, http: http,
            enrollment: enrolledTestCoordinator(), consent: store)
        let location = HTTPLocationSnapshotUploader(baseURL: base, http: http,
            enrollment: enrolledTestCoordinator(), consent: store)
        let activityTask = Task { try await activity.upload(installationId: id) }
        let locationTask = Task {
            try await location.upload(LocationSnapshotPushPayload(
                capturedAt: Date(), locationAgeSeconds: 0, horizontalAccuracyMeters: 5, cellScheme: "h3",
                h3Cell: nil, h3Resolution: 8, county: "COC001", zone: nil, fireZone: nil,
                apnsDeviceToken: "", installationId: id, source: "foregroundLocationChange", auth: "always",
                appVersion: "1", buildNumber: "1", platform: "iOS", osVersion: "26", apnsEnvironment: "sandbox",
                countyLabel: nil, fireZoneLabel: nil, isSubscribed: true))
        }
        while await http.recorded().count < 2 { await Task.yield() }
        #expect(await http.recorded().allSatisfy { $0.path == "/v3/devices/preferences" })
        await http.release()
        try await activityTask.value
        try await locationTask.value
        let requests = await http.recorded()
        #expect(requests.count == 4)
        let presence = try #require(requests.first { $0.path == "/v3/devices/location-snapshots" })
        let json = try #require(try JSONSerialization.jsonObject(with: presence.body!) as? [String: Any])
        for key in ["consent", "consentRevision", "auth", "isSubscribed", "apnsDeviceToken", "apnsEnvironment", "osVersion"] {
            #expect(json[key] == nil)
        }
        #expect(json["cellScheme"] as? String == "ugc-only")
        #expect(json["h3Resolution"] == nil)
    }
}


extension InstallationConsentTests {
    @Test("delayed old opt-in acknowledgment cannot restore ownership after a newer opt-out")
    func oldAcknowledgment() async throws {
        let suite = "consent-ack-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let enabled = Mutex(true)
        let store = InstallationConsentStore(suiteName: suite, settings: {
            .init(isSubscribed: enabled.withLock { $0 }, mesoNotificationsEnabled: true,
                  locationSharingEnabled: true, locationAuthorization: .always)
        }, markerExists: { false }, createMarker: {})
        let http = ConsentHTTP()
        await http.pauseFirst()
        let base = URL(string: "https://arcus.example.com")!
        let old = Task { try await store.synchronize(installationId: id, baseURL: base, http: http, credential: "test") }
        while await http.recorded().isEmpty { await Task.yield() }
        enabled.withLock { $0 = false }
        try await store.synchronize(installationId: id, baseURL: base, http: http, credential: "test")
        #expect(UserDefaults(suiteName: suite)?.bool(forKey: HTTPDevicePreferenceSyncUploader.ownershipDefaultsKey) == false)
        await http.release()
        try await old.value
        #expect(UserDefaults(suiteName: suite)?.bool(forKey: HTTPDevicePreferenceSyncUploader.ownershipDefaultsKey) == false)
        let sent = try await http.recorded().map { try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: $0.body!) }
        #expect(sent.map(\.consentRevision) == [1, 2, 2])
        #expect(sent.map { $0.consent.isSubscribed } == [true, false, false])
    }

    @Test("stale acknowledgments and authorization/conflict failures never admit or downgrade", arguments: [200, 401, 409])
    func rejectedAdmission(status: Int) async throws {
        let store = isolatedConsentStore()
        let http = ConsentHTTP()
        if status == 200 { await http.reportStale() } else { await http.reject(status) }
        let uploader = HTTPForegroundActivityUploader(baseURL: URL(string: "https://arcus.example.com")!,
            http: http, enrollment: enrolledTestCoordinator(), consent: store)
        await #expect(throws: (any Error).self) { try await uploader.upload(installationId: id) }
        #expect(await http.recorded().map(\.path) == ["/v3/devices/preferences"])
    }
}

extension InstallationConsentTests {
    @Test("failed flush cannot be bypassed by an unchanged cached revision")
    func failedFlush() async throws {
        let suite = "consent-flush-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let succeeds = Mutex(false)
        let store = InstallationConsentStore(suiteName: suite, settings: {
            .init(isSubscribed: false, mesoNotificationsEnabled: false, locationSharingEnabled: false, locationAuthorization: .denied)
        }, markerExists: { false }, createMarker: {}, flush: { succeeds.withLock { $0 } })
        for _ in 0..<2 {
            await #expect(throws: InstallationConsentStore.Failure.unavailable) {
                try await store.current(installationId: id)
            }
        }
        succeeds.withLock { $0 = true }
        #expect(try await store.current(installationId: id).revision == 1)
    }

    @Test("admission rechecks the caller budget before a changed-revision followup")
    func admissionRechecksBudget() async throws {
        let suite = "consent-budget-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let allowed = Mutex(true)
        let enabled = Mutex(true)
        let store = InstallationConsentStore(suiteName: suite, settings: {
            .init(isSubscribed: enabled.withLock { $0 }, mesoNotificationsEnabled: true,
                  locationSharingEnabled: true, locationAuthorization: .always)
        }, markerExists: { false }, createMarker: {})
        let http = ConsentHTTP()
        await http.pauseFirst()
        let task = Task {
            try await store.synchronize(installationId: id, baseURL: URL(string: "https://arcus.example.com")!,
                http: http, credential: "test", checking: {
                    if !allowed.withLock({ $0 }) { throw CancellationError() }
                    return nil
                })
        }
        while await http.recorded().isEmpty { await Task.yield() }
        allowed.withLock { $0 = false }
        enabled.withLock { $0 = false }
        await http.release()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await http.recorded().count == 1)
    }

    @Test("revocation during initial v3 admission suppresses location handoff")
    func revokeDuringAdmission() async throws {
        let http = ConsentHTTP()
        await http.pauseFirst()
        let sharing = Mutex(true)
        let location = HTTPLocationSnapshotUploader(baseURL: URL(string: "https://arcus.example.com")!,
            http: http, enrollment: enrolledTestCoordinator(), consent: isolatedConsentStore())
        let task = Task {
            try await location.upload(installationId: id) {
                // No payload need be produced after revocation: this is the queue's final boundary.
                if !sharing.withLock({ $0 }) { throw CancellationError() }
                return LocationSnapshotPushPayload(
                    capturedAt: Date(), locationAgeSeconds: 0, horizontalAccuracyMeters: 5, cellScheme: "ugc-only",
                    h3Cell: nil, h3Resolution: nil, county: nil, zone: nil, fireZone: nil,
                    apnsDeviceToken: "", installationId: id, source: "unknown", auth: "always",
                    appVersion: "1", buildNumber: "1", platform: "iOS", osVersion: "26", apnsEnvironment: "sandbox",
                    countyLabel: nil, fireZoneLabel: nil, isSubscribed: true)
            }
        }
        while await http.recorded().isEmpty { await Task.yield() }
        sharing.withLock { $0 = false }
        await http.release()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await http.recorded().map(\.path) == ["/v3/devices/preferences"])
    }
}

extension InstallationConsentTests {
    @Test("each preparation supplies the actual token for that consent transfer")
    func preparedTokenMatchesTransfer() async throws {
        let store = isolatedConsentStore()
        let http = ConsentHTTP()
        let token = Mutex("B")
        try await store.synchronize(installationId: id, baseURL: URL(string: "https://arcus.example.com")!,
            http: http, credential: "test", token: "A", checking: { token.withLock { $0 } })
        let request = try #require(await http.recorded().first)
        let payload = try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: request.body!)
        #expect(payload.apnsDeviceToken == "B")
        #expect(payload.consentRevision == 1)
    }
}

extension InstallationConsentTests {
    @Test("revocation during consent admission sends higher-revision opt-out before suppressing presence")
    func revokedConsentStillSynchronizes() async throws {
        let suite = "consent-revoked-admission-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let sharing = Mutex(true)
        let store = InstallationConsentStore(suiteName: suite, settings: {
            .init(isSubscribed: true, mesoNotificationsEnabled: true,
                  locationSharingEnabled: sharing.withLock { $0 }, locationAuthorization: .always)
        }, markerExists: { false }, createMarker: {})
        let http = ConsentHTTP()
        await http.pauseFirst()
        let uploader = HTTPLocationSnapshotUploader(baseURL: URL(string: "https://arcus.example.com")!,
            http: http, enrollment: enrolledTestCoordinator(), consent: store)
        let task = Task {
            try await uploader.upload(installationId: id, checking: { try Task.checkCancellation() }) {
                Issue.record("Revoked presence must never be prepared for transmission")
                throw CancellationError()
            }
        }
        while await http.recorded().isEmpty { await Task.yield() }
        sharing.withLock { $0 = false }
        await http.release()
        await #expect(throws: LocationPushError.self) { try await task.value }
        let requests = await http.recorded()
        #expect(requests.map(\.path) == ["/v3/devices/preferences", "/v3/devices/preferences"])
        let payloads = try requests.map { try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: $0.body!) }
        #expect(payloads.map(\.consentRevision) == [1, 2])
        #expect(payloads.map { $0.consent.locationSharingEnabled } == [true, false])
    }

    @Test("earlier same-revision tokenless ownership cannot overwrite a newer bound acknowledgment")
    func sameRevisionOwnershipOrder() async throws {
        let suite = "consent-binding-ack-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = isolatedConsentStore(suiteName: suite)
        let http = ConsentHTTP()
        await http.pauseFirst()
        await http.ownershipDependsOnToken()
        let base = URL(string: "https://arcus.example.com")!
        let old = Task {
            try await store.synchronize(installationId: id, baseURL: base, http: http, credential: "test", token: "")
        }
        while await http.recorded().isEmpty { await Task.yield() }
        try await store.synchronize(installationId: id, baseURL: base, http: http, credential: "test", token: "bound")
        #expect(UserDefaults(suiteName: suite)?.bool(forKey: HTTPDevicePreferenceSyncUploader.ownershipDefaultsKey) == true)
        await http.release()
        try await old.value
        #expect(UserDefaults(suiteName: suite)?.bool(forKey: HTTPDevicePreferenceSyncUploader.ownershipDefaultsKey) == true)
        let requests = try await http.recorded().map { try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: $0.body!) }
        #expect(requests.map(\.consentRevision) == [1, 1])
        #expect(requests.map(\.apnsDeviceToken) == [nil, "bound"])
    }
}

extension InstallationConsentTests {
    @Test("consent conflict persists explicit-recovery state without advancing or resetting the revision")
    func conflictPersistsUntilRecovery() async throws {
        let suite = "consent-terminal-conflict-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let http = ConsentHTTP()
        await http.reject(409)
        let store = isolatedConsentStore(suiteName: suite)
        await #expect(throws: InstallationConsentStore.Failure.consentConflictRequiresRecovery) {
            try await store.synchronize(installationId: id, baseURL: URL(string: "https://arcus.example.com")!,
                                        http: http, credential: "test")
        }
        let data = try #require(UserDefaults(suiteName: suite)?.data(forKey: InstallationConsentStore.recordKey))
        let record = try JSONDecoder().decode(InstallationConsentStore.Record.self, from: data)
        #expect(record.revision == 1)
        #expect(record.conflictRequiresRecovery == true)
        let reopened = isolatedConsentStore(suiteName: suite, consent: .init(isSubscribed: false,
            mesoNotificationsEnabled: false, locationSharingEnabled: false, locationAuthorization: .denied))
        for consent in [store, reopened] {
            await #expect(throws: InstallationConsentStore.Failure.consentConflictRequiresRecovery) {
                try await consent.acceptSubscriptionIntent(installationId: id, enabled: false)
            }
            await #expect(throws: InstallationConsentStore.Failure.consentConflictRequiresRecovery) {
                try await consent.synchronize(installationId: id, baseURL: URL(string: "https://arcus.example.com")!,
                                            http: http, credential: "test")
            }
        }
        #expect(await http.recorded().count == 1)
        #expect(UserDefaults(suiteName: suite)?.data(forKey: InstallationConsentStore.recordKey) == data)
    }

    @Test("conflict persistence failure still blocks further in-process handoffs")
    func conflictFlushFailure() async throws {
        let suite = "consent-conflict-flush-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let flushSucceeds = Mutex(true)
        let store = InstallationConsentStore(suiteName: suite, settings: {
            .init(isSubscribed: true, mesoNotificationsEnabled: true, locationSharingEnabled: true, locationAuthorization: .always)
        }, markerExists: { false }, createMarker: {}, flush: { flushSucceeds.withLock { $0 } })
        _ = try await store.current(installationId: id)
        let http = ConsentHTTP()
        await http.pauseFirst()
        await http.reject(409)
        let first = Task {
            try await store.synchronize(installationId: id, baseURL: URL(string: "https://arcus.example.com")!,
                                        http: http, credential: "test")
        }
        while await http.recorded().isEmpty { await Task.yield() }
        flushSucceeds.withLock { $0 = false }
        await http.release()
        await #expect(throws: InstallationConsentStore.Failure.unavailable) { try await first.value }
        await #expect(throws: InstallationConsentStore.Failure.consentConflictRequiresRecovery) {
            try await store.synchronize(installationId: id, baseURL: URL(string: "https://arcus.example.com")!,
                                        http: http, credential: "test")
        }
        #expect(await http.recorded().count == 1)
    }
}
