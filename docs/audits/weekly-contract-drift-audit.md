# Weekly Contract Drift Audit

## 2026-05-20
- Repos scanned: SkyAware, arcus-signal, ArcusCore
- Commit window: SkyAware `b5d15fe..HEAD` (recent history reviewed via `git log -n 20`), arcus-signal `ebbfd07..HEAD` (recent history reviewed via `git log -n 20`), ArcusCore `85c3d20..HEAD`
- Contract surfaces inspected: device registration/location snapshot payloads, alert/device DTOs, APNs payload keys and client handlers, revision/timestamp mapping
- Top finding: APNs payload contract drift between arcus-signal and SkyAware remote hot-alert ingestion
- Recommended fix: Add explicit APNs custom payload fields (`alertID` or `seriesId`, plus `revisionSent`) and define/share payload contract in ArcusCore
- Watchlist items: None
- Implementation recommended: Yes
- Status: Resolved on 2026-05-21
- Resolution notes:
  - Canonical APNs hot-alert identifier is now `arcusAlertId` (Arcus graph series id).
  - Compatibility aliases are still emitted/accepted: `alertID` and `seriesId`.
  - Decode precedence is `arcusAlertId` -> `alertID` -> `seriesId`.
  - `revisionSent` remains part of the payload contract.
  - ArcusCore contract tests and app/server focused validations were updated and passed.

## 2026-05-25
- Repos scanned: SkyAware (`/Users/justin/Code/project-arcus`), arcus-signal (`/Users/justin/Code/arcus-signal`), ArcusCore (`/Users/justin/Code/ArcusCore`)
- Commit window: SkyAware `9c08b13..58272f4`, arcus-signal `4469c10..c4232cc`, ArcusCore `18f7861..618bf3d`
- Contract surfaces inspected: APNs hot-alert payload keys/types, targeted alert fetch query contract (`id`/`sent`), alert DTO revision fields, location snapshot payload enums/optionality
- Top finding: `revisionSent` date format drift in APNs hot-alert payload encoding path (server emits default `Date` encoding while shared/client contract expects ISO-8601)
- Recommended fix: Configure APNs request encoders in `arcus-signal` to `dateEncodingStrategy = .iso8601` for both sandbox and production containers so `HotAlertAPNsPayload.revisionSent` matches ArcusCore/SkyAware decode contract
- Watchlist items: `GET /api/v2/alerts?sent=` is currently accepted and intentionally ignored; keep docs and client assumptions aligned
- Implementation recommended: Yes

## 2026-06-01
- Repos scanned: SkyAware (`/Users/justin/Code/project-arcus`), arcus-signal (`/Users/justin/Code/arcus-signal`), ArcusCore (`/Users/justin/Code/ArcusCore`)
- Commit window: SkyAware `94db622..36ce30a` (since 2026-05-25), arcus-signal `2c01033..9d1caca`, ArcusCore `83b5cec..ebd690e`
- Contract surfaces inspected: device registration/location snapshot payloads, device preference sync payload/response, location source enums and DB constraints, endpoint contract docs
- Top finding: `POST /api/v1/devices/location-snapshots` docs advertise a stale `source` enum set that no longer matches app/shared model emissions or server DB acceptance
- Recommended fix: Update `arcus-signal/docs/api-endpoints.md` `source` enum documentation to include expanded values (`foregroundPrime`, `foregroundActivate`, `foregroundLocationChange`, `manualRefresh`, `backgroundLocationChange`, `onboarding`, `settingsPreference`) and note backward compatibility with legacy values
- Watchlist items: Device preference sync response date decoding still relies on ISO-8601 assumptions across Vapor/client; add explicit contract test if this endpoint is consumed beyond best-effort decode
- Implementation recommended: Yes (documentation contract correction)

## 2026-06-08
- Audit mode: Cross-repo orchestration mode
- Repos scanned: SkyAware (`/Users/justin/Code/project-arcus`), arcus-signal (`/Users/justin/Code/arcus-signal`), ArcusCore (`/Users/justin/Code/ArcusCore`)
- Commit window:
  - SkyAware `36ce30a..4bea901` (`384fcb0`, `47e074c`, `ab86f7e`, `4bea901`)
  - arcus-signal `9d1caca..12a69c1` (`49ece86` through `12a69c1`)
  - ArcusCore `ebd690e..HEAD` (no commits; current shared contracts inspected as reference)
- Contract surfaces inspected: APNs hot-alert payload keys/date encoding, targeted alert lookup query contract, location snapshot source enum/documentation, device presence persistence and source constraints, new Storm Setup route/response DTOs, alert payload builders, Meso DTO legacy decode compatibility
- Files inspected:
  - SkyAware: `Sources/App/RemoteHotAlertHandler.swift`, `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`, `Sources/Clients/ArcusClient.swift`, `Sources/Models/Meso/MdDTO.swift`, `Tests/UnitTests/MdDTOCodableCompatibilityTests.swift`, `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`, `Sources/Infrastructure/Location/HTTPLocationSnapshotUploader.swift`, `Sources/Infrastructure/Location/HTTPDevicePreferenceSyncUploader.swift`
  - arcus-signal: `Sources/App/configure.swift`, `Sources/App/Jobs/NotificationSendJob.swift`, `Sources/App/Clients/APNsClient.swift`, `Sources/App/Controllers/DeviceController.swift`, `Sources/App/Controllers/StormSetupController.swift`, `Sources/App/StormSetup/StormSetupModels.swift`, `Sources/App/Models/Device/DevicePresenceModel.swift`, `Sources/App/Migrations/UpdateDevicePresenceSourceConstraintForExpandedLocationUploadSources.swift`, `Sources/App/Controllers/AlertsController.swift`, `Sources/App/Models/API/AlertSeriesRow.swift`, `Sources/App/Models/NWS/ArcusSeriesModel.swift`, `docs/api-endpoints.md`
  - ArcusCore: `Sources/ArcusCore/HotAlertAPNsPayload.swift`, `Sources/ArcusCore/DeviceAlertPayload.swift`, `Sources/ArcusCore/LocationSnapshotPushPayload.swift`, `Sources/ArcusCore/LocationUploadSource.swift`, `Sources/ArcusCore/DevicePreferenceSyncPayload.swift`, `Tests/ArcusCoreTests/ArcusCoreTests.swift`
- Top finding: APNs `HotAlertAPNsPayload.revisionSent` still has server encoder drift. New SkyAware evidence in `384fcb0` added numeric APNs date fallback tests (`Tests/UnitTests/RemoteHotAlertHandlerTests.swift`) while ArcusCore still defines ISO-8601 shared contract tests and arcus-signal still registers APNs containers with plain `JSONEncoder()` in `Sources/App/configure.swift`.
- Recommended fix: In arcus-signal, use an APNs request encoder configured with `dateEncodingStrategy = .iso8601` for both sandbox and production containers, then add an APNs payload encoding contract test around `HotAlertAPNsPayload`.
- Watchlist items:
  - New `GET /api/v1/storm-setup/current?h3=` returns `TornadoIngredientSnapshot`, but no SkyAware or ArcusCore consumer/shared contract was found. Promote only after client/shared model evidence exists or endpoint docs/specs declare a stable public contract.
  - `arcus-signal/docs/api-endpoints.md` still lists stale location snapshot `source` values; this is the unresolved 2026-06-01 documentation contract finding, not a new finding.
- Implementation recommended: Yes, for the APNs encoder contract fix.
- Resolution notes:
  - `arcus-signal` now uses a dedicated APNs request encoder with `dateEncodingStrategy = .iso8601` for both sandbox and production containers.
  - Added a focused App test that encodes `HotAlertAPNsPayload` through the shared APNs request encoder and verifies `revisionSent` emits ISO-8601.
  - This keeps `HotAlertAPNsPayload` aligned with the ArcusCore shared decode contract and removes the server-side date encoding drift.
