//
//  LocationUploadPersistenceModels.swift
//  SkyAware
//

import Foundation
import ArcusCore

struct PersistedLocationUploadRequest: Sendable, Codable, Equatable {
    let source: LocationUploadSource
    let reason: LocationUploadReason
    let forceUpload: Bool
    let installationId: String
    let requestedAt: Date
    let isSubscribed: Bool
    let authorizationState: String
    let apnsToken: String
    let operation: PersistedUploadOperation

    enum CodingKeys: String, CodingKey {
        case source
        case reason
        case forceUpload
        case installationId
        case requestedAt
        case isSubscribed
        case authorizationState
        case apnsToken
        case operation
        case context
    }

    init(
        source: LocationUploadSource,
        reason: LocationUploadReason,
        forceUpload: Bool,
        installationId: String,
        requestedAt: Date,
        isSubscribed: Bool,
        authorizationState: String,
        apnsToken: String,
        operation: PersistedUploadOperation
    ) {
        self.source = source
        self.reason = reason
        self.forceUpload = forceUpload
        self.installationId = installationId
        self.requestedAt = requestedAt
        self.isSubscribed = isSubscribed
        self.authorizationState = authorizationState
        self.apnsToken = apnsToken
        self.operation = operation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(LocationUploadSource.self, forKey: .source)
        reason = try container.decode(LocationUploadReason.self, forKey: .reason)
        forceUpload = try container.decode(Bool.self, forKey: .forceUpload)
        installationId = try container.decode(String.self, forKey: .installationId)
        requestedAt = try container.decode(Date.self, forKey: .requestedAt)
        isSubscribed = try container.decode(Bool.self, forKey: .isSubscribed)
        authorizationState = try container.decode(String.self, forKey: .authorizationState)
        apnsToken = try container.decode(String.self, forKey: .apnsToken)

        if let operation = try container.decodeIfPresent(PersistedUploadOperation.self, forKey: .operation) {
            self.operation = operation
        } else if let context = try container.decodeIfPresent(PersistedLocationContext.self, forKey: .context) {
            self.operation = .locationSnapshot(context: context)
        } else {
            self.operation = .preferenceSync
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(reason, forKey: .reason)
        try container.encode(forceUpload, forKey: .forceUpload)
        try container.encode(installationId, forKey: .installationId)
        try container.encode(requestedAt, forKey: .requestedAt)
        try container.encode(isSubscribed, forKey: .isSubscribed)
        try container.encode(authorizationState, forKey: .authorizationState)
        try container.encode(apnsToken, forKey: .apnsToken)
        try container.encode(operation, forKey: .operation)
    }
}

enum PersistedUploadOperation: Sendable, Codable, Equatable {
    case locationSnapshot(context: PersistedLocationContext)
    case preferenceSync

    enum CodingKeys: String, CodingKey {
        case kind
        case context
    }

    enum Kind: String, Codable {
        case locationSnapshot
        case preferenceSync
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .locationSnapshot:
            let context = try container.decode(PersistedLocationContext.self, forKey: .context)
            self = .locationSnapshot(context: context)
        case .preferenceSync:
            self = .preferenceSync
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .locationSnapshot(let context):
            try container.encode(Kind.locationSnapshot, forKey: .kind)
            try container.encode(context, forKey: .context)
        case .preferenceSync:
            try container.encode(Kind.preferenceSync, forKey: .kind)
        }
    }

    var deduplicationOperation: PendingDeduplicationOperation {
        switch self {
        case .locationSnapshot(let context):
            return .locationSnapshot(
                h3Cell: context.h3Cell,
                county: context.county,
                fireZone: context.fireZone,
                forecastZone: context.forecastZone
            )
        case .preferenceSync:
            return .preferenceSync
        }
    }
}

enum PendingDeduplicationOperation: Sendable, Codable, Hashable {
    case locationSnapshot(h3Cell: Int64, county: String?, fireZone: String?, forecastZone: String?)
    case preferenceSync
}

struct PersistedLocationContext: Sendable, Codable, Equatable {
    let capturedAt: Date
    let horizontalAccuracyMeters: Double
    let h3Cell: Int64
    let county: String?
    let fireZone: String?
    let forecastZone: String?
    let countyLabel: String?
    let fireZoneLabel: String?

    init(_ context: LocationContext) {
        self.capturedAt = context.snapshot.timestamp
        self.horizontalAccuracyMeters = context.snapshot.accuracy
        self.h3Cell = context.h3Cell
        self.county = context.grid.countyCode
        self.fireZone = context.grid.fireZone
        self.forecastZone = context.grid.forecastZone
        self.countyLabel = context.grid.countyLabel
        self.fireZoneLabel = context.grid.fireZoneLabel
    }

    init(payload: LocationSnapshotPushPayload) {
        self.capturedAt = payload.capturedAt
        self.horizontalAccuracyMeters = payload.horizontalAccuracyMeters
        self.h3Cell = payload.h3Cell ?? 0
        self.county = payload.county
        self.fireZone = payload.fireZone
        self.forecastZone = payload.zone
        self.countyLabel = payload.countyLabel
        self.fireZoneLabel = payload.fireZoneLabel
    }
}
