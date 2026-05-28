# SPC Map Ingestion Stability Progress

This is the durable handoff ledger for the SPC map-ingestion stability issue set.

Update this file after each issue is implemented. Keep entries factual: what changed, what was validated, what was deliberately left alone, and what the next session should know.

## Current Status

| Order | Issue | Title | Status | Notes |
|---|---:|---|---|---|
| 0 | [#204](https://github.com/justinrooks/project-arcus/issues/204) | Stabilize SPC map ingestion risk persistence | Planned | Parent tracking issue. |
| 1 | [#205](https://github.com/justinrooks/project-arcus/issues/205) | Add regression coverage for transient map-product clears | In Progress | Regression tests added; expected failures document missing guardrails pending #206-#209 production fixes. |
| 2 | [#206](https://github.com/justinrooks/project-arcus/issues/206) | Introduce staged SPC map-product batch validation | Planned | Build the narrow candidate/validation model. |
| 3 | [#207](https://github.com/justinrooks/project-arcus/issues/207) | Remove permissive SPC GeoJSON date fallbacks | Planned | Malformed dates should reject candidate data, not become `Date()`. |
| 4 | [#208](https://github.com/justinrooks/project-arcus/issues/208) | Commit SPC map products transactionally by validity window | Planned | Accepted batches mutate rows; rejected batches preserve existing state. |
| 5 | [#209](https://github.com/justinrooks/project-arcus/issues/209) | Preserve projections and widgets when map sync is rejected | Planned | Prevent rejected syncs from becoming all-clear app/widget projections. |
| 6 | [#210](https://github.com/justinrooks/project-arcus/issues/210) | Add observability for accepted and rejected SPC batches | Planned | Add low-noise diagnostics without sensitive location data. |

## Global Constraints

- Preserve seamless risk continuity.
- Preserve legitimate all-clear transitions from coherent accepted SPC batches.
- Preserve real threat removal when a coherent newer SPC batch omits that threat.
- Keep widgets downstream of accepted app projection state.
- Keep changes scoped to ingestion, persistence, and narrow projection guardrails.
- Avoid live network dependencies in tests.
- Avoid broad refresh-cadence or UI refactors.
- Do not touch unrelated dirty files.

## Baseline Investigation

Observed production behavior:

- Accurate marginal/hail risk was present after app foreground refresh.
- Widgets later fell back to all-clear around a mid-morning SPC update window.
- Opening the app restored the correct marginal/hail risk.

Likely cause:

- `SpcProvider.syncMapProducts()` refreshes map products independently.
- `StormRiskRepo` and `SevereRiskRepo` replace current/future rows with decoded fetch results.
- Empty decoded feature collections are currently treated as authoritative.
- Active lookup returns `.allClear` when no active rows or containing polygons exist.
- `HomeIngestionExecutor` persists those `.allClear` values and refreshes widgets from them.

Important files:

- `Sources/Providers/SPC/SpcProvider+Syncing.swift`
- `Sources/Repos/StormRiskRepo.swift`
- `Sources/Repos/SevereRiskRepo.swift`
- `Sources/Repos/FireRiskRepo.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- `Sources/App/HomeRefreshV2/HomeSnapshotStore.swift`
- `Sources/Repos/HomeProjectionStore.swift`
- `Sources/App/HomeRefreshV2/WidgetSnapshotRefreshCoordinator.swift`

## Implementation Log

### Issue #205 — Regression Coverage for Transient Map-Product Clears

- Status: In progress (test-only safety net added; production behavior intentionally unchanged).
- Files changed:
  - `Tests/UnitTests/SevereRiskRepoRefreshTornadoRiskTests.swift`
  - `Tests/UnitTests/HomeRefreshPipelineTests.swift`
  - `docs/plans/spc-map-ingestion-stability-progress.md`
- Tests added/updated:
  - Severe repo:
    - `Transient empty feature collection must not clear existing active tornado risk` (expected to fail on current behavior).
    - `Coherent newer tornado all-clear transition is still allowed` (control case, should pass).
  - Storm repo:
    - `Transient empty categorical must not clear an existing active categorical risk` (expected to fail on current behavior).
    - `Coherent newer categorical all-clear transition is still allowed` (control case, should pass).
  - Unified ingestion/projection:
    - `slow-product refresh must not overwrite known-good projection as all-clear when map sync is unavailable` (expected to fail on current behavior; captures projection/widget guardrail gap).
- Behavior intentionally preserved:
  - No production ingestion logic changes.
  - No widget rendering workaround.
  - No cadence or scheduling changes.
  - Legitimate coherent all-clear transitions remain possible (explicit control tests added).
- Validation run:
  - Ran:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/SevereRiskRepoRefreshTornadoRiskTests -only-testing:SkyAwareTests/HomeRefreshPipelineTests`
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/StormRiskRepoRefreshCategoricalRiskTests`
  - Result: fails as expected for deferred-fix regression cases; coherent all-clear control tests pass.
- Expected failing tests due to deferred production fix:
  - `SevereRiskRepoRefreshTornadoRiskTests.transientEmptyCollectionDoesNotClearExistingActiveTornadoRisk()`
  - `StormRiskRepoRefreshCategoricalRiskTests.transientEmptyCategoricalDoesNotClearExistingActiveRisk()`
  - `HomeRefreshPipelineTests.slowProductRefresh_unavailableMapSyncDoesNotOverwriteProjectionWithAllClear()`
  - `.xcresult` evidence:
    - `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.28_12-12-47--0600.xcresult`
    - `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.28_12-14-10--0600.xcresult`
- Handoff notes for #206:
  - Implement staged SPC map-product candidate validation before mutating stored rows.
  - Treat categorical coherence as the acceptance anchor.
  - Wire acceptance/rejection outcome into projection persistence so rejected/unknown slow-product sync cannot advance all-clear projection/widget state.

## Open Design Notes

- Categorical should be the anchor for validating Day 1 map-product batches.
- Empty severe products are not automatically invalid; they can mean a real threat removal.
- Empty/incoherent categorical products should not clear current risk.
- Rejected map-product batches should not advance home projection freshness or widget snapshot freshness.
- Date parsing should fail closed instead of falling back to `Date()`.

## Handoff Notes

- Start with issue 1 tests. Without regression tests, this bug is too easy to “fix” in the wrong layer.
- Expect the smallest durable production fix to require changes in repo/provider ingestion, not widget rendering.
- If a proposed fix lives primarily in `WidgetSnapshotBuilder`, it is probably treating the rash while ignoring the infection.
