//
//  LocationSnapshotPusher.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/8/26.
//

import CoreLocation
import Foundation
import OSLog
import Synchronization
import UIKit
import ArcusCore

enum LocationUploadReason: String, Sendable, Codable, Equatable {
    case locationResolved
    case locationChanged
    case preferenceChanged
    case tokenBecameAvailable
    case retry
}

struct PendingLocationUploadDrainBudget: Sendable {
    let uploadQuota: Int
    let deadline: ContinuousClock.Instant

    init(uploadQuota: Int, deadline: ContinuousClock.Instant) {
        self.uploadQuota = max(uploadQuota, 0)
        self.deadline = deadline
    }
}

enum PendingLocationUploadDrainOutcome: Sendable, Equatable {
    case drained
    case remaining
}

protocol PendingLocationUploadDraining: Sendable {
    func drainPendingUploads() async
    func drainPendingUploads(using budget: PendingLocationUploadDrainBudget) async -> PendingLocationUploadDrainOutcome
}

/// Presence admission needs accepted observation evidence, independently of weather context.
protocol LocationPresenceEnqueuing: Sendable {
    /// True when the intent is durably retained (possibly superseded) or already acknowledged.
    @discardableResult
    func enqueuePresence(
        _ observation: LocationSnapshot,
        source: LocationUploadSource,
        reason: LocationUploadReason
    ) async -> Bool
    func enqueueForegroundPresence(_ observation: LocationSnapshot,
        isEligible: @escaping @MainActor @Sendable () -> Bool) async -> Bool

}

extension LocationPresenceEnqueuing {
    func enqueueForegroundPresence(_ observation: LocationSnapshot,
        isEligible: @escaping @MainActor @Sendable () -> Bool) async -> Bool {
        guard await isEligible() else { return false }
        return await enqueuePresence(observation, source: .foregroundLocationChange, reason: .locationChanged)
    }
}

protocol LocationUploadCoordinating: PendingLocationUploadDraining, Sendable {
    var minimumLocationObservationTimestamp: Date? { get }
    func invalidateLocationEvidence(at date: Date)
    func acceptSubscriptionIntent(enabled: Bool) async
    func enqueue(
        _ context: LocationContext,
        source: LocationUploadSource,
        reason: LocationUploadReason,
        forceUpload: Bool
    ) async
    func enqueuePreferenceSync(
        source: LocationUploadSource,
        requestReason: LocationUploadReason,
        forceUpload: Bool,
        detail: String,
        isSubscribedOverride: Bool?
    ) async
}

extension LocationUploadCoordinating {
    var minimumLocationObservationTimestamp: Date? { nil }
    func invalidateLocationEvidence(at date: Date) {}
    func acceptSubscriptionIntent(enabled: Bool) async {}
    func enqueuePreferenceSync(
        source: LocationUploadSource,
        requestReason: LocationUploadReason,
        forceUpload: Bool,
        detail: String
    ) async {
        await enqueuePreferenceSync(
            source: source,
            requestReason: requestReason,
            forceUpload: forceUpload,
            detail: detail,
            isSubscribedOverride: nil
        )
    }
}

enum LocationPushError: Error {
    case invalidResponseStatus(Int)
    case presenceNotAccepted
}

actor LocationSnapshotPusher: LocationUploadCoordinating, LocationPresenceEnqueuing {
    typealias APNsTokenProvider = @Sendable () -> String
    typealias InstallationIDProvider = @Sendable () async -> String
    typealias SubscriptionStatusProvider = @Sendable () -> Bool
    typealias LocationUploadEnabledProvider = @Sendable () -> Bool
    typealias AuthorizationStatusProvider = @Sendable () -> CLAuthorizationStatus
    typealias NowProvider = @Sendable () -> Date

    nonisolated private static let userDefaultsSuiteName = "com.justinrooks.skyaware"
    nonisolated private static let serverNotificationEnabledKey = "serverNotificationEnabled"
    nonisolated private static let locationUploadEnabledKey = "sendL8ntoSignal"
    nonisolated private static let pendingRequestsKey = "pendingLocationUploadRequests"

    private let locationUploader: any LocationSnapshotUploading
    private let preferenceUploader: any DevicePreferenceSyncUploading
    private let apnsTokenProvider: APNsTokenProvider
    private let installationIdProvider: InstallationIDProvider
    private let subscriptionStatusProvider: SubscriptionStatusProvider
    private let mesoNotificationEnabledProvider: SubscriptionStatusProvider
    private let locationUploadEnabledProvider: LocationUploadEnabledProvider
    private let authorizationStatusProvider: AuthorizationStatusProvider
    private let accuracyAuthorizationProvider: @Sendable () -> CLAccuracyAuthorization
    private let osVersionProvider: @Sendable () async -> String
    private let nowProvider: NowProvider
    private let retryDelaysSeconds: [UInt64]
    private let dedupeWindowSeconds: TimeInterval
    private let queueStore: any LocationUploadQueueStoring
    private let logger = Logger.locationPushPusher

    nonisolated private let locationTransfers = Mutex<[UUID: Task<Void, Error>]>([:])

    private var queue: [QueuedUpload] = []
    private var isProcessing = false
    private var lastObservedConsent: DeviceConsentSnapshotV3?
    private var lastObservedEvidenceCutoff: Date?
    private var lastUploadBySemanticKey: [DeduplicationKey: (uploadedAt: Date, capturedAt: Date?)] = [:]
    private var pendingByCoalescingKey: [PendingCoalescingKey: PersistedLocationUploadRequest] = [:]
    private var queuedOrActiveCoalescingKeys: Set<PendingCoalescingKey> = []
    private var activeRequests: [PendingCoalescingKey: PersistedLocationUploadRequest] = [:]
    private var preparedKeys: [PendingCoalescingKey: DeduplicationKey] = [:]
    private var hasLoadedPersistedPending = false
    private var newestContextByCoalescingKey: [PendingCoalescingKey: PersistedLocationContext] = [:]
    private struct DeferredEnrichment {
        let context: PersistedLocationContext
        let source: LocationUploadSource
        let reason: LocationUploadReason
        let forceUpload: Bool
    }
    // Only explicit enrichment that could not enter the durable outbox is retried here.
    private var deferredEnrichment: [String: DeferredEnrichment] = [:]
    private var admissionRevision: UInt64 = 0
    private var successfulAdmissions: [String: (revision: UInt64, context: PersistedLocationContext)] = [:]
    private var pendingLoad: Task<[PersistedLocationUploadRequest], Never>?
    private var committedPending: [PendingCoalescingKey: PersistedLocationUploadRequest] = [:]
    private var pendingSaveCount = 0
    private var pendingSave: Task<Bool, Never>?
    // An opt-out may restrict lagging defaults. An opt-in requires confirmation
    // from the setting provider: asynchronous callbacks can arrive out of order.
    private var subscriptionOverride: (value: Bool, baseline: Bool)?

    private enum TransferSuppressed: Error { case obsolete, persistencePending }
    private enum UploadOutcome { case uploaded, discarded, pending }

    init(
        locationUploader: any LocationSnapshotUploading,
        preferenceUploader: any DevicePreferenceSyncUploading,
        apnsTokenProvider: @escaping APNsTokenProvider = {
            LocationSnapshotPusher.readApnsTokenFromDefaults()
        },
        installationIdProvider: @escaping InstallationIDProvider = {
            InstallationIdentityStore.shared.installationId()
        },
        subscriptionStatusProvider: @escaping SubscriptionStatusProvider = {
            LocationSnapshotPusher.readSubscriptionStatusFromDefaults()
        },
        mesoNotificationEnabledProvider: @escaping SubscriptionStatusProvider = {
            UserDefaults(suiteName: "com.justinrooks.skyaware")?
                .object(forKey: "mesoNotificationEnabled") as? Bool ?? true
        },
        locationUploadEnabledProvider: @escaping LocationUploadEnabledProvider = {
            LocationSnapshotPusher.readLocationUploadEnabledFromDefaults()
        },
        authorizationStatusProvider: @escaping AuthorizationStatusProvider = {
            CLLocationManager().authorizationStatus
        },
        accuracyAuthorizationProvider: @escaping @Sendable () -> CLAccuracyAuthorization = {
            CLLocationManager().accuracyAuthorization
        },
        osVersionProvider: @escaping @Sendable () async -> String = { await UIDevice.current.systemVersion },
        nowProvider: @escaping NowProvider = { Date() },
        retryDelaysSeconds: [UInt64] = [0, 5, 15],
        dedupeWindowSeconds: TimeInterval = 15,
        queueStore: (any LocationUploadQueueStoring)? = nil
    ) {
        self.locationUploader = locationUploader
        self.preferenceUploader = preferenceUploader
        self.apnsTokenProvider = apnsTokenProvider
        self.installationIdProvider = installationIdProvider
        self.mesoNotificationEnabledProvider = mesoNotificationEnabledProvider
        self.subscriptionStatusProvider = subscriptionStatusProvider
        self.locationUploadEnabledProvider = locationUploadEnabledProvider
        self.authorizationStatusProvider = authorizationStatusProvider
        self.accuracyAuthorizationProvider = accuracyAuthorizationProvider
        self.osVersionProvider = osVersionProvider
        self.nowProvider = nowProvider
        self.retryDelaysSeconds = retryDelaysSeconds
        self.dedupeWindowSeconds = dedupeWindowSeconds
        self.queueStore = queueStore ?? UserDefaultsLocationUploadQueueStore(
            suiteName: Self.userDefaultsSuiteName,
            key: Self.pendingRequestsKey
        )
    }

    func enqueue(
        _ context: LocationContext,
        source: LocationUploadSource,
        reason: LocationUploadReason,
        forceUpload: Bool = false
    ) async {
        _ = await enqueueLocation(PersistedLocationContext(context), source: source, reason: reason, forceUpload: forceUpload, retainEnrichmentOnFailure: true)
    }

    @discardableResult
    func enqueuePresence(
        _ observation: LocationSnapshot,
        source: LocationUploadSource,
        reason: LocationUploadReason
    ) async -> Bool {
        guard let context = PersistedLocationContext(observation: observation, now: nowProvider()) else { return false }
        return await enqueueLocation(context, source: source, reason: reason, forceUpload: false)
    }

    /// Retains background evidence without spending the delivery grant on transport first.
    func retainBackgroundPresence(_ observation: LocationSnapshot) async -> Bool {
        await retainPresence(observation, source: .backgroundLocationChange)
    }

    /// Admission completes at the durable boundary; callers choose their transport grant.
    func retainPresence(_ observation: LocationSnapshot, source: LocationUploadSource) async -> Bool {
        guard let context = PersistedLocationContext(observation: observation, now: nowProvider()) else { return false }
        return await enqueueLocation(
            context, source: source, reason: .locationChanged,
            forceUpload: false, processImmediately: false
        )
    }

    private func enqueueLocation(
        _ context: PersistedLocationContext,
        source: LocationUploadSource,
        reason: LocationUploadReason,
        forceUpload: Bool,
        processImmediately: Bool = true,
        retainEnrichmentOnFailure: Bool = false,
        admissionOnly: Bool = false
    ) async -> Bool {
        guard accuracyAuthorizationProvider() == .fullAccuracy,
              context.horizontalAccuracyMeters.isFinite, context.horizontalAccuracyMeters > 0,
              context.horizontalAccuracyMeters <= LocationThrottleConfig().minAccuracy else { return false }
        logger.info(
            "Location upload request accepted source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
        )
        guard forceUpload || locationUploadEnabledProvider() else {
            observeConsent(subscribed: currentSubscription(), authorization: authorizationStatusProvider())
            logger.notice(
                "Location upload request skipped skipReason=disabled source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
            )
            return false
        }

        await ensurePersistedPendingLoaded()
        let installationId = await installationIdProvider()
        admissionRevision &+= 1
        let revision = admissionRevision
        if let deferred = deferredEnrichment[installationId], canReplace(deferred.context, with: context) {
            deferredEnrichment.removeValue(forKey: installationId)
        }
        var admissionFailed = false
        defer {
            if retainEnrichmentOnFailure, admissionFailed,
               successfulAdmissions[installationId].map({ $0.revision < revision || !canReplace(context, with: $0.context) }) ?? true,
               newestContextByCoalescingKey[.location(installationId: installationId)].map({ canReplace($0, with: context) }) ?? true,
               deferredEnrichment[installationId].map({ canReplace($0.context, with: context) }) ?? true {
                deferredEnrichment[installationId] = .init(context: context, source: source, reason: reason, forceUpload: forceUpload)
            }
        }
        do {
            try await preferenceUploader.reconcileConsent(installationId: installationId)
            if let cutoff = try await preferenceUploader.locationEvidenceCutoff(installationId: installationId),
               context.capturedAt < cutoff { return false }
        } catch {
            logger.error("Consent persistence unavailable; device sync deferred")
            admissionFailed = true
            return false
        }
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let isSubscribed = currentSubscription()
        let authorizationStatus = authorizationStatusProvider()
        let now = nowProvider()
        let mesoNotificationsEnabled = mesoNotificationEnabledProvider()
        observeConsent(subscribed: isSubscribed, authorization: authorizationStatus)
        var persisted = PersistedLocationUploadRequest(
            source: source,
            reason: reason,
            forceUpload: forceUpload,
            installationId: installationId,
            requestedAt: now,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            apnsToken: apnsToken,
            operation: .locationSnapshot(context: context),
            mesoNotificationsEnabled: mesoNotificationsEnabled
        )

        let dedupeKey = DeduplicationKey(
            installationId: installationId,
            apnsToken: apnsToken,
            operation: .locationSnapshot(
                h3Cell: context.h3Cell,
                county: context.county,
                fireZone: context.fireZone,
                forecastZone: context.forecastZone
            ),
            isSubscribed: isSubscribed,
            mesoNotificationsEnabled: persisted.mesoNotificationsEnabled,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            forceUpload: forceUpload
        )
        if shouldDedupeRequest(for: dedupeKey, now: now, capturedAt: context.capturedAt) {
            if successfulAdmissions[installationId].map({ $0.revision < revision }) ?? true {
                successfulAdmissions[installationId] = (revision, context)
            }
            logger.notice(
                "Location upload request deduped source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
            )
            return true
        }
        await waitForPendingSave()
        let coalescingKey = coalescingKey(for: persisted)
        if let newest = newestContextByCoalescingKey[coalescingKey], !canReplace(newest, with: context) {
            return await persistPendingState()
        }
        newestContextByCoalescingKey[coalescingKey] = context
        if let existing = pendingByCoalescingKey[coalescingKey], existing.operation == persisted.operation {
            persisted = existing
        }
        guard await upsertPending(persisted) else {
            admissionFailed = true
            return false
        }
        if successfulAdmissions[installationId].map({ $0.revision < revision }) ?? true {
            successfulAdmissions[installationId] = (revision, context)
        }
        // Persistence suspends: a newer observation may already own this key.
        guard pendingByCoalescingKey[coalescingKey] == persisted else { return true }
        guard !admissionOnly else { return true }
        guard enqueueIfNotQueuedOrActive(
            QueuedUpload(
                request: persisted,
                coalescingKey: coalescingKey,
                semanticDedupeKey: dedupeKey,
                reason: reason,
                source: source.rawValue
            )
        ) else { return true }

        guard processImmediately, !isProcessing else { return true }
        await processQueue()
        return true
    }

    nonisolated var minimumLocationObservationTimestamp: Date? {
        do { return try preferenceUploader.savedLocationEvidenceCutoff() }
        catch { return .distantFuture }
    }

    nonisolated func invalidateLocationEvidence(at date: Date) {
        // Registration and invalidation share a lock, including the durable cutoff write.
        // A transfer either sees the new cutoff or is included in this cancellation set.
        locationTransfers.withLock { transfers in
            do { try preferenceUploader.invalidateLocationEvidence(at: date) }
            catch { Logger.locationPushPusher.error("Location evidence invalidation could not be persisted") }
            for transfer in transfers.values { transfer.cancel() }
        }
    }

    func acceptSubscriptionIntent(enabled: Bool) async {
        let installationId = await installationIdProvider()
        do {
            try await preferenceUploader.acceptSubscriptionIntent(installationId: installationId, enabled: enabled)
            subscriptionOverride = nil
        } catch {
            logger.error("Subscription intent persistence unavailable; device sync deferred")
        }
    }

    func enqueuePreferenceSync(
        source: LocationUploadSource,
        requestReason: LocationUploadReason,
        forceUpload: Bool,
        detail: String,
        isSubscribedOverride: Bool?
    ) async {
        await enqueuePreferenceSync(source: source, requestReason: requestReason, forceUpload: forceUpload,
            detail: detail, isSubscribedOverride: isSubscribedOverride, processImmediately: true)
    }

    private func enqueuePreferenceSync(
        source: LocationUploadSource, requestReason: LocationUploadReason, forceUpload: Bool,
        detail: String, isSubscribedOverride: Bool?, processImmediately: Bool
    ) async {
        if isSubscribedOverride == false {
            subscriptionOverride = (false, subscriptionStatusProvider())
            await preferenceUploader.restrictSubscription()
        }
        logger.info(
            "Preference sync request accepted source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
        )

        await ensurePersistedPendingLoaded()
        let installationId = await installationIdProvider()
        do {
            try await preferenceUploader.reconcileConsent(installationId: installationId)
        } catch {
            logger.error("Consent persistence unavailable; device sync deferred")
            return
        }
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let isSubscribed = currentSubscription()
        let authorizationStatus = authorizationStatusProvider()
        let now = nowProvider()
        let mesoNotificationsEnabled = mesoNotificationEnabledProvider()
        observeConsent(subscribed: isSubscribed, authorization: authorizationStatus)
        var persisted = PersistedLocationUploadRequest(
            source: source,
            reason: requestReason,
            forceUpload: forceUpload,
            installationId: installationId,
            requestedAt: now,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            apnsToken: apnsToken,
            operation: .preferenceSync,
            mesoNotificationsEnabled: mesoNotificationsEnabled
        )


        let dedupeKey = DeduplicationKey(
            installationId: installationId,
            apnsToken: apnsToken,
            operation: .preferenceSync,
            isSubscribed: isSubscribed,
            mesoNotificationsEnabled: persisted.mesoNotificationsEnabled,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            forceUpload: forceUpload
        )
        if shouldDedupeRequest(for: dedupeKey, now: now) {
            logger.notice(
                "Preference sync request deduped source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
            )
            return
        }

        await waitForPendingSave()
        let coalescingKey = coalescingKey(for: persisted)
        if pendingByCoalescingKey[coalescingKey] == nil {
            logger.debug(
                "Preference sync request persisted persistReason=queued source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
            )
            guard await upsertPending(persisted) else { return }
        }
        if let retained = pendingByCoalescingKey[coalescingKey] { persisted = retained }
        guard processImmediately else { return }
        guard enqueueIfNotQueuedOrActive(
            QueuedUpload(
                request: persisted,
                coalescingKey: coalescingKey,
                semanticDedupeKey: dedupeKey,
                reason: requestReason,
                source: source.rawValue
            )
        ) else { return }

        guard !isProcessing else { return }
        await processQueue()
    }

    private func recoverPendingPreferenceIntent() async {
        guard preferenceUploader.hasPendingPreferenceIntent else { return }
        await ensurePersistedPendingLoaded()
        // Saved preference requests already replay current consent. Preserve their identity/failure ordering.
        guard !pendingByCoalescingKey.values.contains(where: {
            if case .preferenceSync = $0.operation { return true }
            return false
        }) else {
            if pendingByCoalescingKey != committedPending {
                await waitForPendingSave()
                _ = await persistPendingState()
            }
            return
        }
        let installationId = await installationIdProvider()
        guard pendingByCoalescingKey.values.allSatisfy({ $0.installationId == installationId }) else { return }
        await enqueuePreferenceSync(source: .unknown, requestReason: .preferenceChanged, forceUpload: true,
            detail: "durable-consent-recovery", isSubscribedOverride: nil, processImmediately: false)
    }

    private func recoverDeferredEnrichment() async {
        guard !deferredEnrichment.isEmpty else { return }
        let deferred = deferredEnrichment
        let currentInstallationId = await installationIdProvider()
        for (installationId, intent) in deferred {
            guard installationId == currentInstallationId, locationUploadEnabledProvider(), accuracyAuthorizationProvider() == .fullAccuracy else {
                deferredEnrichment.removeValue(forKey: installationId)
                continue
            }
            _ = await enqueueLocation(intent.context, source: intent.source, reason: intent.reason,
                                      forceUpload: intent.forceUpload, processImmediately: false,
                                      retainEnrichmentOnFailure: true, admissionOnly: true)
        }
    }

    func drainPendingUploads() async {
        await recoverDeferredEnrichment()
        await recoverPendingPreferenceIntent()
        await ensurePersistedPendingLoaded()

        guard pendingSaveCount == 0 else { return }
        guard !pendingByCoalescingKey.isEmpty else { return }
        logger.info("Location upload drain started pendingCount=\(self.pendingByCoalescingKey.count, privacy: .public)")

        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)

        var enqueuedCount = 0
        var dedupedCount = 0
        for pending in committedPending.values.sorted(by: { $0.requestedAt < $1.requestedAt }) {
            guard pendingSaveCount == 0 else { break }
            guard pendingByCoalescingKey[coalescingKey(for: pending)] == pending else { continue }
            let now = nowProvider()
            let dedupeKey = DeduplicationKey(
                installationId: pending.installationId,
                apnsToken: apnsToken,
                operation: pending.operation.deduplicationOperation,
                isSubscribed: pending.isSubscribed,
                mesoNotificationsEnabled: mesoNotificationEnabledProvider(),
                authorizationState: pending.authorizationState,
                forceUpload: pending.forceUpload
            )
            if consentMatchesRequest(pending),
               shouldDedupeRequest(for: dedupeKey, now: now, capturedAt: capturedAt(of: pending)) {
                dedupedCount += 1
                pendingByCoalescingKey.removeValue(forKey: coalescingKey(for: pending))
                await persistPendingState()
                continue
            }
            if enqueueIfNotQueuedOrActive(
                QueuedUpload(
                    request: pending,
                    coalescingKey: coalescingKey(for: pending),
                    semanticDedupeKey: dedupeKey,
                    reason: pending.reason,
                    source: pending.source.rawValue
                )
            ) == false {
                continue
            }
            enqueuedCount += 1
        }
        logger.info(
            "Location upload drain completed enqueued=\(enqueuedCount, privacy: .public) deduped=\(dedupedCount, privacy: .public) remainingPending=\(self.pendingByCoalescingKey.count, privacy: .public)"
        )

        guard !isProcessing else { return }
        await processQueue()
    }

    func drainPendingUploads(
        using budget: PendingLocationUploadDrainBudget
    ) async -> PendingLocationUploadDrainOutcome {
        guard budget.uploadQuota > 0, shouldContinueDraining(before: budget.deadline) else { return .remaining }
        await recoverDeferredEnrichment()
        await recoverPendingPreferenceIntent()
        await ensurePersistedPendingLoaded()

        guard pendingSaveCount == 0 else { return .remaining }
        guard !pendingByCoalescingKey.isEmpty else {
            return preferenceUploader.hasPendingPreferenceIntent || !deferredEnrichment.isEmpty ? .remaining : .drained
        }
        guard !isProcessing else { return .remaining }
        guard budget.uploadQuota > 0, shouldContinueDraining(before: budget.deadline) else {
            return .remaining
        }

        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)

        isProcessing = true
        defer {
            isProcessing = false
            scheduleQueuedProcessingIfNeeded()
        }

        var admittedCount = 0
        for pending in committedPending.values.sorted(by: { $0.requestedAt < $1.requestedAt }) {
            guard pendingSaveCount == 0 else { break }
            guard pendingByCoalescingKey[coalescingKey(for: pending)] == pending else { continue }
            guard admittedCount < budget.uploadQuota, shouldContinueDraining(before: budget.deadline) else {
                break
            }
            admittedCount += 1

            let now = nowProvider()
            let coalescingKey = coalescingKey(for: pending)
            let dedupeKey = DeduplicationKey(
                installationId: pending.installationId,
                apnsToken: apnsToken,
                operation: pending.operation.deduplicationOperation,
                isSubscribed: pending.isSubscribed,
                mesoNotificationsEnabled: mesoNotificationEnabledProvider(),
                authorizationState: pending.authorizationState,
                forceUpload: pending.forceUpload
            )
            if consentMatchesRequest(pending),
               shouldDedupeRequest(for: dedupeKey, now: now, capturedAt: capturedAt(of: pending)) {
                pendingByCoalescingKey.removeValue(forKey: coalescingKey)
                await persistPendingState()
                continue
            }

            let workItem = QueuedUpload(
                request: pending,
                coalescingKey: coalescingKey,
                semanticDedupeKey: dedupeKey,
                reason: pending.reason,
                source: pending.source.rawValue
            )

            guard queuedOrActiveCoalescingKeys.insert(coalescingKey).inserted else { continue }
            defer {
                queuedOrActiveCoalescingKeys.remove(coalescingKey)
                preparedKeys.removeValue(forKey: coalescingKey)
            }

            activeRequests[workItem.coalescingKey] = workItem.request
            defer { activeRequests.removeValue(forKey: workItem.coalescingKey) }
            let outcome = await uploadWithRetry(workItem, deadline: budget.deadline)
            if outcome != .pending {
                await waitForPendingSave()
                if outcome == .uploaded, let semanticDedupeKey = preparedKeys[workItem.coalescingKey] {
                    lastUploadBySemanticKey[semanticDedupeKey] = (nowProvider(), capturedAt(of: workItem.request))
                }
                if pendingByCoalescingKey[coalescingKey] == workItem.request,
                   !queue.contains(where: { $0.coalescingKey == coalescingKey }) {
                    pendingByCoalescingKey.removeValue(forKey: coalescingKey)
                    await persistPendingState()
                }
            }

            guard shouldContinueDraining(before: budget.deadline) else { break }
        }

        return pendingByCoalescingKey.isEmpty && deferredEnrichment.isEmpty && !preferenceUploader.hasPendingPreferenceIntent ? .drained : .remaining
    }

    private func shouldContinueDraining(before deadline: ContinuousClock.Instant) -> Bool {
        !Task.isCancelled && ContinuousClock().now < deadline
    }

    private func shouldDedupeRequest(for key: DeduplicationKey, now: Date, capturedAt: Date? = nil) -> Bool {
        guard dedupeWindowSeconds > 0 else { return false }
        guard let last = lastUploadBySemanticKey[key], last.capturedAt == capturedAt else { return false }
        return now.timeIntervalSince(last.uploadedAt) <= dedupeWindowSeconds
    }

    private nonisolated static func authorizationName(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways: return "always"
        case .authorizedWhenInUse: return "whenInUse"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }

    private func processQueue() async {
        isProcessing = true
        defer { isProcessing = false }
        await drainQueue()
    }

    private func scheduleQueuedProcessingIfNeeded() {
        guard !queue.isEmpty else { return }
        Task { await processQueueIfNeeded() }
    }

    private func processQueueIfNeeded() async {
        guard !isProcessing else { return }
        await processQueue()
    }

    private func drainQueue() async {
        while !queue.isEmpty {
            if Task.isCancelled {
                logger.notice("Location upload queue drain cancelled")
                return
            }
            let workItem = queue.removeFirst()
            queuedOrActiveCoalescingKeys.insert(workItem.coalescingKey)
            defer {
                queuedOrActiveCoalescingKeys.remove(workItem.coalescingKey)
                preparedKeys.removeValue(forKey: workItem.coalescingKey)
            }
            activeRequests[workItem.coalescingKey] = workItem.request
            defer { activeRequests.removeValue(forKey: workItem.coalescingKey) }
            let outcome = await uploadWithRetry(workItem)
            if outcome != .pending {
                await waitForPendingSave()
                logger.notice(
                    "Location upload work completed source=\(workItem.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)"
                )
                if outcome == .uploaded, let semanticDedupeKey = preparedKeys[workItem.coalescingKey] {
                    lastUploadBySemanticKey[semanticDedupeKey] = (nowProvider(), capturedAt(of: workItem.request))
                }
                if pendingByCoalescingKey[workItem.coalescingKey] == workItem.request,
                   !queue.contains(where: { $0.coalescingKey == workItem.coalescingKey }) {
                    pendingByCoalescingKey.removeValue(forKey: workItem.coalescingKey)
                    await persistPendingState()
                }
            } else {
                logger.error(
                    "Location upload failed source=\(workItem.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)"
                )
                if Task.isCancelled {
                    logger.notice("Location upload queue drain stopped after cancellation")
                    return
                }
            }
        }
    }

    private func enqueueIfNotQueuedOrActive(_ workItem: QueuedUpload) -> Bool {
        if let index = queue.firstIndex(where: { $0.coalescingKey == workItem.coalescingKey }),
           capturedAt(of: workItem.request) != nil {
            queue[index] = workItem
            return true
        }
        let inserted = queuedOrActiveCoalescingKeys.insert(workItem.coalescingKey).inserted
        if !inserted {
            // A replay may have prepared different consent from its historical key.
            // Keep one durable follow-up when current intent differs from the active transfer.
            if let active = activeRequests[workItem.coalescingKey],
               let old = capturedAt(of: active), let new = capturedAt(of: workItem.request),
               new >= old, active != workItem.request {
                queue.append(workItem)
                return true
            }
            guard let prepared = preparedKeys[workItem.coalescingKey],
                  prepared != workItem.semanticDedupeKey,
                  !queue.contains(where: { $0.coalescingKey == workItem.coalescingKey }) else { return false }
        }
        queue.append(workItem)
        return true
    }

    private func uploadWithRetry(
        _ workItem: QueuedUpload,
        deadline: ContinuousClock.Instant? = nil
    ) async -> UploadOutcome {
        preparedKeys.removeValue(forKey: workItem.coalescingKey)
        for (index, delay) in retryDelaysSeconds.enumerated() {
            do {
                try Task.checkCancellation()
            } catch is CancellationError {
                logger.notice("Location upload cancelled before attempt source=\(workItem.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)")
                return .pending
            } catch {
                return .pending
            }

            if let deadline, !shouldContinueDraining(before: deadline) {
                logger.notice("Location upload deadline reached before attempt source=\(workItem.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)")
                return .pending
            }

            if delay > 0 {
                do {
                    if let deadline {
                        let clock = ContinuousClock()
                        let retryAt = clock.now.advanced(by: .seconds(Int(delay)))
                        try await clock.sleep(until: min(retryAt, deadline))
                        guard shouldContinueDraining(before: deadline) else {
                            logger.notice("Location upload deadline reached during retry backoff source=\(workItem.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)")
                            return .pending
                        }
                    } else {
                        try await Task.sleep(for: .seconds(Int(delay)))
                    }
                    try Task.checkCancellation()
                } catch is CancellationError {
                    logger.notice("Location upload cancelled during retry backoff source=\(workItem.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)")
                    return .pending
                } catch {
                    return .pending
                }
            }
            do {
                switch workItem.request.operation {
                case .locationSnapshot:
                    try await checkLocationEvidence(for: workItem.request)
                    let transferID = UUID()
                    let transfer = Task {
                        do {
                            try await locationUploader.upload(installationId: workItem.request.installationId, checking: {
                                try await self.checkTransfer(deadline: deadline)
                            }) {
                                try await self.currentLocationPayload(for: workItem.request, deadline: deadline)
                            }
                        } catch let error as LocationPushError {
                            guard case .invalidResponseStatus(let status) = error,
                                  status == 400 || status == 422,
                                  workItem.source != "unknown" else { throw error }
                            // A second transfer needs a fresh check, including after enrollment.
                            try await locationUploader.upload(installationId: workItem.request.installationId, checking: {
                                try await self.checkTransfer(deadline: deadline)
                            }) {
                                try await self.currentLocationPayload(for: workItem.request, deadline: deadline, legacy: true)
                            }
                        }
                        try Task.checkCancellation()
                    }
                    locationTransfers.withLock { $0[transferID] = transfer }
                    defer { locationTransfers.withLock { $0.removeValue(forKey: transferID) } }
                    try await withTaskCancellationHandler {
                        try await transfer.value
                    } onCancel: {
                        transfer.cancel()
                    }
                case .preferenceSync:
                    try await preferenceUploader.upload(installationId: workItem.request.installationId) {
                        try await self.currentPreferencePayload(for: workItem.request, deadline: deadline)
                    }
                }
                return .uploaded
            } catch TransferSuppressed.persistencePending {
                return .pending
            } catch is TransferSuppressed {
                return .discarded
            } catch InstallationConsentStore.Failure.consentConflictRequiresRecovery {
                return .pending
            } catch InstallationConsentStore.Failure.rejected(let status) where [400, 401].contains(status) {
                return .pending
            } catch LocationPushError.presenceNotAccepted {
                return .discarded
            } catch let error as LocationPushError {
                let isFinalAttempt = index == retryDelaysSeconds.count - 1
                if isFinalAttempt {
                    logger.error("Upload failed after retries: \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.warning("Upload attempt failed; retrying")
                }
            } catch is CancellationError {
                logger.notice("Location upload cancelled source=\(workItem.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)")
                return .pending
            } catch {
                let isFinalAttempt = index == retryDelaysSeconds.count - 1
                if isFinalAttempt {
                    logger.error("Upload failed after retries: \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.warning("Upload attempt failed; retrying")
                }
            }
        }

        return .pending
    }

    private func consentMatchesRequest(_ request: PersistedLocationUploadRequest) -> Bool {
        request.isSubscribed == currentSubscription()
            && request.authorizationState == Self.authorizationName(for: authorizationStatusProvider())
    }

    private func recordPreparedKey(
        _ request: PersistedLocationUploadRequest, token: String, subscribed: Bool, authorization: CLAuthorizationStatus
    ) {
        observeConsent(subscribed: subscribed, authorization: authorization)
        preparedKeys[coalescingKey(for: request)] = DeduplicationKey(
            installationId: request.installationId, apnsToken: token,
            operation: request.operation.deduplicationOperation, isSubscribed: subscribed,
            mesoNotificationsEnabled: mesoNotificationEnabledProvider(),
            authorizationState: Self.authorizationName(for: authorization), forceUpload: request.forceUpload
        )
    }

    private func observeConsent(subscribed: Bool, authorization: CLAuthorizationStatus) {
        let consent = DeviceConsentSnapshotV3(
            isSubscribed: subscribed, mesoNotificationsEnabled: mesoNotificationEnabledProvider(),
            locationSharingEnabled: locationUploadEnabledProvider(),
            locationAuthorization: .init(rawValue: Self.authorizationName(for: authorization)) ?? .unknown
        )
        let cutoff = minimumLocationObservationTimestamp
        if lastObservedConsent != consent || lastObservedEvidenceCutoff != cutoff {
            lastUploadBySemanticKey.removeAll()
            lastObservedConsent = consent
            lastObservedEvidenceCutoff = cutoff
        }
    }

    private func currentSubscription() -> Bool {
        let current = subscriptionStatusProvider()
        guard let override = subscriptionOverride else { return current }
        if current != override.baseline || current == override.value {
            subscriptionOverride = nil
            return current
        }
        return override.value
    }

    private func checkTransfer(deadline: ContinuousClock.Instant?) throws {
        try Task.checkCancellation()
        if let deadline, !shouldContinueDraining(before: deadline) { throw CancellationError() }
    }

    private func checkLocationEvidence(for request: PersistedLocationUploadRequest) async throws {
        let cutoff = try await preferenceUploader.locationEvidenceCutoff(installationId: request.installationId)
        guard case .locationSnapshot(let context) = request.operation,
              cutoff.map({ context.capturedAt >= $0 }) ?? true else { throw TransferSuppressed.obsolete }
    }

    private func currentLocationPayload(
        for request: PersistedLocationUploadRequest,
        deadline: ContinuousClock.Instant?,
        legacy: Bool = false
    ) async throws -> LocationSnapshotPushPayload {
        let osVersion = await osVersionProvider()
        try checkTransfer(deadline: deadline)
        try await checkLocationEvidence(for: request)
        try checkTransfer(deadline: deadline)
        guard pendingSaveCount == 0 else { throw TransferSuppressed.persistencePending }
        guard committedPending[coalescingKey(for: request)] == request,
              pendingByCoalescingKey[coalescingKey(for: request)] == request else {
            throw TransferSuppressed.obsolete
        }
        let authorization = authorizationStatusProvider()
        observeConsent(subscribed: currentSubscription(), authorization: authorization)
        guard locationUploadEnabledProvider(), accuracyAuthorizationProvider() == .fullAccuracy,
              case .locationSnapshot(let context) = request.operation,
              context.horizontalAccuracyMeters.isFinite, context.horizontalAccuracyMeters > 0,
              context.horizontalAccuracyMeters <= LocationThrottleConfig().minAccuracy,
              authorization == .authorizedAlways || authorization == .authorizedWhenInUse else {
            throw TransferSuppressed.obsolete
        }
        let token = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let subscribed = currentSubscription()
        recordPreparedKey(request, token: token, subscribed: subscribed, authorization: authorization)
        return makeLocationPayload(
            from: request, apnsToken: token, isSubscribed: subscribed,
            authorizationState: Self.authorizationName(for: authorization), now: nowProvider(),
            osVersion: osVersion, legacy: legacy
        )
    }

    private func currentPreferencePayload(
        for request: PersistedLocationUploadRequest,
        deadline: ContinuousClock.Instant?
    ) async throws -> DevicePreferenceSyncPayload {
        let osVersion = await osVersionProvider()
        try checkTransfer(deadline: deadline)
        let token = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let subscribed = currentSubscription()
        let authorization = authorizationStatusProvider()
        recordPreparedKey(request, token: token, subscribed: subscribed, authorization: authorization)
        return makePreferencePayload(
            from: request, apnsToken: token, isSubscribed: subscribed,
            authorizationState: Self.authorizationName(for: authorization), osVersion: osVersion
        )
    }

    private func makeLocationPayload(
        from request: PersistedLocationUploadRequest,
        apnsToken: String,
        isSubscribed: Bool,
        authorizationState: String,
        now: Date,
        osVersion: String,
        legacy: Bool
    ) -> LocationSnapshotPushPayload {
        guard case .locationSnapshot(let context) = request.operation else {
            preconditionFailure("Location payload requested for non-location operation")
        }
        let capturedAt = context.capturedAt
        let locationAgeSeconds = now.timeIntervalSince(context.capturedAt)
        let horizontalAccuracyMeters = context.horizontalAccuracyMeters

        // A replay must advertise current consent rather than restore a superseded preference.
        return LocationSnapshotPushPayload(
            capturedAt: capturedAt,
            locationAgeSeconds: locationAgeSeconds,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            cellScheme: "h3",
            h3Cell: context.h3Cell,
            h3Resolution: 8,
            county: context.county,
            zone: context.forecastZone,
            fireZone: context.fireZone,
            apnsDeviceToken: apnsToken,
            installationId: request.installationId,
            source: legacy ? "unknown" : request.source.rawValue,
            auth: authorizationState,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            platform: "iOS",
            osVersion: osVersion,
            apnsEnvironment: {
                #if DEBUG
                return "sandbox"
                #else
                return "prod"
                #endif
            }(),
            countyLabel: context.countyLabel,
            fireZoneLabel: context.fireZoneLabel,
            isSubscribed: isSubscribed,
            mesoNotificationsEnabled: mesoNotificationEnabledProvider()
        )
    }

    private func makePreferencePayload(
        from request: PersistedLocationUploadRequest,
        apnsToken: String,
        isSubscribed: Bool,
        authorizationState: String,
        osVersion: String
    ) -> DevicePreferenceSyncPayload {
        // Pending requests preserve their snapshot; delivery uses the current preference.
        DevicePreferenceSyncPayload(
            installationId: request.installationId,
            apnsDeviceToken: apnsToken,
            apnsEnvironment: {
                #if DEBUG
                return "sandbox"
                #else
                return "prod"
                #endif
            }(),
            platform: "iOS",
            osVersion: osVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            auth: authorizationState,
            isSubscribed: isSubscribed,
            source: request.source.rawValue,
            reason: request.reason.rawValue,
            mesoNotificationsEnabled: mesoNotificationEnabledProvider()
        )
    }

    private func capturedAt(of request: PersistedLocationUploadRequest) -> Date? {
        if case .locationSnapshot(let context) = request.operation { return context.capturedAt }
        return nil
    }

    private func ensurePersistedPendingLoaded() async {
        guard !hasLoadedPersistedPending else { return }
        if pendingLoad == nil {
            pendingLoad = Task { await queueStore.loadPendingRequests() }
        }
        guard let pendingLoad else { return }
        let loaded = await pendingLoad.value
        guard !hasLoadedPersistedPending else { return }
        for request in loaded.sorted(by: { $0.requestedAt < $1.requestedAt }) {
            let key = coalescingKey(for: request)
            if case .locationSnapshot(let context) = request.operation {
                if let newest = newestContextByCoalescingKey[key], !canReplace(newest, with: context) { continue }
                newestContextByCoalescingKey[key] = context
            }
            pendingByCoalescingKey[key] = request
        }
        committedPending = pendingByCoalescingKey
        hasLoadedPersistedPending = true
        self.pendingLoad = nil
    }

    @discardableResult
    private func upsertPending(_ request: PersistedLocationUploadRequest) async -> Bool {
        pendingByCoalescingKey[coalescingKey(for: request)] = request
        return await persistPendingState()
    }

    private func waitForPendingSave() async {
        while pendingSaveCount > 0, let save = pendingSave {
            _ = await save.value
        }
    }

    @discardableResult
    private func persistPendingState() async -> Bool {
        let requests = pendingByCoalescingKey.values.sorted(by: { $0.requestedAt < $1.requestedAt })
        let snapshot = pendingByCoalescingKey
        pendingSaveCount += 1
        let previous = pendingSave
        let store = queueStore
        let save = Task {
            defer { pendingSaveCount -= 1 }
            _ = await previous?.value
            do {
                try await store.savePendingRequests(requests)
                committedPending = snapshot
                return true
            } catch {
                // Roll back only this snapshot; a newer admission may already be waiting to save.
                if pendingByCoalescingKey == snapshot {
                    pendingByCoalescingKey = committedPending
                    for (key, request) in snapshot where capturedAt(of: request) != nil {
                        if case .locationSnapshot(let context) = committedPending[key]?.operation {
                            newestContextByCoalescingKey[key] = context
                        } else {
                            newestContextByCoalescingKey.removeValue(forKey: key)
                        }
                    }
                }
                return false
            }
        }
        pendingSave = save
        let saved = await save.value
        if !saved { logger.error("Presence outbox persistence failed; durable enqueue unavailable") }
        return saved
    }

    // Equal-capture enrichment may add metadata to the current cell, but must not
    // replace its geography or erase already resolved targeting fields.
    private func canReplace(_ old: PersistedLocationContext, with new: PersistedLocationContext) -> Bool {
        if new.capturedAt != old.capturedAt { return new.capturedAt > old.capturedAt }
        return new.h3Cell == old.h3Cell &&
            (old.county == nil || new.county == old.county) &&
            (old.fireZone == nil || new.fireZone == old.fireZone) &&
            (old.forecastZone == nil || new.forecastZone == old.forecastZone)
    }

    private func coalescingKey(for request: PersistedLocationUploadRequest) -> PendingCoalescingKey {
        switch request.operation {
        case .locationSnapshot:
            // Presence is current state, independent of travel history or historical consent.
            // Transfer preparation still revalidates current consent and evidence fences.
            return .location(installationId: request.installationId)
        case .preferenceSync:
            return .preference(
                installationId: request.installationId,
                isSubscribed: request.isSubscribed,
                mesoNotificationsEnabled: request.mesoNotificationsEnabled ?? true,
                authorizationState: request.authorizationState,
                forceUpload: request.forceUpload
            )
        }
    }

    nonisolated private static func readApnsTokenFromDefaults() -> String {
        UserDefaults(suiteName: userDefaultsSuiteName)?
            .string(forKey: RemoteNotificationRegistrar.apnsDeviceTokenKey) ?? ""
    }

    nonisolated private static func readSubscriptionStatusFromDefaults() -> Bool {
        if let value = UserDefaults(suiteName: userDefaultsSuiteName)?
            .object(forKey: serverNotificationEnabledKey) as? Bool {
            return value
        }
        return true
    }

    nonisolated private static func readLocationUploadEnabledFromDefaults() -> Bool {
        if let value = UserDefaults(suiteName: userDefaultsSuiteName)?
            .object(forKey: locationUploadEnabledKey) as? Bool {
            return value
        }
        return true
    }

    private struct DeduplicationKey: Hashable {
        let installationId: String
        let apnsToken: String
        let operation: PendingDeduplicationOperation
        let isSubscribed: Bool
        let mesoNotificationsEnabled: Bool?
        let authorizationState: String
        let forceUpload: Bool
    }

    private enum PendingCoalescingKey: Hashable {
        case location(installationId: String)
        case preference(installationId: String, isSubscribed: Bool, mesoNotificationsEnabled: Bool,
                        authorizationState: String, forceUpload: Bool)
    }

    private struct QueuedUpload {
        let request: PersistedLocationUploadRequest
        let coalescingKey: PendingCoalescingKey
        let semanticDedupeKey: DeduplicationKey?
        let reason: LocationUploadReason
        let source: String
    }
}
