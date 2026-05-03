import Foundation
import Testing
@testable import SkyAware

@Suite("Widget freshness formatter")
struct WidgetFreshnessFormatterTests {
    @Test("fresh copy uses concise as-of prefix")
    func freshCopy_usesAsOfPrefix() {
        let freshness = WidgetFreshnessState.from(
            timestamp: Date(timeIntervalSince1970: 1_714_572_040),
            now: Date(timeIntervalSince1970: 1_714_572_100)
        )

        let line = WidgetFreshnessFormatter.line(for: freshness)
        #expect(line.hasPrefix("As of "))
    }

    @Test("stale copy marks staleness explicitly")
    func staleCopy_marksStaleness() {
        let freshness = WidgetFreshnessState.from(
            timestamp: Date(timeIntervalSince1970: 1_714_572_040),
            now: Date(timeIntervalSince1970: 1_714_574_000)
        )

        let line = WidgetFreshnessFormatter.line(for: freshness)
        #expect(line.hasPrefix("As of "))
        #expect(line.hasSuffix("may be stale"))
    }

    @Test("unavailable copy remains stable")
    func unavailableCopy_isStable() {
        let line = WidgetFreshnessFormatter.line(for: WidgetFreshnessState(timestamp: nil, state: .unavailable))
        #expect(line == "As of now: unavailable")
    }
}
