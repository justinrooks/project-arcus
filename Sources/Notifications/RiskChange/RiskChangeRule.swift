//
//  RiskChangeRule.swift
//  SkyAware
//
//  Created by Justin Rooks on 7/15/26.
//

import Foundation
import OSLog

struct RiskChangeRule: RiskChangeNotificationRuleEvaluating {
    private let logger = Logger.notificationsRiskChangeRule

    func evaluate(_ ctx: RiskChangeContext) -> NotificationEvent? {
        logger.debug("Evaluating risk change notification rule")

        let change = ctx.change
        guard change.changedDimensions.isEmpty == false else {
            logger.debug("No changed dimensions for risk change notification")
            return nil
        }

        let payload: [String: Sendable] = [
            "change": change
        ]

        return NotificationEvent(
            kind: .riskProfileChange,
            key: Self.identifier(for: change),
            payload: payload
        )
    }

    static func identifier(for change: RiskProfileChange) -> String {
        "risk:\(change.projectionKey):\(change.currentFingerprint)"
    }
}
