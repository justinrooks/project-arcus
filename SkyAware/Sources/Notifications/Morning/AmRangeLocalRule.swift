//
//  AmRangeLocalRule.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/27/25.
//

import Foundation
import OSLog

struct AmRangeLocalRule: NotificationRule {
    private let logger = Logger.rule
    
    /// Local-time delivery window [startHour, endHour)
    /// Default: 07:00–11:00 local
    /// 7-11 should catch either the 6am (1200z) or 1030 (1630z) run
    let window: Range<Int>

    init(window: Range<Int> = 7..<11) {
        self.window = window
    }
    
    func evaluate(_ ctx: MorningContext) -> NotificationEvent? {
        logger.debug("Evaluating AM 7 to 11 local rule")
        var cal = Calendar(identifier: .gregorian); cal.timeZone = ctx.localTZ
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: ctx.now)
        let maxIssueAge: TimeInterval = 24 * 60 * 60
        
        guard let y = comps.year, let m = comps.month, let d = comps.day, let h = comps.hour else { return nil}
        if let q = ctx.quietHours, q.contains(h) {
            logger.debug("Observed quiet hours, no notification")
            return nil
        }
        
        guard window.contains(h) else {
            logger.debug("Hour \(h) not in window: \(window); skipping")
            return nil
        }
        if let issue = ctx.lastConvectiveIssue, ctx.now.timeIntervalSince(issue) > maxIssueAge {
            logger.debug("Outlook issue is stale; skipping notification")
            return nil
        }

        let stamp = String(format: "%04d-%02d-%02d", y, m, d) // day stamp
        let id = "morning:\(stamp)"
        logger.trace("Stamp generated: \(id)")
        
        return NotificationEvent(
            kind: .morningOutlook,
            key: id,
            payload: [
                "localDay": stamp,
                "issue": ctx.lastConvectiveIssue as Sendable?,
                "stormRisk": ctx.stormRisk,
                "severeRisk": ctx.severeRisk,
                "placeMark": ctx.placeMark
            ]
        )
    }
}
