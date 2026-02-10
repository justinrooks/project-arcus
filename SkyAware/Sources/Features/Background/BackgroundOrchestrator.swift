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
    let watchNotificationsEnabled: Bool
}

protocol NotificationSettingsProviding: Sendable {
    func current() async -> NotificationSettings
}

actor BackgroundOrchestrator {
    private let logger = Logger.backgroundOrchestrator
    private let signposter:OSSignposter
    private let spcProvider: any SpcSyncing & SpcRiskQuerying & SpcOutlookQuerying
    private let nwsProvider: any NwsSyncing & NwsRiskQuerying
    private let locationProvider: LocationProvider
    private let refreshPolicy: RefreshPolicy
    private let morningEngine: MorningEngine
    private let mesoEngine: MesoEngine
    private let watchEngine: WatchEngine
    private let healthStore: BgHealthStore
    private let cadence: CadencePolicy
    private let notificationSettingsProvider: NotificationSettingsProviding
    
    private let clock = ContinuousClock()
    
    init(
        spcProvider: any SpcSyncing & SpcRiskQuerying & SpcOutlookQuerying,
        nwsProvider: any NwsSyncing & NwsRiskQuerying,
        locationProvider: LocationProvider,
        policy: RefreshPolicy,
        engine: MorningEngine,
        mesoEngine: MesoEngine,
        watchEngine: WatchEngine,
        health: BgHealthStore,
        cadence: CadencePolicy,
        notificationSettingsProvider: NotificationSettingsProviding
    ) {
        self.spcProvider = spcProvider
        self.nwsProvider = nwsProvider
        self.locationProvider = locationProvider
        morningEngine = engine
        refreshPolicy = policy
        healthStore = health
        self.cadence = cadence
        self.mesoEngine = mesoEngine
        self.watchEngine = watchEngine
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
            var didWatchNotify = false
            var noNotifyReasons: [String] = []
            var feedsChanged: Set<Feed> = []
            
            do {
                try Task.checkCancellation()
                let settings = await notificationSettingsProvider.current()
                
                // MARK: Get fresh data
                logger.info("Starting SPC sync")
                let syncInterval = signposter.beginInterval("SPC Sync")
                await spcProvider.sync()
                signposter.endInterval("SPC Sync", syncInterval)
                logger.info("SPC sync completed")
                feedsChanged.formUnion([.outlookDay1, .meso])
                
                // - Get the latest convective outlook details
                logger.debug("Fetching latest convective outlook")
                let outlook = try await spcProvider.getLatestConvectiveOutlook()
                logger.debug("Latest convective outlook fetched")
                
                try Task.checkCancellation()
                
                // MARK: Get location snapshot
                logger.debug("Attempting to obtain latest location snapshot")
                guard let snap = await locationProvider.snapshot() else {
                    logger.info("No location snapshot available; rechecking in 20m")
                    let nextRun = refreshPolicy.getNextRunTime(for: .short(20))
                    let end = Date()
                    let active = clock.now - startInstant
                    
                    try? await recordBgRun(start: start, end: end, result: .skipped, didNotify: false, notificationReason: "No location snapshot available. Rechecking in 20m", nextRun: nextRun, cadence: 0, cadenceReason: "Early exit", active: active)
                    
                    return .init(next: nextRun, result: .skipped, didNotify: false, feedsChanged: feedsChanged)
                }
                
                logger.debug("Location snapshot obtained; preparing risk queries and placemark update")
                let updatedSnap = await locationProvider.ensurePlacemark(for: snap.coordinates)
                
                // Keep watch data current each run so cadence decisions can react to active watches.
                await nwsProvider.sync(for: updatedSnap.coordinates)
                
                // MARK: Get Risk Status
                let (severeRisk, stormRisk, activeMesos, activeWatches) = try await withTimeout(seconds: 8, clock: clock) {
                    async let sr = self.spcProvider.getSevereRisk(for: snap.coordinates)
                    async let cr = self.spcProvider.getStormRisk(for: snap.coordinates)
                    async let mesos = self.spcProvider.getActiveMesos(at: .now, for: updatedSnap.coordinates)
                    async let watches = self.nwsProvider.getActiveWatches(for: updatedSnap.coordinates)
                    return try await (sr, cr, mesos, watches)
                }
                let inMeso = activeMesos.isEmpty == false
                let inWatch = activeWatches.isEmpty == false
                
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
                            placeMark: updatedSnap.placemarkSummary ?? "Unknown"
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
                            location: updatedSnap.coordinates,
                            placeMark: updatedSnap.placemarkSummary ?? "Unknown"
                        )
                    )
                    if !didMesoNotify { noNotifyReasons.append("Meso notification skipped") }
                } else { noNotifyReasons.append("Meso notification disabled") }
                
                if settings.watchNotificationsEnabled {
                    // MARK: Send Watch Notification
                    signposter.emitEvent("Watch Notification")
                    didWatchNotify = await watchEngine.run(
                        ctx: .init(
                            now: .now,
                            localTZ: .current,
                            location: updatedSnap.coordinates,
                            placeMark: updatedSnap.placemarkSummary ?? "Unknown"
                        )
                    )
                    if !didWatchNotify { noNotifyReasons.append("Watch notification skipped") }
                } else { noNotifyReasons.append("Watch notification disabled") }
                
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
                let didNotify = didMorningNotify || didMesoNotify || didWatchNotify
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
