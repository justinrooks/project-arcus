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

protocol LocationSnapshotPushing: Sendable {
    func enqueue(_ snapshot: LocationSnapshot) async
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
    let county: String?
    let zone: String?
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
    
}

actor LocationSnapshotPusher: LocationSnapshotPushing {
    typealias APNsTokenProvider = @Sendable () -> String
    typealias InstallationIDProvider = @Sendable () async -> String
    typealias GridRegionContextProvider = @Sendable () async -> NwsGridRegionContext?

    private let uploader: any LocationSnapshotUploading
    private let apnsTokenProvider: APNsTokenProvider
    private let installationIdProvider: InstallationIDProvider
    private let gridRegionContextProvider: GridRegionContextProvider
    private let retryDelaysSeconds: [UInt64]
    private let logger = Logger.locationPushPusher

    private var queue: [LocationSnapshotPushPayload] = []
    private var isProcessing = false

    init(
        uploader: any LocationSnapshotUploading,
        apnsTokenProvider: @escaping APNsTokenProvider = {
            UserDefaults(suiteName: "com.justinrooks.skyaware")?
                .string(forKey: RemoteNotificationRegistrar.apnsDeviceTokenKey) ?? ""
        },
        installationIdProvider: @escaping InstallationIDProvider = {
            InstallationIdentityStore.shared.installationId()
        },
        gridRegionContextProvider: @escaping GridRegionContextProvider = { nil },
        retryDelaysSeconds: [UInt64] = [0, 5, 15]
    ) {
        self.uploader = uploader
        self.apnsTokenProvider = apnsTokenProvider
        self.installationIdProvider = installationIdProvider
        self.gridRegionContextProvider = gridRegionContextProvider
        self.retryDelaysSeconds = retryDelaysSeconds
    }

    func enqueue(_ snapshot: LocationSnapshot) async {
        let regionContext = await gridRegionContextProvider()
        let installationId = await installationIdProvider()
        let apnsToken = apnsTokenProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apnsToken.isEmpty else {
            logger.debug("Skipping location snapshot upload; APNs token unavailable")
            return
        }
        let payload = LocationSnapshotPushPayload(
            capturedAt: snapshot.timestamp,
            locationAgeSeconds: Date().timeIntervalSince(snapshot.timestamp),
            horizontalAccuracyMeters: snapshot.accuracy,
            cellScheme: snapshot.h3Cell == nil ? "ugc-only" : "h3",
            h3Cell: snapshot.h3Cell,
            h3Resolution: 8, // TODO: Make this global someday
            county: regionContext?.county,
            zone: regionContext?.zone,
            fireZone: regionContext?.fireZone,
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
            }()
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
}
