import Foundation
import CoreLocation
import SwiftUI
import Testing
@testable import SkyAware

@Suite("Today Resolving Surface State")
@MainActor
struct TodayResolvingSurfaceStateTests {
    @Test("no content with active refresh shows full-screen resolving")
    func showsEmptyResolving_noContentActiveRefresh() {
        #expect(
            TodayContentState.from(
                readinessState: .ready,
                hasCachedContent: false,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: false
            ).showsResolvingSurface
        )
    }

    @Test("no content while loading local data shows full-screen resolving")
    func showsEmptyResolving_noContentLoadingLocalData() {
        #expect(
            TodayContentState.from(
                readinessState: .loadingLocalData,
                hasCachedContent: false,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: false
            ).showsResolvingSurface
        )
    }

    @Test("meaningful content suppresses full-screen resolving even during refresh")
    func showsEmptyResolving_contentDuringRefresh() {
        #expect(
            TodayContentState.from(
                readinessState: .loadingLocalData,
                hasCachedContent: true,
                hasLiveContent: false,
                isRefreshing: true,
                isOffline: false
            ).showsResolvingSurface == false
        )
    }

    @Test("location unavailable suppresses full-screen resolving")
    func showsEmptyResolving_locationUnavailable() {
        #expect(
            TodayContentState.from(
                readinessState: .locationUnavailable,
                hasCachedContent: false,
                hasLiveContent: false,
                isRefreshing: false,
                isOffline: false
            ).showsResolvingSurface == false
        )
    }
}


@Suite("SummaryView Risk Placeholder Presentation")
@MainActor
struct SummaryViewRiskPlaceholderPresentationTests {
    @Test("nil risk shows resolving placeholder only during no-cache resolving")
    func riskPlaceholder_nilRiskWhileNoCacheResolving() {
        #expect(
            SummaryView.showsRiskResolvingPlaceholder(
                hasRiskValue: false,
                todayContentState: .noCacheResolving,
                showsOfflineToken: false
            )
        )
    }

    @Test("nil risk stays hidden during cached refreshes")
    func riskPlaceholder_nilRiskDuringCachedRefresh() {
        #expect(
            SummaryView.showsRiskResolvingPlaceholder(
                hasRiskValue: false,
                todayContentState: .cachedRefreshing,
                showsOfflineToken: false,
            ) == false
        )
    }

    @Test("nil risk does not show resolving placeholder after completed local data attempt")
    func riskPlaceholder_nilRiskWhenReadyAfterCompletedAttempt() {
        #expect(
            SummaryView.showsRiskResolvingPlaceholder(
                hasRiskValue: false,
                todayContentState: .current,
                showsOfflineToken: false
            ) == false
        )
    }

    @Test("offline bypasses resolving placeholder behavior")
    func riskPlaceholder_offlineBypassesResolvingPlaceholder() {
        #expect(
            SummaryView.showsRiskResolvingPlaceholder(
                hasRiskValue: false,
                todayContentState: .noCacheResolving,
                showsOfflineToken: true
            ) == false
        )
    }
}


@Suite("Summary View Storm Setup Slot State")
@MainActor
struct SummaryViewStormSetupSlotStateTests {
    @Test("forced presentation bypasses the normal Storm Setup feature gate")
    func forcedPresentation_bypassesNormalFeatureGate() {
        let cases: [(String, Bool, Bool, Bool, Bool, Bool)] = [
            ("feature off and force off", true, false, false, false, false),
            ("feature off and force on", true, false, true, false, true),
            ("policy-suppressed presentation forced on", true, true, true, false, true),
            ("force on without payload", false, false, true, false, false),
            ("location unavailable", true, false, true, true, false)
        ]

        for (name, hasPresentation, stormSetupEnabled, isForcedPresentation, isLocationUnavailable, expected) in cases {
            #expect(
                SummaryView.shouldShowStormSetupPresentation(
                    hasPresentation: hasPresentation,
                    stormSetupEnabled: stormSetupEnabled,
                    isForcedPresentation: isForcedPresentation,
                    isLocationUnavailable: isLocationUnavailable
                ) == expected,
                "\\(name)"
            )
        }
    }

    @Test("composed Storm Setup state reserves only loading and visible sections")
    func composedStateAndPlanRespectSlotContract() {
        let cases: [(String, SummaryView.StormSetupSlotState, Bool)] = [
            ("enabled refreshing without content", SummaryView.stormSetupSlotState(
                presentation: nil, hasStormSetup: false, stormSetupEnabled: true,
                isRefreshInFlight: true, isLocationUnavailable: false
            ), true),
            ("visible", .loading, true),
            ("cached visible while refreshing", .loading, true),
            ("disabled", SummaryView.stormSetupSlotState(
                presentation: nil, hasStormSetup: false, stormSetupEnabled: false,
                isRefreshInFlight: true, isLocationUnavailable: false
            ), false),
            ("location unavailable", SummaryView.stormSetupSlotState(
                presentation: nil, hasStormSetup: true, stormSetupEnabled: true,
                isRefreshInFlight: true, isLocationUnavailable: true
            ), false),
            ("policy suppressed existing payload", SummaryView.stormSetupSlotState(
                presentation: nil, hasStormSetup: true, stormSetupEnabled: true,
                isRefreshInFlight: true, isLocationUnavailable: false
            ), false),
            ("idle without content", SummaryView.stormSetupSlotState(
                presentation: nil, hasStormSetup: false, stormSetupEnabled: true,
                isRefreshInFlight: false, isLocationUnavailable: false
            ), false)
        ]

        for (label, slot, shouldInclude) in cases {
            let plan = SummaryView.sectionPlan(
                localAlertsDisplayState: .current(content: .empty, source: .cached),
                stormSetupSlot: slot.sectionSlot,
                hasLocationReliabilityRail: true
            )
            #expect(plan.sections.contains(.stormSetup) == shouldInclude)
        }
    }

    @Test("storm setup shows a loading slot while refresh is in flight")
    func stormSetupSlotState_showsLoadingDuringRefresh() {
        #expect(
            SummaryView.stormSetupSlotState(
                presentation: nil,
                hasStormSetup: false,
                stormSetupEnabled: true,
                isRefreshInFlight: true,
                isLocationUnavailable: false
            ) == .loading
        )
    }

    @Test("storm setup stays hidden when not refreshing")
    func stormSetupSlotState_staysHiddenWhenIdle() {
        #expect(
            SummaryView.stormSetupSlotState(
                presentation: nil,
                hasStormSetup: false,
                stormSetupEnabled: true,
                isRefreshInFlight: false,
                isLocationUnavailable: false
            ) == .hidden
        )
    }

    @Test("disabled storm setup never shows the loading shell")
    func stormSetupSlotState_disabledNeverLoads() {
        #expect(
            SummaryView.stormSetupSlotState(
                presentation: nil,
                hasStormSetup: false,
                stormSetupEnabled: false,
                isForcedPresentation: true,
                isRefreshInFlight: true,
                isLocationUnavailable: false
            ) == .hidden
        )
    }

    @Test("existing storm setup data keeps the slot hidden when policy suppresses visibility")
    func stormSetupSlotState_existingDataDoesNotShowLoadingShell() {
        #expect(
            SummaryView.stormSetupSlotState(
                presentation: nil,
                hasStormSetup: true,
                stormSetupEnabled: true,
                isRefreshInFlight: true,
                isLocationUnavailable: false
            ) == .hidden
        )
    }
}


@Suite("Summary Content Presentation State")
@MainActor
struct SummaryContentPresentationStateTests {
    @Test("online content stays current")
    func presentationState_onlineContentIsCurrent() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: false,
                hasContent: true,
                isResolving: false
            ) == .current
        )
    }

    @Test("offline content becomes stale")
    func presentationState_offlineContentIsStale() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: true,
                hasContent: true,
                isResolving: false
            ) == .stale
        )
    }

    @Test("resolving content remains resolving while online and empty")
    func presentationState_resolvingContentIsResolving() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: false,
                hasContent: false,
                isResolving: true
            ) == .resolving
        )
    }

    @Test("offline without content is unavailable")
    func presentationState_offlineWithoutContentIsUnavailable() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: true,
                hasContent: false,
                isResolving: true
            ) == .unavailable
        )
    }

    @Test("confirmed empty beats unavailable when the latest successful result is empty")
    func presentationState_confirmedEmptyWins() {
        #expect(
            SummaryContentPresentationState.from(
                isOffline: false,
                hasContent: false,
                isResolving: false,
                isConfirmedEmpty: true
            ) == .confirmedEmpty
        )
    }
}


@Suite("Summary Resolution State")
struct SummaryResolutionStateTests {
    @Test("begin tracks provider message and resolving sections")
    func begin_tracksProviderMessageAndSections() {
        var state = SummaryResolutionState()

        state.begin(task: .alerts, sections: [.alerts])

        #expect(state.isRefreshing)
        #expect(state.activeMessages == ["Bringing in local alerts…"])
        #expect(state.primaryActiveMessage == "Bringing in local alerts…")
        #expect(state.isResolving(.alerts))
    }

    @Test("finishing one section keeps the provider active for remaining work")
    func finish_keepsProviderActiveUntilAllSectionsResolve() {
        var state = SummaryResolutionState()

        state.begin(task: .stormRisk, sections: [.stormRisk, .severeRisk])
        state.finish(task: .stormRisk, resolvedSections: [.stormRisk])

        #expect(state.isRefreshing)
        #expect(state.activeMessages == ["Getting storm risk…"])
        #expect(state.primaryActiveMessage == "Getting storm risk…")
        #expect(state.isResolving(.stormRisk) == false)
        #expect(state.isResolving(.severeRisk))
    }

    @Test("finishing remaining sections clears refresh activity")
    func finish_clearsRefreshWhenTaskCompletes() {
        var state = SummaryResolutionState()

        state.begin(task: .weather, sections: [.conditions, .atmosphere])
        state.finish(task: .weather, resolvedSections: [.conditions, .atmosphere])

        #expect(state.isRefreshing == false)
        #expect(state.isResolving(.conditions) == false)
        #expect(state.isResolving(.atmosphere) == false)
        #expect(state.recentCompletedMessage == "Updated conditions")
    }

    @Test("reset clears active tasks and sections")
    func reset_clearsTrackedState() {
        var state = SummaryResolutionState()

        state.begin(task: .location, sections: [.conditions])
        state.reset()

        #expect(state.isRefreshing == false)
        #expect(state.activeMessages.isEmpty)
        #expect(state.primaryActiveMessage == nil)
        #expect(state.isResolving(.conditions) == false)
    }

    @Test("finish all clears every active task and section")
    func finishAll_clearsEveryActiveTaskAndSection() {
        var state = SummaryResolutionState()

        state.begin(task: .weather, sections: [.conditions, .atmosphere])
        state.begin(task: .alerts, sections: [.alerts])
        state.finishAll(completedTask: .finalizing)

        #expect(state.isRefreshing == false)
        #expect(state.activeMessages.isEmpty)
        #expect(state.primaryActiveMessage == nil)
        for section in SummarySection.resolveForwardSections {
            #expect(state.isResolving(section) == false)
        }
        #expect(state.recentCompletedMessage == "Updated conditions")
    }

    @Test("primary active message prefers location readiness over other active tasks")
    func primaryActiveMessage_prioritizesLocationTask() {
        var state = SummaryResolutionState()

        state.begin(task: .alerts, sections: [.alerts])
        state.begin(task: .weather, sections: [.conditions])
        state.begin(task: .location, sections: [.conditions])

        #expect(state.primaryActiveMessage == "Getting your conditions ready…")
    }
}
