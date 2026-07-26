# Today Refresh Performance Progress

## Overview

This ledger tracks the campaign to make SkyAware foreground Today refresh faster and visually stable. It is the durable
handoff record for issue status, implementation decisions, validation evidence, and residual risk.

**Epic status:** Implementation complete; physical-device evidence pending
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

## Campaign Baseline (Historical)

The following describes the pre-implementation state. Detailed entries below are the current authority for completed
work and remaining validation gaps.

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
| 0 | [#318](https://github.com/justinrooks/project-arcus/issues/318) | Epic: Make Today Refresh Fast and Visually Stable | Coordination | Closed; implementation complete | Remaining physical-device evidence is tracked separately. |
| 1 | [#319](https://github.com/justinrooks/project-arcus/issues/319) | Establish Today refresh performance baselines | `GPT-5.6 Luna / medium` | Instrumentation complete; physical-device capture pending | Comparable scenario gaps remain. |
| 2 | [#320](https://github.com/justinrooks/project-arcus/issues/320) | Publish coherent Home projections atomically | `GPT-5.6 Terra / medium` | Complete | #319 |
| 3 | [#321](https://github.com/justinrooks/project-arcus/issues/321) | Keep Local Alerts structurally stable across content changes | `GPT-5.6 Luna / medium` | Implementation complete; simulator inspection blocked | #320 |
| 4 | [#322](https://github.com/justinrooks/project-arcus/issues/322) | Reserve a stable Storm Setup section slot | `GPT-5.6 Luna / medium` | Implementation complete; Reduce Motion inspection blocked | #321 |
| 5 | [#323](https://github.com/justinrooks/project-arcus/issues/323) | Parallelize independent ingestion work within priority lanes | `GPT-5.6 Luna / medium` | Complete | #322 |
| 6 | [#324](https://github.com/justinrooks/project-arcus/issues/324) | Run optional enrichment concurrently | `GPT-5.6 Luna / medium` | Complete | #323 |
| 7 | [#325](https://github.com/justinrooks/project-arcus/issues/325) | Publish core Today content before optional enrichment | `GPT-5.6 Terra / medium` | Complete | #324 |
| 8 | [#326](https://github.com/justinrooks/project-arcus/issues/326) | Isolate continuous Today header rendering | `GPT-5.6 Luna / medium` | Implementation complete; simulator/device-trace validation deferred | #325 |
| 9 | [#327](https://github.com/justinrooks/project-arcus/issues/327) | Prove end-to-end Today refresh smoothness | `GPT-5.6 Luna / medium` | Closed; physical-device evidence incomplete | Remaining comparable evidence is owned by [#345](https://github.com/justinrooks/project-arcus/issues/345). |

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

- Status: Implementation complete; simulator and device-trace validation deferred by unavailable local services
- Files changed:
  - `Sources/App/TodayTabView.swift` — moves normalized scroll progress into a main-actor Observation state holder and
    avoids publishing an unchanged effective value.
  - `Sources/Features/Summary/SummaryView.swift` — passes the stable holder to Current Conditions without reading its
    changing property.
  - `Sources/Features/Summary/SummaryStatus.swift` — becomes the first and only view reader of continuous progress,
    while removing the implicit layout animation keyed to that value.
  - `Sources/Features/Summary/SummaryView+Previews.swift` — supplies the stable holder to the existing Summary preview.
  - `Tests/UnitTests/TodayContentStateTests.swift` — verifies clamped normalization and unchanged-effective-value
    suppression deterministically.
- Rendering evidence: `TodayTabView` owns the stable `TodayHeaderCondenseState`; `SummaryView` only stores and passes
  its reference; `SummaryStatus` first reads `progress`. Therefore continuous progress does not establish an Observation
  dependency for `SummaryView`, cards, alerts, Outlook, Storm Setup, or atmospheric content. The prior
  `SkyAwareMotion.settle` animation keyed to each condense update is removed; weather, refresh-message, and offline
  animations are unchanged. Spacing, padding, corner radius, shadow, opacity, and title-threshold interpolation remain
  unchanged and now track scrolling directly.
- Validation:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
    — passed.
  - Focused Summary/Today and complete `SkyAwareTests` commands were invoked, but their `.xcresult` bundles remained in
    Xcode staging without `Info.plist`, so no executed/passed/failed/skipped counts can be reported.
  - `xcrun simctl list devices available` failed because `CoreSimulatorService` was unavailable. Slow/fast scroll,
    direction reversal, pull-to-refresh while partially condensed, refresh completion while scrolling, Reduce Motion,
    and Dynamic Type could not be exercised locally.
  - `xcrun xctrace list devices` could not initialize because Instruments lacked permission to create its local cache;
    no physical-device Release trace was captured. Quantitative before/after comparison remains deferred to #327.
  - `git diff --check` — passed.
- Residual risk: static Observation ownership and deterministic state tests prove the invalidation boundary and direct
  tracking contract, but runtime visual and hitch evidence remains outstanding until simulator services or a physical
  device are available. No ingestion, refresh, projection, display-state, accessibility identifier, navigation, or
  card-identity behavior changed.
- Handoff: Do not redesign the Summary, introduce speculative caching, or optimize small collections without evidence.

### Issue #327 — 09: Prove end-to-end Today refresh smoothness

- Status: Incomplete — not ready for closure
- Scope: Run the full state/refresh matrix, focused regression suite, Debug build, and before/after Release/device
  Instruments comparison. Fix only documentation or test-fixture defects; file new issues for residual production work.
- Source and environment: validation used HEAD `d520ec8c048c9dcc0050bbf0d2556471ec9f9dc7`, with uncommitted working-tree
  changes. Xcode 26.6 (17F113),
  iPhone 17 simulator iOS 26.5 (`F5154D35-3398-4BEB-943E-E8D174B32832`), and the baseline physical device
  `Js14Max` iOS 26.5.2 (`00008120-001A744E1193C01E`).

The validation working tree included uncommitted test-target and test-fixture corrections in
`SkyAware.xcodeproj/project.pbxproj` (test-target membership),
`Tests/UnitTests/AtmosphericConditionsDescriptorTests.swift` (fixture correction), and
`Tests/UnitTests/SkyAwareAdaptiveLayoutTests.swift` (fixture correction), plus this ledger update. This pass also
added the separate LocationProvider remediation in `Sources/Providers/Location/LocationProvider.swift` (clear a
cached placemark when accepted coordinates change) and its deterministic regression coverage in
`Tests/UnitTests/LocationProviderTests.swift` (actor-gated geocoding and unchanged-coordinate fast-path coverage).

#### Scenario matrix

| Scenario | Result | Evidence / limitation |
|---|---|---|
| Cold launch with no usable Today cache | Blocked | #319 has no valid cold-Today baseline; the attempted current physical-device launch trace did not finalize. |
| Warm cached launch and foreground activation | Not comparable | Valid #319 baseline exists, but no valid current Release/device trace was captured. |
| Pull-to-refresh with useful cached content visible | Not comparable | Valid #319 baseline exists, but no valid current Release/device trace was captured. |
| Local Alerts populated to authoritative empty | Blocked | No deterministic device fixture was available; #319 also has no authoritative-empty capture. |
| Storm Setup loading to success | Blocked | #319 Storm Setup trace is a fresh-cache skip, not a loading-to-success transition. |
| Storm Setup loading to terminal failure | Blocked | No reproducible device timeout/failure fixture was available. |
| Partial core-provider failure with useful cache | Blocked | Deterministic state coverage passed, but no device scenario was exercised. |
| Rapid background/foreground transitions | Blocked | Deterministic identity/rejection coverage passed, but no device lifecycle sequence was exercised. |
| Scroll, reversal, partial-condense refresh | Blocked | No valid post-#326 SwiftUI trace or rendered device/simulator sequence was captured. |
| Refresh completion while scrolling | Blocked | No valid post-#326 SwiftUI trace or rendered device/simulator sequence was captured. |
| Reduce Motion and representative large Dynamic Type | Blocked | Existing unit coverage retains state contracts; no rendered scenario was exercised. |

Focused tests establish the no-partial-projection, cache retention, staged core/enrichment, Local Alerts slot, Storm
Setup slot, stale-run rejection, and header-condense suppression contracts. They do not substitute for the blocked
rendered/device scenarios above.

#### Validation evidence

- Focused suites: passed, 160 executed / 160 passed / 0 failed / 0 skipped. Result bundle:
  `/private/tmp/SkyAware-327-results/focused-escalated.xcresult`. Inspected with
  `xcrun xcresulttool get test-results summary`; the bundle includes `HomeProjectionStoreTests`,
  `HomeRefreshPipelineTests`, `HomeIngestionCoordinatorTests`, `StormSetupIngestionTests`,
  `SummaryViewLocalAlertsTests`, `SummaryViewStormSetupSlotStateTests`, `TodaySurfaceStateFlowTests`,
  `TodayVisibleWeatherStateTests`, and both #326 `TodayContentStateTests` header-condense cases.
- Complete unit target: passed, 865 executed / 865 passed / 0 failed / 0 skipped. Result bundle:
  `/private/tmp/SkyAware-327-results/full-unit.xcresult`, inspected with `xcresulttool`.
- Today UI smoke: not executed. The existing `SkyAwareUITests/testTabNavigationLoadsEachPrimaryView` was selected,
  but Xcode rejected it because `SkyAwareUITests` is not a member of the scheme's specified test plan. Result bundle:
  `/private/tmp/SkyAware-327-results/today-navigation-ui.xcresult`.
- Debug build: passed with
  `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`.
- Release/device attempt: current Release build targeted `Js14Max`; `xctrace` was invoked with the SwiftUI template
  and a 45-second launch capture. Artifact
  `/private/tmp/SkyAware-327-traces/warm-launch-current-20260719.trace` is invalid: `analyze_trace.py` fails with
  `Document Missing Template Error`. It is not performance evidence. An earlier `devicectl` install attempt also
  rejected the otherwise signed bundle as invalid, so no reliable current app launch/interaction sequence was available.
- Valid #319 baseline evidence remains limited to source `b963fa63eb08997ce24872178af5294f63333251`, Xcode 26.6,
  `Js14Max` iOS 26.5.2: warm launch has 14 saves, 10,716 Summary body updates, 112 high-severity SwiftUI events,
  and 8 app hitches / 150.05 ms / 41.68 ms worst; pull-to-refresh has six saves per manual cycle, 14,285 body
  updates, 109 high-severity events, and 12 app hitches / 141.73 ms / 16.67 ms worst. No valid before/after delta
  can be claimed. The #319 Storm Setup capture remains a non-comparable fresh-cache skip.

#### Closure decision and recovery

- Closure recommendation: **not ready**. No production regression was discovered, so no follow-up issue was opened.
  The closure blocker is missing comparable Release/physical-device evidence, not a deterministic test failure.
- To recover, keep `Js14Max` unlocked, rebuild/install the current Release app from an isolated derived-data path,
  then record separate SwiftUI-template traces for cold-no-cache, warm foreground, cached pull-to-refresh,
  alerts-to-empty, Storm Setup success and terminal failure, lifecycle churn, and scroll/refresh sequences. For each
  finalized trace, run `analyze_trace.py --list-signposts`, `--list-logs`, and `--json-only --top 10`; use the
  `Today Visible Commit` to first-following-`Today Summary Render` window and compare only like-for-like windows to
  `/private/tmp/SkyAware-319-traces/warm-events-launch-20260719.trace` and
  `/private/tmp/SkyAware-319-traces/pull-events-20260719.trace`. Capture Reduce Motion and accessibility Dynamic Type
  as rendered variants. Do not use the invalid current trace or #319's Storm Setup fresh-cache trace for a delta.
This pass did not change `LocationSession`, ingestion, SwiftUI, H3 policy, distance thresholds, or the earlier #327
scenario evidence.

### Issue #345 — 16: Capture remaining physical-device Release evidence

- **Status:** Partial trace-only evidence — semantic/visual matrix and deterministic result bundle remain blocked. No
  production, test, project, server, notification, persistence, or optimization work was performed.
- **Environment and provenance:** 2026-07-24T22:57:50Z; source
  `7a7f92065d5d9945aabb59b75d50982e3df638ec` (contains required `7a7f9206`), clean worktree on
  `329-epic-systematically-simplify-skyaware-architecture` (ahead 3); Xcode `26.6 (17F113)`, iPhoneOS SDK `26.5`.
  `record_trace.py --list-devices` reported `Js14Max`, UDID `00008120-001A744E1193C01E`, iOS `26.6`, under
  `devices offline`. `--list-templates` exposed both `SwiftUI` and `Animation Hitches`.
- **Instrumentation/source verification:** `HomeRefreshPipeline` emits `Today Visible Commit` after coherent core
  state application; `SummaryView` emits `Today Summary Render` for current/degraded content. `HomeProjectionStore`
  retains the Create, Touch, Weather, Storm Setup, Slow Products, and Hot Alerts save intervals. The current
  `BackgroundOrchestrator` retains `Background Run` and `Unified Background Ingestion`; `TodayTabView` retains the
  `summary-scroll` narrow header-condense boundary. This static inspection is neither trace nor rendered evidence.
- **Stop condition applied:** no Release build, signing verification, install, launch, trace, log/signpost analysis,
  or screen recording was attempted. Recording requires the target to appear under `devices`, not `devices offline`;
  simulator output cannot replace this evidence. Fresh non-repository artifact root:
  `/private/tmp/SkyAware-345.t1KHRi/{derived,traces,analysis,recordings}`; it contains no captures.
- **Initial device/build recovery attempt:** Js14Max subsequently appeared online under `devices`; its connection is
  no longer the stop condition. One agent-run Release build to
  `/private/tmp/SkyAware-345.t1KHRi/derived/Build/Products/Release-iphoneos/SkyAware.app` left an incomplete product:
  resources and `embedded.mobileprovision` exist, but `Info.plist` and a signed executable do not.
  `codesign --display --verbose=4` returned `bundle format unrecognized, invalid, or unsuitable`. The app cannot be
  installed or associated with the source SHA; this failed product was not installed or traced.
- **Successful Release provenance:** User-built artifact
  `/private/tmp/SkyAware-345-manual-derived/Build/Products/Release-iphoneos/SkyAware.app` subsequently verified
  with `codesign --verify --deep --strict`; `com.skyaware.app`, version `1.1.0` (80), Apple Development team
  `YVC4WFW94T`. It was installed on Js14Max at 17:06:10 MDT. The source SHA remained
  `7a7f92065d5d9945aabb59b75d50982e3df638ec`; the only worktree changes were the #345 ledger files.

#### Scenario matrix

| Scenario | Result | Exact evidence / blocker |
|---|---|---|
| Cold launch with no usable Today cache | Blocked | No deletion/reset of user data; no valid cold trace or rendered evidence. |
| Warm cached launch and foreground activation | Blocked | Valid current trace-only capture exists, but no app signposts/logs or screen recording prove the required semantic/visual boundaries; historical raw trace invalid and OS differs. |
| Pull-to-refresh with useful cached content | Blocked | Valid current trace-only capture exists, but no app signposts/logs or screen recording prove cache retention/core publication; historical raw trace invalid and OS differs. |
| Local Alerts populated to authoritative empty | Blocked | No existing safe deterministic device fixture/control point. |
| Storm Setup loading to success | Blocked | Historical capture is a fresh-cache skip, not the required transition; no existing safe forcing control. |
| Storm Setup loading to terminal failure | Blocked | No safe reproducible timeout/failure fixture. |
| Partial core-provider failure with useful cache | Blocked | No safe device failure fixture without server manipulation. |
| Rapid background/foreground lifecycle changes | Blocked | No dedicated physical lifecycle trace with app signpost boundaries. |
| Scroll, reversal, and partial-condense refresh | Blocked | No dedicated SwiftUI trace plus rendered recording. |
| Refresh completion while scrolling | Blocked | No dedicated SwiftUI trace plus rendered recording. |
| Reduce Motion and representative accessibility Dynamic Type | Blocked | No separate rendered recording. |
| Background upload backlog and task-budget behavior | Blocked | No safe backlog fixture without mutating persisted user data. |

#### Trace, visual, and comparison evidence

- No current trace exposes `Today Visible Commit` to first-following `Today Summary Render` windows,
  projection-save counts, `Background Run`, `Unified Background Ingestion`, upload-drain, cancellation, or
  durable-remainder measurements. No screen recording exists; rendered assertions remain unproven.
- **Current Release/device trace-only evidence:**
  `/private/tmp/SkyAware-345.t1KHRi/traces/warm-foreground-20260724T230650Z.trace` has one finalized 97.790079 s
  SwiftUI run. Analysis `/private/tmp/SkyAware-345.t1KHRi/analysis/warm-foreground-20260724T230650Z.{json,md}`:
  10,961 body updates; 94 high-severity SwiftUI events; 22 app hitches / 462.64 ms total / 83.35 ms worst; one
  289.24 ms microhang. `/private/tmp/SkyAware-345.t1KHRi/traces/pull-refresh-launch-20260724T231500Z.trace` has one
  finalized 45.447359 s SwiftUI run. Analysis
  `/private/tmp/SkyAware-345.t1KHRi/analysis/pull-refresh-launch-20260724T231500Z.{json,md}`: 11,654 body updates;
  89 high-severity events; 16 app hitches / 270.97 ms total / 66.68 ms worst; zero hangs.
- Both valid traces have zero `com.skyaware.app` signpost intervals/events and zero subsystem log entries, so no
  `Today Visible Commit` to `Today Summary Render` window, projection-save count, or foreground/pull lane boundary
  can be identified. No separate screen recording was captured. They are therefore valid Release/device SwiftUI and
  hitch measurements only—not completed semantic or visual scenario evidence. Historical baseline raw artifacts are
  invalid and the iOS 26.5.2-to-26.6 OS mismatch remains, so no before/after or optimization conclusion is valid.
- Historical raw-artifact recheck, inspection-only:
  `analyze_trace.py --trace /private/tmp/SkyAware-319-traces/warm-events-launch-20260719.trace --list-runs` failed
  `Export failed: Trace is malformed - run data is missing`; the equivalent pull trace command failed
  `Export failed: Document Missing Template Error`. The #319 ledger metrics remain historical summaries, not
  analyzable baselines. The iOS 26.5.2-to-26.6 mismatch is an independent comparability limit. No direct
  before/after or optimization claim is valid.

#### Deterministic regression evidence

- Exact command invoked:
  `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_Tests -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" -resultBundlePath /private/tmp/skyaware-345-results.dGPvic/focused.xcresult` with the twelve
  #345 `-only-testing:SkyAwareTests/<suite>` selections from the issue. The result directory contains only `Data/`
  and `Staging/1_Test`; `Info.plist` is absent. Both required `xcresulttool get test-results summary --compact` and
  `tests --compact` commands failed because the bundle is not finalized. Passed/failed/skipped counts are unavailable.
  The known #344 `HomeIngestionCoordinatorTests.finishBeforeCancel_waiterCompletesSuccessfully()` cancellation race
  was neither reproduced nor cleared; no retry or fix was attempted.
- This deterministic invocation is separate from runtime, rendered-video, and Instruments evidence. It proves none of
  the blocked device scenarios and does not alter the ownership/cancellation contracts.

#### Recovery conditions and residual risk

- Connect, unlock, and trust `Js14Max` until `record_trace.py --list-devices` lists UDID
  `00008120-001A744E1193C01E` under `devices`. Recheck source SHA, clean worktree, Xcode/SDK, device OS, templates,
  and Release signing/install provenance before the first capture; keep all metadata fixed.
- A scenario requiring authoritative empty, Storm failure, partial provider failure, or upload backlog remains blocked
  until an existing safe control point is identified. Do not create production/debug seams, alter Arcus Signal or
  provider/server state, mutate persisted user data, or expose private location/alert content to manufacture evidence.
- The Today performance runbook header remains factually correct: implementation is complete and physical-device
  evidence remains pending.

#### 2026-07-26 controlled continuation

- **Source and worktree:** HEAD remained `7a7f92065d5d9945aabb59b75d50982e3df638ec` on
  `329-epic-systematically-simplify-skyaware-architecture`; the prerequisite is the current commit. This continuation
  did not start clean: the two #345 ledgers already contained the 2026-07-24 evidence above, and
  `docs/audits/weekly-performance-audit.md` had an unrelated user-owned edit. No source, test, project, CI, or server
  file was changed.
- **Current-method check and connection smoke:** Apple documents physical-device validation through Xcode Device Hub,
  physical-device SwiftUI profiling through Instruments 26, and cable pairing followed by same-network Wi-Fi use for
  pre-iOS 27 devices. `record_trace.py --list-devices` listed `Js14Max` under physical `devices`;
  CoreDevice reported paired, booted, Developer Mode enabled, and connected over local-network TCP. The target stayed
  iPhone 14 Pro Max (`iPhone15,3`), UDID `00008120-001A744E1193C01E`, iOS 26.6 (`23G71`). Xcode stayed
  `26.6 (17F113)` with iPhoneOS SDK 26.5; `SwiftUI` and `Animation Hitches` remained available.
- **Fresh roots:** capture root `/private/tmp/SkyAware-345-20260726.REBf1C` contains `derived`, `traces`, `analysis`,
  and empty `recordings` directories. Test root:
  `/private/tmp/skyaware-345-results-20260726.5091YV`.
- **Historical recheck:** both
  `/private/tmp/SkyAware-319-traces/warm-events-launch-20260719.trace` and
  `/private/tmp/SkyAware-319-traces/pull-events-20260719.trace` now fail `analyze_trace.py --list-runs` with
  `Export failed: Document Missing Template Error`. The historical ledger summaries remain non-analyzable, and the
  iOS 26.5.2-to-26.6 OS difference remains independently non-comparable.
- **Focused deterministic gate:** the exact twelve-suite #345 command finalized
  `/private/tmp/skyaware-345-results-20260726.5091YV/focused.xcresult`. `xcresulttool ... summary --compact` and
  `tests --compact` report Debug, iPhone 17 simulator, iOS 26.5: 270 total, 269 passed, 1 failed, 0 skipped.
  `HomeIngestionCoordinatorTests.finishBeforeCancel_waiterCompletesSuccessfully()` reproduced the known #344
  `CancellationError()` race. It was not retried or fixed.
- **Release provenance:** the physical-device Release build succeeded into
  `/private/tmp/SkyAware-345-20260726.REBf1C/derived/Build/Products/Release-iphoneos/SkyAware.app`.
  Bundle `com.skyaware.app`, version `1.1.0` (80), Xcode build `17F113`, SDK build `23F81a`; binary and dSYM UUID
  `151E8EF4-F43D-357E-855B-3585296DC8E7`. CoreDevice installed it as a developer app and the smoke launch succeeded.
  Host `codesign --verify --deep --strict` returned `CSSMERR_TP_NOT_TRUSTED`, and `security find-identity` reported
  zero valid identities; the device nevertheless accepted this exact bundle. Record both facts rather than treating
  the host trust-chain failure as a verified signature.
- **Warm SwiftUI evidence:** physical-device Release trace
  `/private/tmp/SkyAware-345-20260726.REBf1C/traces/warm-foreground-20260726T162500Z.trace` finalized as one
  40.623579-second SwiftUI run. Analysis
  `/private/tmp/SkyAware-345-20260726.REBf1C/analysis/warm-foreground-20260726T162500Z.{json,md}` reports five
  View Body Update events, 47 high-severity events, seven app hitches / 141.73 ms total / 25.02 ms worst, and one
  328.24 ms microhang. The stock SwiftUI template exposed no `os-signpost` schemas or app logs.
- **Supplemental signpost evidence and privacy stop:** separate Logging trace
  `/private/tmp/SkyAware-345-20260726.REBf1C/traces/warm-foreground-logging-20260726T162900Z.trace` finalized as one
  240.113890-second run. The intended final activation window is 219,189.595-227,054.907 ms: background at
  219,189.595 ms, activation at 222,588.539 ms, `Today Visible Commit` at 226,968.136 ms, and first following
  `Today Summary Render` at 227,054.907 ms (86.771 ms). The window contains two `Projection Core Save` intervals
  and one `Projection Storm Setup Save`; the latter accompanied a successful foreground Storm Setup request. No
  screen recording exists, so the trace does not prove useful-cache retention or rendered stability. The scoped log
  export also contained location-derived endpoint text. Its private value is intentionally omitted. This triggered
  the issue's privacy stop condition, so no further Logging or device scenario capture was attempted.

This matrix supersedes the 2026-07-24 matrix for the current pass:

| Scenario | Result | Exact evidence / blocker |
|---|---|---|
| Cold launch with no usable Today cache | Blocked | Deleting app data would also reset onboarding/user state; no safe existing no-cache fixture or rendered capture. |
| Warm cached launch and foreground activation | Blocked | Valid SwiftUI metrics and supplemental signpost timing exist, but no separate recording proves useful cache remained visible; the Logging trace is privacy-sensitive and the baseline is invalid. |
| Pull-to-refresh with useful cached content | Blocked | July 24 trace-only evidence lacks signposts/video; further Logging capture stopped after private location-derived text appeared. |
| Local Alerts populated to authoritative empty | Blocked | No safe deterministic device control point; live state remained populated and server manipulation is forbidden. |
| Storm Setup loading to success | Blocked | Supplemental trace records a successful foreground request and save, but no rendered recording proves the stable loading-to-success slot. |
| Storm Setup loading to terminal failure | Blocked | No safe timeout/failure control point without a new fixture or provider manipulation. |
| Partial core-provider failure with useful cache | Blocked | No safe physical-device provider-failure control point. |
| Rapid background/foreground lifecycle changes | Blocked | No dedicated trace or recording; further capture stopped on the private-log condition. |
| Scroll, reversal, and partial-condense refresh | Blocked | No dedicated SwiftUI trace plus rendered recording; further capture stopped on the private-log condition. |
| Refresh completion while scrolling | Blocked | No deterministic way to align completion with scrolling plus separate rendered evidence in this pass. |
| Reduce Motion and representative accessibility Dynamic Type | Blocked | No physical-device rendered recording; Device Hub video recording is documented for simulators, not this device lane. |
| Background upload backlog and task-budget behavior | Blocked | No safe backlog fixture without mutating durable user/location state; no background task was forced. |

No current evidence is directly comparable to #319. The measurements above are current absolute observations, not
before/after evidence, thresholds, regression claims, or optimization findings. The runbook status remains factually
correct.

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
| 2026-07-19 | #326 | Debug iPhone 17 simulator build and `git diff --check` | Passed |
| 2026-07-19 | #326 | Focused and complete unit-test commands with `.xcresult` inspection | Blocked: CoreSimulatorService unavailable; result bundles incomplete and counts unavailable |
| 2026-07-19 | #326 | Release/device SwiftUI Instruments trace | Deferred: local xctrace cache initialization permission failure; no device evidence captured |
| 2026-07-19 | #327 | Focused Today regression suites; `/private/tmp/SkyAware-327-results/focused-escalated.xcresult` inspected | Passed: 160 tests, 0 failures, 0 skipped |
| 2026-07-19 | #327 | Complete `SkyAwareTests`; `/private/tmp/SkyAware-327-results/full-unit.xcresult` inspected | Passed: 865 tests, 0 failures, 0 skipped |
| 2026-07-19 | #327 | Debug iPhone 17 simulator build and `git diff --check` | Passed |
| 2026-07-19 | #327 | Current Release/device SwiftUI capture on baseline `Js14Max` | Blocked: `/private/tmp/SkyAware-327-traces/warm-launch-current-20260719.trace` fails export with `Document Missing Template Error`; no comparable post-change metrics or full rendered scenario matrix |
| 2026-07-20 | #327 | LocationProvider remediation and deterministic regression test at HEAD `d520ec8c048c9dcc0050bbf0d2556471ec9f9dc7`, with uncommitted test-target/fixture corrections | Passed: accepted coordinate changes clear inherited placemarks; unchanged-coordinate fast path remains zero-geocoder-call; files: `Sources/Providers/Location/LocationProvider.swift`, `Tests/UnitTests/LocationProviderTests.swift` |
| 2026-07-20 | #327 | `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" -only-testing:SkyAwareTests/LocationProviderTests -resultBundlePath /private/tmp/SkyAware-review-fix-location.xcresult test`; `xcrun xcresulttool get test-results summary --path /private/tmp/SkyAware-review-fix-location.xcresult` | Passed: 60 executed / 60 passed / 0 failed / 0 skipped; new `send_clearsCachedPlacemarkWhenCoordinatesChange` appears in the bundle |
| 2026-07-20 | #327 | `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" -only-testing:SkyAwareTests -resultBundlePath /private/tmp/SkyAware-review-fix-full.xcresult test`; `xcrun xcresulttool get test-results summary --path /private/tmp/SkyAware-review-fix-full.xcresult` | Passed: 887 executed / 887 passed / 0 failed / 0 skipped |
| 2026-07-20 | #327 | `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" build` | Passed |
| 2026-07-20 | #327 | `git diff --check` | Passed |
| 2026-07-24 | #345 | Device/template preflight, Release install, historical raw-trace reanalysis, selected focused regression bundle, and two current Release/device SwiftUI traces | Partial: Js14Max iOS 26.6 online; signed `com.skyaware.app` 1.1.0 (80) installed; warm/pull traces finalized with SwiftUI/hitch metrics but no `com.skyaware.app` signposts/logs or screen recordings; historical warm trace malformed and pull trace has `Document Missing Template Error`; focused bundle `/private/tmp/skyaware-345-results.dGPvic/focused.xcresult` unfinalized (`Info.plist` absent), counts unavailable |
| 2026-07-26 | #345 | Online-device smoke, exact focused gate, fresh Release build/install/smoke launch, warm SwiftUI capture, and separate signpost capture | Partial/blocked: focused bundle finalized at 269 passed / 1 known cancellation-race failure / 0 skipped; warm SwiftUI trace finalized with 7 app hitches and 1 microhang; supplemental signposts expose an 86.771 ms commit-to-render boundary, but no video exists and private location-derived log text triggered the required stop condition |
| 2026-07-22 | PR #328 review feedback | Projection readiness no longer depends on WeatherKit; persisted slow-product and hot-alert slices remain required. Focused `HomeProjectionStoreTests` and `HomeViewProjectionLaunchTests`; `/private/tmp/SkyAware-328-review-fix.xcresult` inspected | Passed: 39 tests, 0 failures, 0 skipped |
| 2026-07-22 | PR #328 review feedback | Complete `SkyAwareTests`; `/private/tmp/SkyAware-328-review-fix-full.xcresult` inspected | Passed: 888 tests, 0 failures, 0 skipped |
| 2026-07-22 | PR #328 review feedback | Debug iPhone 17 simulator build and `git diff --check` | Passed |

## Handoff Notes

- Execute issues in order and update the matching ledger entry before closing each issue.
- Record exact files, observable behavior, commands, test counts, `.xcresult` findings, trace artifact locations, and
  residual risk.
- Compare each performance slice against issue 01's baseline rather than relying on subjective simulator impressions.
- If an issue discovers a correctness defect outside its boundary, record evidence and open a follow-up; do not absorb
  it into the active diff.
- Stop and re-plan if work requires server changes, feed semantics, background cadence, SwiftData migration,
  unstructured concurrency, or a broad Today redesign.
