# Today Refresh Performance Progress

## Overview

This ledger tracks the campaign to make SkyAware foreground Today refresh faster and visually stable. It is the durable
handoff record for issue status, implementation decisions, validation evidence, and residual risk.

**Epic status:** Planned
**Primary GitHub epic:** [#318](https://github.com/justinrooks/project-arcus/issues/318)

## Global Decisions

- Preserve the unified ingestion pipeline; reliability is not the problem being solved.
- Fix projection publication before tuning view transitions. UI animation cannot compensate for partial data truth.
- Keep cached content visible until a coherent replacement snapshot is ready.
- Preserve hot-alert priority while overlapping only demonstrably independent actor work.
- Separate optional enrichment latency from core Today readiness through explicit, owned stages.
- Keep stable outer SwiftUI identity for Local Alerts and optional sections.
- Measure on a physical device before and after implementation; simulator observation alone is insufficient.
- Default implementation to `GPT-5.6 Luna / medium` except issues 02 and 07, which require
  `GPT-5.6 Terra / medium` because they cross persistence/concurrency/UI publication boundaries.
- No issue currently justifies Sol. Escalate only after the active issue proves its documented boundary insufficient.

## Current State Summary

Foreground entry points submit work through `HomeRefreshPipeline`, `HomeIngestionCoordinator`, and
`HomeIngestionExecutor`. The coordinator reliably coalesces requests, providers and repositories remain actor-isolated,
and final pipeline application is synchronous on the main actor.

The largest publication defect is downstream of ingestion: `HomeProjectionStore.fetchOrCreateModel` saves before the
caller mutates a projection slice, and the executor persists weather, slow products, and hot alerts through separate
operations. A new projection can therefore satisfy `HomeView`'s cached-content check before coherent Today content
exists, followed by multiple SwiftData query invalidations as slices arrive.

Independent hot and slow provider work is serialized, while Storm Setup and AQI are also awaited serially before the
executor returns its single snapshot. SwiftUI then has residual identity problems: Local Alerts bypasses its stable
card container for the empty branch, Storm Setup omits its loading slot from the section plan, and continuous header
progress drives layout animation through the Summary hierarchy.

## Issue Sequence

| Order | Issue | Title | Preferred model | Status | Dependency |
|---:|---|---|---|---|---|
| 0 | [#318](https://github.com/justinrooks/project-arcus/issues/318) | Epic: Make Today Refresh Fast and Visually Stable | Coordination | Planned | Completed investigation |
| 1 | [#319](https://github.com/justinrooks/project-arcus/issues/319) | Establish Today refresh performance baselines | `GPT-5.6 Luna / medium` | Planned | None |
| 2 | [#320](https://github.com/justinrooks/project-arcus/issues/320) | Publish coherent Home projections atomically | `GPT-5.6 Terra / medium` | Planned | #319 |
| 3 | [#321](https://github.com/justinrooks/project-arcus/issues/321) | Keep Local Alerts structurally stable across content changes | `GPT-5.6 Luna / medium` | Planned | #320 |
| 4 | [#322](https://github.com/justinrooks/project-arcus/issues/322) | Reserve a stable Storm Setup section slot | `GPT-5.6 Luna / medium` | Planned | #321 |
| 5 | [#323](https://github.com/justinrooks/project-arcus/issues/323) | Parallelize independent ingestion work within priority lanes | `GPT-5.6 Luna / medium` | Planned | #322 |
| 6 | [#324](https://github.com/justinrooks/project-arcus/issues/324) | Run optional enrichment concurrently | `GPT-5.6 Luna / medium` | Planned | #323 |
| 7 | [#325](https://github.com/justinrooks/project-arcus/issues/325) | Publish core Today content before optional enrichment | `GPT-5.6 Terra / medium` | Planned | #324 |
| 8 | [#326](https://github.com/justinrooks/project-arcus/issues/326) | Isolate continuous Today header rendering | `GPT-5.6 Luna / medium` | Planned | #325 |
| 9 | [#327](https://github.com/justinrooks/project-arcus/issues/327) | Prove end-to-end Today refresh smoothness | `GPT-5.6 Luna / medium` | Planned | #319-#326 |

## Existing Code Map

- Lifecycle and visible publication: `Sources/App/HomeRefreshPipeline.swift`
- Request planning and lanes: `Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift`
- Request joining and sequencing: `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- Feed execution and projection persistence: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Snapshot assembly: `Sources/App/HomeRefreshV2/HomeSnapshotStore.swift`
- Optional enrichment: `Sources/App/HomeRefreshV2/HomeStormSetupIngestion.swift`
- Projection persistence: `Sources/Repos/HomeProjectionStore.swift`
- Today cache/display mapping: `Sources/App/HomeView.swift`, `Sources/App/HomeView+PresentationState.swift`
- Root Today scrolling: `Sources/App/TodayTabView.swift`
- Summary composition and Storm Setup slots: `Sources/Features/Summary/SummaryView.swift`,
  `Sources/Features/StormSetup/StormSetupPresentation.swift`
- Local Alerts rendering: `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- Continuous header rendering: `Sources/Features/Summary/SummaryStatus.swift`
- Focused tests: `Tests/UnitTests/HomeProjectionStoreTests.swift`, `Tests/UnitTests/HomeRefreshPipelineTests.swift`,
  `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`, `Tests/UnitTests/StormSetupIngestionTests.swift`,
  `Tests/UnitTests/SummaryViewLocalAlertsStateTests.swift`, `Tests/UnitTests/SummaryViewLoadingStateTests.swift`,
  `Tests/UnitTests/SummarySectionPlanTests.swift`, `Tests/UnitTests/TodayContentStateTests.swift`

## Investigation Notes

- A `HomeProjection` record currently means both “some durable slice exists” and “Today has coherent cached content.”
  Those are different contracts and must not remain conflated.
- `fetchOrCreateModel` saves an inserted or touched model before the slice operation saves its payload.
- Foreground prime is hot-alert-only and can persist before the full follow-up refresh, making first-visible readiness
  especially important for new location projections.
- `HomeIngestionExecutor.run` executes hot alerts, slow products, and weather in series.
- Mesos/Arcus alert sync and SPC map/outlook sync are independent actor operations; existing SPC code already uses
  structured parallelism elsewhere.
- Storm Setup may wait for its foreground timeout, and AQI follows it serially, before the single snapshot returns.
- `ActiveAlertSummaryView.body` replaces the full card with a separate no-active rail for `.empty`, bypassing the
  transition and height machinery completed under issue #258.
- Storm Setup computes a loading slot but only inserts the section when the state is visible, so loading-to-visible
  changes section structure.
- `TodayTabView` publishes near-continuous condense progress, while `SummaryStatus` applies implicit animation to
  spacing, padding, radius, shadow, and font-related layout derived from that progress.
- The prior Today state-flow epic solved destructive progress mapping and cache-forward display semantics. This
  campaign addresses residual persistence publication, latency, identity, and rendering mechanisms rather than
  reopening that architecture wholesale.

## Status Ledger

### Issue #319 — 01: Establish Today refresh performance baselines

- Status: Instrumentation complete; physical-device capture pending (not complete)
- Scope: Capture Release/device traces and a deterministic signpost/state timeline for cold no-cache, warm cache,
  pull-to-refresh, alerts-to-empty, and optional enrichment. Add low-overhead signposts only where current logs cannot
  answer lane, save, or visible-commit timing.

#### Files changed

- `Sources/App/HomeRefreshPipeline.swift` — emits `Today Visible Commit` after the visible snapshot state is applied.
- `Sources/Features/Summary/SummaryView.swift` — emits `Today Summary Render` for coherent `.current` or `.degraded`
  content states.
- `Sources/Repos/HomeProjectionStore.swift` — wraps each projection save with named intervals:
  `Projection Create Save`, `Projection Touch Save`, `Projection Weather Save`, `Projection Storm Setup Save`,
  `Projection Slow Products Save`, and `Projection Hot Alerts Save`.
- `docs/plans/today-refresh-performance-progress.md` — this evidence and handoff entry.

#### Scenario procedure

Use a Release build on the same unlocked physical device for every run. Start a new SwiftUI Instruments recording for
each scenario, collect the `com.skyaware.app` signposts and SwiftUI/Animation Hitches lanes, and save traces under
`/private/tmp/SkyAware-319-traces/` with the scenario name and UTC timestamp. Record the first `Today Visible Commit`,
the first following `Today Summary Render`, every projection-save interval, lane log boundary, and the SwiftUI and
hitches summaries.

1. Cold launch/no usable Today cache: delete app data, terminate the app, start recording, launch, and stop after the
   first coherent Summary render and all foreground refresh work settles. Confirm the timeline includes projection
   creation and every save/publication.
2. Warm foreground activation/valid cache: seed valid Today content, terminate while preserving data, start recording,
   launch, background and foreground once, then stop after the activation refresh settles.
3. Pull-to-refresh/cached content: with valid cached content visible, start recording, pull to refresh once, and stop
   after the refresh completion and optional enrichment settle.
4. Local Alerts populated-to-authoritative-empty: use a deterministic/device fixture or controlled feed response that
   first has alerts and then returns authoritative empty, record both refreshes, and stop after the empty state renders.
5. Storm Setup: run loading-to-success with an eligible profile; separately run loading-to-timeout with the foreground
   timeout path where reproducible. Stop after each terminal state renders.

#### Baseline metrics and trace paths

No physical-device traces were captured in this workspace. Consequently all required baseline metrics are `N/A`, not
zero: time to first useful content, time to coherent core commit, optional-enrichment completion, projection
save/publication count, relevant SwiftUI body-update evidence, hitch count, and total hitch time. The required cold
launch timeline is also not available. Intended artifact directory: `/private/tmp/SkyAware-319-traces/`; no `.trace`
bundles were created or added to the repository.

#### Instrumentation and existing telemetry

Existing `Logger.appHomeRefresh` logs already expose foreground refresh start/finish, location resolution, hot-alert,
slow-product, and weather lane boundaries, plus Storm Setup/AQI completion context. Existing logs did not expose every
projection save or a visible-commit/Summary-render boundary, so the three production files above add only static,
payload-free signposts. No coordinates, location summaries, alert content, identifiers, or weather payloads are logged.

#### Device/build metadata

- Capture date: not captured; ledger update date is 2026-07-19.
- Source SHA before uncommitted instrumentation: `024658f1d94f472225b86d4bd2b9df16c3728974`.
- Xcode: `26.6 (17F113)`.
- Required physical device/OS: unavailable; `record_trace.py --list-devices` could not enumerate devices because
  `xctrace list devices` aborted with `SIGABRT`.
- Validation build: Debug simulator build, iOS Simulator SDK 26.5, destination `platform=iOS Simulator,name=iPhone 17`.
  This build validates compilation only and is not performance evidence.
- Required Release physical-device configuration and OS: not run.

#### Validation performed

- `git diff --check` — passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
  — passed after instrumentation compile fix.
- No tests run because the change is instrumentation-only and no production logic changed.
- No `.xcresult` was generated; there is no result bundle to inspect.

#### Measurement limitations and residual risks

The issue cannot be closed from this environment because SwiftUI Instruments and Animation Hitches require Release
physical-device captures, and no usable physical-device capture path was available. Simulator behavior must not be
used as a substitute. The Summary render event is emitted for each coherent-state body evaluation; use the first event
after `Today Visible Commit` for the cold-launch render boundary. Existing logger messages remain the source for lane
boundaries; their timestamps should be correlated with the signposts in Instruments. Runtime behavior, ordering,
publication semantics, layout, transitions, and animation were intentionally left unchanged.

#### Final status

Instrumentation is ready and compiles. #319 remains pending until the five required Release/physical-device scenarios
are captured and their exact metrics and trace paths are appended here. Do not begin #320 from this state.

### Issue #320 — 02: Publish coherent Home projections atomically

- Status: Planned
- Scope: Establish one actor-isolated visible projection commit for authorized core slices; prevent a hot-only prime
  from creating a projection that Today treats as display-ready; preserve updates to established projections.
- Validation target: `HomeProjectionStoreTests`, `HomeRefreshPipelineTests`, first-visible state sequence, projection
  save/publication count, and Debug build.
- Handoff: Use `GPT-5.6 Terra / medium`. Avoid schema change; stop and re-plan if a durable readiness field is proven
  necessary. Preserve risk-profile delta and widget semantics.

### Issue #321 — 03: Keep Local Alerts structurally stable across content changes

- Status: Planned
- Scope: Close the residual outer-branch gap left after #258 by keeping one Local Alerts container/card identity and
  transitioning only its content.
- Validation target: Populated-to-empty, empty-to-populated, cached-refreshing, degraded, sheet-selection, Reduce
  Motion, and Dynamic Type scenarios plus focused tests and Debug build.
- Handoff: Do not redesign rows, sorting, navigation, or alert business state.

### Issue #322 — 04: Reserve a stable Storm Setup section slot

- Status: Planned
- Scope: Represent loading/visible/unavailable/hidden slot semantics explicitly in the section plan so loading-to-
  visible does not insert a new unreserved section.
- Validation target: `SummarySectionPlanTests`, Storm Setup slot-state tests, state-sequence preview/simulator evidence,
  and Debug build.
- Handoff: Do not change Storm Setup eligibility, endpoint, detail content, or global Summary ordering.

### Issue #323 — 05: Parallelize independent ingestion work within priority lanes

- Status: Planned
- Scope: Overlap independent hot-source and slow-source actor calls using structured concurrency while retaining lane
  priority, progress phases, freshness updates, and deterministic outcome aggregation.
- Validation target: Gate-controlled concurrency tests proving overlap without wall-clock assertions; coordinator and
  ingestion suites; baseline comparison; Debug build.
- Handoff: Do not parallelize location preparation with dependent work or launch all lanes indiscriminately.

### Issue #324 — 06: Run optional enrichment concurrently

- Status: Planned
- Scope: Start eligible Storm Setup and AQI work concurrently after core snapshot assembly and preserve independent
  timeout, cancellation, failure, and persistence semantics.
- Validation target: Gate-controlled start/join tests, Storm Setup ingestion tests, failure/timeout matrix, signpost
  comparison, and Debug build.
- Handoff: This issue reduces additive optional latency only. It does not introduce staged visible commits.

### Issue #325 — 07: Publish core Today content before optional enrichment

- Status: Planned
- Scope: Add an explicitly owned staged-publication path so the coherent core snapshot returns and commits before
  optional enrichment, whose later result merges through stable UI slots.
- Validation target: Core-success/enrichment-slow, enrichment-success, timeout, failure, cancellation, superseding
  refresh, and location-change tests; pipeline/coordinator suites; device trace; Debug build.
- Handoff: Use `GPT-5.6 Terra / medium`. No detached work. The coordinator or another explicit owner must govern
  cancellation, supersession, and location identity. Stop if more than five production files are required.

### Issue #326 — 08: Isolate continuous Today header rendering

- Status: Planned
- Scope: Remove continuously retargeted implicit layout animation, limit condense-progress invalidation to the header,
  and address only presentation derivation hotspots confirmed by issue 01 or updated Instruments evidence.
- Validation target: Slow/fast scroll and refresh-while-scrolling device traces, Reduce Motion, Dynamic Type, focused
  presentation tests, and Debug build.
- Handoff: Do not redesign the Summary, introduce speculative caching, or optimize small collections without evidence.

### Issue #327 — 09: Prove end-to-end Today refresh smoothness

- Status: Planned
- Scope: Run the full state/refresh matrix, focused regression suite, Debug build, and before/after Release/device
  Instruments comparison. Fix only documentation or test-fixture defects; file new issues for residual production work.
- Validation target: Final metrics, trace references, test counts, `.xcresult` inspection, build result, and completed
  progress ledger.
- Handoff: This is a proof/closure issue, not a container for late production fixes.

## Verification Ledger

| Date | Issue | Verification | Result |
|---|---|---|---|
| 2026-07-19 | Investigation | End-to-end source audit of foreground ingestion, projection persistence, Today state mapping, Summary identity, and scroll rendering | Complete |
| 2026-07-19 | Investigation | Focused simulator suites; `.xcresult` inspected at `/private/tmp/SkyAware-IngestionAudit/Logs/Test/Test-SkyAware-2026.07.19_11-32-03--0600.xcresult` | Passed: 88 tests, 0 failures, 0 skipped |
| 2026-07-19 | Planning | Existing labels and related issues #248, #253, #254, and #258 inspected; campaign boundaries reconciled with completed work | Complete |
| 2026-07-19 | Planning | Epic #318 and sequential children #319-#327 created and verified; runbook/progress links patched; stale-placeholder scan clean | Complete |

## Handoff Notes

- Execute issues in order and update the matching ledger entry before closing each issue.
- Record exact files, observable behavior, commands, test counts, `.xcresult` findings, trace artifact locations, and
  residual risk.
- Compare each performance slice against issue 01's baseline rather than relying on subjective simulator impressions.
- If an issue discovers a correctness defect outside its boundary, record evidence and open a follow-up; do not absorb
  it into the active diff.
- Stop and re-plan if work requires server changes, feed semantics, background cadence, SwiftData migration,
  unstructured concurrency, or a broad Today redesign.
