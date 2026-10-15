import SwiftUI
import WidgetKit

struct WidgetSevereRiskSmallView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if case let .unavailable(message) = snapshot.availability {
                WidgetSmallRiskAwareness(
                    title: "Severe Risk",
                    state: snapshot.severeRisk,
                    kind: .severe,
                    supportingSummary: message,
                    isUnavailable: true
                )
            } else {
                WidgetSmallRiskAwareness(
                    title: "Severe Risk",
                    state: snapshot.severeRisk,
                    kind: .severe,
                    supportingSummary: snapshot.severeRisk.severeSupportingSummary
                )
            }
        }
        .containerBackground(for: .widget) {
            WidgetSurfaceStyle.baseColor(isDark: colorScheme == .dark)
        }
    }
}
