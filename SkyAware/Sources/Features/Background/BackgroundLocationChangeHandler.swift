//
//  BackgroundLocationChangeHandler.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import OSLog

actor BackgroundLocationChangeHandler {
    private let logger = Logger.backgroundOrchestrator
    private let locationContextResolver: any LocationContextResolving
    private let spcSync: any SpcSyncing
    private let spcRisk: any SpcRiskQuerying
    private let arcusSync: any ArcusAlertSyncing
    private let arcusQuery: any ArcusAlertQuerying
    private let watchEngine: WatchEngine
    private var activeTask: Task<Void, Never>?

    init(
        locationContextResolver: any LocationContextResolving,
        spcSync: any SpcSyncing,
        spcRisk: any SpcRiskQuerying,
        arcusSync: any ArcusAlertSyncing,
        arcusQuery: any ArcusAlertQuerying,
        watchEngine: WatchEngine
    ) {
        self.locationContextResolver = locationContextResolver
        self.spcSync = spcSync
        self.spcRisk = spcRisk
        self.arcusSync = arcusSync
        self.arcusQuery = arcusQuery
        self.watchEngine = watchEngine
    }

    func handleLocationChange() async {
        if let activeTask {
            logger.debug("Background location-change sync already in flight; joining existing task")
            await activeTask.value
            return
        }

        let locationContextResolver = self.locationContextResolver
        let spcSync = self.spcSync
        let spcRisk = self.spcRisk
        let arcusSync = self.arcusSync
        let arcusQuery = self.arcusQuery
        let watchEngine = self.watchEngine
        let logger = self.logger

        let task = Task {
            guard let context = await Self.resolveContext(using: locationContextResolver) else { return }

            await HTTPExecutionMode.$current.withValue(.background) {
                await IngestionSupport.syncHotFeeds(
                    spcSync: spcSync,
                    arcusSync: arcusSync,
                    context: context
                )
            }

            do {
                let snapshot = try await HTTPExecutionMode.$current.withValue(.background) {
                    try await IngestionSupport.readHotFeedSnapshot(
                        spcRisk: spcRisk,
                        arcusQuery: arcusQuery,
                        context: context
                    )
                }

                _ = await watchEngine.run(
                    ctx: .init(
                        now: .now,
                        localTZ: .current,
                        location: context.snapshot.coordinates,
                        placeMark: context.snapshot.placemarkSummary ?? "Unknown"
                    ),
                    watches: snapshot.watches
                )
            } catch {
                logger.error("Failed to read hot-feed snapshot for background location change: \(error.localizedDescription, privacy: .public)")
            }
        }

        activeTask = task
        await task.value
        activeTask = nil
    }

    private static func resolveContext(
        using locationContextResolver: any LocationContextResolving
    ) async -> LocationContext? {
        do {
            return try await locationContextResolver.prepareCurrentContext(
                requiresFreshLocation: false,
                showsAuthorizationPrompt: false,
                authorizationTimeout: 30,
                locationTimeout: 12,
                maximumAcceptedLocationAge: 5 * 60,
                placemarkTimeout: 8
            )
        } catch {
            Logger.backgroundOrchestrator.notice(
                "Skipping background location-change ingest because location context is unavailable: \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }
}
