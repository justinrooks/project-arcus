//
//  Sender.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation
import OSLog

struct Sender: NotificationSender {
    private let logger = Logger.sender
    
    init() {}
    
    func send(title: String, body: String, subtitle: String, id: String) async {
        logger.debug("Sending notification")
        await NotificationManager.shared.notify(title: title, subtitle: subtitle, body: body)
        logger.debug("Notification sent")
    }
}
