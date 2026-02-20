//
//  WeatherKitRefreshPolicy.swift
//  SkyAware
//
//  Created by Codex on 2/19/26.
//

import Foundation

struct WeatherKitRefreshPolicy: Sendable {
    let minimumSyncInterval: TimeInterval

    init(minimumSyncInterval: TimeInterval = 30 * 60) {
        self.minimumSyncInterval = minimumSyncInterval
    }

    func shouldSync(now: Date, lastSync: Date?, force: Bool) -> Bool {
        if force { return true }
        guard let lastSync else { return true }
        return now.timeIntervalSince(lastSync) >= minimumSyncInterval
    }
}
