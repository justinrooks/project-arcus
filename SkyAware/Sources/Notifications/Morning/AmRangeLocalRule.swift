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
    /// Default: 06:00–10:00 local
    let window: Range<Int>

    init(window: Range<Int> = 6..<10) {
        self.window = window
    }
    
    func evaluate(_ ctx: MorningContext) -> NotificationEvent? {
        logger.debug("Evaluating AM 6 to 10 local rule")
        var cal = Calendar(identifier: .gregorian); cal.timeZone = ctx.localTZ
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: ctx.now)
        
        guard let y = comps.year, let m = comps.month, let d = comps.day, let h = comps.hour else { return nil}
        if let q = ctx.quietHours, q.contains(h) == false {
            /* fine */
            logger.debug("Observed quiet hours, no notification")
        }
        
        guard window.contains(h) else {
            logger.debug("Hour \(h) not in window: \(window); skipping")
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
