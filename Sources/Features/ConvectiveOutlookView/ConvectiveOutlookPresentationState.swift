//
//  ConvectiveOutlookPresentationState.swift
//  SkyAware
//
//  Created by Justin Rooks on 6/15/26.
//

import Foundation

enum ConvectiveOutlookRefreshStatus: Equatable {
    case loading
    case success(hasContent: Bool)
    case failed
    case stale
}

enum ConvectiveOutlookPresentationState: Equatable {
    enum Activity: Equatable {
        case current
        case refreshing
        case failed
        case stale
    }

    case loading
    case unavailable
    case empty(Activity)
    case populated(Activity)

    static func resolve(
        dtos: [ConvectiveOutlookDTO],
        refreshStatus: ConvectiveOutlookRefreshStatus,
        hasAcceptedEmptySnapshot: Bool = false,
        isOffline: Bool = false
    ) -> ConvectiveOutlookPresentationState {
        let activity: Activity
        if refreshStatus == .failed {
            activity = .failed
        } else if isOffline {
            activity = .stale
        } else {
            switch refreshStatus {
            case .loading: activity = .refreshing
            case .success: activity = .current
            case .failed: activity = .failed
            case .stale: activity = .stale
            }
        }

        if case .success(hasContent: false) = refreshStatus {
            return .empty(activity)
        }
        if hasAcceptedEmptySnapshot && dtos.isEmpty {
            return .empty(activity)
        }
        if dtos.isEmpty == false {
            return .populated(activity)
        }
        if isOffline {
            return .unavailable
        }
        switch refreshStatus {
        case .loading:
            return .loading
        case .success, .failed, .stale:
            return .unavailable
        }
    }

    var activity: Activity? {
        switch self {
        case .empty(let activity), .populated(let activity): activity
        case .loading, .unavailable: nil
        }
    }
}
