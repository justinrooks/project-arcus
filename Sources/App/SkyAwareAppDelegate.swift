//
//  SkyAwareAppDelegate.swift
//  SkyAware
//
//  Created by Codex on 2/22/26.
//

import OSLog
import UIKit
import UserNotifications

@MainActor
final class SkyAwareAppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger.notificationsRemote

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        RemoteNotificationRegistrar.shared.storeDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
    }
    
    func application(
            _ application: UIApplication,
            didReceiveRemoteNotification userInfo: [AnyHashable: Any],
            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
        ) {
            Task {
                do {
                    // Parse your app-specific payload.
                    guard
                        let eventKey = userInfo["eventKey"] as? String,
                        let revision = userInfo["revision"] as? Int
                    else {
                        completionHandler(.noData)
                        return
                    }

                    // Call the same refresh/sync pipeline you would use elsewhere.
                    let didUpdate = try await refreshEventState(eventKey: eventKey, revision: revision)

                    completionHandler(didUpdate ? .newData : .noData)
                } catch {
                    completionHandler(.failed)
                }
            }
        }
    
    private func refreshEventState(eventKey: String, revision: Int) async throws -> Bool {
        // Example:
        // 1. Fetch canonical/latest event details from your backend or source URL
        // 2. Update local persistence
        // 3. Return true if local state changed
        logger.notice("Refresh triggered from Arcus-Signal")
        return true
    }
}

extension SkyAwareAppDelegate: @MainActor UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }
}
