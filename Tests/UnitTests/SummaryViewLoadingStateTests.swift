import Foundation
import CoreLocation
import SwiftUI
import Testing
@testable import SkyAware

@Suite("SummaryView Empty Resolving")
@MainActor
struct SummaryViewEmptyResolvingTests {
    @Test("no content with active refresh shows full-screen resolving")
    func showsEmptyResolving_noContentActiveRefresh() {
        var resolutionState = SummaryResolutionState()
        resolutionState.begin(task: .stormRisk, sections: [.stormRisk])

        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .ready,
                resolutionState: resolutionState,
                hasMeaningfulContent: false,
                isLocationUnavailable: false
            )
        )
    }

    @Test("no content while loading local data shows full-screen resolving")
    func showsEmptyResolving_noContentLoadingLocalData() {
        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .loadingLocalData,
                resolutionState: SummaryResolutionState(),
                hasMeaningfulContent: false,
                isLocationUnavailable: false
            )
        )
    }

    @Test("meaningful content suppresses full-screen resolving even during refresh")
    func showsEmptyResolving_contentDuringRefresh() {
        var resolutionState = SummaryResolutionState()
        resolutionState.begin(task: .alerts, sections: [.alerts])

        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .loadingLocalData,
                resolutionState: resolutionState,
                hasMeaningfulContent: true,
                isLocationUnavailable: false
            ) == false
        )
    }

    @Test("location unavailable suppresses full-screen resolving")
    func showsEmptyResolving_locationUnavailable() {
        #expect(
            SummaryView.showsEmptyResolving(
                readinessState: .locationUnavailable,
                resolutionState: SummaryResolutionState(),
                hasMeaningfulContent: false,
                isLocationUnavailable: true
            ) == false
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


