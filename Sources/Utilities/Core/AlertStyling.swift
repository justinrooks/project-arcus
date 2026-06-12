//
//  AlertStyling.swift
//  SkyAware
//
//  Created by Justin Rooks on 1/23/26.
//

import Foundation
import SwiftUI
import UIKit

struct WarningPolygonStyle {
    let fill: UIColor
    let stroke: UIColor
}

enum WarningPolygonKind: Int, Sendable {
    case tornado = 0
    case severeThunderstorm = 1
    case flashFlood = 2

    init?(event: String) {
        switch event.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "tornado warning":
            self = .tornado
        case "severe thunderstorm warning":
            self = .severeThunderstorm
        case "flash flood warning":
            self = .flashFlood
        default:
            return nil
        }
    }

    var displayTitle: String {
        switch self {
        case .tornado:
            return "Tornado"
        case .severeThunderstorm:
            return "Severe Thunderstorm"
        case .flashFlood:
            return "Flash Flood"
        }
    }

    var accessibilityLabel: String {
        "\(displayTitle) warning"
    }

    func style(fillAlpha: CGFloat = 0.22) -> WarningPolygonStyle {
        switch self {
        case .tornado:
            return WarningPolygonStyle(
                fill: UIColor.tornadoRed.withAlphaComponent(fillAlpha),
                stroke: .tornadoRed
            )

        case .severeThunderstorm:
            return WarningPolygonStyle(
                fill: UIColor.warningYellow.withAlphaComponent(fillAlpha),
                stroke: .warningYellow
            )

        case .flashFlood:
            return WarningPolygonStyle(
                fill: UIColor.floodBlue.withAlphaComponent(fillAlpha),
                stroke: .floodBlue
            )
        }
    }
}

// TODO: There's likely a better place for this than its own file. Move it when we figure it out.
func styleForType(_ type: AlertType, _ watchType: String?) -> (String, Color) {
    switch type {
    case .watch:
        if let watchType {
            switch watchType {
            case "Tornado Watch": return ("tornado", .tornadoRed)
            case "Tornado Warning": return ("tornado", .tornadoRed)
            case "Severe Thunderstorm Watch": return ("cloud.bolt.fill", .severeTstormWarn)
            case "Severe Thunderstorm Warning": return ("cloud.bolt.fill", .severeTstormWarn)
            case "Flash Flood Warning": return ("flood.fill", .hailBlue) // TODO: Create a flood color
            default: return ("exclamationmark.triangle", .red)
            }
        } else {
            return ("exclamationmark.triangle", .red)
        }
    case .mesoscale: return ("waveform.path.ecg.magnifyingglass", .mesoPurple)
    }
}

func warningPolygonStyle(for event: String) -> WarningPolygonStyle? {
    guard let kind = WarningPolygonKind(event: event) else { return nil }
    return kind.style()
}
