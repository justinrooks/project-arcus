#if canImport(Testing)
import Foundation
import Testing
@testable import SkyAware

@Suite("Summary Section Plan")
@MainActor
struct SummarySectionPlanTests {
    @Test("loading and visible Storm Setup share the same ordered section slot")
    func loadingToVisiblePreservesOrderAndIdentity() {
        let loading = makePlan(stormSetupSlot: .loading, hasLocationReliabilityRail: true)
        let visible = makePlan(
            stormSetupSlot: SummaryStormSetupSlot.visible,
            hasLocationReliabilityRail: true
        )

        #expect(loading.sections == visible.sections)
        #expect(loading.sections[4] == .stormSetup)
        #expect(loading.sections[4].id == visible.sections[4].id)
    }

    @Test("section plan retains the Storm Setup slot during cached refresh")
    func cachedVisibleRefreshRetainsStormSetup() {
        let plan = makePlan(
            localAlertsDisplayState: .current(content: .populated, source: .cached),
            stormSetupSlot: SummaryStormSetupSlot.visible,
            hasLocationReliabilityRail: true
        )

        #expect(plan.sections.contains(.stormSetup))
        #expect(plan.sections[3...5] == [.atmosphericConditions, .stormSetup, .locationReliability])
    }

    @Test("hidden Storm Setup is excluded while surrounding order remains stable")
    func hiddenStormSetupIsExcluded() {
        let plan = makePlan(stormSetupSlot: .hidden, hasLocationReliabilityRail: true)

        #expect(plan.sections.contains(.stormSetup) == false)
        #expect(plan.sections == [
            .currentConditions, .primaryAwareness, .localAlerts, .atmosphericConditions,
            .locationReliability, .outlookSummary, .attribution
        ])
    }

    @Test("local alerts and location reliability combinations preserve Storm Setup order")
    func localAlertsAndLocationReliabilityCombinationsPreserveOrder() {
        for state in [
            LocalAlertsDisplayState.current(content: .empty, source: .cached),
            LocalAlertsDisplayState.current(content: .populated, source: .cached)
        ] {
            for hasLocationReliabilityRail in [false, true] {
                let plan = makePlan(
                    localAlertsDisplayState: state,
                    stormSetupSlot: .loading,
                    hasLocationReliabilityRail: hasLocationReliabilityRail
                )
                let stormSetupIndex = plan.sections.firstIndex(of: .stormSetup)
                let atmosphericIndex = plan.sections.firstIndex(of: .atmosphericConditions)
                #expect(stormSetupIndex == atmosphericIndex.map { $0 + 1 })
                if hasLocationReliabilityRail {
                    #expect(plan.sections[stormSetupIndex! + 1] == .locationReliability)
                } else {
                    #expect(plan.sections[stormSetupIndex! + 1] == .outlookSummary)
                }
            }
        }
    }
}

@MainActor
private func makePlan(
    localAlertsDisplayState: LocalAlertsDisplayState = .current(content: .empty, source: .cached),
    stormSetupSlot: SummaryStormSetupSlot,
    hasLocationReliabilityRail: Bool
) -> SummarySectionPlan {
    SummaryView.sectionPlan(
        localAlertsDisplayState: localAlertsDisplayState,
        stormSetupSlot: stormSetupSlot,
        hasLocationReliabilityRail: hasLocationReliabilityRail
    )
}
#endif
