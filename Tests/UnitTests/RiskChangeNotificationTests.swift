#if canImport(Testing)
import Foundation
import Testing
@testable import SkyAware

@Suite("Risk Change Notification")
struct RiskChangeNotificationTests {
    @Test("engine skips nil input without sending")
    func engineSkipsNilInputWithoutSending() async {
        let sender = RecordingSender()
        let engine = RiskChangeEngine(
            rule: RiskChangeRule(),
            gate: RiskChangeGate(store: InMemoryRiskChangeStore()),
            composer: RiskChangeComposer(),
            sender: sender
        )

        let didSend = await engine.run(change: nil)

        #expect(didSend == false)
        #expect(await sender.sent().isEmpty)
    }

    @Test("rule creates a deterministic event for a single changed dimension")
    func ruleCreatesEventForSingleChangedDimension() throws {
        let change = makeChange(
            projectionKey: "projection:alpha",
            previous: makeProfile(storm: .marginal, severe: .allClear, fire: .clear),
            current: makeProfile(storm: .marginal, severe: .allClear, fire: .critical),
            locationSummary: "Oklahoma City, OK"
        )

        let event = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: change)))

        #expect(event.kind == .riskProfileChange)
        #expect(event.key == "risk:projection:alpha:storm=2|severe=allClear|fire=8")
        #expect(event.payload["change"] as? RiskProfileChange == change)
    }

    @Test("composer batches storm, severe, and fire transitions in deterministic order")
    func composerBatchesRiskTransitionsInDeterministicOrder() throws {
        let change = makeChange(
            previous: makeProfile(
                storm: .marginal,
                severe: .wind(probability: 0.12),
                fire: .clear
            ),
            current: makeProfile(
                storm: .enhanced,
                severe: .tornado(probability: 0.31),
                fire: .critical
            ),
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

    @Test("composer renders severe hazard and probability-only changes")
    func composerRendersSevereHazardAndProbabilityOnlyChanges() throws {
        let hazardChange = makeChange(
            previous: makeProfile(storm: .allClear, severe: .wind(probability: 0.10), fire: .clear),
            current: makeProfile(storm: .allClear, severe: .hail(probability: 0.22), fire: .clear),
            locationSummary: "Norman, OK"
        )
        let hazardEvent = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: hazardChange)))

        let hazardMessage = RiskChangeComposer().compose(hazardEvent)
        #expect(hazardMessage.body == "Severe Risk: Wind 10% → Hail 22%")

        let probabilityChange = makeChange(
            previous: makeProfile(storm: .allClear, severe: .tornado(probability: 0.10), fire: .clear),
            current: makeProfile(storm: .allClear, severe: .tornado(probability: 0.18), fire: .clear),
            locationSummary: "Norman, OK"
        )
        let probabilityEvent = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: probabilityChange)))

        let probabilityMessage = RiskChangeComposer().compose(probabilityEvent)
        #expect(probabilityMessage.body == "Severe Risk: Tornado 10% → Tornado 18%")
    }

    @Test("composer uses the location subtitle and falls back to your area")
    func composerUsesLocationSubtitleAndFallback() throws {
        let locationChange = makeChange(
            previous: makeProfile(storm: .allClear, severe: .allClear, fire: .clear),
            current: makeProfile(storm: .slight, severe: .allClear, fire: .clear),
            locationSummary: "Oklahoma City, OK"
        )
        let locationEvent = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: locationChange)))

        let locationMessage = RiskChangeComposer().compose(locationEvent)
        #expect(locationMessage.subtitle == "Updated for Oklahoma City, OK")

        let fallbackChange = makeChange(
            previous: makeProfile(storm: .allClear, severe: .allClear, fire: .clear),
            current: makeProfile(storm: .slight, severe: .allClear, fire: .clear),
            locationSummary: nil
        )
        let fallbackEvent = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: fallbackChange)))

        let fallbackMessage = RiskChangeComposer().compose(fallbackEvent)
        #expect(fallbackMessage.subtitle == "Updated for your area")
    }

    @Test("gate suppresses duplicate risk notifications per projection")
    func gateSuppressesDuplicateRiskNotificationsPerProjection() async {
        let store = InMemoryRiskChangeStore()
        let gate = RiskChangeGate(store: store)
        let change = makeChange(
            projectionKey: "projection:alpha",
            previous: makeProfile(storm: .marginal, severe: .allClear, fire: .clear),
            current: makeProfile(storm: .enhanced, severe: .allClear, fire: .clear),
            locationSummary: "Bennett, CO"
        )
        let event = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: change)))

        #expect(await gate.allow(event, now: .now))
        #expect(await gate.allow(event, now: .now) == false)
    }

    @Test("gate keeps projection keys independent and allows reversions")
    func gateKeepsProjectionKeysIndependentAndAllowsReversions() async throws {
        let store = InMemoryRiskChangeStore()
        let gate = RiskChangeGate(store: store)
        let firstProjection = "projection:alpha"
        let secondProjection = "projection:bravo"

        let aToB = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(
            projectionKey: firstProjection,
            previous: makeProfile(storm: .marginal, severe: .allClear, fire: .clear),
            current: makeProfile(storm: .enhanced, severe: .allClear, fire: .clear),
            locationSummary: "Alpha"
        ))))
        let bToA = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(
            projectionKey: firstProjection,
            previous: makeProfile(storm: .enhanced, severe: .allClear, fire: .clear),
            current: makeProfile(storm: .marginal, severe: .allClear, fire: .clear),
            locationSummary: "Alpha"
        ))))
        let secondProjectionEvent = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(
            projectionKey: secondProjection,
            previous: makeProfile(storm: .allClear, severe: .allClear, fire: .clear),
            current: makeProfile(storm: .slight, severe: .allClear, fire: .clear),
            locationSummary: "Bravo"
        ))))

        #expect(await gate.allow(aToB, now: .now))
        #expect(await gate.allow(secondProjectionEvent, now: .now))
        #expect(await gate.allow(aToB, now: .now) == false)
        #expect(await gate.allow(bToA, now: .now))
        #expect(await gate.allow(aToB, now: .now))
    }

    @Test("gate recovers safely from malformed persisted state")
    func gateRecoversSafelyFromMalformedPersistedState() async throws {
        let store = InMemoryRiskChangeStore(stamp: "not-json")
        let gate = RiskChangeGate(store: store)
        let event = try #require(RiskChangeRule().evaluate(RiskChangeContext(change: makeChange(
            projectionKey: "projection:alpha",
            previous: makeProfile(storm: .allClear, severe: .allClear, fire: .clear),
            current: makeProfile(storm: .slight, severe: .allClear, fire: .clear),
            locationSummary: "Alpha"
        ))))

        #expect(await gate.allow(event, now: .now))
        #expect(await store.lastStamp() != "not-json")
    }

    @Test("engine sends exactly one notification with a deterministic identifier")
    func engineSendsExactlyOneNotificationWithDeterministicIdentifier() async throws {
        let sender = RecordingSender()
        let store = InMemoryRiskChangeStore()
        let engine = RiskChangeEngine(
            rule: RiskChangeRule(),
            gate: RiskChangeGate(store: store),
            composer: RiskChangeComposer(),
            sender: sender
        )
        let change = makeChange(
            projectionKey: "projection:alpha",
            previous: makeProfile(storm: .marginal, severe: .wind(probability: 0.10), fire: .clear),
            current: makeProfile(storm: .enhanced, severe: .hail(probability: 0.25), fire: .critical),
            locationSummary: "Bennett, CO"
        )

        let didSend = await engine.run(change: change)

        #expect(didSend)
        let sent = await sender.sent()
        #expect(sent.count == 1)
        #expect(sent[0].id == "risk:projection:alpha:storm=4|severe=hail:25|fire=8")
        #expect(sent[0].title == "Your Risk Profile Changed")
        #expect(sent[0].subtitle == "Updated for Bennett, CO")
    }
}

private func makeChange(
    projectionKey: String = "projection:alpha",
    previous: RiskProfile,
    current: RiskProfile,
    locationSummary: String?
) -> RiskProfileChange {
    RiskProfileChange(
        previous: previous,
        current: current,
        projectionKey: projectionKey,
        locationSummary: locationSummary
    )!
}

private func makeProfile(
    storm: StormRiskLevel,
    severe: SevereWeatherThreat,
    fire: FireRiskLevel
) -> RiskProfile {
    RiskProfile(stormRisk: storm, severeRisk: severe, fireRisk: fire)
}

actor InMemoryRiskChangeStore: NotificationStateStoring {
    private var stamp: String?

    init(stamp: String? = nil) {
        self.stamp = stamp
    }

    func lastStamp() async -> String? { stamp }

    func setLastStamp(_ stamp: String) async {
        self.stamp = stamp
    }
}

actor RecordingSender: NotificationSending {
    struct SentNotification: Sendable {
        let title: String
        let body: String
        let subtitle: String
        let id: String
    }

    private var notifications: [SentNotification] = []

    func send(title: String, body: String, subtitle: String, id: String) async {
        notifications.append(.init(title: title, body: body, subtitle: subtitle, id: id))
    }

    func sent() -> [SentNotification] {
        notifications
    }
}
#endif
