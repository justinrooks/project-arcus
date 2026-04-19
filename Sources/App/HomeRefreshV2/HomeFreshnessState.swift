//
//  HomeFreshnessState.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

struct HomeFreshnessState: Sendable, Equatable {
    var lastHotFeedSyncAt: Date?
    var lastSlowFeedSyncAt: Date?
    var lastWeatherSyncAt: Date?
    var lastResolvedRefreshKey: LocationContext.RefreshKey?

    init(
        lastHotFeedSyncAt: Date? = nil,
        lastSlowFeedSyncAt: Date? = nil,
        lastWeatherSyncAt: Date? = nil,
        lastResolvedRefreshKey: LocationContext.RefreshKey? = nil
    ) {
        self.lastHotFeedSyncAt = lastHotFeedSyncAt
        self.lastSlowFeedSyncAt = lastSlowFeedSyncAt
        self.lastWeatherSyncAt = lastWeatherSyncAt
        self.lastResolvedRefreshKey = lastResolvedRefreshKey
    }
}
