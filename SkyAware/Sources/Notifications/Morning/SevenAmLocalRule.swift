//
//  SevenAmLocalRule.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

import Foundation
import OSLog

struct SevenAmLocalRule: NotificationRule {
    private let logger = Logger.rule
    
    init () {}
    
    func evaluate(_ ctx: MorningContext) -> NotificationEvent? {
        logger.debug("Evaluating 7am local rule")
        var cal = Calendar(identifier: .gregorian); cal.timeZone = ctx.localTZ
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: ctx.now)
        
        guard let y = comps.year, let m = comps.month, let d = comps.day, let h = comps.hour else { return nil}
        if let q = ctx.quietHours, q.contains(h) == false {
            /* fine */
            logger.debug("Observed quiet hours, no notification")
        }
        
        guard h == 7 else { return nil } // 7:00 - 7:59 local time
        
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
