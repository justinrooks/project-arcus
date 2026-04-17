
# FB-010 Progress Log

## Issue #121 - Define and Persist the Home Projection in SwiftData

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Minimal SwiftData projection schema
  - Projection merge and keyed-record contract
  - Cached home projection identity and bookkeeping
- Issue requirements completed:
  - Added a SwiftData-backed `HomeProjection` model for the current resolved location context
  - Added deterministic `projectionKey` generation from `LocationContext`
  - Added a projection store with fetch-or-create behavior and lane-owned updates for weather, hot alerts, and slow products
  - Added focused tests for keying, reuse, and untouched-slice preservation during lane updates

### Key implementation notes
- The projection stores only the cached home-summary payload required by FB-010 issue `#121`: weather, local risks, active local alerts, active local mesos, and lane freshness timestamps.
- `WatchRowDTO` and `MdDTO` now conform to `Codable` so the projection can persist the existing home-facing alert/meso DTO shapes without introducing a second projection-only alert model.
- `HomeProjectionStore` stays intentionally narrow. It does not route triggers, own queueing, or wire UI observation yet.
- `Dependencies` now registers the projection schema/store so later FB-010 issues can consume it without reopening the persistence container setup.

### Files changed
- `Sources/Models/Home/HomeProjection.swift`
- `Sources/Repos/HomeProjectionStore.swift`
- `Sources/App/Dependencies.swift`
- `Sources/Models/Watches/WatchRowDTO.swift`
- `Sources/Models/Meso/MdDTO.swift`
- `Tests/UnitTests/HomeProjectionStoreTests.swift`
- `SkyAware.xcodeproj/project.pbxproj`

### Tests
- Added:
  - `Tests/UnitTests/HomeProjectionStoreTests.swift`
    - proves deterministic projection key generation
    - proves fetch-or-create reuses an existing projection for the same location context key
    - proves slow-product updates preserve existing weather and hot-alert slices
    - proves weather updates preserve existing risk and hot-alert slices
- Updated:
  - `SkyAware.xcodeproj/project.pbxproj`
    - adds the new test file to the synced-folder exceptions so it builds only with the test target

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SkyAwareTests/HomeProjectionStoreTests test`
  2. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'generic/platform=iOS Simulator' build`
- Expected result:
  - The four `HomeProjectionStoreTests` pass.
  - The `SkyAware` simulator build succeeds.

### Out of scope / intentionally deferred
- Loading the home UI from the persisted projection
- Trigger routing, queueing, and `HomeRefreshV2` execution changes
- APNs hot-alert handling
- Offline/runtime-state UI
- Diagnostics/admin UI
- Convective outlook persistence inside the home projection

### Risks or follow-ups
- The projection store currently uses pragmatic fetch-or-create behavior without deduping duplicate records for the same `projectionKey`; later issues should continue to treat `projectionKey` as authoritative and avoid creating competing writers.
- Lane updates currently replace their owned slices atomically but do not yet emit projection deltas; delta production should stay tied to the issue that actually introduces ingestion writes.

### Handoff to next issue
- The next issue should assume:
  - `Dependencies.homeProjectionStore` and the `HomeProjection` schema are available
  - location-context identity is expressed through `HomeProjection.projectionKey(for:)`
  - lane-owned slices can be updated independently without clobbering untouched data
- Watch out for:
  - keeping projection writes narrow and concrete rather than introducing a generic ingestion framework
  - not expanding the projection payload beyond the cached home-summary contract unless a later issue explicitly requires it
- Recommended next step:
  - move to issue `#122 Build the Unified Home Ingestion Queue on HomeRefreshV2`, keeping queueing separate from UI loading and using the new projection store only where the current issue truly needs a persisted write seam

## Issue #122 - Build the Unified Home Ingestion Queue on HomeRefreshV2

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Trigger wiring and coordinator shape
  - Precedence and coalescing rules
  - Trigger rules for manual, foreground, background, location-change, and remote hot-alert ingestion
- Issue requirements completed:
  - Added a thin single-flight `HomeIngestionCoordinator` actor that keeps one active run and one merged pending follow-up plan
  - Added normalized ingestion request/plan types with lane requirements, forced lanes, location handling, provenance flags, and optional remote alert payload context
  - Extracted the one-run `HomeRefreshV2` execution path into `HomeIngestionExecutor` so the queue stays focused on submission and coalescing
  - Added focused queue tests for single-flight behavior, pending-plan merging, manual escalation, newest location-bearing request wins, and remote hot-alert wait semantics

### Key implementation notes
- `HomeIngestionPlan` keeps the force model concrete by tracking forced lanes instead of introducing a broader policy engine.
- Hot alerts are enforced in every plan, while slow-products and weather work stay trigger-specific.
- Remote hot-alert payload context is carried through the plan shape now, but APNs-specific use of that context remains deferred to the remote-ingestion issue.
- `HomeScreenModel` now awaits the queue actor instead of calling the execution layer directly.

### Files changed
- `Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- `Sources/App/HomeRefreshV2/HomeScreenModel.swift`
- `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
- `SkyAware.xcodeproj/project.pbxproj`
- `docs/plans/FB-010-progress.md`

### Tests
- Added:
  - `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
    - proves only one ingestion run executes at a time
    - proves pending work merges lanes, force requirements, provenance, and remote alert context
    - proves manual refresh escalates queued work to a full forced refresh
    - proves the newest location-bearing request replaces older pending location context
    - proves a remote hot-alert request can wait on an already-sufficient active background plan
- Updated:
  - `SkyAware.xcodeproj/project.pbxproj`
    - adds the new test file to the synced-folder exceptions so it builds only with the test target

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:SkyAwareTests/HomeIngestionCoordinatorTests test`
  2. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'generic/platform=iOS Simulator' build`
  3. Optional coverage check: `xcrun xccov view --report <xcresult>`
- Expected result:
  - The five `HomeIngestionCoordinatorTests` pass.
  - The `SkyAware` simulator build succeeds.
  - Coverage from the focused xcresult shows:
    - `HomeIngestionCoordinator.swift`: `95.90% (117/122)`
    - `HomeRefreshTrigger.swift`: `84.87% (129/152)`
    - `HomeIngestionCoordinatorTests.swift`: `98.87% (263/266)`

### Out of scope / intentionally deferred
- Wiring every app entry point into the new queue
- Loading the home UI from the projection
- Projection writes and deltas from `HomeRefreshV2`
- APNs-specific hot-alert fetch/continuation behavior that consumes the remote payload context
- Offline/runtime-state UI
- Diagnostics/admin UI

### Risks or follow-ups
- `HomeIngestionExecutor` is intentionally thin and currently verified by the focused queue tests only through fake execution plus the simulator build; the next trigger-routing issue should add integration coverage once the new queue is actually wired into app entry points.
- The current provenance flags are intentionally compact and concrete; later issues should extend them only if trigger adapters truly need more detail.

### Handoff to next issue
- The next issue should assume:
  - `HomeIngestionCoordinator.enqueue(...)` and `enqueueAndWait(...)` are the unified app-layer submission APIs
  - `HomeIngestionPlan` already models lane unions, forced-lane escalation, latest location-bearing context, and remote alert metadata
  - `HomeIngestionExecutor` is the single-plan `HomeRefreshV2` execution seam behind the queue
- Watch out for:
  - keeping trigger adapters thin and outside the coordinator
  - not reintroducing `HomeRefreshPipeline`-style UI/timer/orchestration concerns into the new actor
  - preserving the pending-plan merge rules instead of falling back to last-trigger-wins behavior
- Recommended next step:
  - move to issue `#123` and start routing the foreground/home entry points through the new queue without expanding into background/APNs wiring early

## Issue #123 - Load the Home Experience from the Cached Projection

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Cached home projection as the launch source
  - Projection-observed UI updates
  - Bootstrap loading behavior when no cached projection exists yet
- Issue requirements completed:
  - Switched the Today summary in `HomeView` to render from observed `HomeProjection` rows instead of the old in-memory launch snapshot
  - Added projection selection rules that prefer the current resolved location context and fall back to the newest cached projection while context resolution is still in flight
  - Kept `LoadingView` on the Today launch path until a cached projection exists, so cached outlook data alone no longer bypasses bootstrap loading
  - Extended the existing foreground refresh pipeline to persist successful weather, slow-product, and hot-alert lane updates into `HomeProjection`

### Key implementation notes
- The Today tab now reads placemark, weather, local risks, alerts, and mesos from `HomeProjection` via SwiftData observation.
- The latest convective outlook card now reads from cached `ConvectiveOutlook` SwiftData rows because outlook persistence inside `HomeProjection` was intentionally deferred in issue `#121`.
- The existing foreground refresh path still owns trigger submission for this issue; full trigger migration to `HomeRefreshV2` remains issue `#124`.
- Failed location-scoped foreground reads continue preserving the last good cached projection instead of clobbering persisted slices.

### Files changed
- `Sources/App/HomeView.swift`
- `Sources/App/HomeRefreshPipeline.swift`
- `Sources/Models/Home/HomeProjection.swift`
- `Sources/Models/Convective/ConvectiveOutlook.swift`
- `Tests/UnitTests/HomeRefreshPipelineTests.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/plans/FB-010-progress.md`

### Tests
- Updated:
  - `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
    - proves cached launch selects the projection for the current resolved context
    - proves launch falls back to the newest cached projection while context is still resolving
    - proves bootstrap loading remains visible until a cached projection exists
  - `Tests/UnitTests/HomeRefreshPipelineTests.swift`
    - proves a scene-active refresh persists weather, risk, and hot-alert slices into `HomeProjection`
    - proves failed location-scoped reads do not overwrite an existing cached projection

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:SkyAwareTests test`
  2. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'generic/platform=iOS Simulator' build`
- Expected result:
  - The `SkyAwareTests` target passes.
  - The `SkyAware` simulator build succeeds.
  - If a cached projection exists, the Today experience renders from it immediately and updates as projection writes land.
  - If no cached projection exists yet, `LoadingView` remains in place until the first projection is written.

### Out of scope / intentionally deferred
- Routing foreground triggers through `HomeIngestionCoordinator`
- Switching the Alerts and Outlooks tabs off the existing pipeline-owned state
- Persisting convective outlook payloads inside `HomeProjection`
- Background refresh, APNs, offline-state UI, and diagnostics work

### Risks or follow-ups
- `HomeView` still depends on `HomeRefreshPipeline` for foreground trigger submission and transient loading state; issue `#124` should replace that wiring with the unified queue without regressing the new projection-backed launch behavior.
- Projection launch currently falls back to the newest cached projection while location context is unresolved; future multi-location work should revisit whether `lastViewedAt` needs explicit upkeep instead of relying on `updatedAt`.
- The Alerts tab badge/content still come from pipeline-owned state, so the Today tab can now show cached alerts earlier than the dedicated alerts surfaces.

### Handoff to next issue
- The next issue should assume:
  - Today summary rendering is projection-backed and updates automatically when `HomeProjection` changes
  - successful foreground refreshes already persist lane-owned slices into `HomeProjection`
  - cached outlook content is sourced directly from `ConvectiveOutlook` SwiftData rows for now
- Watch out for:
  - not reintroducing direct network-driven Today rendering while migrating triggers
  - keeping queue migration focused on trigger submission and execution ownership instead of changing the projection contract again
- Recommended next step:
  - move to issue `#124` and route `foreground activate`, `manual refresh`, `session tick`, and `foreground location change` through `HomeIngestionCoordinator` while preserving the new cached-projection launch path

## Issue #124 - Route Foreground Triggers Through the Unified Ingestion Flow

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Trigger wiring and coordinator shape
  - Foreground trigger planning rules
  - Projection persistence from the unified execution path
- Issue requirements completed:
  - Routed `foreground activate`, `manual refresh`, `session tick`, and `foreground location change` through `HomeIngestionCoordinator`
  - Replaced the old foreground execution path in `HomeRefreshPipeline` with a thin SwiftUI-facing adapter over the unified coordinator
  - Moved lane-owned `HomeProjection` persistence into `HomeIngestionExecutor` so unified runs keep the projection-backed Today experience up to date
  - Added focused tests for trigger mapping, trigger submission, lane coverage, projection persistence, and failed location-scoped read preservation

### Key implementation notes
- `HomeIngestionCoordinator` now exposes a small protocol seam so foreground adapters can depend on the unified queue without knowing about its concrete actor type.
- `HomeRefreshPipeline` still owns lightweight UI-facing concerns such as timer scheduling, transient loading state, and manual outlook refreshes, but it no longer owns refresh queueing, throttling, or multi-lane execution.
- `HomeIngestionExecutor` now persists lane-owned projection slices after snapshot reads complete, including the location-change path that forces weather and hot-alert work without unnecessarily broadening the slow-product sync.
- Failed location-scoped foreground reads still preserve the last good cached projection and mark the current refresh key as resolved so the projection-backed launch behavior from issue `#123` remains intact.

### Files changed
- `Sources/App/Dependencies.swift`
- `Sources/App/HomeRefreshPipeline.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- `Sources/App/HomeView.swift`
- `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
- `Tests/UnitTests/HomeRefreshPipelineTests.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/plans/FB-010-progress.md`

### Tests
- Updated:
  - `Tests/UnitTests/HomeRefreshPipelineTests.swift`
    - proves scene-active foreground work submits `foregroundActivate`
    - proves context changes forward the resolved `LocationContext` into the unified queue
    - proves loading-driven manual refresh waits for unified queue completion
    - proves timer refreshes stay on the hot-alert lane
    - proves unified scene-active ingestion persists projection slices
    - proves failed location-scoped reads preserve the cached projection and current UI state
    - proves manual outlook refresh still only touches outlook sync/query paths
  - `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
    - proves foreground trigger plans use the expected lane and forced-lane coverage
  - `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
    - proves foreground `HomeView.RefreshTrigger` values map to the intended unified ingestion triggers

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:SkyAwareTests/HomeRefreshPipelineTests -only-testing:SkyAwareTests/HomeIngestionCoordinatorTests -only-testing:SkyAwareTests/HomeViewRefreshTriggerTests test`
  2. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'generic/platform=iOS Simulator' build`
  3. Inspect `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.04.17_08-24-52--0600.xcresult` if focused failure details or coverage are needed
- Expected result:
  - The focused foreground-routing tests pass.
  - The `SkyAware` simulator build succeeds.
  - Foreground home entry points execute through `HomeIngestionCoordinator`, and successful unified runs continue updating the cached Today projection.

### Out of scope / intentionally deferred
- Background refresh and background location-change queue wiring
- APNs-triggered hot-alert ingestion behavior
- Offline/runtime-state UI, diagnostics/admin surfaces, and notification cleanup
- Moving the Alerts and Outlooks tabs completely off remaining pipeline-owned transient state

### Risks or follow-ups
- `Dependencies.live()` currently builds a dedicated ingestion-side `LocationSession` from the shared location provider/manager/resolver instead of reusing the UI-owned session instance directly; later issues should revisit that choice only if they need stronger shared-session semantics.
- `HomeRefreshPipeline` still exists as a thin UI adapter and timer holder. Follow-on issues should keep shrinking that layer rather than reintroducing execution ownership there.
- The session-tick path still reads back cached snapshot data for UI application even though only the hot-alert lane is active; that is acceptable for this issue, but it is worth watching if future work wants even narrower timer-trigger behavior.

### Handoff to next issue
- The next issue should assume:
  - foreground home entry points already submit work through `HomeIngestionCoordinator`
  - `HomeIngestionExecutor` now owns lane-scoped projection persistence for unified runs
  - the Today launch path remains projection-backed and should not fall back to direct network rendering
- Watch out for:
  - keeping background and notification adapters thin
  - not rebuilding a second queue or trigger-merging layer outside `HomeIngestionCoordinator`
  - preserving the existing failed-read behavior that keeps the last good projection visible
- Recommended next step:
  - move to issue `#125` and route background refresh plus background location-change triggers through the same coordinator without expanding into APNs-specific behavior early

## Issue #125 - Route Background Refresh and Background Location Changes Through the Unified Ingestion Flow

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Background trigger wiring through the unified ingestion flow
  - Background trigger planning rules
  - Separation between ingestion and downstream background side effects
- Issue requirements completed:
  - Routed background app refresh through `HomeIngestionCoordinator` and awaited unified ingestion before morning/meso evaluation and cadence scheduling
  - Routed background location changes through `HomeIngestionCoordinator` and kept watch-notification side effects outside the queue
  - Updated the `background location change` plan to force hot-alert and weather refresh for the new context while still skipping slow-product sync
  - Preserved background HTTP execution semantics inside `HomeIngestionExecutor` so background-triggered sync work stays on the background request policy
  - Added focused tests for background trigger coverage, awaited completion behavior, background-mode sync execution, and retained watch-notification behavior

### Key implementation notes
- `BackgroundOrchestrator` no longer owns direct sync/query logic. It now awaits a `backgroundRefresh` snapshot from the unified queue, then uses that returned snapshot for downstream morning summary evaluation, meso evaluation, health recording, and cadence selection.
- `BackgroundLocationChangeHandler` is now a thin adapter over `backgroundLocationChange` ingestion. It still runs `WatchEngine` afterward so watch-notification removal stays deferred to issue `#128`.
- `HomeIngestionExecutor` now chooses `.background` HTTP execution mode for background-triggered sync steps, preserving the longer timeout/retry policy the old background path relied on.
- When unified background ingestion cannot produce a location-scoped snapshot, `BackgroundOrchestrator` still exits early, records a skipped run, and schedules a shorter retry window instead of evaluating downstream notifications on partial data.

### Files changed
- `Sources/App/Dependencies.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- `Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift`
- `Sources/Features/Background/BackgroundLocationChangeHandler.swift`
- `Sources/Features/Background/BackgroundOrchestrator.swift`
- `Sources/Infrastructure/Networking/HTTPDataDownloader.swift`
- `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`
- `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
- `Tests/UnitTests/WatchNotificationTests.swift`
- `docs/plans/FB-010-progress.md`

### Tests
- Updated:
  - `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
    - proves background trigger plans use the expected lane and forced-lane coverage
  - `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`
    - proves background refresh still uses the resolved/current location context for risk evaluation
    - proves location-unavailable background runs still sync slow products and skip downstream notification work
    - proves unified background refresh is awaited before `BackgroundOrchestrator.run()` completes
    - proves background-triggered SPC sync work runs under background HTTP execution mode
    - proves existing cadence decisions still come from the unified snapshot output
  - `Tests/UnitTests/WatchNotificationTests.swift`
    - proves background location change waits for unified ingestion before watch-notification evaluation
    - proves repeated background location changes still avoid duplicate watch notifications while reusing the unified trigger

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:SkyAwareTests/HomeIngestionCoordinatorTests -only-testing:SkyAwareTests/BackgroundOrchestratorCadenceTests -only-testing:SkyAwareTests/WatchNotificationTests test`
  2. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'generic/platform=iOS Simulator' build`
  3. Inspect `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.04.17_08-55-40--0600.xcresult` if focused failure details are needed
- Expected result:
  - The focused background-routing tests pass.
  - The `SkyAware` simulator build succeeds.
  - Background refresh and background location changes both execute through `HomeIngestionCoordinator`, while downstream notification/cadence behavior remains outside the queue.

### Out of scope / intentionally deferred
- APNs-triggered hot-alert ingestion and notification-open continuation
- Offline/runtime-state UI and diagnostics/admin surfaces
- Removing client-side watch notifications from background location handling
- Broader notification cleanup beyond keeping background notification policy outside the ingestion core

### Risks or follow-ups
- `BackgroundLocationChangeHandler` still runs `WatchEngine` after unified ingestion; issue `#128` should remove that remaining client-side watch path without regressing the now-shared ingestion flow.
- `BackgroundOrchestrator.Outcome.feedsChanged` is still a lightweight, best-effort summary derived from the returned snapshot rather than a dedicated ingestion delta; if later work needs precise change reporting, it should build on the future projection-delta issue rather than reintroducing background-only diffing here.
- The ingestion-side `LocationSession` remains separate from the UI-owned `LocationSession`; later issues should only revisit that if remote/APNs continuation needs stronger shared-session guarantees.

### Handoff to next issue
- The next issue should assume:
  - background app refresh and background location changes already submit work through `HomeIngestionCoordinator`
  - `BackgroundOrchestrator` now treats the unified `HomeSnapshot` as the source of truth for downstream morning/meso/cadence work
  - background location changes still keep watch notifications outside the queue for now
- Watch out for:
  - preserving the precedence rules between remote hot-alert work and any already-running background refresh
  - not moving APNs completion mapping or notification policy into `HomeIngestionCoordinator`
  - avoiding premature removal of the watch-notification path before issue `#128`
- Recommended next step:
  - move to issue `#126` and wire `remote hot alert received` / `remote hot alert opened` into the same coordinator with the existing background merge semantics

## Issue #126 - Implement Remote Hot-Alert Ingestion for APNs Receipt and Open

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Remote hot-alert `received` / `opened` trigger rules
  - Unified ingestion precedence for APNs-driven hot-alert work
  - APNs-driven cache warming and in-app continuity for warned events
- Issue requirements completed:
  - Wired APNs receipt into the unified ingestion queue through `remoteHotAlertReceived`
  - Wired notification-open continuation into the unified ingestion queue through `remoteHotAlertOpened`
  - Added the targeted Arcus single-alert fetch/update path used to warm the warned event locally
  - Preserved background merge semantics so active runs absorb remote hot-alert work only until the hot-alert phase has passed, then queue an immediate follow-up verification
  - Mapped APNs receipt handling to `.newData`, `.noData`, and `.failed`
  - Added notification-open presentation continuity so the alerted watch becomes visible in-app after the unified run completes

### Key implementation notes
- `RemoteHotAlertHandler` is the thin APNs adapter for this issue. It keeps receipt/open handling outside `HomeIngestionCoordinator` while still funneling both paths through the same queue.
- `HomeIngestionExecutor` now uses the new targeted Arcus refresh when a remote alert payload is present, while still keeping mesos in the hot-alert lane and preserving a broader context sync when the plan is wider than pure hot-alert work.
- `HomeIngestionCoordinator` now tracks whether the active run can still satisfy remote hot-alert work. Once the hot-alert phase is marked complete, later APNs requests queue an immediate follow-up instead of incorrectly attaching to a run that has already passed the relevant step.
- `SkyAwareAppDelegate` now parses supported APNs hot-alert payloads, routes receipt to `UIBackgroundFetchResult`, and routes notification-open continuation through the same handler.
- `ArcusAlertIdentifier` introduces a deliberately narrow client-side canonicalization seam for UUID-style series IDs so APNs payload IDs, targeted Arcus refreshes, and local SwiftData lookups match reliably even before the server contract is finalized.

### Files changed
- `Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- `Sources/App/HomeView.swift`
- `Sources/App/RemoteHotAlertHandler.swift`
- `Sources/App/SkyAwareApp.swift`
- `Sources/App/SkyAwareAppDelegate.swift`
- `Sources/Clients/ArcusClient.swift`
- `Sources/Features/Alert/AlertView.swift`
- `Sources/Infrastructure/Parsing/Arcus/ArcusAlertIdentifier.swift`
- `Sources/Interfaces/Arcus/ArcusAlertQuerying.swift`
- `Sources/Interfaces/Arcus/ArcusAlertSyncing.swift`
- `Sources/Models/Watches/Watch.swift`
- `Sources/Models/Watches/WatchRowDTO.swift`
- `Sources/Providers/ArcusAlertProvider.swift`
- `Sources/Repos/WatchRepo.swift`
- `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`
- `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
- `Tests/UnitTests/HomeRefreshPipelineTests.swift`
- `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`
- `Tests/UnitTests/WatchRepoRefreshTests.swift`
- `SkyAware.xcodeproj/project.pbxproj`
- `docs/plans/FB-010-progress.md`

### Tests
- Added:
  - `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`
    - proves APNs receipt maps to `.newData` when the warned event becomes locally available
    - proves APNs receipt maps to `.noData` when the pushed revision is already present locally
    - proves APNs receipt maps to `.failed` when the warned event is still unavailable after unified ingestion
    - proves notification-open publishes a focus request after unified ingestion completes
- Updated:
  - `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
    - proves remote hot-alert requests queue an immediate follow-up once an active run has already passed hot-alert sync
  - `Tests/UnitTests/WatchRepoRefreshTests.swift`
    - proves targeted single-alert Arcus refresh decodes a single payload and persists the revision timestamp for UUID-style series IDs
  - `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`
  - `Tests/UnitTests/HomeRefreshPipelineTests.swift`
    - updated fake Arcus providers/clients to satisfy the new targeted-alert seam without changing their existing test intent
  - `SkyAware.xcodeproj/project.pbxproj`
    - adds the new remote-hot-alert test file to the synced-folder exceptions so it builds only with the test target

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:SkyAwareTests/HomeIngestionCoordinatorTests -only-testing:SkyAwareTests/RemoteHotAlertHandlerTests -only-testing:SkyAwareTests/WatchRepoRefreshTests test`
  2. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'generic/platform=iOS Simulator' build`
  3. Inspect `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.04.17_13-22-53--0600.xcresult` if focused failure details or coverage are needed
- Expected result:
  - The focused remote-hot-alert tests pass.
  - The `SkyAware` simulator build succeeds.
  - APNs receipt enters the unified queue, maps receipt outcomes correctly, and warms the warned event locally when possible.
  - Notification-open continuation enters the same queue and leaves the targeted watch ready to present from local state.

### Out of scope / intentionally deferred
- Runtime offline-state tracking and the offline token UI
- Diagnostics/admin freshness surfaces
- Broader notification cleanup beyond the remote hot-alert path
- Replacing the temporary client-side UUID canonicalization seam with a finalized server-owned series-id contract

### Risks or follow-ups
- `ArcusAlertIdentifier` is intentionally temporary. Once the server/APNs contract guarantees one explicit series-id format end-to-end, later work should remove that client-side normalization seam rather than letting it become permanent incidental behavior.
- Notification-open continuity currently relies on the existing Alerts tab data surface plus a focused local watch lookup. Follow-on alerts-surface work should preserve that presentation path instead of reintroducing direct network reads.
- `SkyAwareAppDelegate` currently accepts several legacy/compatible payload key names while the contract is still settling. Server integration work should tighten that list once the production payload is fixed.

### Handoff to next issue
- The next issue should assume:
  - APNs receipt and notification-open now submit work through `HomeIngestionCoordinator`
  - targeted Arcus single-alert refresh exists and is safe for UUID-style series IDs
  - the remote hot-alert path already distinguishes merge-vs-follow-up behavior around the hot-alert phase boundary
- Watch out for:
  - keeping runtime offline-state work separate from APNs continuation logic
  - not moving notification policy or `UIBackgroundFetchResult` mapping into the coordinator actor
  - preserving the current local-first notification-open continuity while future UI/data-surface issues continue migrating tabs
- Recommended next step:
  - move to issue `#127` and add runtime offline-state tracking plus the simple offline token without disturbing the new APNs hot-alert path

## Issue #127 - Add Runtime Offline State and Surface the Offline Token

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Runtime offline state layered on top of the cached home projection
  - General connectivity and hot-alert lane reachability rules
  - Calm home-summary communication of offline state
- Issue requirements completed:
  - Added a runtime-only `RuntimeConnectivityState` service that uses `NWPathMonitor` for general path availability
  - Wired Arcus hot-alert reachability into the existing `ArcusHttpClient`, marking the hot-alert lane unavailable when requests fall back to cache or cannot obtain a live response
  - Injected the runtime state through `SkyAwareApp` and surfaced a restrained `Offline` token in the Today `Current Conditions` header while leaving cached projection content visible
  - Added focused tests covering runtime path-state transitions and Arcus reachability reporting

### Key implementation notes
- `RuntimeConnectivityState` is intentionally runtime-only. It is not persisted to SwiftData and does not alter `HomeProjection` freshness or ownership.
- The Arcus reachability signal stays narrowly tied to real hot-alert fetch outcomes instead of inventing a separate probe endpoint. Live and revalidated responses clear the offline token; cache fallback and failed fetches assert it.
- The token is rendered in `SummaryStatus` so the home summary communicates connectivity loss without adding a staleness badge or changing the cached Today payload.

### Files changed
- `Sources/App/Dependencies.swift`
- `Sources/App/HomeView.swift`
- `Sources/App/RuntimeConnectivityState.swift`
- `Sources/App/SkyAwareApp.swift`
- `Sources/Clients/ArcusClient.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Tests/UnitTests/NwsHttpClientTests.swift`
- `docs/plans/FB-010-progress.md`

### Tests
- Updated:
  - `Tests/UnitTests/NwsHttpClientTests.swift`
    - proves live Arcus responses mark hot-alert reachability as reachable
    - proves cache-fallback Arcus responses still return cached data while marking hot-alert freshness as unavailable
    - proves runtime connectivity state stays online while the general path is available and flips offline when the general path becomes unavailable
    - proves Arcus reachability alone can assert and clear the offline token while cached content remains available

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:SkyAwareTests/ArcusHttpClientTests -only-testing:SkyAwareTests/RuntimeConnectivityStateTests test`
  2. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'generic/platform=iOS Simulator' build`
  3. Inspect `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.04.17_13-50-36--0600.xcresult` and `xcrun xccov view --report <xcresult>` if focused coverage details are needed
- Expected result:
  - The focused offline-state tests pass.
  - The `SkyAware` simulator build succeeds.
  - The Today summary continues rendering cached content while an `Offline` token appears whenever the general network path or live Arcus alert reachability is unavailable.
  - Focused coverage from the recorded xcresult shows:
    - `Sources/App/RuntimeConnectivityState.swift`: `76.19% (64/84)`
    - `Sources/Clients/ArcusClient.swift`: `50.40% (63/125)`
    - `Tests/UnitTests/NwsHttpClientTests.swift`: `41.85% (131/313)`

### Out of scope / intentionally deferred
- Diagnostics/admin freshness UI
- Surfacing the offline token on additional tabs or settings/diagnostics surfaces
- Adding a dedicated Arcus health-probe endpoint beyond the existing hot-alert fetch path
- Notification cleanup, projection deltas, or other non-issue ingestion work

### Risks or follow-ups
- Arcus reachability is updated when real Arcus fetches run. If the app regains general connectivity between hot-alert refreshes, the token can remain until the next live Arcus check confirms recovery.
- The runtime connectivity service currently lives at the app shell and feeds the Today summary only. Future work should keep it runtime-only and resist folding it into persisted projection state or coordinator policy.

### Handoff to next issue
- The next issue should assume:
  - the Today summary now has a runtime-only offline token layered over cached projection content
  - `RuntimeConnectivityState` owns general-path monitoring and receives hot-alert reachability updates from `ArcusHttpClient`
  - cache-fallback Arcus responses intentionally count as offline for the hot-alert lane because they do not verify fresh alert data
- Watch out for:
  - not turning the offline token into a general stale-data badge
  - not moving connectivity UI state into SwiftData or `HomeProjection`
  - preserving the small `ArcusHttpClient` reporting seam rather than growing a separate health-check framework unless a later issue truly needs it
- Recommended next step:
  - move to issue `#128` and remove the remaining client-side watch-notification path while preserving the unified ingestion flow and the new runtime-only offline state behavior
