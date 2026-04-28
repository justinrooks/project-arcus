# Changelog

## Unreleased

## v0.1.0(45)

### Background & Notifications
- Improve notification reliability by filtering non-active watch payloads before persistence and tightening watch-notification behavior/language consistency.
<!-- evidence: d217663 -->

### Data & Repos
- Add warning geometry support from alert payload models through persistence/querying so active warning polygons can be rendered on the map.
<!-- evidence: d217663 -->

### UI / UX
- Add warning map overlays with warning-specific styling, map-legend support, and warning layering above thematic overlays.
<!-- evidence: d217663 -->
- Shift map rendering to selected-layer-first materialization with stable overlay identity/revision handling to reduce unnecessary redraw churn.
<!-- evidence: d217663 -->

### Tests / QA
- Expand automated coverage for map rendering, watch repository behavior, payload parsing, location handling, and UI map behavior; update the shared test plan.
<!-- evidence: d217663 -->

### Maintenance / Cleanup
- Disable bundled warning sample data used during map warning development.
<!-- evidence: 3f71515 -->

## v0.1.0(42)

### Background & Notifications
- Route foreground, background, and remote-alert refresh triggers through a shared Home ingestion flow so cached Home data, location-based updates, and alert-driven refreshes stay in sync.
<!-- evidence: d841412, 55af4bd, e4f7a6d, 245c01b, 49a0ca4, e5e8bdb, a30739b, 59b7c71, 54e542e -->
- Refresh local alert data when a remote hot-alert notification is received or opened, and focus the relevant alert after opening the notification.
<!-- evidence: 245c01b, 59b7c71, 54e542e -->

### Data & Repos
- Persist location-scoped Home projections in SwiftData and restore the Home experience from cached local weather, risks, alerts, and outlook data while fresh loads complete.
<!-- evidence: c8461ad, 11d7db5 -->

### UI / UX
- Show an offline token on Home with an explanation popover, and add ingestion diagnostics in Settings with projection context plus lane-by-lane load timestamps.
<!-- evidence: bffc873, 53d0024, e76160b -->
- Let Home summary cards jump directly to relevant map layers, Alerts, and Outlooks, and make the summary header condense into a tighter compact state while you scroll.
<!-- evidence: 48e8525, e76160b -->
- Refresh Alerts and Outlook surfaces with clearer overview cards, better ordering, updated "Weather Alert" wording, broader warning-title styling, and reduce-motion-aware interaction polish across loading, summary, alerts, and map views.
<!-- evidence: 5652410, 48e8525, e76160b, 9718bc6, 21936aa -->

### Tests / QA
- Expand regression coverage for home-ingestion coordination, cached Home projection persistence, remote hot-alert handling, ingestion diagnostics, location refresh edge cases, and Xcode Cloud timing-sensitive pipeline tests.
<!-- evidence: 21936aa, 1b27db0, 2698085, 36c7811, d841412, 11d7db5, 245c01b, 53d0024, a30739b, 59b7c71, 54e542e -->

### Maintenance / Cleanup
- Deprecate local watch-engine plumbing and add FB-010 architecture, runbook, and progress docs for the unified ingestion rollout.
<!-- evidence: 294cdbb, c8461ad, d841412, 11d7db5, 55af4bd, e4f7a6d, 245c01b, 53d0024 -->

## v0.1.0(38)

### UI / UX
- Surface severe-risk tags in supported alert rows, summary rows, and detail screens, including tornado, wind, hail, and flash-flood threat context when the source data provides it.
<!-- evidence: d109e5c -->
- Show fewer items by default in the active alert summary, add a See all / Show less control, and clean up alert icon alignment in the condensed rows.
<!-- evidence: d109e5c, be9cf9d -->
- Refresh the welcome, disclaimer, and permission screens to better explain best-effort severe-weather awareness, official-warning guidance, and derived location data used for notification targeting.
<!-- evidence: 67445d9 -->

### Maintenance / Cleanup
- Update the privacy policy and public project documentation to describe WeatherKit usage plus derived location data used for server-assisted notification targeting.
<!-- evidence: 67445d9, d921c9d -->

## v0.1.0(33)

### Background & Notifications
- Resolve a complete local location context before running onboarding, foreground, and background location-based refreshes or uploads, so local alerts and conditions wait for county/fire-zone metadata instead of raw coordinates alone.
<!-- evidence: 007e00d -->
- Ask for Always Allow after While Using during onboarding so background alerts can stay current.
<!-- evidence: 007e00d -->
- Fetch hot mesos/watch feeds on background location changes and send a one-time local notification when a newly relevant watch appears.
<!-- evidence: 1bb0289 -->

### Data & Repos
- Filter cancelled and non-active Arcus watch payloads before persisting them, so inactive watches do not appear in local results.
<!-- evidence: b9d3c2d -->

### UI / UX
- Update onboarding permission copy to explain the Always Allow follow-up request and that location is used to determine local weather alerts.
<!-- evidence: 007e00d -->
- Show clearer Summary/Home loading states while SkyAware prepares location context, local risks, alerts, and current conditions.
<!-- evidence: 007e00d, 12386d6, 4fb9697 -->
- Label updated watches correctly in the detail view even when Arcus message-type formatting varies.
<!-- evidence: b9d3c2d -->

### Infra / Parsing
- Coalesce duplicate location-scoped Arcus and mesoscale syncs so repeated refreshes join in-flight work instead of refetching the same local feeds.
<!-- evidence: 8f77ca5 -->
- Split foreground/background ingestion into shared hot-feed and slower-feed refresh paths so mesos/watch updates stay current without forcing every SPC feed to re-run on each location change.
<!-- evidence: de3548b, 7a16313, 9b08893, 1bb0289 -->

### Tests / QA
- Add regression coverage for deterministic location-context readiness, Home refresh pipeline behavior, watch cancellation/update handling, and background location-change watch notifications.
<!-- evidence: 8361968, 6cee659, 64c3a6d, 3870865, b9d3c2d, 1bb0289 -->

### Maintenance / Cleanup
- Refactor Home refresh orchestration and watch persistence helpers into shared pipeline/support types, and refresh repository documentation for the new flow.
<!-- evidence: de3548b, 33dbcbd, bbfdeca, c29bb04 -->

## v0.1.0(29)

### Background & Notifications
- Wait for the actual location-permission result and APNs token before sending the first location snapshot during onboarding.
<!-- evidence: e47120d -->
- Reuse recent location snapshots across cold starts, prefer a fresh fix for background runs, and skip stale location-dependent work.
<!-- evidence: 1798c83, e47120d -->
- Include county/fire-zone codes and labels plus subscription status in location snapshot uploads to the server.
<!-- evidence: 0872620 -->

### Data & Repos
- Move active watch loading to the server alert feed and match watches by both UGC zones and H3 cells so alert results follow location changes more reliably.
<!-- evidence: e47120d, b2fbafb -->

### UI / UX
- Add Server Notifications and Send Location to Signal toggles in Settings.
<!-- evidence: 1798c83, 0872620 -->
- Add a Diagnostics cache-clear action and show more of each log entry before truncating lines in Log Viewer.
<!-- evidence: 1798c83, b2fbafb -->
- Show onboarding progress states while waiting for location and notification permission handoffs.
<!-- evidence: e47120d -->

### Infra / Parsing
- Harden SPC/NWS/alert networking with foreground/background request policies, 429/503 retry handling, Retry-After parsing, 304 cache revalidation, and cached GET fallback after retry exhaustion.
<!-- evidence: 1798c83 -->
- Parallelize independent foreground feed syncs and reduce repeated NWS traffic with filtered active-alert queries, refresh-key quantization, and in-flight/cooldown dedupe.
<!-- evidence: 1798c83 -->

### Tests / QA
- Add regression coverage for downloader retry/caching behavior, location snapshot caching, onboarding/APNs token waiting, server-backed watch syncing/filtering, and background cadence freshness rules.
<!-- evidence: 1798c83, 0872620, e47120d, b2fbafb -->

## v0.1.0(25)

### Features
- Add an Atmosphere rail to Summary that surfaces current atmospheric conditions.
<!-- evidence: 3324c60, 691f147 -->
- Add layered severe-risk hatch overlays and matching legend swatches to distinguish significant intensity levels on the map.
<!-- evidence: 761c5c1, 9cc559f, eb5fa50 -->

### Background & Notifications
- Add location snapshot push plumbing with installation and region context, and switch payloads from raw latitude/longitude to H3 cell identifiers.
<!-- evidence: 61332e6, f947263, 3be4303, 6d8e50a -->
- Enable additional notification types and include Fire Weather risk in morning notifications.
<!-- evidence: c972860, e0c00be -->

### Data & Repos
- Fix map product freshness filtering so outdated map data is not treated as current.
<!-- evidence: b57d41c -->
- Fix severe badge threat sorting so the highest tornado risk is selected for badge output.
<!-- evidence: 0b06f02 -->

### UI / UX
- Make Summary components consistent and use placeholder content while loading.
<!-- evidence: 016c8ab -->
- Hide AI settings, fix the Settings location card width bug, and surface installation/device identifiers in Settings for debugging.
<!-- evidence: 535622d, 61332e6 -->
- Normalize text casing across Summary, Outlook, Meso, and diagnostics surfaces.
<!-- evidence: 0ef93db -->
- Refine map layer picker/legend presentation and unify severe hatch legend swatches.
<!-- evidence: e6dbb10, eb5fa50 -->

### Infra / Parsing
- Improve map rendering with keyed overlay diffing and concurrency-safe hatch layering.
<!-- evidence: fce30a6, 6e3da7a -->

### Tests / QA
- Add and stabilize tests for location snapshot push behavior, map freshness filtering, and severe overlay rendering behavior.
<!-- evidence: cecd695, b57d41c, fce30a6, 761c5c1, eb5fa50 -->
- Fix failing unit tests around severe-risk active-selection helpers.
<!-- evidence: 0b406cc -->

### Maintenance / Cleanup
- Add location snapshot push logging for diagnostics.
<!-- evidence: 6772c75 -->
- Clean up Summary header card layout.
<!-- evidence: b90fecd -->

## v0.1.0(22)

### Features
- Add Fire Weather risk support for SPC wind/RH products, including a dedicated Fire map layer and legend coverage.
<!-- evidence: 751d110 -->
- Add a Fire Weather rail to the Summary risk snapshot with localized risk labels and messaging.
<!-- evidence: fd86cd1 -->
- Add WeatherKit-backed current conditions to the Summary header, including temperature and condition symbol for the current location.
<!-- evidence: 4392ead -->
- Add WeatherKit attribution to Summary so provider branding and legal-link attribution are shown in-app.
<!-- evidence: 0be9d92 -->

### Background & Notifications
- Include Fire Weather zones when evaluating local alert inclusion.
<!-- evidence: 751d110 -->
- Reduce duplicate foreground refresh churn by requiring either elapsed time or location-distance thresholds before re-running refresh work.
<!-- evidence: f87b268 -->
- Throttle WeatherKit refreshes to a policy-driven minimum interval (with force-refresh bypass) to reduce repeated current-conditions fetches.
<!-- evidence: 0be9d92 -->

### Data & Repos
- Fix overlapping SPC map sync ownership so concurrent refresh paths join in-flight work instead of triggering repeated map-product loads.
<!-- evidence: 751d110 -->
- Filter active watches by validity window so expired and not-yet-effective watches are excluded from active results.
<!-- evidence: 3f1a46c -->
- Keep severe-risk deduping keyed by threat type + outlook key so different products at the same threat type do not overwrite each other.
<!-- evidence: 0be9d92 -->

### UI / UX
- Apply feed-provided stroke/fill styling to Fire, Categorical, and Severe polygons, with alpha-tuned overlays for map readability and legend parity.
<!-- evidence: 751d110 -->
- Redesign Summary, Alerts, Outlook, Map, Diagnostics, and Settings surfaces with consistent card/row styling and glass-style treatments.
<!-- evidence: 70cda47, b3b2d1c, 771da07, d38bfbd -->
- Fix intermittent map layer picker button taps by improving hit testing and overlay layering.
<!-- evidence: de88978 -->
- Restore dark-mode background layering and improve visual consistency across tabs.
<!-- evidence: f87b268 -->
- Standardize corner radii across cards, chips, and related surfaces.
<!-- evidence: 13ba38a -->
- Render severe polygons in explicit severity order (including SIGN tie-handling) so higher-severity shading stays visually on top; align legend ordering with that model.
<!-- evidence: 0be9d92 -->

### Infra / Parsing
- Standardize SPC/NWS HTTP handling with status-aware errors (including 429/503), Retry-After parsing, shared request headers, and cancellation-aware retries.
<!-- evidence: 751d110 -->
- Treat cancelled convective/meso sync passes as expected control flow and log them at notice level instead of error.
<!-- evidence: 0be9d92 -->

### Tests / QA
- Add an XCTest plan and expand unit coverage for map style metadata propagation, sync coalescing/cooldown behavior, and network client status mapping.
<!-- evidence: 751d110 -->
- Add Watch repository active-state tests to verify validity-window filtering.
<!-- evidence: 3f1a46c -->
- Add unit coverage for WeatherKit refresh-policy interval behavior and severe map polygon ordering when significant and non-significant probabilities tie.
<!-- evidence: 0be9d92 -->

### Maintenance / Cleanup
- Update release documentation and engineering journal entries for this cycle.
<!-- evidence: 751d110, 876c813, 4392ead -->
- Add architecture notes for a server-backed timely notifications strategy.
<!-- evidence: 0be9d92 -->

## v0.1.0(18)

### UI / UX
- Update the Map tab to use a dedicated screen/canvas flow that keeps overlays in sync by geometry and auto-centers only on the first location fix.
<!-- evidence: 35a47a2 -->
- Fix categorical outlook layering so higher-severity risk polygons render above lower-severity polygons.
<!-- evidence: 35a47a2 -->

### Background & Refresh
- Change app refresh scheduling to replace a pending request only when the new run time is materially earlier, and restore the previous request if replacement submission fails.
<!-- evidence: 35a47a2 -->

### Tests / QA
- Add regression tests for map polygon ordering/filtering and for background scheduler replacement-policy thresholds.
<!-- evidence: 35a47a2 -->

## v0.1.0(16)

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
