import Foundation
import ArcusCore

protocol DevicePreferenceSyncUploading: Sendable {
    func upload(_ payload: DevicePreferenceSyncPayload) async throws
    func restrictSubscription() async
    func reconcileConsent(installationId: String) async throws
    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> DevicePreferenceSyncPayload) async throws
}

extension DevicePreferenceSyncUploading {
    func restrictSubscription() async {}
    func reconcileConsent(installationId: String) async throws {}
    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> DevicePreferenceSyncPayload) async throws {
        try await upload(preparing())
    }
}

actor HTTPDevicePreferenceSyncUploader: DevicePreferenceSyncUploading {
    static let ownershipDefaultsKey = "serverOwnsMesoNotificationDelivery"

    private let consent: InstallationConsentStore
    private let http: HTTPClient
    private let enrollment: InstallationEnrollmentCoordinator
    private let baseURL: URL

    init(
        baseURL: URL,
        http: HTTPClient = URLSessionHTTPClient(),
        enrollment: InstallationEnrollmentCoordinator = .shared,
        consent: InstallationConsentStore = .shared
    ) {
        self.consent = consent
        self.http = http
        self.enrollment = enrollment
        self.baseURL = baseURL
    }

    func upload(_ payload: DevicePreferenceSyncPayload) async throws {
        try await upload(installationId: payload.installationId, preparing: { payload })
    }

    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> DevicePreferenceSyncPayload) async throws {
        let credential = try await enrollment.credential(
            for: installationId, baseURL: baseURL, http: http
        )
        // Enrollment can suspend. Resolve current consent only after it completes.
        try await consent.synchronize(installationId: installationId, baseURL: baseURL,
                                      http: http, credential: credential,
                                      checking: { try await preparing().apnsDeviceToken })
    }

    func restrictSubscription() async {
        await consent.restrictSubscription()
    }

    func reconcileConsent(installationId: String) async throws {
        try await enrollment.validateIdentity(for: installationId)
        _ = try await consent.current(installationId: installationId)
    }
}

struct NoOpDevicePreferenceSyncUploader: DevicePreferenceSyncUploading {
    func upload(_ payload: DevicePreferenceSyncPayload) async throws {}
}
