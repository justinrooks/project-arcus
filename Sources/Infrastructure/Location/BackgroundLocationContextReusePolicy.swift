//
//  BackgroundLocationContextReusePolicy.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

/// Determines whether scheduled background work may use a previously prepared location context.
///
/// The policy intentionally accepts only value inputs. Runtime location acquisition, persistence,
/// and context restoration remain outside this contract.
struct BackgroundLocationContextReusePolicy: Sendable {
    /// Explicit product privacy tolerance for a cached location context; not a scheduler-delay guarantee.
    static let maximumReuseAge: TimeInterval = 90 * 60
    static let maximumHorizontalAccuracy: Double = 100

    enum Authorization: Sendable, Equatable {
        case always
        case whenInUse
        case denied
        case restricted
        case notDetermined
        case unknown
    }

    enum CacheState: Sendable, Equatable {
        case missing
        case invalid
        case available(CachedContext)
    }

    struct CachedContext: Sendable, Equatable {
        let coordinatesAreValid: Bool
        let timestamp: Date
        let horizontalAccuracy: Double
        let isComplete: Bool

        init(
            coordinatesAreValid: Bool,
            timestamp: Date,
            horizontalAccuracy: Double,
            isComplete: Bool
        ) {
            self.coordinatesAreValid = coordinatesAreValid
            self.timestamp = timestamp
            self.horizontalAccuracy = horizontalAccuracy
            self.isComplete = isComplete
        }
    }

    enum MovementEvidence: Sendable, Equatable {
        case none
        case significantLocationChange
        case explicitInvalidation
    }

    enum Decision: Sendable, Equatable {
        case reuseCachedContext
        case attemptFreshLocation
        case skipLocationDependentWork
    }

    struct Input: Sendable, Equatable {
        let authorization: Authorization
        let cache: CacheState
        let movementEvidence: MovementEvidence
        let now: Date

        init(
            authorization: Authorization,
            cache: CacheState,
            movementEvidence: MovementEvidence,
            now: Date
        ) {
            self.authorization = authorization
            self.cache = cache
            self.movementEvidence = movementEvidence
            self.now = now
        }
    }

    func decide(_ input: Input) -> Decision {
        guard isLocationAuthorized(input.authorization) else {
            return .skipLocationDependentWork
        }

        if isEligibleForReuse(input) {
            return .reuseCachedContext
        }

        return input.authorization == .always
            ? .attemptFreshLocation
            : .skipLocationDependentWork
    }

    private func isLocationAuthorized(_ authorization: Authorization) -> Bool {
        switch authorization {
        case .always, .whenInUse:
            true
        case .denied, .restricted, .notDetermined, .unknown:
            false
        }
    }

    private func isEligibleForReuse(_ input: Input) -> Bool {
        guard input.movementEvidence == .none,
              case .available(let context) = input.cache,
              context.isComplete,
              context.coordinatesAreValid,
              context.horizontalAccuracy.isFinite,
              context.horizontalAccuracy > 0,
              context.horizontalAccuracy <= Self.maximumHorizontalAccuracy else {
            return false
        }

        let age = input.now.timeIntervalSince(context.timestamp)
        return age.isFinite && age >= 0 && age <= Self.maximumReuseAge
    }
}
