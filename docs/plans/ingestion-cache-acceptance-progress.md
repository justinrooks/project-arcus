# Ingestion Cache Acceptance Progress

## Overview

Tracks truthful provider acceptance and persistence-gated Home/AQI publication.

**Epic status:** Planned
**Primary GitHub epic:** [#425](https://github.com/justinrooks/project-arcus/issues/425)

## Global Decisions

- Preserve `HomeIngestionCoordinator`; repair contracts downstream.
- Hot replacement is coherent across location-scoped Arcus and meso operations.
- Map and outlook keep independent admission state.
- Projection persistence acknowledgement gates projection-backed UI replacement.
- No SwiftData schema change or cross-model-actor transaction.
- All implementation uses `GPT-5.6 Terra / medium`.

## Current State

Arcus, meso, and outlook sync methods can swallow errors. The executor can advance hot or slow freshness from incomplete evidence. Projection-save failure and AQI persistence failure can still allow candidate live state to reach presentation. SPC RSS parsing also accepts incomplete documents and can manufacture current-looking outlook dates.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#428](https://github.com/justinrooks/project-arcus/issues/428) — Reject malformed SPC text feeds | Pending | None |
| 2 | [#429](https://github.com/justinrooks/project-arcus/issues/429) — Add typed Arcus and meso sync outcomes | Pending | 01 |
| 3 | [#430](https://github.com/justinrooks/project-arcus/issues/430) — Require coherent hot-feed acceptance | Pending | 02 |
| 4 | [#433](https://github.com/justinrooks/project-arcus/issues/433) — Add typed outlook outcome and in-flight joining | Pending | 01 |
| 5 | [#434](https://github.com/justinrooks/project-arcus/issues/434) — Separate map and outlook refresh clocks | Pending | 04 |
| 6 | [#427](https://github.com/justinrooks/project-arcus/issues/427) — Make manual outlook refresh honor its outcome | Pending | 04 |
| 7 | [#435](https://github.com/justinrooks/project-arcus/issues/435) — Return explicit projection commit acknowledgement | Pending | 03, 05 |
| 8 | [#432](https://github.com/justinrooks/project-arcus/issues/432) — Gate core UI replacement on projection acknowledgement | Pending | 07 |
| 9 | [#431](https://github.com/justinrooks/project-arcus/issues/431) — Remove AQI live-only publication fallback | Pending | 08 |

## Existing Code Map

- Provider outcomes: `Sources/Providers/ArcusAlertProvider.swift`, `Sources/Providers/SPC/SpcProvider+Syncing.swift`
- Text persistence: `Sources/Repos/MesoRepo.swift`, `Sources/Repos/ConvectiveOutlookRepo.swift`
- Execution/publication: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`, `Sources/App/HomeRefreshPipeline.swift`
- Durable projection: `Sources/Repos/HomeProjectionStore.swift`

## Status Ledger

### [#428](https://github.com/justinrooks/project-arcus/issues/428) — Reject malformed SPC text feeds
- Status: Pending
- Handoff: Preserve valid empty meso behavior and prior accepted rows.

### [#429](https://github.com/justinrooks/project-arcus/issues/429) — Add typed Arcus and meso sync outcomes
- Status: Pending
- Handoff: Distinguish targeted from complete location-scoped Arcus refresh.

### [#430](https://github.com/justinrooks/project-arcus/issues/430) — Require coherent hot-feed acceptance
- Status: Pending
- Handoff: Partial canonical success must not relabel the projected hot slice.

### [#433](https://github.com/justinrooks/project-arcus/issues/433) — Add typed outlook outcome and in-flight joining
- Status: Pending

### [#434](https://github.com/justinrooks/project-arcus/issues/434) — Separate map and outlook refresh clocks
- Status: Pending

### [#427](https://github.com/justinrooks/project-arcus/issues/427) — Make manual outlook refresh honor its outcome
- Status: Pending

### [#435](https://github.com/justinrooks/project-arcus/issues/435) — Return explicit projection commit acknowledgement
- Status: Pending

### [#432](https://github.com/justinrooks/project-arcus/issues/432) — Gate core UI replacement on projection acknowledgement
- Status: Pending
- Handoff: Background evaluation may retain useful canonical data.

### [#431](https://github.com/justinrooks/project-arcus/issues/431) — Remove AQI live-only publication fallback
- Status: Pending
- Handoff: Issue #331 already owns same-location in-memory preservation history.

## Verification Ledger

No implementation validation yet. Planning verification is recorded after GitHub creation and placeholder replacement.

