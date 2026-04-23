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
- No implementation work has started yet.

---

## Issue #132 - Add Shared Nullable Geometry to DeviceAlertPayload

### Status
- Not started

### Scope planned
- Add nullable warning geometry to the shared app/server `DeviceAlertPayload` contract.
- Preserve decode compatibility for payloads without geometry.
- Support polygon and multipolygon transport.
- Document nil geometry as no renderable warning polygon.

### Key implementation notes
- App payload model currently lives at `Sources/Models/Watches/DeviceAlertPayload.swift`.
- Server payload model currently lives at `/Users/justin/Code/arcus-signal/Sources/App/Models/Device/DeviceAlertPayload.swift`.
- Server canonical geometry semantics already exist as `GeoShape` in `/Users/justin/Code/arcus-signal/Sources/App/Models/NWS/ArcusEvent.swift`.
- This issue should avoid rendering, SwiftData persistence, and notification changes.

### Files expected to change
- `Sources/Models/Watches/DeviceAlertPayload.swift`
- Possibly `/Users/justin/Code/arcus-signal/Sources/App/Models/Device/DeviceAlertPayload.swift`
- Tests under `Tests/UnitTests`

### Verification target
- Payload decode tests prove missing, polygon, and multipolygon geometry behavior.
- Existing alert payload decoding remains compatible.

### Out of scope / intentionally deferred
- Server endpoint exposure
- SwiftData persistence
- Map rendering
- Toggle UI

### Handoff to next issue
- The next issue should assume the shared payload contract has a nullable geometry property with nil-as-no-polygon semantics.

---

## Issue arcus-signal#48 - Expose Latest Series Geometry in DeviceAlertPayload

### Status
- Not started

### Scope planned
- Include latest available current-series geometry in `/api/v1/alerts` responses.
- Source geometry from `arcus_geolocation.geometry`.
- Preserve existing `h3Cells` and notification behavior.

### Key implementation notes
- This issue lives in `/Users/justin/Code/arcus-signal`.
- Read the Arcus Signal `AGENTS.md`, `docs/architecture.md`, and `docs/epics-stories.md` before implementing.
- Do not use deprecated `arcus_series.geometry`.
- Do not add revision-level geometry persistence.

### Files expected to change
- `/Users/justin/Code/arcus-signal/Sources/App/Models/Device/DeviceAlertPayload.swift`
- `/Users/justin/Code/arcus-signal/Sources/App/Models/API/AlertSeriesRow.swift`
- `/Users/justin/Code/arcus-signal/Sources/App/Models/NWS/ArcusSeriesModel.swift`
- `/Users/justin/Code/arcus-signal/Sources/App/Controllers/AlertsController.swift`
- Server tests under `/Users/justin/Code/arcus-signal/Tests/AppTests`

### Verification target
- `/api/v1/alerts` payloads include geometry when joined geolocation has geometry.
- Payloads omit or null geometry when none exists.
- Existing notification behavior remains unchanged.

### Out of scope / intentionally deferred
- Historical/revision geometry persistence
- APNs custom payload changes
- Targeting policy changes
- App rendering

### Handoff to next issue
- The app persistence issue should assume Arcus payloads can include nullable latest series geometry.

---

## Issue #133 - Persist Warning Geometry from Arcus Payloads into SwiftData

### Status
- Not started

### Scope planned
- Decode warning geometry from Arcus alert payloads.
- Persist optional geometry on the existing SwiftData alert model.
- Surface geometry through `WatchRowDTO`.

### Key implementation notes
- Keep the `Watch` model name for this feature even though it carries warnings.
- Geometry should be optional/defaulted for migration safety.
- Preserve existing UGC/H3 matching and alert UI behavior.

### Files expected to change
- `Sources/Models/Watches/Watch.swift`
- `Sources/Models/Watches/WatchRowDTO.swift`
- `Sources/Repos/WatchRepo.swift`
- `Tests/UnitTests/DeviceAlertPayloadTests.swift`
- `Tests/UnitTests/WatchRepoRefreshTests.swift`
- `Tests/UnitTests/WatchRepoActiveTests.swift`

### Verification target
- Missing geometry still decodes and persists normally.
- Polygon and multipolygon geometry persist.
- Updated geometry replaces stored geometry.
- Existing active alert matching still works.

### Out of scope / intentionally deferred
- Map rendering
- UI controls
- Model renaming

### Handoff to next issue
- The active warning geometry query should read persisted geometry from SwiftData-backed alert state.

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
