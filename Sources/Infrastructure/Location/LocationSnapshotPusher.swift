//
//  LocationSnapshotPusher.swift
//  SkyAware
//
//  Created by Justin Rooks on 3/8/26.
//

import CoreLocation
import Foundation
import OSLog
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

protocol LocationUploadCoordinating: PendingLocationUploadDraining, Sendable {
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
}

actor LocationSnapshotPusher: LocationUploadCoordinating {
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
    private let nowProvider: NowProvider
    private let retryDelaysSeconds: [UInt64]
    private let dedupeWindowSeconds: TimeInterval
    private let queueStore: any LocationUploadQueueStoring
    private let logger = Logger.locationPushPusher

    private var queue: [QueuedUpload] = []
    private var isProcessing = false
    private var lastObservedConsent: DeviceConsentSnapshotV3?
    private var lastUploadBySemanticKey: [DeduplicationKey: Date] = [:]
    private var pendingByCoalescingKey: [PendingCoalescingKey: PersistedLocationUploadRequest] = [:]
    private var queuedOrActiveCoalescingKeys: Set<PendingCoalescingKey> = []
    private var preparedKeys: [PendingCoalescingKey: DeduplicationKey] = [:]
    private var hasLoadedPersistedPending = false
    // Explicit settings intent wins while its defaults write is still catching up.
    private var subscriptionOverride: (value: Bool, baseline: Bool)?

    private enum TransferSuppressed: Error { case obsolete }
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
        logger.info(
            "Location upload request accepted source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
        )
        guard forceUpload || locationUploadEnabledProvider() else {
            observeConsent(subscribed: currentSubscription(), authorization: authorizationStatusProvider())
            logger.notice(
                "Location upload request skipped skipReason=disabled source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
            )
            return
        }

        await ensurePersistedPendingLoaded()
        let installationId = await installationIdProvider()
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let isSubscribed = currentSubscription()
        let authorizationStatus = authorizationStatusProvider()
        let now = nowProvider()
        let mesoNotificationsEnabled = mesoNotificationEnabledProvider()
        observeConsent(subscribed: isSubscribed, authorization: authorizationStatus)
        let persisted = PersistedLocationUploadRequest(
            source: source,
            reason: reason,
            forceUpload: forceUpload,
            installationId: installationId,
            requestedAt: now,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            apnsToken: apnsToken,
            operation: .locationSnapshot(context: PersistedLocationContext(context)),
            mesoNotificationsEnabled: mesoNotificationsEnabled
        )

        guard !apnsToken.isEmpty else {
            logger.notice(
                "Location upload request persisted persistReason=missingToken source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
            )
            await upsertPending(persisted)
            return
        }
        let dedupeKey = DeduplicationKey(
            installationId: installationId,
            apnsToken: apnsToken,
            operation: .locationSnapshot(
                h3Cell: context.h3Cell,
                county: context.grid.countyCode,
                fireZone: context.grid.fireZone,
                forecastZone: context.grid.forecastZone
            ),
            isSubscribed: isSubscribed,
            mesoNotificationsEnabled: persisted.mesoNotificationsEnabled,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            forceUpload: forceUpload
        )
        if shouldDedupeRequest(for: dedupeKey, now: now) {
            logger.notice(
                "Location upload request deduped source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
            )
            return
        }
        let coalescingKey = coalescingKey(for: persisted)
        if pendingByCoalescingKey[coalescingKey] == nil {
            logger.debug(
                "Location upload request persisted persistReason=queued source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
            )
            await upsertPending(persisted)
        }
        guard enqueueIfNotQueuedOrActive(
            QueuedUpload(
                request: persisted,
                coalescingKey: coalescingKey,
                semanticDedupeKey: dedupeKey,
                reason: reason,
                source: source.rawValue
            )
        ) else { return }

        guard !isProcessing else { return }
        await processQueue()
    }

    func enqueuePreferenceSync(
        source: LocationUploadSource,
        requestReason: LocationUploadReason,
        forceUpload: Bool,
        detail: String,
        isSubscribedOverride: Bool?
    ) async {
        if let isSubscribedOverride {
            subscriptionOverride = (isSubscribedOverride, subscriptionStatusProvider())
        }
        logger.info(
            "Preference sync request accepted source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
        )
        guard forceUpload || locationUploadEnabledProvider() else {
            observeConsent(subscribed: currentSubscription(), authorization: authorizationStatusProvider())
            logger.notice(
                "Preference sync request skipped skipReason=disabled source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
            )
            return
        }

        await ensurePersistedPendingLoaded()
        let installationId = await installationIdProvider()
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let isSubscribed = currentSubscription()
        let authorizationStatus = authorizationStatusProvider()
        let now = nowProvider()
        let mesoNotificationsEnabled = mesoNotificationEnabledProvider()
        observeConsent(subscribed: isSubscribed, authorization: authorizationStatus)
        let persisted = PersistedLocationUploadRequest(
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

        guard !apnsToken.isEmpty else {
            logger.notice(
                "Preference sync request persisted persistReason=missingToken source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
            )
            await upsertPending(persisted)
            return
        }

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

        let coalescingKey = coalescingKey(for: persisted)
        if pendingByCoalescingKey[coalescingKey] == nil {
            logger.debug(
                "Preference sync request persisted persistReason=queued source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
            )
            await upsertPending(persisted)
        }
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

    func drainPendingUploads() async {
        await ensurePersistedPendingLoaded()

        guard !pendingByCoalescingKey.isEmpty else { return }
        logger.info("Location upload drain started pendingCount=\(self.pendingByCoalescingKey.count, privacy: .public)")

        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apnsToken.isEmpty else {
            logger.notice("Location upload drain skipped reason=missingToken")
            return
        }

        var enqueuedCount = 0
        var dedupedCount = 0
        for pending in pendingByCoalescingKey.values.sorted(by: { $0.requestedAt < $1.requestedAt }) {
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
            if consentMatchesRequest(pending), shouldDedupeRequest(for: dedupeKey, now: now) {
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
        await ensurePersistedPendingLoaded()

        guard !pendingByCoalescingKey.isEmpty else { return .drained }
        guard !isProcessing else { return .remaining }
        guard budget.uploadQuota > 0, shouldContinueDraining(before: budget.deadline) else {
            return .remaining
        }

        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apnsToken.isEmpty else {
            logger.notice("Location upload drain skipped reason=missingToken")
            return .remaining
        }

        isProcessing = true
        defer {
            isProcessing = false
            scheduleQueuedProcessingIfNeeded()
        }

        var admittedCount = 0
        for pending in pendingByCoalescingKey.values.sorted(by: { $0.requestedAt < $1.requestedAt }) {
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
            if consentMatchesRequest(pending), shouldDedupeRequest(for: dedupeKey, now: now) {
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

            let outcome = await uploadWithRetry(workItem, deadline: budget.deadline)
            if outcome != .pending {
                if outcome == .uploaded, let semanticDedupeKey = preparedKeys[workItem.coalescingKey] {
                    lastUploadBySemanticKey[semanticDedupeKey] = nowProvider()
                }
                if !queue.contains(where: { $0.coalescingKey == coalescingKey }) {
                    pendingByCoalescingKey.removeValue(forKey: coalescingKey)
                }
                await persistPendingState()
            }

            guard shouldContinueDraining(before: budget.deadline) else { break }
        }

        return pendingByCoalescingKey.isEmpty ? .drained : .remaining
    }

    private func shouldContinueDraining(before deadline: ContinuousClock.Instant) -> Bool {
        !Task.isCancelled && ContinuousClock().now < deadline
    }

    private func shouldDedupeRequest(for key: DeduplicationKey, now: Date) -> Bool {
        guard dedupeWindowSeconds > 0 else { return false }
        guard let lastUploadAt = lastUploadBySemanticKey[key] else { return false }
        return now.timeIntervalSince(lastUploadAt) <= dedupeWindowSeconds
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
            let outcome = await uploadWithRetry(workItem)
            if outcome != .pending {
                logger.notice(
                    "Location upload work completed source=\(workItem.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)"
                )
                if outcome == .uploaded, let semanticDedupeKey = preparedKeys[workItem.coalescingKey] {
                    lastUploadBySemanticKey[semanticDedupeKey] = nowProvider()
                }
                if !queue.contains(where: { $0.coalescingKey == workItem.coalescingKey }) {
                    pendingByCoalescingKey.removeValue(forKey: workItem.coalescingKey)
                }
                await persistPendingState()
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
        let inserted = queuedOrActiveCoalescingKeys.insert(workItem.coalescingKey).inserted
        if !inserted {
            // A replay may have prepared different consent from its historical key.
            // Keep one durable follow-up when current intent differs from the active transfer.
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
                    do {
                        try await locationUploader.upload(installationId: workItem.request.installationId) {
                            try await self.currentLocationPayload(for: workItem.request, deadline: deadline)
                        }
                    } catch let error as LocationPushError {
                        guard case .invalidResponseStatus(let status) = error,
                              status == 400 || status == 422,
                              workItem.source != "unknown" else { throw error }
                        // A second transfer needs a fresh check, including after enrollment.
                        try await locationUploader.upload(installationId: workItem.request.installationId) {
                            try await self.currentLocationPayload(for: workItem.request, deadline: deadline, legacy: true)
                        }
                    }
                case .preferenceSync:
                    try await preferenceUploader.upload(installationId: workItem.request.installationId) {
                        try await self.currentPreferencePayload(for: workItem.request, deadline: deadline)
                    }
                }
                return .uploaded
            } catch is TransferSuppressed {
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
        if lastObservedConsent != consent {
            lastUploadBySemanticKey.removeAll()
            lastObservedConsent = consent
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

    private func currentLocationPayload(
        for request: PersistedLocationUploadRequest,
        deadline: ContinuousClock.Instant?,
        legacy: Bool = false
    ) async throws -> LocationSnapshotPushPayload {
        let osVersion = await UIDevice.current.systemVersion
        try checkTransfer(deadline: deadline)
        let authorization = authorizationStatusProvider()
        observeConsent(subscribed: currentSubscription(), authorization: authorization)
        guard locationUploadEnabledProvider(),
              authorization == .authorizedAlways || authorization == .authorizedWhenInUse else {
            throw TransferSuppressed.obsolete
        }
        let token = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw LocationPushError.invalidResponseStatus(503) }
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
        let osVersion = await UIDevice.current.systemVersion
        try checkTransfer(deadline: deadline)
        let token = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw LocationPushError.invalidResponseStatus(503) }
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

    private func ensurePersistedPendingLoaded() async {
        guard hasLoadedPersistedPending == false else { return }
        hasLoadedPersistedPending = true
        let loaded = await queueStore.loadPendingRequests()
        // Legacy requests use the original meso default for stable queue identity.
        // Merge collisions deterministically when loading older pending representations.
        for request in loaded.sorted(by: { $0.requestedAt < $1.requestedAt }) {
            pendingByCoalescingKey[coalescingKey(for: request)] = request
        }
    }

    private func upsertPending(_ request: PersistedLocationUploadRequest) async {
        pendingByCoalescingKey[coalescingKey(for: request)] = request
        await persistPendingState()
    }

    private func persistPendingState() async {
        let requests = pendingByCoalescingKey.values.sorted(by: { $0.requestedAt < $1.requestedAt })
        await queueStore.savePendingRequests(requests)
    }

    private func coalescingKey(for request: PersistedLocationUploadRequest) -> PendingCoalescingKey {
        PendingCoalescingKey(
            installationId: request.installationId,
            operation: request.operation.deduplicationOperation,
            isSubscribed: request.isSubscribed,
            mesoNotificationsEnabled: request.mesoNotificationsEnabled ?? true,
            authorizationState: request.authorizationState,
            forceUpload: request.forceUpload
        )
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

    private struct PendingCoalescingKey: Hashable, Codable {
        let installationId: String
        let operation: PendingDeduplicationOperation
        let isSubscribed: Bool
        let mesoNotificationsEnabled: Bool?
        let authorizationState: String
        let forceUpload: Bool
    }

    private struct QueuedUpload {
        let request: PersistedLocationUploadRequest
        let coalescingKey: PendingCoalescingKey
        let semanticDedupeKey: DeduplicationKey?
        let reason: LocationUploadReason
        let source: String
    }
}
