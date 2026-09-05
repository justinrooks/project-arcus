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
- Status: Implemented — awaiting human review
- Handoff: Missing RSS channels and malformed recognized SPC text products now reject without replacing accepted rows; valid empty meso remains accepted and outlook dates stay nil when absent.

### [#429](https://github.com/justinrooks/project-arcus/issues/429) — Add typed Arcus and meso sync outcomes
- Status: Implemented — awaiting human review
- Handoff: Location-scoped Arcus, targeted Arcus, and meso syncs now return distinct typed outcomes for acceptance, fallback, rejection, failure, and cancellation while preserving in-flight joining.

### [#430](https://github.com/justinrooks/project-arcus/issues/430) — Require coherent hot-feed acceptance
- Status: Implemented — awaiting human review
- Handoff: Projected hot alerts and freshness now advance only after both location-scoped Arcus and meso syncs accept; targeted remote sync does not replace the coherent slice.

### [#433](https://github.com/justinrooks/project-arcus/issues/433) — Add typed outlook outcome and in-flight joining
- Status: Implemented — awaiting human review
- Handoff: Outlook sync now returns typed accepted, fallback, rejected, failed, or cancelled outcomes; concurrent callers join one run, cancellation prevents persistence/publication only before commit reservation, and a queued fresh caller retains its own HTTP execution mode.

### [#434](https://github.com/justinrooks/project-arcus/issues/434) — Separate map and outlook refresh clocks
- Status: Implemented — awaiting human review
- Handoff: Map and outlook admission now maintain independent accepted-sync clocks. A failed feed remains due while a fresh sibling is skipped; forced slow refresh still attempts both under the shared slow lane.

### [#427](https://github.com/justinrooks/project-arcus/issues/427) — Make manual outlook refresh honor its outcome
- Status: Implemented — awaiting human review
- Handoff: Manual outlook refresh now queries and reports success only after an accepted sync; fallback, rejection, failure, and cancellation retain the visible accepted cache and report failure without triggering unrelated work.

### [#435](https://github.com/justinrooks/project-arcus/issues/435) — Return explicit projection commit acknowledgement
- Status: Implemented — awaiting human review
- Handoff: Core projection commits now acknowledge the exact saved record and derived risk change. The executor consumes that acknowledgement for widget publication while projection failures remain isolated from canonical ingestion state.

### [#432](https://github.com/justinrooks/project-arcus/issues/432) — Gate core UI replacement on projection acknowledgement
- Status: Implemented — awaiting human review
- Handoff: Core publication now uses the acknowledged projection. On a failed core commit it retains the prior durable slice, or suppresses UI replacement when no durable slice exists; canonical evaluation remains available and the next successful run repairs publication.

### [#431](https://github.com/justinrooks/project-arcus/issues/431) — Remove AQI live-only publication fallback
- Status: Implemented — awaiting human review
- Handoff: AQI persistence unavailability, a rejected persisted response, and persistence failures now preserve the prior projected AQI instead of publishing a live-only response. Issue #331 retains same-location in-memory preservation ownership.

## Verification Ledger

- #431: `StormSetupIngestionTests` passed (47 tests) on iPhone 17, iOS 26.5, Debug; Debug simulator build and `git diff --check` passed.
- #428: `ConvectiveOutlookRepoTests` disk-backed acceptance coverage passed (13 tests); Debug iPhone 17 simulator build passed; `git diff --check` passed.
- #433: `SpcProviderSyncMapProductsTests` validates outcome mapping, joining, cancellation, cancellation-safe persistence, and fresh-caller HTTP execution mode; full `SkyAware_Tests` passed (1,071 tests) before the final review corrections.
- #429: Focused `AlertRepoActiveTests` and `SpcProviderSyncMapProductsTests` passed (36 tests); full unit lane passed (1,062 tests); Debug iPhone 17 simulator build and `git diff --check` passed.
