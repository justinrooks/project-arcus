import Foundation
import OSLog
import UIKit
import ArcusCore

protocol DevicePreferenceSyncUploading: Sendable {
    func upload(_ payload: DevicePreferenceSyncPayload) async throws
}

actor HTTPDevicePreferenceSyncUploader: DevicePreferenceSyncUploading {
    static let ownershipDefaultsKey = "serverOwnsMesoNotificationDelivery"

    private let defaults: UserDefaults
    private let endpoint: URL
    private let http: HTTPClient
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder
    private let logger = Logger.locationPushUploader

    init(
        baseURL: URL,
        http: HTTPClient = URLSessionHTTPClient(),
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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func upload(_ payload: DevicePreferenceSyncPayload) async throws {
        let body = try encoder.encode(payload)
        let response = try await http.post(endpoint, headers: requestHeaders, body: body)
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
