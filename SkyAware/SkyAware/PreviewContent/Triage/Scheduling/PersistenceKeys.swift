//
//  PersistenceKeys.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import Foundation

enum K {
    enum ETag {
        static let outlookDay1 = "etag.outlookDay1"
        static let mesoIndex   = "etag.mesoIndex"
    }
    enum Hash {
        static let outlookPoints = "hash.outlookPoints"
        static let latestMDs     = "hash.latestMDs"
    }
    enum Timestamp {
        static let lastSuccessOutlook = "ts.lastSuccess.outlookDay1"
        static let lastSuccessMeso    = "ts.lastSuccess.meso"
        static let nextCheckOutlook   = "ts.nextCheck.outlookDay1"
        static let nextCheckMeso      = "ts.nextCheck.meso"
    }
    enum Risk {
        static let lastTier   = "risk.lastTier"
        static let lastMDBand = "risk.lastMDBand"
    }
    enum Hysteresis {
        static let pendingTierDownAt = "hyst.tier.pendingAt"
        static let pendingBandDownAt = "hyst.band.pendingAt"
        static let minStableSeconds  = "hyst.minStable"
    }
}
