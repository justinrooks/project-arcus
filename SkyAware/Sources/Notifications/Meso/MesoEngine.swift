//
//  MesoEngine.swift
//  SkyAware
//
//  Created by Justin Rooks on 11/2/25.
//

import Foundation
import OSLog

struct MesoEngine: Sendable {
    private let logger = Logger.mesoEngine
    
    let rule: MesoNotificationRuleEvaluating
    let gate: NotificationGating
    let composer: NotificationComposing
    let sender: NotificationSending
    let spc: SpcRiskQuerying
    
    init(
        rule: MesoNotificationRuleEvaluating,
        gate: NotificationGating,
        composer: NotificationComposing,
        sender: NotificationSending,
        spc: SpcRiskQuerying
    ) {
        self.rule = rule
        self.gate = gate
        self.composer = composer
        self.sender = sender
        self.spc = spc
    }
    
    func run(ctx: NotificationContext) async -> Bool {
        do{
            logger.debug("Fetching active mesos")
            let mesos = try await spc.getActiveMesos(at: .now, for: ctx.location)
            let updatedCtx = MesoContext(
                now: .now,
                localTZ: ctx.localTZ,
                location: ctx.location,
                placeMark: ctx.placeMark,
                mesos: mesos
            )
            
            logger.debug("Running rules")
            guard let event = rule.evaluate(updatedCtx) else { return false }
            
            logger.debug("Checking gate")
            guard await gate.allow(event, now: updatedCtx.now) else { return false }
            
            logger.debug("Building notification")
            let msg = composer.compose(event)
            
            logger.debug("Sending notification")
            await sender.send(title: msg.title, body: msg.body, subtitle: msg.subtitle, id: event.key)
            
            logger.debug("Notification sent")
            return true
        } catch {
            logger.error("Error in MesoEngine: \(error.localizedDescription)")
            return false
        }
    }
}
