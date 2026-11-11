//
//  LocationSession.swift
//  SkyAware
//
//  Created by Codex on 8/15/25.
//

import CoreLocation
import Observation
import OSLog
import SwiftUI
import ArcusCore

enum LocationStartupState: Equatable {
    case idle
    case requestingAuthorization
    case acquiringLocation
    case resolvingContext
    case ready
    case failed(String)
}

@MainActor
@Observable
final class LocationSession: Sendable {
    private var isUITestStaticHome: Bool {
        ProcessInfo.processInfo.environment["UI_TESTS_STATIC_HOME"] == "1"
    }

    private let logger = Logger.locationSession
    private let locationClient: LocationClient
    private let locationManager: LocationManager
    private let locationContextResolver: any LocationContextResolving
    private let locationUploadCoordinator: any LocationUploadCoordinating
    private let presenceNow: @MainActor @Sendable () -> Date
    private let durableContextCache: any DurableLocationContextCaching
    private let retentionCoordinator: HomeProjectionRetentionCoordinator
    private let onDisplayEnriched: @Sendable (LocationContext) async -> Void
    private let onContextPublished: @Sendable () async -> Void

    @ObservationIgnored
    private var updatesTask: Task<Void, Never>?
    @ObservationIgnored
    private var subscriptionIntentTask: Task<Void, Never>?
    @ObservationIgnored
    private var contextRefreshTask: Task<Void, Never>?
    @ObservationIgnored
    private var locationResolutionGeneration: UInt64 = 0
    @ObservationIgnored
    private var observationNotBefore: Date?
    @ObservationIgnored
    private var isPresenceEnrichmentSuppressed = false
    @ObservationIgnored
    private var resolvingSnapshot: LocationSnapshot?
    @ObservationIgnored
    private var pendingResolutionSnapshot: LocationSnapshot?
    @ObservationIgnored
    private var currentScenePhase: ScenePhase = .inactive

    var currentSnapshot: LocationSnapshot?
    private(set) var contextInterruptionRevision: UInt64 = 0
    var currentContext: LocationContext?
    var authorizationStatus: CLAuthorizationStatus
    var accuracyAuthorization: CLAccuracyAuthorization?
    var startupState: LocationStartupState = .idle
    var reliabilityState: LocationReliabilityState {
        LocationReliabilityState(
            authorizationStatus: authorizationStatus,
            accuracyAuthorization: accuracyAuthorization
        )
    }

    init(
        locationClient: LocationClient,
        locationManager: LocationManager,
        locationContextResolver: any LocationContextResolving,
        locationUploadCoordinator: any LocationUploadCoordinating,
        presenceNow: @escaping @MainActor @Sendable () -> Date = { .now },
        durableContextCache: any DurableLocationContextCaching = NoOpDurableLocationContextCache(),
        retentionCoordinator: HomeProjectionRetentionCoordinator = HomeProjectionRetentionCoordinator(),
        onContextPublished: @escaping @Sendable () async -> Void = {},
        onDisplayEnriched: @escaping @Sendable (LocationContext) async -> Void = { _ in }
    ) {
        self.locationClient = locationClient
        self.locationManager = locationManager
        self.locationContextResolver = locationContextResolver
        self.locationUploadCoordinator = locationUploadCoordinator
        self.presenceNow = presenceNow
        self.observationNotBefore = locationUploadCoordinator.minimumLocationObservationTimestamp
        self.durableContextCache = durableContextCache
        self.retentionCoordinator = retentionCoordinator
        self.onContextPublished = onContextPublished
        self.onDisplayEnriched = onDisplayEnriched
        self.authorizationStatus = locationManager.authStatus
        self.accuracyAuthorization = locationManager.accuracyAuthorization

        locationManager.setAuthorizationChangeHandler { [weak self] status, accuracy in
            guard let self else { return }
            self.applyAuthorizationSnapshot(status: status, accuracy: accuracy, source: "authorization-change")
        }

        if isUITestStaticHome == false {
            updatesTask = Task { [weak self] in
                guard let self else { return }

                let initialSnapshot = await locationClient.snapshot()
                if Task.isCancelled { return }
                self.currentSnapshot = initialSnapshot

                let stream = await locationClient.updates()
                for await snapshot in stream {
                    if Task.isCancelled { break }
                    await self.handleSnapshotUpdate(snapshot)
                }
            }
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        currentScenePhase = phase
        syncAuthorizationStatus()
        locationManager.updateMode(for: phase)
        if phase == .active, pendingResolutionSnapshot == nil {
            scheduleAuthorizationRecoveryIfNeeded()
            if startupState == .ready, durableContextCache.requiresPresenceEnrichment {
                Task { @MainActor [weak self] in
                    await self?.enqueueCurrentLocationUpload(source: .foregroundLocationChange, reason: .locationResolved)
                }
            } else if startupState == .ready || startupState == .idle,
                      let snapshot = currentSnapshot, shouldRefreshContext(for: snapshot) {
                Task { @MainActor [weak self] in
                    guard let self, let latest = self.currentSnapshot else { return }
                    await self.handleSnapshotUpdate(latest)
                }
            }
        }
        if phase == .active, let pending = pendingResolutionSnapshot {
            pendingResolutionSnapshot = nil
            Task { @MainActor [weak self] in await self?.handleSnapshotUpdate(pending) }
        }
    }

    func requestInteractiveAuthorization() {
        locationManager.checkLocationAuthorization(isActive: true)
        syncAuthorizationStatus()
    }

    @discardableResult
    func requestAlwaysAuthorizationUpgradeIfNeeded() -> Bool {
        let didRequestUpgrade = locationManager.requestAlwaysAuthorizationUpgradeIfNeeded()
        syncAuthorizationStatus()
        return didRequestUpgrade
    }

    func openSettings() {
        locationManager.openSettings()
    }

    func prepareCurrentLocationContext(
        requiresFreshLocation: Bool,
        showsAuthorizationPrompt: Bool,
        uploadSource: LocationUploadSource? = nil,
        uploadReason: LocationUploadReason? = nil,
        authorizationTimeout: Double = 30,
        locationTimeout: Double = 12,
        maximumAcceptedLocationAge: TimeInterval = 5 * 60,
        placemarkTimeout: Double = 8
    ) async -> LocationContext? {
        syncAuthorizationStatus()
        invalidateDurableContextIfMoved(by: currentSnapshot)
        let generation = beginLocationResolutionAttempt()

        if accuracyAuthorization == .reducedAccuracy ||
            (authorizationStatus.isLocationAuthorized == false && showsAuthorizationPrompt == false) {
            startupState = .failed("location-unavailable")
            await publishCurrentContext(nil)
            return nil
        }

        startupState = showsAuthorizationPrompt && authorizationStatus == .notDetermined
            ? .requestingAuthorization
            : .acquiringLocation

        do {
            let context = try await locationContextResolver.prepareCurrentContext(
                requiresFreshLocation: requiresFreshLocation || observationNotBefore != nil,
                showsAuthorizationPrompt: showsAuthorizationPrompt,
                authorizationTimeout: authorizationTimeout,
                locationTimeout: locationTimeout,
                maximumAcceptedLocationAge: maximumAcceptedLocationAge,
                placemarkTimeout: placemarkTimeout,
                minimumObservationTimestamp: observationNotBefore
            )
            guard isCurrentLocationResolution(generation) else { return nil }
            if let pending = pendingResolutionSnapshot, pending.timestamp > context.snapshot.timestamp,
               await processPendingSnapshot(generation: generation) {
                guard startupState == .ready, currentContext?.h3Cell == context.h3Cell else { return nil }
            }
            pendingResolutionSnapshot = nil
            guard await applyResolvedContext(context, generation: generation) else { return nil }
            guard isCurrentLocationResolution(generation) else { return nil }
            if await processPendingSnapshot(generation: generation), startupState != .ready { return nil }
            guard await reconcileResolvedContext(context, generation: generation) else { return nil }
            if let uploadSource {
                _ = await retainResolvedEnrichment(context, generation: generation,
                    source: uploadSource, reason: uploadReason ?? .locationResolved)
                guard isCurrentLocationResolution(generation) else { return nil }
            }
            startupState = .ready
            return context
        } catch {
            guard isCurrentLocationResolution(generation) else { return nil }
            if await processPendingSnapshot(generation: generation, requiresReplacement: true) { return nil }
            startupState = .failed(Self.failureCode(for: error))
            await publishCurrentContext(nil)
            return nil
        }
    }

    func prepareScheduledBackgroundLocationContext(
        uploadSource: LocationUploadSource?,
        uploadReason: LocationUploadReason?,
        authorizationTimeout: Double,
        locationTimeout: Double,
        maximumAcceptedLocationAge: TimeInterval,
        placemarkTimeout: Double
    ) async -> LocationContext? {
        syncAuthorizationStatus()
        let generation = beginLocationResolutionAttempt()

        guard accuracyAuthorization != .reducedAccuracy, observationNotBefore == nil else {
            // Background fresh acquisition retains the existing Always-only policy.
            guard authorizationStatus == .authorizedAlways else { return nil }
            return await prepareCurrentLocationContext(
                requiresFreshLocation: true, showsAuthorizationPrompt: false,
                uploadSource: uploadSource, uploadReason: uploadReason,
                authorizationTimeout: authorizationTimeout, locationTimeout: locationTimeout,
                maximumAcceptedLocationAge: maximumAcceptedLocationAge, placemarkTimeout: placemarkTimeout
            )
        }
        let providerSnapshot = await locationClient.snapshot()
        guard isCurrentLocationResolution(generation) else { return nil }
        let latestSnapshot = reconcileCurrentSnapshot(with: providerSnapshot)

        let cachedContext = durableContextCache.load()
        // A newer observation needs its own region lookup even inside the same H3 cell.
        // The two existing durable caches preserve this mismatch across process restart.
        if let latestSnapshot, acceptsPrecisionEvidence(latestSnapshot),
           cachedContext.map({ latestSnapshot.h3Cell == $0.h3Cell &&
               latestSnapshot.timestamp >= $0.snapshot.timestamp &&
               !Self.matchesPersistedObservation(latestSnapshot, $0.snapshot) }) ?? true {
            return await prepareCurrentLocationContext(
                requiresFreshLocation: false, showsAuthorizationPrompt: false,
                uploadSource: uploadSource, uploadReason: uploadReason,
                authorizationTimeout: authorizationTimeout, locationTimeout: locationTimeout,
                maximumAcceptedLocationAge: maximumAcceptedLocationAge, placemarkTimeout: placemarkTimeout
            )
        }
        let movementEvidence = movementEvidence(for: cachedContext, currentSnapshot: latestSnapshot)
        if movementEvidence != .none {
            durableContextCache.invalidate()
        }

        let policy = BackgroundLocationContextReusePolicy()
        let authorization = reuseAuthorization(for: authorizationStatus)
        let now = Date.now
        let refreshedContext = cachedContext.map {
            refreshedContextIfStable($0, snapshot: latestSnapshot)
        }
        let refreshedDecision = policy.decide(.init(
            authorization: authorization,
            cache: reuseCacheState(for: refreshedContext),
            movementEvidence: movementEvidence,
            now: now
        ))
        let reusableContext: LocationContext?
        if refreshedDecision == .reuseCachedContext {
            reusableContext = refreshedContext
        } else if let cachedContext,
                  refreshedContext?.snapshot != cachedContext.snapshot,
                  policy.decide(.init(
                      authorization: authorization,
                      cache: reuseCacheState(for: cachedContext),
                      movementEvidence: movementEvidence,
                      now: now
                  )) == .reuseCachedContext {
            reusableContext = cachedContext
        } else {
            reusableContext = nil
        }

        if let context = reusableContext {
            guard await applyResolvedContext(context, generation: generation, needsPresenceEnrichment: false) else { return nil }
            guard isCurrentLocationResolution(generation) else { return nil }
            guard await reconcileResolvedContext(context, generation: generation) else { return nil }
            if let uploadSource {
                // Reusing the same persisted observation is not a new presence intent.
                // Retry its outbox rather than creating an upload.
                let cached = cachedContext?.snapshot
                let isCachedObservation = cached.map {
                    context.snapshot.timestamp == $0.timestamp &&
                    context.snapshot.coordinates.latitude == $0.coordinates.latitude &&
                    context.snapshot.coordinates.longitude == $0.coordinates.longitude &&
                    context.snapshot.accuracy == $0.accuracy && context.snapshot.h3Cell == $0.h3Cell
                } ?? false
                if durableContextCache.requiresPresenceEnrichment {
                    _ = await retainResolvedEnrichment(context, generation: generation,
                        source: uploadSource, reason: uploadReason ?? .locationResolved)
                } else if isCachedObservation {
                    await locationUploadCoordinator.drainPendingUploads()
                } else {
                    await locationUploadCoordinator.enqueue(
                        context,
                        source: uploadSource,
                        reason: uploadReason ?? .locationResolved,
                        forceUpload: false
                    )
                }
                guard isCurrentLocationResolution(generation) else { return nil }
            }
            startupState = .ready
            return context
        }

        switch refreshedDecision {
        case .reuseCachedContext:
            return nil
        case .attemptFreshLocation:
            guard isCurrentLocationResolution(generation) else { return nil }
            return await prepareCurrentLocationContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false,
                uploadSource: uploadSource,
                uploadReason: uploadReason,
                authorizationTimeout: authorizationTimeout,
                locationTimeout: locationTimeout,
                maximumAcceptedLocationAge: maximumAcceptedLocationAge,
                placemarkTimeout: placemarkTimeout
            )
        case .skipLocationDependentWork:
            guard isCurrentLocationResolution(generation) else { return nil }
            startupState = .failed("location-context-unavailable")
            await publishCurrentContext(nil)
            return nil
        }
    }

    /// Called synchronously at the settings write. Only bookkeeping is chained;
    /// transport callbacks can execute in any order and always sync current consent.
    func captureNotificationPreferenceChange(enabled: Bool) -> Task<Void, Never> {
        let previous = subscriptionIntentTask
        let coordinator = locationUploadCoordinator
        let task = Task {
            await previous?.value
            await coordinator.acceptSubscriptionIntent(enabled: enabled)
        }
        subscriptionIntentTask = task
        return task
    }

    func syncNotificationPreference(after intent: Task<Void, Never>) async {
        await intent.value
        await syncPreference(forceUpload: true, reason: "notification")
    }

    func syncNotificationPreference(enabled: Bool) async {
        await syncPreference(forceUpload: true, reason: "notification", isSubscribedOverride: enabled)
    }

    func syncMesoNotificationPreference() async {
        await syncPreference(forceUpload: true, reason: "meso-notification")
    }

    /// Synchronous with the Settings write; transport callbacks cannot erase an intermediate reversal.
    func captureLocationSharingPreferenceChange(enabled: Bool) {
        let cutoff = presenceNow()
        locationUploadCoordinator.invalidateLocationEvidence(at: cutoff)
        durableContextCache.completePresenceEnrichment()
        isPresenceEnrichmentSuppressed = !enabled
        if enabled {
            observationNotBefore = cutoff
            _ = beginLocationResolutionAttempt()
            startupState = .failed("location-evidence-required")
            scheduleAuthorizationRecoveryIfNeeded()
        }
    }

    func syncLocationSharingPreference(enabled _: Bool) async {
        await syncPreference(forceUpload: true, reason: "location-sharing")
    }

    func updateLocationSharingPreference(enabled: Bool) async {
        if enabled {
            _ = requestAlwaysAuthorizationUpgradeIfNeeded()
        }
        await syncLocationSharingPreference(enabled: enabled)
    }

    func enqueueCurrentLocationUpload(source: LocationUploadSource, reason: LocationUploadReason) async {
        guard let context = await resolveCurrentContextIfNeeded(),
              await reconcileResolvedContext(context, generation: locationResolutionGeneration) else { return }
        _ = await retainResolvedEnrichment(context, generation: locationResolutionGeneration, source: source, reason: reason)
    }

    func drainPendingLocationUploads() async {
        await locationUploadCoordinator.drainPendingUploads()
        await syncMesoNotificationPreference()
    }

    private func syncPreference(
        forceUpload: Bool,
        reason: String,
        isSubscribedOverride: Bool? = nil
    ) async {
        logger.notice("Queueing preference sync reason=\(reason, privacy: .public)")
        await locationUploadCoordinator.enqueuePreferenceSync(
            source: .settingsPreference,
            requestReason: .preferenceChanged,
            forceUpload: forceUpload,
            detail: reason,
            isSubscribedOverride: isSubscribedOverride
        )
    }

    private func resolveCurrentContextIfNeeded() async -> LocationContext? {
        if let currentContext {
            return currentContext
        }

        guard let currentSnapshot else { return nil }
        let generation = beginLocationResolutionAttempt()
        guard let resolvedContext = try? await locationContextResolver.resolveContext(
            from: currentSnapshot,
            maximumAcceptedLocationAge: nil,
            placemarkTimeout: 8
        ) else {
            return nil
        }

        guard isCurrentLocationResolution(generation) else { return nil }
        self.currentSnapshot = resolvedContext.snapshot
        await applyResolvedContext(resolvedContext, generation: generation)
        guard isCurrentLocationResolution(generation) else { return nil }
        return resolvedContext
    }

    private func syncAuthorizationStatus() {
        if observationNotBefore == .distantFuture {
            observationNotBefore = locationUploadCoordinator.minimumLocationObservationTimestamp
        }
        applyAuthorizationSnapshot(
            status: locationManager.authStatus,
            accuracy: locationManager.accuracyAuthorization,
            source: "sync"
        )
    }

    private func applyAuthorizationSnapshot(
        status: CLAuthorizationStatus,
        accuracy: CLAccuracyAuthorization?,
        source: String
    ) {
        let hadAuthorizationChange = authorizationStatus != status
        let hadAccuracyChange = accuracyAuthorization != accuracy
        let hadChange = hadAuthorizationChange || hadAccuracyChange

        if hadAuthorizationChange {
            authorizationStatus = status
            Task { [weak self] in
                await self?.syncMesoNotificationPreference()
            }
        }
        if hadAccuracyChange {
            accuracyAuthorization = accuracy
        }

        guard hadChange else { return }

        let reliability = reliabilityState
        logger.info(
            "Location reliability updated source=\(source, privacy: .public) authorization=\(reliability.authorization.logName, privacy: .public) accuracy=\(reliability.accuracy.logName, privacy: .public) nextAction=\(reliability.nextAction.logName, privacy: .public)"
        )

        // A permission transition invalidates pending work, not the accepted Home projection.
        observationNotBefore = presenceNow()
        if let observationNotBefore {
            locationUploadCoordinator.invalidateLocationEvidence(at: observationNotBefore)
        }
        let generation = beginLocationResolutionAttempt()
        if status.isLocationAuthorized == false || accuracy == .reducedAccuracy {
            let hadContext = currentContext != nil
            startupState = .failed("location-unavailable")
            Task { @MainActor [weak self] in
                guard let self, self.isCurrentLocationResolution(generation) else { return }
                await self.publishCurrentContext(nil)
            }
            logger.notice("Location access unavailable; currentContextReset=\(hadContext, privacy: .public)")
        } else {
            startupState = .failed("location-evidence-required")
            scheduleAuthorizationRecoveryIfNeeded()
        }
    }

    private func scheduleAuthorizationRecoveryIfNeeded() {
        guard currentScenePhase == .active, authorizationStatus.isLocationAuthorized,
              accuracyAuthorization != .reducedAccuracy,
              case .failed = startupState else { return }
        Task { @MainActor [weak self] in
            guard let self, self.currentScenePhase == .active,
                  self.authorizationStatus.isLocationAuthorized,
                  self.accuracyAuthorization != .reducedAccuracy,
                  case .failed = self.startupState else { return }
            _ = await self.prepareCurrentLocationContext(
                requiresFreshLocation: true,
                showsAuthorizationPrompt: false,
                uploadSource: .foregroundLocationChange,
                uploadReason: .locationResolved
            )
        }
    }

    private func handleSnapshotUpdate(_ snapshot: LocationSnapshot) async {
        // Display-only stream updates must not restart NWS resolution or presence ingestion.
        if let context = currentContext, context.snapshot.hasSameObservation(as: snapshot) {
            currentSnapshot = snapshot
            let enriched = refreshedContextIfStable(context, snapshot: snapshot)
            currentContext = enriched
            if enriched.snapshot.placemarkSummary != context.snapshot.placemarkSummary {
                await onDisplayEnriched(enriched)
            }
            return
        }
        if currentSnapshot != snapshot {
            currentSnapshot = snapshot
        }

        guard currentScenePhase == .active, authorizationStatus.isLocationAuthorized,
              acceptsPrecisionEvidence(snapshot) else { return }
        switch startupState {
        case .idle, .ready, .failed:
            break
        case .resolvingContext:
            if snapshot != resolvingSnapshot {
                pendingResolutionSnapshot = snapshot
            }
            return
        case .requestingAuthorization, .acquiringLocation:
            pendingResolutionSnapshot = snapshot
            return
        default:
            return
        }
        guard shouldRefreshContext(for: snapshot) else { return }

        let generation = beginLocationResolutionAttempt()
        resolvingSnapshot = snapshot
        startupState = .resolvingContext
        contextRefreshTask = Task { [weak self] in
            guard let self else { return }

            do {
                let context = try await self.locationContextResolver.resolveContext(
                    from: snapshot,
                    maximumAcceptedLocationAge: 5 * 60,
                    placemarkTimeout: 8
                )
                guard Task.isCancelled == false,
                      self.isCurrentLocationResolution(generation) else { return }

                if await self.processPendingSnapshot(generation: generation) { return }
                guard await self.applyResolvedContext(context, generation: generation) else { return }
                guard self.isCurrentLocationResolution(generation) else { return }
                if await self.processPendingSnapshot(generation: generation), self.startupState != .ready { return }
                guard await self.reconcileResolvedContext(context, generation: generation) else { return }
                self.startupState = .ready
                // Independent presence must still be followed by current geographic enrichment.
                _ = await self.retainResolvedEnrichment(context, generation: generation,
                    source: .foregroundLocationChange, reason: .locationChanged)
            } catch is CancellationError {
                return
            } catch {
                guard self.isCurrentLocationResolution(generation) else { return }
                if await self.processPendingSnapshot(generation: generation, requiresReplacement: true) { return }
                self.startupState = .failed(Self.failureCode(for: error))
                await self.publishCurrentContext(nil)
            }
        }
    }

    private func processPendingSnapshot(generation: UInt64, requiresReplacement: Bool = false) async -> Bool {
        guard isCurrentLocationResolution(generation), let pending = pendingResolutionSnapshot else { return false }
        if requiresReplacement {
            guard currentScenePhase == .active, authorizationStatus.isLocationAuthorized else { return false }
            guard shouldRefreshContext(for: pending) else {
                pendingResolutionSnapshot = nil
                return false
            }
        }
        startupState = currentContext == nil ? .failed("location-context-superseded") : .ready
        guard currentScenePhase == .active, authorizationStatus.isLocationAuthorized else { return true }
        pendingResolutionSnapshot = nil
        await handleSnapshotUpdate(pending)
        return true
    }

    private func beginLocationResolutionAttempt() -> UInt64 {
        locationResolutionGeneration &+= 1
        contextRefreshTask?.cancel()
        contextRefreshTask = nil
        resolvingSnapshot = nil
        pendingResolutionSnapshot = nil
        return locationResolutionGeneration
    }

    private func isCurrentLocationResolution(_ generation: UInt64) -> Bool {
        locationResolutionGeneration == generation
    }

    private func retainResolvedEnrichment(
        _ context: LocationContext, generation: UInt64, source: LocationUploadSource, reason: LocationUploadReason
    ) async -> Bool {
        guard !isPresenceEnrichmentSuppressed, locationUploadCoordinator.isLocationSharingEnabled else { return false }
        let retained = await locationUploadCoordinator.enqueueEnrichment(context, source: source, reason: reason)
        guard isCurrentLocationResolution(generation), matchesLatestGeography(context) else { return false }
        guard retained else { return false }
        durableContextCache.completePresenceEnrichment()
        return true
    }

    private func applyResolvedContext(
        _ context: LocationContext, generation: UInt64, needsPresenceEnrichment: Bool = true
    ) async -> Bool {
        guard await reconcileResolvedContext(context, generation: generation) else { return false }
        guard await publishCurrentContext(context, when: {
            self.isCurrentLocationResolution(generation) && self.matchesLatestGeography(context)
        }) else {
            _ = await reconcileResolvedContext(context, generation: generation)
            return false
        }
        // Publication can suspend for retention work or its callback; recheck before persisting/uploading.
        guard await reconcileResolvedContext(context, generation: generation) else { return false }
        if let currentSnapshot, currentSnapshot.timestamp > context.snapshot.timestamp {
            // Preserve a newer streamed fix until its pending resolution completes.
        } else {
            currentSnapshot = context.snapshot
        }
        observationNotBefore = nil
        if needsPresenceEnrichment, !isPresenceEnrichmentSuppressed,
           locationUploadCoordinator.isLocationSharingEnabled {
            durableContextCache.saveForPresenceEnrichment(context)
        } else {
            durableContextCache.save(context)
        }
        return true
    }

    private func acceptsPrecisionEvidence(_ snapshot: LocationSnapshot) -> Bool {
        accuracyAuthorization != .reducedAccuracy &&
            snapshot.accuracy.isFinite && snapshot.accuracy > 0 &&
            snapshot.accuracy <= LocationThrottleConfig().minAccuracy &&
            (observationNotBefore.map { snapshot.timestamp >= $0 } ?? true)
    }

    private func matchesLatestGeography(_ context: LocationContext) -> Bool {
        guard let currentSnapshot, acceptsPrecisionEvidence(currentSnapshot),
              currentSnapshot.timestamp > context.snapshot.timestamp else { return true }
        return currentSnapshot.hasSameObservation(as: context.snapshot)
    }

    private func reconcileResolvedContext(_ context: LocationContext, generation: UInt64) async -> Bool {
        let latest = await locationClient.snapshot()
        guard isCurrentLocationResolution(generation) else { return false }
        guard authorizationStatus.isLocationAuthorized, acceptsPrecisionEvidence(context.snapshot) else {
            startupState = .failed("location-evidence-required")
            return false
        }
        _ = reconcileCurrentSnapshot(with: latest)
        guard matchesLatestGeography(context) else {
            pendingResolutionSnapshot = currentSnapshot
            _ = await processPendingSnapshot(generation: generation)
            return false
        }
        return true
    }

    func publishCurrentContext(_ context: LocationContext?) async {
        _ = await publishCurrentContext(context, when: { true })
    }

    private func publishCurrentContext(_ context: LocationContext?, when isCurrent: () -> Bool) async -> Bool {
        var didPublish = false
        await retentionCoordinator.publish(context, when: isCurrent) {
            if context == nil, currentContext != nil {
                contextInterruptionRevision &+= 1
            }
            currentContext = context
            didPublish = true
        }
        guard didPublish else { return false }
        await onContextPublished()
        return true
    }

    private func invalidateDurableContextIfMoved(by snapshot: LocationSnapshot?) {
        guard let cachedContext = durableContextCache.load(),
              movementEvidence(for: cachedContext, currentSnapshot: snapshot) != .none else {
            return
        }
        durableContextCache.invalidate()
    }

    private func movementEvidence(
        for cachedContext: LocationContext?,
        currentSnapshot: LocationSnapshot?
    ) -> BackgroundLocationContextReusePolicy.MovementEvidence {
        guard let cachedContext, let currentSnapshot,
              currentSnapshot.timestamp > cachedContext.snapshot.timestamp else {
            return .none
        }
        guard currentSnapshot.h3Cell == cachedContext.h3Cell else {
            return .significantLocationChange
        }
        return .none
    }

    private func reconcileCurrentSnapshot(with providerSnapshot: LocationSnapshot?) -> LocationSnapshot? {
        guard let providerSnapshot else { return currentSnapshot }
        guard let currentSnapshot, currentSnapshot.timestamp > providerSnapshot.timestamp else {
            currentSnapshot = providerSnapshot
            return providerSnapshot
        }
        return currentSnapshot
    }

    private func refreshedContextIfStable(_ context: LocationContext, snapshot: LocationSnapshot?) -> LocationContext {
        guard let snapshot,
              snapshot.timestamp >= context.snapshot.timestamp,
              snapshot.h3Cell == context.h3Cell else {
            return context
        }
        if snapshot.timestamp == context.snapshot.timestamp {
            guard snapshot.coordinates.latitude == context.snapshot.coordinates.latitude,
                  snapshot.coordinates.longitude == context.snapshot.coordinates.longitude,
                  context.snapshot.placemarkSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
                  let name = snapshot.placemarkSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
                  name.isEmpty == false else {
                return context
            }
            var enrichedSnapshot = context.snapshot
            enrichedSnapshot.placemarkSummary = name
            return LocationContext(snapshot: enrichedSnapshot, h3Cell: context.h3Cell, grid: context.grid)
        }
        return LocationContext(snapshot: snapshot, h3Cell: context.h3Cell, grid: context.grid)
    }

    private func reuseCacheState(
        for context: LocationContext?
    ) -> BackgroundLocationContextReusePolicy.CacheState {
        guard let context else { return .missing }
        return .available(.init(
            coordinatesAreValid: CLLocationCoordinate2DIsValid(context.snapshot.coordinates),
            timestamp: context.snapshot.timestamp,
            horizontalAccuracy: context.snapshot.accuracy,
            isComplete: context.grid.countyCode?.isEmpty == false && context.grid.fireZone?.isEmpty == false
        ))
    }

    private func reuseAuthorization(for status: CLAuthorizationStatus) -> BackgroundLocationContextReusePolicy.Authorization {
        switch status {
        case .authorizedAlways: .always
        case .authorizedWhenInUse: .whenInUse
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .unknown
        }
    }

    private func shouldRefreshContext(for snapshot: LocationSnapshot) -> Bool {
        guard observationNotBefore == nil, let currentContext else { return true }
        guard let snapshotH3Cell = snapshot.h3Cell else { return false }
        return currentContext.h3Cell != snapshotH3Cell ||
            !currentContext.snapshot.hasSameObservation(as: snapshot)
    }

    private static func matchesPersistedObservation(_ lhs: LocationSnapshot, _ rhs: LocationSnapshot) -> Bool {
        lhs.hasSameObservation(as: rhs)
    }

    private static func failureCode(for error: Error) -> String {
        guard let error = error as? LocationContextError else {
            return "location-context-error"
        }

        switch error {
        case .locationUnavailable:
            return "location-unavailable"
        case .authorizationTimeout:
            return "authorization-timeout"
        case .locationTimeout:
            return "location-timeout"
        case .missingH3Cell:
            return "location-missing-h3"
        case .missingRegionContext:
            return "location-missing-region-context"
        }
    }
}

extension LocationSession {
    @MainActor
    static var preview: LocationSession {
        let provider = LocationProvider(
            snapshotCache: NoOpLocationSnapshotCache()
        )
        let sink: LocationSink = { [provider] update in
            await provider.send(update: update)
        }
        let manager = LocationManager(onUpdate: sink)
        let nwsClient = NwsHttpClient(http: URLSessionHTTPClient())
        let metadataRepo = NwsMetadataRepo()
        let gridPointProvider = GridPointProvider(
            client: nwsClient,
            repo: metadataRepo
        )
        let resolver = LocationContextResolver(
            locationClient: makeLocationClient(provider: provider),
            locationProvider: provider,
            gridPointProvider: gridPointProvider,
            authorizationStatusProvider: {
                await MainActor.run { manager.authStatus }
            },
            authorizationRequester: { isActive in
                await MainActor.run {
                    manager.checkLocationAuthorization(isActive: isActive)
                }
            },
            refreshCurrentLocation: { timeout in
                await manager.refreshCurrentLocation(timeout: timeout)
            }
        )
        let session = LocationSession(
            locationClient: makeLocationClient(provider: provider),
            locationManager: manager,
            locationContextResolver: resolver,
            locationUploadCoordinator: NoOpLocationUploadCoordinator()
        )
        session.currentSnapshot = LocationSnapshot(
            coordinates: .init(latitude: 39.75, longitude: -104.44),
            timestamp: .now,
            accuracy: 20,
            placemarkSummary: "Bennett, CO",
            h3Cell: 0x882681b485fffff
        )
        session.currentContext = LocationContext(
            snapshot: session.currentSnapshot!,
            h3Cell: 0x882681b485fffff,
            grid: GridPointSnapshot(
                nwsId: "https://api.weather.gov/points/39.75,-104.44",
                latitude: 39.75,
                longitude: -104.44,
                gridId: "BOU",
                gridX: 56,
                gridY: 66,
                forecastURL: nil,
                forecastHourlyURL: nil,
                forecastGridDataURL: nil,
                observationStationsURL: nil,
                city: "Bennett",
                state: "CO",
                timeZoneId: "America/Denver",
                radarStationId: "KFTG",
                forecastZone: "COZ039",
                countyCode: "COC005",
                fireZone: "COZ246",
                countyLabel: "Arapahoe County",
                fireZoneLabel: "East Central Colorado"
            )
        )
        session.startupState = .ready
        return session
    }
}
