# Today State Flow Progress

This is the durable handoff ledger for the Today state-flow issue set.

Update this file after each issue is implemented. Keep entries factual: what changed, what was validated, what was
deliberately left alone, and what the next session should know.

## GitHub Coordination

- Parent epic: [#248](https://github.com/justinrooks/project-arcus/issues/248)
- Sub-issues created 2026-06-15: #249 through #255
- Local Alerts follow-up sub-issues created 2026-06-16: #256 through #259
- Runbook: `docs/plans/today-state-flow-runbook.md`

## Current Status

| Order | ID | GitHub | Title | Model | Status | Notes |
|---:|---|---|---|---|---|---|
| 0 | TV-00 | [#248](https://github.com/justinrooks/project-arcus/issues/248) | Audit Today View State Flow | `gpt-5.4-mini / medium` | Planned | Parent tracking issue created from source-backed investigation. |
| 1 | TV-01 | [#249](https://github.com/justinrooks/project-arcus/issues/249) | Introduce canonical Today content state for cache roll-forward rendering | `gpt-5.4-mini / high` | Complete | Foundation boundary added; `HomeView` and `SummaryView` now share `TodayContentState`. |
| 2 | TV-02 | [#250](https://github.com/justinrooks/project-arcus/issues/250) | Keep Today section content stable during resolving refreshes | `gpt-5.4-mini / high` | Complete | Canonical Today state now stabilizes Local Alerts, Today's Awareness, and risk placeholders during cached refreshes. |
| 3 | TV-03 | [#251](https://github.com/justinrooks/project-arcus/issues/251) | Align Current Conditions and Atmospheric Conditions weather roll-forward behavior | `gpt-5.4-mini / high` | Complete | Today boundary now owns visible-weather retention so Current Conditions and Atmospheric Conditions stay aligned during same-location refresh. |
| 4 | TV-04 | [#252](https://github.com/justinrooks/project-arcus/issues/252) | Consolidate Today refresh indicators into one calm updating state | `gpt-5.4-mini / medium` | Complete | Canonical Today state now drives the lone calm update cue; section resolving treatment is suppressed during cached refresh. |
| 5 | TV-05 | [#253](https://github.com/justinrooks/project-arcus/issues/253) | Tighten Today animation and transition scope during refresh | `gpt-5.4-mini / medium` | Complete | Narrowed Today motion scope so cached-refreshing no longer rekeys alert content or participates in broad stack transitions. |
| 6 | TV-06 | [#254](https://github.com/justinrooks/project-arcus/issues/254) | Stabilize Today snapshot application and display-model updates during partial data arrival | `gpt-5.4-mini / high` | Complete | Provider progress now gates orchestration only; Today keeps cached content visible until coherent snapshot commit, and empty-success outlooks preserve cached values explicitly. |
| 7 | TV-07 | [#255](https://github.com/justinrooks/project-arcus/issues/255) | Add Today state-flow previews and transition mapping tests | `gpt-5.4-mini / medium` | Not started | Final validation/support issue after TV-01 through TV-06. |
| 8 | LA-01 | [#256](https://github.com/justinrooks/project-arcus/issues/256) | Define Local Alerts display state with cache provenance | `gpt-5.4-mini / high` | Complete | Alert-specific state semantics now preserve live vs cached provenance, cached refresh, stale/degraded, and true unavailable boundaries. |
| 9 | LA-02 | [#257](https://github.com/justinrooks/project-arcus/issues/257) | Make Local Alerts refresh treatment calm and non-duplicative | `gpt-5.4-mini / medium` | Not started | Depends on LA-01 and the page-level calm cue from TV-04. |
| 10 | LA-03 | [#258](https://github.com/justinrooks/project-arcus/issues/258) | Stabilize ActiveAlertSummaryView transitions and height behavior | `gpt-5.4-mini / high` | Not started | Alert card local state/height mechanics. Depends on LA-01/LA-02. |
| 11 | LA-04 | [#259](https://github.com/justinrooks/project-arcus/issues/259) | Add Local Alerts state-flow previews and tests | `gpt-5.4-mini / medium` | Not started | Final alert-specific validation support after LA-01 through LA-03. |

## Global Constraints

- Preserve cached-first, resolve-forward behavior.
- Preserve full-screen resolving only for true empty/no-cache startup.
- Preserve current Today layout and section visual design.
- Avoid spinner-first, shimmer, or flashy loading behavior.
- Avoid provider, persistence, notification, Map, or app-wide architecture changes unless the issue explicitly requires
  a narrow state-flow correction.
- Do not hide useful cached data during refresh.
- Do not show unavailable/offline states unless no useful cached or fresh data exists.
- Do not touch unrelated dirty files.

## Baseline Investigation

### Current Flow

1. `HomeView` reads cached `HomeProjection` and `ConvectiveOutlook` records via SwiftData `@Query`.
2. `HomeView` selects `displayedProjection` for the current location context and computes displayed values by mixing
   cached projection data with `HomeRefreshPipeline` state.
3. `TodayTabView` renders `SummaryView` with raw section inputs plus `SummaryResolutionState`.
4. `HomeRefreshPipeline` starts refreshes from scene activation, pull refresh, timer, or context change.
5. Scene activation/context change can run a non-visible prime request, then schedule a follow-up refresh.
6. Ingestion progress mutates `SummaryResolutionState` before the final `HomeSnapshot` is applied.
7. `SummaryView` and child components independently decide whether they are loading, empty, resolving, stale, current,
   or unavailable.
8. Final snapshot application updates section values, but visual state has already reacted to progress events.

### Evidence Map

- `Sources/App/HomeView.swift`
  - SwiftData cache queries: lines 20-24.
  - Cached/pipeline value selection: lines 53-135.
  - Today receives raw values plus `SummaryResolutionState`: lines 204-229.
  - Bootstrap loading helper: lines 426-434.
- `Sources/App/HomeRefreshPipeline.swift`
  - Progress event handling: lines 334-343.
  - Lane-to-section mapping: lines 346-384.
  - Prime request can skip visible commit: lines 261-272.
  - Final snapshot apply: lines 472-499.
- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
  - Progress reporting and snapshot load: lines 101-163.
  - Weather progress: lines 347-386.
- `Sources/Features/Summary/SummaryView.swift`
  - Multiple state enums: lines 10-93 and 127-132.
  - Section-level state derivation: lines 184-210, 247-343, 400-431, and 475-553.
  - Empty resolving transition: lines 436-450 and 556-576.
- `Sources/Features/Summary/SummaryStatus.swift`
  - Weather retention exists for Current Conditions: lines 31-64 and 297-313.
  - Secondary progress line animates messages: lines 373-446.
- `Sources/Features/Badges/AtmosphereRailView.swift`
  - Atmospheric Conditions derives directly from raw `weather`: lines 18-20.
  - Nil weather becomes unavailable instrumentation: lines 124-156 and 206-212.
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
  - Loading wins in local content state: lines 59-67.
  - Content identity changes on `contentState`: lines 208-213.
  - Content state animates locally: line 159.
- `Sources/Features/Summary/OutlookSummaryCard.swift`
  - Missing outlook becomes `Getting outlook details...`: lines 36-44.
  - Loading placeholder: lines 73-78.
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
  - Local alerts loading-to-empty/populated sequences: lines 446-482.
  - Risk placeholder behavior: lines 626-684.
  - Weather retention tests: lines 928-1016.
- `Tests/UnitTests/HomeRefreshPipelineTests.swift`
  - Progress mapping tests: lines 104-339.
  - Empty outlook refresh marked completed: lines 817-836.

### Primary Findings

- No single canonical Today display state exists today.
- Sections independently decide loading/empty/stale/current/unavailable.
- Provider progress is currently user-visible presentation state.
- Current Conditions and Atmospheric Conditions can disagree on weather availability.
- Local Alerts can flip through loading before empty or populated states.
- Risk and awareness placeholders are selected locally and can diverge from the desired page-level behavior.
- Refresh indicators and animations are duplicated across sections.

### Local Alerts Follow-Up Findings

- `SummaryView.LocalAlertsPresentationState` currently has only `.unavailable`, `.loading`, `.alerts`, and `.empty`,
  which does not preserve alert-specific provenance such as unknown/no-cache, known empty, stale, or degraded.
- `SummaryView` derives Local Alerts state from page state, location availability, and array emptiness, while
  `HomeProjection` separately stores `activeAlerts`, `activeMesos`, and `lastHotAlertsLoadAt`.
- `HomeView.displayedMesos` and `HomeView.displayedAlerts` switch independently between pipeline arrays and cached
  projection arrays; the Local Alerts section does not receive one stable display model describing why those arrays are
  empty or populated.
- `SummaryView.appliesLocalAlertsResolving` still allows whole-card resolving treatment for settled `.alerts` and
  `.empty` states when alert resolution is active.
- `ActiveAlertSummaryView` owns local `ContentState`, `HeightPhase`, and a delayed main-actor height reset task. Those
  mechanics can still create Local Alerts-specific churn unless constrained by an alert display-state policy.
- Existing Local Alerts tests cover several helper outcomes, but not the complete alert-specific state/provenance,
  refresh-treatment, transition, and preview matrix.

## Target State

The implementation should converge on a small layered model:

1. Raw provider/cache state.
2. Today orchestration state: no cache, cached refreshing, current, stale refreshing, degraded, unavailable.
3. Stable Today display model: section values, section presentation states, one update indicator, and transition hints.
4. SwiftUI views render the display model without independently reconstructing business state.

## Cross-Issue Decisions

Record facts that affect more than one issue here. Include the date, source issue, affected later issues, and the
decision made.

- 2026-06-15, audit: `SummaryStatus` already demonstrates same-location value retention for weather; prefer moving
  that decision up into the Today display model rather than duplicating local retention in Atmospheric Conditions.
- 2026-06-15, audit: `SummaryResolutionState` should remain useful orchestration/progress input, but provider progress
  should not directly force destructive section presentation branches.
- 2026-06-15, audit: Empty-but-known content is meaningful content. A known empty Local Alerts state should not become
  loading during ordinary refresh.
- 2026-06-16, planning: all Today state-flow issues are scoped for `gpt-5.4-mini`. Use `/high` for state-boundary,
  retained-weather, multi-section stability, and async snapshot sequencing work. Use `/medium` for coordination,
  indicators, animation scope, previews, tests, and docs. If an issue starts crossing these boundaries, split it rather
  than expanding the implementation pass.
- 2026-06-16, Local Alerts audit: the broad Today fixes have landed through TV-06, but Local Alerts still needs a
  section-specific display-state/provenance layer and card-level transition cleanup. Track this as LA-01 through LA-04
  under parent issue #248, with `/high` for provenance and height/transition semantics and `/medium` for presentation
  treatment and validation.
- 2026-06-16, LA-01 implementation: Local Alerts presentation should now be driven from `LocalAlertsDisplayState`
  instead of raw array emptiness or page-level state alone. Preserve that boundary for LA-02 through LA-04 so refresh
  treatment and height/transition cleanup do not reintroduce provenance drift.

## Issue Log Template

Copy this section for each completed or active issue.

### TV-XX / GitHub #NNN - Title

Status: Not started
Date:
Model used:

#### Scope

Describe the implemented scope in concrete bullets.

When implementing a sub-issue, list the mini-sized chunks completed from the GitHub issue body.

#### Files Changed

List every changed file.

#### Behavior Preserved

- Cached-first Today rendering preserved.
- Provider behavior preserved unless explicitly scoped.
- Refresh cadence preserved.
- Persistence preserved.
- User-facing design hierarchy preserved.

#### Validation

List every validation command run and result.

#### Deferred Work

List intentionally deferred work, or state `None`.

#### Handoff Notes

Record details the next session needs.

## Implementation Log

### TV-00 / GitHub #248 - Audit Today View State Flow

Status: Complete
Date: 2026-06-15
Model used: GPT-5 Codex

#### Scope

- Investigated Today view composition, cache loading, refresh sequencing, section-level display state, weather
  roll-forward behavior, local alert transitions, outlook behavior, and animation scope.
- Created parent issue #248 and sub-issues #249 through #255.
- Created this runbook and progress ledger for durable execution handoff.

#### Files Changed

- `docs/plans/today-state-flow-runbook.md`
- `docs/plans/today-state-flow-progress.md`

#### Behavior Preserved

- No production source files changed.
- No tests changed.
- No providers, refresh orchestration, persistence, UI layout, or SwiftUI components changed.
- No branch, commit, or PR created.

#### Validation

- Source-backed investigation only.
- GitHub issues created through the GitHub connector.
- No build or test run was required because no production or test code changed.

#### Deferred Work

- Simulator observation of the transition matrix remains for implementation/validation passes.
- No Instruments trace was captured; raw performance profiling was intentionally secondary to state-flow mapping.

#### Handoff Notes

- Start implementation with TV-01 / #249.
- Do not jump directly into card polish before the canonical Today display state exists; that repeats the current
  split-brain state pattern with fresher paint.
- Preserve the distinction between provider progress and user-visible presentation state.

### TV-01 / GitHub #249 - Introduce canonical Today content state for cache roll-forward rendering

Status: Complete
Date: 2026-06-15
Model used: GPT-5 Codex

#### Scope

- Added `TodayContentState` as the canonical Today page state with the expected page-level cases:
  - `noCacheResolving`
  - `cachedRefreshing`
  - `current`
  - `staleRefreshing`
  - `degraded`
  - `unavailable`
- Added mapping tests for no-cache resolving, cached refreshing, current content, stale refreshing, degraded cached
  content, and unavailable.
- Wired `HomeView` to derive the canonical Today state from cache availability, pipeline fallback visibility, refresh
  progress, readiness, and offline state.
- Passed the canonical state into `SummaryView` and used it at the page boundary to drive the top-level resolving
  surface, without changing the individual card visuals yet.

#### Files Changed

- `Sources/App/HomeView.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/TodayContentState.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/plans/today-state-flow-progress.md`

#### Behavior Preserved

- Cached-first rendering behavior was preserved.
- `HomeRefreshPipeline` behavior, cadence, and provider orchestration were left alone.
- Card visuals and local section presentation logic were not redesigned.
- Refresh animations and indicator behavior were not intentionally changed in this issue.
- No new provider, persistence, or data-mutation paths were added.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" test -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests/TodayContentStateTests`
  - Passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" build`
  - Passed.

#### Deferred Work

- Section-level adoption of the canonical state is deferred to #250.
- Current Conditions, Atmospheric Conditions, alerts, and risk cards still infer some loading/empty/unavailable behavior
  locally.
- Refresh indicators and animation scope were intentionally left unchanged.
- Any broader response to partial failures or richer degraded reasons is deferred.

#### Handoff Notes

- #250 should start moving section presentation decisions behind this canonical boundary instead of reading raw
  readiness/resolution booleans directly.
- `TodayContentState` is intentionally small; extend it only when a later issue proves the extra state is actually
  needed.
- `HomeRefreshPipeline` did not change, so any remaining flicker or card-by-card churn is still coming from section
  presentation logic, not the new boundary.

### TV-02 / GitHub #250 - Keep Today section content stable during resolving refreshes

Status: Complete
Date: 2026-06-15
Model used: `gpt-5.4-mini / high`

#### Scope

- Kept Local Alerts on stable surfaces during cached refreshes by driving the section from the canonical
  `TodayContentState`.
- Kept Today’s Awareness and the storm/severe/fire resolving placeholders calm during cached refreshes by gating the
  placeholder branches on the canonical Today state instead of raw refresh progress.
- Preserved true no-cache resolving behavior so the first-load loading surface still appears when Today has no useful
  content yet.
- Updated focused previews to show cached-refreshing empty alerts, cached-refreshing populated alerts, and
  cached-refreshing risk content.

#### Files Changed

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/PrimaryAwarenessPanel.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `Tests/UnitTests/SummaryAwarenessPanelTests.swift`
- `docs/plans/today-state-flow-progress.md`

#### Behavior Preserved

- Cached-first Today rendering remained intact.
- `HomeRefreshPipeline` behavior, cadence, and provider orchestration were left alone.
- True no-cache resolving still uses the calm loading surface.
- Whole-page resolving and refresh cadence policy were not redesigned.
- Weather roll-forward behavior, page-level refresh indicators, and animation policy were intentionally left for later
  issues.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" -only-testing:SkyAwareTests/SummaryViewLocalAlertsTests -only-testing:SkyAwareTests/SummaryViewRiskPlaceholderPresentationTests -only-testing:SkyAwareTests/SummaryAwarenessPanelTests/cachedRefreshingWithoutResolvedRisk_keepsPrimaryHeroCalm -only-testing:SkyAwareTests/SummaryAwarenessPanelTests/noCacheResolving_showsPrimaryLoading test`
  - Passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" build`
  - Passed.

#### Deferred Work

- Weather roll-forward consistency across Current Conditions and Atmospheric Conditions is deferred to #251.
- Consolidated Today update indicators are deferred to #252.
- Global animation and transition scope cleanup is deferred to #253.
- `HomeRefreshPipeline` restructuring and partial-arrival snapshot stabilization are deferred to #254.

#### Handoff Notes

- The next issue should keep using `TodayContentState` as the boundary and focus on weather retention rather than
  re-opening section content branching.
- Local Alerts and the Today awareness/risk surfaces now stay visually stable during cached refreshes, so any new
  churn will likely come from weather-specific value retention or page-level indicator changes.
- Do not widen this into refresh-indicator policy or animation cleanup; those belong to #252 and #253.

### TV-03 / GitHub #251 - Align Current Conditions and Atmospheric Conditions weather roll-forward behavior

Status: Complete
Date: 2026-06-15
Model used: `gpt-5.4-mini / high`

#### Scope

- Added `TodayVisibleWeatherState` as the Today display-boundary model for retained visible weather.
- Moved same-location visible-weather retention to `TodayTabView` so the Today surface resolves one visible weather
  value before rendering both weather-dependent cards.
- Passed the retained visible weather into `SummaryView`, which in turn feeds both `SummaryStatus` and
  `AtmosphericConditionsCard` from the same input.
- Removed the weather-retention state and helper from `SummaryStatus` so Current Conditions no longer owns a separate
  retention path.
- Added focused previews for:
  - cached-refreshing weather
  - no-cache resolving weather
  - unavailable weather
- Added unit coverage for same-location refresh retention and location-identity clearing.

#### Files Changed

- `Sources/App/HomeView.swift`
- `Sources/Features/Badges/AtmosphereRailView.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/TodayVisibleWeatherState.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/plans/today-state-flow-progress.md`

#### Behavior Preserved

- Cached-first Today rendering remained intact.
- Weather providers, refresh cadence, and location-resolution policy were not changed.
- The Today layout and card design were not redesigned.
- Existing cached-first and resolve-forward Today behavior was preserved.
- No broad refresh-indicator consolidation or animation-scope work was introduced.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,id=F5154D35-3398-4BEB-943E-E8D174B32832" test -only-testing:SkyAwareTests/TodayVisibleWeatherStateTests`
  - Passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,id=F5154D35-3398-4BEB-943E-E8D174B32832" build`
  - Passed.

#### Deferred Work

- Refresh-indicator consolidation is deferred to #252.
- Animation and transition scope cleanup is deferred to #253.

#### Handoff Notes

- The visible-weather decision now lives at the Today boundary; later issues should not reintroduce section-local weather
  retention.
- Atmospheric Conditions now receives the same retained weather as Current Conditions, so any remaining churn in Today
  is likely coming from refresh indicator policy or transition scope, not weather data flow.
- Keep the current boundary narrow when working on #252 and #253; they should build on this shared weather input rather
  than reopening card-level retention logic.

### TV-04 / GitHub #252 - Consolidate Today refresh indicators into one calm updating state

Status: Complete
Date: 2026-06-15
Model used: `gpt-5.4-mini / medium`

#### Scope

- Added calm cached-refresh cue helpers on `TodayContentState`.
- Routed the Current Conditions secondary line to the canonical Today cue instead of animating completed messages.
- Suppressed section-level resolving treatment during cached-refreshing so cached content stays visible without multiple
  simultaneous blur/opacity treatments.
- Suppressed local loading copy in alerts, awareness, and outlook during cached-refreshing when stable cached or
  known-empty content already exists.
- Added a focused display-model test proving cached-refreshing exposes one calm page cue and suppresses local loading
  branches.
- Added cached-refreshing and no-cache resolving previews for the Today surface.

#### Files Changed

- `Sources/Features/Summary/TodayContentState.swift`
- `Sources/Features/Summary/SummaryResolving.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Summary/OutlookSummaryCard.swift`
- `Sources/Features/Summary/PrimaryAwarenessPanel.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/plans/today-state-flow-progress.md`

#### Behavior Preserved

- Cached-first Today rendering remained intact.
- First-load no-cache resolving still shows the full-screen loading surface.
- Offline/degraded content remains visible and meaningful.
- Provider cadence, refresh sequencing, and snapshot application logic were not changed.
- The Today layout and card hierarchy were left alone.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,id=F5154D35-3398-4BEB-943E-E8D174B32832" test -only-testing:SkyAwareTests/TodayContentStateTests`
  - Passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,id=F5154D35-3398-4BEB-943E-E8D174B32832" test -only-testing:SkyAwareTests/SummaryAwarenessPanelTests`
  - Failed on pre-existing accessibility contract assertions unrelated to this issue:
    - `stormHeroAccessibilityContract_separatesCategoryValueAndHint()`
    - `fireHeroAccessibilityContract_keepsTheFireValueReadable()`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,id=F5154D35-3398-4BEB-943E-E8D174B32832" build`
  - Passed.

#### Deferred Work

- TV-05 and TV-06 remain untouched.
- The unrelated Summary Awareness accessibility-contract failures should be handled separately.

#### Handoff Notes

- `TodayContentState` now owns the calm cached-refresh cue via `showsCalmUpdatingCue`.
- `summaryResolving` now suppresses section-level resolving treatment for cached refreshes; TV-05 should tighten any
  remaining animation scope rather than reintroducing local loading branches.
- Outlook now uses neutral copy instead of "Getting outlook details…" outside true no-cache resolving.
- Keep the remaining noisy Summary Awareness accessibility tests out of this thread; they are not part of the calm
  update fix.

### TV-05 / GitHub #253 - Tighten Today animation and transition scope during refresh

Status: Complete
Date: 2026-06-16
Model used: `gpt-5.4-mini / medium`

#### Scope

- Added `TodayContentState.suppressesRoutineRefreshMotion` so cached-refreshing can explicitly opt out of routine
  branch animation.
- Removed the root `HomeView` ZStack transition so the Today stack no longer participates in an unnecessary full-screen
  fade.
- Removed `ActiveAlertSummaryView` content identity swapping and branch transition behavior, then gated its content
  animation so cached-refreshing updates stay anchored instead of crossfading empty/loading/populated branches.
- Added display-state coverage proving cached-refreshing suppresses routine refresh motion while no-cache resolving
  remains the state that is allowed to drive page entrance motion.

#### Files Changed

- `Sources/App/HomeView.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Summary/TodayContentState.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/plans/today-state-flow-progress.md`

#### Behavior Preserved

- Cached-first Today rendering preserved.
- True no-cache resolving still uses the calm loading surface and its existing entrance transition.
- Section resolving treatment still stays suppressed for cached-refreshing via the canonical Today state.
- Provider behavior, refresh cadence, and snapshot sequencing were not changed.
- Reduce Motion checks remain in the existing SwiftUI branches; no new motion policy was introduced.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" build`
  - Passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests/TodayContentStateTests`
  - First attempt failed because it collided with the concurrent build database lock.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" -derivedDataPath /private/tmp/skyaware-tv253-test test -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests/TodayContentStateTests`
  - Passed.
- `git diff --check -- Sources/App/HomeView.swift Sources/Features/Summary/ActiveAlertSummaryView.swift Sources/Features/Summary/TodayContentState.swift Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
  - Passed.

#### Deferred Work

- Simulator-level motion observation for cached-refreshing with Reduce Motion on/off remains a good follow-up sanity
  check, but the code paths now explicitly suppress the routine branch animation source.
- Refresh sequencing and partial-arrival stabilization remain deferred to #254.
- Preview/test expansion for the full transition matrix remains deferred to #255.

#### Handoff Notes

- The important motion fix is in `ActiveAlertSummaryView`: stop rekeying the alert card on `contentState` changes and
  keep cached-refreshing out of the branch animation path.
- `TodayContentState.suppressesRoutineRefreshMotion` is the narrow motion hint now available for follow-up work.
- If future motion work needs to reintroduce a broader page transition, it should be done from the canonical Today
  state boundary, not from per-card identity churn.

### TV-06 / GitHub #254 - Stabilize Today snapshot application and display-model updates during partial data arrival

Status: Complete
Date: 2026-06-16
Model used: `gpt-5.4-mini / high`

#### Scope

- Separated provider progress from destructive Today display changes by using refresh-in-flight state as the
  user-visible gating signal.
- Kept cached Today content visible while progress starts and completes before the final snapshot commit.
- Preserved cached outlook content explicitly when a fresh snapshot returns empty outlook values.
- Added degraded-state coverage so stale refreshing stays calm and useful instead of collapsing into unavailable.
- Kept the ingestion executor, provider cadence, and network/data semantics untouched.

#### Files Changed

- `Sources/App/HomeRefreshPipeline.swift`
- `Sources/App/HomeView.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Tests/UnitTests/HomeRefreshPipelineTests.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/plans/today-state-flow-progress.md`

#### Behavior Preserved

- Cached-first Today rendering preserved.
- Provider progress observability preserved internally.
- Refresh cadence preserved.
- Hot-alert and other live content remain eligible to appear as soon as their snapshot data is ready.
- No provider rewrite, serialization change, or broad Today redesign was introduced.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/HomeRefreshPipelineTests`
  - Passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests`
  - Passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" build`
  - Pending at the time of this ledger update; rerun required before final signoff.

#### Deferred Work

- TV-07 remains open for Today previews and transition mapping tests.
- Provider-side sequencing and cadence work remain out of scope.
- Any broader Outlook tab behavior beyond explicit empty-success preservation is deferred.

#### Handoff Notes

- `HomeRefreshPipeline.isRefreshInFlight` is now the narrow signal for whether Today should keep cached display state
  steady while final snapshot values are still pending.
- `HomeView` now chooses cached outlooks explicitly when live refresh output is empty; do not regress that back to
  “first live array entry wins.”
- If the next issue wants more visual polish, it should build on this stable display boundary instead of reintroducing
  raw progress-driven section resets.
- #255 should focus on preview and transition coverage, not on more display-state mechanics.

### LA-00 / GitHub #248 - Local Alerts Section State-Flow Follow-Up Audit

Status: Complete
Date: 2026-06-16
Model used: GPT-5 Codex

#### Scope

- Re-audited the Local Alerts section after the broader Today state-flow work had landed through TV-06.
- Focused on `SummaryView.LocalAlertsPresentationState`, `ActiveAlertSummaryView`, `SummaryResolutionState` alert
  progress copy, cached alert provenance in `HomeProjection`, and Local Alerts-focused tests.
- Created Local Alerts follow-up issues #256 through #259 under parent #248.
- Updated #248, this progress ledger, and the runbook with the Local Alerts issue sequence and model guidance.

#### Files Changed

- `docs/plans/today-state-flow-runbook.md`
- `docs/plans/today-state-flow-progress.md`

#### Behavior Preserved

- No production source files changed.
- No tests changed.
- No providers, refresh orchestration, persistence, UI layout, or SwiftUI components changed.
- No branch, commit, or PR created.

#### Validation

- Source-backed investigation only.
- GitHub issues #256 through #259 created through the GitHub connector.
- Parent issue #248 updated through the GitHub connector.
- No build or test run was required because no production or test code changed.

#### Deferred Work

- Implement LA-01 / #256 first so Local Alerts has explicit cache provenance before presentation/motion cleanup.
- LA-02 / #257 should remove redundant/dimming refresh treatment only after LA-01 lands.
- LA-03 / #258 should constrain `ActiveAlertSummaryView` local height/transition behavior after the alert display state
  is authoritative.
- LA-04 / #259 should add previews/tests after LA-01 through LA-03.

#### Handoff Notes

- Do not fold LA-01 through LA-03 into #255; #255 is page-level Today validation, while #256 through #259 are
  alert-section correctness and polish.
- The most important pre-LA-01 evidence was that `HomeProjection` tracks `lastHotAlertsLoadAt`, but `SummaryView`
  previously only saw array emptiness plus `TodayContentState` when choosing the Local Alerts surface.
- Keep provider cadence and hot-alert delivery semantics out of these issues unless new source evidence proves they are
  the root cause.

### LA-01 / GitHub #256 - Define Local Alerts display state with cache provenance

Status: Complete
Date: 2026-06-16
Model used: `gpt-5.4-mini / high`

#### Scope

- Added `LocalAlertsDisplayState` as the narrow display boundary for Local Alerts provenance.
- Distinguished:
  - no-cache resolving
  - current live empty/populated
  - current cached empty/populated
  - cached refreshing empty/populated
  - offline stale/degraded empty/populated
  - location unavailable
  - true unavailable / no useful alert state
- Wired `HomeView` to derive the display state from the rendered alert source, cached projection presence, and
  `lastHotAlertsLoadAt`.
- Wired `SummaryView` to derive `LocalAlertsPresentationState` from the display state before choosing the existing
  `ActiveAlertSummaryView` branches.
- Kept `ActiveAlertSummaryView` visuals and behavior unchanged.

#### Files Changed

- `Sources/App/HomeView.swift`
- `Sources/Features/Summary/LocalAlertsDisplayState.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/plans/today-state-flow-progress.md`

#### Behavior Preserved

- Cached-first Today rendering was preserved.
- `HomeRefreshPipeline` behavior, cadence, and provider orchestration were left alone.
- `ActiveAlertSummaryView` visuals, row layout, height mechanics, and transition behavior were not changed.
- Refresh cadence, notification delivery, and alert filtering semantics were not changed.
- No new provider, persistence, or data-mutation paths were added.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests/LocalAlertsDisplayStateTests -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests/SummaryViewLocalAlertsTests -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests/TodayContentStateTests`
  - Passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,id=F5154D35-3398-4BEB-943E-E8D174B32832" build`
  - Passed.

#### Deferred Work

- #257 should refine alert refresh treatment now that the provenance boundary exists.
- #258 should stabilize `ActiveAlertSummaryView` transitions and height behavior on top of the new display state.
- #259 should add preview coverage for the new alert display-state matrix and any residual presentation edge cases.

#### Handoff Notes

- `LocalAlertsDisplayState` is the new boundary for alert provenance. Use it instead of rebuilding truth from raw array
  emptiness or `TodayContentState` alone.
- `SummaryView` now treats Local Alerts presentation as derived display state, which keeps later refresh-treatment and
  transition work isolated.
- `HomeRefreshPipeline` did not change, so any remaining alert churn should be addressed in #257 or #258, not by
  reopening provider cadence or refresh sequencing here.
