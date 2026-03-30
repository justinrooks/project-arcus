//
//  BackgroundOrchestrator.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/16/25.
//

import Foundation
import OSLog

enum Feed: String, CaseIterable { case outlookDay1, meso, watch, warning }

struct Outcome: Sendable {
    enum BackgroundResult: Sendable { case success, cancelled, failed, skipped }
    let next: Date
    let result: BackgroundResult
    let didNotify: Bool
    let feedsChanged: Set<Feed> // [.convective, .meso, .watch]
}

struct NotificationSettings: Sendable {
    let morningSummariesEnabled: Bool
    let mesoNotificationsEnabled: Bool
}

protocol NotificationSettingsProviding: Sendable {
    func current() async -> NotificationSettings
}

actor BackgroundOrchestrator {
    private let logger = Logger.backgroundOrchestrator
    private let signposter:OSSignposter
    private let spcProvider: any SpcSyncing & SpcRiskQuerying & SpcOutlookQuerying
    private let arcusProvider: any ArcusAlertSyncing & ArcusAlertQuerying
    private let locationContextResolver: any LocationContextResolving
    private let refreshPolicy: RefreshPolicy
    private let morningEngine: MorningEngine
    private let mesoEngine: MesoEngine
    private let healthStore: BgHealthStore
    private let cadence: CadencePolicy
    private let notificationSettingsProvider: NotificationSettingsProviding
    
    private let clock = ContinuousClock()
    private let requestedLocationTimeout: Double = 12
    private let maximumAcceptedLocationAge: TimeInterval = 5 * 60
    private let mapProductRefreshPolicy = MapProductRefreshPolicy()
    private let outlookRefreshPolicy = OutlookRefreshPolicy()
    private var lastMapProductSyncAt: Date?
    private var lastOutlookSyncAt: Date?
    
    init(
        spcProvider: any SpcSyncing & SpcRiskQuerying & SpcOutlookQuerying,
        arcusProvider: any ArcusAlertSyncing & ArcusAlertQuerying,
        locationContextResolver: any LocationContextResolving,
        policy: RefreshPolicy,
        engine: MorningEngine,
        mesoEngine: MesoEngine,
        health: BgHealthStore,
        cadence: CadencePolicy,
        notificationSettingsProvider: NotificationSettingsProviding
    ) {
        self.spcProvider = spcProvider
        self.arcusProvider = arcusProvider
        self.locationContextResolver = locationContextResolver
        morningEngine = engine
        refreshPolicy = policy
        healthStore = health
        self.cadence = cadence
        self.mesoEngine = mesoEngine
        self.notificationSettingsProvider = notificationSettingsProvider
        signposter = OSSignposter(logger: logger)
        logger.info("BackgroundOrchestrator initialized")
    }
    
    // MARK: Run Background Job
    func run() async -> Outcome {
        logger.notice("Background run started")
        // Mark the entire background job
        let runInterval = signposter.beginInterval("Background Run")
        let startInstant = clock.now
        let start = Date()
        
        return await withTaskCancellationHandler {
            var didMorningNotify = false
            var didMesoNotify = false
            var noNotifyReasons: [String] = []
            var feedsChanged: Set<Feed> = []
            
            do {
                try Task.checkCancellation()
                let settings = await notificationSettingsProvider.current()
                
                // MARK: Get fresh data
                logger.info("Starting slow SPC sync")
                let syncInterval = signposter.beginInterval("SPC Sync")
                let didSyncSlowFeeds = await syncSlowFeeds(now: start)
                signposter.endInterval("SPC Sync", syncInterval)
                logger.info("Slow SPC sync completed")
                if didSyncSlowFeeds {
                    feedsChanged.insert(.outlookDay1)
                }
                
                // - Get the latest convective outlook details
                logger.debug("Fetching latest convective outlook")
                let outlook = try await HTTPExecutionMode.$current.withValue(.background) {
                    try await spcProvider.getLatestConvectiveOutlook()
                }
                logger.debug("Latest convective outlook fetched")
                
                try Task.checkCancellation()
                
                // MARK: Get location snapshot
                logger.debug("Attempting to obtain latest device location for background run")
                guard let context = await resolvedLocationContext() else {
                    logger.info("No current location snapshot available; rechecking in 20m")
                    let nextRun = refreshPolicy.getNextRunTime(for: .short(20))
                    let end = Date()
                    let active = clock.now - startInstant
                    
                    try? await recordBgRun(start: start, end: end, result: .skipped, didNotify: false, notificationReason: "No location snapshot available. Rechecking in 20m", nextRun: nextRun, cadence: 0, cadenceReason: "Early exit", active: active)
                    
                    return .init(next: nextRun, result: .skipped, didNotify: false, feedsChanged: feedsChanged)
                }
                
                logger.debug("Location snapshot obtained; preparing risk queries and placemark update")
                await HTTPExecutionMode.$current.withValue(.background) {
                    await IngestionSupport.syncHotFeeds(
                        spcSync: spcProvider,
                        arcusSync: arcusProvider,
                        context: context
                    )
                }
                feedsChanged.formUnion([.meso, .watch])

                let localSnapshot = try await HTTPExecutionMode.$current.withValue(.background) {
                    try await withTimeout(seconds: 8, clock: clock) {
                        try await IngestionSupport.readLocationScopedSnapshot(
                            spcRisk: self.spcProvider,
                            arcusQuery: self.arcusProvider,
                            context: context
                        )
                    }
                }
                let severeRisk = localSnapshot.severeRisk
                let stormRisk = localSnapshot.stormRisk
                let fireRisk = localSnapshot.fireRisk
                let activeMesos = localSnapshot.mesos
                let activeWatches = localSnapshot.watches
                let inMeso = activeMesos.isEmpty == false
                let inWatch = activeWatches.isEmpty == false
                
                // TODO: Create a fireNotification flow
                // TODO: Put the flow behind an options flag
                
                // MARK: Send the AM Notification
                if settings.morningSummariesEnabled {
                    signposter.emitEvent("Morning Summary Notification")
                    didMorningNotify = await morningEngine.run(
                        ctx: .init(
                            now: .now,
                            lastConvectiveIssue: outlook?.published,
                            localTZ: .current,
                            quietHours: nil,
                            stormRisk: stormRisk,
                            severeRisk: severeRisk,
                            fireRisk: fireRisk,
                            placeMark: context.snapshot.placemarkSummary ?? "Unknown"
                        )
                    )
                    if !didMorningNotify { noNotifyReasons.append("Morning summary skipped") }
                } else { noNotifyReasons.append("Morning summary disabled") }
                
                if settings.mesoNotificationsEnabled {
                    // MARK: Send Meso Notification
                    signposter.emitEvent("Meso Notification")
                    didMesoNotify = await mesoEngine.run(
                        ctx: .init(
                            now: .now,
                            localTZ: .current,
                            location: context.snapshot.coordinates,
                            placeMark: context.snapshot.placemarkSummary ?? "Unknown"
                        ),
                        mesos: activeMesos
                    )
                    if !didMesoNotify { noNotifyReasons.append("Meso notification skipped") }
                } else { noNotifyReasons.append("Meso notification disabled") }
                                
                // MARK: Cadence decision
                let cadenceResult = cadence.decide(
                    for: .init(
                        now: .now,
                        categorical: stormRisk,
                        recentlyChangedLocation: false,
                        inMeso: inMeso,
                        inWatch: inWatch
                    )
                )
                
                let nextRun = refreshPolicy.getNextRunTime(for: cadenceResult.cadence)
                let end = Date()
                let active = clock.now - startInstant
                let didNotify = didMorningNotify || didMesoNotify
                let reasonNoNotify = didNotify ? nil : noNotifyReasons.joined(separator: "; ")

                try? await recordBgRun(
                    start: start,
                    end: end,
                    result: .success,
                    didNotify: didNotify,
                    notificationReason: reasonNoNotify,
                    nextRun: nextRun,
                    cadence: cadenceResult.cadence.getMinutes(),
                    cadenceReason: cadenceResult.reason,
                    active: active
                )
                
                signposter.endInterval("Background Run", runInterval)
                logger.notice("Background run finished with result: success")
                return .init(next: nextRun, result: .success, didNotify: didNotify, feedsChanged: feedsChanged)
            } catch {
                signposter.endInterval("Background Run", runInterval)
                let nextRun = refreshPolicy.getNextRunTime(for: .short(20))
                let end = Date()
                let active = clock.now - startInstant
                
                if error is CancellationError {
                    logger.notice("Background refresh was cancelled: \(error.localizedDescription, privacy: .public)")
                    try? await recordBgRun(start: start, end: end, result: .cancelled, didNotify: false, notificationReason: "Cancelled by iOS", nextRun: nextRun, cadence: 0, cadenceReason: "Background refresh cancelled", active: active)
                    return .init(next: nextRun, result: .cancelled, didNotify: false, feedsChanged: feedsChanged)
                } else {
                    logger.error("Error refreshing background data: \(error.localizedDescription, privacy: .public)")
                    
                    try? await recordBgRun(start: start, end: end, result: .failed, didNotify: false, notificationReason: "Error refreshing background data", nextRun: nextRun, cadence: 0, cadenceReason: "Background refresh failed", active: active)
                        
                    return .init(next: nextRun, result: .failed, didNotify: false, feedsChanged: feedsChanged)
                }
            }
        } onCancel: {
            logger.notice("Background run cancelled")
        }
    }

    private func resolvedLocationContext() async -> LocationContext? {
        do {
            return try await locationContextResolver.prepareCurrentContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false,
                authorizationTimeout: requestedLocationTimeout,
                locationTimeout: requestedLocationTimeout,
                maximumAcceptedLocationAge: maximumAcceptedLocationAge,
                placemarkTimeout: 8
            )
        } catch {
            logger.notice("Skipping location-dependent background work because location context is unavailable: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func syncSlowFeeds(now: Date) async -> Bool {
        let shouldSyncMapProducts = mapProductRefreshPolicy.shouldSync(
            now: now,
            lastSync: lastMapProductSyncAt,
            force: false
        )
        let shouldSyncOutlooks = outlookRefreshPolicy.shouldSync(
            now: now,
            lastSync: lastOutlookSyncAt,
            force: false
        )

        if shouldSyncMapProducts == false && shouldSyncOutlooks == false {
            return false
        }

        await HTTPExecutionMode.$current.withValue(.background) {
            await withTaskGroup(of: Void.self) { group in
                if shouldSyncMapProducts {
                    group.addTask { await self.spcProvider.syncMapProducts() }
                }
                if shouldSyncOutlooks {
                    group.addTask { await self.spcProvider.syncConvectiveOutlooks() }
                }
                await group.waitForAll()
            }
        }

        if shouldSyncMapProducts {
            lastMapProductSyncAt = now
        }
        if shouldSyncOutlooks {
            lastOutlookSyncAt = now
        }
        return true
    }
    
    // MARK: Convenience bg run record
    private func recordBgRun(
        start: Date,
        end: Date,
        result: Outcome.BackgroundResult,
        didNotify: Bool,
        notificationReason: String?,
        nextRun: Date,
        cadence: Int,
        cadenceReason: String?,
        active: Duration
    ) async throws {
        let duration = Int(end.timeIntervalSince(start))
        let outcome = result == .success ? 0 : 2
        
        try await healthStore
            .record(
                runId: UUID().uuidString,
                startedAt: start,
                endedAt: end,
                outcomeCode: outcome,
                didNotify: didNotify,
                reasonNoNotify: notificationReason,
                budgetSecUsed: duration,
                nextScheduledAt: nextRun,
                cadence: cadence,
                cadenceReason: cadenceReason,
                active: active
            )
    }
}
