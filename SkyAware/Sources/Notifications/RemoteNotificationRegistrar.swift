//
//  RemoteNotificationRegistrar.swift
//  SkyAware
//
//  Created by Codex on 2/22/26.
//

import Foundation
import OSLog
import Security
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

actor InstallationIdentityStore {
    static let shared = InstallationIdentityStore()
    nonisolated static let keychainService = "com.justinrooks.skyaware"
    nonisolated static let keychainAccount = "installationId"

    private let logger: Logger
    private let readInstallationId: @Sendable () -> String?
    private let writeInstallationId: @Sendable (String) -> Bool
    private var cachedInstallationId: String?

    init(
        logger: Logger = .identityInstallation,
        readInstallationId: @escaping @Sendable () -> String? = {
            readFromKeychain(service: keychainService, account: keychainAccount)
        },
        writeInstallationId: @escaping @Sendable (String) -> Bool = { value in
            writeToKeychain(value, service: keychainService, account: keychainAccount)
        }
    ) {
        self.logger = logger
        self.readInstallationId = readInstallationId
        self.writeInstallationId = writeInstallationId
    }

    func installationId() -> String {
        if let cachedInstallationId {
            return cachedInstallationId
        }

        if let existing = readInstallationId(), !existing.isEmpty {
            cachedInstallationId = existing
            return existing
        }

        let generated = UUID().uuidString.lowercased()
        if writeInstallationId(generated) {
            logger.notice("Created new installation ID")
        } else {
            logger.error("Failed to persist installation ID to Keychain; using volatile in-memory ID for this launch")
        }

        cachedInstallationId = generated
        return generated
    }

    nonisolated private static func readFromKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        guard let data = item as? Data else { return nil }

        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    nonisolated private static func writeToKeychain(_ value: String, service: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        guard updateStatus == errSecItemNotFound else {
            return false
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }

        if addStatus == errSecDuplicateItem {
            let retryStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            return retryStatus == errSecSuccess
        }

        return false
    }
}
