//
//  WatchRule.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/2/26.
//

import Foundation
import OSLog
import MapKit

struct WatchRule: WatchNotificationRuleEvaluating {
    private let logger = Logger.notificationsWatchRule
    
    func evaluate(_ ctx: WatchContext) -> NotificationEvent? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = ctx.localTZ
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: ctx.now)
        let maxIssueAge: TimeInterval = 24 * 60 * 60
        
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil}
        
        // MARK: Rule
        let activeWatches = ctx.watches.filter {
            $0.validEnd >= ctx.now && ctx.now.timeIntervalSince($0.issued) <= maxIssueAge
        }
        if activeWatches.isEmpty {
            logger.debug("No active watches for current time and location")
            return nil
        }
        if activeWatches.count > 1 { logger.warning("Multiple watches found, only using most recent") }

        let watch: WatchRowDTO? = activeWatches.max(by: { $0.issued < $1.issued }) // Get the most recently issued watch
        
        guard let watch else { return nil }

        // MARK: Stamp
        let stamp = String(format: "%04d-%02d-%02d", y, m, d) // day stamp
        let id = "watch:\(stamp)-\(watch.id)"
        logger.trace("Stamp generated: \(id)")
        
        return NotificationEvent(
            kind: .watchNotification,
            key: id,
            payload: [
                "localDay": stamp,
                "watchId": watch.id,
                "sender": watch.sender,
                "severity": watch.severity,
                "urgency": watch.urgency,
                "certainty": watch.certainty,
                "title": watch.title,
                "headline": watch.headline,
                "area": watch.areaSummary,
                "issue": watch.issued,
                "expires": watch.expires,
                "placeMark": ctx.placeMark
            ]
        )
    }
}
