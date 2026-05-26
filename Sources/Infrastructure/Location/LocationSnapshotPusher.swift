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

protocol PendingLocationUploadDraining: Sendable {
    func drainPendingUploads() async
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
        detail: String
    ) async
}

extension LocationUploadCoordinating {
    func drainPendingUploads() async {}

    func enqueuePreferenceSync(
        source: LocationUploadSource,
        requestReason: LocationUploadReason,
        forceUpload: Bool,
        detail: String
    ) async {}
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

    private let uploader: any LocationSnapshotUploading
    private let apnsTokenProvider: APNsTokenProvider
    private let installationIdProvider: InstallationIDProvider
    private let subscriptionStatusProvider: SubscriptionStatusProvider
    private let locationUploadEnabledProvider: LocationUploadEnabledProvider
    private let authorizationStatusProvider: AuthorizationStatusProvider
    private let nowProvider: NowProvider
    private let retryDelaysSeconds: [UInt64]
    private let dedupeWindowSeconds: TimeInterval
    private let queueStore: any LocationUploadQueueStoring
    private let logger = Logger.locationPushPusher

    private var queue: [QueuedUpload] = []
    private var isProcessing = false
    private var lastUploadBySemanticKey: [DeduplicationKey: Date] = [:]
    private var pendingByCoalescingKey: [PendingCoalescingKey: PersistedLocationUploadRequest] = [:]
    private var hasLoadedPersistedPending = false

    init(
        uploader: any LocationSnapshotUploading,
        apnsTokenProvider: @escaping APNsTokenProvider = {
            LocationSnapshotPusher.readApnsTokenFromDefaults()
        },
        installationIdProvider: @escaping InstallationIDProvider = {
            InstallationIdentityStore.shared.installationId()
        },
        subscriptionStatusProvider: @escaping SubscriptionStatusProvider = {
            LocationSnapshotPusher.readSubscriptionStatusFromDefaults()
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
        self.uploader = uploader
        self.apnsTokenProvider = apnsTokenProvider
        self.installationIdProvider = installationIdProvider
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
            logger.notice(
                "Location upload request skipped skipReason=disabled source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
            )
            return
        }

        await ensurePersistedPendingLoaded()
        let installationId = await installationIdProvider()
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let isSubscribed = subscriptionStatusProvider()
        let authorizationStatus = authorizationStatusProvider()
        let now = nowProvider()
        let persisted = PersistedLocationUploadRequest(
            context: PersistedLocationContext(context),
            source: source,
            reason: reason,
            forceUpload: forceUpload,
            installationId: installationId,
            requestedAt: now,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            apnsToken: apnsToken
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
            h3Cell: context.h3Cell,
            county: context.grid.countyCode,
            fireZone: context.grid.fireZone,
            forecastZone: context.grid.forecastZone,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            forceUpload: forceUpload
        )
        if shouldDedupeRequest(for: dedupeKey, now: now) {
            logger.notice(
                "Location upload request deduped source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
            )
            return
        }
        let payload = await makePayload(
            from: persisted,
            apnsToken: apnsToken,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            now: now
        )
        let coalescingKey = coalescingKey(for: persisted)
        if pendingByCoalescingKey[coalescingKey] == nil {
            logger.debug(
                "Location upload request persisted persistReason=queued source=\(source.rawValue, privacy: .public) reason=\(reason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public)"
            )
            await upsertPending(persisted)
        }

        queue.append(QueuedUpload(payload: payload, coalescingKey: coalescingKey, reason: reason))
        lastUploadBySemanticKey[dedupeKey] = now

        guard !isProcessing else { return }
        await processQueue()
    }

    func enqueuePreferenceSync(
        source: LocationUploadSource,
        requestReason: LocationUploadReason,
        forceUpload: Bool,
        detail: String
    ) async {
        logger.info(
            "Preference sync request accepted source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
        )
        guard forceUpload || locationUploadEnabledProvider() else {
            logger.notice(
                "Preference sync request skipped skipReason=disabled source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
            )
            return
        }

        await ensurePersistedPendingLoaded()
        let installationId = await installationIdProvider()
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let isSubscribed = subscriptionStatusProvider()
        let authorizationStatus = authorizationStatusProvider()
        let now = nowProvider()
        let persisted = PersistedLocationUploadRequest(
            context: nil,
            source: source,
            reason: requestReason,
            forceUpload: forceUpload,
            installationId: installationId,
            requestedAt: now,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            apnsToken: apnsToken
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
            h3Cell: nil,
            county: nil,
            fireZone: nil,
            forecastZone: nil,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            forceUpload: forceUpload
        )
        if shouldDedupeRequest(for: dedupeKey, now: now) {
            logger.notice(
                "Preference sync request deduped source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
            )
            return
        }

        let payload = await makePayload(
            from: persisted,
            apnsToken: apnsToken,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            now: now
        )
        let coalescingKey = coalescingKey(for: persisted)
        if pendingByCoalescingKey[coalescingKey] == nil {
            logger.debug(
                "Preference sync request persisted persistReason=queued source=\(source.rawValue, privacy: .public) reason=\(requestReason.rawValue, privacy: .public) force=\(forceUpload, privacy: .public) detail=\(detail, privacy: .public)"
            )
            await upsertPending(persisted)
        }

        queue.append(QueuedUpload(payload: payload, coalescingKey: coalescingKey, reason: requestReason))
        lastUploadBySemanticKey[dedupeKey] = now

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
                h3Cell: pending.context?.h3Cell,
                county: pending.context?.county,
                fireZone: pending.context?.fireZone,
                forecastZone: pending.context?.forecastZone,
                isSubscribed: pending.isSubscribed,
                authorizationState: pending.authorizationState,
                forceUpload: pending.forceUpload
            )
            if shouldDedupeRequest(for: dedupeKey, now: now) {
                dedupedCount += 1
                pendingByCoalescingKey.removeValue(forKey: coalescingKey(for: pending))
                await persistPendingState()
                continue
            }
            let payload = await makePayload(
                from: pending,
                apnsToken: apnsToken,
                isSubscribed: pending.isSubscribed,
                authorizationState: pending.authorizationState,
                now: now
            )
            queue.append(
                QueuedUpload(
                    payload: payload,
                    coalescingKey: coalescingKey(for: pending),
                    reason: pending.reason
                )
            )
            enqueuedCount += 1
            lastUploadBySemanticKey[dedupeKey] = now
        }
        logger.info(
            "Location upload drain completed enqueued=\(enqueuedCount, privacy: .public) deduped=\(dedupedCount, privacy: .public) remainingPending=\(self.pendingByCoalescingKey.count, privacy: .public)"
        )

        guard !isProcessing else { return }
        await processQueue()
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

    private func drainQueue() async {
        while !queue.isEmpty {
            if Task.isCancelled {
                logger.notice("Location upload queue drain cancelled")
                return
            }
            let workItem = queue.removeFirst()
            let didUpload = await uploadWithRetry(workItem.payload, reason: workItem.reason)
            if didUpload {
                logger.notice(
                    "Location upload succeeded source=\(workItem.payload.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)"
                )
                pendingByCoalescingKey.removeValue(forKey: workItem.coalescingKey)
                await persistPendingState()
            } else {
                logger.error(
                    "Location upload failed source=\(workItem.payload.source, privacy: .public) reason=\(workItem.reason.rawValue, privacy: .public)"
                )
                if Task.isCancelled {
                    logger.notice("Location upload queue drain stopped after cancellation")
                    return
                }
            }
        }
    }

    private func uploadWithRetry(_ payload: LocationSnapshotPushPayload, reason: LocationUploadReason) async -> Bool {
        for (index, delay) in retryDelaysSeconds.enumerated() {
            do {
                try Task.checkCancellation()
            } catch is CancellationError {
                logger.notice("Location upload cancelled before attempt source=\(payload.source, privacy: .public) reason=\(reason.rawValue, privacy: .public)")
                return false
            } catch {
                return false
            }

            if delay > 0 {
                do {
                    try await Task.sleep(for: .seconds(Int(delay)))
                    try Task.checkCancellation()
                } catch is CancellationError {
                    logger.notice("Location upload cancelled during retry backoff source=\(payload.source, privacy: .public) reason=\(reason.rawValue, privacy: .public)")
                    return false
                } catch {
                    return false
                }
            }
            do {
                try await uploader.upload(payload)
                return true
            } catch let error as LocationPushError {
                if await uploadWithLegacySourceFallbackIfNeeded(for: payload, error: error) {
                    return true
                }
                let isFinalAttempt = index == retryDelaysSeconds.count - 1
                if isFinalAttempt {
                    logger.error("Location snapshot upload failed after retries: \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.warning("Location snapshot upload attempt failed; retrying")
                }
            } catch is CancellationError {
                logger.notice("Location upload cancelled source=\(payload.source, privacy: .public) reason=\(reason.rawValue, privacy: .public)")
                return false
            } catch {
                let isFinalAttempt = index == retryDelaysSeconds.count - 1
                if isFinalAttempt {
                    logger.error("Location snapshot upload failed after retries: \(error.localizedDescription, privacy: .public)")
                } else {
                    logger.warning("Location snapshot upload attempt failed; retrying")
                }
            }
        }

        return false
    }

    private func uploadWithLegacySourceFallbackIfNeeded(
        for payload: LocationSnapshotPushPayload,
        error: LocationPushError
    ) async -> Bool {
        guard case .invalidResponseStatus(let status) = error else { return false }
        guard status == 400 || status == 422 else { return false }
        guard payload.source != "unknown" else { return false }

        let fallbackPayload = LocationSnapshotPushPayload(
            capturedAt: payload.capturedAt,
            locationAgeSeconds: payload.locationAgeSeconds,
            horizontalAccuracyMeters: payload.horizontalAccuracyMeters,
            cellScheme: payload.cellScheme,
            h3Cell: payload.h3Cell,
            h3Resolution: payload.h3Resolution,
            county: payload.county,
            zone: payload.zone,
            fireZone: payload.fireZone,
            apnsDeviceToken: payload.apnsDeviceToken,
            installationId: payload.installationId,
            source: "unknown",
            auth: payload.auth,
            appVersion: payload.appVersion,
            buildNumber: payload.buildNumber,
            platform: payload.platform,
            osVersion: payload.osVersion,
            apnsEnvironment: payload.apnsEnvironment,
            countyLabel: payload.countyLabel,
            fireZoneLabel: payload.fireZoneLabel,
            isSubscribed: payload.isSubscribed
        )

        do {
            try await uploader.upload(fallbackPayload)
            logger.notice("Location snapshot upload succeeded with legacy source fallback")
            return true
        } catch {
            return false
        }
    }

    private func makePayload(
        from request: PersistedLocationUploadRequest,
        apnsToken: String,
        isSubscribed: Bool,
        authorizationState: String,
        now: Date
    ) async -> LocationSnapshotPushPayload {
        let capturedAt = request.context?.capturedAt ?? request.requestedAt
        let locationAgeSeconds = request.context.map { now.timeIntervalSince($0.capturedAt) } ?? 0
        let horizontalAccuracyMeters = request.context?.horizontalAccuracyMeters ?? 0

        return LocationSnapshotPushPayload(
            capturedAt: capturedAt,
            locationAgeSeconds: locationAgeSeconds,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            cellScheme: "h3",
            h3Cell: request.context?.h3Cell,
            h3Resolution: request.context == nil ? nil : 8,
            county: request.context?.county,
            zone: request.context?.forecastZone,
            fireZone: request.context?.fireZone,
            apnsDeviceToken: apnsToken,
            installationId: request.installationId,
            source: request.source.rawValue,
            auth: authorizationState,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            platform: "iOS",
            osVersion: await UIDevice.current.systemVersion,
            apnsEnvironment: {
                #if DEBUG
                return "sandbox"
                #else
                return "prod"
                #endif
            }(),
            countyLabel: request.context?.countyLabel,
            fireZoneLabel: request.context?.fireZoneLabel,
            isSubscribed: isSubscribed
        )
    }

    private func ensurePersistedPendingLoaded() async {
        guard hasLoadedPersistedPending == false else { return }
        hasLoadedPersistedPending = true
        let loaded = await queueStore.loadPendingRequests()
        pendingByCoalescingKey = Dictionary(
            uniqueKeysWithValues: loaded.map { (coalescingKey(for: $0), $0) }
        )
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
            apnsToken: request.apnsToken,
            h3Cell: request.context?.h3Cell,
            county: request.context?.county,
            fireZone: request.context?.fireZone,
            forecastZone: request.context?.forecastZone,
            isSubscribed: request.isSubscribed,
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
        let h3Cell: Int64?
        let county: String?
        let fireZone: String?
        let forecastZone: String?
        let isSubscribed: Bool
        let authorizationState: String
        let forceUpload: Bool
    }

    private struct PendingCoalescingKey: Hashable, Codable {
        let installationId: String
        let apnsToken: String
        let h3Cell: Int64?
        let county: String?
        let fireZone: String?
        let forecastZone: String?
        let isSubscribed: Bool
        let authorizationState: String
        let forceUpload: Bool
    }

    private struct QueuedUpload {
        let payload: LocationSnapshotPushPayload
        let coalescingKey: PendingCoalescingKey
        let reason: LocationUploadReason
    }
}

protocol LocationUploadQueueStoring: Sendable {
    func loadPendingRequests() async -> [PersistedLocationUploadRequest]
    func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async
}

struct PersistedLocationUploadRequest: Sendable, Codable, Equatable {
    let context: PersistedLocationContext?
    let source: LocationUploadSource
    let reason: LocationUploadReason
    let forceUpload: Bool
    let installationId: String
    let requestedAt: Date
    let isSubscribed: Bool
    let authorizationState: String
    let apnsToken: String
}

struct PersistedLocationContext: Sendable, Codable, Equatable {
    let capturedAt: Date
    let horizontalAccuracyMeters: Double
    let h3Cell: Int64
    let county: String?
    let fireZone: String?
    let forecastZone: String?
    let countyLabel: String?
    let fireZoneLabel: String?

    init(_ context: LocationContext) {
        self.capturedAt = context.snapshot.timestamp
        self.horizontalAccuracyMeters = context.snapshot.accuracy
        self.h3Cell = context.h3Cell
        self.county = context.grid.countyCode
        self.fireZone = context.grid.fireZone
        self.forecastZone = context.grid.forecastZone
        self.countyLabel = context.grid.countyLabel
        self.fireZoneLabel = context.grid.fireZoneLabel
    }

    init(payload: LocationSnapshotPushPayload) {
        self.capturedAt = payload.capturedAt
        self.horizontalAccuracyMeters = payload.horizontalAccuracyMeters
        self.h3Cell = payload.h3Cell ?? 0
        self.county = payload.county
        self.fireZone = payload.fireZone
        self.forecastZone = payload.zone
        self.countyLabel = payload.countyLabel
        self.fireZoneLabel = payload.fireZoneLabel
    }
}

actor UserDefaultsLocationUploadQueueStore: LocationUploadQueueStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(suiteName: String, key: String) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.key = key
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadPendingRequests() async -> [PersistedLocationUploadRequest] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? decoder.decode([PersistedLocationUploadRequest].self, from: data)) ?? []
    }

    func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async {
        if requests.isEmpty {
            defaults.removeObject(forKey: key)
            return
        }
        if let data = try? encoder.encode(requests) {
            defaults.set(data, forKey: key)
        }
    }
}
