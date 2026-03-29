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

protocol LocationContextPushing: Sendable {
    func enqueue(_ context: LocationContext) async
}

enum LocationPushError: Error {
    case invalidResponseStatus(Int)
}

struct LocationSnapshotPushPayload: Codable, Equatable, Sendable {
    let capturedAt: Date
    let locationAgeSeconds: Double
    let horizontalAccuracyMeters: Double
    let cellScheme: String
    let h3Cell: Int64?
    let h3Resolution: Int?
    let countyCode: String?
    let forecastZone: String?
    let fireZone: String?
    let apnsDeviceToken: String
    let installationId: String
    let source: String
    let auth: String
    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String
    let apnsEnvironment: String
    let countyLabel: String?
    let fireZoneLabel: String?
    let isSubscribed: Bool?

    enum CodingKeys: String, CodingKey {
        case capturedAt
        case locationAgeSeconds
        case horizontalAccuracyMeters
        case cellScheme
        case h3Cell
        case h3Resolution
        case countyCode = "county"
        case forecastZone = "zone"
        case fireZone
        case apnsDeviceToken
        case installationId
        case source
        case auth
        case appVersion
        case buildNumber
        case platform
        case osVersion
        case apnsEnvironment
        case countyLabel
        case fireZoneLabel
        case isSubscribed
    }
}

actor LocationSnapshotPusher: LocationContextPushing {
    typealias APNsTokenProvider = @Sendable () -> String
    typealias InstallationIDProvider = @Sendable () async -> String
    typealias SubscriptionStatusProvider = @Sendable () -> Bool

    nonisolated private static let userDefaultsSuiteName = "com.justinrooks.skyaware"
    nonisolated private static let serverNotificationEnabledKey = "serverNotificationEnabled"

    private let uploader: any LocationSnapshotUploading
    private let apnsTokenProvider: APNsTokenProvider
    private let installationIdProvider: InstallationIDProvider
    private let subscriptionStatusProvider: SubscriptionStatusProvider
    private let retryDelaysSeconds: [UInt64]
    private let logger = Logger.locationPushPusher

    private var queue: [LocationSnapshotPushPayload] = []
    private var isProcessing = false

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
        retryDelaysSeconds: [UInt64] = [0, 5, 15]
    ) {
        self.uploader = uploader
        self.apnsTokenProvider = apnsTokenProvider
        self.installationIdProvider = installationIdProvider
        self.subscriptionStatusProvider = subscriptionStatusProvider
        self.retryDelaysSeconds = retryDelaysSeconds
    }

    func enqueue(_ context: LocationContext) async {
        let snapshot = context.snapshot
        let installationId = await installationIdProvider()
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let isSubscribed = subscriptionStatusProvider()
        guard !apnsToken.isEmpty else {
            logger.debug("Skipping location snapshot upload; APNs token unavailable")
            return
        }
        let payload = LocationSnapshotPushPayload(
            capturedAt: snapshot.timestamp,
            locationAgeSeconds: Date().timeIntervalSince(snapshot.timestamp),
            horizontalAccuracyMeters: snapshot.accuracy,
            cellScheme: "h3",
            h3Cell: context.h3Cell,
            h3Resolution: 8, // TODO: Make this global someday
            countyCode: context.grid.countyCode,
            forecastZone: context.grid.forecastZone,
            fireZone: context.grid.fireZone,
            apnsDeviceToken: apnsToken,
            installationId: installationId,
            source: "unknown",
            auth: {
                switch CLLocationManager().authorizationStatus {
                case .authorizedAlways: return "always"
                case .authorizedWhenInUse: return "whenInUse"
                case .denied: return "denied"
                case .restricted: return "restricted"
                case .notDetermined: return "notDetermined"
                @unknown default: return "unknown"
                }
            }(),
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

        guard !isProcessing else { return }
        isProcessing = true
        await drainQueue()
        isProcessing = false
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
}
