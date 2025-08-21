//
//  MemoryStore.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import Foundation

public final class MemoryStore: KeyValueStore {
    private var bag: [String: Data] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {}

    public func get<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        if T.self == String.self, let data = bag[key], let s = String(data: data, encoding: .utf8) { return s as? T }
        guard let data = bag[key] else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    public func set<T: Encodable>(_ key: String, value: T?) {
        guard let value else { bag.removeValue(forKey: key); return }
        if let s = value as? String, let d = s.data(using: .utf8) { bag[key] = d; return }
        if let d = value as? Data { bag[key] = d; return }
        if let d = try? encoder.encode(value) { bag[key] = d }
    }

    public func remove(_ key: String) { bag.removeValue(forKey: key) }
}

//•    Set an ETag, restart the app, confirm it persists.
//•    Write nextPlannedAt, display Relative.fromNow(nextPlannedAt) in the Summary header.
//•    Swap UserDefaultsStore() with MemoryStore() in the Sandbox to prove everything still works.


//
//// Create your persistence (app runtime)
//let persistence = PersistenceAdapter(store: UserDefaultsStore())
//
//// Save ETag/Last‑Modified after a successful fetch:
//persistence.outlookETag = HTTPCacheTag(etag: "W/\"512f-63c469c536400\"", lastModified: "Tue, 12 Aug 2025 19:20:30 GMT")
//
//// Save timestamps for freshness UI:
//var times = persistence.outlookTimes
//times.lastSuccessAt = Date()
//times.nextPlannedAt = Date().addingTimeInterval(45 * 60)
//persistence.outlookTimes = times
//
//// Remember last known risk tier and MD band (for Notifier + UX):
//persistence.lastRiskTierRaw = RiskTier.slight.rawValue
//persistence.lastMDBandRaw   = WatchProbBand.p20_39.rawValue
//
//// Read back later:
//let etag = persistence.outlookETag?.etag
//let lastUpdatedText = times.lastSuccessAt.map { Relative.fromNow($0) } ?? "never"
