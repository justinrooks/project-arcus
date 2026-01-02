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

protocol NotificationRule: Sendable {
    func evaluate(_ ctx: MorningContext) -> NotificationEvent?
}

protocol MesoNotificationRule: Sendable {
    func evaluate(_ ctx: MesoContext) -> NotificationEvent?
}

protocol WatchNotificationRule: Sendable {
    func evaluate(_ ctx: WatchContext) -> NotificationEvent?
}

protocol NotificationGate: Sendable {
    func allow(_ event: NotificationEvent, now: Date) async -> Bool
}

protocol NotificationComposer: Sendable {
    func compose(_ event: NotificationEvent) -> (title: String, body: String, subtitle: String)
}

protocol NotificationSender: Sendable {
    func send(title: String, body: String, subtitle: String, id: String) async
}

protocol MorningStateStore: Sendable {
    func lastMorningStamp() async -> String?
    func setLastMorningStamp(_ stamp: String) async
}

protocol NotificationStateStore: Sendable {
    func lastStamp() async -> String?
    func setLastStamp(_ stamp: String) async
}
