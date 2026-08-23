# Weekly Performance Audit

## 2026-05-24
- workflow reviewed: Location Resolution and Context Formation
- files inspected:
  - Sources/Infrastructure/Location/LocationSession.swift
  - Sources/Infrastructure/Location/LocationContextResolver.swift
  - Sources/Providers/Location/LocationProvider.swift
  - Sources/App/HomeView.swift
- top finding: `LocationSession` clears `currentContext` to `nil` before setting the resolved context, creating avoidable double invalidation of SwiftUI observers per context refresh.
- second finding: `HomeView` recalculates `refreshLocationReliabilityRail()` through both `.onChange` and `.task(id:)` for the same dependencies (`locationSession.reliabilityState`, `displayedStormRisk`, `displayedSevereRisk`), causing duplicate recomputation and ledger checks per state transition.
- second finding status: completed on 2026-05-25
- second finding implementation notes:
  - Removed duplicate `.task(id:)` rail refresh triggers for reliability/risk dependencies.
  - Kept `.onChange` triggers and added a single initial `.task` to preserve first-load evaluation.
- best next fix: replace the `nil -> context` reset pattern with single guarded assignment keyed by refresh identity to avoid duplicate invalidations and downstream refresh triggers.
- implementation recommended: yes
- implementation status: completed on 2026-05-25
- implementation notes:
  - Replaced `nil -> context` reset pattern with `applyResolvedContext(_:)` in `LocationSession`.
  - Added refresh-key guard to skip `currentContext` reassignment when location scope identity is unchanged.

## 2026-06-07
- workflow reviewed: Foreground Refresh and UI State Propagation
- files inspected:
  - Sources/App/HomeView.swift
  - Sources/App/HomeRefreshPipeline.swift
  - Sources/Features/Summary/SummaryView.swift
  - Sources/Features/Summary/SummaryStatus.swift
  - Sources/Features/Summary/ActiveAlertSummaryView.swift
- top finding: `HomeView` stores Today tab scroll-condense progress at the shell root, so every scroll tick invalidates the entire five-tab container and recomputes unrelated derived state such as cached outlook DTO mapping and projection selection.
- best next fix: move `todayHeaderCondenseProgress` into the Today-tab subtree, or into `SummaryView`, so scroll-driven updates only invalidate the visible summary header instead of the whole `TabView`.
- measurement gap: profile `HomeView` and `SummaryView` body recomputation counts while scrolling the Today tab to quantify fan-out and confirm whether the root-shell invalidation is visible in Instruments.
- implementation recommended: yes
- implementation status: completed on 2026-06-07
- implementation notes:
  - Moved Today scroll-condense state into a dedicated `TodayTabView` subtree in `HomeView`.
  - Kept the visible behavior intact while preventing scroll progress from invalidating the full five-tab shell.

## 2026-06-14
- workflow reviewed: Layered Risk Map
- files inspected:
  - Sources/Features/Map/MapScreenView.swift
  - Sources/Features/Map/MapAccessibilitySupport.swift
  - Sources/Features/Map/MapLegendView.swift
  - Sources/Features/Map/MapFeatureModel.swift
  - Sources/Features/Map/MapCanvasView.swift
  - Sources/Features/Map/MapPolygonMapper.swift
  - Sources/Features/Map/MapCoordinator.swift
  - Sources/Features/Map/RiskPolygonRenderer.swift
- top finding: `MapScreenContent` recomputes warning legend items and accessibility summary data from the same overlay array multiple times per render, which adds avoidable overlay parsing and dedup work to the map tab's hottest SwiftUI body.
- best next fix: hoist `WarningLegendItem.rendered(from:)` and the derived accessibility summary inputs into a single precomputed value per `scene` update, then thread that value through the legend sheet and summary element so the overlay array is walked once instead of several times.
- measurement gap: profile `MapScreenContent` body recomputation count and overlay-derived item generation while toggling warning geometry and changing layers to confirm the duplicate work is visible in Instruments.
- implementation recommended: yes
- implementation status: completed on 2026-06-17
- implementation notes:
  - Added `warningLegendItems` to `MapLayerScene` and materialized it once per scene update.
  - Swapped `MapScreenContent` and `MapAccessibilitySummary` to the precomputed scene data.
  - Ran targeted `MapFeatureModelTests` and `MapLegendAccessibilityTests` in the iPhone 17 simulator destination; both passed.

## 2026-06-21
- workflow reviewed: Alerts workflow
- files inspected:
  - Sources/App/HomeView.swift
  - Sources/Features/Alert/AlertView.swift
  - Sources/Features/Alert/AlertPresentationOrdering.swift
  - Sources/Features/Alert/AlertRowView.swift
  - Sources/Features/Alert/AlertDetailView.swift
  - Sources/Features/Summary/ActiveAlertSummaryView.swift
- top finding: `AlertView` recomputes sorted alert and mesoscale arrays multiple times per render, and also recomputes latest-issued summary data from the same inputs, so the Alerts tab repeats presentation ordering work instead of paying for it once when the data changes.
- best next fix: hoist sorted alerts, sorted mesos, and the latest-issued timestamp into stored values initialized from the input arrays, matching the precompute pattern already used by `ActiveAlertSummaryView`.
- measurement gap: profile `AlertView` body recomputation count and `AlertPresentationOrdering.ordered` call frequency while refreshing alerts or handling a focused-alert handoff to quantify how often the duplicate work fires.
- implementation recommended: yes
- implementation status: completed on 2026-06-22
- implementation notes:
  - Hoisted sorted alerts, sorted mesos, and latest-issued derivation into stored values in `AlertView`.
  - Verified the change with `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`.

## 2026-06-28
- workflow reviewed: Convective Outlooks workflow
- files inspected:
  - docs/codebase/skyaware-app-summary.md
  - Sources/App/HomeView.swift
  - Sources/App/HomeRefreshPipeline.swift
  - Sources/App/HomeRefreshV2/HomeSnapshotStore.swift
  - Sources/Features/ConvectiveOutlookView/ConvectiveOutlookView.swift
  - Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift
  - Sources/Features/ConvectiveOutlookView/OutlookRowView.swift
  - Sources/Features/Summary/OutlookSummaryCard.swift
  - Sources/Features/Summary/OutlookView.swift
  - Sources/Models/Convective/ConvectiveOutlookDTO.swift
  - Sources/Repos/ConvectiveOutlookRepo.swift
- top finding: `ConvectiveOutlookDTO` assigns a fresh `UUID()` in its initializer, so the same SPC outlook becomes a brand-new identity on every refresh or snapshot load, which forces SwiftUI to treat unchanged rows as replacements instead of updates.
- best next fix: derive the DTO identity from a stable feed-backed key such as `link` or the canonical outlook title/published tuple, so `ConvectiveOutlookView` and any summary surfaces can preserve row identity across refreshes.
- measurement gap: profile Outlooks-tab row diff churn and `OutlookRowView` body recomputation count across a manual refresh to confirm how much identity instability is visible in Instruments.
- implementation recommended: yes
- implementation status: completed on 2026-07-01
- implementation notes:
  - Changed `ConvectiveOutlookDTO.id` to use `link.absoluteString` instead of a fresh `UUID()`.
  - Verified with `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/SkyAware-PerformanceAudit build`.

## 2026-07-05
- workflow reviewed: App Launch and Composition
- files inspected:
  - docs/codebase/skyaware-app-summary.md
  - Sources/App/SkyAwareApp.swift
  - Sources/App/HomeView.swift
  - Sources/App/HomeRefreshPipeline.swift
  - Sources/Models/Health/BgHealthStore.swift
  - Sources/Providers/SPC/SpcProvider+Cleanup.swift
  - Sources/Providers/ArcusAlertProvider.swift
  - Sources/Repos/AlertRepo.swift
  - Sources/Repos/MesoRepo.swift
  - Sources/Repos/StormRiskRepo.swift
  - Sources/Repos/SevereRiskRepo.swift
- top finding: `SkyAwareApp` kicks off activation cleanup on every `.active` transition, and that task fans out into `BgHealthStore.purge()`, `SpcProvider.cleanup()`, and `ArcusAlertProvider.cleanup()` while `HomeView` also starts the foreground refresh pipeline, so the app pays repeated datastore cleanup cost exactly when it is trying to become interactive.
- best next fix: gate activation cleanup behind a last-run timestamp so the purge passes run at most hourly instead of on every activation.
- measurement gap: profile activation-to-first-interactive latency and per-repo cleanup duration on a real data set to confirm how much foreground contention the cleanup chain adds.
- implementation recommended: yes
- implementation status: completed on 2026-07-05
- implementation notes:
  - Added `activationCleanupLastRunAt` persistence to `SkyAwareApp`.
  - Gated activation cleanup to once per hour before launching the existing cleanup task.
  - Verified with `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone 17" build`.

## 2026-07-12
- workflow reviewed: Background App Refresh
- files inspected:
  - docs/codebase/skyaware-app-summary.md
  - Sources/App/SkyAwareApp.swift
  - Sources/Features/Background/BackgroundOrchestrator.swift
  - Sources/Infrastructure/Location/LocationSnapshotPusher.swift
  - Sources/Infrastructure/Scheduling/BackgroundScheduler.swift
  - Sources/Models/Health/BgHealthStore.swift
  - Sources/Features/Diagnostics/BgHealthDiagnosticsView.swift
- top finding: `BackgroundOrchestrator` drains pending location uploads before it starts unified background ingestion, and the drain path can sort every queued request and spend 5s/15s retry delays per item, so a backlog can burn the task budget before weather state is refreshed.
- best next fix: move or cap upload draining so the core background refresh and notification work runs first within the available background task window.
- measurement gap: instrument orchestrator span time and pending-upload drain duration against queue size to confirm whether backlog materially increases expiration risk.
- implementation recommended: yes
- implementation status: completed on 2026-07-12
- implementation notes:
  - Moved pending upload draining to the end of `BackgroundOrchestrator.run()` so unified ingestion and notifications complete first.
  - Added a cancellation-safe skip before upload draining so a cancelled background task does not start queue replay.
  - Verified with `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,id=F5154D35-3398-4BEB-943E-E8D174B32832' build`.

> **Supersession note (2026-07-24):** The original findings and implementation notes above remain point-in-time
> evidence. Later review and implementation superseded the post-ingestion ordering: current cancellation handling
> performs a bounded pre-ingestion pending-upload drain of at most one upload or five seconds, then proceeds with the
> subsequent background work.

## 2026-07-19
- workflow reviewed: Location Resolution and Context Formation
- files inspected:
  - docs/codebase/skyaware-app-summary.md
  - Sources/Infrastructure/Location/LocationSession.swift
  - Sources/Infrastructure/Location/LocationManager.swift
  - Sources/Providers/Location/LocationProvider.swift
  - Sources/Infrastructure/Location/LocationContextResolver.swift
  - Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift
  - Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift
  - Sources/App/HomeView.swift
  - Sources/Features/Map/MapScreenView.swift
  - Sources/Features/Onboarding/OnboardingView.swift
  - Sources/Features/Settings/SettingsDiagnosticsView.swift
- top finding: `LocationContextResolver.resolveContext` always routes through reverse geocoding, so the same coordinate can pay placemark work again during onboarding, foreground refresh, and hot-location handoffs even when `LocationProvider` already has a usable snapshot.
- best next fix: add a small same-coordinate placemark reuse check in `LocationProvider.ensurePlacemark` so context resolution skips reverse geocoding when the cached placemark is already valid.
- measurement gap: profile reverse-geocode call count and end-to-end context resolution latency across onboarding and foreground refresh.
- implementation recommended: yes
- implementation status: completed on 2026-07-19
- implementation notes:
  - Reused an unchanged coordinate's cached snapshot only when it has a non-empty placemark and H3 cell.
  - Added a focused `LocationProviderTests` assertion that the reuse path makes no reverse-geocode call.
  - Verified with `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/LocationProviderTests test`.

## 2026-07-26
- workflow reviewed: Widget and Glanceable Summary Rendering
- files inspected:
  - docs/codebase/skyaware-app-summary.md
  - Shared/SkyAwareWidgetKind.swift
  - Shared/WidgetSnapshot.swift
  - Shared/WidgetSnapshotStore.swift
  - Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift
  - Sources/App/HomeRefreshV2/WidgetSnapshotBuilder.swift
  - Sources/App/HomeRefreshV2/WidgetSnapshotRefreshCoordinator.swift
  - WidgetsExtension/SkyAwareWidgetsBundle.swift
  - WidgetsExtension/WidgetCombinedComponents.swift
  - WidgetsExtension/WidgetStormRiskComponents.swift
  - WidgetsExtension/WidgetSevereRiskComponents.swift
  - Tests/UnitTests/WidgetSnapshotRefreshCoordinatorTests.swift
- top finding: no code-supported performance defect met the recommendation threshold; snapshot derivation stays outside
  SwiftUI rendering, refresh scope targets only affected widget kinds, and the remaining rendering and reload concerns
  require runtime evidence.
- best next fix: no production change recommended; first capture WidgetKit render duration and extension CPU for the
  combined widget, plus reload request counts during foreground and background ingestion.
- measurement gap: quantify the cost of the combined widget's layered gradients and large blurred glow circles, and
  determine whether unchanged-risk ingestion causes materially redundant timeline renders.
- implementation recommended: no

## 2026-08-02
- workflow reviewed: Settings and Diagnostics
- why selected: This is the only named product workflow in the current app summary with no prior performance-audit
  entry; Today, Alerts, Map, Outlooks, location, background work, launch, and widgets were all reviewed recently.
  Its diagnostic lists and repeated refresh/filter actions also provide concrete SwiftUI update paths to inspect.
- files inspected:
  - docs/codebase/skyaware-app-summary.md
  - Sources/Features/Settings/SettingsView.swift
  - Sources/Features/Settings/SettingsDiagnosticsView.swift
  - Sources/Features/Diagnostics/DiagnosticsView.swift
  - Sources/Features/Diagnostics/BgHealthDiagnosticsView.swift
  - Sources/Features/Diagnostics/LogViewerView.swift
- performance risk summary: The main Settings surface is largely static and uses lazy layout. The Log Viewer has one
  code-supported cancellation gap that can preserve superseded log scans during rapid filter or configuration changes.
- findings:

  | Finding | Evidence | Performance mechanism | Impact | Confidence | Evidence type | Change size | Regression risk | Recommended action |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | Superseded log loads do not cancel their detached scans | `LogViewerView.triggerLoad` cancels `loadTask`, but `fetchLogs` creates a detached task and only that detached task's cancellation state is checked in its enumeration loop. The parent cancellation is not forwarded to it. | Rapid query, window, subsystem, or limit changes can leave multiple `OSLogStore` enumerations running and permit an older load to publish after a newer request. | Medium | High | Code-supported | S | Low | Wrap the detached scan in a cancellation handler that explicitly cancels it when the awaiting load is cancelled, and check cancellation before publishing fetched rows. |

  - implementation completed: Propagated cancellation from `loadTask` into the detached `OSLogStore` scan in
    `Sources/Features/Diagnostics/LogViewerView.swift`, rejected cancelled results before assigning `lines` and
    `exportCache`, and protected loading-state ownership. Deterministic `LogViewerCancellationTests` pass 3/3; the
    Debug build passed. The full unit lane reported 1 unrelated pre-existing failure and 1,003 passing tests.
- measurement gap: Instrument active `OSLogStore` scan count, scan duration, and result-publication order while typing
  into the filter with the 2-hour/2,000-entry configuration. No runtime trace or measured latency was available in
  this audit.
- watchlist: `DiagnosticsView` observes an unbounded, sorted `@Query` and maps every cached projection to a record on
  each diagnostics recomputation even though it displays one projection. Record projection count, SwiftData fetch
  frequency, and body recomputation cost before considering a narrower fetch; current user impact is not established.
  - implementation recommended: completed, limited to the Log Viewer cancellation fix

## 2026-08-09
- Date: 2026-08-09
- Repository reviewed: project-arcus
- Workflow reviewed: Settings and Diagnostics
- Workflow selection reason: This workflow changed materially after its 2026-08-02 audit: commit `5d7a51e0` implemented
  cancellation propagation and stale-result ownership for the Log Viewer finding. Re-reviewing the same workflow was
  therefore higher value than selecting an unchanged workflow because current `HEAD` can verify whether the recorded
  performance mechanism was actually removed.
- Previous workflow review: 2026-08-02
- Commit window: `63ddc0296592cf36ce26339d95d01b818d126c59..5d7a51e0571686d8ab8c2524ec40fbd0352445b6`
  (2026-08-02 through 2026-08-09); workflow-specific marker was the prior audit entry and its remediation commit.
- Relevant commits: `5d7a51e0` (`Fix logging perf issue`).
- Relevant changed files: `Sources/Features/Diagnostics/LogViewerView.swift`,
  `Tests/UnitTests/LogViewerCancellationTests.swift`.
- Files and symbols inspected:
  - `docs/codebase/skyaware-app-summary.md` — Settings and Diagnostics product surface
  - `Sources/Features/Diagnostics/LogViewerView.swift` — `LogViewerView.triggerLoad`, `load(requestID:)`,
    `LogViewerLoadState`, `fetchLogs`, and `runDetachedLogScan`
  - `Tests/UnitTests/LogViewerCancellationTests.swift` — parent cancellation, partial-result rejection, and stale-request
    ownership tests
- Tests, metrics, traces, or profiling inspected: Inspected the three deterministic cancellation tests introduced by
  `5d7a51e0`. A fresh targeted `SkyAware_Tests` invocation was attempted on iPhone 17 / iOS 26.5 / Debug, but testing
  did not start because the sandbox could not connect to CoreSimulatorService or write required SwiftPM/module caches;
  no finalized result bundle or test counts were available. No profiler trace, timing metric, or device capture exists.
- Findings: No new or recurring confirmed performance finding. No performance action recommended.
- Measurement gaps: Runtime scan cancellation latency and active `OSLogStore` scan count remain unmeasured, but the
  original unpropagated-cancellation mechanism is no longer present and does not justify a measurement issue by itself.
- Watchlist: The unchanged 2026-08-02 `DiagnosticsView` unbounded-query concern was not re-added; no new evidence was
  discovered in this workflow-specific commit window.
- Resolved findings:
  - Finding ID: `PERF-ARCUS-SETTINGS-LOG-SCAN-CANCELLATION`
  - Fingerprint: `performance|project-arcus|settings-and-diagnostics|log-viewer|superseded-detached-scan`
  - Repository: project-arcus
  - Audit type: Weekly Workflow Performance Audit
  - Workflow: Settings and Diagnostics
  - Title: Superseded Log Viewer loads retain detached log scans
  - Status: RESOLVED
  - Severity: MEDIUM
  - Confidence: HIGH
  - Evidence class: CODE-SUPPORTED
  - First observed: 2026-08-02
  - Last verified: 2026-08-09
  - Affected files and symbols: `Sources/Features/Diagnostics/LogViewerView.swift` — `triggerLoad`,
    `load(requestID:)`, `runDetachedLogScan`, and `LogViewerLoadState`
  - Execution path: A query or configuration change cancels the parent load task; `runDetachedLogScan` now forwards
    that cancellation to the detached scan, enumeration checks cancellation, and request ownership rejects stale
    publication or loading-state completion.
  - Performance mechanism: The prior detached-task cancellation gap has been removed, so superseded loads no longer
    have a code path that intentionally continues scanning or publishes stale results.
  - User or operational impact: Rapid Log Viewer changes no longer retain superseded scans by construction, reducing
    avoidable diagnostic CPU work and stale-result churn without changing the displayed log contract.
  - Measurement evidence: None; resolution is established from the current execution path and deterministic test
    coverage, not a measured latency or CPU improvement.
  - Measurement gap: A device trace would be required to quantify cancellation latency or CPU savings.
  - Minimal fix strategy: Completed in `5d7a51e0`; no further production change recommended.
  - Required validation: Re-run `LogViewerCancellationTests` when simulator services are available; use Instruments
    only if quantitative benefit or cancellation latency must be established.
  - Related GitHub issue: None found or required for a resolved finding.
- Top finding: The 2026-08-02 Log Viewer cancellation finding is resolved at current `HEAD`.
- Best next action: No implementation or measurement issue; retain the deterministic cancellation coverage and allow a
  future audit to select another workflow unless Settings and Diagnostics changes materially again.
- Implementation recommended: no
- Measurement recommended: no
- GitHub issues created: none
- GitHub issues updated: none
- Existing issues referenced: none
- Out-of-scope repositories: arcus-signal; ArcusCore


## 2026-08-20
- Date: 2026-08-20
- Repository reviewed: project-arcus
- Workflow reviewed: Today refresh and presentation
- Workflow selection reason: Commit `56fa92a4` materially changed the shared Today ingestion and projection path after
  the 2026-06-07 foreground-refresh audit by adding per-domain risk comparison baselines. Today remains the primary,
  frequently refreshed user surface, and the new persistence work runs before its coherent core publication.
- Previous workflow review: 2026-06-07 (`Foreground Refresh and UI State Propagation`)
- Commit window: `ab86f7efed5583e6b555ce1c7f5a7c05f53375d4..56fa92a44162761a4426de5962f0bf7e7acc58da`
  (2026-06-07 through 2026-08-20), using the prior workflow audit date because no workflow-specific commit marker was
  recorded.
- Relevant commits: `56fa92a4` (`Prevent false risk-change notifications from partial syncs and movement`),
  `126cd521` (`Simplify SkyAware refresh architecture and document validation`), and `0697e440` (`Improve Today refresh
  pipeline and stabilize presentation`).
- Relevant changed files: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`,
  `Sources/Repos/HomeProjectionStore.swift`, `Sources/App/HomeView.swift`, `Tests/UnitTests/HomeProjectionStoreTests.swift`,
  and `Tests/UnitTests/HomeRefreshPipelineTests.swift`.
- Files and symbols inspected:
  - `docs/codebase/skyaware-app-summary.md` — unified ingestion, persistence, and Today presentation workflow
  - `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift` — `run`, `persistProjection`,
    `reconcilingRejectedRiskDomains`, and `slowProductPersistenceDecision`
  - `Sources/Repos/HomeProjectionStore.swift` — `commitCore`, `advancesComparisonBaseline`,
    `activeComparisonSourceKey`, `invalidateOtherComparisonBaselines`, and `fetchProjection`
  - `Sources/App/HomeView.swift` — `cachedProjections` and `presentationSnapshot(now:)`
  - `Tests/UnitTests/HomeProjectionStoreTests.swift` and `Tests/UnitTests/HomeRefreshPipelineTests.swift` — accepted,
    rejected, mixed-domain, persistence, and publication coverage
- Tests, metrics, traces, or profiling inspected: Current deterministic tests cover risk-baseline correctness but do
  not count projection fetches or vary retained projection volume. Historical Release/device evidence in
  `docs/plans/today-refresh-performance-progress.md` includes refresh duration, save intervals, body updates, and
  hitches, but it does not record retained projection count or isolate baseline-scan cost. No new trace or test run was
  required for this audit-only measurement finding.
- Findings:
  - Finding ID: `PERF-ARCUS-TODAY-PROJECTION-SCAN-SCALING`
  - Fingerprint: `performance|project-arcus|today-refresh-and-presentation|home-projection|unbounded-baseline-and-query-scan`
  - Repository: project-arcus
  - Audit type: Weekly Workflow Performance Audit
  - Workflow: Today refresh and presentation
  - Title: Projection-count scaling is unknown for risk baseline maintenance and Today observation
  - Status: MEASUREMENT REQUIRED
  - Severity: MEDIUM
  - Confidence: MEDIUM
  - Evidence class: MEASUREMENT GAP
  - First observed: 2026-08-20
  - Last verified: 2026-08-20
  - Affected files and symbols: `Sources/Repos/HomeProjectionStore.swift` — `activeComparisonSourceKey` and
    `invalidateOtherComparisonBaselines`; `Sources/App/HomeView.swift` — `cachedProjections` and
    `presentationSnapshot(now:)`
  - Execution path: An accepted slow-product refresh reaches `HomeProjectionStore.commitCore`; each accepted domain
    advances its comparison baseline, may scan all projections for an inherited source, and always fetches all
    projections to clear competing baselines before the core save. The save invalidates `HomeView`'s unbounded sorted
    projection query, whose presentation derivation maps every retained projection to a record.
  - Performance mechanism: Work is structurally proportional to the total retained `HomeProjection` collection, and
    an accepted convective-plus-fire commit invokes baseline invalidation once per domain. No projection retention or
    purge bound was found. Material runtime impact is not established because current traces do not report projection
    count or isolate these fetches.
  - User or operational impact: If projection history grows through travel, foreground publication and background
    ingestion may accumulate avoidable SwiftData fetch/mutation work before Today publication. The likely frequency is
    accepted slow-product refreshes; the real-world row-count distribution and latency remain unknown.
  - Measurement evidence: Historical Release/device traces provide end-to-end timing only; there is no row-count
    scaling series, query count, or isolated baseline-scan duration.
  - Measurement gap: Measure 1, 10, 100, and 1,000 retained projections under the same accepted slow-product refresh;
    record fetch count, rows fetched/mutated, core-commit duration, commit-to-render duration, body updates, and hitches.
  - Minimal fix strategy: Do not select an optimization yet. If measurement confirms material scaling, prefer a
    bounded/predicate baseline update and a narrowed Today projection input without changing risk-notification or
    location/source semantics.
  - Required validation: Deterministic seeded-store scaling measurement first, followed by a Release physical-device
    trace only when the measured trend is material.
  - Related GitHub issue: Creation attempted on 2026-08-20 as `[Performance Measurement] Today refresh: quantify
    projection scan scaling`; the GitHub connector rejected the write because approval is disabled, so no issue exists.
- Measurement gaps: `PERF-ARCUS-TODAY-PROJECTION-SCAN-SCALING` is the sole promoted measurement gap for this run.
- Watchlist: Partial-domain rejection now performs an extra projection lookup in
  `HomeIngestionExecutor.reconcilingRejectedRiskDomains` before `commitCore` fetches the same projection. Rejected
  syncs are not a credible hot path and no latency evidence exists; promote only if rejection telemetry shows material
  frequency or profiling attributes meaningful time to the duplicate lookup.
- Resolved findings: none
- Top finding: `PERF-ARCUS-TODAY-PROJECTION-SCAN-SCALING` (MEASUREMENT REQUIRED, MEDIUM confidence).
- Best next action: Run the bounded seeded-store scaling measurement before choosing any retention, predicate-fetch,
  baseline-ownership, or SwiftUI-query optimization.
- Implementation recommended: no
- Measurement recommended: yes
- GitHub issues created: none; measurement issue creation failed because the GitHub connector required approval while
  this automation's approval policy is `never`.
- GitHub issues updated: none
- Existing issues referenced: closed issues #318, #319, #320, and #345 provide historical Today performance context
  but do not measure retained-projection scaling and are not duplicates.
- Out-of-scope repositories: arcus-signal; ArcusCore

## 2026-08-23
- Date: 2026-08-23
- Repository reviewed: project-arcus
- Workflow reviewed: Layered Risk Map
- Workflow selection reason: No production workflow changed after the 2026-08-20 Today audit, so selection fell back
  to review age and impact. The Layered Risk Map was last reviewed on 2026-06-14, is the oldest un-reverified complex
  product surface, and performs MapKit geometry construction on a frequently interactive path.
- Previous workflow review: 2026-06-14
- Commit window: `59893c99e4648105d07a98257075afa4ae020050..57b73e3a604c14c0d0e4d1791dc4e5464e81d47e`
  (2026-06-14 through 2026-08-23), using the prior audit date because the earlier entry recorded no workflow-specific
  commit marker. No production commits landed after 2026-08-20; the end commit only updates release documentation.
- Relevant commits: `6e5327e8` (precompute warning legend data), `3bc13be1` (decompose map model and render planning),
  `8bf056f7` (preserve polygon holes), and `126cd521` (refresh-architecture simplification touching Map composition).
- Relevant changed files: `Sources/Features/Map/MapFeatureModel.swift`,
  `Sources/Features/Map/MapRenderPlan.swift`, `Sources/Features/Map/MapScenePlanner.swift`,
  `Sources/Features/Map/MapCanvasView.swift`, `Sources/Features/Map/MapCoordinator.swift`, and Map unit-test suites.
- Files and symbols inspected:
  - `docs/codebase/skyaware-app-summary.md` — Map product surface and G5 runtime ownership
  - `Sources/Features/Map/MapScreenView.swift` — activation reload, layer selection, warning toggle, and content rendering
  - `Sources/Features/Map/MapFeatureModel.swift` — `reload`, `performReload`, `applySelectedLayer`,
    `setWarningGeometryVisible`, `scheduleWarmRemainingScenes`, and scene caches
  - `Sources/Features/Map/MapScenePlanner.swift` and `Sources/Features/Map/MapRenderPlan.swift` — render-plan construction
    and main-actor `MapSceneMaterializer.materialize`
  - `Sources/Features/Map/MapCanvasView.swift` and `Sources/Features/Map/MapCoordinator.swift` — revision-gated overlay
    synchronization and stable overlay reuse
  - `Sources/Features/Map/MapPolygonMapper.swift`, `MapAccessibilitySupport.swift`, and `MapLegendView.swift` — geometry,
    summary, and warning-legend derivation
  - `Tests/UnitTests/MapFeatureModelTests.swift`, `MapFeatureModelSceneTests.swift`,
    `MapFeatureModelWarningsTests.swift`, `MapPolygonMapperTests.swift`, and `MapLegendAccessibilityTests.swift`
- Tests, metrics, traces, or profiling inspected: Current deterministic tests establish layer/warning composition,
  overlay ordering and stable keys, polygon-hole preservation, revision stability, and accessibility output. No test,
  benchmark, signpost capture, Time Profiler trace, Allocations capture, or physical-device measurement compares eager
  inactive-scene warming with lazy materialization. No test run was required because this audit changed documentation
  only and did not claim runtime validation.
- Findings:
  - Finding ID: `PERF-ARCUS-MAP-SCENE-WARMING`
  - Fingerprint: `performance|project-arcus|layered-risk-map|map-feature-model|eager-inactive-scene-materialization`
  - Repository: project-arcus
  - Audit type: Weekly Workflow Performance Audit
  - Workflow: Layered Risk Map
  - Title: Inactive map-scene warming cost and layer-switch benefit are unmeasured
  - Status: MEASUREMENT REQUIRED
  - Severity: MEDIUM
  - Confidence: MEDIUM
  - Evidence class: MEASUREMENT GAP
  - First observed: 2026-08-23
  - Last verified: 2026-08-23
  - Affected files and symbols: `Sources/Features/Map/MapFeatureModel.swift` — `performReload`,
    `setWarningGeometryVisible`, and `scheduleWarmRemainingScenes`; `Sources/Features/Map/MapRenderPlan.swift` —
    `MapSceneMaterializer.materialize`
  - Execution path: A Map activation reload fetches five data domains concurrently, builds plans for every layer,
    materializes the selected scene, then starts a main-actor task that materializes and caches every inactive layer.
    Changing warning visibility clears all cached scenes, rematerializes the selected scene, and repeats the inactive
    warming pass.
  - Performance mechanism: Each inactive-scene materialization builds a polygon lookup, constructs overlay wrappers,
    hashes every overlay revision, and derives warning legend items. The work is proportional to overlay volume and is
    performed for four inactive layers on every successful reload or warning-toggle cache reset, but it may reduce
    the first-switch latency enough to be worthwhile.
  - User or operational impact: Eager warming can add main-thread CPU and retained overlay memory immediately after Map
    refresh while the user is interacting with the selected layer. Removing it without evidence could instead move
    that cost into a visible layer switch, so current impact and the correct tradeoff remain unknown.
  - Measurement evidence: None. Code establishes the eager repeated work, while current tests establish behavioral
    contracts only; no timing, allocation, hitch, or layer-switch baseline exists.
  - Measurement gap: Compare current eager warming with an instrumentation-only lazy baseline using small, typical,
    and high polygon-count fixtures in a physical-device Release build. Record selected-scene time, per-inactive-layer
    warm time, overlay counts, peak and retained memory, hitches, and first layer-switch latency with warnings on/off.
  - Minimal fix strategy: Do not select an optimization yet. If measurement shows material eager cost without a
    meaningful switch benefit, prefer bounded or demand-driven warming while preserving scene identity, warning
    composition, cancellation, and overlay ordering.
  - Required validation: Signpost or benchmark scene materialization by layer and overlay count, capture Time Profiler
    and Allocations during reload and first layer switches, and use the existing deterministic Map suites as the
    behavioral regression gate.
  - Related GitHub issue: Creation attempted on 2026-08-23 as `[Performance Measurement] Map: quantify inactive scene
    warming`; the GitHub connector rejected the write because approval is disabled, so no issue exists.
- Measurement gaps: `PERF-ARCUS-MAP-SCENE-WARMING` is the sole promoted measurement gap for this run.
- Watchlist: `MapAccessibilitySummary.make` still walks rendered overlays when `MapScreenContent` recomputes, but the
  prior duplicate warning-legend derivation is gone and no trace establishes meaningful summary cost. Promote only if
  SwiftUI instrumentation shows repeated summary work on unrelated state changes with material overlay counts.
- Resolved findings: The 2026-06-14 duplicate warning-legend/accessibility derivation mechanism remains resolved:
  warning legend items are materialized once into `MapLayerScene`, and MapKit overlay updates are revision-gated with
  stable key/signature reuse. No new quantitative resolution claim is made.
- Top finding: `PERF-ARCUS-MAP-SCENE-WARMING` (MEASUREMENT REQUIRED, MEDIUM confidence).
- Best next action: Measure eager inactive-scene warming against first layer-switch latency before changing the cache
  or materialization policy.
- Implementation recommended: no
- Measurement recommended: yes
- GitHub issues created: none; measurement issue creation failed because the GitHub connector required approval while
  this automation's approval policy is `never`.
- GitHub issues updated: none
- Existing issues referenced: closed issues #137 and #297 document warning composition and preservation of warming,
  but neither measures or owns the eager-warming performance tradeoff.
- Out-of-scope repositories: arcus-signal; ArcusCore
