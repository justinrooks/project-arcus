//
//  FeedCache.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/14/25.
//

import Foundation
import SwiftData

enum FeedKey {
    static let outlookDay1RSS      = "outlook.day1"
//    static let outlookDay1Points   = "outlook.points.day1"
    static let mesoRSS             = "mesos"
    static let categoricalGeoJSON  = "categorical.geojson"
    static let tornadoGeoJSON      = "tornado.geojson"
    static let windGeoJSON         = "wind.geojson"
    static let hailGeoJSON         = "hail.geojson"
}

struct FeedCachePatch: Sendable {
    var etag: String?
    var lastModified: String?
    var lastSuccessAt: Date?
    var nextPlannedAt: Date?
    var body: Data?
}

@Model
final class FeedCache: Sendable {
    // One row per feed (keyed by `feedKey`)
        @Attribute(.unique) var feedKey: String           // e.g., "outlook.day1", "mesoRSS"
        var etag: String?
        var lastModified: String?
        var lastSuccessAt: Date?
        var nextPlannedAt: Date?
        var bodyHash: String?                              // when no validators exist
        var body: Data?                                    // raw payload (RSS / MD index / points)
        var createdAt: Date
        var updatedAt: Date

        init(feedKey: String) {
            self.feedKey = feedKey
            self.createdAt = .now
            self.updatedAt = .now
        }
}
