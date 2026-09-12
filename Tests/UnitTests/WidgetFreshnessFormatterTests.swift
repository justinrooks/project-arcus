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
        #expect(line.contains("Delayed update"))
    }

    @Test("silent-aging presentation preserves fresh copy")
    func silentAgingPresentation_preservesFreshCopy() {
        let freshness = WidgetFreshnessState.from(
            timestamp: Date(timeIntervalSince1970: 1_714_572_040),
            now: Date(timeIntervalSince1970: 1_714_572_100)
        )

        let line = WidgetFreshnessFormatter.lineSuppressingStaleState(for: freshness)
        #expect(line?.hasPrefix("As of ") == true)
    }

    @Test("silent-aging presentation suppresses stale copy")
    func silentAgingPresentation_suppressesStaleCopy() {
        let freshness = WidgetFreshnessState.from(
            timestamp: Date(timeIntervalSince1970: 1_714_572_040),
            now: Date(timeIntervalSince1970: 1_714_574_000)
        )

        #expect(WidgetFreshnessFormatter.lineSuppressingStaleState(for: freshness) == nil)
    }

    @Test("unavailable copy remains stable")
    func unavailableCopy_isStable() {
        let freshness = WidgetFreshnessState(timestamp: nil, state: .unavailable)
        let line = WidgetFreshnessFormatter.line(for: freshness)
        #expect(line == "unavailable")
        #expect(WidgetFreshnessFormatter.lineSuppressingStaleState(for: freshness) == "unavailable")
    }
}
