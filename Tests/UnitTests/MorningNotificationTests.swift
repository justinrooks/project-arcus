import Testing
@testable import SkyAware
import Foundation

@Suite("Morning Notification")
struct MorningNotificationTests {
    private let centralTime: TimeZone = TimeZone(secondsFromGMT: -6 * 3600)!
    
    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, tz: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let components = DateComponents(calendar: calendar, timeZone: tz, year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }
    
    @Test
    func ruleCreatesEventInWindow() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 8, tz: centralTime)
        let issue = now.addingTimeInterval(-2 * 3600)
        
        let ctx = MorningContext(
            now: now,
            lastConvectiveIssue: issue,
            localTZ: centralTime,
            quietHours: nil,
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.3),
            fireRisk: .clear,
            placeMark: "Oklahoma City, OK"
        )
        
        let rule = AmRangeLocalRule(window: 7..<11)
        let event = rule.evaluate(ctx)
        #expect(event?.kind == NotificationKind.morningOutlook)
        #expect(event?.key == "morning:2026-01-02")
        #expect(event?.payload["localDay"] as? String == "2026-01-02")
        #expect(event?.payload["issue"] as? Date == issue)
        #expect(event?.payload["placeMark"] as? String == "Oklahoma City, OK")
    }
    
    @Test
    func ruleSkipsOutsideWindow() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 13, tz: centralTime)
        
        let ctx = MorningContext(
            now: now,
            lastConvectiveIssue: now.addingTimeInterval(-2 * 3600),
            localTZ: centralTime,
            quietHours: nil,
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.3),
            fireRisk: .clear,
            placeMark: "Oklahoma City, OK"
        )
        
        let rule = AmRangeLocalRule(window: 7..<11)
        let event = rule.evaluate(ctx)
        
        #expect(event == nil)
    }
    
    @Test
    func ruleSkipsStaleIssue() {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 8, tz: centralTime)
        let issue = now.addingTimeInterval(-26 * 3600)
        
        let ctx = MorningContext(
            now: now,
            lastConvectiveIssue: issue,
            localTZ: centralTime,
            quietHours: nil,
            stormRisk: .slight,
            severeRisk: .tornado(probability: 0.3),
            fireRisk: .clear,
            placeMark: "Oklahoma City, OK"
        )
        
        let rule = AmRangeLocalRule(window: 7..<11)
        let event = rule.evaluate(ctx)
        
        #expect(event == nil)
    }
    
    @Test
    func gateBlocksDuplicateEvents() async {
        let gate = MorningGate(store: InMemoryMorningStore())
        let event = NotificationEvent(
            kind: .morningOutlook,
            key: "morning:2026-01-02",
            payload: [
                "localDay": "2026-01-02"
            ]
        )
        
        let firstPass = await gate.allow(event, now: .now)
        let secondPass = await gate.allow(event, now: .now)
        
        #expect(firstPass == true)
        #expect(secondPass == false)
    }

    @Test("composer preserves the normal morning summary without a risk change")
    func composerPreservesNormalMorningSummaryWithoutRiskChange() {
        let message = MorningComposer().compose(
            NotificationEvent(
                kind: .morningOutlook,
                key: "morning:2026-01-02",
                payload: [
                    "stormRisk": StormRiskLevel.slight,
                    "severeRisk": SevereWeatherThreat.tornado(probability: 0.3),
                    "fireRisk": FireRiskLevel.clear,
                    "placeMark": "Oklahoma City, OK"
                ]
            )
        )

        #expect(message.title == "Today's Outlook for Oklahoma City, OK")
        #expect(message.body == """
        Storm Activity: Chance for a few strong storms
        Severe Activity: Tornados are possible
        Fire Risk: No elevated fire weather risk is forecast.
        """)
    }

    @Test("composer adds deterministic risk transitions before the morning outlook")
    func composerAddsRiskTransitionsBeforeMorningOutlook() throws {
        let change = try #require(
            RiskProfileChange(
                previous: .init(
                    stormRisk: .marginal,
                    severeRisk: .wind(probability: 0.12),
                    fireRisk: .clear
                ),
                current: .init(
                    stormRisk: .enhanced,
                    severeRisk: .tornado(probability: 0.31),
                    fireRisk: .critical
                ),
                projectionKey: "projection:okc",
                locationSummary: "Oklahoma City, OK",
                occurrenceID: "morning-transition"
            )
        )
        let message = MorningComposer().compose(
            NotificationEvent(
                kind: .morningOutlook,
                key: "morning:2026-01-02",
                payload: [
                    "stormRisk": StormRiskLevel.enhanced,
                    "severeRisk": SevereWeatherThreat.tornado(probability: 0.31),
                    "fireRisk": FireRiskLevel.critical,
                    "placeMark": "Oklahoma City, OK",
                    "riskProfileChange": change
                ]
            )
        )

        #expect(message.body == """
        Risk Update
        Storm Risk: Marginal Risk → Enhanced Risk
        Severe Risk: Wind 12% → Tornado 31%
        Fire Risk: Clear → Critical

        Storm Activity: Several severe storms are possible
        Severe Activity: Tornados are possible
        Fire Risk: Dry fuels, strong winds, and very low humidity could allow any fire that starts to spread rapidly.
        """)
    }

    @Test("engine reports scheduling failure")
    func engineReportsSchedulingFailure() async {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 8, tz: centralTime)
        let engine = MorningEngine(
            rule: AmRangeLocalRule(window: 7..<11),
            gate: MorningGate(store: InMemoryMorningStore()),
            composer: MorningComposer(),
            sender: FailingMorningSender()
        )
        let context = MorningContext(
            now: now,
            lastConvectiveIssue: now.addingTimeInterval(-7_200),
            localTZ: centralTime,
            quietHours: nil,
            stormRisk: .slight,
            severeRisk: .allClear,
            fireRisk: .clear,
            placeMark: "Oklahoma City, OK"
        )

        #expect(await engine.run(ctx: context) == false)
    }
}

// MARK: - Test Doubles

actor InMemoryMorningStore: NotificationStateStoring {
    private var stamp: String?
    
    func lastStamp() async -> String? { stamp }
    func setLastStamp(_ stamp: String) async { self.stamp = stamp }
}

private struct FailingMorningSender: NotificationSending {
    func send(title: String, body: String, subtitle: String, id: String) async -> Bool { false }
}
