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
    struct RefreshDecision: Sendable {
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

    private struct QueryTimeoutError: Error {}

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

    private var refreshStates: [String: RefreshState] = [:]

    init(
        logger: Logger,
        querying: (any StormSetupQuerying)?,
        projectionStore: (any HomeProjectionPersisting)?,
        preferencesReader: @escaping @Sendable () async -> StormSetupPreferences,
        currentDate: @escaping @Sendable () -> Date,
        foregroundTimeout: TimeInterval,
        failedAttemptBackoff: TimeInterval
    ) {
        self.logger = logger
        self.querying = querying
        self.projectionStore = projectionStore
        self.preferencesReader = preferencesReader
        self.currentDate = currentDate
        self.foregroundTimeout = foregroundTimeout
        self.failedAttemptBackoff = failedAttemptBackoff
    }

    func refresh(
        context: LocationContext?,
        snapshot: HomeSnapshot,
        plan: HomeIngestionPlan,
        executionMode: HTTPExecutionMode
    ) async -> RefreshDecision {
        let startedAt = Date()
        let now = currentDate()

        guard let context else {
            logOutcome(
                outcome: "skipped",
                reason: "no-location",
                startedAt: startedAt,
                executionMode: executionMode
            )
            return .init(result: .skipped, currentResponse: nil, stormSetup: nil)
        }

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
        let cachedCurrentResponse = projection?.stormSetupCurrentResponse
        let cachedStormSetup = cachedCurrentResponse.map(StormSetupDTO.init(response:))
        let freshCachedCurrentResponse = cachedCurrentResponse.flatMap {
            $0.setup.freshness.expiresAt > now ? $0 : nil
        }
        let freshCachedStormSetup = freshCachedCurrentResponse.map(StormSetupDTO.init(response:))

        let policyInput = StormSetupPolicyInput(
            preferences: preferences,
            stormRisk: snapshot.stormRisk,
            severeRisk: snapshot.severeRisk,
            hasActiveAlert: snapshot.alerts.isEmpty == false,
            hasActiveMeso: snapshot.mesos.isEmpty == false,
            assessmentOverall: cachedStormSetup.map { StormSetupAssessment(dto: $0).assessment.overall },
            payloadExpiresAt: cachedStormSetup?.freshness.expiresAt,
            now: now
        )

        let shouldFetchPrimary = querying != nil && StormSetupFetchPolicy.shouldFetch(policyInput)
        let shouldBackOffPrimary = shouldBackOff(for: projectionKey, plan: plan, now: now)

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

        async let primaryOutcome: AttemptOutcome = {
            guard shouldFetchPrimary, let querying else {
                return .skipped
            }

            if shouldBackOffPrimary {
                return .skipped
            }

            return await performFetch(
                h3Cell: context.h3Cell,
                querying: querying,
                executionMode: executionMode
            )
        }()

        let resolvedPrimaryDecision = await handleOutcome(
            primaryOutcome,
            context: context,
            projectionKey: projectionKey,
            cachedCurrentResponse: cachedCurrentResponse,
            freshCachedCurrentResponse: freshCachedCurrentResponse,
            freshCachedStormSetup: freshCachedStormSetup,
            now: now,
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
            let foregroundTimeout = foregroundTimeout
            return try await withThrowingTaskGroup(of: StormSetupCurrentResponse.self) { group in
                group.addTask {
                    try await HTTPExecutionMode.$current.withValue(executionMode) {
                        try await querying.fetchCurrentStormSetup(h3Cell: h3Cell)
                    }
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(foregroundTimeout))
                    throw QueryTimeoutError()
                }

                do {
                    guard let stormSetup = try await group.next() else {
                        throw CancellationError()
                    }
                    group.cancelAll()
                    return stormSetup
                } catch {
                    group.cancelAll()
                    throw error
                }
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
            markAttemptFailed(
                for: projectionKey,
                refreshKey: context.refreshKey,
                now: now
            )
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
