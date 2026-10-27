//
//  HomeStormSetupIngestion.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import OSLog
import ArcusCore

actor HomeStormSetupIngestion {
    enum RefreshIntent: Sendable {
        case automatic
        case userInitiated
    }

    struct RefreshDecision: Sendable, Equatable {
        let result: HomeStormSetupRefreshResult
        let currentResponse: StormSetupCurrentResponse?
        let stormSetup: StormSetupDTO?
    }

    private struct RefreshState: Sendable {
        var refreshKey: LocationContext.RefreshKey
        var lastAttemptAt: Date?
        var lastSuccessAt: Date?
        var lastAttemptFailed: Bool
    }

    private struct ActiveRefresh: Sendable {
        let id: UUID
        let intent: RefreshIntent
        var task: Task<Void, Never>?
        var waiters: [UUID: CheckedContinuation<RefreshDecision, Never>]
        var pendingManual: [UUID: PendingManual]
        var isFetching = false
        var startHandlers: [UUID: @Sendable () async -> Void] = [:]
    }

    private struct PendingManual: Sendable {
        let context: LocationContext
        let snapshot: HomeSnapshot
        let plan: HomeIngestionPlan
        let executionMode: HTTPExecutionMode
        let continuation: CheckedContinuation<RefreshDecision, Never>
        let onStarted: @Sendable () async -> Void
    }

    private struct QueryTimeoutError: Error {}

    private actor ForegroundQueryRace {
        private var continuation: CheckedContinuation<StormSetupCurrentResponse, Error>?
        private var result: Result<StormSetupCurrentResponse, Error>?
        private var queryTask: Task<Void, Never>?
        private var deadlineTask: Task<Void, Never>?

        func run(
            timeout: TimeInterval,
            sleep: @escaping @Sendable (TimeInterval) async throws -> Void,
            now: @escaping @Sendable () -> ContinuousClock.Instant,
            operation: @escaping @Sendable () async throws -> StormSetupCurrentResponse
        ) async throws -> StormSetupCurrentResponse {
            if let result { return try result.get() }
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let deadline = now().advanced(by: .seconds(timeout))
                queryTask = Task {
                    do {
                        let response = try await operation()
                        self.finish(now() < deadline ? .success(response) : .failure(QueryTimeoutError()))
                    } catch { self.finish(.failure(error)) }
                }
                deadlineTask = Task {
                    do {
                        try await sleep(timeout)
                        try Task.checkCancellation()
                        self.finish(.failure(QueryTimeoutError()))
                    } catch { self.finish(.failure(error)) }
                }
            }
        }

        func finish(_ result: Result<StormSetupCurrentResponse, Error>) {
            guard self.result == nil else { return }
            self.result = result
            queryTask?.cancel()
            deadlineTask?.cancel()
            queryTask = nil
            deadlineTask = nil
            continuation?.resume(with: result)
            continuation = nil
        }
    }

    private enum AttemptOutcome {
        case success(StormSetupCurrentResponse)
        case failure
        case timeout
        case cancelled
        case skipped
    }

    private let logger: Logger
    private let querying: (any StormSetupQuerying)?
    private let projectionStore: (any HomeProjectionPersisting)?
    private let preferencesReader: @Sendable () async -> StormSetupPreferences
    private let currentDate: @Sendable () -> Date
    private let foregroundTimeout: TimeInterval
    private let failedAttemptBackoff: TimeInterval
    private let deadlineNow: @Sendable () -> ContinuousClock.Instant
    private let sleepForDeadline: @Sendable (TimeInterval) async throws -> Void

    private var refreshStates: [String: RefreshState] = [:]
    private var activeRefreshes: [String: ActiveRefresh] = [:]

    init(
        logger: Logger,
        querying: (any StormSetupQuerying)?,
        projectionStore: (any HomeProjectionPersisting)?,
        preferencesReader: @escaping @Sendable () async -> StormSetupPreferences,
        currentDate: @escaping @Sendable () -> Date,
        foregroundTimeout: TimeInterval,
        failedAttemptBackoff: TimeInterval,
        deadlineNow: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock().now },
        sleepForDeadline: @escaping @Sendable (TimeInterval) async throws -> Void = {
            try await Task.sleep(for: .seconds($0))
        }
    ) {
        self.logger = logger
        self.querying = querying
        self.projectionStore = projectionStore
        self.preferencesReader = preferencesReader
        self.currentDate = currentDate
        self.foregroundTimeout = foregroundTimeout
        self.failedAttemptBackoff = failedAttemptBackoff
        self.sleepForDeadline = sleepForDeadline
        self.deadlineNow = deadlineNow
    }

    func refresh(
        context: LocationContext?,
        snapshot: HomeSnapshot,
        plan: HomeIngestionPlan,
        executionMode: HTTPExecutionMode,
        intent: RefreshIntent = .automatic,
        onStarted: @escaping @Sendable () async -> Void = {}
    ) async -> RefreshDecision {
        guard let context else {
            let startedAt = Date()
            logOutcome(
                outcome: "skipped",
                reason: "no-location",
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .skipped, currentResponse: nil, stormSetup: nil)
        }

        let projectionKey = HomeProjection.projectionKey(for: context)
        let ownerID = UUID()
        if activeRefreshes[projectionKey]?.isFetching == true {
            await onStarted()
        }
        return await withTaskCancellationHandler {
            guard Task.isCancelled == false else {
                return .init(result: .cancelled, currentResponse: nil, stormSetup: nil)
            }
            return await withCheckedContinuation { continuation in
                if var activeRefresh = activeRefreshes[projectionKey] {
                    if intent == .userInitiated, activeRefresh.intent == .automatic {
                        activeRefresh.pendingManual[ownerID] = .init(
                            context: context,
                            snapshot: snapshot,
                            plan: plan,
                            executionMode: executionMode,
                            continuation: continuation,
                            onStarted: onStarted
                        )
                    } else {
                        activeRefresh.waiters[ownerID] = continuation
                        if activeRefresh.isFetching == false {
                            activeRefresh.startHandlers[ownerID] = onStarted
                        }
                    }
                    activeRefreshes[projectionKey] = activeRefresh
                    return
                }
                startRefresh(
                    context: context,
                    snapshot: snapshot,
                    plan: plan,
                    executionMode: executionMode,
                    intent: intent,
                    projectionKey: projectionKey,
                    waiterID: ownerID,
                    continuation: continuation,
                    onStarted: onStarted
                )
            }
        } onCancel: {
            Task { await self.cancelWaiter(ownerID, for: projectionKey) }
        }
    }

    private func startRefresh(context: LocationContext, snapshot: HomeSnapshot, plan: HomeIngestionPlan, executionMode: HTTPExecutionMode, intent: RefreshIntent, projectionKey: String, waiterID: UUID, continuation: CheckedContinuation<RefreshDecision, Never>, onStarted: @escaping @Sendable () async -> Void) {
        let refreshID = UUID()
        activeRefreshes[projectionKey] = .init(id: refreshID, intent: intent, task: nil, waiters: [waiterID: continuation], pendingManual: [:], startHandlers: [waiterID: onStarted])
        let task = Task {
            let decision = await self.performRefresh(context: context, snapshot: snapshot, plan: plan, executionMode: executionMode, intent: intent, onStarted: {
                await self.notifyStarted(id: refreshID, for: projectionKey)
            })
            self.finishRefresh(id: refreshID, for: projectionKey, decision: decision)
        }
        activeRefreshes[projectionKey]?.task = task
    }

    private func notifyStarted(id: UUID, for projectionKey: String) async {
        guard var active = activeRefreshes[projectionKey], active.id == id else { return }
        active.isFetching = true
        let handlers = active.startHandlers.values
        active.startHandlers = [:]
        activeRefreshes[projectionKey] = active
        for handler in handlers { await handler() }
    }

    private func cancelWaiter(_ waiterID: UUID, for projectionKey: String) {
        guard var active = activeRefreshes[projectionKey] else { return }
        if let continuation = active.waiters.removeValue(forKey: waiterID) ?? active.pendingManual.removeValue(forKey: waiterID)?.continuation {
            continuation.resume(returning: .init(result: .cancelled, currentResponse: nil, stormSetup: nil))
        }
        active.startHandlers[waiterID] = nil
        if active.waiters.isEmpty && active.pendingManual.isEmpty {
            active.task?.cancel()
            activeRefreshes[projectionKey] = nil
            return
        }
        activeRefreshes[projectionKey] = active
    }

    private func finishRefresh(id: UUID, for projectionKey: String, decision: RefreshDecision) {
        guard let active = activeRefreshes[projectionKey], active.id == id else { return }
        active.waiters.values.forEach { $0.resume(returning: decision) }
        if let (nextID, next) = active.pendingManual.first {
            activeRefreshes[projectionKey] = nil
            startRefresh(context: next.context, snapshot: next.snapshot, plan: next.plan, executionMode: next.executionMode, intent: .userInitiated, projectionKey: projectionKey, waiterID: nextID, continuation: next.continuation, onStarted: next.onStarted)
            if var promoted = activeRefreshes[projectionKey] {
                for (owner, pending) in active.pendingManual where owner != nextID {
                    promoted.waiters[owner] = pending.continuation
                    promoted.startHandlers[owner] = pending.onStarted
                }
                activeRefreshes[projectionKey] = promoted
            }
        } else { activeRefreshes[projectionKey] = nil }
    }

    private func performRefresh(
        context: LocationContext,
        snapshot: HomeSnapshot,
        plan: HomeIngestionPlan,
        executionMode: HTTPExecutionMode,
        intent: RefreshIntent,
        onStarted: @Sendable () async -> Void
    ) async -> RefreshDecision {
        let startedAt = Date()
        let now = currentDate()

        guard let projectionStore else {
            logOutcome(
                outcome: "skipped",
                reason: "ineligible",
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .skipped, currentResponse: nil, stormSetup: nil)
        }

        let preferences = await preferencesReader()
        let projectionKey = HomeProjection.projectionKey(for: context)
        let projection = try? await projectionStore.projection(for: context)
        let cachedCurrentResponse = projection?.stormSetupCurrentResponse.flatMap {
            $0.setup.h3Cell == context.h3Cell ? $0 : nil
        }
        let cachedStormSetup = cachedCurrentResponse.map(StormSetupDTO.init(response:))
        let freshCachedCurrentResponse = cachedCurrentResponse.flatMap {
            $0.setup.freshness.expiresAt > now ? $0 : nil
        }
        let freshCachedStormSetup = freshCachedCurrentResponse.map(StormSetupDTO.init(response:))

        let policyInput = StormSetupPolicyInput(
            preferences: preferences,
            stormRisk: snapshot.stormRisk,
            severeRisk: snapshot.severeRisk,
            hasQualifyingConvectiveAlert: StormSetupAlertEligibility.hasQualifyingAlert(
                in: snapshot.alerts,
                now: now
            ),
            hasActiveMeso: snapshot.mesos.isEmpty == false,
            assessmentOverall: cachedStormSetup.map { StormSetupAssessment(dto: $0).assessment.overall },
            payloadExpiresAt: cachedStormSetup?.freshness.expiresAt,
            now: now
        )

        let shouldFetchPrimary = querying != nil
            && preferences.stormSetupEnabled
            && (intent == .userInitiated || StormSetupFetchPolicy.shouldFetch(policyInput))
        let shouldBackOffPrimary = intent == .automatic && shouldBackOff(for: projectionKey, plan: plan, now: now)

        if shouldFetchPrimary == false {
            let resolvedStormSetup = freshCachedStormSetup
            logOutcome(
                outcome: "skipped",
                reason: resolvedStormSetup == nil ? "disabled-or-ineligible" : "fresh-cache",
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .skipped, currentResponse: freshCachedCurrentResponse, stormSetup: resolvedStormSetup)
        }

        let primaryOutcome: AttemptOutcome
        if shouldBackOffPrimary {
            primaryOutcome = .skipped
        } else if Task.isCancelled {
            primaryOutcome = .cancelled
        } else if let querying {
            await onStarted()
            logOutcome(outcome: "started", reason: nil, startedAt: startedAt, executionMode: executionMode)
            primaryOutcome = await performFetch(h3Cell: context.h3Cell, querying: querying, executionMode: executionMode)
        } else {
            primaryOutcome = .skipped
        }

        let completedAt = currentDate()
        let usableCache = freshCachedCurrentResponse.flatMap { $0.setup.freshness.expiresAt > completedAt ? $0 : nil }
        let resolvedPrimaryDecision = await handleOutcome(
            Task.isCancelled ? .cancelled : primaryOutcome,
            context: context,
            projectionKey: projectionKey,
            cachedCurrentResponse: cachedCurrentResponse,
            freshCachedCurrentResponse: usableCache,
            freshCachedStormSetup: usableCache.map(StormSetupDTO.init(response:)),
            now: completedAt,
            startedAt: startedAt,
            executionMode: executionMode
        )

        return resolvedPrimaryDecision
    }

    private func performFetch(
        h3Cell: Int64,
        querying: any StormSetupQuerying,
        executionMode: HTTPExecutionMode
    ) async -> AttemptOutcome {
        do {
            let stormSetup = try await fetch(
                h3Cell: h3Cell,
                querying: querying,
                executionMode: executionMode
            )
            return .success(stormSetup)
        } catch is QueryTimeoutError {
            return .timeout
        } catch let error as URLError where error.code == .timedOut {
            return .timeout
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failure
        }
    }

    private func fetch(
        h3Cell: Int64,
        querying: any StormSetupQuerying,
        executionMode: HTTPExecutionMode
    ) async throws -> StormSetupCurrentResponse {
        if executionMode == .foreground {
            // A task-group scope waits for cancelled children. This owned race releases the caller
            // at the deadline even if a provider ignores cancellation; only its winner can return data.
            let race = ForegroundQueryRace()
            return try await withTaskCancellationHandler {
                try Task.checkCancellation()
                return try await race.run(timeout: foregroundTimeout, sleep: sleepForDeadline, now: deadlineNow) {
                    try await HTTPExecutionMode.$current.withValue(executionMode) {
                        try await querying.fetchCurrentStormSetup(h3Cell: h3Cell)
                    }
                }
            } onCancel: {
                Task { await race.finish(.failure(CancellationError())) }
            }
        }

        return try await HTTPExecutionMode.$current.withValue(executionMode) {
            try await querying.fetchCurrentStormSetup(h3Cell: h3Cell)
        }
    }

    private func handleOutcome(
        _ outcome: AttemptOutcome,
        context: LocationContext,
        projectionKey: String,
        cachedCurrentResponse: StormSetupCurrentResponse?,
        freshCachedCurrentResponse: StormSetupCurrentResponse?,
        freshCachedStormSetup: StormSetupDTO?,
        now: Date,
        startedAt: Date,
        executionMode: HTTPExecutionMode
    ) async -> RefreshDecision {
        switch outcome {
        case .success(let stormSetup):
            return await handleSuccess(
                stormSetup,
                context: context,
                projectionKey: projectionKey,
                cachedCurrentResponse: cachedCurrentResponse,
                freshCachedCurrentResponse: freshCachedCurrentResponse,
                freshCachedStormSetup: freshCachedStormSetup,
                now: now,
                startedAt: startedAt,
                executionMode: executionMode
            )
        case .timeout:
            markAttemptFailed(
                for: projectionKey,
                refreshKey: context.refreshKey,
                now: now
            )
            logOutcome(
                outcome: "timeout",
                reason: nil,
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .timeout, currentResponse: freshCachedCurrentResponse, stormSetup: freshCachedStormSetup)
        case .cancelled:
            logOutcome(
                outcome: "cancelled",
                reason: nil,
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .cancelled, currentResponse: freshCachedCurrentResponse, stormSetup: freshCachedStormSetup)
        case .failure:
            markAttemptFailed(
                for: projectionKey,
                refreshKey: context.refreshKey,
                now: now
            )
            logOutcome(
                outcome: "failure",
                reason: nil,
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .failure, currentResponse: freshCachedCurrentResponse, stormSetup: freshCachedStormSetup)
        case .skipped:
            logOutcome(
                outcome: "skipped",
                reason: "no-request",
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .skipped, currentResponse: freshCachedCurrentResponse, stormSetup: freshCachedStormSetup)
        }
    }

    private func handleSuccess(
        _ stormSetup: StormSetupCurrentResponse,
        context: LocationContext,
        projectionKey: String,
        cachedCurrentResponse: StormSetupCurrentResponse?,
        freshCachedCurrentResponse: StormSetupCurrentResponse?,
        freshCachedStormSetup: StormSetupDTO?,
        now: Date,
        startedAt: Date,
        executionMode: HTTPExecutionMode
    ) async -> RefreshDecision {
        guard Task.isCancelled == false else {
            return .init(result: .cancelled, currentResponse: freshCachedCurrentResponse, stormSetup: freshCachedStormSetup)
        }
        let legacyStormSetup = StormSetupDTO(response: stormSetup)

        guard legacyStormSetup.h3Cell == context.h3Cell else {
            markAttemptFailed(
                for: projectionKey,
                refreshKey: context.refreshKey,
                now: now
            )
            logOutcome(
                outcome: "h3-mismatch",
                reason: nil,
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .h3Mismatch, currentResponse: freshCachedCurrentResponse, stormSetup: freshCachedStormSetup)
        }

        guard let projectionStore else {
            markAttemptFailed(
                for: projectionKey,
                refreshKey: context.refreshKey,
                now: now
            )
            logOutcome(
                outcome: "failure",
                reason: "missing-projection-store",
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .failure, currentResponse: freshCachedCurrentResponse, stormSetup: freshCachedStormSetup)
        }

        let shouldPersist = cachedCurrentResponse.map { Self.isNewer(stormSetup, than: $0) } ?? true

        if shouldPersist {
            do {
                _ = try await projectionStore.updateStormSetup(
                    stormSetup,
                    for: context,
                    loadedAt: now
                )
                markAttemptSucceeded(
                    for: projectionKey,
                    refreshKey: context.refreshKey,
                    now: now
                )

                logOutcome(
                    outcome: "success",
                    reason: nil,
                    startedAt: startedAt,
                    executionMode: executionMode
                )
                let resolvedCurrentResponse = stormSetup.setup.freshness.expiresAt > now ? stormSetup : freshCachedCurrentResponse
                return .init(result: .success, currentResponse: resolvedCurrentResponse, stormSetup: resolvedCurrentResponse.map(StormSetupDTO.init(response:)))
            } catch {
                markAttemptFailed(
                    for: projectionKey,
                    refreshKey: context.refreshKey,
                    now: now
                )
                logOutcome(
                    outcome: "failure",
                    reason: "persistence",
                    startedAt: startedAt,
                    executionMode: executionMode
                )
                return .init(result: .failure, currentResponse: freshCachedCurrentResponse, stormSetup: freshCachedStormSetup)
            }
        }

        markAttemptFailed(
            for: projectionKey,
            refreshKey: context.refreshKey,
            now: now
        )
        logOutcome(
            outcome: "success",
            reason: "stale-response",
            startedAt: startedAt,
            executionMode: executionMode
        )
        return .init(result: .success, currentResponse: freshCachedCurrentResponse, stormSetup: freshCachedStormSetup)
    }

    private static func isNewer(_ candidate: StormSetupDTO, than cached: StormSetupDTO) -> Bool {
        let candidateFreshness = candidate.freshness
        let cachedFreshness = cached.freshness
        let candidateValues = [
            candidateFreshness.modelRunTime,
            candidateFreshness.sourceValidTime,
            candidateFreshness.fetchedAt
        ]
        let cachedValues = [
            cachedFreshness.modelRunTime,
            cachedFreshness.sourceValidTime,
            cachedFreshness.fetchedAt
        ]

        for (candidateValue, cachedValue) in zip(candidateValues, cachedValues) {
            switch (candidateValue, cachedValue) {
            case let (candidateValue?, cachedValue?):
                if candidateValue != cachedValue {
                    return candidateValue > cachedValue
                }
            case (nil, nil):
                continue
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            }
        }

        return false
    }

    private static func isNewer(
        _ candidate: StormSetupCurrentResponse,
        than cached: StormSetupCurrentResponse
    ) -> Bool {
        isNewer(
            StormSetupDTO(response: candidate),
            than: StormSetupDTO(response: cached)
        )
    }

    private func shouldBackOff(
        for projectionKey: String,
        plan: HomeIngestionPlan,
        now: Date
    ) -> Bool {
        guard plan.provenance.contains(.background) || plan.provenance.contains(.sessionTick) else {
            return false
        }

        guard let state = refreshStates[projectionKey],
              state.lastAttemptFailed,
              let lastAttemptAt = state.lastAttemptAt else {
            return false
        }

        return now.timeIntervalSince(lastAttemptAt) < failedAttemptBackoff
    }

    private func markAttemptSucceeded(
        for projectionKey: String,
        refreshKey: LocationContext.RefreshKey,
        now: Date
    ) {
        refreshStates[projectionKey] = .init(
            refreshKey: refreshKey,
            lastAttemptAt: now,
            lastSuccessAt: now,
            lastAttemptFailed: false
        )
    }

    private func markAttemptFailed(
        for projectionKey: String,
        refreshKey: LocationContext.RefreshKey,
        now: Date
    ) {
        refreshStates[projectionKey] = .init(
            refreshKey: refreshKey,
            lastAttemptAt: now,
            lastSuccessAt: refreshStates[projectionKey]?.lastSuccessAt,
            lastAttemptFailed: true
        )
    }

    private func logOutcome(
        outcome: String,
        reason: String?,
        startedAt: Date,
        executionMode: HTTPExecutionMode
    ) {
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        if let reason {
            logger.info(
                "Storm Setup refresh outcome=\(outcome, privacy: .public) reason=\(reason, privacy: .public) mode=\(executionMode.logName, privacy: .public) durationMs=\(durationMs, privacy: .public)"
            )
        } else {
            logger.info(
                "Storm Setup refresh outcome=\(outcome, privacy: .public) mode=\(executionMode.logName, privacy: .public) durationMs=\(durationMs, privacy: .public)"
            )
        }
    }
}
