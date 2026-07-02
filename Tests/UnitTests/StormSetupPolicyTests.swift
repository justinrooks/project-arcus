import Foundation
import Testing
@testable import SkyAware

@Suite("Storm Setup Policy")
struct StormSetupPolicyTests {
    @Test("disabled storm setup suppresses every fetch and display path")
    func disabledStormSetupSuppressesEveryPath() {
        let input = makeInput(
            preferences: .init(stormSetupEnabled: false, detailedIngredientsEnabled: true),
            stormRisk: .high,
            severeRisk: .tornado(probability: 0.7),
            hasActiveAlert: true,
            hasActiveMeso: true,
            assessmentOverall: .strong,
            payloadExpiresAt: future,
            now: now
        )

        #expect(StormSetupFetchPolicy.shouldFetch(input) == false)
        #expect(StormSetupDisplayPolicy.shouldShow(input) == false)
    }

    @Test("fetch policy respects risk, alert, meso, override, and payload freshness")
    func fetchPolicyRespectsTriggersAndFreshness() {
        let cases: [(String, StormSetupPolicyInput, Bool)] = [
            ("thunderstorm does not qualify", makeInput(stormRisk: .thunderstorm), false),
            ("marginal qualifies", makeInput(stormRisk: .marginal), true),
            ("enhanced qualifies", makeInput(stormRisk: .enhanced), true),
            ("wind qualifies", makeInput(severeRisk: .wind(probability: 0.2)), true),
            ("hail qualifies", makeInput(severeRisk: .hail(probability: 0.2)), true),
            ("tornado qualifies", makeInput(severeRisk: .tornado(probability: 0.2)), true),
            ("alert qualifies", makeInput(hasActiveAlert: true), true),
            ("meso qualifies", makeInput(hasActiveMeso: true), true),
            ("detailed ingredients qualifies", makeInput(preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true)), true),
            ("unexpired payload suppresses refetch", makeInput(stormRisk: .high, payloadExpiresAt: future), false),
            ("expired payload still permits fetch", makeInput(stormRisk: .high, payloadExpiresAt: past), true),
            ("exact expiry still permits fetch", makeInput(stormRisk: .high, payloadExpiresAt: now), true),
            ("quiet inputs stay hidden", makeInput(), false)
        ]

        for (label, input, expected) in cases {
            #expect(StormSetupFetchPolicy.shouldFetch(input) == expected, "\(label)")
        }
    }

    @Test("display policy respects assessment quality, alerts, mesos, and expiry")
    func displayPolicyRespectsAssessmentQualityAndExpiry() {
        let cases: [(String, StormSetupPolicyInput, Bool)] = [
            ("supportive qualifies", makeInput(assessmentOverall: .supportive, payloadExpiresAt: future), true),
            ("strong qualifies", makeInput(assessmentOverall: .strong, payloadExpiresAt: future), true),
            ("weak stays hidden", makeInput(assessmentOverall: .weak, payloadExpiresAt: future), false),
            ("conditional stays hidden", makeInput(assessmentOverall: .conditional, payloadExpiresAt: future), false),
            ("unknown stays hidden", makeInput(assessmentOverall: .unknown, payloadExpiresAt: future), false),
            ("alert qualifies", makeInput(assessmentOverall: .unknown, hasActiveAlert: true, payloadExpiresAt: future), true),
            ("meso qualifies", makeInput(assessmentOverall: .weak, hasActiveMeso: true, payloadExpiresAt: future), true),
            ("override qualifies", makeInput(assessmentOverall: .conditional, preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true), payloadExpiresAt: future), true),
            ("missing assessment stays hidden", makeInput(assessmentOverall: nil, hasActiveAlert: true, preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true), payloadExpiresAt: future), false),
            ("expired assessment stays hidden", makeInput(assessmentOverall: .strong, hasActiveAlert: true, preferences: .init(stormSetupEnabled: true, detailedIngredientsEnabled: true), payloadExpiresAt: past), false)
        ]

        for (label, input, expected) in cases {
            #expect(StormSetupDisplayPolicy.shouldShow(input) == expected, "\(label)")
        }
    }

    @Test("stored detailed ingredients survives feature disablement")
    func storedDetailedIngredientsSurvivesFeatureDisablement() {
        var preferences = StormSetupPreferences(stormSetupEnabled: true, detailedIngredientsEnabled: true)

        #expect(preferences.effectiveDetailedIngredientsEnabled == true)
        preferences.stormSetupEnabled = false
        #expect(preferences.detailedIngredientsEnabled == true)
        #expect(preferences.effectiveDetailedIngredientsEnabled == false)
    }
}

private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
private let past = now.addingTimeInterval(-1)
private let future = now.addingTimeInterval(1)

private func makeInput(
    preferences: StormSetupPreferences = .init(stormSetupEnabled: true, detailedIngredientsEnabled: false),
    stormRisk: StormRiskLevel? = nil,
    severeRisk: SevereWeatherThreat? = nil,
    hasActiveAlert: Bool = false,
    hasActiveMeso: Bool = false,
    assessmentOverall: StormSetupSignal? = nil,
    payloadExpiresAt: Date? = nil,
    now: Date = now
) -> StormSetupPolicyInput {
    StormSetupPolicyInput(
        preferences: preferences,
        stormRisk: stormRisk,
        severeRisk: severeRisk,
        hasActiveAlert: hasActiveAlert,
        hasActiveMeso: hasActiveMeso,
        assessmentOverall: assessmentOverall,
        payloadExpiresAt: payloadExpiresAt,
        now: now
    )
}
