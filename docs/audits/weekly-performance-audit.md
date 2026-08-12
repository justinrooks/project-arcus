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
