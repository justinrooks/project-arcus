#if canImport(Testing)
import Foundation
import Testing
@testable import SkyAware

@Suite("Summary Section Plan")
struct SummarySectionPlanTests {
    @Test("local alerts stay first below the primary awareness across alert and storm setup states")
    func localAlertsStayFirstAcrossAlertAndStormSetupStates() {
        let cases: [(String, LocalAlertsDisplayState, Bool, [SummarySectionKind])] = [
            (
                "no active alerts with storm setup visible",
                .current(content: .empty, source: .cached),
                true,
                [
                    .currentConditions,
                    .primaryAwareness,
                    .localAlerts,
                    .atmosphericConditions,
                    .stormSetup,
                    .locationReliability,
                    .outlookSummary,
                    .attribution
                ]
            ),
            (
                "active alerts with storm setup visible",
                .current(content: .populated, source: .cached),
                true,
                [
                    .currentConditions,
                    .primaryAwareness,
                    .localAlerts,
                    .atmosphericConditions,
                    .stormSetup,
                    .locationReliability,
                    .outlookSummary,
                    .attribution
                ]
            ),
            (
                "no active alerts with storm setup hidden",
                .current(content: .empty, source: .cached),
                false,
                [
                    .currentConditions,
                    .primaryAwareness,
                    .localAlerts,
                    .atmosphericConditions,
                    .locationReliability,
                    .outlookSummary,
                    .attribution
                ]
            ),
            (
                "active alerts with storm setup hidden",
                .current(content: .populated, source: .cached),
                false,
                [
                    .currentConditions,
                    .primaryAwareness,
                    .localAlerts,
                    .atmosphericConditions,
                    .locationReliability,
                    .outlookSummary,
                    .attribution
                ]
            )
        ]

        for (label, state, showsStormSetup, expectedSections) in cases {
            let plan = makePlan(
                localAlertsDisplayState: state,
                showsStormSetup: showsStormSetup,
                hasLocationReliabilityRail: true
            )

            #expect(plan.sections == expectedSections)
        }
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
