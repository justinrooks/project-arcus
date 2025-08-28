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
    
    
    func notify(for outlook:ConvectiveOutlook?) async {
        guard let outlook else { return } // if we don't get an outlook, dont send a notification
        
//        let d = does(outlook.published, matchHour: 7)
        
        // TODO: Move this check somewhere else? Maybe ask on first load
        let center = UNUserNotificationCenter.current()
        let authType = await checkAuthorized()
        
        let addNotification = {
            let notificationReq = UNMutableNotificationContent()
            notificationReq.title = "New Day 1 Convective Outlook"
            notificationReq.subtitle = "Published: \(formattedDate(outlook.published))"
            notificationReq.body = "\(String(outlook.summary.prefix(24)))..."
            notificationReq.sound = UNNotificationSound.default
            notificationReq.badge = 0
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: notificationReq, trigger: trigger)
            center.add(request)
        }
        
        switch authType {
        case .notDetermined:
            let result = await requestAuthorization()
            if result {
                addNotification()
            } else {
                logger.error("Error authorizing notifications")
                return
            }
        case .denied:
            return
        case .authorized, .provisional, .ephemeral:
            addNotification()
        @unknown default:
            logger.warning("Unknown authorization status")
            return
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
            try await center.requestAuthorization(options: [.alert, .badge, .sound, .provisional])
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
