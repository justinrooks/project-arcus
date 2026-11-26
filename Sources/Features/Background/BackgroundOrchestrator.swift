//
//  BackgroundOrchestrator.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/16/25.
//

import Foundation
import OSLog
import Synchronization

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
    let serverOwnsMesoNotificationDelivery: Bool
    let winterImpactsEnabled: Bool

    init(
        morningSummariesEnabled: Bool,
        mesoNotificationsEnabled: Bool,
        riskChangeNotificationsEnabled: Bool = true,
        serverOwnsMesoNotificationDelivery: Bool = false,
        winterImpactsEnabled: Bool = false
    ) {
        self.morningSummariesEnabled = morningSummariesEnabled
        self.mesoNotificationsEnabled = mesoNotificationsEnabled
        self.riskChangeNotificationsEnabled = riskChangeNotificationsEnabled
        self.serverOwnsMesoNotificationDelivery = serverOwnsMesoNotificationDelivery
        self.winterImpactsEnabled = winterImpactsEnabled
    }
}

protocol NotificationSettingsProviding: Sendable {
    func current() async -> NotificationSettings
}

actor BackgroundOrchestrator {
    typealias WinterAssessmentLoader = @Sendable (
        Date, @Sendable (WSSIAcceptedAssessment?) -> Void
    ) async -> Void

    struct WinterAssessmentSource: Sendable {
        let load: WinterAssessmentLoader
        let currentLocation: @Sendable () async -> WSSIAcceptedAssessment.Location?
    }

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
    private let winterAssessmentSource: WinterAssessmentSource?
    private let morningNow: @Sendable () -> Date
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
        winterAssessmentSource: WinterAssessmentSource? = nil,
        morningNow: @escaping @Sendable () -> Date = { .now },
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
        self.winterAssessmentSource = winterAssessmentSource
        self.morningNow = morningNow
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
        let winterAssessmentSource = winterAssessmentSource
        let morningNow = morningNow
        let cadence = cadence
        return try await withThrowingTaskGroup(of: BackgroundWorkEvaluation?.self) { group in
            group.addTask {
                try await BackgroundRefreshExecutionContext.$current.withValue(executionContext) {
                    let settings = await notificationSettingsProvider.current()
                    try Task.checkCancellation()
                    let localTZ = TimeZone.current
                    let startedAt = morningNow()
                    let preparedWinter = Mutex<WSSIAcceptedAssessment?>(nil)
                    // A committed local assessment may enrich SPC if it is ready after ingestion.
                    // Never join this task on the SPC delivery path.
                    let winterRead: Task<Void, Never>? = if settings.morningSummariesEnabled,
                       settings.winterImpactsEnabled, let winterAssessmentSource,
                       morningEngine.rule.isInDeliveryWindow(at: startedAt, localTZ: localTZ) {
                        Task {
                            await winterAssessmentSource.load(startedAt) { assessment in
                                preparedWinter.withLock {
                                    if !Task.isCancelled { $0 = assessment }
                                }
                            }
                        }
                    } else {
                        nil
                    }
                    defer { winterRead?.cancel() }

                    @Sendable func winterStillApplies(
                        _ impact: MorningContext.WinterImpact, at location: WSSIAcceptedAssessment.Location?
                    ) async -> Bool {
                        guard let winterAssessmentSource, let location,
                              await winterAssessmentSource.currentLocation() == location else { return false }
                        let latest = await notificationSettingsProvider.current()
                        let time = morningNow()
                        return latest.morningSummariesEnabled && latest.winterImpactsEnabled
                            && clock.now < workDeadline && time < impact.sourceInterval.end
                            && morningEngine.rule.isInDeliveryWindow(at: time, localTZ: localTZ)
                    }

                    func attemptWinterOnly(at locationSnapshot: LocationSnapshot?) async throws -> Bool {
                        let time = morningNow()
                        guard settings.morningSummariesEnabled, settings.winterImpactsEnabled,
                              let winterAssessmentSource, clock.now < workDeadline,
                              morningEngine.rule.isInDeliveryWindow(at: time, localTZ: localTZ),
                              let location = await winterAssessmentSource.currentLocation()
                        else { return false }

                        let latest = await notificationSettingsProvider.current()
                        try Task.checkCancellation()
                        guard latest.morningSummariesEnabled, latest.winterImpactsEnabled else { return false }
                        let prepared = preparedWinter.withLock { $0 }
                        let assessment: WSSIAcceptedAssessment?
                        if prepared?.location == location {
                            assessment = prepared
                        } else {
                            // Give the local lookup one second and leave time for delivery and finalization.
                            guard executionContext.budget.remainingWork(at: clock.now) >= .seconds(2) else { return false }
                            winterRead?.cancel()
                            assessment = await Self.readWinterAssessment(from: winterAssessmentSource, at: morningNow())
                        }
                        try Task.checkCancellation()
                        guard let assessment, clock.now < workDeadline else { return false }

                        let snapshotLocation = locationSnapshot.flatMap(WSSIAcceptedAssessment.Location.init)
                        signposter.emitEvent("Morning Summary Notification")
                        return await morningEngine.run(ctx: .init(
                            now: morningNow(), lastConvectiveIssue: nil, localTZ: localTZ, quietHours: nil,
                            stormRisk: nil, severeRisk: nil, fireRisk: nil,
                            placeMark: snapshotLocation == location ? locationSnapshot?.placemarkSummary : nil,
                            acceptedWinterAssessment: assessment,
                            currentWinterLocation: location, winterImpactsEnabled: true
                        )) { await winterStillApplies($0, at: location) }
                    }

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
                        // The current accepted point can be usable before NWS enrichment is available.
                        let didNotify = try await attemptWinterOnly(at: nil)
                        try Task.checkCancellation()
                        return .init(
                            result: .skipped,
                            didNotify: didNotify,
                            notificationReason: didNotify ? nil : "No location snapshot available. Rechecking in 20m",
                            cadence: .short,
                            cadenceReason: "Early exit",
                            feedsChanged: []
                        )
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

                    let activeMesos = snapshot.mesos
                    let activeAlerts = snapshot.alerts
                    let inMeso = activeMesos.isEmpty == false
                    let inAlert = activeAlerts.isEmpty == false
                    var didMorningNotify = false
                    var didMesoNotify = false
                    var didRiskChangeNotify = false
                    var noNotifyReasons: [String] = []
                    let issue = snapshot.latestOutlook?.published
                    let stormRisk = snapshot.severeRisk != nil && snapshot.fireRisk != nil ? snapshot.stormRisk : nil
                    let winterLocation = WSSIAcceptedAssessment.Location(locationSnapshot)
                    let readyWinter = preparedWinter.withLock { $0 }
                    let morningSettings = readyWinter == nil ? settings : await notificationSettingsProvider.current()
                    try Task.checkCancellation()
                    let acceptedWinter: WSSIAcceptedAssessment? = if morningSettings.winterImpactsEnabled,
                       let readyWinter, readyWinter.location == winterLocation, let winterAssessmentSource,
                       await winterAssessmentSource.currentLocation() == readyWinter.location {
                        readyWinter
                    } else {
                        nil
                    }
                    let now = morningNow()
                    let hasSPC = stormRisk != nil && AmRangeLocalRule.acceptsSPC(issue: issue, at: now)
                    // A projection can independently acknowledge a risk transition even when the SPC summary is absent.
                    let morningRiskChange = morningSettings.riskChangeNotificationsEnabled ? snapshot.riskProfileChange : nil

                    if morningSettings.morningSummariesEnabled && (hasSPC || acceptedWinter != nil) {
                        signposter.emitEvent("Morning Summary Notification")
                        didMorningNotify = await morningEngine.run(
                            ctx: .init(
                                now: now,
                                lastConvectiveIssue: hasSPC ? issue : nil,
                                localTZ: localTZ,
                                quietHours: nil,
                                stormRisk: hasSPC ? snapshot.stormRisk : nil,
                                severeRisk: hasSPC ? snapshot.severeRisk : nil,
                                fireRisk: hasSPC ? snapshot.fireRisk : nil,
                                placeMark: locationSnapshot.placemarkSummary,
                                riskProfileChange: morningRiskChange,
                                acceptedWinterAssessment: acceptedWinter,
                                currentWinterLocation: winterLocation,
                                winterImpactsEnabled: morningSettings.winterImpactsEnabled
                            )
                        ) { await winterStillApplies($0, at: winterLocation) }
                    }
                    if hasSPC || acceptedWinter != nil { winterRead?.cancel() }

                    let coalescedCurrentRiskChange = didMorningNotify && morningRiskChange != nil
                    if coalescedCurrentRiskChange, let riskProfileChange = morningRiskChange {
                        await riskChangeEngine.coalesce(change: riskProfileChange)
                    }
                    try Task.checkCancellation()

                    // Sync may acknowledge a handoff while ingestion or morning delivery is awaiting.
                    let mesoSettings = await notificationSettingsProvider.current()
                    try Task.checkCancellation()
                    if mesoSettings.serverOwnsMesoNotificationDelivery {
                        noNotifyReasons.append("Meso notification owned by Signal")
                    } else if mesoSettings.mesoNotificationsEnabled {
                        signposter.emitEvent("Meso Notification")
                        didMesoNotify = await mesoEngine.run(
                            ctx: .init(
                                now: .now,
                                localTZ: .current,
                                location: locationSnapshot.coordinates,
                                placeMark: locationSnapshot.placemarkSummary ?? "Unknown"
                            ),
                            mesos: activeMesos,
                            allowsDelivery: {
                                let latest = await notificationSettingsProvider.current()
                                return latest.mesoNotificationsEnabled && !latest.serverOwnsMesoNotificationDelivery
                            }
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

                    // A later local assessment can still supply a winter-only summary. Independent
                    // notifications have already had their delivery opportunity in this grant.
                    if !hasSPC, acceptedWinter == nil {
                        didMorningNotify = try await attemptWinterOnly(at: locationSnapshot)
                    }
                    if !didMorningNotify {
                        noNotifyReasons.append(
                            morningSettings.morningSummariesEnabled ? "Morning summary skipped" : "Morning summary disabled"
                        )
                    }
                    try Task.checkCancellation()

                    let cadenceResult = stormRisk.map {
                        cadence.decide(for: .init(categorical: $0, inMeso: inMeso, inAlert: inAlert))
                    } ?? .init(cadence: .short, reason: "Incomplete location-scoped SPC snapshot")
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

    nonisolated private static func readWinterAssessment(
        from source: WinterAssessmentSource, at time: Date
    ) async -> WSSIAcceptedAssessment? {
        let (results, continuation) = AsyncStream.makeStream(of: WSSIAcceptedAssessment?.self)
        let read = Task {
            await source.load(time) { _ = continuation.yield($0) }
            continuation.finish()
        }
        defer {
            read.cancel()
            continuation.finish()
        }
        // Race the result stream so cancellation never waits for a synchronous store read to unwind.
        return try? await withTimeout(timeout: 1) {
            var iterator = results.makeAsyncIterator()
            return await iterator.next() ?? nil
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
