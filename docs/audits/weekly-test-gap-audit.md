# Weekly Test Gap Audit

## 2026-06-23
- Repository reviewed: project-arcus (`/Users/justin/Code/project-arcus`)
- Commit window inspected: since last automation run marker `2026-06-16T15:02:20Z` through `2026-06-23`; commits inspected included `6e5327e86d50d792f64b41de79e99492a862d5c3` and `e54ae2669f7969e48ff1b98f8aaaefb0e68ef2f6`
- High-risk areas inspected: `HomeRefreshPipeline`, `HomeIngestionExecutor`, `HomeSnapshot`, `AlertView`, `LocationContextResolver`, alert ordering, stale weather refresh handling, location timing and timeout behavior
- Files inspected: `Sources/App/HomeRefreshPipeline.swift`, `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`, `Sources/App/HomeRefreshV2/HomeSnapshot.swift`, `Sources/Features/Alert/AlertView.swift`, `Sources/Infrastructure/Location/LocationContextResolver.swift`, `Tests/UnitTests/HomeRefreshPipelineTests.swift`, `Tests/UnitTests/AlertPresentationOrderingTests.swift`, `Tests/UnitTests/LocationProviderTests.swift`, `Tests/UnitTests/RemoteNotificationRegistrarTests.swift`, `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
- Existing relevant tests found: `Tests/UnitTests/HomeRefreshPipelineTests.swift`, `Tests/UnitTests/AlertPresentationOrderingTests.swift`, `Tests/UnitTests/LocationProviderTests.swift`, `Tests/UnitTests/RemoteNotificationRegistrarTests.swift`, `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
- No test gap recommended. The recent commit already adds regression coverage for stale-weather clearing and skip-path preservation, and the location timing changes are already pinned by resolver and coordinator tests.
- Watchlist items: none
- Implementation recommended: no
- Out-of-scope repositories intentionally not scanned: none

## 2026-05-26
- Repos scanned: SkyAware (`/Users/justin/Code/project-arcus`), arcus-signal (`/Users/justin/Code/arcus-signal`), ArcusCore (`/Users/justin/Code/ArcusCore`)
- Commit window: last 7 days (2026-05-19 to 2026-05-26 UTC)
- High-risk areas inspected: APNs hot-alert payload contract, targeted alerts API (`/api/v2/alerts?id=`), geometry-vs-UGC targeting, notification dispatch fallback on unsupported geometry, remote hot-alert decoding, alert lifecycle filtering
- Top recommended test: `TargetEventRevisionJobTests.unsupportedGeometry_queuesUGCFallbackAndDrainsUGC` (Implemented)
  - Validation note (2026-05-28): Covered by `TargetEventRevisionJobFallbackTests.unsupportedGeometryUsesUGCFallbackDrainOnly` in `arcus-signal` and verified passing via targeted run.
- Watchlist items:
  - Verify cross-repo rollout sequencing for canonical `arcusAlertId` payload key to avoid mixed-client drift during staged deploys.
- Implementation recommended: Completed (no further action for this finding)

## 2026-06-02
- Repos scanned: SkyAware (`/Users/justin/Code/project-arcus`), arcus-signal (`/Users/justin/Code/arcus-signal`), ArcusCore (`/Users/justin/Code/ArcusCore`)
- Commit window: since last automation run marker `2026-05-26T15:00:38Z`
- High-risk areas inspected: SPC accepted-batch persistence and all-clear handling, mesoscale DTO/copy changes, background-location ingestion routing, pending location/preference upload persistence, dedicated device-preference sync API, shared DTO/source enum additions
- Top recommended test: `DevicePreferenceSyncPayloadContractTests.encodesStableWireKeysAndRoundTripsAcceptedResponse`
- Watchlist items:
  - `arcus-signal` source-constraint migration now allows expanded upload sources, but current coverage only smoke-tests `foregroundPrime`; the rest are not directly exercised through `POST /api/v1/devices/location-snapshots`.
- Implementation recommended: Completed (regression test added in `Tests/UnitTests/LocationProviderTests.swift`)

## 2026-06-09
- Repository reviewed: project-arcus (`/Users/justin/Code/project-arcus`)
- Commit window inspected: since `2026-06-02T15:07:36.770Z` through `2026-06-09`; commits inspected included `384fcb0ab4ac7b123786d50cecdb7dd8e5ce80d3` through `21a670b3cfd88452985604fd7dd296d9fac47386`
- High-risk areas inspected: remote alert context date parsing, APNs hot-alert handling, `MdDTO` compatibility decoding, persisted location upload queue decoding, diagnostics handling
- Files inspected: `Sources/App/RemoteHotAlertHandler.swift`, `Sources/Models/Meso/MdDTO.swift`, `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`, `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`, `Tests/UnitTests/MdDTOCodableCompatibilityTests.swift`, `Tests/UnitTests/LocationProviderTests.swift`
- Existing relevant tests found: `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`, `Tests/UnitTests/MdDTOCodableCompatibilityTests.swift`, `Tests/UnitTests/LocationProviderTests.swift`
- Top recommended test: `RemoteHotAlertHandlerTests.numericAPNsRevisionDateDecodesFromStandardEpochSeconds` to lock the non-reference-date branch in `HomeRemoteAlertContext.normalizedDate(from:)` (implemented in `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`)
- Watchlist items: none
- Validation note: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2" -only-testing:SkyAwareTests/RemoteHotAlertHandlerTests test` passed on 2026-06-09.
- Implementation recommended: Completed
- Out-of-scope repositories intentionally not scanned: none
