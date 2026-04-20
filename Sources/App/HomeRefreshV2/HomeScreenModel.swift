//
//  HomeScreenModel.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeScreenModel {
    private let coordinator: HomeIngestionCoordinator

    private(set) var snapshot: HomeSnapshot
    private(set) var resolutionState = SummaryResolutionState()
    private(set) var isRefreshing = false
    private(set) var lastErrorDescription: String?

    init(
        coordinator: HomeIngestionCoordinator,
        initialSnapshot: HomeSnapshot = .empty
    ) {
        self.coordinator = coordinator
        self.snapshot = initialSnapshot
    }

    func refresh(_ trigger: HomeRefreshTrigger) async {
        isRefreshing = true
        lastErrorDescription = nil

        do {
            snapshot = try await coordinator.enqueueAndWait(trigger)
        } catch {
            lastErrorDescription = error.localizedDescription
        }

        isRefreshing = false
    }
}
