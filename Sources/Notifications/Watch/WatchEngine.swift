//
//  WatchEngine.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import OSLog

@available(*, deprecated, message: "Remove References")
struct WatchEngine: Sendable {
    private let logger = Logger.notificationsWatchEngine

    let rule: WatchNotificationRuleEvaluating
    let gate: NotificationGating
    let composer: NotificationComposing
    let sender: NotificationSending

    init(
        rule: WatchNotificationRuleEvaluating,
        gate: NotificationGating,
        composer: NotificationComposing,
        sender: NotificationSending
    ) {
        self.rule = rule
        self.gate = gate
        self.composer = composer
        self.sender = sender
    }

    func run(ctx: NotificationContext, watches: [WatchRowDTO]) async -> Bool {
        let watchContext = WatchContext(
            now: ctx.now,
            localTZ: ctx.localTZ,
            location: ctx.location,
            placeMark: ctx.placeMark,
            watches: watches
        )

        logger.debug("Running watch rules")
        guard let event = rule.evaluate(watchContext) else { return false }

        logger.debug("Checking watch gate")
        guard await gate.allow(event, now: watchContext.now) else { return false }

        logger.debug("Building watch notification")
        let message = composer.compose(event)

        logger.info("Sending watch notification")
        await sender.send(title: message.title, body: message.body, subtitle: message.subtitle, id: event.key)

        logger.notice("Watch notification sent")
        return true
    }
}
