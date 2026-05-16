# FB-013 Progress Log

## Overview

FB-013 adds active NWS warning geometry to the SkyAware map.

Implementation should proceed one issue at a time under epic `#131 [Epic] Add active warning geometry to the map`, following `docs/plans/FB-013-issue-runbook.md`.

Primary source of truth:
- `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/+/FB-013 Add Active Warning Geometry.md`

Related GitHub issues:
- `justinrooks/project-arcus#131` - `[Epic] Add active warning geometry to the map`
- `justinrooks/project-arcus#132` - `Add Shared Nullable Geometry to DeviceAlertPayload`
- `justinrooks/arcus-signal#48` - `Expose Latest Series Geometry in DeviceAlertPayload`
- `justinrooks/project-arcus#133` - `Persist Warning Geometry from Arcus Payloads into SwiftData`
- `justinrooks/project-arcus#134` - `Add SwiftData-Backed Active Warning Geometry Query`
- `justinrooks/project-arcus#135` - `Convert Active Warning Geometry into Stable Map Overlays`
- `justinrooks/project-arcus#136` - `Add Warning-Specific Map Polygon Styling`
- `justinrooks/project-arcus#137` - `Compose Warning Overlays above Every Map Layer`
- `justinrooks/project-arcus#138` - `Add Default-On Warning Geometry Toggle to Map Picker`
- `justinrooks/project-arcus#139` - `Validate Offline Warning Geometry Rendering from SwiftData`

---

## Global Decisions

- `DeviceAlertPayload.geometry` is the app/server transport contract for warning geometry.
- `geometry == nil` means the alert has no renderable warning polygon.
- Server geometry should come from latest current-series `arcus_geolocation.geometry`.
- App geometry should persist in SwiftData and render from SwiftData-backed alert state.
- Warning geometry is a default-on baseline overlay above all thematic map layers.
- Warning geometry is not a mutually exclusive `MapLayer`.
- V1 is render-only.
- Watches, mesos, tap/select behavior, overlap resolution, and historical revision geometry are out of scope.
- Existing alert notification behavior should remain unchanged.

---

## Current Status

- Epic and all child issues have been created.
- All FB-013 items are assigned to the Project Arcus GitHub Project.
- Project status/priority:
  - Epic `#131`: `Ready`, `P0`
  - Child issues: `Ready`, `P1`
- Issue bodies have been normalized to the FB-010 issue format.
- Issue `#132` is complete in Project Arcus and mirrored in the Arcus Signal payload model.
- Issue `arcus-signal#48` is complete in Arcus Signal.
- Issue `#133` is complete in Project Arcus.
- Issue `#138` is complete in Project Arcus.
- Remaining Project Arcus child issues are still pending and should continue in sequence from `#139`.

---

## Issue #132 - Add Shared Nullable Geometry to DeviceAlertPayload

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Goals 1 and 2 by defining the shared warning geometry transport shape.
  - Constraints / Invariants covering nil geometry semantics and polygon plus multipolygon compatibility.
  - Acceptance criteria 1 and 9 by adding the nullable payload contract and decoding support for both geometry families.
- Issue requirements completed:
  - Added nullable `geometry` to the app and server `DeviceAlertPayload` models.
  - Supported `Polygon` and `MultiPolygon` transport payloads.
  - Preserved decode compatibility when `geometry` is missing.
  - Documented transport coordinate order as longitude then latitude.
  - Left rendering, persistence, and notification behavior untouched.

### Key implementation notes
- Added a narrow `DeviceAlertGeometry` enum instead of reusing the server's broader `GeoShape`, because v1 only needs polygon and multipolygon transport and this issue should not smuggle in unsupported geometry types.
- Transport coordinates are modeled as `[longitude, latitude]` arrays via `DeviceAlertCoordinate`, with map-native conversion deferred to the rendering edge.
- `swift-concurrency-expert` was not applicable because this issue does not change async flows, actors, SwiftData actors, or cross-concurrency boundaries.
- `build-ios-apps:swiftui-ui-patterns` was not applicable because this issue does not touch SwiftUI, view composition, or picker controls.

### Files changed
- `Sources/Models/Watches/DeviceAlertPayload.swift`
- `Tests/UnitTests/DeviceAlertPayloadTests.swift`
- `/Users/justin/Code/arcus-signal/Sources/App/Models/Device/DeviceAlertPayload.swift`

### Tests
- Added:
  - `DeviceAlertPayloadTests.polygonGeometry_decodes`
  - `DeviceAlertPayloadTests.multiPolygonGeometry_decodes`
- Updated:
  - `DeviceAlertPayloadTests.missingUgc_decodes`

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -only-testing:SkyAwareTests/DeviceAlertPayloadTests test`
  2. Confirm the suite passes for missing geometry, polygon geometry, and multipolygon geometry decoding.
  3. Confirm the app and Arcus Signal payload models both expose `geometry: DeviceAlertGeometry?`.
- Expected result:
  - Payloads without `geometry` still decode.
  - `Polygon` and `MultiPolygon` payloads decode with longitude/latitude transport order preserved.
  - Nil geometry remains the explicit no-polygon contract.

### Out of scope / intentionally deferred
- Server endpoint exposure
- SwiftData persistence
- Map rendering
- Toggle UI

### Risks or follow-ups
- The app and server now mirror the same contract shape, but they are still duplicated source files. A future packaging/shared-model cleanup can remove that drift risk without broadening FB-013 scope.
- Server-side endpoint exposure and row mapping are still deferred to `arcus-signal#48`.

### Handoff to next issue
- The next issue should assume:
  - `DeviceAlertPayload.geometry` exists and is nullable in both repos.
  - The transport shape supports only `Polygon` and `MultiPolygon`.
  - Coordinate arrays are stored as longitude then latitude until the rendering edge.
- Watch out for:
  - Do not re-encode geometry into map-native coordinate objects inside payload or persistence layers.
  - Do not broaden the contract to points or interior rings unless a later issue explicitly requires it.
- Recommended next step:
  - Implement `arcus-signal#48` so `/api/v1/alerts` actually populates the new payload field from latest series geometry.

---

## Issue arcus-signal#48 - Expose Latest Series Geometry in DeviceAlertPayload

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Goals 1 and 2 by wiring server-side warning geometry into the existing device alert payload path.
  - Target Behavior requiring the server and app to share the warning geometry contract through `DeviceAlertPayload`.
  - Constraints / Invariants requiring server geometry to come from latest current-series `arcus_geolocation.geometry`.
  - Acceptance criteria 1 and 9 by serving nullable polygon and multipolygon geometry through the shared payload shape.
- Issue requirements completed:
  - `/api/v1/alerts` row mapping now selects joined `arcus_geolocation.geometry`.
  - `AlertSeriesRow.asDeviceAlertPayload()` passes nullable joined geometry through to `DeviceAlertPayload.geometry`.
  - `ArcusSeriesModel.asDeviceAlertPayload()` passes eager-loaded `ArcusGeolocationModel.geometry` through for model-based payload creation.
  - `GeoShape.point` maps to nil because v1 has no renderable warning polygon for point geometry.
  - Existing `h3Cells` behavior remains unchanged.
  - No schema migration, APNs payload change, targeting policy change, or revision-level geometry persistence was introduced.

### Key implementation notes
- Added a narrow `DeviceAlertGeometry.init?(geoShape:)` conversion helper that accepts only polygon and multipolygon server geometry.
- The alert response SQL continues to left join `arcus_geolocation`; missing geolocation rows produce nil geometry and empty `h3Cells`.
- The row projection explicitly selects `g.geometry AS geometry` and avoids the deprecated `arcus_series.geometry` column.
- `swift-concurrency-expert` was applicable because this is server Swift/Vapor payload code. It did not require actor or isolation changes; the implementation stayed in immutable `Sendable` value mapping and did not alter async handler behavior.
- `build-ios-apps:swiftui-ui-patterns` was not applicable because this issue does not touch SwiftUI, view composition, picker controls, or user-facing app UI.

### Files changed
- `/Users/justin/Code/arcus-signal/Sources/App/Models/Device/DeviceAlertPayload.swift`
- `/Users/justin/Code/arcus-signal/Sources/App/Models/API/AlertSeriesRow.swift`
- `/Users/justin/Code/arcus-signal/Sources/App/Models/NWS/ArcusSeriesModel.swift`
- `/Users/justin/Code/arcus-signal/Tests/AppTests/AppTests.swift`

### Tests
- Added:
  - `AppTests.deviceAlertPayloadIncludesGeolocationGeometry`
  - `AppTests.deviceAlertGeometryConvertsMultipolygonGeoShape`
  - `AppTests.alertSeriesRowPayloadIncludesJoinedGeometry`
  - `AppTests.alertSeriesRowSelectsJoinedGeolocationGeometry`
- Updated:
  - `AppTests.deviceAlertPayloadIncludesGeolocationCells`
  - `AppTests.alertSeriesRowPayloadAllowsMissingGeolocation`

### Verification
- How to verify:
  1. In `/Users/justin/Code/arcus-signal`, run `swift test --filter AppTests`.
  2. In `/Users/justin/Code/arcus-signal`, run `swift build`.
  3. Confirm an alert row with joined `arcus_geolocation.geometry` maps that geometry into `DeviceAlertPayload.geometry`.
  4. Confirm an alert row without joined geolocation still returns `geometry == nil` and `h3Cells == []`.
- Expected result:
  - `/api/v1/alerts` payload rows include geometry when `arcus_geolocation.geometry` is present and renderable.
  - Payload rows omit/null geometry when geolocation is absent or geometry is a non-renderable point.
  - Existing notification and H3 cell behavior is unchanged.

### Out of scope / intentionally deferred
- Historical/revision geometry persistence
- APNs custom payload changes
- Targeting policy changes
- App rendering

### Risks or follow-ups
- The epic checkbox for `arcus-signal#48` was already checked even though the issue itself remained open and the progress log still said not started. Treat this entry as the durable implementation record.
- The endpoint-level behavior is covered through row/model payload mapping tests rather than a live database-backed `/api/v1/alerts` integration test, because the existing test harness does not create alert/geolocation rows for that endpoint.
- Pre-existing local changes in Arcus Signal SQL scratch docs and `Package.resolved` were present before this issue work and were left untouched.

### Handoff to next issue
- The app persistence issue should assume:
  - Arcus `/api/v1/alerts` payloads can include nullable latest-series `DeviceAlertPayload.geometry`.
  - Nil geometry still means no renderable warning polygon.
  - Transport coordinates remain longitude then latitude.
- Watch out for:
  - Persist geometry as optional/defaulted state on the existing `Watch` model; do not rename the model.
  - Do not convert coordinates to map-native types in persistence.
  - Preserve existing alert matching, H3, and notification semantics.
- Recommended next step:
  - Implement Project Arcus `#133` to persist optional geometry from Arcus payloads into SwiftData and surface it through `WatchRowDTO`.

---

## Issue #133 - Persist Warning Geometry from Arcus Payloads into SwiftData

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Goals 1 and 3 by carrying active warning geometry from Arcus payloads into local alert state.
  - Target Behavior requiring warning geometry to be available from the local SwiftData cache.
  - Constraints / Invariants requiring SwiftData to be the client source for active warning geometry.
  - Acceptance criteria 6, 7, and 9 by persisting nullable polygon and multipolygon geometry without changing active alert matching.
- Issue requirements completed:
  - Decoded `DeviceAlertPayload.geometry` now flows into `WatchRepo.makeWatch(from:)`.
  - The existing `Watch` SwiftData model stores optional warning geometry through a SwiftData-safe JSON `Data` backing column.
  - `Watch.geometry` and `WatchRowDTO.geometry` expose typed `DeviceAlertGeometry?` to call sites.
  - Missing or later-omitted geometry persists as nil and clears stale stored geometry on refresh.
  - Existing UGC/H3 active matching and alert UI data flow remain unchanged.

### Key implementation notes
- Kept the existing `Watch` model name even though it now carries warning geometry.
- Did not persist `DeviceAlertGeometry?` directly because SwiftData traps on the associated-value enum as an optional composite attribute. `Watch.geometryData` stores encoded JSON `Data?`, while `Watch.geometry` remains the typed boundary.
- Mirrored that storage pattern in `WatchRowDTO` because `HomeProjection.activeAlerts` persists `[WatchRowDTO]`; direct enum storage there would create the same SwiftData risk for cached home projections.
- Added `Hashable` to `DeviceAlertGeometry` and `DeviceAlertCoordinate` so `WatchRowDTO` remains `Hashable`.
- Marked `WatchRepoRefreshTests` serialized because the suite exercises one in-memory SwiftData repo with unique-id replacement semantics.
- `swift-concurrency-expert` was applicable because this issue touches SwiftData and a `@ModelActor` repository. The final shape keeps immutable `Sendable` value transport and does not alter actor isolation or async flow.
- `build-ios-apps:swiftui-ui-patterns` was not applicable because this issue does not touch SwiftUI views, picker controls, map composition, or user-facing UI.

### Files changed
- `Sources/Models/Watches/DeviceAlertPayload.swift`
- `Sources/Models/Watches/Watch.swift`
- `Sources/Models/Watches/WatchRowDTO.swift`
- `Sources/Repos/WatchRepo.swift`
- `Tests/UnitTests/HomeProjectionStoreTests.swift`
- `Tests/UnitTests/WatchRepoRefreshTests.swift`

### Tests
- Added:
  - `WatchRepoRefreshTests.refresh_persistsPolygonGeometry`
  - `WatchRepoRefreshTests.refresh_persistsMultiPolygonGeometry`
  - `WatchRepoRefreshTests.refresh_replacesStoredGeometry`
  - `WatchRepoRefreshTests.refresh_clearsStoredGeometry`
  - `HomeProjectionStoreTests.updateHotAlerts_preservesWarningGeometry`
- Updated:
  - `WatchRepoRefreshTests.targetedRefresh_decodesSinglePayload`

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/WatchRepoRefreshTests -only-testing:SkyAwareTests/HomeProjectionStoreTests test`
  2. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/DeviceAlertPayloadTests -only-testing:SkyAwareTests/WatchRepoActiveTests test`
  3. Confirm polygon and multipolygon payload geometry persist into `Watch` and surface through `WatchRowDTO`.
  4. Confirm refreshing the same alert replaces geometry without duplicating the stored row.
  5. Confirm a later payload with missing geometry clears the stored geometry.
- Expected result:
  - Payloads without geometry still decode and persist normally.
  - Polygon and multipolygon geometries persist in SwiftData-backed alert state.
  - Updated geometry replaces stored geometry for the same canonical alert id.
  - Existing active alert matching by UGC/H3 continues to work.
  - Cached home projections can persist and reload `WatchRowDTO` values carrying warning geometry.

### Out of scope / intentionally deferred
- Map rendering
- UI controls
- Model renaming
- Notification behavior changes

### Handoff to next issue
- The active warning geometry query should assume:
  - `Watch.geometry` and `WatchRowDTO.geometry` expose typed optional `DeviceAlertGeometry`.
  - The persisted SwiftData column is `geometryData`, not a direct enum property.
  - Nil geometry means no renderable warning polygon and should be filtered out by the query.
- Watch out for:
  - Query typed geometry through the computed `geometry` property; do not reach into `geometryData` outside persistence/cache boundaries.
  - Keep active filtering explicit and local: supported warning events, active lifecycle state, current time window, and non-nil geometry.
  - Do not fetch network state from the map or query layer.
- Recommended next step:
  - Implement Project Arcus `#134` to add a SwiftData-backed active warning geometry query for supported warning types only.

---

## Issue #134 - Add SwiftData-Backed Active Warning Geometry Query

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - Goals 1, 2, and 3 by exposing locally persisted warning geometry as client-consumable active alert state.
  - Target Behavior requiring warning geometry to be surfaced from the SwiftData cache for app rendering.
  - Constraints / Invariants requiring explicit lifecycle filtering, supported warning filtering, and nil-geometry exclusion.
  - Acceptance criteria 6, 7, 9, and the lifecycle portions of 3 by querying cached polygon/multipolygon geometry only for active supported warnings.
- Issue requirements completed:
  - Added `ActiveWarningGeometry` as a narrow immutable result shape for future map overlay conversion.
  - Added `ArcusAlertQuerying.getActiveWarningGeometries(on:)`.
  - Implemented the query through `ArcusAlertProvider` and `WatchRepo`.
  - Included only Tornado Warning, Severe Thunderstorm Warning, and Flash Flood Warning.
  - Excluded watches, unsupported alert types, nil geometry, expired warnings, canceled messages, and non-active states.
  - Kept the query SwiftData-backed and network-free.

### Key implementation notes
- The query returns all locally persisted active supported warning geometries, rather than location-filtering a second time. The local cache already represents the app's Arcus-backed alert state, and future map composition can consume this without issuing network requests.
- `ActiveWarningGeometry` carries alert id, revision identifier, revision sent date, event type, lifecycle timing fields, message type, and typed `DeviceAlertGeometry`.
- Local lifecycle filtering treats `Active` and legacy CAP-style `Actual` statuses as renderable only when the warning is within its effective/end window and the message type is not cancel/cancelled.
- Kept geometry in the existing `Watch` model and typed `DeviceAlertGeometry` boundary; no map-native coordinate conversion was introduced.
- `swift-concurrency-expert` was applicable because the issue touches a SwiftData `@ModelActor` and an async provider protocol. The implementation returns immutable `Sendable` values from the actor and does not alter actor isolation or introduce detached work.
- `build-ios-apps:swiftui-ui-patterns` was not applicable because this issue does not touch SwiftUI views, picker controls, `@State`, `@Binding`, map composition, or layout.

### Files changed
- `Sources/Interfaces/Arcus/ArcusAlertQuerying.swift`
- `Sources/Models/Watches/WatchRowDTO.swift`
- `Sources/Providers/ArcusAlertProvider.swift`
- `Sources/Repos/WatchRepo.swift`
- `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`
- `Tests/UnitTests/HomeRefreshPipelineTests.swift`
- `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`
- `Tests/UnitTests/WatchRepoActiveTests.swift`

### Tests
- Added:
  - `WatchRepoActiveTests.activeWarningGeometries_includesSupportedWarningsWithGeometry`
  - `WatchRepoActiveTests.activeWarningGeometries_excludesUnsupportedAndNilGeometry`
  - `WatchRepoActiveTests.activeWarningGeometries_excludesInactiveLifecycle`
  - `WatchRepoActiveTests.providerActiveWarningGeometries_usesLocalRepoWithoutNetwork`
- Updated:
  - Arcus alert query test fakes to satisfy the new `getActiveWarningGeometries(on:)` protocol requirement.

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/WatchRepoActiveTests test`
  2. Confirm the new active warning geometry tests pass.
  3. Confirm `providerActiveWarningGeometries_usesLocalRepoWithoutNetwork` passes with an `ArcusClient` that would fail any network fetch.
  4. Run a full app build to verify the protocol change compiles across app and test targets.
- Expected result:
  - Supported active warnings with polygon or multipolygon geometry are returned from SwiftData.
  - Watches, unsupported events, nil geometry, expired warnings, canceled messages, and non-active states are excluded.
  - Querying through `ArcusAlertProvider` does not call Arcus network fetch methods.
  - The result contains enough identity, revision, lifecycle, event, and geometry data for issue `#135` to build stable overlays.

### Out of scope / intentionally deferred
- Map overlay construction
- Network fetch behavior changes
- Map styling
- Toggle UI
- Notification behavior changes

### Risks or follow-ups
- The query currently sorts by event then id for deterministic results. Future overlay conversion should define its own stable overlay identity and not rely on result order as map z-order.
- The result shape intentionally carries transport geometry, not `CLLocationCoordinate2D` or `MKPolygon`; conversion remains deferred to `#135`.

### Handoff to next issue
- The map overlay conversion issue should assume:
  - `ArcusAlertQuerying.getActiveWarningGeometries(on:)` returns cached active warning geometry without network access.
  - `ActiveWarningGeometry.geometry` is still GeoJSON-like transport geometry with longitude/latitude coordinate order.
  - Nil, inactive, expired, canceled, watch, meso, and unsupported warning rows have already been filtered out.
- Watch out for:
  - Do not reach into `Watch.geometryData` or raw SwiftData from map overlay conversion.
  - Do not add tap/select behavior while converting overlays.
  - Do not change meso or watch rendering.
- Recommended next step:
  - Implement Project Arcus `#135` by mapping `ActiveWarningGeometry` polygon and multipolygon exterior rings into stable map overlay entries.

---

## Issue #135 - Convert Active Warning Geometry into Stable Map Overlays

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - `Map Overlay Mapping` by converting active warning polygon and multipolygon geometry into stable keyed map overlay entries.
  - `Active Warning Geometry Query` by consuming the issue `#134` result shape (`ActiveWarningGeometry`) at the map-mapping seam.
  - `Architecture Direction` by reusing existing map overlay mapping structures and avoiding broader architecture changes.
  - `Explicitly Out of Scope for V1` by keeping the change render-mapping only with no tap/select, toggle, overlap handling, or notification work.
- Issue requirements completed:
  - Added warning geometry mapping in `MapPolygonMapper`.
  - Supported polygon and multipolygon exterior rings only.
  - Generated deterministic warning overlay keys from alert id, revision identity fallback, event type, polygon index, and geometry fingerprint.
  - Ensured geometry changes produce new overlay identity keys so stale geometry is replaced.
  - Left existing SPC/fire/meso key and signature behavior unchanged.

### Key implementation notes
- Added `MapPolygonMapper.warningPolygons(from:)` as an issue-local seam that maps `ActiveWarningGeometry` into `KeyedMapPolygons`.
- Multipolygon conversion emits one overlay entry per polygon using the exterior ring only; interior rings are intentionally ignored for v1.
- Warning entries are sorted deterministically by event, id, revision identity, and issued date before mapping, so output remains stable regardless of input ordering.
- Warning key format includes a geometry fingerprint derived from normalized coordinates, allowing revised geometry to replace stale overlays without touching non-warning key behavior.
- `swift-concurrency-expert` was evaluated and not applicable for this issue because no async flow, actor isolation, or Sendable boundary changed.
- `build-ios-apps:swiftui-ui-patterns` was evaluated and not applicable because this issue does not touch SwiftUI views or map screen composition.

### Files changed
- `Sources/Features/Map/MapPolygonMapper.swift`
- `Tests/UnitTests/MapPolygonMapperTests.swift`

### Tests
- Added:
  - `MapPolygonMapperTests.warningPolygonMapping_usesExteriorRingOnly`
  - `MapPolygonMapperTests.warningMultipolygonMapping_createsStableEntries`
  - `MapPolygonMapperTests.warningOverlayKeys_areDeterministic`
  - `MapPolygonMapperTests.warningOverlayEntries_haveStableOrdering`
  - `MapPolygonMapperTests.warningGeometryChanges_updateOverlayIdentityFingerprint`
- Updated:
  - None

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/MapPolygonMapperTests test`
  2. Confirm new warning mapping tests pass for polygon/multipolygon conversion, deterministic keying, stable ordering, and geometry update identity changes.
  3. Confirm existing `MapPolygonMapperTests` for categorical/severe/meso/fire still pass.
- Expected result:
  - Warning geometry maps into stable keyed overlay entries for polygon and multipolygon shapes.
  - Geometry revisions produce changed key fingerprints for replacement behavior.
  - Existing non-warning overlay mapping behavior remains unchanged.

### Out of scope / intentionally deferred
- Final warning styling
- Warning overlay composition above all map layers
- Warning toggle in picker
- Tap/select behavior
- Overlap resolution
- Notification behavior changes

### Handoff to next issue
- The next issue should assume:
  - Warning geometry can already be converted into deterministic keyed overlay entries via `MapPolygonMapper`.
  - Multipolygon and polygon exterior rings map to stable entries with per-polygon identity.
  - Non-warning key/signature behavior is unchanged.
- Watch out for:
  - Do not rework warning key semantics when implementing styling.
  - Keep warning styling isolated to overlay appearance, not overlay identity.
- Recommended next step:
  - Implement issue `#136` to add warning-specific visual styling on top of these stable warning overlay entries.

---

## Issue #136 - Add Warning-Specific Map Polygon Styling

### Status
- Completed

### Scope completed
- Add warning-specific stroke/fill treatments for supported warning types.

### Key implementation notes
- Tornado Warning uses existing `tornadoRed`.
- Severe Thunderstorm Warning uses a yellow warning treatment.
- Flash Flood Warning uses a dedicated blue/flood treatment.
- Stroke should be stronger than fill.
- Fill should stay light and translucent.
- Do not overload SPC probability styling with warning semantics.
- Added a focused warning polygon style helper instead of threading warning semantics through the SPC probability resolver.
- The renderer now checks warning styling first for generic `MKPolygon` overlays and falls back to existing SPC styling for non-warning polygons.
- `swift-concurrency-expert` was not applicable because this issue does not change async flow, actor isolation, SwiftData concurrency, or other cross-boundary sendability concerns.
- `build-ios-apps:swiftui-ui-patterns` was not applicable because this issue does not change SwiftUI view composition, state flow, or picker/map screen structure.

### Files changed
- `Sources/Utilities/Core/AlertStyling.swift`
- `Sources/Utilities/Extensions/ext+Color.swift`
- `Sources/Features/Map/MapCoordinator.swift`
- `Tests/UnitTests/AlertStylingTests.swift`
- `Tests/UnitTests/RiskPolygonOverlayTests.swift`

### Tests
- Added:
  - `AlertStylingTests.warningPolygonStyle_usesTornadoRed`
  - `AlertStylingTests.warningPolygonStyle_usesYellowForSevereThunderstormWarning`
  - `AlertStylingTests.warningPolygonStyle_usesBlueForFlashFloodWarning`
  - `AlertStylingTests.warningPolygonStyle_ignoresUnsupportedWarnings`
  - `RiskPolygonOverlayTests.mapCoordinator_rendersWarningPolygonWithWarningStyle`

### Verification
- How to verify:
  1. Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SkyAwareTests/AlertStylingTests -only-testing:SkyAwareTests/RiskPolygonOverlayTests test`
  2. Confirm the new warning-style tests pass for Tornado Warning, Severe Thunderstorm Warning, Flash Flood Warning, and unsupported warning titles.
  3. Confirm the renderer path returns a warning-specific `MKPolygonRenderer` with stronger stroke styling for warning-titled polygons.
- Result:
  - Focused unit tests passed.
  - The xcresult summary showed no test failures.
  - Coverage information was present in the result bundle, but no explicit coverage percentage was surfaced by the summary command we inspected.

### Verification target
- Each supported warning type maps to a distinct deterministic style.
- Existing SPC/fire/meso styles are not regressed.

### Out of scope / intentionally deferred
- Overlap resolution
- Legend polish
- Tap/select behavior

### Handoff to next issue
- Map composition can now append warning overlays using finalized visual treatment above thematic layers.

---

## Issue #137 - Compose Warning Overlays above Every Map Layer

### Status
- Completed

### Scope completed
- Compose warning overlays above every selected thematic map layer.

### Key implementation notes
- Warning geometry is a baseline overlay, not a new exclusive map layer.
- `MapFeatureModel.reload` now fetches active warning geometry alongside SPC map data through the existing `ArcusAlertQuerying` boundary.
- Warning query failures are logged and treated as empty warning geometry; cancellation still aborts the reload so superseded work does not apply stale scenes.
- `MapDataPayload` now carries `activeWarnings`, and `MapRenderPlanBuilder` appends warning overlay plans after thematic overlay plans for every `MapLayer`.
- Warning overlay plans materialize as plain `MKPolygon` overlays so the warning-specific renderer path from issue `#136` applies without changing thematic overlay behavior.
- Overlay revision calculation now includes appended warning plans, so warning add/remove/revision changes invalidate cached overlay state correctly while leaving non-warning key/signature behavior unchanged.
- Layer warming and cached per-layer scene behavior stay intact because warnings are composed inside the existing `MapLayerRenderPlan` pipeline rather than through a separate cache or map layer system.
- `swift-concurrency-expert` was applicable because this issue added an async query through the provider boundary. The implementation kept the existing `@MainActor` model, reused immutable value payloads, and preserved cancellation semantics instead of introducing detached work or broader isolation changes.
- `build-ios-apps:swiftui-ui-patterns` was applicable because the map screen wires the reload call from SwiftUI. The only UI change was passing the existing environment dependency into the existing `onAppear` and scene-phase reload hooks; no new view state or control surface was introduced.

### Files changed
- `Sources/Features/Map/MapFeatureModel.swift`
- `Sources/Features/Map/MapScreenView.swift`
- `Tests/UnitTests/MapFeatureModelTests.swift`
- `docs/plans/FB-013-progress.md`

### Tests
- Added:
  - `MapFeatureModelTests.reload_composesWarningOverlaysAboveSelectedLayer`
  - `MapFeatureModelTests.reload_composesWarningOverlaysForEveryLayer`
  - `MapFeatureModelTests.reload_warningQueryFailurePreservesThematicLayers`
  - `MapFeatureModelTests.reload_warningGeometryChangesUpdateOverlayRevision`
- Updated:
  - Existing `MapFeatureModelTests` reload call sites to inject the Arcus warning query stub.

### Verification
- Ran:
  1. `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/MapFeatureModelTests test`
  2. `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/MapPolygonMapperTests -only-testing:SkyAwareTests/RiskPolygonOverlayTests test`
  3. `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build`
- Result:
  - Focused map composition tests passed, including overlay ordering, per-layer warning composition, warning-query failure isolation, and overlay revision updates when warning geometry changes.
  - Existing warning overlay mapping and rendering tests also passed.
  - Full app build succeeded after the reload dependency change.

### Out of scope / intentionally deferred
- Picker toggle UI
- Legend polish
- Alert detail routing
- Overlap resolution
- Tap/select behavior
- Warning detail routing or selection
- Any architecture broadening beyond the existing map scene plan/materializer path

### Handoff to next issue
- Toggle work should only control whether composed warning overlays are included, not how alert geometry is fetched or persisted.

---

## Issue #137 Implementation Plan

### 1. Issue-specific scope summary
- Compose already-queryable active warning geometry into the existing map scene planning/rendering path.
- Warnings should render as baseline situational context above every selected thematic map layer: categorical, wind, hail, tornado, meso, and fire.
- The implementation should query SwiftData-backed warning state through `ArcusAlertQuerying.getActiveWarningGeometries(on:)`, convert it through the existing warning polygon mapper, and append warning overlay plans after the thematic overlay plans for each `MapLayer`.
- Existing map layers must continue rendering when warning geometry is empty or when the warning query fails.
- This issue should not add user controls. Until issue `#138`, warning overlay composition is effectively default-on whenever the query succeeds.

### 2. Relevant feature-brief sections used
- `Map Scene Composition`
  - Warning overlays compose above every selected thematic layer.
  - Warning geometry is baseline context, not a mutually exclusive map layer.
  - Warning overlays should append last or otherwise render above thematic overlays.
  - Layer warming, scene caching, and overlay revision/signature behavior should be preserved where practical.
  - Warning query failures should not prevent unrelated thematic layers from rendering.
- `Map Overlay Mapping`
  - Warning polygon/multipolygon conversion and deterministic warning overlay identity already exist from issue `#135`.
  - Revised geometry should change overlay identity or signature so stale polygons are replaced.
  - Non-warning overlay key/signature behavior must remain unchanged.
- `Active Warning Geometry Query`
  - Query active supported warnings from the existing repository/provider boundary.
  - Keep the query network-free and sourced from SwiftData-backed alert state.
- `Architecture Direction`
  - Keep warning geometry on the Arcus alert path and render from DTO/render-ready values, not raw SwiftData models.
  - Preserve the current map layer architecture unless current seams are insufficient.
- `Explicitly Out of Scope for V1`
  - No tap/select behavior, warning detail routing, overlap resolution, watch geometry, meso behavior changes, historical geometry rendering, notification changes, or broad GIS/map-layer frameworks.

### 3. Existing map/rendering seams discovered
- `MapScreenView` owns `MapFeatureModel` and currently calls `model.reload(using: dependencies.spcMapData, selectedLayer:)` from `onAppear` and active scene-phase refreshes.
- `MapFeatureModel.performReload(using:)` concurrently fetches severe, categorical, meso, and fire map products, converts failures to empty thematic payloads, then asks `MapScenePlanner` to build one render plan per `MapLayer`.
- `MapScenePlanner.buildRenderPlans(payload:polygonMapper:)` builds all layer plans up front; `MapFeatureModel` then materializes the selected layer immediately and warms the remaining layers from the already-built plans.
- `MapRenderPlanBuilder.build(layer:payload:polygonMapper:)` maps the selected thematic layer into `MapPolygonEntry` values, creates `MapOverlayBuildPlan` values, and computes `overlayRevision` from plan keys and signatures.
- `MapSceneMaterializer.materialize(plan:initialCenterCoordinate:)` turns `MapOverlayBuildPlan` values into `MKOverlay`s in plan order.
- `MapCanvasView` registers and adds overlays in `state.overlays` order, compares `overlayRevision` to decide whether to sync, and reorders overlays if the final MKMapView order differs from desired key order.
- `MapCoordinator` caches overlays by stable key/signature and already renders plain `MKPolygon`s with warning-specific styling when the polygon title matches a supported warning event.
- `MapPolygonMapper.warningPolygons(from:)` already converts `ActiveWarningGeometry` into stable `warn|...` `MapPolygonEntry` values with geometry fingerprints.

### 4. Expected files to touch
- `Sources/Features/Map/MapFeatureModel.swift`
  - Add warning geometry to the reload payload.
  - Add warning overlay build-plan support and append warning plans last for every layer.
  - Add a warning query helper that treats non-cancellation failures as empty warning geometry.
- `Sources/Features/Map/MapScreenView.swift`
  - Pass the existing Arcus alert query provider into `MapFeatureModel.reload`.
- `Tests/UnitTests/MapFeatureModelTests.swift`
  - Add focused render-plan/order/failure tests and update existing test stubs for the new reload dependency.
- Possibly `Sources/App/Dependencies.swift`
  - Only if a protocol-typed `arcusAlerts: any ArcusAlertQuerying` accessor is needed for cleaner injection. Prefer using the existing `dependencies.arcusProvider` if it compiles cleanly.

### 5. Smallest safe implementation plan
1. Extend `MapFeatureModel.reload`/`performReload` to accept an `any ArcusAlertQuerying` warning source in addition to `any SpcMapData`.
2. Add a fifth concurrent fetch in `performReload` for `getActiveWarningGeometries(on: .now)` or the default extension method.
3. Treat warning cancellation like other map fetch cancellation: if the warning task is canceled, exit the reload without partially applying stale work.
4. Treat non-cancellation warning query failures as `[]`, log through `Logger.uiMap`, and continue building thematic scenes from the SPC results.
5. Add `activeWarnings: [ActiveWarningGeometry]` to `MapDataPayload`.
6. In `MapRenderPlanBuilder.build`, call `polygonMapper.warningPolygons(from: payload.activeWarnings)` once per layer or pass precomputed warning entries into the builder if that is cleaner.
7. Extend `MapOverlayBuildPlan.Kind` with a warning case and materialize warning plans as plain `MKPolygon` overlays so `MapCoordinator` uses the warning styling path added in issue `#136`.
8. Compose each layer plan as `thematicPolygonEntries + warningPolygonEntries` and `thematicOverlayPlans + warningOverlayPlans`, with warning overlay plans appended last.
9. Keep existing thematic key/signature generation intact. Warning overlay keys should come from `MapPolygonMapper.warningPolygons(from:)`; warning signatures should participate in `overlayRevision(for:)` so adding/removing/revising warnings invalidates cached scene overlays.
10. Preserve existing scene warming/caching by keeping warning overlays inside the same per-layer `MapLayerRenderPlan` objects. When a reload receives different warning geometry, replacing `renderPlans` and clearing `cachedScenes` should naturally refresh selected and warmed scenes.

### 6. Risks/ambiguities
- Query timing: use `.now` at reload time unless implementation discovers an existing injected clock pattern nearby. Adding a broad clock abstraction for this issue would be overreach.
- Dependency injection: `MapScreenView` can likely pass `dependencies.arcusProvider`, because it conforms to `ArcusAlertQuerying`. If that causes type or actor-isolation friction, add the smallest protocol accessor on `Dependencies`.
- Cancellation semantics need care. A canceled warning query should not be silently treated as empty because that could apply a scene during teardown or superseded reload work.
- Warning overlay identity already includes geometry fingerprints in the key. The implementation should avoid adding a second, conflicting identity system. Let the existing key/signature/revision flow do its job.
- `MapFeatureModelTests.overlayTitles(in:)` currently only reads `RiskPolygonOverlay` titles. Warning overlays will be plain `MKPolygon`s, so tests that inspect order should account for both overlay types.
- The current materializer is private inside `MapFeatureModel.swift`. If tests need deeper render-plan assertions, prefer testing through `model.activeScene` before exposing internals.

### 7. Tests/checks to add or run
- Add `MapFeatureModelTests.reload_composesWarningOverlaysAboveSelectedLayer`:
  - Stub one thematic polygon and one warning geometry.
  - Verify overlay order places the warning key/title after the thematic overlay.
- Add `MapFeatureModelTests.reload_composesWarningOverlaysForEveryLayer`:
  - After one reload, select categorical, wind, hail, tornado, meso, and fire.
  - Verify each scene includes warning overlays appended after that layer's thematic overlays.
- Add `MapFeatureModelTests.reload_warningQueryFailurePreservesThematicLayers`:
  - Warning source throws a non-cancellation error.
  - Verify selected thematic overlays still render and no warning overlays are present.
- Add `MapFeatureModelTests.reload_warningGeometryChangesUpdateOverlayRevision`:
  - Reload once with one warning geometry, reload again with changed warning geometry.
  - Verify warning keys/revision change so stale polygons are replaced.
- Add or adapt a cancellation test only if the new fifth task makes existing cancellation behavior ambiguous.
- Run focused tests:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/MapFeatureModelTests test`
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/MapPolygonMapperTests -only-testing:SkyAwareTests/RiskPolygonOverlayTests test`
- Run a build if implementation touches protocol/dependency surfaces:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' build`

### 8. Explicit out-of-scope items
- Picker toggle UI or visibility preference persistence.
- Legend polish or warning legend entries.
- Alert detail routing.
- Tap/select behavior for warning polygons.
- Overlap resolution.
- Notification behavior, APNs payloads, targeting policy, or background refresh policy.
- Watch polygon rendering.
- Meso rendering or meso layer behavior changes.
- Historical/revision-level geometry rendering.
- Broad map architecture, GIS, or preference framework changes.

### 9. Recommendation for implementation model/intelligence
- Use a high-reasoning implementation pass. The code change is probably small, but the failure/cancellation/cache/order interactions are easy to get subtly wrong.
- `swift-concurrency-expert` should be used for implementation review because this issue adds an async SwiftData-backed query into a `@MainActor` feature model and coordinates it with concurrent SPC fetches.
- `build-ios-apps:swiftui-ui-patterns` should be used lightly because `MapScreenView` dependency injection and lifecycle-triggered reloads are SwiftUI state/lifecycle seams, even though this issue should not alter visible UI.
- Avoid broad delegation for implementation. If using a helper agent, keep it to one narrow read-only check such as "verify render-plan order and cache behavior after the patch."

---

## Issue #138 - Add Default-On Warning Geometry Toggle to Map Picker

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - `Warning Geometry Toggle` by adding the user-facing picker control with default-on behavior.
  - `Map Scene Composition` by threading the toggle state into map scene materialization and cache invalidation.
  - `Product Intent` by preserving the selected thematic layer while letting warning geometry hide/show independently.
  - `Explicitly Out of Scope for V1` by keeping the work render-only and avoiding interaction, overlap, or separate layer changes.
- Issue requirements completed:
  - Added a default-on warning geometry toggle to the existing map picker surface.
  - Persisted the preference with the app's existing lightweight `@AppStorage` pattern.
  - Threaded warning visibility into `MapFeatureModel` scene composition.
  - Hid warning polygons without changing the selected thematic layer.
  - Restored warning polygons from the existing cached/rendered scene state when toggled back on.
  - Preserved alert data, lifecycle state, network refresh behavior, and current thematic layer selection.

### Key implementation notes
- Added `showsWarningGeometry` as persisted view state on `MapScreenView` using `@AppStorage("mapWarningGeometryVisible", store: UserDefaults.shared)`.
- Threaded the binding into `LayerPickerSheet` so the control stays in the existing picker surface rather than creating a separate settings path.
- Added `MapFeatureModel.setWarningGeometryVisible(_:)` to invalidate cached scenes and re-materialize the selected layer with the current warning-visibility state.
- Computed overlay revision from the rendered overlay list so toggling warnings forces `MapCanvasView` to sync without refetching data.
- Kept the toggle local to rendering and scene composition; no alert records, geometry payloads, or network fetches were changed.
- `build-ios-apps:swiftui-ui-patterns` applied because this is a SwiftUI `@Binding`/sheet/picker state-flow change.
- `swift-concurrency-expert` applied lightly because `MapFeatureModel` is `@MainActor` and this change threads UI state through an async reload path without altering isolation.

### Files expected to change
- `Sources/Features/Map/Picker.swift`
- `Sources/Features/Map/MapScreenView.swift`
- Possibly `Sources/Features/Map/MapFeatureModel.swift`
- Tests under `Tests/UnitTests` or focused UI smoke coverage

### Files changed
- `Sources/Features/Map/Picker.swift`
- `Sources/Features/Map/MapScreenView.swift`
- `Sources/Features/Map/MapFeatureModel.swift`
- `Tests/UnitTests/MapFeatureModelTests.swift`

### Verification target
- Warning geometry defaults on.
- Toggle off removes warning polygons without changing the selected thematic layer.
- Toggle on restores warning polygons from cached/rendered state.

### Tests
- Added:
  - `MapFeatureModelTests.warningGeometryToggle_hidesAndRestoresOverlays`

### Verification
- Ran:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iPhone Simulator,name=iPhone 17" -only-testing:SkyAwareTests/MapFeatureModelTests test`
- Result:
  - Passed

### Out of scope / intentionally deferred
- Alert detail interactions
- Overlap controls
- Separate warning layer tile

### Handoff to next issue
- Issue `#139` should assume the toggle already exists and controls only rendering.
- Keep offline validation focused on SwiftData-backed active geometry, lifecycle filtering, and hide/show behavior.

---

## Issue #139 - Validate Offline Warning Geometry Rendering from SwiftData

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - `Offline Rendering and Validation` by tightening test coverage around offline warning-only rendering and lifecycle filtering.
  - `Active Warning Geometry Query` by proving local-time and lifecycle exclusion rules on SwiftData-backed warning geometry reads.
  - `Warning Geometry Toggle` by validating hide/show behavior against offline-rendered warning polygons.
  - `App Persistence` by validating the query returns the latest geometry persisted in SwiftData.
- Issue requirements completed:
  - Added query-side validation for inactive lifecycle exclusions including future-effective and superseded warnings.
  - Added query-side validation that the latest stored warning geometry is what is returned for rendering.
  - Added map composition validation that warning-only overlays render from fake cached warning geometry and respond correctly to the toggle.
  - Kept validation and implementation scoped to warning geometry behavior; no network, notification, or background policy changes.

### Key implementation notes
- `WatchRepo.activeWarningGeometries(on:)` remains the SwiftData-backed filter seam for offline warning rendering.
- Local lifecycle filtering now has explicit test coverage for:
  - expired time windows
  - canceled/cancelled message/status semantics
  - non-active/superseded status
  - not-yet-effective warnings
- Added an explicit test proving map composition can render from warning query data with no thematic overlays and that the warning toggle hides/shows those offline-rendered polygons.
- `swift-concurrency-expert` applied lightly: this issue touches `@ModelActor` query behavior and async query consumption, but no actor-isolation changes were required.
- `build-ios-apps:swiftui-ui-patterns` applied lightly: this issue validates existing map/toggle composition behavior without introducing new SwiftUI structure.

### Files changed
- `Tests/UnitTests/WatchRepoActiveTests.swift`
- `Tests/UnitTests/MapFeatureModelTests.swift`
- `docs/plans/FB-013-progress.md`

### Tests
- Added:
  - `WatchRepoActiveTests.activeWarningGeometries_returnsLatestStoredGeometry`
  - `MapFeatureModelTests.offlineWarningGeometry_rendersAndToggles`
- Updated:
  - `WatchRepoActiveTests.activeWarningGeometries_excludesInactiveLifecycle` (expanded lifecycle/time coverage)

### Verification
- Ran:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/WatchRepoActiveTests -only-testing:SkyAwareTests/MapFeatureModelTests test`
- Result:
  - Passed
- Test artifact:
  - `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.04.24_16-08-28--0600.xcresult`

### Focused manual validation path
1. Launch app with network/server reachable; navigate to a location with an active Tornado/Severe Thunderstorm/Flash Flood Warning and confirm warning polygon appears.
2. Kill app.
3. Disable connectivity to Arcus/SPC endpoints (for example: airplane mode or local network off plus backend unavailable).
4. Relaunch app at the same location and open map.
5. Confirm active warning polygon still renders from local cache.
6. In the map picker, toggle `Show Active Alerts` off and confirm warning polygon hides.
7. Toggle `Show Active Alerts` on and confirm the same warning polygon reappears.
8. Repeat with a warning that has expired or been canceled/superseded, then relaunch offline and confirm no warning polygon renders.

### Out of scope / intentionally deferred
- URLCache-specific warning geometry implementation
- Notification behavior changes
- New background refresh policy
- Broad unrelated map regression work

### Handoff to next issue
- FB-013 planned issue sequence is now complete through `#139`.
- Any remaining gaps should be tracked as follow-up issues rather than broadening this slice.

---

## FB-013 Final Review Finding - Stale Warning Geometry after Cancellation/Supersession

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - `App Persistence` by reconciling terminal Arcus lifecycle payloads onto existing local rows instead of dropping them pre-upsert.
  - `Active Warning Geometry Query` by preserving its defensive lifecycle filtering while ensuring persisted lifecycle state is current.
  - `Offline Rendering and Validation` by clearing stored geometry when alerts transition to cancelled/superseded/expired lifecycle states.
  - `Explicitly Out of Scope for V1` by keeping map styling/composition, notification policy, and refresh orchestration unchanged.
- Finding requirements completed:
  - Split ingestion into renderable upsert path and terminal lifecycle reconciliation path in `WatchRepo`.
  - Terminal payloads now update existing rows (when present), update lifecycle/revision/timing fields when available, clear geometry, and save.
  - Unseen terminal payloads are ignored and do not create rows.
  - `activeWarningGeometries(on:)` remains a defensive filter, but is no longer the only safeguard against stale terminal geometry.
  - `active()` now excludes non-renderable lifecycle rows so terminal reconciliations do not leak into active alert list projections.

### Key implementation notes
- Canonical identity remains unchanged: `Watch.nwsId == ArcusAlertIdentifier.canonical(item.id)`.
- Reconciliation is implemented at the ingestion boundary (`WatchRepo.refresh` and `refreshAlert`) rather than map query logic.
- Terminal lifecycle rules are explicit and conservative:
  - cancellation message types (`cancel`, `cancelled`)
  - terminal states (`superseded`, `expired`, `canceled`, `cancelled`)
- Geometry removal is implemented as row update (`existing.geometry = nil`) rather than deletion.

### Files changed
- `Sources/Repos/WatchRepo.swift`
- `Tests/UnitTests/WatchRepoRefreshTests.swift`
- `Tests/UnitTests/WatchRepoActiveTests.swift`
- `docs/plans/FB-013-progress.md`

### Tests
- Added:
  - `WatchRepoRefreshTests.refresh_reconcilesCancelledPayloads`
  - `WatchRepoRefreshTests.refresh_reconcilesSupersededPayloads`
  - `WatchRepoRefreshTests.refresh_reconcilesExpiredPayloads`
  - `WatchRepoRefreshTests.refresh_ignoresUnseenTerminalPayload`
  - `WatchRepoActiveTests.active_excludesTerminalLifecycleRows`

### Verification
- Ran:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:SkyAwareTests/WatchRepoRefreshTests -only-testing:SkyAwareTests/WatchRepoActiveTests test`
- Result:
  - Passed
- Test artifact:
  - `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.04.24_16-48-13--0600.xcresult`

### Out of scope / intentionally deferred
- Map overlay mapping/styling/composition behavior changes
- Notification policy changes
- New background refresh behavior
- Row deletion strategy changes

### Remaining risk
- If Arcus introduces new terminal lifecycle strings beyond the explicit set, they will remain non-terminal until added to the lifecycle helper. Existing defensive query filtering still limits rendering risk for unsupported non-active values.

---

## Progress Entry Template

Use this shape when completing each issue:

```markdown
## Issue #NNN - Issue Title

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - ...
- Issue requirements completed:
  - ...

### Key implementation notes
- ...

### Files changed
- ...

### Tests
- Added:
  - ...
- Updated:
  - ...

### Verification
- How to verify:
  1. ...
- Expected result:
  - ...

### Out of scope / intentionally deferred
- ...

### Risks or follow-ups
- ...

### Handoff to next issue
- The next issue should assume:
  - ...
- Watch out for:
  - ...
- Recommended next step:
  - ...
```
