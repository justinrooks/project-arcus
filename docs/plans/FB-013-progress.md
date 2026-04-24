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
- Remaining Project Arcus child issues are still pending and should continue in sequence from `#134`.

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
- Not started

### Scope planned
- Add a focused query that returns active supported warnings with geometry from SwiftData.

### Key implementation notes
- Include only:
  - Tornado Warning
  - Severe Thunderstorm Warning
  - Flash Flood Warning
- Exclude watches, mesos, unsupported alert types, non-active alerts, and nil geometry.
- Use local active rules based on status/message type and current time window.

### Files expected to change
- `Sources/Interfaces/Arcus/ArcusAlertQuerying.swift`
- `Sources/Providers/ArcusAlertProvider.swift`
- `Sources/Repos/WatchRepo.swift`
- Tests under `Tests/UnitTests`

### Verification target
- Query returns only active supported warning geometries.
- Query works without network access.
- Result shape is sufficient for map overlay rendering.

### Out of scope / intentionally deferred
- Map overlay construction
- Network fetch behavior changes

### Handoff to next issue
- The map overlay conversion issue should consume this focused query result rather than reaching into network or raw persistence details.

---

## Issue #135 - Convert Active Warning Geometry into Stable Map Overlays

### Status
- Not started

### Scope planned
- Convert active warning polygon and multipolygon geometry into stable map overlay entries.

### Key implementation notes
- Generate deterministic keys from alert id, revision identifier or sent date, event type, polygon index, and polygon fingerprint.
- Support exterior rings for v1.
- Preserve existing overlay key/signature behavior.
- Do not add tap/select behavior.

### Files expected to change
- `Sources/Features/Map/MapPolygonMapper.swift`
- Possibly `Sources/Features/Map/RiskPolygonOverlay.swift`
- `Tests/UnitTests/MapPolygonMapperTests.swift`

### Verification target
- Polygon and multipolygon warning geometry map to stable overlay entries.
- Revised geometry changes identity/signature enough to replace stale overlays.
- Existing SPC/fire/meso mapping still works.

### Out of scope / intentionally deferred
- Final warning styling
- Toggle UI
- Tap/select behavior
- Overlap resolution

### Handoff to next issue
- Warning styling should be able to rely on stable overlay metadata or typed warning overlay entries.

---

## Issue #136 - Add Warning-Specific Map Polygon Styling

### Status
- Not started

### Scope planned
- Add warning-specific stroke/fill treatments for supported warning types.

### Key implementation notes
- Tornado Warning uses existing `tornadoRed`.
- Severe Thunderstorm Warning uses a yellow warning treatment.
- Flash Flood Warning uses a dedicated blue/flood treatment.
- Stroke should be stronger than fill.
- Fill should stay light and translucent.
- Do not overload SPC probability styling with warning semantics.

### Files expected to change
- `Sources/Utilities/Core/AlertStyling.swift`
- `Sources/Utilities/Extensions/ext+Color.swift`
- `Sources/Features/Map/PolygonStyleProvider.swift` or a new focused warning style helper
- `Sources/Features/Map/RiskPolygonOverlay.swift`
- `Sources/Features/Map/RiskPolygonRenderer.swift`
- Tests under `Tests/UnitTests`

### Verification target
- Each supported warning type maps to a distinct deterministic style.
- Existing SPC/fire/meso styles are not regressed.

### Out of scope / intentionally deferred
- Overlap resolution
- Legend polish
- Tap/select behavior

### Handoff to next issue
- Map composition should be able to append warning overlays with finalized visual treatment above thematic layers.

---

## Issue #137 - Compose Warning Overlays above Every Map Layer

### Status
- Not started

### Scope planned
- Compose warning overlays above every selected thematic map layer.

### Key implementation notes
- Warning geometry is a baseline overlay, not a new exclusive map layer.
- Append warning overlays last so they render above thematic overlays.
- Preserve layer warming and cached scene behavior where practical.
- Query warning geometry from SwiftData-backed alert state.
- Warning query failures should not break unrelated map layers.

### Files expected to change
- `Sources/Features/Map/MapFeatureModel.swift`
- `Sources/Features/Map/MapScreenView.swift`
- Map scene planning/materialization code in `Sources/Features/Map`
- Tests under `Tests/UnitTests`

### Verification target
- Warning polygons can render over categorical, wind, hail, tornado, meso, and fire layers.
- Warning overlays render above existing overlays.
- Existing map layers still render without warnings.

### Out of scope / intentionally deferred
- Picker toggle UI
- Legend polish
- Alert detail routing
- Overlap resolution

### Handoff to next issue
- Toggle work should only control whether composed warning overlays are included, not how alert geometry is fetched or persisted.

---

## Issue #138 - Add Default-On Warning Geometry Toggle to Map Picker

### Status
- Not started

### Scope planned
- Add a default-on map picker control for showing or hiding warning geometry.

### Key implementation notes
- Place the toggle in the existing map picker or selector surface.
- Toggle rendering only.
- Do not mutate SwiftData alert records.
- Preserve existing thematic layer selection behavior.
- Persist preference only if an existing lightweight preference pattern makes that straightforward.

### Files expected to change
- `Sources/Features/Map/Picker.swift`
- `Sources/Features/Map/MapScreenView.swift`
- Possibly `Sources/Features/Map/MapFeatureModel.swift`
- Tests under `Tests/UnitTests` or focused UI smoke coverage

### Verification target
- Warning geometry defaults on.
- Toggle off removes warning polygons without changing the selected thematic layer.
- Toggle on restores warning polygons from cached/rendered state.

### Out of scope / intentionally deferred
- Alert detail interactions
- Overlap controls
- Separate warning layer tile

### Handoff to next issue
- Offline validation should verify toggle behavior works with warning overlays rendered from SwiftData without network access.

---

## Issue #139 - Validate Offline Warning Geometry Rendering from SwiftData

### Status
- Not started

### Scope planned
- Validate that active warning geometry renders from SwiftData while the app is offline.

### Key implementation notes
- SwiftData is the cache source for warning geometry.
- Validate active filtering with local time and status rules.
- Expired or canceled alerts should not render offline even if geometry exists locally.
- Keep validation focused on warning geometry behavior.

### Files expected to change
- Tests under `Tests/UnitTests`
- Possibly small test seams in map/query code if required
- `docs/plans/FB-013-progress.md`

### Verification target
- Active warning with stored geometry renders offline.
- Expired warning with stored geometry does not render offline.
- Canceled or non-active warning with stored geometry does not render offline.
- Toggle still hides and shows offline-rendered warning geometry.

### Out of scope / intentionally deferred
- URLCache-specific warning geometry implementation
- Notification behavior changes
- New background refresh policy
- Broad unrelated map regression work

### Handoff to next issue
- This is the final planned FB-013 implementation issue. Any remaining gaps should be recorded here as follow-up issues rather than silently expanding scope.

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
