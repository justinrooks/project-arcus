//
//  HomeSnapshotStore.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import CoreLocation

protocol HomeSnapshotReading: Sendable {
    func loadSnapshot(
        for context: LocationContext?,
        weather: SummaryWeather?,
        freshness: HomeFreshnessState
    ) async throws -> HomeSnapshot
}

actor HomeSnapshotStore: HomeSnapshotReading {
    private let spcRisk: any SpcRiskQuerying
    private let spcOutlook: any SpcOutlookQuerying
    private let arcusAlerts: any ArcusAlertQuerying

    init(
        spcRisk: any SpcRiskQuerying,
        spcOutlook: any SpcOutlookQuerying,
        arcusAlerts: any ArcusAlertQuerying
    ) {
        self.spcRisk = spcRisk
        self.spcOutlook = spcOutlook
        self.arcusAlerts = arcusAlerts
    }

    func loadSnapshot(
        for context: LocationContext?,
        weather: SummaryWeather?,
        freshness: HomeFreshnessState
    ) async throws -> HomeSnapshot {
        guard let context else {
            let outlooks = try await spcOutlook.getConvectiveOutlooks()
            let latestOutlook = outlooks.max(by: { $0.published < $1.published })
            return HomeSnapshot(
                weather: weather,
                outlooks: outlooks,
                latestOutlook: latestOutlook,
                freshness: freshness
            )
        }

        let coord = context.snapshot.coordinates

        async let stormRisk = spcRisk.getStormRisk(for: coord)
        async let severeRisk = spcRisk.getSevereRisk(for: coord)
        async let fireRisk = spcRisk.getFireRisk(for: coord)
        async let mesos = spcRisk.getActiveMesos(at: .now, for: coord)
        async let watches = arcusAlerts.getActiveWatches(context: context)
        async let outlooks = spcOutlook.getConvectiveOutlooks()

        let resolvedOutlooks = try await outlooks
        let latestOutlook = resolvedOutlooks.max(by: { $0.published < $1.published })

        return try await HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            weather: weather,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            mesos: mesos,
            watches: watches,
            outlooks: resolvedOutlooks,
            latestOutlook: latestOutlook,
            freshness: freshness
        )
    }
}
