import Testing
import SwiftUI
import UIKit
@testable import SkyAware

@Suite("Alert styling")
struct AlertStylingTests {
    @Test("Uses tornado styling for tornado warnings")
    func stylesTornadoWarning() {
        let style = styleForType(.watch, "Tornado Warning")

        #expect(style.0 == "tornado")
    }

    @Test("Uses severe thunderstorm styling for severe thunderstorm warnings")
    func stylesSevereThunderstormWarning() {
        let style = styleForType(.watch, "Severe Thunderstorm Warning")

        #expect(style.0 == "cloud.bolt.fill")
    }

    @Test("Uses flood styling for flash flood warnings")
    func stylesFlashFloodWarning() {
        let style = styleForType(.watch, "Flash Flood Warning")

        #expect(style.0 == "flood.fill")
    }

    @Test("Warning polygon styling uses tornado red")
    func warningPolygonStyle_usesTornadoRed() {
        let style = warningPolygonStyle(for: "Tornado Warning")
        let expected = rgba(.tornadoRed)

        #expect(style != nil)
        guard let style else { return }

        #expect(rgba(style.stroke) == expected)
        #expect(rgba(style.fill).red == expected.red)
        #expect(rgba(style.fill).green == expected.green)
        #expect(rgba(style.fill).blue == expected.blue)
        #expect(abs(rgba(style.fill).alpha - 0.22) < 0.001)
    }

    @Test("Warning polygon styling uses yellow for severe thunderstorm warnings")
    func warningPolygonStyle_usesYellowForSevereThunderstormWarning() {
        let style = warningPolygonStyle(for: "Severe Thunderstorm Warning")
        let expected = rgba(.warningYellow)

        #expect(style != nil)
        guard let style else { return }

        #expect(rgba(style.stroke) == expected)
        #expect(rgba(style.fill).red == expected.red)
        #expect(rgba(style.fill).green == expected.green)
        #expect(rgba(style.fill).blue == expected.blue)
        #expect(abs(rgba(style.fill).alpha - 0.22) < 0.001)
    }

    @Test("Warning polygon styling uses blue for flash flood warnings")
    func warningPolygonStyle_usesBlueForFlashFloodWarning() {
        let style = warningPolygonStyle(for: "Flash Flood Warning")
        let expected = rgba(.floodBlue)

        #expect(style != nil)
        guard let style else { return }

        #expect(rgba(style.stroke) == expected)
        #expect(rgba(style.fill).red == expected.red)
        #expect(rgba(style.fill).green == expected.green)
        #expect(rgba(style.fill).blue == expected.blue)
        #expect(abs(rgba(style.fill).alpha - 0.22) < 0.001)
    }

    @Test("Warning polygon styling ignores unsupported warning titles")
    func warningPolygonStyle_ignoresUnsupportedWarnings() {
        #expect(warningPolygonStyle(for: "Tornado Watch") == nil)
    }

    @Test("Watch status chips share the neutral metadata tint")
    func watchStatusChipsShareTheNeutralMetadataTint() {
        let lightSeverity = rgba(WatchChipKind.severity("Severe").tint(for: .light), scheme: .light)
        let lightCertainty = rgba(WatchChipKind.certainty("Likely").tint(for: .light), scheme: .light)
        let lightUrgency = rgba(WatchChipKind.urgency("Immediate").tint(for: .light), scheme: .light)

        #expect(lightSeverity == lightCertainty)
        #expect(lightCertainty == lightUrgency)

        let darkSeverity = rgba(WatchChipKind.severity("Severe").tint(for: .dark), scheme: .dark)
        let darkCertainty = rgba(WatchChipKind.certainty("Likely").tint(for: .dark), scheme: .dark)
        let darkUrgency = rgba(WatchChipKind.urgency("Immediate").tint(for: .dark), scheme: .dark)

        #expect(darkSeverity == darkCertainty)
        #expect(darkCertainty == darkUrgency)
    }

    private func rgba(_ color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }

    private func rgba(_ color: Color, scheme: ColorScheme) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        let resolved = UIColor(color)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
}
