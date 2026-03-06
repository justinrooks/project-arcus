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
        spacing: 11.5,
        lineWidth: 1.55,
        opacity: 0.42,
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
            adjusted.spacing *= 1.10
            adjusted.opacity *= 1.0
            adjusted.dashPattern = [3.2, 4.4]
            adjusted.lineOffset = adjusted.spacing * 0.15
        case 2:
            adjusted.opacity = min(0.48, adjusted.opacity * 1.05)
            adjusted.dashPattern = [8.5, 4.0]
            adjusted.lineOffset = adjusted.spacing * 0.45
        case 3:
            adjusted.spacing *= 0.82
            adjusted.lineWidth *= 1.22
            adjusted.opacity = min(0.56, adjusted.opacity * 1.22)
            adjusted.dashPattern = [15.0, 1.8]
            adjusted.lineOffset = adjusted.spacing * 0.75
        default:
            break
        }
        return adjusted
    }
}
