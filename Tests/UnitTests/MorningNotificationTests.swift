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
    func gateClaimsOnceRetriesFailureAndCommitsSuccess() async {
        let store = InMemoryMorningStore()
        let gate = MorningGate(store: store)
        let event = NotificationEvent(
            kind: .morningOutlook,
            key: "morning:2026-01-02",
            payload: [
                "localDay": "2026-01-02"
            ]
        )
        
        async let firstPass = gate.allow(event, now: .now)
        async let secondPass = gate.allow(event, now: .now)
        let claimCount = await [firstPass, secondPass].filter { $0 }.count

        #expect(claimCount == 1)
        await gate.finish(event, didSchedule: false)
        #expect(await gate.allow(event, now: .now))
        await gate.finish(event, didSchedule: true)
        #expect(await gate.allow(event, now: .now) == false)
        #expect(await MorningGate(store: store).allow(event, now: .now) == false)
    }

    @Test("gate reads the existing morning stamp")
    func gateReadsExistingStamp() async {
        let store = InMemoryMorningStore(stamp: "2026-01-02")
        let gate = MorningGate(store: store)
        let event = NotificationEvent(
            kind: .morningOutlook,
            key: "morning:2026-01-02",
            payload: ["localDay": "2026-01-02"]
        )

        #expect(await gate.allow(event, now: .now) == false)
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
        Severe Activity: Tornadoes are possible
        Fire Risk: No elevated fire weather risk is forecast.
        """)
    }

    @Test("winter-only uses the strongest Overall day and earliest source window on a tie")
    func winterOnlyUsesSelectedSourceWindow() throws {
        let later = winterPeriod(1, impact: .match(.major), startsInHours: 40)
        let earlier = winterPeriod(2, impact: .match(.major), startsInHours: 16)
        let weaker = winterPeriod(3, impact: .match(.moderate), startsInHours: 0)
        let context = winterContext([weaker, later, earlier])
        let event = try #require(AmRangeLocalRule().evaluate(context))
        let winter = try #require(event.payload["winterImpact"] as? MorningContext.WinterImpact)
        #expect(winter.day == 2)
        #expect(winter.severity == .major)
        #expect(winter.sourceInterval.start == winterNow + 16 * 3600)
        #expect(winter.sourceInterval.end == winterNow + 40 * 3600)

        let message = MorningComposer().compose(event)
        #expect(message.title == "Winter Impacts for Bennett, CO")
        #expect(message.subtitle == "NOAA winter outlook")
        var style = Date.IntervalFormatStyle().month(.abbreviated).day().hour().minute()
        style.timeZone = centralTime
        let expectedPeriod = ((winterNow + 16 * 3600)..<(winterNow + 40 * 3600)).formatted(style)
        #expect(message.body == "Major winter impacts are forecast for Day 2 (\(expectedPeriod)).")
    }

    @Test("one accepted winter slot enriches a partial SPC summary")
    func winterEnrichesPartialSPC() throws {
        let overall = winterPeriod(3, impact: .match(.minor), startsInHours: 48)
        let component = winterPeriod(1, product: .iceAccumulation, impact: .match(.extreme), startsInHours: 0)
        let context = winterContext([component, overall], stormRisk: .allClear, convectiveIssue: winterNow - 7200)
        let event = try #require(AmRangeLocalRule().evaluate(context))
        let message = MorningComposer().compose(event)
        let lines = message.body.split(separator: "\n")
        #expect(message.subtitle.isEmpty)
        #expect(lines.count == 2)
        #expect(lines.first == "Storm Activity: \(StormRiskLevel.allClear.summary)")
        #expect(lines.last?.hasPrefix("Minor winter impacts are forecast for Day 3 (") == true)
        #expect(context.winterImpact?.localTimeZone == centralTime)
    }

    @Test("a convective issue time does not label a fire and winter summary")
    func mixedFireAndWinterOmitsConvectiveSubtitle() throws {
        let winter = winterPeriod(2, impact: .match(.moderate), startsInHours: 24)
        let context = winterContext([winter], fireRisk: .clear, convectiveIssue: winterNow - 7200)
        let event = try #require(AmRangeLocalRule().evaluate(context))
        let message = MorningComposer().compose(event)
        #expect(message.subtitle.isEmpty)
        #expect(message.body.hasPrefix("Fire Risk: \(FireRiskLevel.clear.message)\nModerate winter impacts"))
    }

    @Test("winter without qualifying accepted local Overall impact cannot create a morning event")
    func ineligibleWinterAddsNoContent() throws {
        let minor = winterPeriod(1, impact: .match(.minor), startsInHours: 0)
        let outsideLocation = WSSIAcceptedAssessment.Location(
            point: .init(latitude: 40, longitude: -105), h3Cell: 2, observedAt: winterNow
        )
        let cases: [(String, [WSSIAcceptedAssessment.Period], Bool, WSSIAcceptedAssessment.Location)] = [
            ("off", [minor], false, winterLocation),
            ("off location", [minor], true, outsideLocation),
            ("pending", [], true, winterLocation),
            ("expired at end", [winterPeriod(1, impact: .match(.major), startsInHours: -24)], true, winterLocation),
            ("unavailable", [winterPeriod(1, impact: .unavailable, startsInHours: 0)], true, winterLocation),
            ("unknown coverage", [winterPeriod(1, impact: .noMatchUnknownCoverage, startsInHours: 0)], true, winterLocation),
            ("weather area", [winterPeriod(1, impact: .match(.winterWeatherArea), startsInHours: 0)], true, winterLocation),
            ("component only", [winterPeriod(1, product: .snowLoad, impact: .match(.extreme), startsInHours: 0)],
             true, winterLocation)
        ]
        let rule = AmRangeLocalRule()
        for (scenario, periods, enabled, location) in cases {
            #expect(rule.evaluate(winterContext(periods, enabled: enabled, location: location)) == nil,
                    "\(scenario)")
            let partialSPC = winterContext(periods, enabled: enabled, location: location, stormRisk: .slight)
            let event = try #require(rule.evaluate(partialSPC), "\(scenario)")
            #expect(MorningComposer().compose(event).body == "Storm Activity: Chance for a few strong storms",
                    "\(scenario)")
        }
    }

    private var winterNow: Date {
        makeDate(year: 2026, month: 1, day: 2, hour: 8, tz: centralTime)
    }

    private var winterLocation: WSSIAcceptedAssessment.Location {
        .init(point: .init(latitude: 39, longitude: -105), h3Cell: 1, observedAt: winterNow)
    }

    private func winterContext(
        _ periods: [WSSIAcceptedAssessment.Period], enabled: Bool = true,
        location: WSSIAcceptedAssessment.Location? = nil, stormRisk: StormRiskLevel? = nil,
        fireRisk: FireRiskLevel? = nil, convectiveIssue: Date? = nil,
        riskProfileChange: RiskProfileChange? = nil
    ) -> MorningContext {
        .init(
            now: winterNow, lastConvectiveIssue: convectiveIssue, localTZ: centralTime, quietHours: nil,
            stormRisk: stormRisk, severeRisk: nil, fireRisk: fireRisk, placeMark: "Bennett, CO",
            riskProfileChange: riskProfileChange,
            acceptedWinterAssessment: .init(location: winterLocation, periods: periods, refreshStatus: .notAttempted),
            currentWinterLocation: location ?? winterLocation, winterImpactsEnabled: enabled
        )
    }

    private func winterPeriod(
        _ day: Int, product: WSSIProduct = .overallImpact, impact: WSSIPointAssessment.Impact, startsInHours: Double
    ) -> WSSIAcceptedAssessment.Period {
        let start = winterNow + startsInHours * 3600
        let revision = WSSIAcceptedRevision(
            revision: UUID(), issuedAt: winterNow - 3600, validFrom: start, validTo: start + 24 * 3600,
            gisFileDate: nil, gisIngestDate: nil, retrievedAt: winterNow, geometryPath: "/geometry"
        )
        return .init(assessment: .init(
            product: product, day: day, point: winterLocation.point, revision: revision,
            validity: start > winterNow ? .notYetValid : .valid, sourceStatus: .available,
            pollHealth: .successful, impact: impact
        ), coverage: .unknown)
    }

    @Test("missing and synthetic location labels use the generic morning title",
          arguments: [nil, "", " \n\t ", "Unknown", " UNKNOWN ", "Ready", "ready"] as [String?])
    func composerUsesGenericTitle(place: String?) {
        var payload: [String: Sendable] = [:]
        if let place { payload["placeMark"] = place }
        let message = MorningComposer().compose(
            NotificationEvent(kind: .morningOutlook, key: "morning:2026-01-02", payload: payload)
        )
        #expect(message.title == "Today's Outlook")
    }

    @Test("composer trims a valid location name")
    func composerTrimsValidName() {
        let message = MorningComposer().compose(
            NotificationEvent(kind: .morningOutlook, key: "morning:2026-01-02",
                              payload: ["placeMark": " Bennett, CO \n"])
        )
        #expect(message.title == "Today's Outlook for Bennett, CO")
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
        let context = MorningContext(
            now: winterNow, lastConvectiveIssue: nil, localTZ: centralTime, quietHours: nil,
            stormRisk: .enhanced, severeRisk: .tornado(probability: 0.31), fireRisk: .critical,
            placeMark: "Oklahoma City, OK", riskProfileChange: change
        )
        let event = try #require(AmRangeLocalRule().evaluate(context))
        let message = MorningComposer().compose(event)

        #expect(message.body == """
        Risk Update
        Storm Risk: Marginal Risk → Enhanced Risk
        Severe Risk: Wind 12% → Tornado 31%
        Fire Risk: Clear → Critical

        Storm Activity: Several severe storms are possible
        Severe Activity: Tornadoes are possible
        Fire Risk: Dry fuels, strong winds, and very low humidity could allow any fire that starts to spread rapidly.
        """)

        let winter = winterPeriod(1, impact: .match(.moderate), startsInHours: 0)
        let winterOnly = winterContext([winter], riskProfileChange: change)
        let winterEvent = try #require(AmRangeLocalRule().evaluate(winterOnly))
        let sections = MorningComposer().compose(winterEvent).body.components(separatedBy: "\n\n")
        #expect(sections.count == 2)
        #expect(sections.first == message.body.components(separatedBy: "\n\n").first)
        #expect(sections.last?.hasPrefix("Moderate winter impacts are forecast for Day 1 (") == true)
        #expect(sections.last?.contains("\n") == false)
    }

    @Test("engine retries a scheduling failure and suppresses the successful occurrence")
    func engineRetriesSchedulingFailure() async {
        let now = makeDate(year: 2026, month: 1, day: 2, hour: 8, tz: centralTime)
        let sender = SequencedMorningSender(results: [false, true])
        let engine = MorningEngine(
            rule: AmRangeLocalRule(window: 7..<11),
            gate: MorningGate(store: InMemoryMorningStore()),
            composer: MorningComposer(),
            sender: sender
        )
        let context = MorningContext(
            now: now,
            lastConvectiveIssue: now.addingTimeInterval(-7_200),
            localTZ: centralTime,
            quietHours: nil,
            stormRisk: .slight,
            severeRisk: .allClear,
            fireRisk: .clear,
            placeMark: nil
        )

        #expect(await engine.run(ctx: context) == false)
        #expect(await engine.run(ctx: context))
        #expect(await engine.run(ctx: context) == false)
        #expect(await sender.attemptCount() == 2)
    }
}

// MARK: - Test Doubles

actor InMemoryMorningStore: NotificationStateStoring {
    private var stamp: String?

    init(stamp: String? = nil) {
        self.stamp = stamp
    }
    
    func lastStamp() async -> String? { stamp }
    func setLastStamp(_ stamp: String) async { self.stamp = stamp }
}

private actor SequencedMorningSender: NotificationSending {
    private var results: [Bool]
    private var attempts = 0

    init(results: [Bool]) {
        self.results = results
    }

    func send(title: String, body: String, subtitle: String, id: String) async -> Bool {
        attempts += 1
        return results.removeFirst()
    }

    func attemptCount() -> Int { attempts }
}
