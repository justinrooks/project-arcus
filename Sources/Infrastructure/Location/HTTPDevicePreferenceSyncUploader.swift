import Foundation
import OSLog
import UIKit
import ArcusCore

protocol DevicePreferenceSyncUploading: Sendable {
    func upload(_ payload: DevicePreferenceSyncPayload) async throws
}

actor HTTPDevicePreferenceSyncUploader: DevicePreferenceSyncUploading {
    private let endpoint: URL
    private let http: HTTPClient
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder
    private let logger = Logger.locationPushUploader

    init(baseURL: URL, http: HTTPClient = URLSessionHTTPClient()) {
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

        if let data = response.data, data.isEmpty == false {
            _ = try? decoder.decode(DevicePreferenceSyncAcceptedResponse.self, from: data)
        }

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
