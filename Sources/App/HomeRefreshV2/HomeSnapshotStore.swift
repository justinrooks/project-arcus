//
//  HomeSnapshotStore.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import CoreLocation
import OSLog

protocol HomeSnapshotReading: Sendable {
    func loadSnapshot(
        for context: LocationContext?,
        weather: SummaryWeather?,
        freshness: HomeFreshnessState,
        refreshMesos: Bool
    ) async throws -> HomeSnapshot
}

actor HomeSnapshotStore: HomeSnapshotReading {
    private let spcRisk: any SpcRiskQuerying
    private let spcOutlook: any SpcOutlookQuerying
    private let arcusMesos: any ArcusMesoQuerying
    private let arcusAlerts: any ArcusAlertQuerying

    init(
        spcRisk: any SpcRiskQuerying,
        spcOutlook: any SpcOutlookQuerying,
        arcusAlerts: any ArcusAlertQuerying,
        arcusMesos: any ArcusMesoQuerying
    ) {
        self.spcRisk = spcRisk
        self.spcOutlook = spcOutlook
        self.arcusAlerts = arcusAlerts
        self.arcusMesos = arcusMesos
    }

    func loadSnapshot(
        for context: LocationContext?,
        weather: SummaryWeather?,
        freshness: HomeFreshnessState,
        refreshMesos: Bool
    ) async throws -> HomeSnapshot {
        guard let context else {
            let collection = try await spcOutlook.getConvectiveOutlookSnapshot()
            let outlooks = collection.outlooks
            logOutlookCounts(outlooks)
            let latestOutlook = outlooks.max(by: { $0.published < $1.published })
            return HomeSnapshot(
                weather: weather,
                outlooks: outlooks,
                latestOutlook: latestOutlook,
                hasAcceptedOutlookCollection: collection.isAccepted,
                freshness: freshness
            )
        }

        let coord = context.snapshot.coordinates

        async let stormRisk = spcRisk.getStormRisk(for: coord)
        async let severeRisk = spcRisk.getSevereRisk(for: coord)
        async let fireRisk = spcRisk.getFireRisk(for: coord)
        async let mesoCollection = refreshMesos ? loadMesos(for: context) : (mesos: [], isAccepted: false)
        async let alerts = arcusAlerts.getActiveAlerts(context: context)
        async let collection = spcOutlook.getConvectiveOutlookSnapshot()

        let resolvedCollection = try await collection
        let resolvedOutlooks = resolvedCollection.outlooks
        logOutlookCounts(resolvedOutlooks)
        let latestOutlook = resolvedOutlooks.max(by: { $0.published < $1.published })

        let resolvedMesos = try await mesoCollection
        return try await HomeSnapshot(
            locationSnapshot: context.snapshot,
            refreshKey: context.refreshKey,
            weather: weather,
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            mesos: resolvedMesos.mesos,
            hasAcceptedMesoCollection: resolvedMesos.isAccepted,
            alerts: alerts,
            outlooks: resolvedOutlooks,
            latestOutlook: latestOutlook,
            hasAcceptedOutlookCollection: resolvedCollection.isAccepted,
            freshness: freshness
        )
    }

    private func logOutlookCounts(_ outlooks: [ConvectiveOutlookDTO]) {
        let counts = (1...3).map { day in outlooks.filter { $0.day == day }.count }
        Logger.appHomeRefresh.info("Home outlook collection day1=\(counts[0], privacy: .public) day2=\(counts[1], privacy: .public) day3=\(counts[2], privacy: .public)")
    }

    private func loadMesos(for context: LocationContext) async throws -> (mesos: [MdDTO], isAccepted: Bool) {
        do {
            let response = try await arcusMesos.getActiveMesos(h3Cell: context.h3Cell)
            try Task.checkCancellation()
            switch response.source {
            case .live, .cacheRevalidated304:
                return (response.value.map(MdDTO.init(payload:)), true)
            case .localCache, .cacheFallback:
                return ([], false)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Logger.appHomeRefresh.error("Home meso read failed; preserving accepted projection")
            return ([], false)
        }
    }
}
