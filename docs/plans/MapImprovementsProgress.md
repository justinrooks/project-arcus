# Map Improvements Progress

## Status Legend

- `Planned`: Scoped but not started yet.
- `In Progress`: Actively being implemented.
- `Validated`: Implemented and validated locally.
- `Follow-up`: Intentionally deferred item or runtime validation still needed.

## Overall Plan

1. Create a stable implementation log and keep it current as the map refactor progresses.
2. Extract map orchestration out of `MapScreenView` into a dedicated feature model so the screen becomes a thin UI shell.
3. Introduce a single scene contract that drives both the map canvas and the legend from the same derived data.
4. Shift map rendering toward selected-layer-first materialization, then warm remaining layers incrementally without blocking first paint.
5. Simplify the `MKMapView` bridge so no-op SwiftUI updates do not trigger expensive overlay reconciliation work.
6. Harden concurrency, cancellation, and identity so the feature remains correct while we add future map capabilities.
7. Validate the refactor with targeted tests and a full app build.

## Scoped Fix Plans

### 1. Thin Screen And Extract A Feature Model

**Status:** `Validated`

**Goal**

Move data loading, derived-state building, and lifecycle management out of `MapScreenView` so the screen only coordinates UI composition.

**Implementation Plan**

1. Introduce a root-owned map feature model using modern Observation.
2. Move map loading, scene caching, selected-layer application, and teardown into the model.
3. Split the screen into a thin container and a content view that renders plain state.
4. Keep `selectedMapLayer` owned by `HomeView` so current navigation behavior stays intact.

**Validation Plan**

1. Build the app.
2. Run targeted map unit tests.

### 2. Introduce A Single Scene Contract

**Status:** `Validated`

**Goal**

Replace the current mix of raw DTO state, display state, and legend-specific re-derivation with one map scene model.

**Implementation Plan**

1. Define shared scene types for canvas state, legend state, and per-layer render plans.
2. Move legend derivation into the same planning pipeline that prepares map overlays.
3. Update `MapLegend` to render from derived legend state instead of raw DTO arrays.
4. Remove redundant screen-local map state that is no longer needed.

**Validation Plan**

1. Run map unit tests that cover ordering and style behavior.
2. Confirm the map feature still builds cleanly after the state-model swap.

### 3. Materialize The Selected Layer First

**Status:** `Validated`

**Goal**

Reduce cold-load hitching by avoiding eager main-thread MapKit object creation for every layer before the first visible layer is shown.

**Implementation Plan**

1. Keep all-layer planning in cheap sendable value types.
2. Materialize `MKOverlay` objects only for the selected layer first.
3. Warm remaining layers incrementally after the selected layer is visible.
4. Preserve fast layer switching by caching materialized scenes after they are built.

**Validation Plan**

1. Build the app.
2. Re-run targeted map tests.

### 4. Add A Cheap No-Op Bridge Path

**Status:** `Validated`

**Goal**

Stop the `UIViewRepresentable` bridge from doing expensive overlay reconciliation when the semantic map content has not changed.

**Implementation Plan**

1. Collapse the bridge input down to one overlay-driven canvas state.
2. Add a revision token to the canvas state.
3. Bail out early in `updateUIView` when the revision is unchanged.
4. Remove unused steady-state `MKMultiPolygon` work from the map canvas path.

**Validation Plan**

1. Build the app.
2. Run affected map tests.

### 5. Harden Concurrency And Lifecycle Behavior

**Status:** `Validated`

**Goal**

Make the map pipeline more predictable under cancellation and future feature growth.

**Implementation Plan**

1. Replace detached rebuild work with structured async flow or an explicit planner boundary.
2. Treat `CancellationError` as cancellation instead of a normal load failure.
3. Keep MapKit object creation and cache mutation explicitly on the main actor.
4. Preserve current one-time initial map centering behavior without tying map work to every location snapshot update.

**Validation Plan**

1. Build the app.
2. Run targeted tests.

### 6. Stabilize Overlay Identity

**Status:** `Validated`

**Goal**

Reduce overlay churn during future feed refreshes and make the cache more resilient to input reordering.

**Implementation Plan**

1. Replace index-based polygon keys with stable geometry-based fingerprints.
2. Carry stable overlay signatures through the render plan so the bridge can reuse work cheaply.
3. Update tests to cover key stability and identity expectations.

**Validation Plan**

1. Run map unit tests.
2. Build the app.

## Progress Log

### 2026-04-21

- Created the implementation tracker with the overall plan and per-fix scoped plans.
- Extracted map orchestration into `MapFeatureModel` and reduced `MapScreenView` to a thin container plus content view.
- Unified the map canvas and legend behind shared derived scene state so overlay planning and legend output now come from the same pipeline.
- Switched the feature to selected-layer-first materialization with cached scene warming for the remaining layers after first paint.
- Simplified the `MKMapView` bridge to a single canvas state input with overlay revision short-circuiting for no-op SwiftUI updates.
- Replaced index-based polygon identity with stable geometry fingerprints and threaded stable overlay signatures through the render plan and bridge cache.
- Added focused `MapFeatureModelTests` for selected-scene construction, partial-feed resilience, no-refetch behavior, layer switching, and one-time initial centering.
- Updated `SkyAware.xcodeproj` filesystem-synced membership exceptions so the new map tests are excluded from the app target and included in the unit-test target.
- Investigated a reported runtime regression where map layers appeared to be missing after the refactor.
- Verified in the iPhone 17 simulator that Severe Risk, Wind, and categorical overlays render correctly with current store data.
- Confirmed the Fire layer was empty because the synced fire product was future-dated, with the latest `valid` timestamp at `2026-04-21 17:00:00 UTC` while the investigation was performed around `2026-04-21 16:35 UTC`.
- Removed temporary map debug instrumentation after finishing the runtime investigation.
- Added scene-level regression tests that verify categorical overlays stack from thunderstorm upward and that wind, hail, and tornado overlays stack from lower percentages to higher percentages, with higher-risk overlays last/topmost.

### 2026-04-22

- Re-read the updated repo and app `AGENTS.md` guidance before starting the latest-product regression work.
- Traced the full map-product flow from `MapScreenView` through `MapFeatureModel`, `SpcMapData`, the SPC provider, and the backing SwiftData repos.
- Confirmed a regression in the refactored map feature model: once the map loaded once, stale layer scenes could remain cached and local map data was not guaranteed to be re-read on later appearances.
- Updated the map feature model so refresh requests cannot be silently dropped while a load is already in progress; a second request now forces one follow-up fetch after the current pass finishes.
- Kept the map screen reloading local map data on appearance and when the scene becomes active so the visible layer rehydrates from the latest persisted products.
- Aligned current-valid map queries across categorical, severe, and mesoscale repos with inclusive expiry/end boundaries so products do not disappear exactly at transition timestamps.
- Added focused regression tests for queued follow-up reloads in `MapFeatureModel` and boundary-valid map product selection in the repo layer.
- Rebuilt the app and verified in the iPhone 17 simulator that Fire and Severe Risk layers render visible products after reopening the app.

## Validation

### Targeted Map Tests

- Command: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/MapFeatureModelTests -only-testing:SkyAwareTests/MapPolygonMapperTests -only-testing:SkyAwareTests/RiskPolygonOverlayTests test`
- Result: `Passed`
- xcresult: `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.04.21_09-52-01--0600.xcresult`

### App Build

- Command: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: `Passed`
- Notes: Build completed with one existing unrelated deprecation warning in `Sources/Interfaces/Notification/NotificationRuleEvaluating.swift`.

### Overlay Ordering Verification

- Command: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/MapFeatureModelTests -only-testing:SkyAwareTests/MapPolygonMapperTests test`
- Result: `Passed`
- xcresult: `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.04.21_13-17-19--0600.xcresult`
- Notes: Verified categorical stacking order and severe-layer probability stacking order at both the polygon-mapping stage and the final scene overlay stage.

### Latest-Product Regression Verification

- Command: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/MapFeatureModelTests -only-testing:SkyAwareTests/MapPolygonMapperTests -only-testing:SkyAwareTests/MapDataFreshnessRepoTests test`
- Result: `Passed`
- xcresult: `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.04.22_11-15-43--0600.xcresult`
- Notes: Covers refetch-on-reload behavior, stale scene replacement, queued follow-up reloads while a load is in flight, overlay ordering, and inclusive validity-boundary selection in the repo layer.

### Latest-Product Runtime Verification

- Command: manual simulator interaction on `iPhone 17` with the freshly built/tested app.
- Result: `Passed`
- Notes: Reopened the app, navigated to the map, and confirmed visible products on both `Severe Risk` and `Fire` layers after lifecycle transitions.
