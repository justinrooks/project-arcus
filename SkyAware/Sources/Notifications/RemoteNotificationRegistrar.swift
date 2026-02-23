//
//  RemoteNotificationRegistrar.swift
//  SkyAware
//
//  Created by Codex on 2/22/26.
//

import Foundation
import OSLog
import UIKit
import UserNotifications

@MainActor
final class RemoteNotificationRegistrar {
    static let shared = RemoteNotificationRegistrar()
    nonisolated static let apnsDeviceTokenKey = "apnsDeviceToken"

    private let center: UNUserNotificationCenter
    private let userDefaults: UserDefaults?
    private let logger: Logger
    private let registerRemoteNotifications: @MainActor () -> Void

    init(
        center: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults? = UserDefaults.shared,
        logger: Logger = .notificationsRemote,
        registerRemoteNotifications: @escaping @MainActor () -> Void = {
            UIApplication.shared.registerForRemoteNotifications()
        }
    ) {
        self.center = center
        self.userDefaults = userDefaults
        self.logger = logger
        self.registerRemoteNotifications = registerRemoteNotifications
    }

    func requestAuthorizationAndRegister() async {
        let status = await requestAuthorizationIfNeeded()
        registerIfAuthorized(status: status, context: "permission-request")
    }

    func registerForRemoteNotificationsIfAuthorized(context: String) async {
        let settings = await center.notificationSettings()
        registerIfAuthorized(status: settings.authorizationStatus, context: context)
    }

    func storeDeviceToken(_ deviceToken: Data) {
        let token = Self.deviceTokenString(from: deviceToken)
        userDefaults?.set(token, forKey: Self.apnsDeviceTokenKey)
        logger.notice("Stored APNs device token with \(token.count, privacy: .public) hex chars")
#if DEBUG
        logger.debug("APNs device token (debug): \(token, privacy: .public)")
#endif
    }

    nonisolated static func deviceTokenString(from deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    private func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()

        if settings.authorizationStatus != .notDetermined {
            return settings.authorizationStatus
        }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            let updatedSettings = await center.notificationSettings()
            logger.notice("Notification authorization status changed to: \(String(describing: updatedSettings.authorizationStatus), privacy: .public)")
            return updatedSettings.authorizationStatus
        } catch {
            logger.error("Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
            return .denied
        }
    }

    private func registerIfAuthorized(status: UNAuthorizationStatus, context: String) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            logger.debug("Registering for remote notifications (\(context, privacy: .public))")
            registerRemoteNotifications()
        case .notDetermined, .denied:
            logger.debug("Skipping remote notification registration (\(context, privacy: .public)) due to auth status: \(String(describing: status), privacy: .public)")
        @unknown default:
            logger.warning("Unknown notification auth status while registering APNs token")
        }
    }
}
