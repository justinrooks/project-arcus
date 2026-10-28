import Foundation
import OSLog
import UIKit
import ArcusCore

protocol DevicePreferenceSyncUploading: Sendable {
    func upload(_ payload: DevicePreferenceSyncPayload) async throws
    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> DevicePreferenceSyncPayload) async throws
}

extension DevicePreferenceSyncUploading {
    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> DevicePreferenceSyncPayload) async throws {
        try await upload(preparing())
    }
}

actor HTTPDevicePreferenceSyncUploader: DevicePreferenceSyncUploading {
    static let ownershipDefaultsKey = "serverOwnsMesoNotificationDelivery"

    private let defaults: UserDefaults
    private let endpoint: URL
    private let http: HTTPClient
    private let enrollment: InstallationEnrollmentCoordinator
    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder
    private let logger = Logger.locationPushUploader

    init(
        baseURL: URL,
        http: HTTPClient = URLSessionHTTPClient(),
        enrollment: InstallationEnrollmentCoordinator = .shared,
        defaultsSuiteName: String = "com.justinrooks.skyaware"
    ) {
        self.defaults = UserDefaults(suiteName: defaultsSuiteName) ?? .standard
        guard let endpoint = ArcusSignalConfiguration.url(
            from: baseURL,
            path: ArcusSignalConfiguration.devicePreferencesPath
        ) else {
            preconditionFailure("Invalid Arcus signal base URL")
        }
        self.endpoint = endpoint
        self.http = http
        self.enrollment = enrollment
        self.baseURL = baseURL

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func upload(_ payload: DevicePreferenceSyncPayload) async throws {
        try await upload(installationId: payload.installationId, preparing: { payload })
    }

    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> DevicePreferenceSyncPayload) async throws {
        let credential = try await enrollment.credential(
            for: installationId, baseURL: baseURL, http: http
        )
        // Enrollment can suspend. Resolve current consent only after it completes.
        let payload = try await preparing()
        try Task.checkCancellation()
        let body = try encoder.encode(payload)
        var headers = requestHeaders
        headers["Authorization"] = "Bearer \(credential)"
        let response = try await http.post(endpoint, headers: headers, body: body)
        guard (200...299).contains(response.status) else {
            throw LocationPushError.invalidResponseStatus(response.status)
        }

        let accepted = response.data.flatMap {
            try? decoder.decode(DevicePreferenceSyncAcceptedResponse.self, from: $0)
        }
        // Missing or malformed acknowledgments must not preserve a prior ownership claim.
        defaults.set(accepted?.serverOwnsMesoNotificationDelivery, forKey: Self.ownershipDefaultsKey)

        logger.info("Device preference sync uploaded")
    }

    private var requestHeaders: [String: String] {
        [
            "User-Agent": HTTPRequestHeaders.userAgent(),
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
    }
}

struct NoOpDevicePreferenceSyncUploader: DevicePreferenceSyncUploading {
    func upload(_ payload: DevicePreferenceSyncPayload) async throws {}
}
