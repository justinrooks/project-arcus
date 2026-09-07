//
//  ForegroundDurableContextReusePolicy.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

/// Defines the safe, non-blocking foreground use of a durable location context.
///
/// This policy deliberately does not load, save, invalidate, resolve, or upload anything. A future runtime
/// integration must supply evidence for the cached context, show it immediately only when this policy permits it,
/// and refresh the context independently behind that foreground result. Current v1 durable entries are ineligible:
/// they do not persist capture authorization or a separately verified current grid reference.
struct ForegroundDurableContextReusePolicy: Sendable {
    /// Matches the resolver's maximum age for a recently acquired live location.
    static let maximumReuseAge: TimeInterval = 15

    enum Authorization: Sendable, Equatable {
        case always
        case whenInUse
        case denied
        case restricted
        case notDetermined
        case unknown
    }

    struct GridIdentity: Sendable, Equatable {
        let nwsId: String
        let gridId: String
        let gridX: Int
        let gridY: Int

        var isValid: Bool {
            nwsId.isEmpty == false && gridId.isEmpty == false && gridX >= 0 && gridY >= 0
        }

        /// `nwsId` is a coordinate-specific NWS point URL, not part of the stable forecast grid identity.
        func matchesGridCell(_ other: GridIdentity) -> Bool {
            gridId == other.gridId && gridX == other.gridX && gridY == other.gridY
        }
    }

    struct CachedContext: Sendable, Equatable {
        let capturedAt: Date
        let authorizationAtCapture: Authorization
        let snapshotH3Cell: Int64?
        let contextH3Cell: Int64
        let grid: GridIdentity
        let isComplete: Bool
    }

    enum CacheState: Sendable, Equatable {
        case missing
        case invalid
        /// The existing persisted format cannot establish this policy's authorization and grid prerequisites.
        case legacyV1
        case available(CachedContext)
    }

    /// A current, trusted context used to prove the durable context still targets the same H3 and NWS grid.
    struct CurrentContextEvidence: Sendable, Equatable {
        let h3Cell: Int64
        let grid: GridIdentity
    }

    enum MovementEvidence: Sendable, Equatable {
        case none
        case significantLocationChange
        case explicitInvalidation
    }

    enum Decision: Sendable, Equatable {
        /// Render the durable context immediately and independently resolve a fresh context afterward.
        case reuseAndRefreshBehind
        /// Do not expose the durable context; resolve a fresh context before location-dependent work proceeds.
        case resolveFreshLocation
        case skipLocationDependentWork

        /// Reuse has no upload side effect. A refresh-behind may upload only its newly resolved context with its
        /// original capture timestamp; it must never rewrite the durable context's timestamp.
        var uploadDisposition: UploadDisposition {
            switch self {
            case .reuseAndRefreshBehind, .skipLocationDependentWork:
                .none
            case .resolveFreshLocation:
                .afterFreshResolutionPreservingCaptureTime
            }
        }
    }

    enum UploadDisposition: Sendable, Equatable {
        case none
        case afterFreshResolutionPreservingCaptureTime
    }

    struct Input: Sendable, Equatable {
        let authorization: Authorization
        let cache: CacheState
        let currentContext: CurrentContextEvidence?
        let movementEvidence: MovementEvidence
        let now: Date
    }

    func decide(_ input: Input) -> Decision {
        guard isLocationAuthorized(input.authorization) else {
            return .skipLocationDependentWork
        }

        guard input.movementEvidence == .none,
              case .available(let context) = input.cache,
              context.authorizationAtCapture == input.authorization,
              isCompatible(context, with: input.currentContext),
              isEligible(context, now: input.now) else {
            return .resolveFreshLocation
        }

        return .reuseAndRefreshBehind
    }

    private func isLocationAuthorized(_ authorization: Authorization) -> Bool {
        switch authorization {
        case .always, .whenInUse:
            true
        case .denied, .restricted, .notDetermined, .unknown:
            false
        }
    }

    private func isEligible(_ context: CachedContext, now: Date) -> Bool {
        guard context.isComplete,
              context.snapshotH3Cell == context.contextH3Cell,
              context.contextH3Cell != 0,
              context.grid.isValid else {
            return false
        }

        let age = now.timeIntervalSince(context.capturedAt)
        return age.isFinite && age >= 0 && age <= Self.maximumReuseAge
    }

    private func isCompatible(_ context: CachedContext, with currentContext: CurrentContextEvidence?) -> Bool {
        guard let currentContext else { return false }
        return context.contextH3Cell == currentContext.h3Cell && context.grid.matchesGridCell(currentContext.grid)
    }
}
