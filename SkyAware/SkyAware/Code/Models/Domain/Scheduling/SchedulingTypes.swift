//
//  SchedulingTypes.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import Foundation

// MARK: - Feeds we plan/schedule
enum Feed: String, CaseIterable { case outlookDay1, meso }

// MARK: - Risk tiers (categorical outlook at user location)
enum RiskTier: Int, CaseIterable, CustomStringConvertible {
    case none, slight, enhanced, moderate, high
    var description: String {
        switch self {
        case .none: return "None"
        case .slight: return "Slight"
        case .enhanced: return "Enhanced"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }
}

// MARK: - SPC MD "watch probability" bands
enum WatchProbBand: Int, CaseIterable, CustomStringConvertible {
    case lt20, p20_39, p40_59, gte60
    var description: String {
        switch self {
        case .lt20:   return "<20%"
        case .p20_39: return "20–39%"
        case .p40_59: return "40–59%"
        case .gte60:  return "≥60%"
        }
    }
}

struct MDContext: Equatable {
    var hasActiveMD: Bool
    var watchProbBand: WatchProbBand
    var coveringOrNearby: Bool  // within 25mi
}

// MARK: - Derived state the planner consumes
struct DerivedState: Equatable {
    var riskTier: RiskTier
    var md: MDContext
    var quietHours: Bool            // 23:00–06:00
    var lowPowerMode: Bool          // bump intervals when true
}

// MARK: - Planned check result
struct CheckPlan: Equatable {
    let feed: Feed
    let interval: TimeInterval
    let earliestBeginDate: Date
    let reason: String
}

// MARK: - Time helpers
extension Double {
    var minutes: TimeInterval { self * 60 }
    var hours: TimeInterval   { self * 3600 }
}

public struct HTTPCacheTag: Codable, Equatable {
    public var etag: String?
    public var lastModified: String?
    public init(etag: String? = nil, lastModified: String? = nil) {
        self.etag = etag; self.lastModified = lastModified
    }
}

public struct FeedTimestamps: Codable, Equatable {
    public var lastSuccessAt: Date?
    public var nextPlannedAt: Date?
    public init(lastSuccessAt: Date? = nil, nextPlannedAt: Date? = nil) {
        self.lastSuccessAt = lastSuccessAt; self.nextPlannedAt = nextPlannedAt
    }
}
