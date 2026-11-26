//
//  NotificationRule.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/3/26.
//

import Foundation

protocol NotificationRuleEvaluating: Sendable {
    func evaluate(_ ctx: MorningContext) -> NotificationEvent?
    func isInDeliveryWindow(at time: Date, localTZ: TimeZone) -> Bool
}

extension NotificationRuleEvaluating {
    func isInDeliveryWindow(at time: Date, localTZ: TimeZone) -> Bool { true }
}

protocol MesoNotificationRuleEvaluating: Sendable {
    func evaluate(_ ctx: MesoContext) -> NotificationEvent?
}

protocol WatchNotificationRuleEvaluating: Sendable {
    func evaluate(_ ctx: WatchContext) -> NotificationEvent?
}

protocol RiskChangeNotificationRuleEvaluating: Sendable {
    func evaluate(_ ctx: RiskChangeContext) -> NotificationEvent?
}
