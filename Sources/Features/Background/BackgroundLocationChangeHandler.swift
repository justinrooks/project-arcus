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
    private let coordinator: any HomeIngestionCoordinating
    private let watchEngine: WatchEngine
    private var activeTask: Task<Void, Never>?

    init(
        coordinator: any HomeIngestionCoordinating,
        watchEngine: WatchEngine
    ) {
        self.coordinator = coordinator
        self.watchEngine = watchEngine
    }

    func handleLocationChange() async {
        if let activeTask {
            logger.debug("Background location-change sync already in flight; joining existing task")
            await activeTask.value
            return
        }

        let coordinator = self.coordinator
        let watchEngine = self.watchEngine
        let logger = self.logger

        let task = Task {
            do {
                let snapshot = try await coordinator.enqueueAndWait(
                    .backgroundLocationChange,
                    locationContext: nil,
                    remoteAlertContext: nil
                )
                guard let locationSnapshot = snapshot.locationSnapshot else {
                    logger.notice("Skipping background location-change watch evaluation because no location snapshot was returned")
                    return
                }

                _ = await watchEngine.run(
                    ctx: .init(
                        now: .now,
                        localTZ: .current,
                        location: locationSnapshot.coordinates,
                        placeMark: locationSnapshot.placemarkSummary ?? "Unknown"
                    ),
                    watches: snapshot.watches
                )
            } catch {
                logger.error(
                    "Failed to execute background location-change ingestion: \(error.localizedDescription, privacy: .public)"
                )
            }
        }

        activeTask = task
        await task.value
        activeTask = nil
    }
}
