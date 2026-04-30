import Foundation
import Testing
@testable import SkyAware

@Suite("SevereWeatherThreat")
struct SevereWeatherThreatTests {
    @Test("probability returns 0 for allClear and preserves stored value for others")
    func probability_returnsExpectedValues() {
        #expect(SevereWeatherThreat.allClear.probability == 0.0)
        #expect(SevereWeatherThreat.wind(probability: 0.2).probability == 0.2)
        #expect(SevereWeatherThreat.hail(probability: 0.35).probability == 0.35)
        #expect(SevereWeatherThreat.tornado(probability: 0.7).probability == 0.7)
    }

    @Test("priority ordering matches tornado > hail > wind > allClear")
    func priority_ordering() {
        #expect(SevereWeatherThreat.tornado(probability: 0.1).priority == 3)
        #expect(SevereWeatherThreat.hail(probability: 0.1).priority == 2)
        #expect(SevereWeatherThreat.wind(probability: 0.1).priority == 1)
        #expect(SevereWeatherThreat.allClear.priority == 0)
    }

    @Test("Comparable uses priority for sorting")
    func comparable_sorting() {
        let items: [SevereWeatherThreat] = [
            .wind(probability: 0.3),
            .tornado(probability: 0.1),
            .allClear,
            .hail(probability: 0.2)
        ]
        let sorted = items.sorted()
        #expect(sorted.first == .allClear)
        #expect(sorted.last == .tornado(probability: 0.1))
    }

    @Test("message and summary strings are correct")
    func message_and_summary() {
        #expect(SevereWeatherThreat.allClear.message == "No Active Threats")
        #expect(SevereWeatherThreat.wind(probability: 0.1).message == "Wind")
        #expect(SevereWeatherThreat.hail(probability: 0.1).message == "Hail")
        #expect(SevereWeatherThreat.tornado(probability: 0.1).message == "Tornado")

        #expect(SevereWeatherThreat.allClear.summary == "No severe threats expected")
        #expect(SevereWeatherThreat.wind(probability: 0.1).summary == "Damaging wind possible")
        #expect(SevereWeatherThreat.hail(probability: 0.1).summary == "1 in or larger hail possible")
        #expect(SevereWeatherThreat.tornado(probability: 0.1).summary == "Tornados are possible")
    }

    @Test("dynamicSummary formats percentages and is empty for allClear")
    func dynamicSummary_formatsPercent() {
        #expect(SevereWeatherThreat.allClear.dynamicSummary.isEmpty)
        #expect(SevereWeatherThreat.tornado(probability: 0.32).dynamicSummary == "32% chance of tornadoes")
        #expect(SevereWeatherThreat.hail(probability: 0.05).dynamicSummary == "5% chance of large hail")
        #expect(SevereWeatherThreat.wind(probability: 0.2).dynamicSummary == "20% chance of damaging winds")
    }

    @Test("with(probability:) preserves threat type")
    func with_preservesType() {
        #expect(SevereWeatherThreat.allClear.with(probability: 0.5) == .allClear)
        #expect(SevereWeatherThreat.wind(probability: 0.1).with(probability: 0.9) == .wind(probability: 0.9))
        #expect(SevereWeatherThreat.hail(probability: 0.1).with(probability: 0.9) == .hail(probability: 0.9))
        #expect(SevereWeatherThreat.tornado(probability: 0.1).with(probability: 0.9) == .tornado(probability: 0.9))
    }
}

@Suite("LocationReliability")
struct LocationReliabilityTests {
    @Test("elevated-risk helper includes slight")
    func elevatedRisk_includesSlight() {
        #expect(LocationReliabilitySummaryRailEligibility.isElevatedRisk(stormRisk: .slight, severeRisk: nil))
    }

    @Test("elevated-risk helper includes hail and tornado severe threats")
    func elevatedRisk_includesHailAndTornado() {
        #expect(LocationReliabilitySummaryRailEligibility.isElevatedRisk(stormRisk: .allClear, severeRisk: .hail(probability: 0.10)))
        #expect(LocationReliabilitySummaryRailEligibility.isElevatedRisk(stormRisk: .allClear, severeRisk: .tornado(probability: 0.10)))
    }

    @Test("quiet day does not consume asks")
    func quietDay_doesNotConsumeAsk() {
        let suite = "LocationReliabilityTests-quiet-day-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        let ledger = LocationReliabilityAskLedger(userDefaults: store)
        defer { store.removePersistentDomain(forName: suite) }

        #expect(ledger.snapshot().askCount == 0)

        let reliability = LocationReliabilityState(authorization: .whileUsing, accuracy: .precise)
        let decision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: .allClear,
            severeRisk: .allClear,
            ledger: ledger.snapshot(),
            now: iso("2026-04-29T18:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        #expect(decision.isEligible == false)
        #expect(decision.reason == .notElevatedRisk)
        #expect(ledger.snapshot().askCount == 0)
    }

    @Test("ask count increments on counted rail impression and caps at three")
    func askCount_incrementsAndCaps() {
        let suite = "LocationReliabilityTests-cap-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        let ledger = LocationReliabilityAskLedger(userDefaults: store)
        defer { store.removePersistentDomain(forName: suite) }

        ledger.recordCountedRailImpression(at: iso("2026-04-20T12:00:00Z"), qualifyingDay: "2026-04-20")
        ledger.recordCountedRailImpression(at: iso("2026-04-21T12:00:00Z"), qualifyingDay: "2026-04-21")
        ledger.recordCountedRailImpression(at: iso("2026-04-22T12:00:00Z"), qualifyingDay: "2026-04-22")
        ledger.recordCountedRailImpression(at: iso("2026-04-23T12:00:00Z"), qualifyingDay: "2026-04-23")

        let snapshot = ledger.snapshot()
        #expect(snapshot.askCount == 3)
        #expect(snapshot.hasExhaustedCap)
        #expect(snapshot.lastCountedQualifyingDay == "2026-04-23")
    }

    @Test("eligibility fails when cap is exhausted")
    func eligibility_failsWhenCapExhausted() {
        let reliability = LocationReliabilityState(authorization: .whileUsing, accuracy: .precise)
        let snapshot = LocationReliabilityAskLedgerSnapshot(
            askCount: 3,
            maxAsks: 3,
            lastCountedRailImpressionAt: nil,
            lastCountedQualifyingDay: nil,
            lastSuppressedQualifyingDay: nil
        )

        let decision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: .slight,
            severeRisk: .allClear,
            ledger: snapshot,
            now: iso("2026-04-29T12:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        #expect(decision.isEligible == false)
        #expect(decision.reason == .askCapExhausted)
    }

    @Test("eligibility fails for non-while-using authorization")
    func eligibility_failsForNonWhileUsing() {
        let reliability = LocationReliabilityState(authorization: .always, accuracy: .precise)
        let snapshot = LocationReliabilityAskLedgerSnapshot(
            askCount: 0,
            maxAsks: 3,
            lastCountedRailImpressionAt: nil,
            lastCountedQualifyingDay: nil,
            lastSuppressedQualifyingDay: nil
        )

        let decision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: .moderate,
            severeRisk: .tornado(probability: 0.10),
            ledger: snapshot,
            now: iso("2026-04-29T12:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        #expect(decision.isEligible == false)
        #expect(decision.reason == .authorizationNotWhileUsing)
    }

    @Test("reduced-accuracy alone does not trigger rail eligibility")
    func reducedAccuracyAlone_doesNotTriggerRail() {
        let reliability = LocationReliabilityState(authorization: .whileUsing, accuracy: .reduced)
        let snapshot = LocationReliabilityAskLedgerSnapshot(
            askCount: 0,
            maxAsks: 3,
            lastCountedRailImpressionAt: nil,
            lastCountedQualifyingDay: nil,
            lastSuppressedQualifyingDay: nil
        )

        let decision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: .allClear,
            severeRisk: .wind(probability: 0.10),
            ledger: snapshot,
            now: iso("2026-04-29T12:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        #expect(decision.isEligible == false)
        #expect(decision.reason == .notElevatedRisk)
    }

    @Test("same-day suppression blocks repeat ask")
    func sameDaySuppression_blocksEligibility() {
        let reliability = LocationReliabilityState(authorization: .whileUsing, accuracy: .precise)
        let snapshot = LocationReliabilityAskLedgerSnapshot(
            askCount: 1,
            maxAsks: 3,
            lastCountedRailImpressionAt: iso("2026-04-29T01:00:00Z"),
            lastCountedQualifyingDay: "2026-04-29",
            lastSuppressedQualifyingDay: "2026-04-29"
        )

        let decision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: .moderate,
            severeRisk: .allClear,
            ledger: snapshot,
            now: iso("2026-04-29T20:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        #expect(decision.isEligible == false)
        #expect(decision.reason == .sameDaySuppressed)
    }

    @Test("next qualifying day and 24-hour minimum both required")
    func nextQualifyingDay_requiresLaterDayAnd24Hours() {
        let reliability = LocationReliabilityState(authorization: .whileUsing, accuracy: .precise)
        let ledger = LocationReliabilityAskLedgerSnapshot(
            askCount: 1,
            maxAsks: 3,
            lastCountedRailImpressionAt: iso("2026-04-29T12:00:00Z"),
            lastCountedQualifyingDay: "2026-04-29",
            lastSuppressedQualifyingDay: nil
        )

        let sameDayDecision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: .slight,
            severeRisk: .allClear,
            ledger: ledger,
            now: iso("2026-04-29T23:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        #expect(sameDayDecision.isEligible == false)
        #expect(sameDayDecision.reason == .waitingForNextQualifyingDay)

        let nextDayTooSoon = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: .slight,
            severeRisk: .allClear,
            ledger: ledger,
            now: iso("2026-04-30T10:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        #expect(nextDayTooSoon.isEligible == false)
        #expect(nextDayTooSoon.reason == .waitingForMinimumInterval)

        let eligible = LocationReliabilitySummaryRailEligibility.decision(
            reliability: reliability,
            stormRisk: .slight,
            severeRisk: .allClear,
            ledger: ledger,
            now: iso("2026-04-30T12:30:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        #expect(eligible.isEligible)
        #expect(eligible.reason == .eligible)
    }

    @Test("not-now suppression blocks same-day repeat without refunding ask")
    func notNowSuppression_blocksSameDayRepeatWithoutRefund() {
        let suite = "LocationReliabilityTests-not-now-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suite)!
        let ledger = LocationReliabilityAskLedger(userDefaults: store)
        defer { store.removePersistentDomain(forName: suite) }

        ledger.recordCountedRailImpression(at: iso("2026-04-29T12:00:00Z"), qualifyingDay: "2026-04-29")
        #expect(ledger.snapshot().askCount == 1)

        ledger.recordSameDaySuppression(qualifyingDay: "2026-04-29")
        let decision = LocationReliabilitySummaryRailEligibility.decision(
            reliability: .init(authorization: .whileUsing, accuracy: .precise),
            stormRisk: .slight,
            severeRisk: .allClear,
            ledger: ledger.snapshot(),
            now: iso("2026-04-29T16:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        #expect(decision.isEligible == false)
        #expect(decision.reason == .sameDaySuppressed)
        #expect(ledger.snapshot().askCount == 1)
    }

    @Test("home-view rail state records impression intent on first qualifying display")
    @MainActor
    func homeViewRailState_recordsImpressionOnFirstDisplay() {
        let state = HomeView.locationReliabilityRailState(
            reliability: .init(authorization: .whileUsing, accuracy: .precise),
            stormRisk: .slight,
            severeRisk: .allClear,
            ledger: .init(
                askCount: 0,
                maxAsks: 3,
                lastCountedRailImpressionAt: nil,
                lastCountedQualifyingDay: nil,
                lastSuppressedQualifyingDay: nil
            ),
            now: iso("2026-04-29T12:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            currentlyShownQualifyingDay: nil
        )

        #expect(state.shouldShowRail)
        #expect(state.qualifyingDay == "2026-04-29")
        #expect(state.shouldRecordImpression)
    }

    @Test("home-view rail state does not double-record in same qualifying day")
    @MainActor
    func homeViewRailState_noDoubleRecordSameDay() {
        let state = HomeView.locationReliabilityRailState(
            reliability: .init(authorization: .whileUsing, accuracy: .precise),
            stormRisk: .slight,
            severeRisk: .allClear,
            ledger: .init(
                askCount: 0,
                maxAsks: 3,
                lastCountedRailImpressionAt: nil,
                lastCountedQualifyingDay: nil,
                lastSuppressedQualifyingDay: nil
            ),
            now: iso("2026-04-29T18:00:00Z"),
            timeZone: TimeZone(secondsFromGMT: 0)!,
            currentlyShownQualifyingDay: "2026-04-29"
        )

        #expect(state.shouldShowRail)
        #expect(state.shouldRecordImpression == false)
    }

    private func iso(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
