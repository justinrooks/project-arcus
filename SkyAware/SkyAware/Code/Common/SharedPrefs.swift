//
//  SharedPrefs.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/13/25.
//

import Foundation

enum DataFreshness: Equatable {
    case fresh(minutes: Int)     // updated within threshold
    case stale(minutes: Int)     // older than threshold
    case neverUpdated            // no record exists

    var description: String {
        switch self {
        case .fresh(let mins):
            return "Updated \(mins) min ago"
        case .stale(let mins):
            return "Stale (\(mins) min ago)"
        case .neverUpdated:
            return "Never updated"
        }
    }
}

enum SharedPrefs {
    static let suite = UserDefaults(suiteName: "com.justinrooks.skyaware")!
    
    private static let lastGlobalSuccessAtKey = "lastGlobalSuccessAt"
    
    static func recordGlobalSuccess(_ date: Date = .now) {
        suite.set(date.timeIntervalSince1970, forKey: lastGlobalSuccessAtKey)
    }
    
    static func lastGlobalSuccess() -> Date? {
        let time = suite.double(forKey: lastGlobalSuccessAtKey)
        return time > 0 ? Date(timeIntervalSince1970: time) : nil
    }
}

extension SharedPrefs {
    static func wasUpdated(within minutes: Int) -> Bool {
        guard let last = lastGlobalSuccess() else { return false }
        return Date().timeIntervalSince(last) <= TimeInterval(minutes * 60)
    }

    static func freshness(thresholdMinutes: Int) -> DataFreshness {
        guard let last = lastGlobalSuccess() else {
            return .neverUpdated
        }

        let elapsedMinutes = Int(Date().timeIntervalSince(last) / 60)

        if elapsedMinutes <= thresholdMinutes {
            return .fresh(minutes: elapsedMinutes)
        } else {
            return .stale(minutes: elapsedMinutes)
        }
    }

    static func clearGlobalSuccess() {
        suite.removeObject(forKey: "lastGlobalSuccessAt")
    }
}
