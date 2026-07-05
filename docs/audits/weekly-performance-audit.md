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
