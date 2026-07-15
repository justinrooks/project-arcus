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
    let gate: RiskChangeGate
    let composer: NotificationComposing
    let sender: NotificationSending

    init(
        rule: RiskChangeNotificationRuleEvaluating,
        gate: RiskChangeGate,
        composer: NotificationComposing,
        sender: NotificationSending
    ) {
        self.rule = rule
        self.gate = gate
        self.composer = composer
        self.sender = sender
    }

    func run(change: RiskProfileChange?, isEnabled: Bool = true) async -> Bool {
        var preferredEventKey: String?
        if let change {
            let context = RiskChangeContext(change: change)
            logger.debug("Running risk change rules")
            if let event = rule.evaluate(context) {
                let message = composer.compose(event)
                await gate.register(event: event, message: message)
                preferredEventKey = event.key
            }
        }

        guard let delivery = await gate.claim(preferredEventKey: preferredEventKey, isEnabled: isEnabled) else {
            return false
        }

        logger.info("Sending risk change notification")
        let didSchedule = await sender.send(
            title: delivery.title,
            body: delivery.body,
            subtitle: delivery.subtitle,
            id: delivery.eventKey
        )
        await gate.finish(delivery, didSchedule: didSchedule)

        if didSchedule {
            logger.notice("Risk change notification scheduled")
        }
        return didSchedule
    }
}
