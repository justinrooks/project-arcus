//
//  ArcusAlertSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation

enum ArcusLocationSyncOutcome: Sendable, Equatable {
    case accepted
    case fallback
    case rejected
    case failed
    case cancelled
}

enum ArcusRemoteAlertSyncOutcome: Sendable, Equatable {
    case accepted
    case fallback
    case rejected
    case failed
    case cancelled
}

protocol ArcusAlertSyncing: Sendable {
    func sync(context: LocationContext) async -> ArcusLocationSyncOutcome
    func syncRemoteAlert(id: String, revisionSent: Date?) async -> ArcusRemoteAlertSyncOutcome
}
