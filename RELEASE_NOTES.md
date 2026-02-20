# Release Notes

## Unreleased

## v0.1.0(23)

### Overview
This update adds WeatherKit conditions plus in-app attribution, expands Fire Weather surfacing, and refreshes major screens with a more consistent visual system while tightening refresh and networking behavior.

### Highlights
- Fire Weather risk is now surfaced in both the map experience and the Summary risk snapshot rail.
- Summary now shows current-location weather conditions (temperature + symbol) from WeatherKit.
- Summary now includes WeatherKit attribution with provider/legal-link presentation.
- Active watch results are now filtered by watch validity window, excluding expired and not-yet-effective watches.
- Summary, Alerts, Outlook, Map, Diagnostics, and Settings screens were refreshed with consistent card/row treatments and corner-radius alignment.
- Map layer picker interactions were hardened to prevent intermittent missed taps.
- Fire, Categorical, and Severe overlays continue to use feed-provided stroke/fill styling with tuned alpha and legend parity.

### Reliability & Performance
- SPC map sync now coalesces overlapping refresh requests to avoid repeated map-product reloads.
- SPC/NWS HTTP handling now uses status-aware errors (including 429/503), Retry-After parsing, shared headers, and cancellation-aware retries.
- Foreground refresh now gates duplicate reruns using elapsed-time and movement-distance thresholds.
- WeatherKit refreshes now follow a minimum-interval policy (with force-refresh bypass) to reduce repeated conditions fetches.
- Convective and mesoscale sync cancellations during interactive refresh are treated as expected flow to reduce false error-noise in logs.

### UI / UX
- Fire Weather now has a dedicated Summary rail with localized severity messaging.
- Dark-mode background layering was restored for clearer contrast across tabs.
- Map layer controls now have improved tap hit areas and overlay stacking behavior.
- Severe overlays now render with explicit severity ordering so higher-severity (including significant tie-cases) appears on top consistently.

### Tests / QA
- Added an XCTest plan and expanded unit coverage for map style metadata, sync coalescing/cooldown, and HTTP status mapping.
- Added Watch repository tests that verify active-watch validity-window filtering.
- Added tests for WeatherKit refresh-policy interval behavior and severe polygon ordering for equal-probability significant overlays.

## v0.1.0(18)

### Overview
This update focuses on map rendering correctness and safer background refresh rescheduling behavior.

### Highlights
- Map overlays now stay in sync more reliably, and the map auto-centers only on the first location fix.
- Categorical outlook polygons now render by severity so higher-risk areas appear above lower-risk areas.
- Background refresh scheduling now replaces pending requests only when the newly requested run is materially earlier.
- If a replacement refresh request fails to submit, the prior scheduled refresh request is restored.

### Reliability & Performance
- Map overlay updates now avoid unnecessary remove/add churn while keeping geometry-synced rendering.
- App refresh replacement now uses a timing threshold to avoid frequent schedule churn.

### UI / UX
- The Map tab now uses a dedicated screen/canvas flow for more stable layer rendering behavior.

### Tests / QA
- Added regression coverage for map polygon ordering/filtering and background scheduler replacement-policy decisions.

## v0.1.0(16)

### Overview
This update focuses on startup flow polish, more reliable location state handling, and safer background cadence decisions during active severe-weather conditions.

### Highlights
- Added a dedicated loading overlay on Home and refined `LoadingView` styling.
- Improved location authorization accuracy by updating `authStatus` directly from authorization callbacks.
- Hardened placemark lookups by preventing overlapping geocode behavior and stale completion regressions.
- Throttled convective outlook syncing to reduce redundant refresh work.
- Fixed a cadence bug where active mesos/watches were ignored, which could delay follow-up background refreshes during higher-risk periods.

### Reliability & Performance
- Reordered SPC product sync flow and introduced an outlook refresh throttle.
- Location provider now uses request-scoped geocoders and guards snapshot recency during geocode completion.
- Background cadence now evaluates real active meso/watch presence before scheduling the next run.

### UI / UX
- Home loading surfaces now present a cleaner, more consistent visual state during data bootstrapping.

### Tests / QA
- Added and expanded unit tests for loading overlay behavior, location provider/manager logic, and outlook throttling.
- Added `BackgroundOrchestratorCadenceTests` to verify short cadence under active meso/watch and long cadence for all-clear.

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
