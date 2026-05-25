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
- best next fix: replace the `nil -> context` reset pattern with single guarded assignment keyed by refresh identity to avoid duplicate invalidations and downstream refresh triggers.
- implementation recommended: yes
- implementation status: completed on 2026-05-25
- implementation notes:
  - Replaced `nil -> context` reset pattern with `applyResolvedContext(_:)` in `LocationSession`.
  - Added refresh-key guard to skip `currentContext` reassignment when location scope identity is unchanged.
