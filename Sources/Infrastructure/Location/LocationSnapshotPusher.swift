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

enum LocationUploadSource: String, Sendable {
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
}

extension LocationUploadCoordinating {
    func enqueue(_ context: LocationContext, source: LocationUploadSource) async {
        await enqueue(context, source: source, forceUpload: false)
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

    private let uploader: any LocationSnapshotUploading
    private let apnsTokenProvider: APNsTokenProvider
    private let installationIdProvider: InstallationIDProvider
    private let subscriptionStatusProvider: SubscriptionStatusProvider
    private let locationUploadEnabledProvider: LocationUploadEnabledProvider
    private let authorizationStatusProvider: AuthorizationStatusProvider
    private let nowProvider: NowProvider
    private let retryDelaysSeconds: [UInt64]
    private let dedupeWindowSeconds: TimeInterval
    private let logger = Logger.locationPushPusher

    private var queue: [LocationSnapshotPushPayload] = []
    private var isProcessing = false
    private var lastUploadBySemanticKey: [DeduplicationKey: Date] = [:]

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
        dedupeWindowSeconds: TimeInterval = 15
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
    }

    func enqueue(_ context: LocationContext, source: LocationUploadSource, forceUpload: Bool = false) async {
        guard forceUpload || locationUploadEnabledProvider() else {
            logger.debug("Skipping location snapshot upload; disabled in settings")
            return
        }

        let snapshot = context.snapshot
        let installationId = await installationIdProvider()
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let isSubscribed = subscriptionStatusProvider()
        let authorizationStatus = authorizationStatusProvider()
        let now = nowProvider()
        guard !apnsToken.isEmpty else {
            logger.debug("Skipping location snapshot upload; APNs token unavailable")
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
        let payload = LocationSnapshotPushPayload(
            capturedAt: snapshot.timestamp,
            locationAgeSeconds: now.timeIntervalSince(snapshot.timestamp),
            horizontalAccuracyMeters: snapshot.accuracy,
            cellScheme: "h3",
            h3Cell: context.h3Cell,
            h3Resolution: 8, // TODO: Make this global someday
            county: context.grid.countyCode,
            zone: context.grid.forecastZone,
            fireZone: context.grid.fireZone,
            apnsDeviceToken: apnsToken,
            installationId: installationId,
            source: source.rawValue,
            auth: Self.authorizationName(for: authorizationStatus),
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
            countyLabel: context.grid.countyLabel,
            fireZoneLabel: context.grid.fireZoneLabel,
            isSubscribed: isSubscribed
        )

        queue.append(payload)
        lastUploadBySemanticKey[dedupeKey] = now

        guard !isProcessing else { return }
        isProcessing = true
        await drainQueue()
        isProcessing = false
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

    private func drainQueue() async {
        while !queue.isEmpty {
            let payload = queue.removeFirst()
            _ = await uploadWithRetry(payload)
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
}
