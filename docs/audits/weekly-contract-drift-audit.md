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

## 2026-06-15

### Audit mode
- Cross-repo orchestration mode.

### Repositories scanned
- SkyAware (`/Users/justin/Code/project-arcus`)
- arcus-signal (`/Users/justin/Code/arcus-signal`)
- ArcusCore (`/Users/justin/Code/ArcusCore`)

### Commit window inspected
- SkyAware: reliable prior marker `4bea901`; inspected commits dated 2026-06-09 through 2026-06-14 on the current `uiRefresh` branch through `3a5f738`, plus current uncommitted changes. The prior marker is not an ancestor of the current branch, so the date window and changed contract-relevant files were used rather than claiming a linear range.
- arcus-signal: `12a69c1..dd6e743` (2026-06-09 merge commit, including Storm Setup contract and interpreter changes).
- ArcusCore: `ebd690e..de86f50` (2026-06-09 test-only commit).

### Contract surfaces inspected
- Storm Setup response DTOs, assessment enums, interpretation rules, freshness fields, H3 cache keys, persisted snapshot encoding, and rules-version invalidation.
- Device location snapshot request source enum, server validation, database constraint, endpoint tests, shared enum Codable behavior, and endpoint documentation.
- APNs `HotAlertAPNsPayload` identifier/date encoding and SkyAware decoding.
- Remote-alert revision handling, targeted alert lookup, alert lifecycle ordering, location-context refresh authority, map warning-geometry stale/failure behavior, optional SPC metadata presentation, and device preference synchronization.

### Highest-risk areas
- Storm Setup cache invalidation because persisted assessments can outlive a deployment while interpretation semantics change.
- Location source enums because client fallback behavior, server validation, persistence constraints, and public API documentation must agree.
- APNs revision timestamps because date-format drift can break notification-driven alert refresh and deduplication.

### Findings

| Finding | Repositories | Contract surface | Contract direction | Evidence | Impact | Confidence | Minimal fix | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Storm Setup interpretation changes reuse the V1 persisted cache namespace | arcus-signal | Persistence schema/cache key → response builder | Persisted `TornadoIngredientSnapshot` → `GET /api/v1/storm-setup/current` | Commit `7905842` changed CAPE, CIN, shear, SRH, cloud-base, scoring, and limiting-factor thresholds in `Sources/App/StormSetup/TornadoIngredientInterpreter.swift`. `Sources/App/StormSetup/StormSetupRulesVersion.swift` still sets `current = .tornadoIngredientV1`. `DefaultStormSetupProvider.loadSnapshot` builds `StormSetupSnapshotCacheKey` with `.current`; `StormSetupSnapshotCache.loadSnapshot` returns a fresh matching record directly. `StormSetupSnapshotCacheTests.differentRulesVersionsMissTheCache` proves the rules version is the intended semantic invalidation boundary. | A deployment can return a pre-change V1 assessment calculated with obsolete thresholds while current code advertises the new semantics. This can overstate or understate tornado-ingredient support until the retained snapshot expires, normally within the 90-minute freshness window. Unfixed blast radius is the Storm Setup endpoint for H3/source combinations with persisted cache records. Proposed-change blast radius is limited to cache namespace invalidation and recomputation. | High | Change `StormSetupRulesVersion.current` to `.tornadoIngredientV2`; keep V1 decode support for old records. Expected files: `StormSetupRulesVersion.swift` and one focused cache/provider test. Estimated churn: under 20 lines. Regression risk: Low; first request after deployment recomputes affected snapshots. | Cache contract test: store a V1 snapshot, request using `.current`, and assert a miss after current becomes V2. Provider test: verify stale-version records are not returned. Manual: preserve a V1 cache directory across deploy and confirm a V2 path is written. |
| Location snapshot endpoint documentation omits accepted shared `source` values | SkyAware, arcus-signal, ArcusCore | Device presence/location freshness request enum | Shared model/app encoder → server validator/persistence/documentation | ArcusCore `LocationUploadSource` defines nine values and commit `de86f50` added `locationUploadSourceRoundTripsAllCasesThroughCodable`. SkyAware emits expanded values including `foregroundPrime`, `foregroundLocationChange`, `onboarding`, and `settingsPreference`. arcus-signal `DeviceController.create` validates with the shared enum; `UpdateDevicePresenceSourceConstraintForExpandedLocationUploadSources` permits the expanded set; `DeviceControllerTests.createPersistsExpandedSourceValues` proves `foregroundPrime` and `settingsPreference` persist. `docs/api-endpoints.md` still documents only `foreground|backgroundRefresh|significantChange|manual|unknown`. | Integrators following the endpoint contract may reject valid values locally, send legacy values, or incorrectly assume current app payloads receive `400`. Runtime app/server behavior currently aligns; the drift is in the published local contract. Unfixed blast radius is documentation consumers and fixtures. Proposed-change blast radius is documentation only. | High | Update only the `source` enum list in `arcus-signal/docs/api-endpoints.md`, retaining a note that legacy values remain accepted. | Documentation review against `LocationUploadSource.all cases`; optional contract test or generated-doc check that compares documented values with the shared enum. |

### Top recommended fix
- Bump `StormSetupRulesVersion.current` to `.tornadoIngredientV2`.
- This matters first because current code can serve cached severe-weather assessments calculated under obsolete interpretation thresholds.
- Expected files touched: `arcus-signal/Sources/App/StormSetup/StormSetupRulesVersion.swift` and `arcus-signal/Tests/AppTests/StormSetupSnapshotCacheTests.swift` or `StormSetupProviderTests.swift`.
- Estimated churn: under 20 lines.
- Regression risk: Low; the operational cost is a one-time cache miss and recomputation per active key.

### Watchlist
- SkyAware `HomeRefreshPipeline` commit `fefe943` can advance `lastResolvedLocationScopedRefreshKey` after a prime refresh while intentionally withholding that prime snapshot from visible state. This may allow prior-context pipeline values to be treated as current until the follow-up commits. Keep as app-local watchlist, not confirmed cross-repo drift. Promote with a deterministic test showing a changed H3 context renders the previous context's severe-weather data as resolved.
- SkyAware `MapFeatureModel` commit `b27e62b` maps active-warning query failure to an empty warning list while preserving stale thematic layers. This may remove saved warning geometry during transient query failure. Keep as app-local watchlist. Promote with a test proving previously rendered warning geometry disappears after a failed warning refresh and a documented requirement that warning geometry must retain stale state.
- Alert Center orders alerts by `ends`, while Summary surfaces order by `expires`. Keep as lifecycle-semantics watchlist until a product rule or fixture with differing `expires` and `ends` establishes which field is authoritative for presentation ordering.
- `GET /api/v1/storm-setup/current?h3=` still has no SkyAware consumer or ArcusCore shared DTO. Promote any response-shape concern only when a client decoder/shared contract exists.
- APNs ISO-8601 drift is resolved: arcus-signal now uses `makeAPNSRequestEncoder()` for sandbox and production, ArcusCore tests the ISO-8601 wire contract, and SkyAware decodes it with `.iso8601`.

### Files inspected
- SkyAware: `Sources/App/HomeRefreshPipeline.swift`, `Sources/App/HomeView.swift`, `Sources/App/RemoteHotAlertHandler.swift`, `Sources/Clients/ArcusClient.swift`, `Sources/Features/Alert/AlertPresentationOrdering.swift`, `Sources/Features/Alert/AlertView.swift`, `Sources/Features/Summary/ActiveAlertSummaryView.swift`, `Sources/Features/Map/MapFeatureModel.swift`, `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`, `Tests/UnitTests/HomeRefreshPipelineTests.swift`, `Tests/UnitTests/MapFeatureModelTests.swift`, `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`, `Tests/UnitTests/LocationProviderTests.swift`.
- arcus-signal: `Sources/App/StormSetup/StormSetupRulesVersion.swift`, `StormSetupProvider.swift`, `StormSetupSnapshotCache.swift`, `StormSetupSnapshotCacheKey.swift`, `StormSetupModels.swift`, `TornadoIngredientAssessment.swift`, `TornadoIngredientInterpreter.swift`, `IngredientFreshness.swift`, `Sources/App/Controllers/StormSetupController.swift`, `Sources/App/Controllers/DeviceController.swift`, `Sources/App/Migrations/UpdateDevicePresenceSourceConstraintForExpandedLocationUploadSources.swift`, `Sources/App/configure.swift`, `Tests/AppTests/StormSetupSnapshotCacheTests.swift`, `StormSetupProviderTests.swift`, `StormSetupControllerTests.swift`, `DeviceControllerTests.swift`, `AppTests.swift`, `docs/api-endpoints.md`.
- ArcusCore: `Sources/ArcusCore/LocationUploadSource.swift`, `LocationSnapshotPushPayload.swift`, `DevicePreferenceSyncPayload.swift`, `HotAlertAPNsPayload.swift`, `Tests/ArcusCoreTests/ArcusCoreTests.swift`.

### Out-of-scope and recommendation status
- No repositories outside SkyAware, arcus-signal, and ArcusCore were inspected.
- No SkyAware/ArcusCore Storm Setup consumer contract exists, so that cross-repo response side was unavailable.
- Findings: 2 High, 0 Medium, 0 Low. Watchlist: 4 active concerns; APNs recorded as resolved.
- Implementation recommended: Yes, first for Storm Setup rules-version invalidation, then for the location-source documentation correction.
- No implementation, tests, branches, commits, pushes, PRs, or GitHub issues were created by this audit.

## 2026-06-22

### Audit mode
- Cross-repo orchestration mode.

### Repositories scanned
- SkyAware (`/Users/justin/Code/project-arcus`)
- arcus-signal (`/Users/justin/Code/arcus-signal`)
- ArcusCore (`/Users/justin/Code/ArcusCore`)

### Commit window inspected
- SkyAware: the prior `3a5f738` checkout marker is not an ancestor of current `main`; inspected contract-relevant commits dated after the 2026-06-15 automation run through `6e5327e` (`f4632e5` through `6e5327e`) rather than claiming a linear range.
- arcus-signal: `dd6e743..origin/main` contains no commits, so inspected the current default branch at `dd6e743` for the three highest-risk established surfaces: Storm Setup rules-version invalidation, device location-source contracts, and APNs revision payload encoding. The current `newIngredientParams` checkout (`d23f2c..ff40ad1`) was also inspected as unmerged supplemental evidence because it introduces Anvil/HRRR DTOs.
- ArcusCore: `de86f50..HEAD` contains no commits. The local checkout is one test-only commit ahead of `origin/main` (`ebd690e`); inspected current shared APNs and location contracts as reference for the same three high-risk surfaces.

### Contract surfaces inspected
- Storm Setup persisted snapshot cache keys, `StormSetupRulesVersion`, `TornadoIngredientSnapshot`, and newly added raw-parameter fields.
- New Anvil profile request/preview DTOs, H3 location fields, ISO-8601 dates, pressure-profile fixtures, route/controller, and request builder.
- Device location snapshot source enums across SkyAware upload call sites, ArcusCore shared types, arcus-signal validation/persistence, and endpoint documentation.
- APNs hot-alert identifiers, `revisionSent` encoding/decoding, targeted refresh handling, and ArcusCore package pins.
- Alert lifecycle `expires`/`ends` presentation and the new SkyAware cached/stale Local Alerts display-state flow.

### Highest-risk areas
- Storm Setup cache versioning remains safety-sensitive because persisted severe-weather assessments can survive a deployment.
- Anvil profile DTOs are a new server-side wire boundary carrying H3, pressure-level, and date/time semantics.
- APNs revision timestamps and location-source enums remain established multi-repository contracts with direct notification and freshness impact.

### Findings

| Finding | Repositories | Contract surface | Contract direction | Evidence | Impact | Confidence | Minimal fix | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| No new confirmed contract drift | SkyAware, arcus-signal, ArcusCore | Changed and highest-risk current contract surfaces | Producer ↔ consumer and shared model → app/server | Both sides were inspected for APNs and location payloads. New Anvil/HRRR DTOs exist only in the unmerged arcus-signal branch, so no second scoped contract side is available. Prior unresolved Storm Setup rules-version and location-source documentation findings have no materially new evidence and were not duplicated. | No newly evidenced runtime or user-visible contract break was established in this window. | — | No new contract fix recommended. Preserve the prior unresolved recommendations separately. | Continue focused encoding/decoding and cache-version contract tests when the Anvil consumer or shared model becomes available. |

### Top recommended fix
- No new contract fix recommended.
- The prior 2026-06-15 recommendations remain unresolved and unchanged: bump the Storm Setup rules version when interpretation semantics change, then correct the documented location upload source values. They are not re-added as new findings because this run found no new evidence, higher severity, or materially better fix.

### Watchlist
- arcus-signal commit `d23f2c` introduces `AnvilAnalyzeProfileRequest` with required `runTime`, `forecastHour`, `validTime`, `location`, and `profile` fields, plus an ISO-8601 fixture; `1367779` exposes the assembled request through a debug-only preview route. No Anvil consumer schema, generated client, SkyAware decoder, or ArcusCore shared model exists in the scoped repositories. Promote only after the producer-facing Anvil schema/decoder is available and field names, units, optionality, H3 representation, and date encoding can be compared directly.
- The unmerged arcus-signal branch adds optional `tempDewPtDeltaF` and `threeCapeJkg` fields to `TornadoRawParameters`. No SkyAware or ArcusCore Storm Setup consumer exists. Promote only if a scoped client/shared DTO appears and its decoder does not tolerate the additive fields or requires different names/units.
- SkyAware still presents alert ordering with `ends` in Alert Center and `expires` in Summary surfaces. No new lifecycle contract evidence resolved which timestamp is authoritative. Promote only with an explicit product contract or a fixture where the fields differ and the expected active/order behavior is specified.

### Files inspected
- SkyAware: `Sources/App/HomeRefreshPipeline.swift`, `Sources/App/RemoteHotAlertHandler.swift`, `Sources/Clients/ArcusClient.swift`, `Sources/Features/Alert/AlertPresentationOrdering.swift`, `Sources/Features/Alert/AlertView.swift`, `Sources/Features/Summary/ActiveAlertSummaryView.swift`, `Sources/Features/Summary/LocalAlertsDisplayState.swift`, `Sources/Features/Summary/TodayContentState.swift`, `Sources/Features/Summary/TodayVisibleWeatherState.swift`, `Sources/Infrastructure/Location/HTTPLocationSnapshotUploader.swift`, `Sources/Infrastructure/Location/LocationContextResolver.swift`, `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`, `Sources/Models/Watches/AlertDTO.swift`, and focused unit tests changed in the window.
- arcus-signal default branch: `Sources/App/configure.swift`, `Sources/App/Controllers/DeviceController.swift`, `Sources/App/StormSetup/StormSetupProvider.swift`, `Sources/App/StormSetup/StormSetupRulesVersion.swift`, `Sources/App/StormSetup/StormSetupSnapshotCache.swift`, `Tests/AppTests/AppTests.swift`, `Tests/AppTests/DeviceControllerTests.swift`, and `docs/api-endpoints.md`.
- arcus-signal unmerged supplemental branch: `Sources/App/Models/API/AnvilAnalyzeProfileRequest.swift`, `Sources/App/Models/API/AnvilAnalyzeProfilePreviewResponse.swift`, `Sources/App/Controllers/AnvilProfilePreviewController.swift`, `Sources/App/StormSetup/AnvilProfileRequestBuilder.swift`, `Sources/App/StormSetup/AnvilProfilePreviewProvider.swift`, `Sources/App/StormSetup/StormSetupModels.swift`, `Tests/AppTests/AnvilAnalyzeProfileDTOTests.swift`, and `Tests/AppTests/Fixtures/AnvilAnalyzeProfileRequest.json`.
- ArcusCore: `Sources/ArcusCore/HotAlertAPNsPayload.swift`, `Sources/ArcusCore/LocationSnapshotPushPayload.swift`, `Sources/ArcusCore/LocationUploadSource.swift`, and `Tests/ArcusCoreTests/ArcusCoreTests.swift`.

### Out-of-scope and recommendation status
- No repositories outside SkyAware, arcus-signal, and ArcusCore were inspected.
- The actual Anvil consumer contract is unavailable in the scoped repositories; no cross-repo claim was made for that boundary.
- Findings: 0 High, 0 Medium, 0 Low. The table records the no-new-drift outcome rather than a counted finding. Watchlist: 3.
- No new implementation is recommended from this run. Prior unresolved recommendations remain valid.
- No implementation, tests, branches, commits, pushes, PRs, or GitHub issues were created by this audit.

## 2026-06-29

### Audit mode
- Cross-repo orchestration mode.

### Repositories scanned
- SkyAware (`/Users/justin/Code/project-arcus`)
- arcus-signal (`/Users/justin/Code/arcus-signal`)
- ArcusCore (`/Users/justin/Code/ArcusCore`)

### Commit window inspected
- SkyAware: commits after the 2026-06-22 automation run through `0b76556`; contract-relevant code change was `e54ae26` (`Fix stale weather refreshes and precompute alert ordering (#262)`). `0b76556` was release-doc-only and did not change code contracts.
- arcus-signal: commits after the 2026-06-22 automation run through `386dd9f` on the current `newIngredientParams` checkout, including Anvil request/response DTOs, Storm Setup pressure-artifact consumption, sampled snapshot cache behavior, pressure artifact catalog/readiness dashboard fields, and cancellation behavior. Current working-tree edits in `Sources/App/StormSetup/StormSetupProvider.swift` and `Tests/AppTests/PressureArtifactDiagnosticsTests.swift` were present and inspected as current-state evidence, but no source files were modified by this audit.
- ArcusCore: no commits in the window; current `main` shared APNs, alert, and location contracts were inspected as reference.

### Contract surfaces inspected
- Storm Setup sampled snapshot cache key/versioning, `StormSetupRulesVersion`, `StormSetupSnapshotCache`, `TornadoRawParameters`, `TornadoIngredientNormalizer`, `TornadoIngredientInterpreter`, and `GET /api/v1/storm-setup/current` response composition.
- Anvil profile analysis request/response DTOs, frozen fixtures, HTTP client encoder/decoder, debug profile routes, Postman collection, pressure-level request builder, and pressure artifact stale/exact selection.
- Pressure artifact catalog persistence and operator dashboard response DTOs, including `PressureArtifactReadinessSelectionOutcome`, `PressureArtifactCatalogStatus`, `byteSize`, `fieldSetVersion`, dates, and stale fallback fields.
- Device location snapshot upload sources across SkyAware, ArcusCore, arcus-signal validation/persistence/docs, and Postman fixtures.
- APNs hot-alert payload identifiers and `revisionSent` date encoding/decoding across arcus-signal, SkyAware, and ArcusCore.
- Alert lifecycle fields (`expires`, `ends`, revision identifiers) and SkyAware stale-weather/local-alert display behavior changed by `e54ae26`.

### Highest-risk areas
- Storm Setup sampled snapshot cache versioning because cached raw parameter payloads can survive code deployments and directly shape severe-weather assessment semantics.
- Anvil and HRRR pressure-profile contracts because they are new, date-heavy, H3/geospatial payloads with required arrays and external service assumptions.
- APNs/location contracts because they remain direct cross-repo notification and freshness boundaries with prior drift history.

### Findings

| Finding | Repositories | Contract surface | Contract direction | Evidence | Impact | Confidence | Minimal fix | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Storm Setup raw-parameter and assessment semantics changed while sampled snapshot cache still uses V1 namespace | arcus-signal | Storm Setup sampled snapshot persistence/cache key and response builder | Normalizer/interpreter semantics -> persisted sampled snapshot cache -> `GET /api/v1/storm-setup/current` response | Commit `674c2c7` keeps the new `TornadoRawParameters.tempDewPtDeltaF` spelling and `threeCapeJkg` field in `Sources/App/StormSetup/StormSetupModels.swift`; `TornadoIngredientNormalizer` now populates those fields from 2m temperature/dewpoint and 3CAPE samples; `TornadoIngredientInterpreter.moistureScore` and `cloudBaseScore` consume `tempDewPtDeltaF`. `Sources/App/StormSetup/StormSetupRulesVersion.swift` still declares `.tornadoIngredientV2` but sets `current = .tornadoIngredientV1`. `DefaultStormSetupProvider.loadSnapshot` builds `StormSetupSnapshotCacheKey(... rulesVersion: .current)`, and `StormSetupSnapshotCache.loadSnapshot` returns a fresh matching record after recomputing only the baseline assessment from the cached raw payload. `StormSetupSnapshotCacheTests.differentRulesVersionsMissTheCache` proves rules version is the intended invalidation boundary. | Existing fresh V1 sampled snapshots can bypass resampling after deployment, so the endpoint can return assessments computed from cached raw payloads that lack the newly available `tempDewPtDeltaF` and `threeCapeJkg` inputs until cache expiry. That can understate or overstate moisture/cloud-base support and user-facing tornado-ingredient confidence for affected H3/source keys. Unfixed blast radius is Storm Setup current responses served from sampled snapshot cache. Proposed-change blast radius is limited to cache namespace invalidation and one-time recomputation. | High | Bump `StormSetupRulesVersion.current` to `.tornadoIngredientV2`; keep V1 decode support for existing records. Add a focused regression proving a V1 cached record misses after the current version changes, and preferably a provider test showing a cached V1 raw payload without new fields is not served under current semantics. | Unit: cache key/version miss test for V1-to-current. Provider: seed V1 sampled snapshot lacking `tempDewPtDeltaF`, call current provider, assert resampling occurs. Manual: deploy with existing sampled cache and confirm new V2 cache paths are written. |

### Top recommended fix
- Bump `StormSetupRulesVersion.current` to `.tornadoIngredientV2`.
- This matters because Storm Setup now has new raw inputs and assessment evidence paths, while the sampled snapshot cache still advertises the old semantic namespace.
- Expected files touched: `arcus-signal/Sources/App/StormSetup/StormSetupRulesVersion.swift` and one focused cache/provider test in `arcus-signal/Tests/AppTests/StormSetupSnapshotCacheTests.swift` or `StormSetupProviderTests.swift`.
- Estimated churn: under 25 lines.
- Regression risk: Low; affected keys miss the sampled snapshot cache once and recompute under current semantics.

### Watchlist
- Anvil profile analysis remains partly out-of-scope as a cross-repo contract. arcus-signal now has `AnvilAnalyzeProfileRequest`, `AnvilAnalyzeProfileResponse`, frozen JSON fixtures, a Postman `v1/analyze-profile` request, and client tests. The actual Anvil service schema/decoder is not in the scoped repositories, and SkyAware/ArcusCore do not consume these DTOs. Promote only when the external producer contract is in scope or a generated/shared schema appears.
- Location snapshot documentation and Postman examples still show stale source values (`foreground`, `significantChange`) while ArcusCore and server validation use the expanded `LocationUploadSource` set. This is the unresolved 2026-06-15 documentation-contract finding with no materially better evidence this week; do not duplicate it as a new finding.
- SkyAware still has presentation paths that order or describe alerts by different lifecycle fields (`AlertView` orders by `ends`; Summary active-alert copy uses `expires`). No new producer-side lifecycle contract changed this week, so keep this as a semantics watchlist until a fixture/spec declares the authoritative user-facing timestamp.

### Files inspected
- SkyAware: `Sources/App/HomeRefreshPipeline.swift`, `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`, `Sources/App/HomeRefreshV2/HomeSnapshot.swift`, `Sources/Features/Alert/AlertPresentationOrdering.swift`, `Sources/Features/Alert/AlertView.swift`, `Sources/Features/Summary/PrimaryAwarenessPanel.swift`, `Sources/Clients/ArcusClient.swift`, `Sources/App/RemoteHotAlertHandler.swift`, `Sources/Infrastructure/Location/HTTPLocationSnapshotUploader.swift`, `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`, `Tests/UnitTests/HomeRefreshPipelineTests.swift`, `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`, and `SkyAware.xcodeproj/project.pbxproj`.
- arcus-signal: `Sources/App/StormSetup/StormSetupModels.swift`, `StormSetupRulesVersion.swift`, `StormSetupSnapshotCache.swift`, `StormSetupProvider.swift`, `TornadoIngredientNormalizer.swift`, `TornadoIngredientInterpreter.swift`, `AnvilIngredientEvidence.swift`, `AnvilProfileClient.swift`, `AnvilProfileAnalysisProvider.swift`, `AnvilProfileRequestBuilder.swift`, `PressureArtifactCatalogLookupService.swift`, `Sources/App/Models/API/AnvilAnalyzeProfileRequest.swift`, `AnvilAnalyzeProfileResponse.swift`, `AnvilAnalyzeProfileAnalysisResponse.swift`, `AnvilAnalyzeProfilePreviewResponse.swift`, `OperatorDashboardSnapshotResponse.swift`, `Sources/App/Models/Data/PressureArtifactCatalogModel.swift`, `Sources/App/Migrations/CreatePressureArtifactCatalog.swift`, `AddClaimFencingToPressureArtifactCatalog.swift`, `Sources/App/lib/OperatorDashboardSnapshotRefresher.swift`, `OperatorDashboardPageRenderer.swift`, `Sources/App/Controllers/StormSetupController.swift`, `AnvilProfileAnalysisController.swift`, `AnvilProfilePreviewController.swift`, `Sources/App/configure.swift`, `Sources/App/Jobs/NotificationSendJob.swift`, `Tests/AppTests/StormSetupSnapshotCacheTests.swift`, `StormSetupProviderTests.swift`, `StormSetupControllerTests.swift`, `AnvilAnalyzeProfileDTOTests.swift`, `AnvilAnalyzeProfileResponseDTOTests.swift`, `AnvilProfileClientTests.swift`, `AnvilProfileRequestBuilderTests.swift`, `OperatorDashboardPressureArtifactTests.swift`, `Tests/AppTests/Fixtures/AnvilAnalyzeProfileRequest.json`, `Tests/AppTests/Fixtures/AnvilAnalyzeProfileResponse.json`, `docs/api-endpoints.md`, and Anvil/Device Postman request YAML files.
- ArcusCore: `Sources/ArcusCore/HotAlertAPNsPayload.swift`, `Sources/ArcusCore/LocationUploadSource.swift`, `Sources/ArcusCore/LocationSnapshotPushPayload.swift`, `Sources/ArcusCore/DeviceAlertPayload.swift`, and `Tests/ArcusCoreTests/ArcusCoreTests.swift`.

### Out-of-scope and recommendation status
- No repositories outside SkyAware, arcus-signal, and ArcusCore were inspected.
- The actual Anvil service repository/schema was not inspected because it is outside this automation scope; no confirmed drift claim was made for that external boundary.
- Findings: 1 High, 0 Medium, 0 Low. Watchlist: 3.
- Implementation recommended: Yes, for Storm Setup rules-version invalidation.
- No implementation, tests, branches, commits, pushes, PRs, or GitHub issues were created by this audit.

## 2026-07-13

### Audit mode
- Cross-repo orchestration mode.

### Repositories scanned
- SkyAware (`/Users/justin/Code/project-arcus`)
- arcus-signal (`/Users/justin/Code/arcus-signal`)
- ArcusCore (`/Users/justin/Code/ArcusCore`)

### Commit window inspected
- SkyAware: commits after the 2026-07-06 automation run through `0fb54008`. Contract-relevant change was `fa73e569` (`Migrate Storm Setup to the ArcusCore aggregate and wire it through Today (#303)`); later commits were test/file-organization or release-note changes. Current local map refactor edits were present but not contract-relevant.
- arcus-signal: commits after the 2026-07-06 automation run through `139f10b`, including `a7b277d` (`Separate tornado viability from the Storm Setup current response (#147)`), AirNow AQI endpoint work, and package updates. Current Postman rename/delete working-tree changes were inspected as documentation/fixture evidence only.
- ArcusCore: commits after `de86f50` through `977945d`, including shared Storm Setup aggregate models, raw-string tornado viability enum compatibility, and `AirQualityCurrentResponse`.

### Contract surfaces inspected
- `GET /api/v1/storm-setup/current` route, provider composition, `StormSetupCurrentResponse`, `TornadoViabilityReport`, canonical/diagnostic ingredient split, `profileAnalysis`, `surfaceHeightMslM`, and app decoding/persistence of the ArcusCore aggregate.
- Storm Setup sampled snapshot cache key/versioning, `StormSetupRulesVersion`, `StormSetupSnapshotCache`, interpreter semantics, Anvil exact/stale evidence handling, and response builder paths.
- `GET /api/v1/air-quality/current`, `AirQualityCurrentResponse`, AirNow normalization, app AQI client decoding, README/Postman endpoint fixtures.
- Package pins for ArcusCore in SkyAware and arcus-signal.
- Prior high-risk APNs/date and location-source documentation findings were not re-expanded because no new evidence changed those contracts in this window.

### Highest-risk areas
- Storm Setup cache versioning remains highest risk because persisted sampled snapshots can survive deployments while the public severe-weather interpretation semantics continue to evolve.
- The new shared Storm Setup aggregate is high risk because the server, shared package, app decoder, persistence codec, and presentation mapping all now depend on one response shape.
- Air Quality was inspected because it is a new app/server/shared endpoint with location-scoped freshness and date decoding assumptions.

### Findings

| Finding | Repositories | Contract surface | Contract direction | Evidence | Impact | Confidence | Minimal fix | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Storm Setup viability semantics changed again while sampled snapshot cache still uses the V1 rules namespace | arcus-signal, ArcusCore, SkyAware | Storm Setup sampled snapshot persistence/cache key and public current response | Interpreter/response semantics -> persisted sampled snapshot cache -> `GET /api/v1/storm-setup/current` -> app/shared decoder | arcus-signal commit `a7b277d` rewired `TornadoIngredientInterpreter` into a richer tornado viability diagnosis and added the public `TornadoViabilityReport` bridge. `Sources/App/StormSetup/StormSetupRulesVersion.swift` still sets `current = .tornadoIngredientV1` even though `.tornadoIngredientV2` exists. `StormSetupSnapshotCacheKey` includes `rulesVersion` in the cache path, and `StormSetupSnapshotCacheTests.differentRulesVersionsMissTheCache` proves that version is the intended semantic invalidation boundary. `StormSetupSnapshotCache.loadSnapshot` returns a fresh matching record after re-assessing only the cached raw snapshot with the requested rules version. ArcusCore `Sources/ArcusCore/StormSetup/StormSetupCurrentResponse.swift` now makes `tornadoViability` part of the shared response, and SkyAware `Sources/Clients/StormSetupClient.swift` decodes that shared response directly. | Fresh V1 cache records can continue to shape the public tornado viability response after semantics change, especially for cached sampled snapshots that lack exact Anvil canonical ingredients. The user-visible blast radius is Storm Setup guidance for affected H3/source keys until cache expiry. Proposed-change blast radius is limited to sampled snapshot namespace invalidation and one-time recomputation. | High | Bump `StormSetupRulesVersion.current` to `.tornadoIngredientV2`; keep V1 decode support for existing cache records. Add a focused regression proving a V1 sampled snapshot misses when requested through current rules, then verify the current response still encodes/decodes through ArcusCore. | Unit: cache version miss test keyed from `.tornadoIngredientV1` to `.current`. Provider/API contract: seed a V1 cached sampled snapshot and assert current response recomputes under V2. Decoding: keep ArcusCore/SkyAware `StormSetupCurrentResponse` round-trip tests. |

### Top recommended fix
- Bump `arcus-signal/Sources/App/StormSetup/StormSetupRulesVersion.swift` so `StormSetupRulesVersion.current == .tornadoIngredientV2`.
- This matters because the public `tornadoViability` response is now shared across ArcusCore and consumed directly by SkyAware, so stale cached assessments have a clearer app-facing contract impact than in prior runs.
- Expected files touched: `arcus-signal/Sources/App/StormSetup/StormSetupRulesVersion.swift` and one focused cache/provider test.
- Estimated churn: under 25 lines.
- Regression risk: Low; existing V1 records remain decodable but should miss the current cache namespace and recompute.

### Watchlist
- `GET /api/v1/air-quality/current` is implemented in arcus-signal, modeled in ArcusCore, and decoded by SkyAware, but `arcus-signal/docs/api-endpoints.md` does not document the route or response shape. README and Postman mention the endpoint, and code/tests align, so this is not confirmed runtime drift. Promote only if endpoint docs are treated as the authoritative public API contract or fixtures begin contradicting the shared DTO.
- Anvil profile analysis service schema remains outside the scoped repositories. arcus-signal and ArcusCore now expose app-facing `AnvilAnalyzeProfileResponse` through `StormSetupCurrentResponse.profileAnalysis`, and SkyAware decodes it, but the external Anvil service producer contract is unavailable here. Promote only when that schema/client generation source is in scope.
- The stale location-source documentation/Postman concern remains a prior unresolved documentation-contract item; no materially better evidence was found this week.

### Files inspected
- SkyAware: `SkyAware.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `Sources/Clients/StormSetupClient.swift`, `Sources/Clients/AirQualityClient.swift`, `Sources/Models/StormSetup/StormSetupDTO.swift`, `Sources/Models/StormSetup/StormSetupAssessment.swift`, `Sources/Models/Home/HomeProjection.swift`, `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`, `Sources/App/HomeView.swift`, `Sources/Features/StormSetup/StormSetupPresentation.swift`, `Sources/Features/StormSetup/StormSetupDetailPresentation.swift`, `Tests/UnitTests/StormSetupHTTPClientTests.swift`, `Tests/UnitTests/StormSetupIngestionTests.swift`, `Tests/UnitTests/HomeProjectionStoreTests.swift`, and `Tests/UnitTests/AirQualityHTTPClientTests.swift`.
- arcus-signal: `Package.resolved`, `Sources/App/Controllers/StormSetupController.swift`, `Sources/App/StormSetup/StormSetupProvider.swift`, `Sources/App/StormSetup/StormSetupRulesVersion.swift`, `Sources/App/StormSetup/StormSetupSnapshotCache.swift`, `Sources/App/StormSetup/StormSetupSnapshotCacheKey.swift`, `Sources/App/StormSetup/StormSetupModels.swift`, `Sources/App/StormSetup/TornadoIngredientInterpreter.swift`, `Sources/App/StormSetup/TornadoIngredientAssessment.swift`, `Sources/App/StormSetup/AnvilIngredientEvidence.swift`, `Sources/App/Controllers/AirQualityController.swift`, `Sources/App/AirQuality/AirQualityProvider.swift`, `Sources/App/AirQuality/AirNowClient.swift`, `Sources/App/AirQuality/AirNowObservation.swift`, `Sources/App/Extensions/VaporContentConformances.swift`, `Tests/AppTests/StormSetupCurrentResponseDTOTests.swift`, `Tests/AppTests/StormSetupProviderTests.swift`, `Tests/AppTests/StormSetupSnapshotCacheTests.swift`, `Tests/AppTests/AirQualityTests.swift`, `README.md`, `docs/api-endpoints.md`, and AirQuality/StormSetup/Anvil Postman request YAML files.
- ArcusCore: `Sources/ArcusCore/StormSetup/StormSetupCurrentResponse.swift`, `Sources/ArcusCore/StormSetup/TornadoIngredientAssessment.swift`, `Sources/ArcusCore/StormSetup/TornadoRawParameters.swift`, `Sources/ArcusCore/StormSetup/StormSetupSourceModels.swift`, `Sources/ArcusCore/AirQualityCurrentResponse.swift`, `Tests/ArcusCoreTests/StormSetupDTOTests.swift`, and `Tests/ArcusCoreTests/ArcusCoreTests.swift`.

### Out-of-scope and recommendation status
- No repositories outside SkyAware, arcus-signal, and ArcusCore were inspected.
- No external Anvil service schema, deployed API logs, or generated OpenAPI schema was available in the scoped repositories.
- Findings: 1 High, 0 Medium, 0 Low. Watchlist: 3.
- Implementation recommended: Yes, for Storm Setup rules-version invalidation.
- No implementation, tests, branches, commits, pushes, PRs, or GitHub issues were created by this audit.

## 2026-07-06

### Audit mode
- Cross-repo orchestration mode.

### Repositories scanned
- SkyAware (`/Users/justin/Code/project-arcus`)
- arcus-signal (`/Users/justin/Code/arcus-signal`)
- ArcusCore (`/Users/justin/Code/ArcusCore`)

### Commit window inspected
- SkyAware: `0b76556..162d232` on the current `stormSetup` checkout (2026-07-02 through 2026-07-06). The window added the Storm Setup production client/DTO, profile-analysis DTO/client, SwiftData persistence, cache-forward ingestion, matching policy, and user-facing Detailed Ingredients rows.
- arcus-signal: the prior `386dd9f` marker is not an ancestor of the current `anvilParams` checkout, so a date-based window after the 2026-06-29 automation run was used through `852d7f1` (`ba97707`, `8781021`, `852d7f1`). Contract-relevant changes added the Anvil profile-analysis route/DTOs and exact-cycle surface loading.
- ArcusCore: `de86f50..HEAD` contains no commits. Current `main` at `de86f50` was inspected as the shared-contract reference for APNs, alert, and location payloads.

### Contract surfaces inspected
- `GET /api/v1/storm-setup/current?h3=` route, `TornadoIngredientSnapshot`, `StormSetupSourceMetadata`, `TornadoRawParameters`, `IngredientFreshness`, SkyAware `StormSetupDTO`, ISO-8601 decoding, H3 query encoding, optionality, and user-facing mapping.
- Legacy profile-analysis route availability, environment guard, request identity fields, response DTOs, SkyAware profile-analysis DTOs, HTTP client, matching policy, SwiftData persistence, and Detailed Ingredients presentation.
- Storm Setup sampled snapshot cache keys and `StormSetupRulesVersion`.
- APNs `HotAlertAPNsPayload` identifiers and ISO-8601 revision encoding across arcus-signal, SkyAware, and ArcusCore.
- Location snapshot H3/freshness fields and `LocationUploadSource` values across SkyAware, arcus-signal, and ArcusCore.
- Alert lifecycle and revision fields in ArcusCore plus the unchanged SkyAware `ends`/`expires` presentation boundary.

### Highest-risk areas
- Profile-analysis route availability because SkyAware once treated the endpoint as an app ingestion dependency, while arcus-signal classified it as a non-production debug endpoint.
- Storm Setup response optionality because a single partial field can reject the complete severe-weather payload before safe mapping or stale-cache policy runs.
- Storm Setup persistence/versioning because cached assessments survive deployments and now feed a user-facing client.

### Findings

| Finding | Repositories | Contract surface | Contract direction | Evidence | Impact | Confidence | Minimal fix | Validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SkyAware called a profile-analysis route that arcus-signal disabled in production | SkyAware, arcus-signal | Profile-analysis API route and client availability | Server route → app client | arcus-signal commit `ba97707` added `AnvilProfileAnalysisController`: it registered only the legacy profile-analysis route and returned 404 when `application.environment == .production`; `AnvilProfileAnalysisControllerTests.productionStillBlocksTheEndpoint` locked that behavior. SkyAware commits `2bd08d7` and `4715868` set `ArcusSignalConfiguration` to that same legacy path and added the profile-analysis HTTP client. `Dependencies` always installed that client into `HomeIngestionExecutor`; the profile-analysis policy activated it whenever Storm Setup and Detailed Ingredients were enabled. Commits `0a4b39a`, `06fb0eb`, and `162d232` persisted and displayed its response. | In production, every eligible profile-analysis request received 404, was recorded as a failed refresh, and could not populate Detailed Ingredients. Users saw no profile rows or only a previously cached value; the app repeated failed attempts after backoff. Unfixed blast radius was all production users enabling Detailed Ingredients. | High | Add a production-supported Storm Setup profile-analysis route and point SkyAware at it. Return only the request identity needed for matching plus the analysis response; do not expose the raw profile/location/debug wrapper merely to make the old route public. Proposed-change blast radius was the new route, one app path constant, and focused route/client tests. | Server integration: production environment returns 200 for the supported route and still blocks the old route. Cross-repo contract: encode the server response fixture and decode it with SkyAware's DTO. App HTTP test: assert the production path. Manual: enable Detailed Ingredients against a production-configured server and verify a fresh matched response appears. |
| Storm Setup permits a missing surface height but SkyAware requires it | SkyAware, arcus-signal | Storm Setup response optionality and safe degraded decoding | Server payload → client decoder | arcus-signal `TornadoIngredientSnapshot.surfaceHeightMslM` is `Double?` with a default of `nil` in `StormSetupModels.swift`. `TornadoIngredientNormalizer.surfaceHeightMslM(from:)` returns `nil` when no surface-height sample exists. `DefaultStormSetupProvider.loadSnapshot` requires only `raw.nonNilFieldCount > 0` and then returns the optional normalized surface height, so a successful response may encode `surfaceHeightMslM: null`. SkyAware commit `8d67dd4` defines `StormSetupDTO.surfaceHeightMslM` as required `Double`; `StormSetupHTTPClient` decodes the whole response with `DecoderFactory.iso8601` and maps any decode failure to `ArcusError.parsingError`. `StormSetupAssessment` also requires the value. | A valid partial server response with useful ingredient and freshness data is rejected wholesale. Without a fresh cache, Storm Setup disappears; with one, the app can retain stale data instead of accepting the current degraded payload. Unfixed blast radius is responses where surface-height sampling is absent or null. | High | Make SkyAware's wire DTO and mapped assessment surface height optional, and render height-dependent detail as unavailable. Preserve the server's explicit partial/degraded contract rather than manufacturing a value. Proposed-change blast radius is the DTO/mapping and height presentation only. | Cross-repo decoding test with the server contract fixture containing `surfaceHeightMslM: null`; mapping test verifies all other fields survive; presentation test verifies height-dependent copy is omitted or marked unavailable. |

### Top recommended fix
- Replace the dev-only profile-analysis dependency with a production-supported Storm Setup profile-analysis route and update SkyAware's path.
- This matters first because the current producer explicitly rejects the current consumer in production; the feature cannot succeed regardless of payload correctness.
- Expected files touched:
  - arcus-signal `Sources/App/Controllers/AnvilProfileAnalysisController.swift`
  - arcus-signal profile-analysis response DTO (existing or a small production response DTO)
  - arcus-signal `Tests/AppTests/AnvilProfileAnalysisControllerTests.swift`
  - SkyAware `Sources/App/ArcusSignalConfiguration.swift`
  - SkyAware `Tests/UnitTests/StormSetupHTTPClientTests.swift`
- Estimated churn: approximately 60-120 lines.
- Regression risk: Medium. The response should be sanitized before production exposure, and route availability plus request cost need focused review.

### Watchlist
- arcus-signal `StormSetupSourceMetadata` models `model`, `product`, `domain`, `runTime`, `validTime`, `forecastHour`, `fieldSetVersion`, and `bbox` as optional, while SkyAware's `StormSetupDTO.Source` requires them. Current successful surface-provider evidence builds a complete source, so this is not confirmed runtime drift. Promote if a successful route fixture or degraded/fallback path emits any of those fields as null.
- Storm Setup and profile-analysis wire DTOs are duplicated in SkyAware and arcus-signal and are not shared through ArcusCore. Duplication is not itself a finding. Promote only when another explicit field, enum, optionality, or date-format mismatch appears; a cross-repo fixture test would reduce this risk without forcing premature shared ownership.
- SkyAware still uses different lifecycle fields for alert presentation (`ends` in Alert Center ordering and `expires` in Summary active-state copy). No changed producer contract or authoritative fixture in this window establishes the intended precedence. Promote only with an explicit lifecycle specification or a fixture where the fields diverge and expected behavior is defined.

### Previously reported findings not duplicated
- The 2026-06-29 Storm Setup rules-version finding remains unresolved: `StormSetupRulesVersion.current` is still `.tornadoIngredientV1`. This week adds a real SkyAware consumer and therefore increases user-visible blast radius, but the mismatch and minimal fix are unchanged, so it is not counted again.
- The stale location-source values in `arcus-signal/docs/api-endpoints.md` and Postman examples remain unchanged. ArcusCore and server code still use the expanded enum set. No materially better evidence or fix was found, so the prior documentation finding is not duplicated.

### Files inspected
  - SkyAware: `Sources/App/ArcusSignalConfiguration.swift`, `Dependencies.swift`, `HomeRefreshPipeline.swift`, `HomeRefreshV2/HomeIngestionExecutor.swift`, `HomeRefreshV2/HomeSnapshot.swift`, `Sources/Clients/StormSetupClient.swift`, `Sources/Models/StormSetup/StormSetupDTO.swift`, `StormSetupAssessment.swift`, `StormSetupPreferences.swift`, `Sources/Models/Home/HomeProjection.swift`, `Sources/Repos/HomeProjectionStore.swift`, `Sources/Features/StormSetup/StormSetupDetailPresentation.swift`, `StormSetupDetailView.swift`, `Sources/Features/Summary/SummaryView.swift`, and focused Storm Setup tests.
- arcus-signal: `Sources/App/Controllers/StormSetupController.swift`, `AnvilProfileAnalysisController.swift`, `Sources/App/Models/API/AnvilAnalyzeProfileAnalysisResponse.swift`, `AnvilAnalyzeProfileRequest.swift`, `AnvilAnalyzeProfileResponse.swift`, `Sources/App/StormSetup/StormSetupModels.swift`, `StormSetupProvider.swift`, `StormSetupRulesVersion.swift`, `StormSetupSnapshotCache.swift`, `TornadoIngredientNormalizer.swift`, `IngredientFreshness.swift`, `AnvilProfileAnalysisProvider.swift`, `AnvilProfileRequestBuilder.swift`, `Sources/App/configure.swift`, `Tests/AppTests/StormSetupControllerTests.swift`, `StormSetupProviderTests.swift`, `StormSetupSnapshotCacheTests.swift`, `AnvilProfileAnalysisControllerTests.swift`, `AnvilAnalyzeProfileDTOTests.swift`, `AnvilAnalyzeProfileResponseDTOTests.swift`, `docs/api-endpoints.md`, and relevant Postman definitions.
- ArcusCore: `Sources/ArcusCore/HotAlertAPNsPayload.swift`, `DeviceAlertPayload.swift`, `LocationSnapshotPushPayload.swift`, `LocationUploadSource.swift`, and `Tests/ArcusCoreTests/ArcusCoreTests.swift`.

### Out-of-scope and recommendation status
- The external Anvil service schema/implementation remains outside the three-repository scope; no finding claims drift across that unavailable boundary.
- No generated Storm Setup client/schema exists in the scoped repositories.
- Findings: 2 High, 0 Medium, 0 Low. Watchlist: 3.
- Implementation recommended: Yes, first for production profile-analysis route alignment, then for tolerant `surfaceHeightMslM` decoding.
- No source files, tests, branches, commits, pushes, PRs, or GitHub issues were created or modified by this audit.
