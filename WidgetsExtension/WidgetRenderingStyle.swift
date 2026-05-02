import SwiftUI
import WidgetKit

enum WidgetRiskKind: String, CaseIterable {
    case storm
    case severe

    var title: String {
        switch self {
        case .storm:
            return "Storm Risk"
        case .severe:
            return "Severe Risk"
        }
    }
}

struct WidgetRiskVisualStyle {
    let icon: String
    let tint: Color
    let chip: Color

    static func style(for kind: WidgetRiskKind, severity: Int) -> WidgetRiskVisualStyle {
        switch kind {
        case .storm:
            return stormStyle(severity: severity)
        case .severe:
            return severeStyle(severity: severity)
        }
    }

    private static func stormStyle(severity: Int) -> WidgetRiskVisualStyle {
        switch severity {
        case 6:
            return WidgetRiskVisualStyle(icon: "bolt.trianglebadge.exclamationmark.fill", tint: Color(red: 0.62, green: 0.25, blue: 0.80), chip: Color(red: 0.62, green: 0.25, blue: 0.80).opacity(0.18))
        case 5:
            return WidgetRiskVisualStyle(icon: "exclamationmark.octagon.fill", tint: Color(red: 0.88, green: 0.30, blue: 0.25), chip: Color(red: 0.88, green: 0.30, blue: 0.25).opacity(0.18))
        case 4:
            return WidgetRiskVisualStyle(icon: "bolt.fill", tint: Color(red: 0.95, green: 0.55, blue: 0.20), chip: Color(red: 0.95, green: 0.55, blue: 0.20).opacity(0.18))
        case 3:
            return WidgetRiskVisualStyle(icon: "exclamationmark.triangle.fill", tint: Color(red: 0.95, green: 0.80, blue: 0.25), chip: Color(red: 0.95, green: 0.80, blue: 0.25).opacity(0.18))
        case 2:
            return WidgetRiskVisualStyle(icon: "exclamationmark.circle.fill", tint: Color(red: 0.25, green: 0.60, blue: 0.30), chip: Color(red: 0.25, green: 0.60, blue: 0.30).opacity(0.18))
        case 1:
            return WidgetRiskVisualStyle(icon: "cloud.bolt.rain.fill", tint: Color(red: 0.35, green: 0.70, blue: 0.35), chip: Color(red: 0.35, green: 0.70, blue: 0.35).opacity(0.18))
        default:
            return WidgetRiskVisualStyle(icon: "checkmark.seal.fill", tint: Color(red: 0.40, green: 0.75, blue: 0.40), chip: Color(red: 0.40, green: 0.75, blue: 0.40).opacity(0.18))
        }
    }

    private static func severeStyle(severity: Int) -> WidgetRiskVisualStyle {
        switch severity {
        case 3:
            return WidgetRiskVisualStyle(icon: "tornado", tint: Color(red: 0.80, green: 0.20, blue: 0.40), chip: Color(red: 0.80, green: 0.20, blue: 0.40).opacity(0.18))
        case 2:
            return WidgetRiskVisualStyle(icon: "cloud.hail.fill", tint: Color(red: 0.30, green: 0.60, blue: 0.90), chip: Color(red: 0.30, green: 0.60, blue: 0.90).opacity(0.18))
        case 1:
            return WidgetRiskVisualStyle(icon: "wind", tint: Color(red: 0.20, green: 0.70, blue: 0.70), chip: Color(red: 0.20, green: 0.70, blue: 0.70).opacity(0.18))
        default:
            return WidgetRiskVisualStyle(icon: "checkmark.seal.fill", tint: Color(red: 0.40, green: 0.75, blue: 0.40), chip: Color(red: 0.40, green: 0.75, blue: 0.40).opacity(0.18))
        }
    }
}

struct WidgetAlertVisualStyle {
    let icon: String
    let tint: Color

    static func style(for alert: WidgetSelectedAlertRowDisplayState) -> WidgetAlertVisualStyle {
        let type = alert.typeLabel.localizedLowercase
        if type.contains("tornado") {
            return WidgetAlertVisualStyle(icon: "tornado", tint: Color(red: 0.80, green: 0.20, blue: 0.40))
        }
        if type.contains("severe") {
            return WidgetAlertVisualStyle(icon: "cloud.bolt.fill", tint: Color(red: 0.38, green: 0.48, blue: 0.92))
        }
        if type.contains("flood") {
            return WidgetAlertVisualStyle(icon: "flood.fill", tint: Color(red: 0.19, green: 0.54, blue: 0.92))
        }
        if type.contains("mesoscale") {
            return WidgetAlertVisualStyle(icon: "waveform.path.ecg.magnifyingglass", tint: Color(red: 0.45, green: 0.35, blue: 0.85))
        }
        if type.contains("watch") {
            return WidgetAlertVisualStyle(icon: "exclamationmark.triangle", tint: Color(red: 0.96, green: 0.78, blue: 0.18))
        }

        // Severity fallback keeps meaning even when type labels vary.
        switch alert.severity {
        case 5...:
            return WidgetAlertVisualStyle(icon: "exclamationmark.triangle.fill", tint: .red)
        case 3...4:
            return WidgetAlertVisualStyle(icon: "exclamationmark.circle.fill", tint: .orange)
        default:
            return WidgetAlertVisualStyle(icon: "info.circle.fill", tint: .yellow)
        }
    }
}
