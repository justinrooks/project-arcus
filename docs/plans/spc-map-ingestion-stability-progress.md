# SPC Map Ingestion Stability Progress

This is the durable handoff ledger for the SPC map-ingestion stability issue set.

Update this file after each issue is implemented. Keep entries factual: what changed, what was validated, what was deliberately left alone, and what the next session should know.

## Current Status

| Order | Issue | Title | Status | Notes |
|---|---:|---|---|---|
| 0 | [#204](https://github.com/justinrooks/project-arcus/issues/204) | Stabilize SPC map ingestion risk persistence | Planned | Parent tracking issue. |
| 1 | [#205](https://github.com/justinrooks/project-arcus/issues/205) | Add regression coverage for transient map-product clears | In Progress | Regression tests added; expected failures document missing guardrails pending #206-#209 production fixes. |
| 2 | [#206](https://github.com/justinrooks/project-arcus/issues/206) | Introduce staged SPC map-product batch validation | In Progress | Staged candidate model and categorical-anchored validation wired in provider sync; transactional commit still deferred to #208. |
| 3 | [#207](https://github.com/justinrooks/project-arcus/issues/207) | Remove permissive SPC GeoJSON date fallbacks | In Progress | GeoJSON repo mapping now fails closed on malformed `ISSUE`/`VALID`/`EXPIRE`; transactional preservation still deferred to #208. |
| 4 | [#208](https://github.com/justinrooks/project-arcus/issues/208) | Commit SPC map products transactionally by validity window | In Progress | Provider now commits accepted map batches by accepted anchor window and preserves rows on rejected candidates. |
| 5 | [#209](https://github.com/justinrooks/project-arcus/issues/209) | Preserve projections and widgets when map sync is rejected | In Progress | Ingestion now gates slow-product projection/widget writes on explicit map sync acceptance outcome. |
| 6 | [#210](https://github.com/justinrooks/project-arcus/issues/210) | Add observability for accepted and rejected SPC batches | In Progress | Batch-level and product-level SPC map-sync decision logs added with projection/widget preservation outcomes and privacy-safe fields. |

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

### Issue #206 — Staged SPC Map-Product Batch Validation

- Status: In progress (staged validation plumbing added; transactional persistence rewrite intentionally deferred to #208).
- Files changed:
  - `Sources/Providers/SPC/SpcProvider+Syncing.swift`
  - `Sources/Infrastructure/Parsing/GeoJSON/GeoJSONModels.swift`
  - `Tests/UnitTests/SevereRiskRepoRefreshTornadoRiskTests.swift`
  - `docs/plans/spc-map-ingestion-stability-progress.md`
- Validation model added:
  - Internal staged candidate representation per map product with:
    - product type
    - decoded `GeoJSONFeatureCollection`
    - feature count
    - parsed `ISSUE`, `VALID`, `EXPIRE`
    - per-product validation status/rejection reason
  - Batch-level staged validation with categorical as anchor.
- Validation rules implemented:
  - Empty categorical is rejected (`categorical_empty`).
  - Missing/malformed categorical metadata is rejected (`categorical_metadata_invalid`).
  - Expired categorical is rejected (`categorical_expired`).
  - Future-only categorical is rejected (`categorical_future_only`).
  - Empty severe products are allowed when categorical anchor is coherent.
  - No repo mutation runs unless batch validation is accepted.
- Behavior intentionally preserved:
  - No refresh cadence changes.
  - No widget/projection workaround in this issue.
  - No transactional row-window rewrite here; current repo replacement behavior remains for accepted batches.
- Validation run:
  - Ran focused tests:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests`
  - Observed failure details from result bundle:
    - `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.28_12-20-18--0600.xcresult`
    - Failures were fixture/cooldown expectation mismatches and were patched.
  - Re-run currently blocked by long-running/incomplete `xcodebuild` result-bundle finalization in this environment; latest bundle path observed:
    - `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.28_12-23-53--0600.xcresult`
- Handoff notes for #207:
  - Replace fallback date usage in map-product-to-model conversion with strict parsing/rejection so malformed metadata cannot flow into persisted rows.
- Handoff notes for #208:
  - Move accepted-batch persistence from repo-local "delete current/future by type" to issuance/validity-window transactional commit semantics.

### Issue #207 — Remove Permissive SPC GeoJSON Date Fallbacks

- Status: In progress (strict map-product date parsing implemented; transactional windowed commit remains deferred to #208).
- Files changed:
  - `Sources/Repos/StormRiskRepo.swift`
  - `Sources/Repos/SevereRiskRepo.swift`
  - `Sources/Repos/FireRiskRepo.swift`
  - `Tests/UnitTests/SevereRiskRepoRefreshTornadoRiskTests.swift`
  - `docs/plans/spc-map-ingestion-stability-progress.md`
- Date fallback paths removed:
  - Removed all `props.ISSUE.asUTCDate() ?? Date()` / `props.VALID.asUTCDate() ?? Date()` / `props.EXPIRE.asUTCDate() ?? Date()` usage from SPC GeoJSON risk model construction.
  - `StormRiskRepo.refreshStormRisk`: now throws `SpcError.parsingError` if any feature has malformed `ISSUE`/`VALID`/`EXPIRE` before persistence mutation.
  - `SevereRiskRepo.refresh*Risk`: `makeSevereRisk` now throws on malformed dates; callers map with `try` so mutation is skipped on failure.
  - `FireRiskRepo.refreshFireRisk`: now throws `SpcError.parsingError` if any feature has malformed `ISSUE`/`VALID`/`EXPIRE` before persistence mutation.
- Tests added/updated:
  - `SevereRiskRepoRefreshTornadoRiskTests.malformedTornadoDatesFailClosed` now verifies malformed severe metadata throws and preserves existing persisted rows/dates.
  - `StormRiskRepoRefreshCategoricalRiskTests.malformedCategoricalDatesFailClosed` added to verify malformed categorical metadata throws and preserves existing persisted rows/dates.
  - `SpcProviderSyncMapProductsTests.malformedFireMetadataDoesNotClearActiveFireRisk` added to verify malformed fire metadata in staged sync does not clear existing active fire risk.
- Behavior intentionally preserved:
  - UTC `yyyyMMddHHmm` parsing behavior in `String.asUTCDate()` unchanged.
  - RSS/convective outlook parsing untouched.
  - Existing non-transactional accepted-batch persistence semantics unchanged (still a #208 concern).
- Validation run:
  - Passed focused malformed-date/staged tests:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/SevereRiskRepoRefreshTornadoRiskTests/malformedTornadoDatesFailClosed -only-testing:SkyAwareTests/StormRiskRepoRefreshCategoricalRiskTests/malformedCategoricalDatesFailClosed -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests/malformedFireMetadataDoesNotClearActiveFireRisk -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests/rejectedEmptyCategoricalPreservesExistingPersistedRisks -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests/futureOnlyCategoricalDoesNotReplaceActiveProjectionWindow`
  - Ran broader #205/#206 regression coverage and observed expected/deferred failures:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests -only-testing:SkyAwareTests/SevereRiskRepoRefreshTornadoRiskTests -only-testing:SkyAwareTests/SevereRiskRepoActiveSelectionTests`
    - Failing tests:
      - `SpcProviderSyncMapProductsTests.rejectedEmptyCategoricalPreservesExistingPersistedRisks()`
      - `SpcProviderSyncMapProductsTests.futureOnlyCategoricalDoesNotReplaceActiveProjectionWindow()`
      - `SevereRiskRepoRefreshTornadoRiskTests.transientEmptyCollectionDoesNotClearExistingActiveTornadoRisk()`
    - `.xcresult`: `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.28_12-37-25--0600.xcresult`
  - Build passed:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Handoff notes for #208:
  - Remaining failing regression cases still require transactional commit-by-window behavior to preserve existing active rows when candidate batches are rejected at provider stage.

### Issue #208 — Commit SPC Map Products Transactionally by Validity Window

- Status: In progress (core transactional window-scoped commit path implemented; one existing cooldown regression test remains failing, and projection/widget preservation remains #209 scope).
- Files changed:
  - `Sources/Providers/SPC/SpcProvider+Syncing.swift`
  - `Sources/Repos/StormRiskRepo.swift`
  - `Sources/Repos/SevereRiskRepo.swift`
  - `Sources/Repos/FireRiskRepo.swift`
  - `Tests/UnitTests/SevereRiskRepoRefreshTornadoRiskTests.swift`
  - `docs/plans/spc-map-ingestion-stability-progress.md`
- Transactional commit behavior implemented:
  - Provider map sync now stages and validates first, then commits accepted map products via explicit repo batch commit methods anchored to accepted categorical `ISSUE/VALID/EXPIRE`.
  - Rejected candidate batches now skip persistence mutation entirely and preserve existing active rows.
  - Accepted severe products can be empty and now clear only that threat within the accepted anchor window (legitimate threat removal/all-clear), not all current/future rows.
  - Repo writes for accepted batches are scoped to anchor window equality (`issued`, `valid`, `expires`) and do not delete unrelated future windows.
  - Existing `refresh*` methods were retained for existing callers/tests and still route through legacy replacement behavior outside the accepted-batch path.
- Tests added/updated:
  - `SpcProviderSyncMapProductsTests.acceptedBatchReplacesOnlyAcceptedWindowRows` added to prove accepted-window replacement does not clear unrelated future windows.
  - Existing staged regression tests updated to use active-time-aligned timestamps for current-date execution.
- Behavior intentionally preserved:
  - Staged validation anchor and rejection semantics from #206/#207 remain intact.
  - Empty severe products remain allowed in accepted coherent batches.
  - UI/widget projection behavior was not changed in this issue (deferred to #209).
- Validation run:
  - Ran:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests -only-testing:SkyAwareTests/SevereRiskRepoActiveSelectionTests -only-testing:SkyAwareTests/SevereRiskRepoRefreshTornadoRiskTests/malformedTornadoDatesFailClosed`
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests -only-testing:SkyAwareTests/SevereRiskRepoActiveSelectionTests`
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
  - Focused test result:
    - `SpcProviderSyncMapProductsTests` now passes all transactional/rejection/accepted-window cases except `backToBackCallsAreThrottled`.
    - `SevereRiskRepoActiveSelectionTests` passed.
    - `.xcresult` (latest focused): `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.28_14-22-35--0600.xcresult`
  - Build result: passed.
- Remaining handoff notes for #209:
  - `HomeRefreshPipelineTests.slowProductRefresh_unavailableMapSyncDoesNotOverwriteProjectionWithAllClear` still fails and remains the projection/widget-preservation follow-on.
  - Ensure rejected/unknown slow-product sync outcome is surfaced to projection persistence so rejected map sync cannot advance all-clear app/widget snapshots.

### Issue #209 — Preserve Projections and Widgets When Map Sync Is Rejected

- Status: In progress (slow-product projection/widget persistence now gated by explicit map-sync acceptance outcome; #205 and map-sync cooldown legacy failures remain outside this issue scope).
- Files changed:
  - `Sources/Interfaces/SPC/SpcSyncing.swift`
  - `Sources/Providers/SPC/SpcProvider.swift`
  - `Sources/Providers/SPC/SpcProvider+Syncing.swift`
  - `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
  - `Tests/UnitTests/HomeRefreshPipelineTests.swift`
  - `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`
  - `docs/plans/spc-map-ingestion-stability-progress.md`
- Ingestion outcome + projection preservation behavior:
  - Added explicit `SpcMapSyncOutcome` (`accepted`, `rejected`, `skipped`, `failed`) on the SPC sync seam.
  - `SpcProvider.syncMapProductsOutcome()` now reports staged-batch acceptance/rejection and transport/persistence failure state.
  - `HomeIngestionExecutor` now carries map-sync outcome through slow-product lane execution and gates persistence:
    - `accepted` and `skipped` keep existing slow-product projection/widget behavior.
    - `rejected` and `failed` skip `HomeProjectionStore.updateSlowProducts` and skip risk/location widget snapshot refresh.
  - Rejected/unavailable map sync can no longer advance projection risk slices or write false all-clear widget snapshots.
  - Accepted coherent all-clear updates remain allowed and continue to write both projection and widgets.
- Behavior intentionally preserved:
  - Hot-alert-only widget refresh behavior remains unchanged (remote hot-alert plans still excluded from normal widget refresh scope).
  - Background scheduling/cadence logic unchanged.
  - Slow-product freshness-skip behavior preserved (`skipped` outcome still permits existing projection/widget refresh flow).
- Tests added/updated:
  - Existing regression now passes:
    - `HomeRefreshPipelineTests.slowProductRefresh_unavailableMapSyncDoesNotOverwriteProjectionWithAllClear`
  - Added:
    - `HomeRefreshPipelineTests.slowProductRefresh_acceptedAllClearUpdatesProjectionAndWidgets`
  - Updated test doubles to support `syncMapProductsOutcome()` in:
    - `HomeRefreshPipelineTests`
    - `BackgroundOrchestratorCadenceTests`
- Validation run:
  - Ran focused regression suite:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/HomeRefreshPipelineTests -only-testing:SkyAwareTests/BackgroundOrchestratorCadenceTests -only-testing:SkyAwareTests/HomeProjectionStoreTests -only-testing:SkyAwareTests/WidgetSnapshotRefreshCoordinatorTests -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests -only-testing:SkyAwareTests/SevereRiskRepoRefreshTornadoRiskTests -only-testing:SkyAwareTests/SevereRiskRepoActiveSelectionTests`
  - Result: expected non-#209 legacy failures remain:
    - `SevereRiskRepoRefreshTornadoRiskTests.transientEmptyCollectionDoesNotClearExistingActiveTornadoRisk()`
    - `SpcProviderSyncMapProductsTests.backToBackCallsAreThrottled()`
  - `.xcresult`: `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.28_14-30-16--0600.xcresult`
  - Build passed:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Handoff notes for #210 observability:
  - Emit low-noise diagnostics for map sync outcomes consumed by home ingestion (`accepted`/`rejected`/`skipped`/`failed`) and whether projection/widget risk writes were skipped.
  - Include rejection reason and accepted window metadata from staged batch validation without logging location-sensitive payloads.

### Issue #210 — Add Observability for Accepted and Rejected SPC Batches

- Status: In progress (observability implemented with no ingestion-behavior changes).
- Files changed:
  - `Sources/Providers/SPC/SpcProvider+Syncing.swift`
  - `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
  - `docs/plans/spc-map-ingestion-stability-progress.md`
- Logs/diagnostics added:
  - Product-level staged diagnostics in SPC map sync:
    - `spc_map_product_stage`
    - Fields: `product`, `result` (`accepted`/`rejected`/`missing`), `reason`, `featureCount`, `issue`, `valid`, `expire`.
  - Batch validation summary:
    - `spc_map_batch_validation`
    - Fields: `result` (`accepted`/`rejected`), `reason`, `productCount`, and accepted anchor window fields (`anchorIssued`, `anchorValid`, `anchorExpires`) when accepted.
  - Persistence decision summary:
    - `spc_map_batch_persistence`
    - Fields: `result` (`skipped`/`committed`/`partial_failure`), `reason` (for skipped/rejected), `committed`, and accepted anchor window fields when applicable.
  - Projection/widget preservation/update decision in home ingestion:
    - `spc_map_persistence_projection_decision`
    - Fields: `mapSyncOutcome` (`accepted`/`rejected`/`skipped`/`failed`/`none`), `reason`, `projection` (`updated`/`preserved`), `widgets` (`updated`/`preserved`).
- Behavior intentionally preserved:
  - Staged validation acceptance/rejection semantics unchanged.
  - Transactional persistence semantics unchanged.
  - Projection/widget gating semantics from #209 unchanged; only explicit decision logging added.
  - No diagnostics UI expansion.
- Privacy guardrails preserved:
  - No user coordinates, placemark summaries, alert payloads, or location/alert sensitive fields added to logs.
  - Logged fields are product metadata, validity windows, feature counts, and rejection/decision reasons only.
- Validation run:
  - Tests passed:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test -only-testing:SkyAwareTests/HomeRefreshPipelineTests -only-testing:SkyAwareTests/BackgroundOrchestratorCadenceTests -only-testing:SkyAwareTests/HomeProjectionStoreTests -only-testing:SkyAwareTests/WidgetSnapshotRefreshCoordinatorTests -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests -only-testing:SkyAwareTests/SevereRiskRepoRefreshTornadoRiskTests -only-testing:SkyAwareTests/SevereRiskRepoActiveSelectionTests`
  - Result bundle:
    - `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.28_14-55-13--0600.xcresult`
  - Build passed:
    - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Remaining risks / follow-up recommendations:
  - Logs are intentionally compact and string-based for Console grepability; if future triage requires stronger machine parsing, consider adding a narrow typed diagnostics sink without changing ingestion flow.
