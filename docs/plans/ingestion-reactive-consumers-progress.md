# Ingestion Reactive Consumers Progress

## Overview

Tracks accepted-generation invalidation, bounded Home observation, cache retention, detail reconciliation, and final cache-consumer evidence.

**Epic status:** Planned
**Primary GitHub epic:** [#424](https://github.com/justinrooks/project-arcus/issues/424)

## Global Decisions

- Generations trigger rereads; they do not carry domain data.
- Map preserves its current scene until replacement is ready.
- Home query narrowing precedes retention cleanup.
- Details remain immediately cache-seeded and perform no navigation-time networking.
- Outlook issuance switching is out of scope.
- All implementation uses `GPT-5.6 Terra / medium`.

## Current State

Map reloads on scene activation rather than accepted feed changes. Home observes all retained projections and outlooks. Details are fast value-based snapshots but open alert content cannot reconcile accepted revisions.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#452](https://github.com/justinrooks/project-arcus/issues/452) — Invalidate the visible map from accepted generations | Pending | Durable feed generations |
| 2 | [#455](https://github.com/justinrooks/project-arcus/issues/455) — Introduce keyed Home projection observation | Pending | Persistence-gated publication |
| 3 | [#456](https://github.com/justinrooks/project-arcus/issues/456) — Add explicit Home projection retention | Pending | 02 and measurement |
| 4 | [#451](https://github.com/justinrooks/project-arcus/issues/451) — Reconcile open alert detail with accepted revisions | Pending optional | Durable hot generation |
| 5 | [#450](https://github.com/justinrooks/project-arcus/issues/450) — Prove end-to-end cache consumer behavior | Pending | 01–04 shipped scope |

## Existing Code Map

- Map: `Sources/Features/Map/MapScreenView.swift`, `Sources/Features/Map/MapFeatureModel.swift`
- Home cache selection: `Sources/App/HomeView.swift`, `Sources/App/HomeView+PresentationState.swift`
- Projection persistence: `Sources/Repos/HomeProjectionStore.swift`
- Details: Alert and Outlook feature views

## Status Ledger

### [#452](https://github.com/justinrooks/project-arcus/issues/452) — Invalidate the visible map from accepted generations
- Status: Pending

### [#455](https://github.com/justinrooks/project-arcus/issues/455) — Introduce keyed Home projection observation
- Status: Implemented — no SwiftData schema change
- Handoff: Home uses one plain, newest-first `@Query` over all retained projections. Current-location and startup display readiness are selected in memory through `HomeProjectionRecord.newestDisplayReady(in:)`, preserving legacy partial-risk and nil-weather cache behavior while avoiding unsupported custom-type predicates. The actor fallback uses the same sorted descriptor. This read is intentionally unbounded until issue #456 adds explicit retention; retain that dependency when sequencing #456.

### [#456](https://github.com/justinrooks/project-arcus/issues/456) — Add explicit Home projection retention
- Status: Pending

### [#451](https://github.com/justinrooks/project-arcus/issues/451) — Reconcile open alert detail with accepted revisions
- Status: Pending optional

### [#450](https://github.com/justinrooks/project-arcus/issues/450) — Prove end-to-end cache consumer behavior
- Status: Pending validation gate

## Verification Ledger

- [#455](https://github.com/justinrooks/project-arcus/issues/455): focused `HomeViewKeyedProjectionObservationTests` passed (2 tests, 0 failures, 0 skipped) on iPhone 17, iOS 26.5, Debug: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.eYPkL6/unit.xcresult`. The full unit lane passed (1,188 tests, 0 failures, 0 skipped) on the same simulator and configuration: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.tjwVGk/unit.xcresult`. `git diff --check` passes.
