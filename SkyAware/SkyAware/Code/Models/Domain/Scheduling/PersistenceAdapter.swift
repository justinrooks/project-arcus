//
//  PersistenceAdapter.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import Foundation

public protocol Persistence {
    // HTTP cache tags
    var outlookETag: HTTPCacheTag? { get set }
    var mesoIndexETag: HTTPCacheTag? { get set }

    // Hashes when no ETag/LM available
    var outlookPointsHash: String? { get set }
    var latestMDsHash: String? { get set }

    // Timestamps
    var outlookTimes: FeedTimestamps { get set }
    var mesoTimes: FeedTimestamps { get set }

    // Risk snapshots (for UX + notifications)
    var lastRiskTierRaw: Int? { get set }      // map to RiskTier as needed
    var lastMDBandRaw: Int? { get set }        // map to WatchProbBand as needed
}

public final class PersistenceAdapter: Persistence {
    private let store: KeyValueStore
    public init(store: KeyValueStore) { self.store = store }

    public var outlookETag: HTTPCacheTag? {
        get { store.get(K.ETag.outlookDay1, as: HTTPCacheTag.self) }
        set { store.set(K.ETag.outlookDay1, value: newValue) }
    }
    public var mesoIndexETag: HTTPCacheTag? {
        get { store.get(K.ETag.mesoIndex, as: HTTPCacheTag.self) }
        set { store.set(K.ETag.mesoIndex, value: newValue) }
    }

    public var outlookPointsHash: String? {
        get { store.get(K.Hash.outlookPoints, as: String.self) }
        set { store.set(K.Hash.outlookPoints, value: newValue) }
    }
    public var latestMDsHash: String? {
        get { store.get(K.Hash.latestMDs, as: String.self) }
        set { store.set(K.Hash.latestMDs, value: newValue) }
    }

    public var outlookTimes: FeedTimestamps {
        get { store.get(K.Timestamp.lastSuccessOutlook, as: FeedTimestamps.self) ?? FeedTimestamps() }
        set { store.set(K.Timestamp.lastSuccessOutlook, value: newValue) }
    }
    public var mesoTimes: FeedTimestamps {
        get { store.get(K.Timestamp.lastSuccessMeso, as: FeedTimestamps.self) ?? FeedTimestamps() }
        set { store.set(K.Timestamp.lastSuccessMeso, value: newValue) }
    }

    public var lastRiskTierRaw: Int? {
        get { store.get(K.Risk.lastTier, as: Int.self) }
        set { store.set(K.Risk.lastTier, value: newValue) }
    }
    public var lastMDBandRaw: Int? {
        get { store.get(K.Risk.lastMDBand, as: Int.self) }
        set { store.set(K.Risk.lastMDBand, value: newValue) }
    }
}
