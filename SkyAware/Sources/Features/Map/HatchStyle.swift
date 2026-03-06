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
    var dashPattern: [Double]
    var lineOffset: Double

    static let `default` = HatchStyle(
        angleDegrees: -45,
        spacing: 14,
        lineWidth: 1,
        opacity: 0.24,
        dashPattern: [],
        lineOffset: 0
    )

    static var legendPreviewStyles: [HatchStyle] {
        [1, 2, 3].map { HatchStyle.default.adjusted(forIntensityLevel: $0) }
    }

    func adjusted(forIntensityLevel level: Int) -> HatchStyle {
        var adjusted = self
        switch level {
        case 1:
            adjusted.spacing *= 1.15
            adjusted.opacity *= 0.90
            adjusted.dashPattern = [1.2, 7.5]
            adjusted.lineOffset = adjusted.spacing * 0.15
        case 2:
            adjusted.dashPattern = [5.5, 6.5]
            adjusted.lineOffset = adjusted.spacing * 0.45
        case 3:
            adjusted.spacing *= 0.90
            adjusted.lineWidth *= 1.08
            adjusted.opacity = min(0.30, adjusted.opacity * 1.12)
            adjusted.dashPattern = [10.0, 4.0]
            adjusted.lineOffset = adjusted.spacing * 0.75
        default:
            break
        }
        return adjusted
    }
}
