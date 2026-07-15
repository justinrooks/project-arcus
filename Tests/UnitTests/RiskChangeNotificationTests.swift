#if canImport(Testing)
import Foundation
import Testing
@testable import SkyAware

@Suite("Risk Change Notification")
struct RiskChangeNotificationTests {
    @Test("engine skips nil input without pending delivery")
    func engineSkipsNilInputWithoutPendingDelivery() async {
        let sender = RecordingSender()
        let engine = makeEngine(sender: sender)

        #expect(await engine.run(change: nil) == false)
        #expect(await sender.sent().isEmpty)
    }

    @Test("rule creates an occurrence-aware event")
    func ruleCreatesOccurrenceAwareEvent() throws {
        let change = makeChange(occurrenceID: "accepted-transition-1")
        let event = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: change)))

        #expect(event.kind == .riskProfileChange)
        #expect(event.key == "risk:projection:alpha:accepted-transition-1")
        #expect(event.payload["change"] as? RiskProfileChange == change)
    }

    @Test("composer batches storm, severe, and fire transitions in deterministic order")
    func composerBatchesRiskTransitionsInDeterministicOrder() throws {
        let change = makeChange(
            previous: makeProfile(storm: .marginal, severe: .wind(probability: 0.12), fire: .clear),
            current: makeProfile(storm: .enhanced, severe: .tornado(probability: 0.31), fire: .critical),
            locationSummary: "Bennett, CO"
        )
        let event = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: change)))
        let message = RiskChangeComposer().compose(event)

        #expect(message.title == "Your Risk Profile Changed")
        #expect(message.subtitle == "Updated for Bennett, CO")
        #expect(message.body == """
        Storm Risk: Marginal Risk → Enhanced Risk
        Severe Risk: Wind 12% → Tornado 31%
        Fire Risk: Clear → Critical
        """)
    }

    @Test("disabled occurrence survives unchanged refresh after enablement")
    func disabledOccurrenceSurvivesUnchangedRefreshAfterEnablement() async {
        let sender = RecordingSender()
        let store = InMemoryRiskChangeStore()
        let engine = makeEngine(sender: sender, store: store)

        #expect(await engine.run(change: makeChange(), isEnabled: false) == false)
        #expect(await engine.run(change: nil, isEnabled: true))
        #expect((await sender.sent()).count == 1)
    }

    @Test("failed scheduling retains occurrence and reports false until retry succeeds")
    func failedSchedulingRetainsOccurrenceUntilRetrySucceeds() async {
        let sender = OutcomeSender(outcomes: [false, true])
        let engine = makeEngine(sender: sender)
        let change = makeChange()

        #expect(await engine.run(change: change) == false)
        #expect(await engine.run(change: nil))
        #expect(await sender.attemptCount() == 2)
    }

    @Test("a later identical transition has a distinct accepted occurrence")
    func laterIdenticalTransitionHasDistinctAcceptedOccurrence() async {
        let sender = RecordingSender()
        let engine = makeEngine(sender: sender)
        let a = makeProfile(storm: .marginal, severe: .allClear, fire: .clear)
        let b = makeProfile(storm: .enhanced, severe: .allClear, fire: .clear)

        #expect(await engine.run(change: makeChange(previous: a, current: b, occurrenceID: "background-a-to-b-1")))
        // The foreground B → A update advances persistence but deliberately never reaches this delivery engine.
        #expect(await engine.run(change: makeChange(previous: a, current: b, occurrenceID: "background-a-to-b-2")))
        #expect((await sender.sent()).count == 2)
    }

    @Test("simultaneous consumers claim one occurrence once")
    func simultaneousConsumersClaimOneOccurrenceOnce() async {
        let sender = SlowRecordingSender()
        let engine = makeEngine(sender: sender)
        let change = makeChange()

        async let first = engine.run(change: change)
        async let second = engine.run(change: change)
        let results = await [first, second]

        #expect(results.filter { $0 }.count == 1)
        #expect((await sender.sent()).count == 1)
    }

    @Test("concurrent projection occurrences preserve both pending entries")
    func concurrentProjectionOccurrencesPreserveBothPendingEntries() async {
        let sender = RecordingSender()
        let engine = makeEngine(sender: sender)
        let alpha = makeChange(projectionKey: "projection:alpha", occurrenceID: "alpha")
        let bravo = makeChange(projectionKey: "projection:bravo", occurrenceID: "bravo")

        async let first = engine.run(change: alpha, isEnabled: false)
        async let second = engine.run(change: bravo, isEnabled: false)
        _ = await [first, second]

        #expect(await engine.run(change: nil, isEnabled: true))
        #expect(await engine.run(change: nil, isEnabled: true))
        #expect((await sender.sent()).count == 2)
    }
}

private func makeEngine<Sender: NotificationSending>(
    sender: Sender,
    store: any NotificationStateStoring = InMemoryRiskChangeStore()
) -> RiskChangeEngine {
    RiskChangeEngine(
        rule: RiskChangeRule(),
        gate: RiskChangeGate(store: store),
        composer: RiskChangeComposer(),
        sender: sender
    )
}

private func makeChange(
    projectionKey: String = "projection:alpha",
    previous: RiskProfile = makeProfile(storm: .marginal, severe: .allClear, fire: .clear),
    current: RiskProfile = makeProfile(storm: .enhanced, severe: .allClear, fire: .clear),
    locationSummary: String? = "Bennett, CO",
    occurrenceID: String = UUID().uuidString
) -> RiskProfileChange {
    RiskProfileChange(
        previous: previous,
        current: current,
        projectionKey: projectionKey,
        locationSummary: locationSummary,
        occurrenceID: occurrenceID
    )!
}

private func makeProfile(storm: StormRiskLevel, severe: SevereWeatherThreat, fire: FireRiskLevel) -> RiskProfile {
    RiskProfile(stormRisk: storm, severeRisk: severe, fireRisk: fire)
}

private actor InMemoryRiskChangeStore: NotificationStateStoring {
    private var stamp: String?

    func lastStamp() async -> String? { stamp }
    func setLastStamp(_ stamp: String) async { self.stamp = stamp }
}

private actor RecordingSender: NotificationSending {
    private var notifications: [String] = []

    func send(title: String, body: String, subtitle: String, id: String) async -> Bool {
        notifications.append(id)
        return true
    }

    func sent() -> [String] { notifications }
}

private actor OutcomeSender: NotificationSending {
    private var outcomes: [Bool]
    private var attempts = 0

    init(outcomes: [Bool]) { self.outcomes = outcomes }

    func send(title: String, body: String, subtitle: String, id: String) async -> Bool {
        attempts += 1
        return outcomes.removeFirst()
    }

    func attemptCount() -> Int { attempts }
}

private actor SlowRecordingSender: NotificationSending {
    private var notifications: [String] = []

    func send(title: String, body: String, subtitle: String, id: String) async -> Bool {
        notifications.append(id)
        try? await Task.sleep(for: .milliseconds(50))
        return true
    }

    func sent() -> [String] { notifications }
}
#endif
