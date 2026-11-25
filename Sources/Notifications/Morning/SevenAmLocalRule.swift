//
//  SevenAmLocalRule.swift
//  SkyAware
//
//  Created by Justin Rooks on 10/21/25.
//

struct SevenAmLocalRule: NotificationRuleEvaluating {
    func evaluate(_ ctx: MorningContext) -> NotificationEvent? {
        AmRangeLocalRule(window: 7..<8).evaluate(ctx)
    }
}
