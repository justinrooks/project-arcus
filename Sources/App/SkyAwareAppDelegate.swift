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
    private static var remoteHotAlertHandler: RemoteHotAlertHandler?
    private static var startup: AppStartup?

    static func install(startup: AppStartup) {
        self.startup = startup
    }

    static func install(remoteHotAlertHandler: RemoteHotAlertHandler) {
        self.remoteHotAlertHandler = remoteHotAlertHandler
    }

    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        Self.startup?.retry()
    }

    static func resumePendingNotificationOpen() {
        guard let handler = remoteHotAlertHandler,
              let context = startup?.takePendingNotificationOpen() else { return }
        Task { await handler.handleNotificationOpen(context) }
    }

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
        guard let remoteAlertContext = HomeRemoteAlertContext(userInfo: userInfo) else {
            logger.notice("Ignoring remote notification without a supported hot-alert payload")
            completionHandler(.noData)
            return
        }

        Self.startup?.retry()
        guard let handler = Self.remoteHotAlertHandler else {
            logger.notice("Remote hot-alert receipt deferred because startup is unavailable")
            completionHandler(.failed)
            return
        }

        Task {
            completionHandler(await handler.handleRemoteNotification(remoteAlertContext))
        }
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let remoteAlertContext = HomeRemoteAlertContext(userInfo: userInfo) else {
            logger.notice("Ignoring notification open without a supported hot-alert payload")
            completionHandler()
            return
        }

        Self.startup?.retry()
        guard let handler = Self.remoteHotAlertHandler,
              Self.startup?.hasPresentedHome == true else {
            Self.startup?.deferNotificationOpen(remoteAlertContext)
            logger.notice("Retaining notification open until Home is ready")
            completionHandler()
            return
        }

        Task {
            await handler.handleNotificationOpen(remoteAlertContext)
            completionHandler()
        }
    }
}
