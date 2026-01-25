//
//  WatchEngine.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/2/26.
//

import Foundation
import OSLog

struct WatchEngine: Sendable {
    private let logger = Logger.notificationsWatchEngine
    
    let rule: WatchNotificationRuleEvaluating
    let gate: NotificationGating
    let composer: NotificationComposing
    let sender: NotificationSending
    let nws: NwsRiskQuerying
    
    init(
        rule: WatchNotificationRuleEvaluating,
        gate: NotificationGating,
        composer: NotificationComposing,
        sender: NotificationSending,
        nws: NwsRiskQuerying
    ) {
        self.rule = rule
        self.gate = gate
        self.composer = composer
        self.sender = sender
        self.nws = nws
    }

    func run(ctx: NotificationContext) async -> Bool {
        do{
            logger.debug("Fetching active watches")
            let watches = try await nws.getActiveWatches(for: ctx.location)
            let updatedCtx = WatchContext(
                now: .now,
                localTZ: ctx.localTZ,
                location: ctx.location,
                placeMark: ctx.placeMark,
                watches: watches
            )
            
            logger.debug("Running rules")
            guard let event = rule.evaluate(updatedCtx) else { return false }
            
            logger.debug("Checking gate")
            guard await gate.allow(event, now: updatedCtx.now) else { return false }
            
            logger.debug("Building notification")
            let msg = composer.compose(event)
            
            logger.info("Sending notification")
            await sender.send(title: msg.title, body: msg.body, subtitle: msg.subtitle, id: event.key)
            
            logger.notice("Notification sent")
            return true
        } catch {
            logger.error("Error in WatchEngine: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
