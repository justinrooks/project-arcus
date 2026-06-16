# Today State Flow Runbook

Use this runbook when implementing the Today state-flow issue set derived from GitHub issue #248.

This work is a focused refinement of the existing cached-first, resolve-forward Today experience. It is not a visual
redesign, provider rewrite, refresh-cadence project, or permission to add theatrical loading behavior. The goal is a
calm, predictable landing surface where cached content appears immediately and fresh data resolves forward quietly.

## GitHub Coordination

- Parent epic: [#248](https://github.com/justinrooks/project-arcus/issues/248)
- Sub-issues: #249 through #255, ordered as listed below

## Source Of Truth

- Parent issue: [#248](https://github.com/justinrooks/project-arcus/issues/248)
- Progress ledger: `docs/plans/today-state-flow-progress.md`
- Product direction: `docs/SkyAware North Star Spec.md`
- Repository guidance: `AGENTS.md` and `Sources/AGENTS.md`
- Prior related UI polish ledger: `docs/plans/resolve-forward-ui-polish-progress.md`

## Required Read Order

Before implementing any work item:

1. Read `AGENTS.md`.
2. Read `Sources/AGENTS.md`.
3. Read `tasks/lessons.md`.
4. Read the current GitHub issue.
5. Read this runbook.
6. Read `docs/plans/today-state-flow-progress.md`.
7. Read the relevant production and test files named by the issue.
8. For SwiftUI state, animation, or preview work, use the SwiftUI expert guidance available in the workspace.
9. For async sequencing, `@MainActor`, or refresh pipeline work, use the Swift concurrency guidance available in the
   workspace.

## Non-Negotiables

- Preserve cached-first, resolve-forward behavior.
- Preserve full-screen resolving only for true no-cache startup.
- Do not replace meaningful cached content with loading, empty, unavailable, or placeholder states during refresh.
- Do not add flashy loading states, shimmer, or spinner-first behavior.
- Do not redesign the Today layout, Today's Awareness, Atmospheric Conditions, or risk cards.
- Do not change weather, SPC, NWS, Arcus, or WeatherKit data semantics.
- Do not broaden this into Map performance, notification delivery, persistence, or app-wide architecture work.
- Do not expose provider names, system jargon, or debug language in user-facing copy.
- Keep each issue independently reviewable.
- Update `docs/plans/today-state-flow-progress.md` before finishing any issue.

## Design North Star

The Today view is the landing surface for a severe-weather awareness app. It should answer what matters now without
making normal refreshes feel alarming.

Prefer:

- cached content in place
- one calm updating cue
- stable card identity
- value-level updates
- deterministic state transitions
- subtle degraded/stale treatment when useful
- true unavailable states only when no useful data exists

Avoid:

- multiple local `Getting...` messages during ordinary refresh
- empty/loading/unavailable flashes while cached data exists
- section-by-section nervous motion
- broad `.animation` scopes for refresh bookkeeping
- clearing display values before a replacement display model is ready
- presenting provider progress as product state

## Current Implementation Map

Today entry and orchestration:

- `Sources/App/HomeView.swift`
- `Sources/App/HomeRefreshPipeline.swift`
- `Sources/App/HomeRefreshPolicies.swift`
- `Sources/App/HomeRefreshV2/HomeSnapshot.swift`
- `Sources/App/HomeRefreshV2/HomeSnapshotStore.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- `Sources/App/HomeRefreshV2/HomeFreshnessState.swift`

Today/Summary UI:

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/SummaryResolving.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/PrimaryAwarenessPanel.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Summary/OutlookSummaryCard.swift`
- `Sources/Features/Badges/AtmosphereRailView.swift`
- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`
- `Sources/Features/Badges/FireWeatherRailView.swift`

Relevant tests:

- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `Tests/UnitTests/HomeRefreshPipelineTests.swift`
- `Tests/UnitTests/SummaryAwarenessPanelTests.swift`

## Baseline State Flow

Current flow:

1. `HomeView` reads cached `HomeProjection` and `ConvectiveOutlook` records through SwiftData `@Query`.
2. `HomeView` selects a cached projection for the current context, then mixes projection values with
   `HomeRefreshPipeline` values.
3. `TodayTabView` passes raw section values and `SummaryResolutionState` into `SummaryView`.
4. `HomeRefreshPipeline` starts refreshes from scene activation, pull refresh, timer, or context change.
5. Scene activation and context change can run a prime request that does not commit visible snapshot data, then schedule
   a follow-up refresh.
6. Ingestion progress events mutate `SummaryResolutionState` before the final `HomeSnapshot` is applied.
7. `SummaryView` and child components independently infer loading, empty, resolving, stale, and unavailable states.
8. Final snapshot application updates the raw values that the sections consume.

Primary fragmentation points:

- `SummaryReadinessState`, `SummaryResolutionState`, `SummaryContentPresentationState`,
  `LocalAlertsPresentationState`, and per-card booleans each encode part of the Today display truth.
- Provider progress events are consumed directly as visual state.
- Current Conditions retains weather during same-location refresh; Atmospheric Conditions does not.
- Local Alerts can intentionally transition through loading before empty or populated states.
- Risk/awareness resolving placeholders are selected locally per section.
- Refresh indicators and animations are distributed across multiple cards.

## Target Design

Use a layered model:

1. Raw provider/domain state: SwiftData cache, pipeline snapshot, ingestion progress, reachability, freshness.
2. Today orchestration state: no cache, cached refreshing, current, stale refreshing, degraded, unavailable.
3. Stable Today display model: values shown by each section, section presentation states, one update indicator, and
   transition hints.
4. SwiftUI views: render stable display models and avoid making business/state decisions in view bodies.

Suggested state shape:

```swift
enum TodayContentState: Equatable {
    case emptyResolving
    case cachedRefreshing(freshness: TodayFreshness)
    case current
    case staleRefreshing
    case degraded(reason: TodayDegradedReason)
    case unavailable(reason: TodayUnavailableReason)
}
```

Keep this boring. If the implementation starts needing a grand state-machine framework, stop and re-plan. The app
needs a clean display boundary, not a cathedral to loading.

## Model Guidance

This issue set is intentionally scoped so `gpt-5.4-mini` can execute it in sequential passes.

- Use `gpt-5.4-mini / high` for state-boundary, refresh-sequencing, retained-weather, and multi-section presentation
  work where small mistakes can create user-visible churn.
- Use `gpt-5.4-mini / medium` for issue coordination, docs, previews, focused tests, indicator copy/policy, and
  animation-scope cleanup after state correctness lands.
- Do not escalate scope just because a thread can see a tempting adjacent fix. Split the work at the issue boundary.
- Stop and re-plan if a chunk starts changing provider cadence, serializing refresh work, redesigning card layout, or
  rewriting broad `HomeRefreshPipeline` behavior.

## Ordered Work Items

| Order | ID | GitHub | Title | Model | Priority | Effort | Dependency |
|---:|---|---|---|---|---|---|---|
| 0 | TV-00 | [#248](https://github.com/justinrooks/project-arcus/issues/248) | Audit Today View State Flow | `gpt-5.4-mini / medium` | Parent | - | Tracking issue |
| 1 | TV-01 | [#249](https://github.com/justinrooks/project-arcus/issues/249) | Introduce canonical Today content state for cache roll-forward rendering | `gpt-5.4-mini / high` | P1 | M | None |
| 2 | TV-02 | [#250](https://github.com/justinrooks/project-arcus/issues/250) | Keep Today section content stable during resolving refreshes | `gpt-5.4-mini / high` | P0 | M | TV-01 |
| 3 | TV-03 | [#251](https://github.com/justinrooks/project-arcus/issues/251) | Align Current Conditions and Atmospheric Conditions weather roll-forward behavior | `gpt-5.4-mini / high` | P0 | M | TV-01 |
| 4 | TV-04 | [#252](https://github.com/justinrooks/project-arcus/issues/252) | Consolidate Today refresh indicators into one calm updating state | `gpt-5.4-mini / medium` | P1 | S/M | TV-01, TV-02 |
| 5 | TV-05 | [#253](https://github.com/justinrooks/project-arcus/issues/253) | Tighten Today animation and transition scope during refresh | `gpt-5.4-mini / medium` | P1 | S/M | TV-01, TV-02, TV-04 |
| 6 | TV-06 | [#254](https://github.com/justinrooks/project-arcus/issues/254) | Stabilize Today snapshot application and display-model updates during partial data arrival | `gpt-5.4-mini / high` | P1 | M | TV-01 |
| 7 | TV-07 | [#255](https://github.com/justinrooks/project-arcus/issues/255) | Add Today state-flow previews and transition mapping tests | `gpt-5.4-mini / medium` | P2/P3 | M | TV-01 through TV-06 |

## Work Item Contracts

### TV-01: Canonical Today Content State

Introduce the smallest display-state boundary that distinguishes no cache, cached refreshing, current, stale/degraded,
and unavailable. Keep raw provider progress out of SwiftUI section decision logic.

Recommended model: `gpt-5.4-mini / high`.

Mini-sized chunks:

1. Add failing mapping tests for no cache, cached refresh, stale/degraded, unavailable, and partial failure inputs.
2. Introduce the smallest `TodayContentState` and section-display model needed for those tests.
3. Wire `HomeView`/`SummaryView` to consume display state at the boundary without changing section visuals yet.
4. Run focused mapping tests and app build.

Likely files: `HomeView.swift`, `HomeRefreshPipeline.swift`, `SummaryView.swift`, focused tests.

### TV-02: Stable Section Content

Make cached populated and cached empty section content remain visually stable during refresh. Do not transition through
loading unless the section has no meaningful prior state.

Recommended model: `gpt-5.4-mini / high`.

Mini-sized chunks:

1. Test cached empty alerts and cached populated alerts during active refresh.
2. Refactor local-alert presentation to consume Today section display state.
3. Refactor risk and awareness placeholders to respect canonical content state.
4. Update focused previews and run focused tests/build.

Likely files: `SummaryView.swift`, `ActiveAlertSummaryView.swift`, `PrimaryAwarenessPanel.swift`, risk badge views,
focused tests.

### TV-03: Weather Roll-Forward Consistency

Move same-location weather retention out of `SummaryStatus`-only behavior so Current Conditions and Atmospheric
Conditions render from the same visible-weather decision.

Recommended model: `gpt-5.4-mini / high`.

Mini-sized chunks:

1. Test same-location refresh retention and location-identity clearing.
2. Move/expose the visible-weather decision at the Today display-model boundary.
3. Pass retained visible weather to both Current Conditions and Atmospheric Conditions.
4. Add focused previews and run focused tests/build.

Likely files: `HomeView.swift`, `SummaryView.swift`, `SummaryStatus.swift`, `AtmosphereRailView.swift`, focused tests.

### TV-04: Calm Updating Indicator

Consolidate normal refresh feedback into one page-level or top-section cue. Suppress local loading copy when stable
cached or known-empty content exists.

Recommended model: `gpt-5.4-mini / medium`.

Mini-sized chunks:

1. Test that cached-refreshing exposes one update indicator.
2. Route the Current Conditions secondary line or page cue from canonical update state.
3. Suppress local `Getting...` copy where stable content exists.
4. Add cached-refreshing and no-cache resolving previews.

Likely files: `SummaryView.swift`, `SummaryStatus.swift`, `SummaryResolving.swift`, `ActiveAlertSummaryView.swift`,
`OutlookSummaryCard.swift`, `PrimaryAwarenessPanel.swift`.

### TV-05: Animation Scope

Narrow refresh animations to meaningful value changes. Avoid full-content transitions, identity swaps, or broad
section animation for routine cached refreshes.

Recommended model: `gpt-5.4-mini / medium`.

Mini-sized chunks:

1. Test that cached-refreshing does not request a full-content transition.
2. Guard broad Today stack transitions so they apply only to true no-cache resolving.
3. Adjust active-alert identity transitions for routine refresh.
4. Verify Reduce Motion through previews or simulator observation.

Likely files: `HomeView.swift`, `SummaryView.swift`, `SummaryResolving.swift`, `ActiveAlertSummaryView.swift`,
`PrimaryAwarenessPanel.swift`, `SummaryStatus.swift`.

### TV-06: Snapshot And Partial Arrival Stability

Separate provider progress from user-visible display commits. Apply final values in coherent display-model updates,
preserve cached display values on partial failure, and make empty outlook semantics explicit.

Recommended model: `gpt-5.4-mini / high`.

Mini-sized chunks:

1. Test progress-started and progress-completed-before-snapshot display mapping.
2. Map progress to non-destructive updating/degraded hints.
3. Preserve cached Today outlook when fresh snapshot content is empty and useful cached outlook exists.
4. Add partial-failure/degraded tests and run focused pipeline tests/build.

Likely files: `HomeRefreshPipeline.swift`, `HomeIngestionExecutor.swift`, `HomeSnapshot.swift`,
`HomeSnapshotStore.swift`, `HomeRefreshPipelineTests.swift`.

### TV-07: Previews And Tests

Add durable validation for the target state matrix: no cache, cached refreshing, stale, degraded, unavailable, and
large Dynamic Type/color-scheme variants.

Recommended model: `gpt-5.4-mini / medium`.

Mini-sized chunks:

1. Add transition mapping unit tests for the final Today state matrix.
2. Add Summary/Today preview fixtures for no-cache, cached-refreshing, stale/degraded, unavailable, light/dark, and
   Large Dynamic Type.
3. Add one smoke UI test only if unit tests and previews cannot cover the scenario cleanly.
4. Record validation results in the progress ledger.

Likely files: `HomeViewLoadingOverlayStateTests.swift`, `HomeRefreshPipelineTests.swift`, `SummaryView.swift`, any new
Today display-model test file.

## Validation Expectations

At minimum:

- Run focused unit tests when derived state or transition mapping changes.
- Build the app target when production Swift changes.
- Inspect relevant previews or Simulator states when SwiftUI layout, copy, or motion changes.
- Inspect `.xcresult` on test failure.
- Update `docs/plans/today-state-flow-progress.md` before finishing.

Preferred build command:

```sh
xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build
```

Use focused `-only-testing:` filters for issue-specific tests.

## Scenario Matrix

Every implementation pass should preserve or improve these scenarios:

| Scenario | Expected behavior |
|---|---|
| First launch with no cache | Show calm resolving surface only because no meaningful content exists. |
| Launch with valid cache | Show cached content immediately; begin refresh quietly. |
| Launch with stale cache | Show stale/cached content with subtle freshness treatment; do not hide content. |
| Refresh succeeds with cache | Keep content in place; update changed values intentionally. |
| Partial refresh failure with cache | Keep cached content; show degraded/freshness treatment only where useful. |
| Full refresh failure with no cache | Show true unavailable/resolving failure state calmly. |
| Watch/risk data changes visible | Update affected values without animating the whole stack. |
| Atmospheric values update visible | Keep instrumentation stable; update changed measurements. |
| Local Alerts update visible | Avoid loading-to-empty-to-alerts churn; show new alerts promptly. |
| App returns foreground | Cached content remains first paint; refresh indicator is subtle. |
| Tab switch away/back | Do not restart visual resolving theater for existing content. |
| Light/dark/large Dynamic Type | No clipping, overlap, or accidental hierarchy shifts. |

## Progress Handoff Requirement

Before finishing any issue, update:

- `docs/plans/today-state-flow-progress.md`

Record:

- issue status
- files changed
- behavior intentionally preserved
- validation run
- screenshots/previews inspected, if any
- deferred work
- risk notes for the next issue

The next agent should be able to resume without psychic powers. We keep those off by default for battery life.
