//
//  HomeRefreshPolicies.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import SwiftUI
import CoreLocation

struct RefreshContext {
    let coordinates: CLLocationCoordinate2D
    let refreshedAt: Date
}

struct AlertRefreshPolicy: Sendable {
    let minimumSyncInterval: TimeInterval

    init(minimumSyncInterval: TimeInterval = 2 * 60) {
        self.minimumSyncInterval = minimumSyncInterval
    }

    func shouldSync(now: Date, lastSync: Date?, force: Bool) -> Bool {
        if force { return true }
        guard let lastSync else { return true }
        return now.timeIntervalSince(lastSync) >= minimumSyncInterval
    }
}

struct MapProductRefreshPolicy: Sendable {
    let minimumSyncInterval: TimeInterval

    init(minimumSyncInterval: TimeInterval = 10 * 60) {
        self.minimumSyncInterval = minimumSyncInterval
    }

    func shouldSync(now: Date, lastSync: Date?, force: Bool) -> Bool {
        if force { return true }
        guard let lastSync else { return true }
        return now.timeIntervalSince(lastSync) >= minimumSyncInterval
    }
}

extension HomeView {
    static func shouldPerformLocationRefresh(
        lastRefreshContext: RefreshContext?,
        snapshot: LocationSnapshot,
        force: Bool,
        minimumForegroundRefreshInterval: TimeInterval = 3 * 60,
        minimumRefreshDistanceMeters: CLLocationDistance = 800
    ) -> Bool {
        if force {
            return true
        }

        guard let lastRefreshContext else {
            return true
        }

        let currentLocation = CLLocation(
            latitude: snapshot.coordinates.latitude,
            longitude: snapshot.coordinates.longitude
        )
        let previousLocation = CLLocation(
            latitude: lastRefreshContext.coordinates.latitude,
            longitude: lastRefreshContext.coordinates.longitude
        )
        let elapsed = snapshot.timestamp.timeIntervalSince(lastRefreshContext.refreshedAt)
        let distance = currentLocation.distance(from: previousLocation)
        return elapsed >= minimumForegroundRefreshInterval || distance >= minimumRefreshDistanceMeters
    }

    static func readinessState(
        startupState: LocationStartupState,
        hasContext: Bool,
        hasResolvedLocalData: Bool,
        stormRisk: StormRiskLevel?,
        severeRisk: SevereWeatherThreat?,
        fireRisk: FireRiskLevel?
    ) -> SummaryReadinessState {
        switch startupState {
        case .idle, .requestingAuthorization, .acquiringLocation:
            return SummaryReadinessState.loadingLocation
        case .resolvingContext:
            return SummaryReadinessState.resolvingLocalContext
        case .failed:
            return SummaryReadinessState.locationUnavailable
        case .ready:
            if hasContext == false {
                return SummaryReadinessState.loadingLocation
            }
            if hasResolvedLocalData == false &&
                (stormRisk == nil || severeRisk == nil || fireRisk == nil) {
                return SummaryReadinessState.loadingLocalData
            }
            return SummaryReadinessState.ready
        }
    }
}
