# Today State Flow Progress

This is the durable handoff ledger for the Today state-flow issue set.

Update this file after each issue is implemented. Keep entries factual: what changed, what was validated, what was
deliberately left alone, and what the next session should know.

## GitHub Coordination

- Parent epic: [#248](https://github.com/justinrooks/project-arcus/issues/248)
- Sub-issues created 2026-06-15: #249 through #255
- Runbook: `docs/plans/today-state-flow-runbook.md`

## Current Status

| Order | ID | GitHub | Title | Model | Status | Notes |
|---:|---|---|---|---|---|---|
| 0 | TV-00 | [#248](https://github.com/justinrooks/project-arcus/issues/248) | Audit Today View State Flow | `gpt-5.4-mini / medium` | Planned | Parent tracking issue created from source-backed investigation. |
| 1 | TV-01 | [#249](https://github.com/justinrooks/project-arcus/issues/249) | Introduce canonical Today content state for cache roll-forward rendering | `gpt-5.4-mini / high` | Complete | Foundation boundary added; `HomeView` and `SummaryView` now share `TodayContentState`. |
| 2 | TV-02 | [#250](https://github.com/justinrooks/project-arcus/issues/250) | Keep Today section content stable during resolving refreshes | `gpt-5.4-mini / high` | Not started | Depends on TV-01. Highest visible flicker risk. |
| 3 | TV-03 | [#251](https://github.com/justinrooks/project-arcus/issues/251) | Align Current Conditions and Atmospheric Conditions weather roll-forward behavior | `gpt-5.4-mini / high` | Not started | Depends on TV-01. Header/weather split is source-backed. |
| 4 | TV-04 | [#252](https://github.com/justinrooks/project-arcus/issues/252) | Consolidate Today refresh indicators into one calm updating state | `gpt-5.4-mini / medium` | Not started | Depends on TV-01 and TV-02. |
| 5 | TV-05 | [#253](https://github.com/justinrooks/project-arcus/issues/253) | Tighten Today animation and transition scope during refresh | `gpt-5.4-mini / medium` | Not started | Depends on TV-01, TV-02, and TV-04. |
| 6 | TV-06 | [#254](https://github.com/justinrooks/project-arcus/issues/254) | Stabilize Today snapshot application and display-model updates during partial data arrival | `gpt-5.4-mini / high` | Not started | Depends on TV-01. Keep provider progress internal. |
| 7 | TV-07 | [#255](https://github.com/justinrooks/project-arcus/issues/255) | Add Today state-flow previews and transition mapping tests | `gpt-5.4-mini / medium` | Not started | Final validation/support issue after TV-01 through TV-06. |

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
