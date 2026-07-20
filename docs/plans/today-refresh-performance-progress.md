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
| 7 | [#325](https://github.com/justinrooks/project-arcus/issues/325) | Publish core Today content before optional enrichment | `GPT-5.6 Terra / medium` | Complete | #324 |
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

Physical-device Release traces are available for warm launch, pull-to-refresh, and Storm Setup's fresh-cache skip path
under `/private/tmp/SkyAware-319-traces/`. They are not repository artifacts.

- Warm launch: `warm-events-launch-20260719.trace` and `warm-events-launch-20260719-analysis.{json,md}`. First
  foreground refresh started at 1,458.257 ms and finished at 3,189.896 ms (logged duration 1,594 ms). The first
  visible commit was 3,926.712 ms and the first following coherent Summary render was 3,937.825 ms. The trace showed
  14 projection-save intervals across two observed refresh cycles. SwiftUI: 10,716 body updates; 112 high-severity
  events. Hitches: 8 app hitches, 150.05 ms total, 41.68 ms worst.
- Pull-to-refresh: `pull-events-20260719.trace` and `pull-events-20260719-analysis.{json,md}`. Two manual refresh
  cycles were observed; the first started at 18,319.189 ms and finished at 20,589.369 ms (logged duration 2,269 ms),
  with visible commit at 20,589.351 ms and first following Summary render at 20,593.258 ms. Six projection-save
  intervals were observed per manual cycle. SwiftUI: 14,285 body updates; 109 high-severity events. Hitches: 12 app
  hitches, 141.73 ms total, 16.67 ms worst.
- Storm Setup: `storm-setup-success-20260719.trace` and `storm-setup-success-20260719-analysis.{json,md}`. The
  eligible configuration was captured, but the provider returned `skipped / fresh-cache` (43–46 ms) rather than a
  loading-to-success transition. SwiftUI: 10,354 body updates; 82 high-severity events. Hitches: 16 app hitches,
  425.19 ms total, 75.02 ms worst.
- Cold no-cache Today: not captured successfully. `cold-no-cache-20260719.trace` captured onboarding rather than
  Today; `cold-events-20260719.trace` had the same issue. The later `cold-today-events-20260719.trace` reached Today
  after onboarding but xctrace finalization hung and the bundle failed `xctrace export` with `Document Missing Template
  Error`; it is not evidence.
- Local Alerts populated-to-authoritative-empty: not reproduced. The observed live refreshes remained populated
  (`alerts=1`); no authoritative-empty transition was recorded.
- Time to optional-enrichment completion: not separately measurable in these traces because no dedicated enrichment
  completion signpost exists and Storm Setup was fresh-cache skipped. Record the existing Storm Setup/AQI logs when a
  non-skipped run is captured.

The required cold-launch save/publication timeline, authoritative-empty transition, and Storm Setup loading/success or
timeout evidence remain outstanding. Intended artifact directory: `/private/tmp/SkyAware-319-traces/`; no `.trace`
bundles are committed to the repository.

#### Instrumentation and existing telemetry

Existing `Logger.appHomeRefresh` logs already expose foreground refresh start/finish, location resolution, hot-alert,
slow-product, and weather lane boundaries, plus Storm Setup/AQI completion context. Existing logs did not expose every
projection save or a visible-commit/Summary-render boundary, so the three production files above add only static,
payload-free signposts. No coordinates, location summaries, alert content, identifiers, or weather payloads are logged.

#### Device/build metadata

- Capture date: 2026-07-19 (America/Denver); all listed physical-device captures were made on this date.
- Source SHA before instrumentation: `024658f1d94f472225b86d4bd2b9df16c3728974`; instrumentation commit/build source:
  `b963fa63eb08997ce24872178af5294f63333251`.
- Xcode: `26.6 (17F113)`.
- Physical device: `Js14Max`, UDID `00008120-001A744E1193C01E`, iOS `26.5.2`.
- Release build: Xcode `26.6 (17F113)`, iPhoneOS SDK `26.5`, installed from
  `/private/tmp/SkyAware-319-ReleaseDerivedData/Build/Products/Release-iphoneos/SkyAware.app`.
- Debug simulator build: iOS Simulator SDK 26.5, destination `platform=iOS Simulator,name=iPhone 17`; compilation-only
  validation and not performance evidence.

#### Validation performed

- `git diff --check` — passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
  — passed after instrumentation compile fix.
- No tests run because the change is instrumentation-only and no production logic changed.
- No `.xcresult` was generated; there is no result bundle to inspect.

#### Measurement limitations and residual risks

The physical capture path is now working, but the required scenario matrix is incomplete. Simulator behavior must not
be used as a substitute. The Summary render event is emitted for each coherent-state body evaluation; use the first
event after `Today Visible Commit` for a render boundary. Existing logger messages remain the source for lane
boundaries; correlate them with signposts in Instruments. Runtime behavior, ordering, publication semantics, layout,
transitions, and animation were intentionally left unchanged.

#### Final status

Instrumentation is ready and compiles. Partial Release/device evidence is recorded, but #319 remains pending until a
valid cold Today timeline, populated-to-authoritative-empty Alerts transition, and reproducible Storm Setup terminal
state capture are appended here. Do not begin #320 from this state.

### Issue #320 — 02: Publish coherent Home projections atomically

- Status: Complete
- Scope: One actor-isolated core projection commit for authorized weather, slow-product, and hot-alert mutations;
  display readiness from existing durable load timestamps; no schema change.

#### Files changed

- `Sources/Repos/HomeProjectionStore.swift` — adds the one-save `commitCore` boundary, derives risk deltas from the
  persisted profile in that actor, and avoids create/touch saves before payload mutation.
- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift` — sends all authorized core mutations through `commitCore`.
- `Sources/App/HomeView+PresentationState.swift` — treats a projection as Today-ready only when weather,
  slow-products, and hot-alert timestamps are all durable.
- `Tests/UnitTests/HomeProjectionStoreTests.swift` — adds core-commit, hot-only readiness, empty-alert, risk-delta,
  skipped-slice, and real SwiftData reopen coverage.
- `Tests/UnitTests/HomeViewStateTests.swift` — makes cached projection fixtures explicitly coherent.

#### Final persistence/readiness contract

A new projection is inserted and mutated before its first core save. A core commit applies every authorized weather,
slow-product, and hot-alert mutation within `HomeProjectionStore`, computes a risk change from the previous persisted
profile in the same actor operation, then performs one `Projection Core Save`. Existing projections retain any slice
not authorized by that commit. A `HomeView` cache is display-ready only when all three existing durable core load
timestamps are non-nil; no new SwiftData field or migration was needed. Explicit fetch/create and Storm Setup retain
their individually atomic saves, but an auxiliary-only or hot-only record is not a coherent Today cache.

#### Observable behavior and publication evidence

The no-cache foreground path stays resolving after a hot-only prime because the durable weather and slow-product
timestamps remain absent. It becomes eligible as cached Today content only after the coherent core commit. Warm cache
selection continues to expose the already coherent record while a replacement is being prepared; skipped or failed
lanes do not clear prior values. Location-key filtering remains unchanged, so another context's projection cannot be
selected after a location change.

Before this change, the #319 signposts could show `Projection Create Save`/`Projection Touch Save` followed by
independent `Projection Weather Save`, `Projection Slow Products Save`, and `Projection Hot Alerts Save` intervals.
After this change, a full foreground core persistence path produces one `Projection Core Save`; create/touch signposts
remain only for explicit fetch/create. Deterministic state-publication tests verify that the first-visible projection is
not selectable until that commit. This is code/test evidence, not a comparable physical-device trace.

#### Validation

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/HomeProjectionStoreTests -only-testing:SkyAwareTests/HomeRefreshPipelineTests test` — passed.
  `.xcresult`: `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.07.19_16-52-42--0600.xcresult`; 64 passed, 0 failed, 0 skipped.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build` — passed.
- `git diff --check` — passed.

#### Assumptions and residual risks

The readiness rule deliberately requires all three durable core timestamps; legacy or specialized-only records remain
non-display-ready until a coherent foreground core commit. The #319 cold no-cache, authoritative-empty, and Storm
Setup device scenarios are still incomplete. No quantitative device-performance improvement is claimed here; obtain
comparable physical-device traces and before/after metrics under #327.

#### Final status

Acceptance criteria satisfied for coherent projection publication. Do not begin #321 in this slice.

### Issue #321 — 03: Keep Local Alerts structurally stable across content changes

- Status: Implementation complete; rendered simulator inspection blocked by CoreSimulator service failure
- Scope: Close the residual outer-branch gap left after #258 by keeping one Local Alerts container/card identity and
  transitioning only its content.
- Files changed:
  - `Sources/Features/Summary/ActiveAlertSummaryView.swift` — removes the top-level empty replacement, keeps one
    stable outer owner for loading/alerts/empty, attaches sheet/lifecycle/height state to that owner, transitions only
    the internal content slot, preserves renderable-alert precedence, and gives the no-active rail sole ownership of
    empty-state chrome. Adds an interactive state-sequence preview and retains the existing accessibility-size preview.
  - `Tests/UnitTests/SummaryViewLocalAlertsStateTests.swift` — covers renderable-alert precedence across transient
    states and the authoritative-empty height/motion policy.
  - `docs/plans/today-refresh-performance-progress.md` — this evidence and handoff entry.
- Final stable-container contract: `ActiveAlertSummaryView.body` always returns the existing `activeContent` owner.
  Loading, alerts, and empty are internal `contentStateView` values; sheet presentation, selection state, detents,
  transition observation, height-phase state, cancellation, and lifecycle modifiers remain on the stable owner. No
  `.id`, `AnyView`, broad implicit animation, business-state recreation, or dependency was added.
- Observable transition and height behavior: renderable rows still outrank transient loading/empty bookkeeping;
  cached populated and cached empty refreshes remain calm because their content state does not change. Meaningful
  empty/alerts changes crossfade only the internal slot. Alerts-to-authoritative-empty retains flexible height during
  the cancellable main-actor hold, including the Reduce Motion timing path; ordinary cached refreshes do not hold
  height or animate the full surface. The no-active rail owns its own rail styling without nested card chrome.
- Rendered scenarios inspected: the existing populated, empty, cached-refreshing, offline/degraded, and accessibility
  large-type previews were reviewed, and a stateful real-view preview now exercises loading → empty → populated. The
  existing seeded UI fixture was reviewed for sheet selection, Alert Center navigation, stable identifiers, and
  accessibility coverage. A live iPhone 17 simulator sequence with Reduce Motion off/on and AX Dynamic Type could
  not be completed after CoreSimulatorService became unavailable (`connection refused`); no simulator evidence is
  claimed.
- Validation:
  - `xcodebuild ... -only-testing:SkyAwareTests/SummaryViewLocalAlertsTests -only-testing:SkyAwareTests/TodayContentStateTests test` — passed; `.xcresult` at
    `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.07.19_17-01-23--0600.xcresult`; 28 passed, 0 failed, 0 skipped.
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build` — passed.
  - `git diff --check` — passed.
  - The existing UI test target is not a member of the scheme’s active test plan, so its sheet fixture could not be
    invoked through the requested `xcodebuild -only-testing` path.
- Accessibility/Reduce Motion validation: accessibility identifiers, combined VoiceOver elements, Dynamic Type text
  styles, sheet identifiers, and the existing `.accessibility3` preview remain unchanged. Reduce Motion is honored by
  the existing `SkyAwareMotion.layerChange` and cancellable height-reset policy; rendered off/on verification remains
  blocked by CoreSimulatorService.
- Assumptions and residual risks: the parent-provided `LocalAlertsDisplayState` remains authoritative, and the current
  empty rail’s copy and appearance remain product-owned. Identity assertion is not directly exposed by existing test
  infrastructure; the stable body boundary, deterministic policy tests, and stateful preview provide the available
  evidence. Physical-device quantitative campaign validation remains deferred to #327, and no #319 instrumentation or
  #320 projection-publication changes were touched.
- Final status: implementation, focused tests, Debug build, and static/rendered-preview review complete; live simulator
  Reduce Motion/Dynamic Type sequence remains an environment-blocked follow-up, not a new production scope.
- Handoff: Do not redesign rows, sorting, navigation, or alert business state.

### Issue #322 — 04: Reserve a stable Storm Setup section slot

- Status: Implementation complete; rendered Reduce Motion inspection blocked by CoreSimulatorService failure
- Files changed:
  - `Sources/Features/StormSetup/StormSetupPresentation.swift` — replaces the boolean Storm Setup plan input with the
    explicit `SummaryStormSetupSlot` contract; loading and visible reserve layout, hidden excludes it.
  - `Sources/Features/Summary/SummaryView.swift` — carries the derived Storm Setup slot state into both section
    planning and rendering, making the existing loading branch reachable without changing section identity or order.
  - `Tests/UnitTests/SummarySectionPlanTests.swift` — covers loading-to-visible identity/order, cached refresh retention,
    hidden exclusion, Local Alerts populated/empty, and Location Reliability present/absent combinations.
  - `Tests/UnitTests/SummaryViewLoadingStateTests.swift` — covers composed state-to-plan behavior for loading, visible,
    cached refresh, disabled, location-unavailable, policy-suppressed, and idle-without-content cases.
- Final slot-to-section contract: `SummaryStormSetupSlot.hidden` excludes `.stormSetup`; `.loading` and `.visible`
  include `.stormSetup`. The slot remains after `.atmosphericConditions` and before `.locationReliability` when present,
  otherwise before `.outlookSummary`.
- Observable layout/transition behavior: eligible no-content refresh renders the existing loading card in a reserved
  Storm Setup position. Loading-to-visible and cached-refresh transitions retain `SummarySectionKind.stormSetup` and
  animate only the existing Storm Setup content branch via its local transition/animation. The Summary section list is
  not globally animated or re-identified.
- State matrix covered: enabled + refreshing + no content, loading → visible plan identity, cached visible + refreshing,
  disabled + refreshing, location unavailable, policy-suppressed existing payload, idle without content, Local Alerts
  empty/populated, and Location Reliability present/absent.
- Preview/simulator evidence: static review of existing `SummaryView+Previews.swift` confirmed Storm Setup visible,
  hidden, and cached-refresh preview inputs and existing Reduce Motion-aware local animation. One simulator test run
  executed all focused cases on iPhone 17/iOS 26.5; rendered Reduce Motion off/on inspection was blocked after the run
  by `CoreSimulatorService connection became invalid` / `Connection refused`.
- Tests/build evidence: the required focused command produced `.xcresult` at
  `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.07.19_17-17-31--0600.xcresult` with 9 passed, 0 failed, and 0 skipped tests. The
  required Debug build succeeded. `git diff --check` passed.
- Assumptions and residual risks: existing Storm Setup display policy remains the authority for visible content; no new
  terminal/unavailable business state or copy was introduced. Live rendered Reduce Motion and Dynamic Type inspection
  remains an environment follow-up. Local Alerts, instrumentation, navigation, and all ingestion/persistence behavior
  were left unchanged.
- Final status: acceptance criteria satisfied. Do not begin #323 in this slice.

### Issue #323 — 05: Parallelize independent ingestion work within priority lanes

- Status: Complete
- Files changed:
  - `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift` — uses `async let` for the normal hot-alert SPC meso and
    Arcus context syncs, and for slow-product map outcome and convective-outlook syncs; both children are joined before
    lane completion and the original map outcome is returned.
  - `Tests/UnitTests/HomeRefreshPipelineTests.swift` — extends the existing executor/pipeline fakes with independent
    gates, HTTP-mode capture, cancellation probes, and deterministic overlap/join/cancellation coverage.
  - `docs/plans/today-refresh-performance-progress.md` — records this implementation and validation evidence.
- Final concurrency and join contract: the normal context-backed hot path starts SPC mesoscale discussions and Arcus
  alert synchronization as structured children inside the existing `HTTPExecutionMode.$current.withValue` scope and
  awaits both. The existing remote-alert task group and its context rules remain unchanged. The slow lane starts map
  synchronization and convective-outlook synchronization as structured children, awaits both, and returns the map
  result captured from its child. Cancellation propagates through the parent and both children are joined before the
  executor returns.
- Preserved semantics: hot freshness updates only after the joined hot operation and the existing hot completion
  progress event remains before `markHotAlertsCompleted`. Slow freshness advances only for `.accepted`; rejected,
  failed, and skipped map outcomes retain existing projection/widget/retry behavior. Progress events, lane boundaries,
  snapshot assembly, logging, remote-alert behavior, provider actors, and in-flight coalescing are unchanged.
- Gate-controlled scenarios covered: both hot children start before release; releasing one hot child does not complete
  the lane; terminal hot progress precedes the mark callback; both slow children start before release; releasing one slow
  child does not complete the lane; the map outcome is returned only after both children finish; both hot and slow
  children observe foreground HTTP execution; and cancellation observes both started hot children as cancelled after
  the parent joins them. Existing pipeline coverage retains remote-alert, accepted, rejected, failed, skipped, empty,
  projection/widget, freshness, and final snapshot behavior.
- Tests/build evidence: focused `HomeRefreshPipelineTests` result bundle
  `/tmp/arcus-derived-data-323/Logs/Test/Test-SkyAware-2026.07.19_17-35-13--0600.xcresult` reports 44 passed, 0 failed,
  0 skipped. The final required coordinator/pipeline/Storm Setup command result bundle
  `/tmp/arcus-derived-data-323/Logs/Test/Test-SkyAware-2026.07.19_17-38-18--0600.xcresult` reports 76 passed, 0 failed,
  0 skipped, verified through the legacy `xcresulttool` object summary because the current summary command could not
  create its temporary `TestReport` directory in the sandbox. The required Debug simulator build passed, and
  `git diff --check` passed.
- Signpost comparison: #319 physical-device baseline evidence remains available in
  `/private/tmp/SkyAware-319-traces/` (`warm-events-launch-20260719-analysis.md` and
  `pull-events-20260719-analysis.md`), but no comparable post-#323 physical-device trace was captured. No latency
  improvement is claimed; quantitative campaign comparison remains deferred to #327.
- Assumptions and residual risks: provider calls remain actor-owned and any provider-internal request coalescing stays
  authoritative. The simulator verifies deterministic join and cancellation behavior, not production network latency;
  physical-device release evidence is still required for quantitative performance claims.
- Final status: acceptance criteria satisfied. Do not begin #324 in this slice.

### Issue #324 — 06: Run optional enrichment concurrently

- Status: Complete
- Files changed:
  - `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift` — starts Storm Setup and AQI as structured `async let`
    children after core snapshot assembly, joins both results, then maps each result independently before the existing
    projection persistence and single-snapshot return.
  - `Tests/UnitTests/StormSetupIngestionTests.swift` — extends the existing Storm Setup/AQI fakes with independent
    start observation, release gates, cancellation observation, response injection, and HTTP-mode capture; adds
    deterministic optional-enrichment overlap, join, failure, timeout, cache, eligibility, mode, and cancellation
    coverage.
  - `docs/plans/today-refresh-performance-progress.md` — records the #324 implementation and validation evidence.
- Final optional-enrichment concurrency/join contract: after core snapshot assembly, the executor creates two
  structured children with the same immutable context, plan, execution mode, and core snapshot input used by the
  previous serial path. It awaits the Storm Setup and AQI results as a tuple before mutating the final snapshot or
  continuing to projection persistence. Both children remain owned by the executor run and are joined on cancellation.
- Preserved semantics: Storm Setup eligibility, fresh-cache resolution, failed-attempt backoff, foreground timeout,
  cancellation result, persistence, current-response/DTO mapping, and failure isolation are unchanged. AQI retains
  weather-lane eligibility, missing-context/provider behavior, HTTP mode, error isolation, and nil-on-failure mapping.
  Projection persistence, risk-profile delta calculation, widget refresh, freshness, logging, final snapshot contents,
  and the single-snapshot publication contract remain unchanged. No core content is published early; that remains #325.
- Gate-controlled scenarios covered: both eligible children start before either gate opens; releasing only Storm Setup
  or only AQI does not return the snapshot; successful results appear together; Storm Setup failure and timeout preserve
  successful AQI; AQI failure preserves Storm Setup and persistence; fresh-cache and ineligible Storm Setup still allow
  AQI; session-tick hot-only plans skip AQI; both children observe foreground HTTP mode; and parent cancellation is
  observed by both blocked children with no child left running. Background HTTP mode and missing-context/provider
  behavior are also asserted. Existing Storm Setup backoff, cache, timeout,
  persistence, missing-provider, and mapping tests retain their behavior.
- Tests/build evidence: the required focused command produced `.xcresult` at
  `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.07.19_17-54-41--0600.xcresult`
  with 76 tests, 0 failures, and 0 skipped, confirmed through the legacy `xcresulttool` object summary and the
  successful `xcodebuild` result because the
  current summary command could not move its temporary database in this environment. The required Debug simulator
  build passed, and `git diff --check` passed.
- Signpost comparison and limitations: the available #319 traces include the Storm Setup success trace
  `/private/tmp/SkyAware-319-traces/storm-setup-success-20260719-analysis.md`, but do not provide a comparable
  post-change terminal optional-enrichment interval or paired AQI/Storm Setup overlap. The deterministic gate tests
  prove the new bounded-by-the-slower-child join contract; no quantitative latency improvement is claimed. Physical
  device comparison remains deferred to #327.
- Assumptions and residual risks: existing provider and projection actors remain authoritative for internal request
  coalescing and persistence ordering. Simulator gates verify ownership, overlap, and cancellation, but not production
  network scheduling or physical-device latency. No production API contract, retry policy, timeout duration, or
  eligibility rule changed.
- Final status: acceptance criteria satisfied. Do not begin #325 in this slice.

### Issue #325 — 07: Publish core Today content before optional enrichment

- Status: Complete
- Files changed:
  - `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift` — defines the core/enrichment publication contract,
    publishes the persisted core before starting optional children, then publishes joined optional results.
  - `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift` — assigns one run identity and forwards both stages to
    compatible waiters while preserving the atomic fallback for conformers that emit no stages.
  - `Sources/App/HomeRefreshPipeline.swift` — accepts staged publication through submission, run, and location-key
    identity; shares core/enrichment application with the atomic path; keeps prime callbacks and results non-visible.
  - `Tests/UnitTests/StormSetupIngestionTests.swift` — proves real-executor sequencing, persistence-before-core,
    independent optional gating, joined enrichment, and shared run/location identity.
  - `Tests/UnitTests/HomeIngestionCoordinatorTests.swift` — proves the coordinator forwards one executor run identity
    across both stages.
  - `Tests/UnitTests/HomeRefreshPipelineTests.swift` — proves identity rejection, failure/timeout/cancellation retention,
    location clearing, same-location supersession, and non-staging atomic compatibility.
  - `docs/plans/today-refresh-performance-progress.md` — records this contract and its validation evidence.
- Final staged-publication contract: after snapshot assembly, the executor completes the existing atomic core
  projection commit and widget refresh attempt, then reports one core containing location, weather, risks, alerts,
  mesos, and outlooks. Only after that report returns does it start Storm Setup and AQI as sibling `async let`
  children. It awaits both, reports one enrichment, and returns the complete snapshot. No detached or fire-and-forget
  enrichment work exists; cancellation remains bounded by the executor/coordinator-owned run.
- Identity and supersession contract: every visible pipeline submission has a submission UUID; every coordinator run
  has a run UUID; each stage carries the resolved location refresh key. Core acceptance records the exact triple.
  Enrichment must match all three values, and the pipeline closes the submission window when its waiter returns.
  Submission identity is required because compatible coordinator waiters can share a run; run identity binds the two
  executor stages; refresh-key identity prevents location-A optional content from mutating location-B core content.
  Older same-location submissions cannot overwrite a newer accepted publication.
- Atomic and lifecycle compatibility: core application is implemented once; the atomic path calls that same core
  function followed by the same enrichment function. A coordinator conformer that emits no stage therefore still
  applies its final snapshot atomically. A staged final result does not reapply core. Scene-activation prime uses no
  progress or publication callback and does not apply its returned snapshot; the existing prime/follow-up cache-forward
  test is unchanged. Same-location Storm Setup failure/timeout/nil retains valid cached guidance, while a location-key
  change clears old Storm Setup and AQI ownership at core publication. Core remains visible if optional work fails,
  times out, or no enrichment is accepted after cancellation.
- Test evidence: the real executor test supplies a known run UUID, blocks Storm Setup and AQI independently, verifies
  the durable core timestamps before observing core, proves no enrichment after one child has actually settled, and
  verifies core then enrichment share the run UUID and refresh key. Pipeline tests use payloads that would visibly
  overwrite state if either run or refresh-key guard were removed. Separate tests cover failure, timeout, cancellation,
  location change, and older same-location enrichment. Existing atomic, prime/follow-up, weather, alerts, resolution,
  Storm Setup retention, AQI, outlook, and signpost coverage remains green.
- Validation evidence:
  - Required focused command passed. `.xcresult`:
    `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.07.19_19-38-43--0600.xcresult`;
    90 executed, 90 passed, 0 failed, 0 skipped. Console output and result inspection confirm all three named suites ran.
  - Complete `SkyAwareTests` command passed without the known `AlertNotificationTests` polling timeout. `.xcresult`:
    `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.07.19_19-47-35--0600.xcresult`;
    863 executed, 863 passed, 0 failed, 0 skipped.
  - Required Debug iPhone 17 simulator build passed.
  - `git diff --check` passed.
- Review gate: all publication fields are consumed; staged and atomic core application share one implementation; the
  executor owns and joins both optional children; the coordinator filters stages to its active plan and run; the
  pipeline rejects stale submission/run/location triples. Production changes remain within the requested three files.
- Residual risk: deterministic simulator tests prove ordering, ownership, and rejection but not physical-device latency.
  No post-#325 Release/device trace was captured, so no quantitative improvement is claimed; the campaign comparison
  remains deferred to #327.
- Final status: acceptance criteria satisfied. Do not begin #326 in this slice.

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
| 2026-07-19 | #325 | Required focused pipeline/coordinator/Storm Setup suites; `.xcresult` `Test-SkyAware-2026.07.19_19-38-43--0600.xcresult` inspected | Passed: 90 tests, 0 failures, 0 skipped |
| 2026-07-19 | #325 | Complete `SkyAwareTests` bundle; `.xcresult` `Test-SkyAware-2026.07.19_19-47-35--0600.xcresult` inspected | Passed: 863 tests, 0 failures, 0 skipped |
| 2026-07-19 | #325 | Debug iPhone 17 simulator build and `git diff --check` | Passed |

## Handoff Notes

- Execute issues in order and update the matching ledger entry before closing each issue.
- Record exact files, observable behavior, commands, test counts, `.xcresult` findings, trace artifact locations, and
  residual risk.
- Compare each performance slice against issue 01's baseline rather than relying on subjective simulator impressions.
- If an issue discovers a correctness defect outside its boundary, record evidence and open a follow-up; do not absorb
  it into the active diff.
- Stop and re-plan if work requires server changes, feed semantics, background cadence, SwiftData migration,
  unstructured concurrency, or a broad Today redesign.
