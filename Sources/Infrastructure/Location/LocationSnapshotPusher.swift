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

enum LocationUploadSource: String, Sendable, Codable {
    case foregroundPrime
    case foregroundActivate
    case foregroundLocationChange
    case manualRefresh
    case backgroundRefresh
    case backgroundLocationChange
    case onboarding
    case settingsPreference
}

protocol LocationUploadCoordinating: Sendable {
    func enqueue(_ context: LocationContext, source: LocationUploadSource, forceUpload: Bool) async
    func drainPendingUploads() async
}

extension LocationUploadCoordinating {
    func enqueue(_ context: LocationContext, source: LocationUploadSource) async {
        await enqueue(context, source: source, forceUpload: false)
    }

    func drainPendingUploads() async {}
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

    func enqueue(_ context: LocationContext, source: LocationUploadSource, forceUpload: Bool = false) async {
        guard forceUpload || locationUploadEnabledProvider() else {
            logger.debug("Skipping location snapshot upload; disabled in settings")
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
            forceUpload: forceUpload,
            installationId: installationId,
            requestedAt: now,
            isSubscribed: isSubscribed,
            authorizationState: Self.authorizationName(for: authorizationStatus),
            apnsToken: apnsToken
        )

        guard !apnsToken.isEmpty else {
            logger.debug("Skipping location snapshot upload; APNs token unavailable")
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
            logger.debug("Deduplicating location snapshot upload request")
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
            await upsertPending(persisted)
        }

        queue.append(QueuedUpload(payload: payload, coalescingKey: coalescingKey))
        lastUploadBySemanticKey[dedupeKey] = now

        guard !isProcessing else { return }
        await processQueue()
    }

    func drainPendingUploads() async {
        await ensurePersistedPendingLoaded()

        guard !pendingByCoalescingKey.isEmpty else { return }

        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apnsToken.isEmpty else {
            logger.debug("Skipping pending location upload drain; APNs token unavailable")
            return
        }

        for pending in pendingByCoalescingKey.values.sorted(by: { $0.requestedAt < $1.requestedAt }) {
            let now = nowProvider()
            let dedupeKey = DeduplicationKey(
                installationId: pending.installationId,
                apnsToken: apnsToken,
                h3Cell: pending.context.h3Cell,
                county: pending.context.county,
                fireZone: pending.context.fireZone,
                forecastZone: pending.context.forecastZone,
                isSubscribed: pending.isSubscribed,
                authorizationState: pending.authorizationState,
                forceUpload: pending.forceUpload
            )
            if shouldDedupeRequest(for: dedupeKey, now: now) {
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
            queue.append(QueuedUpload(payload: payload, coalescingKey: coalescingKey(for: pending)))
            lastUploadBySemanticKey[dedupeKey] = now
        }

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
            let workItem = queue.removeFirst()
            let didUpload = await uploadWithRetry(workItem.payload)
            if didUpload {
                pendingByCoalescingKey.removeValue(forKey: workItem.coalescingKey)
                await persistPendingState()
            }
        }
    }

    private func uploadWithRetry(_ payload: LocationSnapshotPushPayload) async -> Bool {
        for (index, delay) in retryDelaysSeconds.enumerated() {
            if delay > 0 {
                try? await Task.sleep(for: .seconds(Int(delay)))
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
                logger.debug("Location snapshot upload cancelled")
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
        LocationSnapshotPushPayload(
            capturedAt: request.context.capturedAt,
            locationAgeSeconds: now.timeIntervalSince(request.context.capturedAt),
            horizontalAccuracyMeters: request.context.horizontalAccuracyMeters,
            cellScheme: "h3",
            h3Cell: request.context.h3Cell,
            h3Resolution: 8,
            county: request.context.county,
            zone: request.context.forecastZone,
            fireZone: request.context.fireZone,
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
            countyLabel: request.context.countyLabel,
            fireZoneLabel: request.context.fireZoneLabel,
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
            h3Cell: request.context.h3Cell,
            county: request.context.county,
            fireZone: request.context.fireZone,
            forecastZone: request.context.forecastZone,
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
        let h3Cell: Int64
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
        let h3Cell: Int64
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
    }
}

protocol LocationUploadQueueStoring: Sendable {
    func loadPendingRequests() async -> [PersistedLocationUploadRequest]
    func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async
}

struct PersistedLocationUploadRequest: Sendable, Codable, Equatable {
    let context: PersistedLocationContext
    let source: LocationUploadSource
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
        self.capturedAt = payload.capturedAt ?? .now
        self.horizontalAccuracyMeters = payload.horizontalAccuracyMeters ?? 0
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
