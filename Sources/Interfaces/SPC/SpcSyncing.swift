//
//  SpcSyncing.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/17/25.
//

import Foundation

enum SpcMapSourceIdentity: Sendable, Equatable {
    case forecast(issued: Date, valid: Date, expires: Date)
    case acceptedAllClear(at: Date)

    var persistenceToken: String {
        switch self {
        case .forecast(let issued, let valid, let expires):
            return "forecast:\(Self.token(for: issued)):\(Self.token(for: valid)):\(Self.token(for: expires))"
        case .acceptedAllClear(let date):
            return "all-clear:\(Self.token(for: date))"
        }
    }

    private static func token(for date: Date) -> String {
        String(date.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
    }
}

enum SpcMapSyncDomainOutcome: Sendable, Equatable {
    case accepted
    case rejected
    case skipped
    case failed

    var authorizesProjection: Bool {
        self == .accepted || self == .skipped
    }
}

enum SpcMapTransportSource: Sendable, Equatable {
    case live
    case revalidated
    case localCache
    case errorFallback
}

struct SpcMapSyncOutcome: Sendable, Equatable {
    let convective: SpcMapSyncDomainOutcome
    let fire: SpcMapSyncDomainOutcome
    let convectiveSource: SpcMapSourceIdentity?
    let fireSource: SpcMapSourceIdentity?
    let convectiveTransportSource: SpcMapTransportSource?
    let fireTransportSource: SpcMapTransportSource?

    init(
        convective: SpcMapSyncDomainOutcome,
        fire: SpcMapSyncDomainOutcome,
        convectiveSource: SpcMapSourceIdentity? = nil,
        fireSource: SpcMapSourceIdentity? = nil,
        convectiveTransportSource: SpcMapTransportSource? = nil,
        fireTransportSource: SpcMapTransportSource? = nil
    ) {
        self.convective = convective
        self.fire = fire
        self.convectiveSource = convectiveSource
        self.fireSource = fireSource
        self.convectiveTransportSource = convectiveTransportSource
        self.fireTransportSource = fireTransportSource
    }

    static let accepted = SpcMapSyncOutcome(convective: .accepted, fire: .accepted)
    static let rejected = SpcMapSyncOutcome(convective: .rejected, fire: .rejected)
    static let skipped = SpcMapSyncOutcome(convective: .skipped, fire: .skipped)
    static let failed = SpcMapSyncOutcome(convective: .failed, fire: .failed)

    var isFullyAccepted: Bool {
        convective == .accepted && fire == .accepted
    }
}

enum SpcMesoSyncOutcome: Sendable, Equatable {
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

enum SpcOutlookSyncOutcome: Sendable, Equatable {
    case live
    case revalidated
    case localCache
    case errorFallback
    case rejected
    case failed
    case cancelled

    static var accepted: Self { .live }
    static var fallback: Self { .errorFallback }

    var isCanonicalAcceptance: Bool {
        self == .live || self == .revalidated
    }
}

protocol SpcSyncing: Sendable {//where Self: Actor {
    func sync() async -> Void
    func syncMapProducts() async -> Void
    func syncMapProductsOutcome() async -> SpcMapSyncOutcome
    func syncTextProducts() async -> Void
    func syncConvectiveOutlooks() async -> SpcOutlookSyncOutcome
    func syncMesoscaleDiscussions() async -> SpcMesoSyncOutcome
}
