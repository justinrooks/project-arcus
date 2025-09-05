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
    private let logger = Logger.notifications
    
    func notify(title: String, subtitle: String, body: String, interval: TimeInterval = 10) async {
        let notificationReq = UNMutableNotificationContent()
        notificationReq.title = title
        notificationReq.subtitle = subtitle
        notificationReq.body = body
        notificationReq.sound = UNNotificationSound.default
        notificationReq.badge = 0
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationReq, trigger: trigger)
        
        await internalNotify(request: request)
    }
    
    func notify(for outlook:ConvectiveOutlook?, with message: String?) async {
        guard let outlook else { return } // if we don't get an outlook, dont send a notification
        
        //        let d = does(outlook.published, matchHour: 7)

        let notificationReq = UNMutableNotificationContent()
        notificationReq.title = "New Day 1 Convective Outlook"
        notificationReq.subtitle = "Published: \(outlook.published.toShortTime())"
        notificationReq.body = "\(message ?? String(outlook.summary.prefix(24)))..."
        notificationReq.sound = UNNotificationSound.default
        notificationReq.badge = 0
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationReq, trigger: trigger)
        
        await internalNotify(request: request)
    }
    
    
    
    
    private func internalNotify(request: UNNotificationRequest) async {
        let authType = await checkAuthorized()

        do {
            let center = UNUserNotificationCenter.current()
            switch authType {
            case .notDetermined:
                let result = await requestAuthorization()
                if result {
                    try await center.add(request)
                } else {
                    logger.error("Error authorizing notifications")
                    return
                }
            case .denied:
                return
            case .authorized, .provisional, .ephemeral:
                try await center.add(request)
            @unknown default:
                logger.warning("Unknown authorization status")
                return
            }
        } catch {
            logger.error("Error sending notification: \(error.localizedDescription)")
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
            try await center.requestAuthorization(options: [.alert, .badge, .sound])
            logger.debug("Notification authorization successful")
            return true
            
        } catch {
            logger.error("Error requesting notification authorization: \(error.localizedDescription)")
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
