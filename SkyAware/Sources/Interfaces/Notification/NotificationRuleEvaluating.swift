//
//  NotificationRule.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

protocol NotificationRuleEvaluating: Sendable {
    func evaluate(_ ctx: MorningContext) -> NotificationEvent?
}

protocol MesoNotificationRuleEvaluating: Sendable {
    func evaluate(_ ctx: MesoContext) -> NotificationEvent?
}

protocol WatchNotificationRuleEvaluating: Sendable {
    func evaluate(_ ctx: WatchContext) -> NotificationEvent?
}
