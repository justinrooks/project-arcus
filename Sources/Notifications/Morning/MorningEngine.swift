//
//  MorningEngine.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation
import OSLog

struct MorningEngine: Sendable {
    struct DeliveryAuthorization: Sendable {
        let time: Date
        let includeWinter: Bool
    }

    private let logger = Logger.notificationsMorningEngine
    
    let rule: NotificationRuleEvaluating
    let gate: NotificationGating
    let composer: NotificationComposing
    let sender: NotificationSending
    
    init(
        rule: NotificationRuleEvaluating,
        gate: NotificationGating,
        composer: NotificationComposing,
        sender: NotificationSending
    ) {
        self.rule = rule
        self.gate = gate
        self.composer = composer
        self.sender = sender
    }
    
    func run(
        ctx: MorningContext,
        authorizeDelivery: (@Sendable (MorningContext.WinterImpact?) async -> DeliveryAuthorization?)? = nil
    ) async -> Bool {
        logger.debug("Running rules")
        guard !Task.isCancelled, let event = rule.evaluate(ctx) else { return false }
        
        logger.debug("Checking gate")
        guard await gate.allow(event, now: ctx.now) else { return false }
        guard !Task.isCancelled else {
            await gate.finish(event, didSchedule: false)
            return false
        }

        let delivery: NotificationEvent?
        if let authorizeDelivery {
            // Claim admission can await storage while policy, time, or the accepted point changes.
            let authorization = await authorizeDelivery(ctx.winterImpact)
            delivery = authorization.flatMap {
                rule.evaluate(ctx.atDeliveryTime($0.time, includeWinter: $0.includeWinter))
            }
        } else {
            delivery = event
        }
        guard !Task.isCancelled, let delivery, delivery.key == event.key else {
            await gate.finish(event, didSchedule: false)
            return false
        }
        
        logger.debug("Building notification")
        let msg = composer.compose(delivery)
        
        logger.info("Sending notification")
        let didSchedule = await sender.send(title: msg.title, body: msg.body, subtitle: msg.subtitle, id: event.key)
        await gate.finish(event, didSchedule: didSchedule)
        
        if didSchedule { logger.notice("Notification scheduled") }
        return didSchedule
    }
}
