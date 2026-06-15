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
}

enum ConvectiveOutlookPresentationState: Equatable {
    case loading
    case unavailable
    case empty
    case populated

    static func resolve(
        dtos: [ConvectiveOutlookDTO],
        refreshStatus: ConvectiveOutlookRefreshStatus
    ) -> ConvectiveOutlookPresentationState {
        if dtos.isEmpty == false {
            return .populated
        }

        switch refreshStatus {
        case .loading:
            return .loading
        case .success(let hasContent):
            return hasContent ? .populated : .empty
        case .failed:
            return .unavailable
        }
    }
}
