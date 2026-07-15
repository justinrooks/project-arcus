//
//  NotificationManager.swift
//  SkyAware
//
//  Created by Justin Rooks on 8/27/25.
//

import Foundation
import UserNotifications
import OSLog

struct NotificationManager: Sendable {
    private let logger = Logger.notificationsManager
    static let shared = NotificationManager()
    
    /// Prepares and requests the notification to be sent. Each property after body is optional
    /// these properties will be assigned appropriately to the UNMutableNotificationContent
    /// object.
    /// - Parameters:
    ///   - title: title of the notification
    ///   - subtitle: subtitle for the notification
    ///   - body: body of the notification
    ///   - interval: delay send, defaults to 10 seconds
    ///   - sound: sound to use for notification default
    ///   - badge: badge count for the app icon defaults to 0
    ///   - repeats: repeats or not, defaults to false
    func notify(
        title: String,
        subtitle: String,
        body: String,
        id: String,
        interval: TimeInterval = 0.25,
        sound: UNNotificationSound = .default,
        badge: NSNumber = 0,
        repeats: Bool = false
    ) async -> Bool {
        let notificationReq = UNMutableNotificationContent()
        notificationReq.title = title
        notificationReq.subtitle = subtitle
        notificationReq.body = body
        notificationReq.sound = sound
        notificationReq.badge = badge
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: notificationReq, trigger: trigger)
        
        return await internalNotify(request: request)
    }
    
    /// Sends the notification with checks for authorization every time
    private func internalNotify(request: UNNotificationRequest) async -> Bool {
        let authType = await checkAuthorized()

        do {
            let center = UNUserNotificationCenter.current()
            switch authType {
            case .notDetermined:
                let result = await requestAuthorization()
                if result {
                    try await center.add(request)
                    return true
                } else {
                    logger.error("Error authorizing notifications")
                    return false
                }
            case .denied:
                return false
            case .authorized, .provisional, .ephemeral:
                try await center.add(request)
                return true
            @unknown default:
                logger.warning("Unknown authorization status")
                return false
            }
        } catch {
            logger.error("Error sending notification: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    /// Checks if the user has authorized Notifiations
    /// - Returns: the authorization status
    private func checkAuthorized() async -> UNAuthorizationStatus {
        logger.debug("Checking notification authorization status")
        let center = UNUserNotificationCenter.current()
        
        let settings = await center.notificationSettings()
        
        return settings.authorizationStatus
    }
    
    /// Requests notification permissions
    /// - Returns: returns true if the request was successful. False otherwise
    private func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert,
                                                            .sound,
                                                            .badge,
                                                            .carPlay,
                                                            .provisional,
//                                                            .criticalAlert,
                                                            .providesAppNotificationSettings])
            if granted {
                logger.info("Notification authorization successful")
            }
            return granted
            
        } catch {
            logger.error("Error requesting notification authorization: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    /// Gets the notification alert settings
    /// - Returns: the notification alert setting
    private func getAlertSetting() async -> UNNotificationSetting {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        return settings.alertSetting
    }
}
