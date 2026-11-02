import Foundation
import ArcusCore

protocol DevicePreferenceSyncUploading: Sendable {
    func upload(_ payload: DevicePreferenceSyncPayload) async throws
    var hasPendingPreferenceIntent: Bool { get }
    func savedLocationEvidenceCutoff() throws -> Date?
    func invalidateLocationEvidence(at date: Date) throws
    func locationEvidenceCutoff(installationId: String) async throws -> Date?
    func restrictSubscription() async
    func acceptSubscriptionIntent(installationId: String, enabled: Bool) async throws
    func reconcileConsent(installationId: String) async throws
    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> DevicePreferenceSyncPayload) async throws
}

extension DevicePreferenceSyncUploading {
    var hasPendingPreferenceIntent: Bool { false }
    func savedLocationEvidenceCutoff() throws -> Date? { nil }
    func invalidateLocationEvidence(at date: Date) throws {}
    func locationEvidenceCutoff(installationId: String) async throws -> Date? { nil }
    func restrictSubscription() async {}
    func acceptSubscriptionIntent(installationId: String, enabled: Bool) async throws {}
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

    nonisolated var hasPendingPreferenceIntent: Bool { consent.hasPendingPreferenceIntent }

    nonisolated func savedLocationEvidenceCutoff() throws -> Date? {
        try consent.savedLocationEvidenceCutoff()
    }

    nonisolated func invalidateLocationEvidence(at date: Date) throws {
        try consent.invalidateLocationEvidence(at: date)
    }

    func locationEvidenceCutoff(installationId: String) async throws -> Date? {
        try await enrollment.validateIdentity(for: installationId)
        return try await consent.locationEvidenceCutoff(installationId: installationId)
    }

    func restrictSubscription() async {
        await consent.restrictSubscription()
    }

    func acceptSubscriptionIntent(installationId: String, enabled: Bool) async throws {
        try await enrollment.validateIdentity(for: installationId)
        try await consent.acceptSubscriptionIntent(installationId: installationId, enabled: enabled)
    }

    func reconcileConsent(installationId: String) async throws {
        try await enrollment.validateIdentity(for: installationId)
        _ = try await consent.current(installationId: installationId)
    }
}

struct NoOpDevicePreferenceSyncUploader: DevicePreferenceSyncUploading {
    func upload(_ payload: DevicePreferenceSyncPayload) async throws {}
}
