import Testing
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
}
