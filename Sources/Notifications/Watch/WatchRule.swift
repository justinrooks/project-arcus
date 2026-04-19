//
//  WatchRule.swift
//  SkyAware
//
//  Created by OpenAI Codex.
//

import Foundation
import OSLog

@available(*, deprecated, message: "Remove References")
struct WatchRule: WatchNotificationRuleEvaluating {
    private let logger = Logger.notificationsWatchRule

    func evaluate(_ ctx: WatchContext) -> NotificationEvent? {
        logger.debug("Evaluating watch notification rule")

        let activeWatches = ctx.watches
            .filter { $0.ends > ctx.now && $0.isUpdateMessage == false }
            .sorted { lhs, rhs in
                if lhs.issued == rhs.issued {
                    return lhs.id < rhs.id
                }
                return lhs.issued > rhs.issued
            }

        guard let watch = activeWatches.first else {
            logger.debug("No active watches eligible for notification")
            return nil
        }

        let localDay = Self.localDayString(for: ctx.now, timeZone: ctx.localTZ)
        return NotificationEvent(
            kind: .watchNotification,
            key: "watch:\(watch.id)",
            payload: [
                "watchId": watch.id,
                "title": watch.title,
                "headline": watch.headline,
                "placeMark": ctx.placeMark,
                "localDay": localDay
            ]
        )
    }

    private static func localDayString(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
