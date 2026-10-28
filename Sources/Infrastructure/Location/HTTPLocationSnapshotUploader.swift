//
//  HTTPLocationSnapshotUploader.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/8/26.
//

import Foundation
import OSLog
import ArcusCore

protocol LocationSnapshotUploading: Sendable {
    func upload(_ payload: LocationSnapshotPushPayload) async throws
}

struct NoOpLocationUploadCoordinator: LocationUploadCoordinating {
    func enqueue(
        _ context: LocationContext,
        source: LocationUploadSource,
        reason: LocationUploadReason,
        forceUpload: Bool
    ) async {}
    func enqueuePreferenceSync(
        source: LocationUploadSource,
        requestReason: LocationUploadReason,
        forceUpload: Bool,
        detail: String,
        isSubscribedOverride: Bool?
    ) async {}
    func drainPendingUploads() async {}

    func drainPendingUploads(
        using budget: PendingLocationUploadDrainBudget
    ) async -> PendingLocationUploadDrainOutcome {
        .drained
    }
}

actor HTTPLocationSnapshotUploader: LocationSnapshotUploading {
    private let endpoint: URL
    private let http: HTTPClient
    private let enrollment: InstallationEnrollmentCoordinator
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let logger = Logger.locationPushUploader

    init(baseURL: URL, http: HTTPClient = URLSessionHTTPClient(),
        enrollment: InstallationEnrollmentCoordinator = .shared) {
        guard let endpoint = ArcusSignalConfiguration.url(
            from: baseURL,
            path: ArcusSignalConfiguration.locationSnapshotsPath
        ) else {
            preconditionFailure("Invalid Arcus signal base URL")
        }
        self.endpoint = endpoint
        self.http = http
        self.enrollment = enrollment
        self.baseURL = baseURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func upload(_ payload: LocationSnapshotPushPayload) async throws {
        let body = try encoder.encode(payload)
        let credential = try await enrollment.credential(
            for: payload.installationId, baseURL: baseURL, http: http
        )
        try Task.checkCancellation()
        var headers = requestHeaders
        headers["Authorization"] = "Bearer \(credential)"
        let response = try await http.post(endpoint, headers: headers, body: body)
        guard (200...299).contains(response.status) else {
            throw LocationPushError.invalidResponseStatus(response.status)
        }
        logger.info("Location snapshot uploaded")
    }

    private var requestHeaders: [String: String] {
        [
            "User-Agent": HTTPRequestHeaders.userAgent(),
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
    }
}
