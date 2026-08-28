# Air Quality Cache-Forward Progress

## Overview

This ledger tracks the ordered work required to persist location-scoped AQI and roll it forward on Today while a
fresh foreground response is pending.

**Epic status:** Planned

**Primary GitHub epic:** [#404](https://github.com/justinrooks/project-arcus/issues/404)

## Global decisions

- Use `GPT-5.6 Terra / medium` for every child issue.
- Complete the existing `HomeProjectionStore` cache-forward path; do not create a second cache.
- Persist primitive AQI fields and reconstruct the ArcusCore response at the record boundary.
- Preserve core-before-enrichment publication and existing `.replace` versus `.preserve` semantics.
- Keep AQI ingestion independent of the `alwaysShowAirQuality` presentation preference.
- Reuse the existing stable AQI metric identity and settle animation; no UI redesign is planned.
- Issue #331 is completed prerequisite behavior. It preserves same-location in-memory AQI but intentionally excludes
  persistence.

## Current state summary

AQI fetches in the optional foreground enrichment stage after the durable Home core is published. The pipeline
preserves an already-held same-location AQI across skipped, empty, failed, and canceled enrichment, and clears it on
location changes. The gap is launch durability: `HomeProjection` has no AQI slice, successful enrichment is not
persisted, and `HomePresentationSnapshot` returns `nil` until the current pipeline resolves. The shared HTTP cache
cannot provide stale-while-revalidate publication.

## Issue sequence

| Order | Issue | Preferred model | Status | Dependency |
| ---: | --- | --- | --- | --- |
| 00 | [#404](https://github.com/justinrooks/project-arcus/issues/404) — Epic | Coordination | Planned | Investigation |
| 01 | [#405](https://github.com/justinrooks/project-arcus/issues/405) — Persist AQI in the Home projection | `GPT-5.6 Terra / medium` | Planned | None |
| 02 | [#406](https://github.com/justinrooks/project-arcus/issues/406) — Persist accepted AQI enrichment | `GPT-5.6 Terra / medium` | Planned | 01 |
| 03 | [#407](https://github.com/justinrooks/project-arcus/issues/407) — Roll cached AQI forward in Today | `GPT-5.6 Terra / medium` | Planned | 02 |

## Existing code map

- Durable projection model/value: `Sources/Models/Home/HomeProjection.swift`
- Projection protocol/store: `Sources/Repos/HomeProjectionStore.swift`
- Optional AQI fetch/publication: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Visible AQI state and location clearing: `Sources/App/HomeRefreshPipeline.swift`
- Cached/live arbitration: `Sources/App/HomeView+PresentationState.swift`
- Home query/input assembly: `Sources/App/HomeView.swift`
- Atmospheric presentation: `Sources/Features/AtmosphericRail/AtmosphereRailView.swift`
- HTTP behavior: `Sources/Infrastructure/Networking/HTTPDataDownloader.swift`
- Focused tests: `Tests/UnitTests/HomeProjectionStoreTests.swift`,
  `Tests/UnitTests/StormSetupIngestionTests.swift`, `Tests/UnitTests/HomeRefreshPipelineTests.swift`,
  `Tests/UnitTests/HomeViewStateTests.swift`, `Tests/UnitTests/AtmosphericConditionsDescriptorTests.swift`

## Investigation notes

- The pipeline plumbing is already correct for same-process preservation and stale publication rejection.
- The durable projection currently contains weather, risks, alerts, mesos, and Storm Setup but no AQI.
- Presentation uses normal cached/live fallback for weather and risks but a special AQI branch that suppresses cache.
- `URLSessionHTTPClient` uses protocol caching and post-failure cache fallback; it does not publish cached then fresh
  values from one request.
- The AQI response provides `observedAt`, which is the correct monotonic replacement key. `loadedAt` remains separate
  persistence provenance.
- The Atmospheric Conditions rail already uses `.aqi` stable identity and reduce-motion-aware settle animation.

## Status ledger

### Issue #405 — 01: Persist AQI in the Home projection

- **Status:** Ready for commit
- **Goal:** Add a durable, reconstructable, monotonic AQI slice to each location-scoped Home projection.
- **Expected production files:** `HomeProjection.swift`, `HomeProjectionStore.swift`.
- **Required proof:** nil defaults; complete response reconstruction; independent locations; older-observation
  rejection; preservation of every other slice; current-schema disk reopen; immediate-pre-AQI schema migration.
- **Completed:** Added optional primitive AQI fields and `lastAirQualityLoadAt`, record-boundary reconstruction, and
  `updateAirQuality(_:for:loadedAt:)`. Equal/newer observations replace the cache; older observations return the
  cached record without changing AQI or timestamps. No ingestion or presentation path changed.
- **Focused proof:** `HomeProjectionStoreTests` passed 36/36 on iPhone 17, iOS 26.5, Debug. Finalized result bundle:
  `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.zDj9Nz/unit.xcresult`.
- **Build:** Debug simulator build passed.
- **Migration proof:** Replaced the live legacy `@Model` test setup with a frozen immediate-pre-AQI SQLite fixture.
  The test copies its clean SQLite artifact into an isolated temporary store, then opens it with the current schema and
  verifies AQI defaults to nil. It does not claim migration coverage from the latest tagged production release.
- **Release boundary:** This feature establishes the durable schema for the next release. Migration from `v1.1.0(113)`
  is intentionally out of scope because no prior version shipped these AQI fields; subsequent schema changes must
  preserve and test this released shape.
- **Full unit lane:** passed 1,038/1,038 on iPhone 17, iOS 26.5, Debug. Finalized result bundle:
  `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.87e5lR/unit.xcresult`.
- **Next dependency:** #406 is unblocked after human review and publication of #405.

### Issue #406 — 02: Persist accepted AQI enrichment

- **Status:** Ready for commit
- **Goal:** Write successful foreground AQI enrichment through the projection store and publish the accepted value.
- **Expected production files:** `HomeIngestionExecutor.swift`; protocol test conformers only as required by issue 01.
- **Required proof:** success persists; older candidates publish the accepted cache; nil/failure/cancellation/hot-only
  preserve without a write; persistence failure still publishes the live response; core publication remains first.
- **Completed:** Successful foreground AQI responses now call `updateAirQuality(_:for:loadedAt:)` and publish the
  response returned by durable storage. Rejected older observations therefore publish the newer stored response.
  Persistence errors are logged as degraded durability and retain the valid live response. Unavailable, nil,
  cancelled, background, and hot-only paths continue to publish `.preserve` without an AQI write.
- **Focused proof:** `StormSetupIngestionTests` passed 46/46 on iPhone 17, iOS 26.5, Debug. Finalized result bundle:
  `/private/tmp/issue406-focused-rereview.xcresult`.
- **Build:** Debug simulator build passed.
- **Full unit lane:** passed 1,040/1,040 on iPhone 17, iOS 26.5, Debug. Finalized result bundle:
  `/private/tmp/issue406-full-rereview.xcresult`.
- **Stop condition:** Ingestion tests prove persistence and publication semantics without changing presentation.

### Issue #407 — 03: Roll cached AQI forward in Today

- **Status:** Planned
- **Goal:** Use the selected projection AQI until matching pipeline AQI becomes available.
- **Expected production files:** `HomeView+PresentationState.swift`; `HomeView.swift` only if the pure selector needs an
  additional copied input.
- **Required proof:** startup cache; cache during delayed enrichment; fresh replacement; same-location preserve;
  location switch isolation; existing preference threshold behavior; no missing-value flash in manual validation.
- **Stop condition:** Presentation tests, full unit lane, Debug build, navigation smoke, and warm-launch check pass.

## Verification ledger

| Issue | Focused tests | Build | Full unit lane | UI/manual evidence | Result bundle |
| --- | --- | --- | --- | --- | --- |
| 01 | 36/36 passed | Debug build passed | 1,038/1,038 passed | Not required | `unit.xcresult` (`zDj9Nz`, `87e5lR`) |
| 02 | Pending | Pending | Required | Not required | Pending |
| 03 | Pending | Pending | Required | Navigation smoke and warm-launch/location-switch checks | Pending |

## Handoff notes

- Update only the active issue section with changed files, behavior, exact executed/passed/failed/skipped counts,
  `.xcresult` path, residual risk, and next dependency.
- Do not mark an issue complete from `** TEST SUCCEEDED **` or command exit status alone.
- Stop after each issue for human review. Do not roll directly into the next slice.
