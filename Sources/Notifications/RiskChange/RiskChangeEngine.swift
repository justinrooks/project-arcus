//
//  RiskChangeEngine.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/15/26.
//

import Foundation
import OSLog

struct RiskChangeEngine: Sendable {
    private let logger = Logger.notificationsRiskChangeEngine

    let rule: RiskChangeNotificationRuleEvaluating
    let gate: NotificationGating
    let composer: NotificationComposing
    let sender: NotificationSending

    init(
        rule: RiskChangeNotificationRuleEvaluating,
        gate: NotificationGating,
        composer: NotificationComposing,
        sender: NotificationSending
    ) {
        self.rule = rule
        self.gate = gate
        self.composer = composer
        self.sender = sender
    }

    func run(change: RiskProfileChange?) async -> Bool {
        guard let change else {
            logger.debug("Skipping risk change notification run because there is no change")
            return false
        }

        let context = RiskChangeContext(change: change)
        logger.debug("Running risk change rules")
        guard let event = rule.evaluate(context) else { return false }

        logger.debug("Checking risk change gate")
        guard await gate.allow(event, now: .now) else { return false }

        logger.debug("Building risk change notification")
        let message = composer.compose(event)

        logger.info("Sending risk change notification")
        await sender.send(title: message.title, body: message.body, subtitle: message.subtitle, id: event.key)

        logger.notice("Risk change notification sent")
        return true
    }
}
