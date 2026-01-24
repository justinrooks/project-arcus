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
    
    func run(ctx: MorningContext) async -> Bool {
        logger.debug("Running rules")
        guard let event = rule.evaluate(ctx) else { return false }
        
        logger.debug("Checking gate")
        guard await gate.allow(event, now: ctx.now) else { return false }
        
        logger.debug("Building notification")
        let msg = composer.compose(event)
        
        logger.debug("Sending notification")
        await sender.send(title: msg.title, body: msg.body, subtitle: msg.subtitle, id: event.key)
        
        logger.debug("Notification sent")
        return true
    }
}
