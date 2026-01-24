# Release Notes

## Unreleased

## v0.1.0(10)

### Overview
This release focuses on watch accuracy and presentation, including how watch time windows are shown and which NWS alert page opens from a watch link.

### Highlights
- Watch notifications now use the watch end time when determining active alerts.
- Watch details and summary rows now display end times with "Ends in" messaging.
- Watch links now open the correct NWS alert page.
- Watch icons are corrected for tornado vs severe thunderstorm watches.

### Background & Notifications
- Watch notification rules now use watch end time to decide active status.

### Data & Repos
- Watch records now use stable VTEC event keys for identity, with message IDs as a fallback.

### UI / UX
- Corrected watch icons and timing labels across alert and summary views.
- Watch detail and summary rows now show end times consistently.
- Watch links now open in the browser with the correct NWS alert page.

### Maintenance
- CI/TestFlight notes automation and script permission fixes.
- Pull request templates added/updated.

## v0.1.0(3)

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
