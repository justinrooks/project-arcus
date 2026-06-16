//
//  LocalAlertsDisplayState.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

enum LocalAlertsPresentationState: Sendable, Equatable {
    case unavailable
    case loading
    case alerts
    case empty
}

enum LocalAlertsDisplayState: Sendable, Equatable {
    enum Content: Sendable, Equatable {
        case empty
        case populated
    }

    enum Source: Sendable, Equatable {
        case live
        case cached
    }

    enum UnavailableReason: Sendable, Equatable {
        case locationUnavailable
        case noUsefulAlertState
    }

    case noCacheResolving
    case current(content: Content, source: Source)
    case cachedRefreshing(content: Content)
    case staleOrDegraded(content: Content)
    case unavailable(reason: UnavailableReason)

    static func from(
        todayContentState: TodayContentState,
        hasCachedProjection: Bool,
        isCurrentContextResolvedInPipeline: Bool,
        lastHotAlertsLoadAt: Date?,
        hasActiveAlerts: Bool,
        isLocationUnavailable: Bool
    ) -> LocalAlertsDisplayState {
        if isLocationUnavailable {
            return .unavailable(reason: .locationUnavailable)
        }

        let content: Content = hasActiveAlerts ? .populated : .empty

        if isCurrentContextResolvedInPipeline {
            return .current(content: content, source: .live)
        }

        switch todayContentState {
        case .noCacheResolving:
            return .noCacheResolving

        case .cachedRefreshing:
            if hasCachedProjection {
                guard lastHotAlertsLoadAt != nil || hasActiveAlerts else {
                    return .unavailable(reason: .noUsefulAlertState)
                }
                return .cachedRefreshing(content: content)
            }
            return .noCacheResolving

        case .staleRefreshing, .degraded:
            if hasCachedProjection {
                guard lastHotAlertsLoadAt != nil || hasActiveAlerts else {
                    return .unavailable(reason: .noUsefulAlertState)
                }
                return .staleOrDegraded(content: content)
            }
            return .current(content: content, source: .live)

        case .current:
            if hasCachedProjection {
                guard lastHotAlertsLoadAt != nil || hasActiveAlerts else {
                    return .unavailable(reason: .noUsefulAlertState)
                }
                return .current(content: content, source: .cached)
            }
            return .current(content: content, source: .live)

        case .unavailable:
            return .unavailable(reason: .noUsefulAlertState)
        }
    }

    var presentationState: LocalAlertsPresentationState {
        switch self {
        case .noCacheResolving:
            .loading
        case .current(let content, _), .cachedRefreshing(let content), .staleOrDegraded(let content):
            content == .populated ? .alerts : .empty
        case .unavailable:
            .unavailable
        }
    }

    var showsLoadingCopy: Bool {
        self == .noCacheResolving
    }

    var showsOfflineStatusCopy: Bool {
        switch self {
        case .staleOrDegraded(content: .populated):
            true
        case .noCacheResolving,
            .current,
            .cachedRefreshing,
            .staleOrDegraded(content: .empty),
            .unavailable:
            false
        }
    }

    var usesSummaryResolvingTreatment: Bool {
        false
    }
}
