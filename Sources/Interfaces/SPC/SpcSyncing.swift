//
//  SpcSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation

enum SpcMapSyncDomainOutcome: Sendable, Equatable {
    case accepted
    case rejected
    case skipped
    case failed

    var authorizesProjection: Bool {
        self == .accepted || self == .skipped
    }
}

struct SpcMapSyncOutcome: Sendable, Equatable {
    let convective: SpcMapSyncDomainOutcome
    let fire: SpcMapSyncDomainOutcome

    static let accepted = SpcMapSyncOutcome(convective: .accepted, fire: .accepted)
    static let rejected = SpcMapSyncOutcome(convective: .rejected, fire: .rejected)
    static let skipped = SpcMapSyncOutcome(convective: .skipped, fire: .skipped)
    static let failed = SpcMapSyncOutcome(convective: .failed, fire: .failed)

    var isFullyAccepted: Bool {
        convective == .accepted && fire == .accepted
    }
}

protocol SpcSyncing: Sendable {//where Self: Actor {
    func sync() async -> Void
    func syncMapProducts() async -> Void
    func syncMapProductsOutcome() async -> SpcMapSyncOutcome
    func syncTextProducts() async -> Void
    func syncConvectiveOutlooks() async -> Void
    func syncMesoscaleDiscussions() async -> Void
}
