//
//  ArcusAlertSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation

enum ArcusLocationSyncOutcome: Sendable, Equatable {
    case live
    case revalidated
    case localCache
    case errorFallback
    case rejected
    case failed
    case cancelled

    static var accepted: Self { .live }
    static var fallback: Self { .errorFallback }

    var authorizesLocationScopedAcceptance: Bool {
        switch self {
        case .live, .revalidated:
            true
        case .localCache, .errorFallback, .rejected, .failed, .cancelled:
            false
        }
    }
}

enum ArcusRemoteAlertSyncOutcome: Sendable, Equatable {
    case live
    case revalidated
    case localCache
    case errorFallback
    case rejected
    case failed
    case cancelled

    static var accepted: Self { .live }
    static var fallback: Self { .errorFallback }
}

protocol ArcusAlertSyncing: Sendable {
    func sync(context: LocationContext) async -> ArcusLocationSyncOutcome
    func syncRemoteAlert(id: String, revisionSent: Date?) async -> ArcusRemoteAlertSyncOutcome
}
