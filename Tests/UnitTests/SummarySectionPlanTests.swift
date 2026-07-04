#if canImport(Testing)
import Foundation
import Testing
@testable import SkyAware

@Suite("Summary Section Plan")
struct SummarySectionPlanTests {
    @Test("populated alerts precede Storm Setup and the atmospheric fallback")
    func populatedAlerts_precedeStormSetupAndAtmosphericFallback() {
        let populated = makePlan(
            localAlertsDisplayState: .current(content: .populated, source: .cached),
            showsStormSetup: true,
            hasLocationReliabilityRail: true
        )
        let fallback = makePlan(
            localAlertsDisplayState: .current(content: .populated, source: .cached),
            showsStormSetup: false,
            hasLocationReliabilityRail: true
        )

        #expect(populated.sections == [
            .currentConditions,
            .primaryAwareness,
            .localAlerts,
            .stormSetup,
            .locationReliability,
            .outlookSummary,
            .attribution
        ])
        #expect(fallback.sections == [
            .currentConditions,
            .primaryAwareness,
            .localAlerts,
            .atmosphericConditions,
            .locationReliability,
            .outlookSummary,
            .attribution
        ])
    }

    @Test("quiet loading empty and unavailable alerts follow Storm Setup or the atmospheric fallback")
    func quietLoadingEmptyAndUnavailableAlerts_followSupportingSection() {
        let cases: [(String, LocalAlertsDisplayState, [SummarySectionKind])] = [
            (
                "loading",
                .noCacheResolving,
                [.currentConditions, .primaryAwareness, .stormSetup, .localAlerts, .outlookSummary, .attribution]
            ),
            (
                "empty",
                .current(content: .empty, source: .cached),
                [.currentConditions, .primaryAwareness, .stormSetup, .localAlerts, .outlookSummary, .attribution]
            ),
            (
                "unavailable",
                .unavailable(reason: .locationUnavailable),
                [.currentConditions, .primaryAwareness, .stormSetup, .localAlerts, .outlookSummary, .attribution]
            )
        ]

        for (label, state, expectedStormSetupOrder) in cases {
            let stormSetupPlan = makePlan(
                localAlertsDisplayState: state,
                showsStormSetup: true,
                hasLocationReliabilityRail: false
            )
            let atmosphericPlan = makePlan(
                localAlertsDisplayState: state,
                showsStormSetup: false,
                hasLocationReliabilityRail: false
            )

            #expect(stormSetupPlan.sections == expectedStormSetupOrder, "\(label) storm setup order")
            #expect(atmosphericPlan.sections == [
                .currentConditions,
                .primaryAwareness,
                .atmosphericConditions,
                .localAlerts,
                .outlookSummary,
                .attribution
            ], "\(label) atmospheric fallback order")
            #expect(stormSetupPlan.sections.contains(.stormSetup) != stormSetupPlan.sections.contains(.atmosphericConditions))
        }
    }

    @Test("location reliability never precedes populated alerts")
    func locationReliability_neverPrecedesPopulatedAlerts() {
        let plan = makePlan(
            localAlertsDisplayState: .current(content: .populated, source: .cached),
            showsStormSetup: true,
            hasLocationReliabilityRail: true
        )

        let localAlertsIndex = plan.sections.firstIndex(of: .localAlerts)
        let locationReliabilityIndex = plan.sections.firstIndex(of: .locationReliability)

        #expect(localAlertsIndex != nil)
        #expect(locationReliabilityIndex != nil)
        guard let localAlertsIndex, let locationReliabilityIndex else {
            return
        }
        #expect(locationReliabilityIndex > localAlertsIndex)
    }

    @Test("disabled Storm Setup always selects Atmospheric Conditions")
    func disabledStormSetup_selectsAtmosphericConditions() {
        let plan = makePlan(
            localAlertsDisplayState: .noCacheResolving,
            showsStormSetup: false,
            hasLocationReliabilityRail: false
        )

        #expect(plan.sections.contains(.stormSetup) == false)
        #expect(plan.sections.contains(.atmosphericConditions))
    }

    @Test("Storm Setup and Atmospheric Conditions are mutually exclusive")
    func stormSetupAndAtmosphericConditions_areMutuallyExclusive() {
        let stormPlan = makePlan(
            localAlertsDisplayState: .noCacheResolving,
            showsStormSetup: true,
            hasLocationReliabilityRail: false
        )

        #expect(stormPlan.sections.contains(.stormSetup))
        #expect(stormPlan.sections.contains(.atmosphericConditions) == false)
    }

    @Test("outlook and attribution remain last in canonical order")
    func outlookAndAttributionRemainLast() {
        let plan = makePlan(
            localAlertsDisplayState: .current(content: .empty, source: .cached),
            showsStormSetup: false,
            hasLocationReliabilityRail: true
        )

        #expect(Array(plan.sections.suffix(2)) == [.outlookSummary, .attribution])
    }
}

private func makePlan(
    localAlertsDisplayState: LocalAlertsDisplayState,
    showsStormSetup: Bool,
    hasLocationReliabilityRail: Bool
) -> SummarySectionPlan {
    SummarySectionPlan.make(
        localAlertsDisplayState: localAlertsDisplayState,
        showsStormSetup: showsStormSetup,
        hasLocationReliabilityRail: hasLocationReliabilityRail
    )
}
#endif
