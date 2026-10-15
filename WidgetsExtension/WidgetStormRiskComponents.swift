import SwiftUI
import WidgetKit

struct WidgetStormRiskSmallView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if case let .unavailable(message) = snapshot.availability {
                WidgetSmallRiskAwareness(
                    title: "Storm Risk",
                    state: snapshot.stormRisk,
                    kind: .storm,
                    supportingSummary: message,
                    isUnavailable: true
                )
            } else {
                WidgetSmallRiskAwareness(
                    title: "Storm Risk",
                    state: snapshot.stormRisk,
                    kind: .storm,
                    supportingSummary: snapshot.stormRisk.stormSupportingSummary
                )
            }
        }
        .containerBackground(for: .widget) {
            WidgetSurfaceStyle.baseColor(isDark: colorScheme == .dark)
        }
    }
}
