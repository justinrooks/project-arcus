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

    @Test("preferred delivery never falls back to another pending occurrence")
    func preferredDeliveryDoesNotDrainAnotherOccurrence() async {
        let sender = RecordingSender()
        let engine = makeEngine(sender: sender)

        #expect(await engine.run(change: makeChange(projectionKey: "projection:alpha", occurrenceID: "x"), isEnabled: false) == false)
        #expect(await engine.run(change: makeChange(projectionKey: "projection:alpha", occurrenceID: "y")))
        #expect(await engine.run(change: makeChange(projectionKey: "projection:alpha", occurrenceID: "y")) == false)
        #expect((await sender.sent()) == ["risk:projection:alpha:y"])
    }

    @Test("newer disabled occurrence supersedes older occurrence for one projection")
    func newerPendingOccurrenceSupersedesOlderOccurrence() async {
        let sender = RecordingSender()
        let engine = makeEngine(sender: sender)

        _ = await engine.run(change: makeChange(occurrenceID: "old"), isEnabled: false)
        _ = await engine.run(change: makeChange(occurrenceID: "new"), isEnabled: false)
        #expect(await engine.run(change: nil))
        #expect((await sender.sent()) == ["risk:projection:alpha:new"])
    }

    @Test("pending projections drain in registration order")
    func pendingProjectionsDrainInRegistrationOrder() async {
        let sender = RecordingSender()
        let engine = makeEngine(sender: sender)

        _ = await engine.run(change: makeChange(projectionKey: "projection:bravo", occurrenceID: "bravo"), isEnabled: false)
        _ = await engine.run(change: makeChange(projectionKey: "projection:alpha", occurrenceID: "alpha"), isEnabled: false)
        #expect(await engine.run(change: nil))
        #expect(await engine.run(change: nil))
        #expect((await sender.sent()) == ["risk:projection:bravo:bravo", "risk:projection:alpha:alpha"])
    }

    @Test("failed in-flight occurrence does not replace newer pending occurrence")
    func failedInFlightOccurrenceDoesNotReplaceNewerPendingOccurrence() async throws {
        let gate = RiskChangeGate(store: InMemoryRiskChangeStore())
        let old = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(occurrenceID: "old"))))
        let new = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(occurrenceID: "new"))))
        let message = RiskChangeComposer().compose(old)
        await gate.register(event: old, message: message)
        let delivery = await gate.claim(preferredEventKey: old.key, isEnabled: true)
        await gate.register(event: new, message: RiskChangeComposer().compose(new))
        if let delivery { await gate.finish(delivery, didSchedule: false) }

        #expect((await gate.claim(preferredEventKey: nil, isEnabled: true)?.eventKey) == new.key)
    }

    @Test("expired pending occurrence is removed without delivery")
    func expiredPendingOccurrenceIsRemovedWithoutDelivery() async throws {
        let gate = RiskChangeGate(store: InMemoryRiskChangeStore())
        let event = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(occurrenceID: "expired"))))
        let old = Date(timeIntervalSince1970: 1_000)
        await gate.register(event: event, message: RiskChangeComposer().compose(event), now: old)

        #expect(await gate.claim(preferredEventKey: nil, isEnabled: true, now: old.addingTimeInterval(24 * 60 * 60 + 1)) == nil)
    }

    @Test("recreated gate restores pending state")
    func recreatedGateRestoresPendingState() async throws {
        let store = InMemoryRiskChangeStore()
        let event = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(occurrenceID: "restored"))))
        let firstGate = RiskChangeGate(store: store)
        await firstGate.register(event: event, message: RiskChangeComposer().compose(event), now: Date(timeIntervalSince1970: 1_000))

        let secondGate = RiskChangeGate(store: store)
        #expect((await secondGate.claim(preferredEventKey: nil, isEnabled: true)?.eventKey) == event.key)
    }

    @Test("delivered tombstones cap at 128 while recent duplicates stay suppressed")
    func deliveredTombstonesAreCapped() async throws {
        let gate = RiskChangeGate(store: InMemoryRiskChangeStore())
        let base = Date(timeIntervalSince1970: 2_000)
        for index in 0..<129 {
            let event = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(occurrenceID: String(index)))))
            await gate.register(event: event, message: RiskChangeComposer().compose(event), now: base.addingTimeInterval(Double(index)))
            let delivery = await gate.claim(preferredEventKey: event.key, isEnabled: true)
            if let delivery { await gate.finish(delivery, didSchedule: true, now: base.addingTimeInterval(Double(index))) }
        }

        let oldest = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(occurrenceID: "0"))))
        let recent = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(occurrenceID: "128"))))
        await gate.register(event: oldest, message: RiskChangeComposer().compose(oldest), now: base.addingTimeInterval(130))
        #expect(await gate.claim(preferredEventKey: oldest.key, isEnabled: true) != nil)
        await gate.register(event: recent, message: RiskChangeComposer().compose(recent), now: base.addingTimeInterval(130))
        #expect(await gate.claim(preferredEventKey: recent.key, isEnabled: true) == nil)
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
