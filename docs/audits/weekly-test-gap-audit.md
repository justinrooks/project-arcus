# Weekly Test Gap Audit

## 2026-07-21
- Repository reviewed: project-arcus (`/Users/justin/Code/project-arcus`)
- Commit window inspected: since last reliable audit marker `d44cd790407ea3a9d0069a5f5490efd34178549f` through `97028ac094ec5895d4db68c95c6a69990576eb66` (2026-07-14 through 2026-07-20); 23 commits inspected
- High-risk areas inspected: risk-change notification occurrence persistence, deduplication, retry, and morning-summary coalescing; background cadence scheduling and failure recovery; GeoJSON polygon-hole parsing, SwiftData persistence, risk lookup, and map rendering; concurrent ingestion lanes and staged Today-content publication
- Files inspected: `Sources/Notifications/RiskChange/RiskChangeComposer.swift`, `Sources/Notifications/RiskChange/RiskChangeEngine.swift`, `Sources/Notifications/RiskChange/RiskChangeGate.swift`, `Sources/Features/Background/BackgroundOrchestrator.swift`, `Sources/Infrastructure/Scheduling/BackgroundScheduler.swift`, `Sources/Policies/CadencePolicy.swift`, `Sources/Infrastructure/Parsing/GeoJSON/GeoJSONModels.swift`, `Sources/Utilities/Geometry/GeoPolygonEntity.swift`, `Sources/Features/Map/MapPolygonMapper.swift`, `Sources/App/HomeRefreshPipeline.swift`, `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`, `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`, and their adjacent unit tests
- Existing relevant tests found: `Tests/UnitTests/RiskChangeNotificationTests.swift`, `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`, `Tests/UnitTests/MorningNotificationTests.swift`, `Tests/UnitTests/GeoJsonParserTests.swift`, `Tests/UnitTests/MapDataFreshnessRepoTests.swift`, `Tests/UnitTests/MapPolygonMapperTests.swift`, `Tests/UnitTests/RiskPolygonOverlayTests.swift`, `Tests/UnitTests/HomeRefreshPipelineTests.swift`, `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`, `Tests/UnitTests/StormSetupIngestionTests.swift`
- Top recommended test: No test gap recommended. The inspected notification, scheduling, geometry, persistence, concurrency, and staged-publication behaviors have focused contract and regression coverage in the same commit window.
- Watchlist items: none
- Implementation recommended: no
- Out-of-scope repositories intentionally not scanned: all sibling repositories and external services; no cross-repository findings were evaluated or reported

## 2026-07-14
- Repository reviewed: project-arcus (`/Users/justin/Code/project-arcus`)
- Commit window inspected: since last automation run marker `2026-07-07T15:01:53.356Z` through `2026-07-14`; 15 commits inspected from `fa73e5692e6e132747126bc8e48afa69a5dd2c73` through `d44cd790407ea3a9d0069a5f5490efd34178549f`
- High-risk areas inspected: Storm Setup aggregate migration and persistence, `HomeRefresh` / `HomeView` selection logic, `HomeProjection` storm setup cache encoding, and location upload queue persistence / deduplication
- Files inspected: `Sources/Models/StormSetup/StormSetupDTO.swift`, `Sources/App/HomeRefreshV2/HomeStormSetupIngestion.swift`, `Sources/Models/Home/HomeProjection.swift`, `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`, `Sources/Infrastructure/Location/LocationUploadQueueStore.swift`, `Sources/App/HomeView+PresentationState.swift`, `Tests/UnitTests/StormSetupMappingTests.swift`, `Tests/UnitTests/StormSetupHTTPClientTests.swift`, `Tests/UnitTests/StormSetupIngestionTests.swift`, `Tests/UnitTests/HomeProjectionStoreTests.swift`, `Tests/UnitTests/LocationProviderTests.swift`, `Tests/UnitTests/HomeViewStateTests.swift`
- Existing relevant tests found: `Tests/UnitTests/StormSetupHTTPClientTests.swift`, `Tests/UnitTests/StormSetupMappingTests.swift`, `Tests/UnitTests/StormSetupIngestionTests.swift`, `Tests/UnitTests/HomeProjectionStoreTests.swift`, `Tests/UnitTests/LocationProviderTests.swift`, `Tests/UnitTests/HomeViewStateTests.swift`
- Top recommended test: No test gap recommended.
- Watchlist items: none
- Implementation recommended: no
- Out-of-scope repositories intentionally not scanned: none

## 2026-07-07
- Repository reviewed: project-arcus (`/Users/justin/Code/project-arcus`)
- Commit window inspected: since last automation run marker `2026-06-30T15:00:37.541Z` through `2026-07-07`; commits inspected included `d5e80f584476955adab5e7ca4b4016e887842e58`, `06fb0eb48428f345ddd69e4dac5e3824a7674df2`, and `8c1cb914fe79a2f2bfdb6f463fca0fb175815114`
- High-risk areas inspected: `SkyAwareApp` activation cleanup gating, storm-setup DTO/policy/ingestion flow, home refresh pipeline/profile-analysis propagation, DTO and presentation contract behavior
- Files inspected: `Sources/App/SkyAwareApp.swift`, `Sources/App/HomeRefreshPipeline.swift`, `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`, `Sources/Models/StormSetup/StormSetupDTO.swift`, legacy profile-analysis policy code, `Tests/UnitTests/HomeRefreshPipelineTests.swift`, `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`, `Tests/UnitTests/StormSetupMappingTests.swift`, legacy profile-analysis policy tests, `Tests/UnitTests/StormSetupIngestionTests.swift`, `Tests/UnitTests/HomeProjectionStoreTests.swift`, legacy profile-analysis DTO and HTTP client tests, `Tests/UnitTests/StormSetupPresentationTests.swift`
- Existing relevant tests found: `Tests/UnitTests/HomeRefreshPipelineTests.swift`, `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`, `Tests/UnitTests/StormSetupMappingTests.swift`, legacy profile-analysis policy tests, `Tests/UnitTests/StormSetupIngestionTests.swift`, `Tests/UnitTests/HomeProjectionStoreTests.swift`, legacy profile-analysis DTO and HTTP client tests, `Tests/UnitTests/StormSetupPresentationTests.swift`
- Top recommended test: `SkyAwareAppActivationCleanupTests.shouldRunActivationCleanup_enforcesHourlyThrottle` to lock the new hourly activation-cleanup gate in `Sources/App/SkyAwareApp.swift` (implemented and verified)
- Watchlist items: none
- Validation note: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/SkyAwareAppActivationCleanupTests test` passed
- Implementation recommended: completed
- Out-of-scope repositories intentionally not scanned: none

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
