# Changelog

## Unreleased

### Background & Refresh
- Reorder SPC product syncing and add throttling for convective outlook refreshes to reduce redundant update churn.
<!-- evidence: 5f1326f -->
- Fix background cadence evaluation to use live active meso/watch state (instead of hardcoded false flags), so hazardous conditions correctly tighten refresh interval.

### Location & Authorization
- Update location `authStatus` directly from authorization callbacks so permission state stays accurate.
<!-- evidence: 2be882f -->
- Improve placemark resolution reliability with request-scoped geocoders, coordinate-consistent snapshots, and stale-result protection.
<!-- evidence: b54881e -->

### UI / UX
- Add a Home loading overlay and restyle `LoadingView` to better match the app visual language.
<!-- evidence: 0b7de41, 742e6cb -->

### Tests / QA
- Add unit coverage for loading overlay state, location provider/manager behavior, and convective outlook throttling.
<!-- evidence: 0b7de41, e9c8d10, 5f1326f -->
- Add `BackgroundOrchestratorCadenceTests` to lock cadence behavior for active meso/watch vs all-clear scenarios.

### Maintenance / Cleanup
- Update repository agent instructions.
<!-- evidence: 61e3933 -->

## v0.1.0(10)

### Background & Notifications
- Use watch end time when determining active watch notifications.
<!-- evidence: 26cf27d -->

### Data & Repos
- Use VTEC event keys as stable watch IDs (falling back to message IDs when unavailable).
<!-- evidence: 4e447b2 -->

### UI / UX
- Fix watch icon styling for tornado vs severe thunderstorm watches across alert surfaces.
<!-- evidence: 61703e5 -->
- Show watch end times in watch details and summary rows, with "Ends in" copy for time remaining.
<!-- evidence: 61703e5 -->
- Watch alert links now open the correct NWS alert page; footer label reads "Open in browser."
<!-- evidence: 1129370 -->

### Tests / QA
- Update watch notification and purge tests for watch end-time handling and message ID support.
<!-- evidence: 26cf27d, 1129370 -->

### Maintenance / Cleanup
- Add CI/TestFlight notes automation assets and fix CI post-build script permissions.
<!-- evidence: 12bfca3, a1380bd -->
- Add and update pull request templates.
<!-- evidence: a93a766, 707dea4 -->

## v0.1.0(3)

### Features
- Background scheduling and notification pipeline for morning summaries, meso alerts, and watches.
- Watch domain model, repo, DTO wiring, and watch detail UI.
- Mesoscale discussion flow including detail cards, active alerts, and map integration.
- Convective outlook domain + views, including detail screens and summary integration.
- Onboarding flow with permissions handling and settings integration.
- Diagnostics views and background health tracking.

### Background & Notifications
- Full background orchestration for refresh, cadence, gating, and notification sending.
- Notification rule/gate/composer/engine architecture with interfaces and providers.
- Background watch refresh support and settings-driven toggles.

### Data & Repos
- Repos for SPC and NWS data, including SwiftData persistence for outlooks/mesos/watches.
- NWS provider and parsing infrastructure (watch/gridpoint/geojson).
- Location pipeline with throttling, caching, and background updates.

### UI / UX
- Summary view redesign and componentization; improved badges and freshness display.
- Map enhancements: legends, layer selector, polygon styling, and centering improvements.
- Shared SPC header/footer components and consistent card styling.
- Color system refresh for risk and alert visuals.

### Infra / Parsing
- SPC RSS parsing and regex parsing updates for outlooks, mesos, and watches.
- HTTP downloader refactors, caching, and error consolidation.
- Interface segregation for SPC provider operations and cleanup routines.

### Tests / QA
- Unit tests for outlook parsing, watch parsing, watch repo purge, and notification rules.
- Mocks for providers to support previews and testability.

### Maintenance / Cleanup
- Large-scale file reorganization, protocol renaming, and refactors across features.
- Removal of unused files, state files, and CocoaPods.
- Updated docs, notes, and agent instructions.
