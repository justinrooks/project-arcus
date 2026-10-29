import ArcusCore
import CoreLocation
import Foundation
import Security
import Synchronization
import Testing
@testable import SkyAware

// MARK: - Installation enrollment and authenticated device writes

func enrolledTestCoordinator() -> InstallationEnrollmentCoordinator {
    InstallationEnrollmentCoordinator(
        installationId: { enrollmentTestID },
        read: { .init(installationId: enrollmentTestID, credential: enrollmentTestSecret,
                      enrolledOrigin: "https://arcus.example.com:443") },
        write: { _ in }, generate: { enrollmentTestSecret }
    )
}

private let enrollmentTestID = "f0465f55-f0a2-48a0-aac0-6a5c48a95891"
private let enrollmentTestSecret = String(repeating: "A", count: 43)

private final class EnrollmentMemoryStore: Sendable {
    let record = Mutex<InstallationEnrollmentCoordinator.Record?>(nil)
    let failWrites = Mutex(false)

    func coordinator(enrollmentWaiterDidJoin: @escaping @Sendable () -> Void = {}) -> InstallationEnrollmentCoordinator {
        InstallationEnrollmentCoordinator(
            installationId: { enrollmentTestID },
            read: { self.record.withLock { $0 } },
            write: { value in
                if self.failWrites.withLock({ $0 }) { throw InstallationEnrollmentError.persistenceUnavailable }
                self.record.withLock { $0 = value }
            },
            generate: { enrollmentTestSecret },
            enrollmentWaiterDidJoin: enrollmentWaiterDidJoin
        )
    }
}

private func enrollmentPayload(_ request: EnrollmentHTTPState.Request) throws -> InstallationEnrollmentRequest {
    let body = try #require(request.body)
    return try JSONDecoder().decode(InstallationEnrollmentRequest.self, from: body)
}

private actor EnrollmentHTTPState {
    struct Request: Sendable {
        let url: URL
        let headers: [String: String]
        let body: Data?
    }
    var requests: [Request] = []
    var responses: [Int]
    let acknowledgment: Data?
    init(_ responses: [Int], acknowledgment: Data?) {
        self.responses = responses
        self.acknowledgment = acknowledgment
    }
    func post(_ url: URL, headers: [String: String], body: Data?) throws -> HTTPResponse {
        requests.append(Request(url: url, headers: headers, body: body))
        if url.path == "/v3/devices/preferences" {
            let payload = try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: body!)
            let ack = try DevicePreferencesV3AcceptedResponse(status: .accepted,
                acceptedConsentRevision: payload.consentRevision, receivedAt: Date(),
                serverOwnsMesoNotificationDelivery: false)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return HTTPResponse(status: 200, headers: [:], data: try encoder.encode(ack))
        }
        let status = responses.removeFirst()
        if status == -1 { throw URLError(.networkConnectionLost) }
        if url.path == "/v3/devices/location-snapshots", (200...299).contains(status) {
            return HTTPResponse(status: 200, headers: [:], data: Data("{\"status\":\"accepted\",\"receivedAt\":\"2026-10-29T00:00:00Z\"}".utf8))
        }
        return HTTPResponse(status: url.path == "/v3/devices/foreground-activity" && status == 202 ? 204 : status,
                            headers: [:], data: acknowledgment)
    }
    func allRequests() -> [Request] { requests }
}

private final class EnrollmentHTTPClient: HTTPClient, Sendable {
    let state: EnrollmentHTTPState
    let beforePost: @Sendable () async throws -> Void
    init(_ responses: [Int], acknowledgment: Data? = Data("{\"status\":\"accepted\"}".utf8),
         beforePost: @escaping @Sendable () async throws -> Void = {}) {
        state = EnrollmentHTTPState(responses, acknowledgment: acknowledgment)
        self.beforePost = beforePost
    }
    func get(_ url: URL, headers: [String: String], fallbackPolicy: HTTPFallbackPolicy) async throws -> HTTPResponse {
        throw URLError(.unsupportedURL)
    }
    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> HTTPResponse {
        try await beforePost()
        return try await state.post(url, headers: headers, body: body)
    }
    func clearCache() {}
}

@Suite("Installation enrollment")
struct InstallationEnrollmentTests {
    let baseURL = URL(string: "https://arcus.example.com")!

    @Test("privacy preparation runs after enrollment and can suppress protected handoff", arguments: [false, true])
    func privacyAfterEnrollment(preferences: Bool) async throws {
        let store = EnrollmentMemoryStore()
        let revoked = Mutex(false)
        let http = EnrollmentHTTPClient([200], beforePost: {
            revoked.withLock { $0 = true }
        })
        let coordinator = store.coordinator()
        await #expect(throws: CancellationError.self) {
            if preferences {
                let uploader = HTTPDevicePreferenceSyncUploader(baseURL: baseURL, http: http, enrollment: coordinator,
                    consent: isolatedConsentStore())
                try await uploader.upload(installationId: enrollmentTestID) {
                    #expect(revoked.withLock { $0 })
                    #expect(store.record.withLock { $0?.enrolledOrigin } != nil)
                    throw CancellationError()
                }
            } else {
                let uploader = HTTPLocationSnapshotUploader(baseURL: baseURL, http: http, enrollment: coordinator, consent: isolatedConsentStore())
                try await uploader.upload(installationId: enrollmentTestID) {
                    #expect(revoked.withLock { $0 })
                    #expect(store.record.withLock { $0?.enrolledOrigin } != nil)
                    throw CancellationError()
                }
            }
        }
        #expect(await http.state.allRequests().map(\.url.path) == ["/v2/devices/enroll"])
    }

    @Test("fresh and legacy installations persist before enrollment and enroll without APNs")
    func persistBeforeEnroll() async throws {
        let store = EnrollmentMemoryStore()
        let http = EnrollmentHTTPClient([200], beforePost: {
            #expect(store.record.withLock { $0?.credential } == enrollmentTestSecret)
            #expect(store.record.withLock { $0?.enrolledOrigin } == nil)
        })
        let coordinator = store.coordinator()
        let secret = try await coordinator.credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        #expect(secret == enrollmentTestSecret)
        #expect(store.record.withLock { $0?.enrolledOrigin } == "https://arcus.example.com:443")
        let request = try #require(await http.state.allRequests().first)
        let body = try #require(request.body)
        #expect(try JSONDecoder().decode(InstallationEnrollmentRequest.self, from: body) ==
                InstallationEnrollmentRequest(installationId: enrollmentTestID, credential: enrollmentTestSecret))
        #expect(request.headers["Authorization"] == nil)
        #expect(request.url.path == "/v2/devices/enroll")
    }

    @Test("lost acknowledgment retries the same persisted credential after restart")
    func lostResponse() async throws {
        let store = EnrollmentMemoryStore()
        let http = EnrollmentHTTPClient([-1, 200])
        await #expect(throws: URLError.self) {
            try await store.coordinator().credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        }
        #expect(store.record.withLock { $0?.credential } == enrollmentTestSecret)
        #expect(store.record.withLock { $0?.enrolledOrigin } == nil)
        _ = try await store.coordinator().credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        let requests = await http.state.allRequests()
        #expect(requests.count == 2)
        #expect(try enrollmentPayload(requests[0]) == enrollmentPayload(requests[1]))
    }

    @Test("normal reactivation and restart perform no enrollment validation call")
    func enrolledRestart() async throws {
        let store = EnrollmentMemoryStore()
        let http = EnrollmentHTTPClient([200, 202, 202])
        for _ in 0..<2 {
            let uploader = HTTPForegroundActivityUploader(baseURL: baseURL, http: http, enrollment: store.coordinator(), consent: isolatedConsentStore())
            try await uploader.upload(installationId: enrollmentTestID)
        }
        let requests = await http.state.allRequests()
        #expect(requests.map(\.url.path) == ["/v2/devices/enroll", "/v3/devices/preferences", "/v3/devices/foreground-activity", "/v3/devices/preferences", "/v3/devices/foreground-activity"])
        #expect(requests.dropFirst().allSatisfy { $0.headers["Authorization"] == "Bearer \(enrollmentTestSecret)" })
    }

    @Test("failed persistence prevents network enrollment")
    func persistenceFailure() async {
        let store = EnrollmentMemoryStore()
        store.failWrites.withLock { $0 = true }
        let http = EnrollmentHTTPClient([])
        await #expect(throws: InstallationEnrollmentError.persistenceUnavailable) {
            try await store.coordinator().credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        }
        #expect(await http.state.allRequests().isEmpty)
    }

    @Test("conflicting claims and invalid proof never fall back or replace the credential", arguments: [409, 401])
    func rejected(status: Int) async {
        let store = EnrollmentMemoryStore()
        let http = EnrollmentHTTPClient([status])
        await #expect(throws: InstallationEnrollmentError.rejected(status)) {
            try await store.coordinator().credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        }
        #expect(store.record.withLock { $0?.credential } == enrollmentTestSecret)
        #expect(await http.state.allRequests().map(\.url.path) == ["/v2/devices/enroll"])
    }

    @Test("queued uploads from another identity fail without sending or claiming it")
    func mismatchedQueueIdentity() async {
        let store = EnrollmentMemoryStore()
        let http = EnrollmentHTTPClient([])
        await #expect(throws: InstallationEnrollmentError.invalidIdentity) {
            try await store.coordinator().credential(for: UUID().uuidString, baseURL: baseURL, http: http)
        }
        #expect(await http.state.allRequests().isEmpty)
    }

    @Test("concurrent callers share enrollment")
    func concurrentEnrollment() async throws {
        let store = EnrollmentMemoryStore()
        let coordinator = store.coordinator()
        let http = EnrollmentHTTPClient([200])
        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask { try await coordinator.credential(for: enrollmentTestID, baseURL: baseURL, http: http) }
            }
            for try await secret in group { #expect(secret == enrollmentTestSecret) }
        }
        #expect(await http.state.allRequests().count == 1)
    }
    @Test("location and preference writes share v2 authority without body credentials")
    func allDeviceWrites() async throws {
        let store = EnrollmentMemoryStore()
        let coordinator = store.coordinator()
        let http = EnrollmentHTTPClient([200, 202, 202])
        let location = HTTPLocationSnapshotUploader(baseURL: baseURL, http: http, enrollment: coordinator, consent: isolatedConsentStore())
        let suite = "enrollment-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let preferences = HTTPDevicePreferenceSyncUploader(baseURL: baseURL, http: http,
                                                          enrollment: coordinator, consent: isolatedConsentStore())
        try await location.upload(LocationSnapshotPushPayload(
            capturedAt: Date(timeIntervalSince1970: 1), locationAgeSeconds: 0, horizontalAccuracyMeters: 10,
            cellScheme: "h3", h3Cell: nil, h3Resolution: nil, county: nil, zone: nil, fireZone: nil,
            apnsDeviceToken: "test-token", installationId: enrollmentTestID, source: "unknown", auth: "always",
            appVersion: "1", buildNumber: "1", platform: "iOS", osVersion: "26", apnsEnvironment: "sandbox",
            countyLabel: nil, fireZoneLabel: nil, isSubscribed: true
        ))
        try await preferences.upload(DevicePreferenceSyncPayload(
            installationId: enrollmentTestID, apnsDeviceToken: "test-token", apnsEnvironment: "sandbox",
            platform: "iOS", osVersion: "26", appVersion: "1", buildNumber: "1", auth: "denied",
            isSubscribed: false, source: "unknown", reason: "opt-out", mesoNotificationsEnabled: false
        ))
        let requests = await http.state.allRequests()
        #expect(requests.map(\.url.path) == ["/v2/devices/enroll", "/v3/devices/preferences", "/v3/devices/location-snapshots", "/v3/devices/preferences"])
        for request in requests.dropFirst() {
            #expect(request.headers["Authorization"] == "Bearer \(enrollmentTestSecret)")
            let body = try #require(request.body)
            let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["credential"] == nil)
        }
        let last = try #require(requests.last?.body)
        let payload = try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: last)
        #expect(payload.consent.isSubscribed == true)
        #expect(payload.consent.mesoNotificationsEnabled == true)
    }

    @Test("invalid protected-write proof fails without reenrollment or v1 fallback")
    func invalidWriteProof() async {
        let http = EnrollmentHTTPClient([401, 401])
        let uploader = HTTPForegroundActivityUploader(baseURL: baseURL, http: http, enrollment: enrolledTestCoordinator(), consent: isolatedConsentStore())
        for _ in 0..<2 {
            await #expect(throws: ForegroundActivityError.invalidResponseStatus(401)) {
                try await uploader.upload(installationId: enrollmentTestID)
            }
        }
        #expect(await http.state.allRequests().map(\.url.path) == ["/v3/devices/preferences", "/v3/devices/foreground-activity", "/v3/devices/preferences", "/v3/devices/foreground-activity"])
    }

    @Test("enrollment only accepts the exact success response", arguments: [201, 202, 400])
    func invalidStatus(status: Int) async {
        let store = EnrollmentMemoryStore()
        let http = EnrollmentHTTPClient([status])
        await #expect(throws: InstallationEnrollmentError.rejected(status)) {
            try await store.coordinator().credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        }
        #expect(store.record.withLock { $0?.enrolledOrigin } == nil)
    }

    @Test("insecure endpoints and changed origins do not receive credentials")
    func endpointIsolation() async throws {
        let http = EnrollmentHTTPClient([])
        let coordinator = enrolledTestCoordinator()
        await #expect(throws: InstallationEnrollmentError.insecureEndpoint) {
            try await coordinator.credential(for: enrollmentTestID, baseURL: URL(string: "http://arcus.example.com")!, http: http)
        }
        await #expect(throws: InstallationEnrollmentError.invalidIdentity) {
            try await coordinator.credential(for: enrollmentTestID, baseURL: URL(string: "https://other.example.com")!, http: http)
        }
        #expect(await http.state.allRequests().isEmpty)
    }

}

private actor EnrollmentGate {
    var started = false
    var release: CheckedContinuation<Void, Never>?
    func pause() async {
        started = true
        await withCheckedContinuation { release = $0 }
    }
    func hasStarted() -> Bool { started }
    func open() { release?.resume(); release = nil }
}

extension InstallationEnrollmentTests {
    @Test("missing malformed and nonaccepted acknowledgments retain pending enrollment",
          arguments: [Data(), Data("{}".utf8), Data("{\"status\":\"no\"}".utf8)])
    func malformedAcknowledgment(data: Data) async {
        let store = EnrollmentMemoryStore()
        let http = EnrollmentHTTPClient([200], acknowledgment: data)
        await #expect(throws: InstallationEnrollmentError.invalidAcknowledgment) {
            try await store.coordinator().credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        }
        #expect(store.record.withLock { $0?.enrolledOrigin } == nil)
    }

    @Test("failed acknowledgment persistence retries the same claim")
    func acknowledgmentPersistenceFailure() async throws {
        let store = EnrollmentMemoryStore()
        let failAcknowledgment = Mutex(true)
        func coordinator() -> InstallationEnrollmentCoordinator {
            InstallationEnrollmentCoordinator(
                installationId: { enrollmentTestID }, read: { store.record.withLock { $0 } },
                write: { record in
                    if record.enrolledOrigin != nil && failAcknowledgment.withLock({ $0 }) {
                        throw InstallationEnrollmentError.persistenceUnavailable
                    }
                    store.record.withLock { $0 = record }
                }, generate: { enrollmentTestSecret }
            )
        }
        let http = EnrollmentHTTPClient([200, 200])
        await #expect(throws: InstallationEnrollmentError.persistenceUnavailable) {
            try await coordinator().credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        }
        #expect(store.record.withLock { $0?.enrolledOrigin } == nil)
        failAcknowledgment.withLock { $0 = false }
        _ = try await coordinator().credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        let requests = await http.state.allRequests()
        #expect(try enrollmentPayload(requests[0]) == enrollmentPayload(requests[1]))
    }

    @Test("canceled and overlapping writers share the pending claim until unwind")
    func canceledWaiterDoesNotReleaseClaim() async throws {
        let store = EnrollmentMemoryStore()
        let gate = EnrollmentGate()
        let http = EnrollmentHTTPClient([200, 202], beforePost: {
            if store.record.withLock({ $0?.enrolledOrigin }) == nil { await gate.pause() }
        })
        let joined = Mutex(false)
        let coordinator = store.coordinator(enrollmentWaiterDidJoin: { joined.withLock { $0 = true } })
        let uploader = HTTPForegroundActivityUploader(baseURL: baseURL, http: http, enrollment: coordinator, consent: isolatedConsentStore())
        let canceled = Task { try await uploader.upload(installationId: enrollmentTestID) }
        while await !gate.hasStarted() { await Task.yield() }
        canceled.cancel()
        let survivor = Task { try await uploader.upload(installationId: enrollmentTestID) }
        while !joined.withLock({ $0 }) { await Task.yield() }
        #expect(store.record.withLock { $0?.enrolledOrigin } == nil)
        await gate.open()
        await #expect(throws: CancellationError.self) { try await canceled.value }
        try await survivor.value
        #expect(await http.state.allRequests().map(\.url.path) == ["/v2/devices/enroll", "/v3/devices/preferences", "/v3/devices/foreground-activity"])
    }

    @Test("reopened queues retain work across enrollment failure and remove only authenticated success",
          arguments: [false, true])
    func reopenedQueue(mismatchedIdentity: Bool) async throws {
        let suite = "enrollment-queue-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let queue = UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
        let request = PersistedLocationUploadRequest(
            source: .settingsPreference, reason: .preferenceChanged, forceUpload: true,
            installationId: mismatchedIdentity ? UUID().uuidString : enrollmentTestID,
            requestedAt: Date(timeIntervalSince1970: 1000), isSubscribed: true, authorizationState: "always",
            apnsToken: "token", operation: .preferenceSync, mesoNotificationsEnabled: true
        )
        await queue.savePendingRequests([request])
        let store = EnrollmentMemoryStore()
        let http = EnrollmentHTTPClient(mismatchedIdentity ? [] : [-1, 200, 202])
        func reopened() -> LocationSnapshotPusher {
            let consent = isolatedConsentStore(suiteName: suite, consent: .init(isSubscribed: false,
                mesoNotificationsEnabled: false, locationSharingEnabled: false, locationAuthorization: .denied))
            return LocationSnapshotPusher(
                locationUploader: HTTPLocationSnapshotUploader(baseURL: baseURL, http: http, enrollment: store.coordinator(), consent: consent),
                preferenceUploader: HTTPDevicePreferenceSyncUploader(baseURL: baseURL, http: http,
                    enrollment: store.coordinator(), consent: consent),
                apnsTokenProvider: { "token" }, installationIdProvider: { enrollmentTestID },
                subscriptionStatusProvider: { false }, mesoNotificationEnabledProvider: { false },
                authorizationStatusProvider: { .denied }, retryDelaysSeconds: [0],
                queueStore: UserDefaultsLocationUploadQueueStore(suiteName: suite, key: "pending")
            )
        }
        await reopened().drainPendingUploads()
        #expect(await queue.loadPendingRequests() == [request])
        await reopened().drainPendingUploads()
        if mismatchedIdentity {
            #expect(await queue.loadPendingRequests() == [request])
            #expect(await http.state.allRequests().isEmpty)
        } else {
            #expect(await queue.loadPendingRequests().isEmpty)
            let requests = await http.state.allRequests()
            #expect(requests.map(\.url.path) == ["/v2/devices/enroll", "/v2/devices/enroll", "/v3/devices/preferences"])
            #expect(try enrollmentPayload(requests[0]) == enrollmentPayload(requests[1]))
            #expect(requests[2].headers["Authorization"] == "Bearer \(enrollmentTestSecret)")
            let sent = try JSONDecoder().decode(DevicePreferencesV3Payload.self, from: requests[2].body!)
            #expect(sent.consentRevision == 1)
            #expect(!sent.consent.isSubscribed && !sent.consent.mesoNotificationsEnabled && !sent.consent.locationSharingEnabled)
            #expect(sent.consent.locationAuthorization == .denied)
        }
    }

    @Test("Keychain record reopen, credential loss and corruption fail closed", arguments: [false, true])
    func keychainCredentialLoss(corrupt: Bool) async throws {
        let service = "enrollment-keychain-test-\(UUID())"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        defer { SecItemDelete(query as CFDictionary) }
        #expect(try InstallationCredentialKeychain.read(service: service) == nil)
        let secret = try InstallationCredentialKeychain.generate()
        let decoded = Data(base64Encoded: secret.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/") + "=")
        #expect(decoded?.count == 32)
        #expect(secret.count == 43)
        let record = InstallationEnrollmentCoordinator.Record(installationId: enrollmentTestID, credential: secret)
        try InstallationCredentialKeychain.write(record, service: service)
        #expect(try InstallationCredentialKeychain.read(service: service)?.credential == secret)
        var secretQuery = query
        secretQuery[kSecAttrAccount as String] = InstallationCredentialKeychain.account
        if corrupt {
            #expect(SecItemUpdate(secretQuery as CFDictionary,
                [kSecValueData as String: Data("corrupt".utf8)] as CFDictionary) == errSecSuccess)
        } else {
            #expect(SecItemDelete(secretQuery as CFDictionary) == errSecSuccess)
        }
        let http = EnrollmentHTTPClient([])
        let coordinator = InstallationEnrollmentCoordinator(
            installationId: { enrollmentTestID },
            read: { try InstallationCredentialKeychain.read(service: service) },
            write: { try InstallationCredentialKeychain.write($0, service: service) },
            generate: { Issue.record("Credential must not be regenerated"); return enrollmentTestSecret }
        )
        await #expect(throws: InstallationEnrollmentError.persistenceUnavailable) {
            try await coordinator.credential(for: enrollmentTestID, baseURL: baseURL, http: http)
        }
        #expect(await http.state.allRequests().isEmpty)
    }

    @Test("installation redirects are refused by the URLSession delegate", arguments: [307, 308])
    func redirectConfinement(status: Int) throws {
        for path in ["/v2/devices/enroll", "/v3/devices/preferences", "/api/v2/devices/location-snapshots", "/v3/devices/foreground-activity"] {
            for destination in ["https://outside.example.com/leak", "https://arcus.example.com/v1/mesos", "http://arcus.example.com/leak"] {
                var original = URLRequest(url: baseURL.appendingPathComponent(path))
                original.httpMethod = "POST"
                original.httpBody = Data("synthetic credential".utf8)
                original.setValue("Bearer synthetic", forHTTPHeaderField: "Authorization")
                let task = URLSession.shared.dataTask(with: original)
                let delegate: any URLSessionTaskDelegate = URLSessionTaskMetricsCollector()
                let response = try #require(HTTPURLResponse(url: original.url!, statusCode: status,
                    httpVersion: "HTTP/1.1", headerFields: ["Location": destination]))
                let called = Mutex(false)
                delegate.urlSession?(URLSession.shared, task: task, willPerformHTTPRedirection: response,
                    newRequest: URLRequest(url: URL(string: destination)!), completionHandler: { request in
                        #expect(request == nil)
                        called.withLock { $0 = true }
                    })
                #expect(called.withLock { $0 })
                task.cancel()
            }
        }
        var weather = URLRequest(url: baseURL.appendingPathComponent("/v1/mesos"))
        weather.httpMethod = "GET"
        #expect(InstallationRequestRedirectPolicy.allowsRedirect(for: weather))
    }
}

extension InstallationEnrollmentTests {
    @Test("volatile identity cannot initialize durable v3 consent bookkeeping")
    func consentRequiresDurableIdentity() async throws {
        let suite = "consent-identity-\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let http = EnrollmentHTTPClient([])
        let enrollment = InstallationEnrollmentCoordinator(installationId: {
            throw InstallationEnrollmentError.persistenceUnavailable
        })
        let uploader = HTTPDevicePreferenceSyncUploader(baseURL: baseURL, http: http,
            enrollment: enrollment, consent: isolatedConsentStore(suiteName: suite))
        await #expect(throws: InstallationEnrollmentError.persistenceUnavailable) {
            try await uploader.reconcileConsent(installationId: enrollmentTestID)
        }
        #expect(UserDefaults(suiteName: suite)?.data(forKey: InstallationConsentStore.recordKey) == nil)
        #expect(await http.state.allRequests().isEmpty)
    }
}
