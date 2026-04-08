//
//  HomeIngestionSupport.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation

struct LocationScopedDataSnapshot: Sendable {
    let stormRisk: StormRiskLevel
    let severeRisk: SevereWeatherThreat
    let fireRisk: FireRiskLevel
    let mesos: [MdDTO]
    let watches: [WatchRowDTO]
}

struct HotFeedSnapshot: Sendable {
    let mesos: [MdDTO]
    let watches: [WatchRowDTO]
}

enum IngestionSupport {
    static func syncHotFeeds(
        spcSync: any SpcSyncing,
        arcusSync: any ArcusAlertSyncing,
        context: LocationContext
    ) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await spcSync.syncMesoscaleDiscussions() }
            group.addTask { await arcusSync.sync(context: context) }
            await group.waitForAll()
        }
    }

    static func readLocationScopedSnapshot(
        spcRisk: any SpcRiskQuerying,
        arcusQuery: any ArcusAlertQuerying,
        context: LocationContext
    ) async throws -> LocationScopedDataSnapshot {
        let coord = context.snapshot.coordinates
        async let stormRisk = spcRisk.getStormRisk(for: coord)
        async let severeRisk = spcRisk.getSevereRisk(for: coord)
        async let fireRisk = spcRisk.getFireRisk(for: coord)
        async let mesos = spcRisk.getActiveMesos(at: .now, for: coord)
        async let watches = arcusQuery.getActiveWatches(context: context)

        return try await .init(
            stormRisk: stormRisk,
            severeRisk: severeRisk,
            fireRisk: fireRisk,
            mesos: mesos,
            watches: watches
        )
    }

    static func readHotFeedSnapshot(
        spcRisk: any SpcRiskQuerying,
        arcusQuery: any ArcusAlertQuerying,
        context: LocationContext
    ) async throws -> HotFeedSnapshot {
        let coord = context.snapshot.coordinates
        async let mesos = spcRisk.getActiveMesos(at: .now, for: coord)
        async let watches = arcusQuery.getActiveWatches(context: context)

        return try await .init(mesos: mesos, watches: watches)
    }
}
