//
//  MorningEngine.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation
import OSLog

struct MorningEngine: Sendable {
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
        winterStillApplies: (@Sendable (MorningContext.WinterImpact) async -> Bool)? = nil
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
        if let winter = ctx.winterImpact, let winterStillApplies, !(await winterStillApplies(winter)) {
            // Claim admission can await storage while the accepted point or opt-in changes.
            delivery = rule.evaluate(.init(
                now: ctx.now, lastConvectiveIssue: ctx.lastConvectiveIssue, localTZ: ctx.localTZ,
                quietHours: ctx.quietHours, stormRisk: ctx.stormRisk, severeRisk: ctx.severeRisk,
                fireRisk: ctx.fireRisk, placeMark: ctx.placeMark, riskProfileChange: ctx.riskProfileChange
            ))
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
