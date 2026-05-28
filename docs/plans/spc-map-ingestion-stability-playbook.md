# SPC Map Ingestion Stability Playbook

Use this playbook when implementing the SPC map-ingestion stability issue set.

The work fixes a production-class correctness bug: transient SPC Day 1 GeoJSON publication states can be interpreted as authoritative all-clear risk and then persisted into the app and widgets. The goal is seamless risk continuity. SkyAware should keep the last coherent active risk profile until a validated newer SPC map-product batch replaces it.

## Issue Set

| Order | Issue | Title | Dependency |
|---|---:|---|---|
| 0 | [#204](https://github.com/justinrooks/project-arcus/issues/204) | [Epic] Stabilize SPC map ingestion risk persistence | Parent tracking issue |
| 1 | [#205](https://github.com/justinrooks/project-arcus/issues/205) | [SPC Stability] Add regression coverage for transient map-product clears | None |
| 2 | [#206](https://github.com/justinrooks/project-arcus/issues/206) | [SPC Stability] Introduce staged SPC map-product batch validation | After #205 |
| 3 | [#207](https://github.com/justinrooks/project-arcus/issues/207) | [SPC Stability] Remove permissive SPC GeoJSON date fallbacks | After #206 |
| 4 | [#208](https://github.com/justinrooks/project-arcus/issues/208) | [SPC Stability] Commit SPC map products transactionally by validity window | After #206 and #207 |
| 5 | [#209](https://github.com/justinrooks/project-arcus/issues/209) | [SPC Stability] Preserve projections and widgets when map sync is rejected | After #208 |
| 6 | [#210](https://github.com/justinrooks/project-arcus/issues/210) | [SPC Stability] Add observability for accepted and rejected SPC batches | After #209 |

## Required Read Order

Before touching code for any issue, read:

1. `AGENTS.md`
2. `Sources/AGENTS.md`
3. `tasks/lessons.md`
4. The current GitHub issue body
5. `docs/plans/spc-map-ingestion-stability-progress.md`
6. This playbook
7. The files listed in the issue scope

For implementation work touching Swift concurrency, SwiftData actors, or ingestion orchestration, also use the Swift concurrency guidance already available in this repo/workspace.

## Problem Summary

Observed behavior:

- The app initially displayed accurate marginal and hail risk.
- After a mid-morning convective/SPC update window, widgets fell back to all-clear.
- Opening the app refreshed data and restored the correct marginal and hail state.

Likely cause:

- Background slow-product sync fetched a transient SPC GeoJSON state during publication.
- Repos replaced current/future rows with whatever decoded successfully.
- Empty or incoherent geometry became no active rows.
- Point risk lookup returned `.allClear`.
- Projection and widget snapshot persistence treated `.allClear` as valid data.

## Current Implementation Map

SPC map fetch and sync:

- `Sources/Clients/SpcClient.swift`
- `Sources/Providers/SPC/SpcProvider.swift`
- `Sources/Providers/SPC/SpcProvider+Syncing.swift`

Risk persistence and query:

- `Sources/Repos/StormRiskRepo.swift`
- `Sources/Repos/SevereRiskRepo.swift`
- `Sources/Repos/FireRiskRepo.swift`
- `Sources/Providers/SPC/SpcProvider+SpcRiskQuerying.swift`
- `Sources/Providers/SPC/SpcProvider+SpcMapData.swift`

GeoJSON parsing and models:

- `Sources/Infrastructure/Parsing/GeoJSON/GeoJSONModels.swift`
- `Sources/Utilities/Extensions/ext+String.swift`
- `Sources/Models/Categorical/StormRisk.swift`
- `Sources/Models/Severe/SevereRisk.swift`
- `Sources/Models/Fire/FireRisk.swift`

Home/background/widget projection:

- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- `Sources/App/HomeRefreshV2/HomeSnapshotStore.swift`
- `Sources/Repos/HomeProjectionStore.swift`
- `Sources/App/HomeRefreshV2/WidgetSnapshotRefreshCoordinator.swift`
- `Sources/App/HomeRefreshV2/WidgetSnapshotBuilder.swift`
- `Shared/WidgetSnapshotStore.swift`
- `WidgetsExtension/SkyAwareWidgetsBundle.swift`

Background orchestration:

- `Sources/Features/Background/BackgroundOrchestrator.swift`
- `Sources/App/SkyAwareApp.swift`
- `Sources/Infrastructure/Scheduling/BackgroundScheduler.swift`

Relevant tests:

- `Tests/UnitTests/SevereRiskRepoRefreshTornadoRiskTests.swift`
- `Tests/UnitTests/SevereRiskRepoActiveSelectionTests.swift`
- `Tests/UnitTests/HomeProjectionStoreTests.swift`
- `Tests/UnitTests/HomeRefreshPipelineTests.swift`
- `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`
- `Tests/UnitTests/WidgetSnapshotRefreshCoordinatorTests.swift`

## Non-Negotiables

- Do not fix this in widgets. Widgets should reflect the accepted app projection.
- Do not hide real all-clear states.
- Do not preserve stale hail/wind/tornado forever when a coherent newer SPC batch legitimately removes that threat.
- Do not treat an empty severe layer as invalid by itself. Empty severe layers can be real.
- Do not treat an empty, malformed, or future-only categorical map-product batch as authoritative.
- Do not delete current/future rows before the incoming batch is validated.
- Do not introduce live network dependencies in tests.
- Do not bypass SwiftData actor boundaries.
- Do not broaden the work into unrelated refresh cadence, UI polish, or notification changes.

## Target Design

The SPC map-product path should become staged and stale-safe:

1. Fetch and decode the Day 1 map products into an in-memory candidate batch.
2. Validate candidate metadata before persistence.
3. Use categorical as the batch anchor because severe hazards depend on an elevated categorical outlook.
4. Require coherent `ISSUE`, `VALID`, and `EXPIRE` dates.
5. Reject batches that are empty, malformed, expired, or future-only for the current active projection window.
6. Commit accepted products by issuance/validity window.
7. Clear a threat only when a coherent accepted batch proves that threat is absent for the accepted window.
8. Preserve existing active rows, projections, and widget snapshots when a candidate batch is rejected.

## Sequential Implementation Plan

### Issue 1 - Regression Coverage

Add failing tests that prove the bug:

- transient empty categorical does not clear an active categorical risk
- transient empty or malformed severe product does not clear a known-good active severe risk unless the batch is coherent
- unified/background ingestion must not write all-clear widgets from rejected map sync

This issue may introduce test doubles or helpers, but should avoid production behavior changes unless needed for testability and explicitly scoped.

### Issue 2 - Batch Validation Model

Introduce a small internal representation for staged SPC map products and their parsed metadata.

Expected shape:

- decoded product features
- product type
- parsed issue/valid/expire window
- validation status/reason

Keep it boring. This is a guardrail, not a framework audition.

### Issue 3 - Strict Date Parsing

Remove `Date()` fallbacks for SPC GeoJSON map-product `ISSUE`, `VALID`, and `EXPIRE`.

Malformed dates should reject the candidate product or batch without mutation. They should not create rows with accidental current timestamps.

### Issue 4 - Transactional Commit

Change map-product persistence so accepted batches are committed after validation and rejected batches leave existing rows untouched.

The commit should operate by accepted issuance/validity window, not by deleting all current/future rows first.

### Issue 5 - Projection and Widget Preservation

Ensure `HomeIngestionExecutor` does not persist all-clear slow-product projections or write widget snapshots when the slow-product map sync was rejected or unavailable.

The UI/widget contract should remain:

- accepted coherent all-clear updates are written
- rejected/unknown map sync keeps the last accepted projection

### Issue 6 - Observability

Add focused logging/diagnostic breadcrumbs for accepted/rejected SPC map batches:

- product
- issue/valid/expire window
- feature counts
- rejection reason
- whether persistence was skipped or committed

Do not log sensitive location data.

## Validation Expectations

For each issue:

- Run the focused unit tests that cover the changed seam.
- Build the app target if production Swift changes.
- Inspect `.xcresult` on test failure.
- Update `docs/plans/spc-map-ingestion-stability-progress.md`.

Preferred baseline command:

```sh
xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build
```

Use focused `-only-testing:` filters for issue-specific tests.

## Progress Handoff Requirement

Before finishing any issue, update:

- `docs/plans/spc-map-ingestion-stability-progress.md`

Record:

- issue status
- files changed
- behavior intentionally preserved
- validation run
- any rejected approaches
- risk notes for the next issue

The next Codex 5.3 run should be able to resume from the issue body plus these docs without reverse-engineering the whole chain again.
