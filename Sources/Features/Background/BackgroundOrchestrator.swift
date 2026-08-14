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
    private let executionContextFactory: @Sendable (ContinuousClock.Instant) -> BackgroundRefreshExecutionContext
    private let workDeadlineWaiter: @Sendable (ContinuousClock.Instant) async throws -> Void
    
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
        pendingUploadDrainer: any PendingLocationUploadDraining,
        executionContextFactory: @escaping @Sendable (ContinuousClock.Instant) -> BackgroundRefreshExecutionContext = {
            BackgroundRefreshExecutionContext(budget: .standard(start: $0))
        },
        workDeadlineWaiter: @escaping @Sendable (ContinuousClock.Instant) async throws -> Void = {
            try await ContinuousClock().sleep(until: $0)
        }
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
        self.executionContextFactory = executionContextFactory
        self.workDeadlineWaiter = workDeadlineWaiter
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
        let executionContext = executionContextFactory(startInstant)
        let runId = run.runId
        let recoveryCadence = Cadence.short.minutes

        var uploadDrainDuration: Duration?
        var uploadDrainOutcome: BgPhaseOutcome?
        let phaseState = BackgroundWorkPhaseState()

        defer {
            signposter.endInterval("Background Run", runInterval)
        }
        
        return await withTaskCancellationHandler {
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

                let evaluation = try await evaluateWork(
                    using: executionContext,
                    runId: runId,
                    phaseState: phaseState
                )
                let nextRun = refreshPolicy.getNextRunTime(for: evaluation.cadence)
                let end = Date()
                let active = clock.now - startInstant
                let ingestion = await phaseState.ingestion()

                try? await finalizeBgRun(
                    runId: runId,
                    end: end,
                    result: evaluation.result,
                    didNotify: evaluation.didNotify,
                    notificationReason: evaluation.notificationReason,
                    nextRun: nextRun,
                    cadence: evaluation.cadence.minutes,
                    cadenceReason: evaluation.cadenceReason,
                    active: active,
                    uploadDrainDuration: uploadDrainDuration,
                    uploadDrainOutcome: uploadDrainOutcome,
                    ingestionDuration: ingestion?.duration,
                    ingestionOutcome: ingestion?.outcome
                )

                logger.notice("Background run finished with result: \(String(describing: evaluation.result), privacy: .public)")
                return outcome(
                    next: nextRun,
                    result: evaluation.result,
                    didNotify: evaluation.didNotify,
                    feedsChanged: evaluation.feedsChanged
                )
            } catch {
                let nextRun = refreshPolicy.getNextRunTime(for: .short)
                let end = Date()
                let active = clock.now - startInstant
                let ingestion = await phaseState.ingestion()
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
                    ingestionDuration: ingestion?.duration,
                    ingestionOutcome: ingestion?.outcome
                )
                return outcome(next: nextRun, result: result, didNotify: false, feedsChanged: [])
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

    private func evaluateWork(
        using executionContext: BackgroundRefreshExecutionContext,
        runId: String,
        phaseState: BackgroundWorkPhaseState
    ) async throws -> BackgroundWorkEvaluation {
        try Task.checkCancellation()

        let workDeadline = executionContext.budget.workDeadline
        guard clock.now < workDeadline else {
            await executionContext.deadlineState.markExceeded()
            let evidence = BackgroundIngestionEvidence(duration: .zero, outcome: .expired)
            await phaseState.record(ingestion: evidence)
            try? await healthStore.recordIngestion(
                runId: runId,
                duration: evidence.duration,
                outcome: evidence.outcome
            )
            throw CancellationError()
        }

        let coordinator = coordinator
        let workDeadlineWaiter = workDeadlineWaiter
        let notificationSettingsProvider = notificationSettingsProvider
        let signposter = signposter
        let clock = clock
        let healthStore = healthStore
        let logger = logger
        let morningEngine = morningEngine
        let mesoEngine = mesoEngine
        let riskChangeEngine = riskChangeEngine
        let cadence = cadence
        return try await withThrowingTaskGroup(of: BackgroundWorkEvaluation?.self) { group in
            group.addTask {
                try await BackgroundRefreshExecutionContext.$current.withValue(executionContext) {
                    let settings = await notificationSettingsProvider.current()
                    try Task.checkCancellation()
                    let ingestionInterval = signposter.beginInterval("Unified Background Ingestion")
                    let ingestionStart = clock.now
                    let snapshot: HomeSnapshot
                    do {
                        snapshot = try await BackgroundOrchestrator.unifiedIngestion(
                            using: executionContext,
                            coordinator: coordinator
                        )
                        try Task.checkCancellation()
                        let evidence = BackgroundIngestionEvidence(
                            duration: clock.now - ingestionStart,
                            outcome: .completed
                        )
                        await phaseState.record(ingestion: evidence)
                        try? await healthStore.recordIngestion(
                            runId: runId,
                            duration: evidence.duration,
                            outcome: evidence.outcome
                        )
                        signposter.endInterval("Unified Background Ingestion", ingestionInterval)
                    } catch {
                        let evidence = BackgroundIngestionEvidence(
                            duration: clock.now - ingestionStart,
                            outcome: await executionContext.deadlineState.exceeded()
                                ? .expired
                                : error is CancellationError ? .cancelled : .failed
                        )
                        await phaseState.record(ingestion: evidence)
                        try? await healthStore.recordIngestion(
                            runId: runId,
                            duration: evidence.duration,
                            outcome: evidence.outcome
                        )
                        signposter.endInterval("Unified Background Ingestion", ingestionInterval)
                        throw error
                    }

                    try Task.checkCancellation()

                    guard let locationSnapshot = snapshot.locationSnapshot else {
                        logger.info("No current location snapshot available; rechecking in 20m")
                        return .init(
                            result: .skipped,
                            didNotify: false,
                            notificationReason: "No location snapshot available. Rechecking in 20m",
                            cadence: .short,
                            cadenceReason: "Early exit",
                            feedsChanged: []
                        )
                    }

                    guard
                        let stormRisk = snapshot.stormRisk,
                        let severeRisk = snapshot.severeRisk,
                        let fireRisk = snapshot.fireRisk
                    else {
                        throw BackgroundOrchestratorError.missingLocationScopedSnapshot
                    }

                    var feedsChanged: Set<Feed> = []
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
                    var didMorningNotify = false
                    var didMesoNotify = false
                    var didRiskChangeNotify = false
                    var noNotifyReasons: [String] = []

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

                    let coalescedCurrentRiskChange = settings.riskChangeNotificationsEnabled
                        && didMorningNotify
                        && snapshot.riskProfileChange != nil
                    if coalescedCurrentRiskChange, let riskProfileChange = snapshot.riskProfileChange {
                        await riskChangeEngine.coalesce(change: riskProfileChange)
                    }
                    try Task.checkCancellation()

                    if settings.mesoNotificationsEnabled {
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
                    try Task.checkCancellation()

                    didRiskChangeNotify = await riskChangeEngine.run(
                        change: coalescedCurrentRiskChange ? nil : snapshot.riskProfileChange,
                        isEnabled: settings.riskChangeNotificationsEnabled,
                        activeLocationKey: snapshot.riskComparisonLocationKey
                    )
                    try Task.checkCancellation()
                    if settings.riskChangeNotificationsEnabled {
                        if !didRiskChangeNotify, !coalescedCurrentRiskChange {
                            noNotifyReasons.append(
                                snapshot.riskProfileChange == nil
                                    ? "Risk change notification skipped (no change)"
                                    : "Risk change notification skipped"
                            )
                        }
                    } else {
                        noNotifyReasons.append("Risk change notifications disabled")
                    }

                    let cadenceResult = cadence.decide(
                        for: .init(categorical: stormRisk, inMeso: inMeso, inAlert: inAlert)
                    )
                    let didNotify = didMorningNotify || didMesoNotify || didRiskChangeNotify
                    return .init(
                        result: .success,
                        didNotify: didNotify,
                        notificationReason: didNotify ? nil : noNotifyReasons.joined(separator: "; "),
                        cadence: cadenceResult.cadence,
                        cadenceReason: cadenceResult.reason,
                        feedsChanged: feedsChanged
                    )
                }
            }
            group.addTask {
                try await workDeadlineWaiter(workDeadline)
                try Task.checkCancellation()
                await executionContext.deadlineState.markExceeded()
                return nil
            }

            defer { group.cancelAll() }
            guard let firstCompleted = try await group.next() else {
                throw CancellationError()
            }
            guard let snapshot = firstCompleted else {
                throw CancellationError()
            }

            let deadlineWasExceeded = await executionContext.deadlineState.exceeded()
            if clock.now >= workDeadline || deadlineWasExceeded {
                await executionContext.deadlineState.markExceeded()
                throw CancellationError()
            }
            return snapshot
        }
    }

    nonisolated private static func unifiedIngestion(
        using executionContext: BackgroundRefreshExecutionContext,
        coordinator: any HomeIngestionCoordinating
    ) async throws -> HomeSnapshot {
        try await BackgroundRefreshExecutionContext.$current.withValue(executionContext) {
            try await coordinator.enqueueAndWait(
                .backgroundRefresh,
                locationContext: nil,
                remoteAlertContext: nil
            )
        }
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

private struct BackgroundWorkEvaluation: Sendable {
    let result: Outcome.BackgroundResult
    let didNotify: Bool
    let notificationReason: String?
    let cadence: Cadence
    let cadenceReason: String
    let feedsChanged: Set<Feed>
}

private struct BackgroundIngestionEvidence: Sendable {
    let duration: Duration
    let outcome: BgPhaseOutcome
}

private actor BackgroundWorkPhaseState {
    private var ingestionEvidence: BackgroundIngestionEvidence?

    func record(ingestion evidence: BackgroundIngestionEvidence) {
        ingestionEvidence = evidence
    }

    func ingestion() -> BackgroundIngestionEvidence? {
        ingestionEvidence
    }
}
