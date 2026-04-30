# 1. Executive Summary

The most likely cause is not bad alert data. It is presentation sequencing.

`HomeView` and `SummaryView` currently have several overlapping state machines: bootstrap loading, readiness, section resolving, cached projection availability, and local alert emptiness. During launch, Local Alerts can move through:

1. full-screen `LoadingView`
2. normal Summary subtree entering with blur/opacity
3. `ActiveAlertSummaryView` loading or resolving opacity
4. final empty/content branch

That makes the user perceive an extra “partially loaded card” even though the data is correct. The current `ActiveAlertSummaryView` no longer uses redacted placeholder rows for loading, but it still swaps internal content branches, and the parent applies resolving treatment at the card level.

# 2. Lifecycle Map

| Step | Parent State | Child Props | Child Branch | Visual Result | Desirable? |
|---|---|---|---|---|---|
| 1 | `HomeView` has no projection/fallback; refresh active or readiness not ready | `SummaryView` may not render child | `LoadingView` | full resolving screen | Yes |
| 2 | First useful content appears: cached projection or pipeline fallback | `mesos/watches` from cache or pipeline, `resolutionState` may still resolve alerts | `SummaryView.summaryContent` enters | whole Summary subtree blur/opacity transition | Mostly yes, but can look like a middle state |
| 3 | Alerts lane is resolving and no active alerts yet | `isLoading = true`, empty `mesos/watches` | `loadingContent` | clear “Checking local alerts” content, but parent dims card opacity | Yes semantically, slightly ambiguous visually |
| 4 | Alerts lane resolves empty | `isLoading = false`, empty `mesos/watches` | `emptyContent` | “No Active Alerts” | Yes |
| 5 | Alerts lane resolves populated | `isLoading = false`, non-empty arrays | `alertsContent` | watch/meso rows | Yes |
| 6 | Offline | `isOffline = true` | `offlineContent` wins over loading/content | offline message | Yes, but cached alert visibility is not preserved in this card |

Important parent facts:

- `HomeView.displayedMesos` and `displayedWatches` use pipeline arrays once the current context key is resolved; otherwise they fall back to cached projection arrays: [HomeView.swift](/Users/justin/Code/project-arcus/Sources/App/HomeView.swift:87), [HomeView.swift](/Users/justin/Code/project-arcus/Sources/App/HomeView.swift:97).
- `SummaryView` derives Local Alerts from `readinessState`, `hasActiveAlerts`, `isLocationUnavailable`, and `resolutionState.isResolving(.alerts)`: [SummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryView.swift:93).
- Arcus watches and SPC mesos are queried together for the final snapshot: [HomeSnapshotStore.swift](/Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeSnapshotStore.swift:52). UI progress models them as one `.hotAlerts` lane, not two independently presentable sources: [HomeRefreshPipeline.swift](/Users/justin/Code/project-arcus/Sources/App/HomeRefreshPipeline.swift:364).

# 3. Findings

## Parent State Sequencing

**High: Local Alerts can legitimately show empty while the broader Summary is still loading local data.**  
Evidence: `localAlertsPresentationState` returns `.empty` for `.loadingLocalData` when no alerts are resolving and no alerts exist: [SummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryView.swift:334). That is truthful for alerts, but during launch it can read as “this card finished before the screen finished.” Risk of changing: Medium, because this helper is already tested.

**Medium: Bootstrap and Summary empty resolving use different thresholds.**  
Evidence: `HomeView.hasMeaningfulSummaryContent` is projection/fallback based: [HomeView.swift](/Users/justin/Code/project-arcus/Sources/App/HomeView.swift:129). `SummaryView.hasMeaningfulContent` is field based: [SummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryView.swift:102). Divergence can create one-frame disagreements. Risk: Medium.

**Low: Arcus/SPC do not currently expose source-specific readiness.**  
Evidence: watches and mesos are read with separate async lets but returned as one snapshot: [HomeSnapshotStore.swift](/Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeSnapshotStore.swift:55). Risk: High if changed; do not split source orchestration for this polish issue.

## Child Rendering Branches

**Medium: `ActiveAlertSummaryView` has distinct semantic branches but no explicit transition boundary.**  
Evidence: it switches `offlineContent`, `loadingContent`, `alertsContent`, and `emptyContent` inline: [ActiveAlertSummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/ActiveAlertSummaryView.swift:110). Risk: Low to Medium.

**Low: Dead placeholder alert rows remain in the file.**  
Evidence: `placeholderAlertsContent` and `PlaceholderAlertSection` exist but are not used: [ActiveAlertSummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/ActiveAlertSummaryView.swift:70), [ActiveAlertSummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/ActiveAlertSummaryView.swift:225). This is a trap for future “fixes.” Risk: Low to remove later.

**Medium: Offline wins over actual alert content.**  
Evidence: `if isOffline { offlineContent } else { ... }`: [ActiveAlertSummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/ActiveAlertSummaryView.swift:110). If cached alerts exist offline, this hides them. Risk: Medium; may be intentional, so defer unless product wants cached alerts visible.

## SwiftUI Identity / Transitions

**High: The full Summary subtree enters with blur/opacity after `LoadingView`.**  
Evidence: `showsEmptyResolving` swaps `LoadingView` and `summaryContent`, with a custom blur/opacity transition: [SummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryView.swift:279), [SummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryView.swift:355). This likely explains the “indistinct middle state.” Risk: Medium.

**Medium: Alerts resolving dims the whole Local Alerts card.**  
Evidence: `.summaryResolving(... appliesBlur: false)` still applies opacity to the entire `ActiveAlertSummaryView`: [SummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryView.swift:262), [SummaryResolving.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryResolving.swift:158). Risk: Low.

**Low: Redacted placeholders are used elsewhere, not in Local Alerts.**  
Evidence: placeholder modifier uses `.redacted`: [ext+View.swift](/Users/justin/Code/project-arcus/Sources/Utilities/Extensions/ext+View.swift:10). Summary applies it to risk/atmosphere, not Local Alerts: [SummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryView.swift:146).

## Accessibility Semantics

**Medium: Dead placeholder alert rows have real text if ever used.**  
Evidence: “Placeholder alert title” and “Until 00:00 pm” are real `Text` nodes with no `accessibilityHidden`: [ActiveAlertSummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/ActiveAlertSummaryView.swift:236). Risk: Low to fix/remove.

**Low: Current loading and empty states are combined sensibly.**  
Evidence: both use `.accessibilityElement(children: .combine)`: [ActiveAlertSummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/ActiveAlertSummaryView.swift:181), [ActiveAlertSummaryView.swift](/Users/justin/Code/project-arcus/Sources/Features/Summary/ActiveAlertSummaryView.swift:194).

## Test Coverage

**Medium: Pure state tests exist, but not the launch sequence.**  
Evidence: `SummaryViewLocalAlertsTests` covers loading/empty/alerts state helper cases: [HomeViewLoadingOverlayStateTests.swift](/Users/justin/Code/project-arcus/Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift:317). `SummaryViewEmptyResolvingTests` covers full-screen resolving helper cases: [HomeViewLoadingOverlayStateTests.swift](/Users/justin/Code/project-arcus/Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift:417). Missing: combined sequence tests for loading → empty/content and cached alerts during refresh.

# 4. Recommended Fix Strategy

Smallest safe approach:

1. Keep `ActiveAlertSummaryView` as the one Local Alerts container for loading, empty, and populated states.
2. Introduce an explicit internal presentation enum in `ActiveAlertSummaryView`, or pass one from `SummaryView`, so loading/empty/content/offline are distinct and testable.
3. Transition only the inner content area, not the full card.
4. Remove or accessibility-hide unused placeholder alert rows. Better: remove dead placeholder code if no longer used.
5. Avoid applying resolving opacity to the entire Local Alerts card when `isLoading` is already showing a clear loading state. The card should not look half-disabled while also saying it is checking alerts.
6. Respect Reduce Motion: use opacity-only under Reduce Motion; otherwise use a calm crossfade with optional tiny blur inside the content region.
7. Do not touch alert ingestion, Arcus/SPC refresh cadence, or source orchestration.

# 5. Implementation Slices

## Slice 1: State Helper Tests

Goal: lock down the intended state sequence before UI changes.  
Files: `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`, maybe `Sources/Features/Summary/SummaryView.swift`.

Steps:
1. Add tests for loading → empty when `isAlertsResolving` flips false and arrays remain empty.
2. Add tests for loading → alerts when arrays become non-empty.
3. Add cached-content refresh cases: active alerts while resolving, empty cached projection while resolving.
4. Add a test proving location unavailable still wins.

Guardrails: pure helper tests only; no production UI change.  
Validation: run focused `HomeViewLoadingOverlayStateTests`.  
Model recommendation: smaller model.  
Intelligence recommendation: medium.

## Slice 2: Loading Placeholder Semantics

Goal: remove the risk of fake alert rows becoming accessible or visible.  
Files: `Sources/Features/Summary/ActiveAlertSummaryView.swift`.

Steps:
1. Delete `placeholderAlertsContent` and `PlaceholderAlertSection` if unused.
2. If kept for future use, mark the placeholder subtree `.accessibilityHidden(true)` and keep it unreachable from current loading.
3. Confirm `loadingContent` remains the only Local Alerts loading representation.

Guardrails: do not redesign loading copy or row layout.  
Validation: build; VoiceOver inspect loading/empty states.  
Model recommendation: smaller model.  
Intelligence recommendation: low-medium.

## Slice 3: Smooth Transition Inside ActiveAlertSummaryView

Goal: make loading → empty/content resolve inside a stable card.  
Files: `Sources/Features/Summary/ActiveAlertSummaryView.swift`.

Steps:
1. Add a private enum, e.g. `ContentState: Equatable { case loading, empty, alerts, offline }`.
2. Derive `contentState` from `isOffline`, `isLoading`, and `hasRenderableAlerts`.
3. Wrap only the content below the header in a stable `ZStack` or `Group` with `.transition(.opacity)` for Reduce Motion and subtle opacity/blur otherwise.
4. Animate on `contentState`, not on raw arrays.
5. Keep the header and card background outside the transition.
6. Avoid changing row sorting, sheets, actions, labels, colors, spacing, or typography.

Guardrails: one stable card container; no redacted empty content; no whole-card blur.  
Validation: manually verify loading → empty, loading → watches, loading → mesos, loading → both.  
Model recommendation: smaller model.  
Intelligence recommendation: medium.

## Slice 4: Parent Presentation-State Cleanup

Goal: prevent parent/card-level resolving treatment from creating the ambiguous middle.  
Files: `Sources/Features/Summary/SummaryView.swift`, maybe `Sources/Features/Summary/SummaryResolving.swift`.

Steps:
1. Keep `localAlertsPresentationState` as the parent truth source unless tests show it is wrong.
2. Consider suppressing `.summaryResolving(.alerts)` on Local Alerts when `localAlertsPresentationState == .loading`; the child already renders a clear loading state.
3. If keeping resolving treatment, apply it to inner content only, not the whole `ActiveAlertSummaryView`.
4. Confirm unavailable location still uses the existing `unavailableCard`.

Guardrails: no new architecture; no provider changes; no copy churn.  
Validation: launch no-alerts, cached alerts during refresh, active alerts resolving.  
Model recommendation: stronger small model or main model.  
Intelligence recommendation: medium-high.

## Slice 5: Optional Bootstrap Exit Review

Goal: confirm the perceived middle state is not mostly the Summary subtree entrance.  
Files: `Sources/Features/Summary/SummaryView.swift`.

Steps:
1. After Slice 3, inspect whether `summaryContentEntrance` still creates the observed blur.
2. If yes, narrow blur duration/radius or use opacity-only for the full Summary entrance while preserving internal section transitions.
3. Keep Reduce Motion opacity-only.

Guardrails: preserve `LoadingView`; do not redesign startup.  
Validation: cold no-cache launch recording before/after.  
Model recommendation: main model.  
Intelligence recommendation: high.

# 6. Validation Checklist

- Launch while alerts are loading.
- Loading resolves to no active alerts.
- Loading resolves to watches only.
- Loading resolves to mesos only.
- Loading resolves to watches + mesos.
- Cached alerts available during foreground refresh.
- Cached no-alert projection during foreground refresh.
- Arcus watches present.
- SPC mesos present.
- Both sources empty.
- Offline/cached mode.
- Location unavailable.
- Reduce Motion enabled.
- VoiceOver labels for loading, empty, offline, populated.
- Dynamic Type large sizes.
- Light mode and dark mode.
- Confirm no new Swift concurrency warnings.
- Run focused unit tests and an iOS simulator build.

# 7. Do Not Change

- Do not redesign Local Alerts.
- Do not change Arcus, SPC, NWS ingestion.
- Do not split alert refresh orchestration by source.
- Do not change refresh cadence.
- Do not add dependencies.
- Do not move orchestration into SwiftUI views.
- Do not change alert row layout, detail sheets, or navigation.
- Do not change SkyAware typography, colors, card styling, or section order.
- Do not add spinners, shimmer, bounce, or strong spring motion.
- Do not remove the full-screen `LoadingView` for true no-cache startup.
- Do not claim runtime validation without running it.

Investigation only completed. I did not edit files, run tests, create commits, or touch git.