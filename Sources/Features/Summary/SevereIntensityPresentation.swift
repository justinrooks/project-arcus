import Foundation
import SwiftUI

/// An intensity modifier, never an occurrence probability or a replacement for an official alert.
struct SevereIntensityPresentation: Equatable, Sendable {
    let hazard: ThreatType
    let level: Int

    init?(hazard: ThreatType, level: Int) {
        guard hazard != .unknown, (1...3).contains(level), !(hazard == .hail && level == 3) else { return nil }
        self.hazard = hazard
        self.level = level
    }

    var title: String {

        switch (hazard, level) {
        case (.tornado, 1): "Strong tornadoes possible"
        case (.tornado, 2): "More intense tornadoes possible"
        case (.tornado, _): "Highest tornado intensity potential"

        case (.wind, 1): "Destructive gusts possible"
        case (.wind, 2): "More intense wind damage possible"
        case (.wind, _): "Highest wind intensity potential"

        case (.hail, 1): "Very large hail possible"
        case (.hail, _): "Giant hail possible"

        case (.unknown, _): ""
        }
    }

    // Based on SPC's 2026 conditional-intensity guidance, linked in the North Star spec.
    // These describe potential intensity if the hazard occurs; they do not increase
    // the underlying probability and are neither guaranteed outcomes nor maximum limits.
    var detail: String {

        switch (hazard, level) {
        case (.tornado, 1):
            "If tornadoes form, the environment favors a greater potential for strong tornadoes."

        case (.tornado, 2):
            "If tornadoes form, the potential for stronger, more damaging tornadoes is higher."

        case (.tornado, _):
            "If tornadoes form, the environment supports the highest tornado intensity potential."

        case (.wind, 1):
            "If damaging winds occur, some gusts could be especially strong."

        case (.wind, 2):
            "If damaging winds occur, the environment favors stronger wind gusts."

        case (.wind, _):
            "If damaging winds occur, the environment supports the highest wind intensity potential."

        case (.hail, 1):
            "If severe hail occurs, the environment favors larger hailstones."

        case (.hail, _):
            "If severe hail occurs, the environment supports the highest hail intensity potential."

        case (.unknown, _):
            ""
        }
    }

    func matches(_ threat: SevereWeatherThreat?) -> Bool {
        switch threat {
        case .tornado: hazard == .tornado
        case .wind: hazard == .wind
        case .hail: hazard == .hail
        case .allClear, nil: false
        }
    }

    func displayed(for threat: SevereWeatherThreat?, contentState: TodayContentState) -> Self? {
        guard matches(threat), contentState != .unavailable, !contentState.showsResolvingSurface else { return nil }
        return self
    }

    static func levels(for layer: MapLayer) -> [Self] {
        let hazard: ThreatType = switch layer {
        case .tornado: .tornado
        case .hail: .hail
        case .wind: .wind
        default: .unknown
        }
        return (1...3).compactMap { Self(hazard: hazard, level: $0) }
    }
}

extension EnvironmentValues {
    @Entry var severeIntensity: SevereIntensityPresentation? = nil
}

/// Uses the map's screen-space geometry; text always carries the meaning independently of texture.
struct SevereIntensityTexture: View {
    let level: Int

    var body: some View {
        Canvas { context, size in
            let style = HatchStyle.default.adjusted(forIntensityLevel: level)
            let extent = max(size.width, size.height) * 2
            context.opacity = style.opacity * 0.45
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: .degrees(style.angleDegrees))
            for y in stride(from: -extent + style.lineOffset, through: extent, by: style.spacing) {
                var path = Path()
                path.move(to: CGPoint(x: -extent, y: y))
                path.addLine(to: CGPoint(x: extent, y: y))
                context.stroke(path, with: .color(.primary), style: StrokeStyle(
                    lineWidth: style.lineWidth, lineCap: .round, dash: style.dashPattern.map { CGFloat($0) }
                ))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
