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
    case current
    case staleRefreshing
    case degraded
    case unavailable

    static func from(
        readinessState: SummaryReadinessState,
        hasCachedContent: Bool,
        hasLiveContent: Bool,
        isRefreshing: Bool,
        isOffline: Bool
    ) -> TodayContentState {
        if readinessState == .locationUnavailable {
            return .unavailable
        }

        if hasCachedContent {
            if isRefreshing {
                return isOffline ? .staleRefreshing : .cachedRefreshing
            }
            return isOffline ? .degraded : .current
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
        case .cachedRefreshing, .staleRefreshing:
            true
        case .noCacheResolving, .current, .degraded, .unavailable:
            false
        }
    }

    var allowsSectionResolvingTreatment: Bool {
        self != .cachedRefreshing
    }
}
