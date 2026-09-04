//
//  HomeFreshnessState.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

struct HomeFreshnessState: Sendable, Equatable {
    var lastHotFeedSyncAt: Date?
    var lastMapProductSyncAt: Date?
    var lastOutlookSyncAt: Date?
    var lastWeatherSyncAt: Date?
    var lastResolvedRefreshKey: LocationContext.RefreshKey?

    init(
        lastHotFeedSyncAt: Date? = nil,
        lastMapProductSyncAt: Date? = nil,
        lastOutlookSyncAt: Date? = nil,
        lastWeatherSyncAt: Date? = nil,
        lastResolvedRefreshKey: LocationContext.RefreshKey? = nil
    ) {
        self.lastHotFeedSyncAt = lastHotFeedSyncAt
        self.lastMapProductSyncAt = lastMapProductSyncAt
        self.lastOutlookSyncAt = lastOutlookSyncAt
        self.lastWeatherSyncAt = lastWeatherSyncAt
        self.lastResolvedRefreshKey = lastResolvedRefreshKey
    }
}
