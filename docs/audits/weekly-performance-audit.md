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
