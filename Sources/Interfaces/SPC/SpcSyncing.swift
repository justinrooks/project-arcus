//
//  SpcSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation

enum SpcMapSyncOutcome: Sendable, Equatable {
    case accepted
    case rejected
    case skipped
    case failed
}

protocol SpcSyncing: Sendable {//where Self: Actor {
    func sync() async -> Void
    func syncMapProducts() async -> Void
    func syncMapProductsOutcome() async -> SpcMapSyncOutcome
    func syncTextProducts() async -> Void
    func syncConvectiveOutlooks() async -> Void
    func syncMesoscaleDiscussions() async -> Void
}

extension SpcSyncing {
    func syncMapProductsOutcome() async -> SpcMapSyncOutcome {
        await syncMapProducts()
        return .accepted
    }
}
