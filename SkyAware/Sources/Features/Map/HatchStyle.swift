//
//  HatchStyle.swift
//  SkyAware
//
//  Created by Codex on 3/5/26.
//

import Foundation

struct HatchStyle: Hashable, Sendable {
    var angleDegrees: Double
    var spacing: Double
    var lineWidth: Double
    var opacity: Double

    static let `default` = HatchStyle(
        angleDegrees: -45,
        spacing: 14,
        lineWidth: 1,
        opacity: 0.24
    )

    func adjusted(forIntensityLevel level: Int) -> HatchStyle {
        var adjusted = self
        switch level {
        case 1:
            adjusted.spacing *= 1.15
            adjusted.angleDegrees = 0
        case 3:
            adjusted.spacing *= 0.90
        default:
            break
        }
        return adjusted
    }
}
