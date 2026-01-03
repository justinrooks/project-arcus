//
//  NotificationsCore.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation

enum NotificationKind: Sendable { case morningOutlook, mesoNotification, watchNotification }

struct NotificationEvent: Sendable {
    let kind: NotificationKind
    let key: String
    let payload: [String: Sendable]
}
