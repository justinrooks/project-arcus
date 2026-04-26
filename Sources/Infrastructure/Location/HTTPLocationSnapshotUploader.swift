//
//  HTTPLocationSnapshotUploader.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/8/26.
//

import Foundation
import OSLog

protocol LocationSnapshotUploading: Sendable {
    func upload(_ payload: LocationSnapshotPushPayload) async throws
}

struct NoOpLocationContextPusher: LocationContextPushing {
    func enqueue(_ context: LocationContext, forceUpload: Bool) async {}
}

actor HTTPLocationSnapshotUploader: LocationSnapshotUploading {
    private let endpoint: URL
    private let http: HTTPClient
    private let encoder: JSONEncoder
    private let logger = Logger.locationPushUploader

    init(baseURL: URL, http: HTTPClient = URLSessionHTTPClient()) {
        guard let endpoint = ArcusSignalConfiguration.url(
            from: baseURL,
            path: ArcusSignalConfiguration.locationSnapshotsPath
        ) else {
            preconditionFailure("Invalid Arcus signal base URL")
        }
        self.endpoint = endpoint
        self.http = http
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func upload(_ payload: LocationSnapshotPushPayload) async throws {
        let body = try encoder.encode(payload)
        let response = try await http.post(endpoint, headers: requestHeaders, body: body)
        guard (200...299).contains(response.status) else {
            logger.error("Location snapshot upload failed status=\(response.status, privacy: .public)")
            throw LocationPushError.invalidResponseStatus(response.status)
        }
        logger.info("Location snapshot uploaded cell=\(String(payload.h3Cell ?? 0), privacy: .public)")
    }

    private var requestHeaders: [String: String] {
        [
            "User-Agent": HTTPRequestHeaders.userAgent(),
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
    }
}
