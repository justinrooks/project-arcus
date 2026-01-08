# Release Notes

## v0.1.0

### Overview
This release establishes the core SkyAware experience: background refresh, alerting, and a full data flow for convective outlooks, mesoscale discussions, and watches. The UI has been reorganized into feature‑based modules with improved summaries, map tooling, and shared components. The infrastructure now includes SwiftData persistence, a refined location pipeline, and extensible notification rules for background tasks.

### Highlights
- End‑to‑end background orchestration for cadence, gating, and notifications.
- Watch, Meso, and Outlook domains wired through repos, providers, and views.
- Map UI enhancements (legend, selector, polygon rendering, centering).
- Reworked summary surfaces with badges and freshness status.
- Testing coverage for key parsing and notification logic.

### Features
- Onboarding flow with permissions guidance.
- Settings for notification toggles and diagnostics entry points.
- Watch detail UI and active alert presentation.
- Mesoscale discussion cards and active alert summary surfacing.
- Convective outlook list/detail view consolidation and summary integration.

### Background & Notifications
- Notification engine architecture (rule → gate → composer → sender).
- Background scheduler and orchestration for periodic refresh.
- Watch notification pipeline aligned with meso and morning behaviors.

### Data & Repos
- SwiftData persistence for outlooks, mesos, and watches.
- NWS provider pipeline (watch/gridpoint/geojson) with parsing utilities.
- SPC provider pipeline and RSS parsing enhancements.

### UI / UX
- Shared SPC product header/footer components.
- Consistent card and list styling across alerts and outlooks.
- Improved map layers and legend presentation.

### Tests / QA
- Unit tests for watch parsing and purge behavior.
- Tests for outlook parsing and repository refresh.
- Notification tests for watch, morning, and meso pipelines.

### Maintenance
- File reorganization into feature‑oriented modules.
- Cleanup of unused code paths and state files.
- Documentation updates and internal tooling notes.
