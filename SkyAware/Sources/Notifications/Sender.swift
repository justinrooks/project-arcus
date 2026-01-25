//
//  Sender.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation
import OSLog

struct Sender: NotificationSending {
    private let logger = Logger.notificationsSender
    
    func send(title: String, body: String, subtitle: String, id: String) async {
        logger.info("Sending notification")
        await NotificationManager.shared.notify(title: title, subtitle: subtitle, body: body)
        logger.notice("Notification sent")
    }
}
