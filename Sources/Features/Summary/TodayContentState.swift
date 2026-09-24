//
//  TodayContentState.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

enum TodayContentState: Sendable, Equatable {
    case noCacheResolving
    case cachedRefreshing
    case quietRefreshing
    case current
    case staleRefreshing
    case refreshFailedWithCache
    case degraded
    case unavailable

    static func from(
        readinessState: SummaryReadinessState,
        hasCachedContent: Bool,
        hasLiveContent: Bool,
        isRefreshing: Bool,
        isOffline: Bool,
        isManualRefreshInFlight: Bool = false,
        didManualRefreshFail: Bool = false
    ) -> TodayContentState {
        if readinessState == .locationUnavailable {
            return .unavailable
        }

        if hasCachedContent {
            if isManualRefreshInFlight {
                return isOffline ? .staleRefreshing : .cachedRefreshing
            }
            if isOffline { return .degraded }
            if didManualRefreshFail { return .refreshFailedWithCache }
            if isRefreshing { return .quietRefreshing }
            return .current
        }

        if hasLiveContent {
            return isOffline ? .degraded : .current
        }

        if isRefreshing ||
            readinessState == .loadingLocation ||
            readinessState == .resolvingLocalContext ||
            readinessState == .loadingLocalData
        {
            return .noCacheResolving
        }

        return .unavailable
    }

    var showsResolvingSurface: Bool {
        self == .noCacheResolving
    }

    var showsCalmUpdatingCue: Bool {
        switch self {
        case .refreshFailedWithCache:
            true
        case .noCacheResolving, .cachedRefreshing, .quietRefreshing, .current,
             .staleRefreshing, .degraded, .unavailable:
            false
        }
    }

    var manualRefreshStatusMessage: String? {
        switch self {
        case .refreshFailedWithCache:
            "Couldn't update. Showing saved conditions."
        case .noCacheResolving, .cachedRefreshing, .quietRefreshing, .current,
             .staleRefreshing, .degraded, .unavailable:
            nil
        }
    }

    var allowsSectionResolvingTreatment: Bool {
        switch self {
        case .cachedRefreshing, .quietRefreshing, .staleRefreshing, .refreshFailedWithCache:
            false
        case .noCacheResolving, .current, .degraded, .unavailable:
            true
        }
    }

    var suppressesRoutineRefreshMotion: Bool {
        switch self {
        case .cachedRefreshing, .quietRefreshing, .staleRefreshing, .refreshFailedWithCache:
            true
        case .noCacheResolving, .current, .degraded, .unavailable:
            false
        }
    }
}
