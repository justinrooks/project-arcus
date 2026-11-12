import Foundation
import SwiftData

enum WSSISnapshotError: Error, Equatable {
    case invalidSnapshot
    case staleIssuance
    case conflictingIssuance
    case capacityExceeded
    case injectedFailure
}

/// Codable values are encoded into a primitive Data attribute, never persisted as SwiftData enums.
struct WSSISnapshotLayer: Codable, Sendable, Equatable {
    enum State: String, Codable, Sendable { case identifiedData, observedEmpty, identifiedEmpty }
    let product: WSSIProduct
    let period: WSSIPeriod
    let state: State
    let issuedAt: Date?
    let validFrom: Date?
    let validTo: Date?
    let features: [WSSIFeature]

    /// Requires geometry already validated by WSSIDecoder; this seam validates publication metadata.
    func assessmentLayer(in scope: WSSIScope) throws -> WSSIAssessmentLayer? {
        if state == .observedEmpty {
            guard issuedAt == nil, validFrom == nil, validTo == nil, features.isEmpty else {
                throw WSSISnapshotError.invalidSnapshot
            }
            return nil
        }
        guard let issuedAt, let validFrom, let validTo,
              (state == .identifiedEmpty) == features.isEmpty else { throw WSSISnapshotError.invalidSnapshot }
        return try WSSIAssessmentLayer(product: product, period: period, issuedAt: issuedAt,
                                       validFrom: validFrom, validTo: validTo, scope: scope, features: features)
    }
}

struct WSSISnapshot: Codable, Sendable, Equatable {
    let scope: WSSIScope
    let source: URL
    let acquisitionStartedAt: Date
    let verifiedAt: Date
    let provenance: String
    let layers: [WSSISnapshotLayer]

    func validate() throws {
        _ = try WSSIScope(south: scope.south, west: scope.west, north: scope.north, east: scope.east)
        guard source.scheme == "https", source.host != nil,
              acquisitionStartedAt.timeIntervalSince1970.isFinite, verifiedAt.timeIntervalSince1970.isFinite,
              acquisitionStartedAt <= verifiedAt, provenance.utf8.count <= 65_536,
              layers.count == WSSIProduct.allCases.count * WSSIPeriod.allCases.count else {
            throw WSSISnapshotError.invalidSnapshot
        }
        for product in WSSIProduct.allCases {
            for period in WSSIPeriod.allCases {
                guard let layer = layers.first(where: { $0.product == product && $0.period == period }),
                      layers.filter({ $0.product == product && $0.period == period }).count == 1 else {
                    throw WSSISnapshotError.invalidSnapshot
                }
                _ = try layer.assessmentLayer(in: scope)
            }
        }
    }
}

struct WSSICachedSnapshot: Codable, Sendable, Equatable {
    let snapshot: WSSISnapshot
    let revision: Int64
    let committedAt: Date
    var selectedAt: Date
}

struct WSSIIssuanceWatermark: Codable, Sendable, Equatable {
    let product: WSSIProduct
    let period: WSSIPeriod
    var issuedAt: Date
}

/// One row makes scope replacement, revision allocation, retention and watermarks one durable write.
/// The V7 layer table remains intact for migration compatibility; it is not canonical snapshot evidence.
@Model
final class WSSICacheRecord {
    var formatVersion: Int = 1
    var payload: Data

    init(payload: Data) { self.payload = payload }
}

struct WSSICacheContents: Codable, Sendable {
    var revision: Int64 = 0
    var snapshots: [WSSICachedSnapshot] = []
    var watermarks: [WSSIIssuanceWatermark] = []

    func validate() throws {
        guard revision >= 0, snapshots.count <= 2, watermarks.count <= 20 else {
            throw WSSISnapshotError.invalidSnapshot
        }
        for (index, entry) in snapshots.enumerated() {
            try entry.snapshot.validate()
            guard entry.revision > 0, entry.revision <= revision,
                  entry.committedAt.timeIntervalSince1970.isFinite,
                  entry.selectedAt.timeIntervalSince1970.isFinite,
                  !snapshots.prefix(index).contains(where: { $0.snapshot.scope == entry.snapshot.scope }) else {
                throw WSSISnapshotError.invalidSnapshot
            }
        }
        for (index, watermark) in watermarks.enumerated() {
            guard watermark.issuedAt.timeIntervalSince1970.isFinite,
                  !watermarks.prefix(index).contains(where: {
                      $0.product == watermark.product && $0.period == watermark.period
                  }) else { throw WSSISnapshotError.invalidSnapshot }
        }
        for layer in snapshots.flatMap(\.snapshot.layers) {
            if let issuedAt = layer.issuedAt {
                guard watermarks.contains(where: {
                    $0.product == layer.product && $0.period == layer.period && $0.issuedAt >= issuedAt
                }) else { throw WSSISnapshotError.invalidSnapshot }
            }
        }
    }
}
