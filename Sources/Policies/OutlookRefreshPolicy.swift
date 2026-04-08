//
//  OutlookRefreshPolicy.swift
//  SkyAware
//
//  Created by Codex on 2/7/26.
//

import Foundation

struct OutlookRefreshPolicy: Sendable {
    let minimumSyncInterval: TimeInterval

    init(minimumSyncInterval: TimeInterval = 15 * 60) {
        self.minimumSyncInterval = minimumSyncInterval
    }

    func shouldSync(now: Date, lastSync: Date?, force: Bool) -> Bool {
        if force { return true }
        guard let lastSync else { return true }
        return now.timeIntervalSince(lastSync) >= minimumSyncInterval
    }
}
