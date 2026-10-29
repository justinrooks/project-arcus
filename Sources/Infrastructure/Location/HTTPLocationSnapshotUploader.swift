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
    func upload(installationId: String, checking: @escaping @Sendable () async throws -> Void,
                preparing: @escaping @Sendable () async throws -> LocationSnapshotPushPayload) async throws
    func upload(_ payload: LocationSnapshotPushPayload) async throws
    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> LocationSnapshotPushPayload) async throws
}

extension LocationSnapshotUploading {
    func upload(installationId: String, checking: @escaping @Sendable () async throws -> Void,
                preparing: @escaping @Sendable () async throws -> LocationSnapshotPushPayload) async throws {
        try await checking()
        try await upload(installationId: installationId, preparing: preparing)
    }

    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> LocationSnapshotPushPayload) async throws {
        try await upload(preparing())
    }
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
    private let consent: InstallationConsentStore
    private let endpoint: URL
    private let http: HTTPClient
    private let enrollment: InstallationEnrollmentCoordinator
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let logger = Logger.locationPushUploader

    init(baseURL: URL, http: HTTPClient = URLSessionHTTPClient(),
        enrollment: InstallationEnrollmentCoordinator = .shared,
        consent: InstallationConsentStore = .shared) {
        guard let endpoint = ArcusSignalConfiguration.url(
            from: baseURL,
            path: ArcusSignalConfiguration.locationSnapshotsPath
        ) else {
            preconditionFailure("Invalid Arcus signal base URL")
        }
        self.consent = consent
        self.endpoint = endpoint
        self.http = http
        self.enrollment = enrollment
        self.baseURL = baseURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func upload(_ payload: LocationSnapshotPushPayload) async throws {
        try await upload(installationId: payload.installationId, preparing: { payload })
    }

    func upload(installationId: String, preparing: @escaping @Sendable () async throws -> LocationSnapshotPushPayload) async throws {
        try await upload(installationId: installationId, checking: { try Task.checkCancellation() }, preparing: preparing)
    }

    func upload(installationId: String, checking: @escaping @Sendable () async throws -> Void,
                preparing: @escaping @Sendable () async throws -> LocationSnapshotPushPayload) async throws {
        let credential = try await enrollment.credential(
            for: installationId, baseURL: baseURL, http: http
        )
        try await consent.synchronize(installationId: installationId, baseURL: baseURL,
                                      http: http, credential: credential,
                                      checking: { try await checking(); return nil })
        try await checking()
        let current = try await consent.current(installationId: installationId).consent
        guard current.locationSharingEnabled,
              current.locationAuthorization == .always || current.locationAuthorization == .whenInUse else {
            throw LocationPushError.presenceNotAccepted
        }
        // Admission can suspend. Recheck the queue privacy gate after it completes.
        let payload = try await preparing()
        try Task.checkCancellation()
        let presence = try DeviceLocationSnapshotV3Payload(
            installationId: payload.installationId, capturedAt: payload.capturedAt,
            locationAgeSeconds: max(0, payload.locationAgeSeconds),
            horizontalAccuracyMeters: payload.horizontalAccuracyMeters,
            cellScheme: payload.h3Cell == nil ? "ugc-only" : "h3",
            h3Cell: payload.h3Cell, h3Resolution: payload.h3Cell == nil ? nil : payload.h3Resolution,
            county: payload.county, zone: payload.zone, fireZone: payload.fireZone,
            countyLabel: payload.countyLabel, fireZoneLabel: payload.fireZoneLabel,
            source: LocationUploadSource(rawValue: payload.source) ?? .unknown
        )
        let body = try encoder.encode(presence)
        var headers = requestHeaders
        headers["Authorization"] = "Bearer \(credential)"
        let response = try await http.post(endpoint, headers: headers, body: body)
        guard response.status == 200 else {
            throw LocationPushError.invalidResponseStatus(response.status)
        }
        struct Acknowledgment: Decodable { let status: String; let receivedAt: Date }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = response.data,
              let ack = try? decoder.decode(Acknowledgment.self, from: data),
              ["accepted", "ignored", "stale"].contains(ack.status) else {
            throw InstallationConsentStore.Failure.inconsistentAcknowledgment
        }
        guard ack.status == "accepted" else { throw LocationPushError.presenceNotAccepted }
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
