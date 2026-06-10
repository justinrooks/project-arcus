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
