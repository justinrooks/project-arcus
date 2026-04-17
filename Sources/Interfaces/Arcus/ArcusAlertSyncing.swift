//
//  ArcusAlertSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/17/26.
//

import Foundation

protocol ArcusAlertSyncing: Sendable {
    func sync(context: LocationContext) async -> Void
    func syncRemoteAlert(id: String, revisionSent: Date?) async -> Void
}
