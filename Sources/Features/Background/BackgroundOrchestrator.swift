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
    enum BackgroundResult: Sendable { case success, cancelled, failed, skipped, expired }
    let next: Date
    let result: BackgroundResult
    let didNotify: Bool
    let feedsChanged: Set<Feed> // [.convective, .meso, .watch]
}

struct NotificationSettings: Sendable {
    let morningSummariesEnabled: Bool
    let mesoNotificationsEnabled: Bool
    let riskChangeNotificationsEnabled: Bool

    init(
        morningSummariesEnabled: Bool,
        mesoNotificationsEnabled: Bool,
        riskChangeNotificationsEnabled: Bool = true
    ) {
        self.morningSummariesEnabled = morningSummariesEnabled
        self.mesoNotificationsEnabled = mesoNotificationsEnabled
        self.riskChangeNotificationsEnabled = riskChangeNotificationsEnabled
    }
}

protocol NotificationSettingsProviding: Sendable {
    func current() async -> NotificationSettings
}

actor BackgroundOrchestrator {
    private let logger = Logger.backgroundOrchestrator
    private let signposter:OSSignposter
    private let coordinator: any HomeIngestionCoordinating
    private let refreshPolicy: RefreshPolicy
    private let morningEngine: MorningEngine
    private let mesoEngine: MesoEngine
    private let riskChangeEngine: RiskChangeEngine
    private let healthStore: BgHealthStore
    private let cadence: CadencePolicy
    private let notificationSettingsProvider: NotificationSettingsProviding
    private let pendingUploadDrainer: any PendingLocationUploadDraining
    
    private let clock = ContinuousClock()
    private let pendingUploadQuota = 1
    private let pendingUploadDrainDuration: Duration = .seconds(5)
    
    init(
        coordinator: any HomeIngestionCoordinating,
        policy: RefreshPolicy,
        engine: MorningEngine,
        mesoEngine: MesoEngine,
        riskChangeEngine: RiskChangeEngine,
        health: BgHealthStore,
        cadence: CadencePolicy,
        notificationSettingsProvider: NotificationSettingsProviding,
        pendingUploadDrainer: any PendingLocationUploadDraining
    ) {
        self.coordinator = coordinator
        morningEngine = engine
        refreshPolicy = policy
        healthStore = health
        self.cadence = cadence
        self.mesoEngine = mesoEngine
        self.riskChangeEngine = riskChangeEngine
        self.notificationSettingsProvider = notificationSettingsProvider
        self.pendingUploadDrainer = pendingUploadDrainer
        signposter = OSSignposter(logger: logger)
        logger.info("BackgroundOrchestrator initialized")
    }
    
    func beginRun() async -> BackgroundRefreshRun {
        let runId = UUID().uuidString
        let startedAt = Date()
        do {
            try await healthStore.start(runId: runId, startedAt: startedAt)
        } catch {
            logger.error("Unable to persist started background diagnostic run: \(error.localizedDescription, privacy: .public)")
        }
        return BackgroundRefreshRun(
            runId: runId,
            startedAt: startedAt,
            schedulingRecorder: { [healthStore] phase, outcome in
                try? await healthStore.recordScheduling(
                    runId: runId,
                    phase: phase,
                    outcome: outcome
                )
            }
        )
    }

    // MARK: Run Background Job
    func run() async -> Outcome {
        let run = await beginRun()
        return await self.run(run)
    }

    func run(_ run: BackgroundRefreshRun) async -> Outcome {
        logger.notice("Background run started")
        // Mark the entire background job
        let runInterval = signposter.beginInterval("Background Run")
        let startInstant = clock.now
        let executionContext = BackgroundRefreshExecutionContext(
            budget: .standard(start: startInstant)
        )
        let runId = run.runId
        let recoveryCadence = Cadence.short.minutes

        var uploadDrainDuration: Duration?
        var uploadDrainOutcome: BgPhaseOutcome?
        var ingestionDuration: Duration?
        var ingestionOutcome: BgPhaseOutcome?

        defer {
            signposter.endInterval("Background Run", runInterval)
        }
        
        return await withTaskCancellationHandler {
            var didMorningNotify = false
            var didMesoNotify = false
            var didRiskChangeNotify = false
            var noNotifyReasons: [String] = []
            var feedsChanged: Set<Feed> = []
            
            do {
                try Task.checkCancellation()
                let pendingUploadDrainBudget = PendingLocationUploadDrainBudget(
                    uploadQuota: pendingUploadQuota,
                    deadline: clock.now + pendingUploadDrainDuration
                )
                let uploadDrainStart = clock.now
                let pendingUploadDrainOutcome = await pendingUploadDrainer.drainPendingUploads(
                    using: pendingUploadDrainBudget
                )
                uploadDrainDuration = clock.now - uploadDrainStart
                uploadDrainOutcome = Task.isCancelled
                    ? .cancelled
                    : pendingUploadDrainOutcome == .drained ? .drained : .remaining
                if let uploadDrainDuration, let uploadDrainOutcome {
                    try? await healthStore.recordUploadDrain(
                        runId: runId,
                        duration: uploadDrainDuration,
                        outcome: uploadDrainOutcome
                    )
                }
                if pendingUploadDrainOutcome == .remaining {
                    logger.notice("Background upload drain left durable requests remaining")
                }

                try Task.checkCancellation()
                let settings = await notificationSettingsProvider.current()
                let ingestionInterval = signposter.beginInterval("Unified Background Ingestion")
                let ingestionStart = clock.now
                let snapshot: HomeSnapshot
                do {
                    snapshot = try await BackgroundRefreshExecutionContext.$current.withValue(executionContext) {
                        try await coordinator.enqueueAndWait(
                            .backgroundRefresh,
                            locationContext: nil,
                            remoteAlertContext: nil
                        )
                    }
                    ingestionDuration = clock.now - ingestionStart
                    ingestionOutcome = .completed
                    if let ingestionDuration, let ingestionOutcome {
                        try? await healthStore.recordIngestion(
                            runId: runId,
                            duration: ingestionDuration,
                            outcome: ingestionOutcome
                        )
                    }
                    signposter.endInterval("Unified Background Ingestion", ingestionInterval)
                } catch {
                    ingestionDuration = clock.now - ingestionStart
                    ingestionOutcome = await executionContext.deadlineState.exceeded()
                        ? .expired
                        : error is CancellationError ? .cancelled : .failed
                    if let ingestionDuration, let ingestionOutcome {
                        try? await healthStore.recordIngestion(
                            runId: runId,
                            duration: ingestionDuration,
                            outcome: ingestionOutcome
                        )
                    }
                    signposter.endInterval("Unified Background Ingestion", ingestionInterval)
                    throw error
                }

                try Task.checkCancellation()

                guard let locationSnapshot = snapshot.locationSnapshot else {
                    logger.info("No current location snapshot available; rechecking in 20m")
                    let nextRun = refreshPolicy.getNextRunTime(for: .short)
                    let end = Date()
                    let active = clock.now - startInstant
                    
                    try? await finalizeBgRun(
                        runId: runId,
                        end: end,
                        result: .skipped,
                        didNotify: false,
                        notificationReason: "No location snapshot available. Rechecking in 20m",
                        nextRun: nextRun,
                        cadence: recoveryCadence,
                        cadenceReason: "Early exit",
                        active: active,
                        uploadDrainDuration: uploadDrainDuration,
                        uploadDrainOutcome: uploadDrainOutcome,
                        ingestionDuration: ingestionDuration,
                        ingestionOutcome: ingestionOutcome
                    )
                    
                    return outcome(next: nextRun, result: .skipped, didNotify: false, feedsChanged: feedsChanged)
                }
                
                guard
                    let stormRisk = snapshot.stormRisk,
                    let severeRisk = snapshot.severeRisk,
                    let fireRisk = snapshot.fireRisk
                else {
                    throw BackgroundOrchestratorError.missingLocationScopedSnapshot
                }

                if snapshot.latestOutlook != nil {
                    feedsChanged.insert(.outlookDay1)
                }
                if snapshot.mesos.isEmpty == false {
                    feedsChanged.insert(.meso)
                }
                if snapshot.alerts.isEmpty == false {
                    feedsChanged.insert(.watch)
                }

                let outlook = snapshot.latestOutlook
                let activeMesos = snapshot.mesos
                let activeAlerts = snapshot.alerts
                let inMeso = activeMesos.isEmpty == false
                let inAlert = activeAlerts.isEmpty == false
                
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
                            placeMark: locationSnapshot.placemarkSummary ?? "Unknown",
                            riskProfileChange: settings.riskChangeNotificationsEnabled ? snapshot.riskProfileChange : nil
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
                            location: locationSnapshot.coordinates,
                            placeMark: locationSnapshot.placemarkSummary ?? "Unknown"
                        ),
                        mesos: activeMesos
                    )
                    if !didMesoNotify { noNotifyReasons.append("Meso notification skipped") }
                } else { noNotifyReasons.append("Meso notification disabled") }

                let coalescedCurrentRiskChange = settings.riskChangeNotificationsEnabled
                    && didMorningNotify
                    && snapshot.riskProfileChange != nil
                if coalescedCurrentRiskChange, let riskProfileChange = snapshot.riskProfileChange {
                    await riskChangeEngine.coalesce(change: riskProfileChange)
                }
                didRiskChangeNotify = await riskChangeEngine.run(
                    change: coalescedCurrentRiskChange ? nil : snapshot.riskProfileChange,
                    isEnabled: settings.riskChangeNotificationsEnabled
                )
                if settings.riskChangeNotificationsEnabled {
                    if !didRiskChangeNotify, !coalescedCurrentRiskChange {
                        if snapshot.riskProfileChange == nil {
                            noNotifyReasons.append("Risk change notification skipped (no change)")
                        } else {
                            noNotifyReasons.append("Risk change notification skipped")
                        }
                    }
                } else {
                    noNotifyReasons.append("Risk change notifications disabled")
                }
                                
                // MARK: Cadence decision
                let cadenceResult = cadence.decide(
                    for: .init(
                        categorical: stormRisk,
                        inMeso: inMeso,
                        inAlert: inAlert
                    )
                )
                
                let nextRun = refreshPolicy.getNextRunTime(for: cadenceResult.cadence)
                let end = Date()
                let active = clock.now - startInstant
                let didNotify = didMorningNotify || didMesoNotify || didRiskChangeNotify
                let reasonNoNotify = didNotify ? nil : noNotifyReasons.joined(separator: "; ")

                try? await finalizeBgRun(
                    runId: runId,
                    end: end,
                    result: .success,
                    didNotify: didNotify,
                    notificationReason: reasonNoNotify,
                    nextRun: nextRun,
                    cadence: cadenceResult.cadence.minutes,
                    cadenceReason: cadenceResult.reason,
                    active: active,
                    uploadDrainDuration: uploadDrainDuration,
                    uploadDrainOutcome: uploadDrainOutcome,
                    ingestionDuration: ingestionDuration,
                    ingestionOutcome: ingestionOutcome
                )

                logger.notice("Background run finished with result: success")
                return outcome(next: nextRun, result: .success, didNotify: didNotify, feedsChanged: feedsChanged)
            } catch {
                let nextRun = refreshPolicy.getNextRunTime(for: .short)
                let end = Date()
                let active = clock.now - startInstant
                let expired = await executionContext.deadlineState.exceeded()
                let result: Outcome.BackgroundResult
                let reason: String
                if expired {
                    result = .expired
                    reason = "Background refresh work deadline reached"
                } else if error is CancellationError {
                    result = .cancelled
                    reason = "Cancelled by iOS"
                } else {
                    result = .failed
                    reason = "Error refreshing background data"
                }

                if result == .cancelled {
                    logger.notice("Background refresh was cancelled: \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.error("Error refreshing background data: \(error.localizedDescription, privacy: .public)")
                }

                try? await finalizeBgRun(
                    runId: runId,
                    end: end,
                    result: result,
                    didNotify: false,
                    notificationReason: reason,
                    nextRun: nextRun,
                    cadence: recoveryCadence,
                    cadenceReason: result == .expired ? "Background refresh expired" : "Background refresh \(result)",
                    active: active,
                    uploadDrainDuration: uploadDrainDuration,
                    uploadDrainOutcome: uploadDrainOutcome,
                    ingestionDuration: ingestionDuration,
                    ingestionOutcome: ingestionOutcome
                )
                return outcome(next: nextRun, result: result, didNotify: false, feedsChanged: feedsChanged)
            }
        } onCancel: {
            logger.notice("Background run cancelled")
        }
    }
    
    private func outcome(
        next: Date,
        result: Outcome.BackgroundResult,
        didNotify: Bool,
        feedsChanged: Set<Feed>
    ) -> Outcome {
        Outcome(
            next: next,
            result: result,
            didNotify: didNotify,
            feedsChanged: feedsChanged
        )
    }

    private func finalizeBgRun(
        runId: String,
        end: Date,
        result: Outcome.BackgroundResult,
        didNotify: Bool,
        notificationReason: String?,
        nextRun: Date,
        cadence: Int,
        cadenceReason: String?,
        active: Duration,
        uploadDrainDuration: Duration?,
        uploadDrainOutcome: BgPhaseOutcome?,
        ingestionDuration: Duration?,
        ingestionOutcome: BgPhaseOutcome?
    ) async throws {
        try await healthStore.finalize(
            runId: runId,
            with: .init(
                endedAt: end,
                outcome: bgRunOutcome(for: result),
                didNotify: didNotify,
                reasonNoNotify: notificationReason,
                budgetSecUsed: Int(active.components.seconds),
                desiredNextRunAt: nextRun,
                cadence: cadence,
                cadenceReason: cadenceReason,
                active: active,
                uploadDrainDuration: uploadDrainDuration,
                uploadDrainOutcome: uploadDrainOutcome,
                ingestionDuration: ingestionDuration,
                ingestionOutcome: ingestionOutcome
            )
        )
    }

    private func bgRunOutcome(for result: Outcome.BackgroundResult) -> BgRunOutcome {
        switch result {
        case .success: .success
        case .skipped: .skipped
        case .failed: .failed
        case .cancelled: .cancelled
        case .expired: .expired
        }
    }
}

private enum BackgroundOrchestratorError: Error {
    case missingLocationScopedSnapshot
}
