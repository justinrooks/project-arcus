# Weekly Bug Scan

## 2026-05-21T16:07:12Z
- date: 2026-05-21T16:07:12Z
- workflow reviewed: Weekly bug scan (audit-only)
- files inspected:
  - /Users/justin/Code/project-arcus/Sources/App/RemoteHotAlertHandler.swift
  - /Users/justin/Code/project-arcus/Sources/Providers/ArcusAlertProvider.swift
  - /Users/justin/Code/project-arcus/Sources/Repos/AlertRepo.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeIngestionSupport.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/RemoteHotAlertHandlerTests.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Jobs/NotificationSendJob.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Clients/APNsClient.swift
  - /Users/justin/Code/arcus-signal/Tests/AppTests/NotificationSendJobDeliveryBoundaryTests.swift
  - /Users/justin/Code/ArcusCore/Sources/ArcusCore/HotAlertAPNsPayload.swift
- top finding: No high-confidence bug confirmed from commits since 2026-05-14T16:06:33Z.
- best next fix: No fix recommended; add one APNs end-to-end contract test for payload decode in app delegate path.
- implementation is recommended: No


## 2026-05-28T16:08:22Z
- date: 2026-05-28T16:08:22Z
- workflow reviewed: Weekly bug scan (audit-only)
- files inspected:
  - /Users/justin/Code/project-arcus/Sources/Infrastructure/Location/LocationSession.swift
  - /Users/justin/Code/project-arcus/Sources/Infrastructure/Location/LocationSnapshotPusher.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Settings/SettingsView.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryStatus.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryView.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Controllers/DeviceController.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Migrations/UpdateDevicePresenceSourceConstraintForExpandedLocationUploadSources.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Jobs/IngestNWSAlertsJob.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Jobs/TargetEventRevisionJob.swift
- top finding: `LocationSession.syncNotificationPreference(enabled:)` and `syncLocationSharingPreference(enabled:)` ignore their `enabled` argument and rely on async defaults-backed reads for `isSubscribed`, which can race on quick toggle transitions.
- best next fix: Thread explicit `enabled` intent into preference-sync payload construction (or pass override into uploader) and assert in unit tests.
- implementation is recommended: Yes
- implementation status: Fixed on 2026-05-28 by threading `isSubscribedOverride` through preference-sync enqueue path and adding regression coverage in `LocationSessionTests` and `LocationProviderTests`.

## 2026-06-04T16:10:30Z
- date: 2026-06-04T16:10:30Z
- workflow reviewed: Weekly bug scan (audit-only)
- files inspected:
  - /Users/justin/Code/project-arcus/Sources/Models/Meso/MdDTO.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/MdDTOCodableCompatibilityTests.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Controllers/DeviceController.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Jobs/NotificationSendJob.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Migrations/UpdateDevicePresenceSourceConstraintForExpandedLocationUploadSources.swift
  - /Users/justin/Code/arcus-signal/Sources/App/Models/Device/DevicePresenceModel.swift
  - /Users/justin/Code/arcus-signal/Tests/AppTests/DevicePreferencesControllerTests.swift
- top finding: `DeviceController.upsertDevicePresence` preserves old H3 fields on `ugc-only` updates, but `loadH3Candidates` still targets any row with a non-null `h3_cell`, so stale H3 data can keep devices on the wrong alert path.
- best next fix: Clear H3 fields when `cellScheme == .ugcOnly` and require `cell_scheme = 'h3'` in H3 candidate queries.
- implementation is recommended: Yes

## 2026-06-18T16:11:44Z
- date: 2026-06-18T16:11:44Z
- repository reviewed: project-arcus
- workflow reviewed: Weekly bug scan (audit-only)
- commit window inspected: 2026-06-11T16:05:14.019Z through 2026-06-18T16:11:44Z
- files inspected:
  - /Users/justin/Code/project-arcus/Sources/App/HomeView.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshPipeline.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeSnapshot.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Summary/TodayVisibleWeatherState.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Summary/SummaryView.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Summary/LocalAlertsDisplayState.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Map/MapFeatureModel.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Map/MapScreenView.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Alert/AlertView.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/HomeRefreshPipelineTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift
- top finding: `HomeRefreshPipeline.apply(_:, commitsVisibleSnapshot:)` only updates `summaryWeather` when the snapshot carries a non-nil weather payload, so a successful refresh that omits weather keeps the previous value alive and `TodayVisibleWeatherState` continues rendering stale weather as if it were current.
- best next fix: Assign `summaryWeather = snapshot.weather` when committing a visible snapshot, then add a regression test for a nil-weather refresh clearing the Today weather card.
- implementation is recommended: Yes
- implementation status: completed on 2026-06-22
- implementation notes:
  - Updated `HomeRefreshPipeline.apply(_:, commitsVisibleSnapshot:)` to assign `summaryWeather = snapshot.weather` unconditionally on visible commits.
  - Added a regression test proving a successful visible refresh with `weather: nil` clears stale cached weather.
- out-of-scope repositories intentionally not scanned: arcus-signal, ArcusCore

## 2026-06-25T16:12:18Z
- date: 2026-06-25T16:12:18Z
- repository reviewed: project-arcus
- workflow reviewed: Weekly bug scan (audit-only)
- commit window inspected: 2026-06-18T16:11:44Z through 2026-06-24T15:36:35Z
- files inspected:
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshPipeline.swift
  - /Users/justin/Code/project-arcus/Sources/Clients/WeatherClient.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeSnapshot.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Alert/AlertView.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Alert/AlertPresentationOrdering.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeSnapshotStore.swift
  - /Users/justin/Code/project-arcus/docs/codebase/skyaware-app-summary.md
  - /Users/justin/Code/project-arcus/Tests/UnitTests/HomeRefreshPipelineTests.swift
- top finding: `WeatherClient.currentWeather(for:)` collapses WeatherKit failures into `nil`, but `HomeIngestionExecutor.refreshWeatherIfNeeded` still marks the lane refreshed and `HomeRefreshPipeline.apply(_:, commitsVisibleSnapshot:)` clears `summaryWeather` on any refreshed nil payload, so a transient WeatherKit error wipes the visible current-conditions card instead of preserving the last known reading.
- best next fix: Carry explicit weather refresh success/failure state through the ingestion snapshot, and only clear `summaryWeather` when WeatherKit returns a successful empty result; keep the prior value on transport or API failure.
- implementation is recommended: Yes
- implementation status: completed on 2026-07-01
- implementation notes:
  - Introduced `HomeWeatherRefreshResult` to distinguish skipped, success, and failure outcomes.
  - Updated the ingestion pipeline and `HomeRefreshPipeline` to preserve stale weather on failure while still clearing on successful empty refreshes.
  - Added regression coverage for success, skipped, and failure paths.
- out-of-scope repositories intentionally not scanned: arcus-signal, ArcusCore

## 2026-07-02T16:10:07Z
- date: 2026-07-02T16:10:07Z
- repository reviewed: project-arcus
- workflow reviewed: Weekly bug scan (audit-only)
- commit window inspected: 2026-06-25T16:12:18Z through 2026-07-02T15:12:24Z
- files inspected:
  - /Users/justin/Code/project-arcus/Sources/Models/Convective/ConvectiveOutlookDTO.swift
  - /Users/justin/Code/project-arcus/Sources/Repos/ConvectiveOutlookRepo.swift
  - /Users/justin/Code/project-arcus/Sources/Features/ConvectiveOutlookView/ConvectiveOutlookView.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/ConvectiveOutlookRepoTests.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshPipeline.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift
  - /Users/justin/Code/project-arcus/Sources/Clients/WeatherClient.swift
- top finding: `ConvectiveOutlookDTO.id` now uses `link.absoluteString`, but the repo persists multiple historical outlook rows and the list view keys earlier rows by that id, so distinct revisions that share SPC’s generic day URL collide and SwiftUI can merge or hide them.
- best next fix: Derive DTO identity from an issue-specific key such as the feed GUID or a `title + published` composite, then add a regression test that loads two same-day outlooks with the same link but different publication times and verifies both remain visible.
- implementation is recommended: Yes
- out-of-scope repositories intentionally not scanned: arcus-signal, ArcusCore

## 2026-07-16T10:10:24Z
- date: 2026-07-16T10:10:24Z
- repository reviewed: project-arcus
- workflow reviewed: Weekly bug scan (audit-only)
- commit window inspected: 2026-07-02T16:10:07Z through 2026-07-16T09:55:34-06:00
- files inspected:
  - /Users/justin/Code/project-arcus/Sources/Features/Background/BackgroundOrchestrator.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Background/BackgroundLocationChangeHandler.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/AmRangeLocalRule.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/MorningComposer.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/MorningContext.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/SevenAmLocalRule.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeComposer.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeEngine.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeGate.swift
  - /Users/justin/Code/project-arcus/Sources/Infrastructure/Scheduling/BackgroundScheduler.swift
  - /Users/justin/Code/project-arcus/Sources/Policies/CadencePolicy.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/MorningNotificationTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/RiskChangeNotificationTests.swift
- top finding: No credible bug confirmed in the inspected window; the new morning/risk-change coalescing and cadence changes matched the current tests and the documented notification contract.
- best next fix: No fix recommended.
- implementation is recommended: No
- out-of-scope repositories intentionally not scanned: arcus-signal, ArcusCore

## 2026-07-23T10:09:07-06:00
- date: 2026-07-23T10:09:07-06:00
- repository reviewed: project-arcus
- workflow reviewed: Weekly bug scan (audit-only)
- commit window inspected: 2026-07-16T10:10:24Z through 2026-07-22T12:40:11-06:00
  (`def3ba51`, `367b1678`, `55539723`, `8bf056f7`, `f8114459`, `0697e440`)
- files inspected:
  - /Users/justin/Code/project-arcus/Sources/Features/Background/BackgroundOrchestrator.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/AmRangeLocalRule.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/MorningComposer.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/MorningContext.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/SevenAmLocalRule.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeComposer.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeEngine.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeGate.swift
  - /Users/justin/Code/project-arcus/Config/Info.plist
  - /Users/justin/Code/project-arcus/Sources/App/LaunchSplashView.swift
  - /Users/justin/Code/project-arcus/Sources/App/SkyAwareApp.swift
  - /Users/justin/Code/project-arcus/Sources/Infrastructure/Parsing/GeoJSON/GeoJSONModels.swift
  - /Users/justin/Code/project-arcus/Sources/Utilities/Geometry/GeoPolygonEntity.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Map/MapPolygonMapper.swift
  - /Users/justin/Code/project-arcus/Sources/Repos/FireRiskRepo.swift
  - /Users/justin/Code/project-arcus/Sources/Repos/SevereRiskRepo.swift
  - /Users/justin/Code/project-arcus/Sources/Repos/StormRiskRepo.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshPipeline.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift
  - /Users/justin/Code/project-arcus/Sources/Repos/HomeProjectionStore.swift
  - /Users/justin/Code/project-arcus/Sources/Providers/Location/LocationProvider.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/MorningNotificationTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/GeoJsonParserTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/MapPolygonMapperTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/HomeProjectionStoreTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/HomeRefreshPipelineTests.swift
- top finding: No credible bug confirmed; staged Today publication, polygon-hole exclusion, launch configuration,
  and morning/risk-change coalescing matched the inspected contracts and focused tests.
- best next fix: No fix recommended.
- implementation is recommended: No
- validation: Focused `xcodebuild test` passed for Home refresh, projection persistence, GeoJSON/map polygon,
  morning notification, and background cadence suites.
- out-of-scope repositories intentionally not scanned: arcus-signal, ArcusCore

## 2026-07-30T10:08:10-06:00
- date: 2026-07-30T10:08:10-06:00
- repository reviewed: project-arcus
- workflow reviewed: Weekly bug scan (audit-only)
- commit window inspected: 2026-07-23T10:09:07-06:00 through 2026-07-29T12:19:32-06:00
  (`126cd521`, `c82bbfe5`, `a4f3b2cd`, `63ddc029`)
- highest-risk changed areas:
  - bounded background refresh execution, cancellation ownership, retry/deadline handling, scheduling, and diagnostics
  - cached background location-context eligibility and privacy tolerance
  - Storm Setup alert eligibility, refresh gating, and user-visible presentation
- files inspected:
  - /Users/justin/Code/project-arcus/Sources/App/BackgroundRefreshLifecycle.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeStormSetupIngestion.swift
  - /Users/justin/Code/project-arcus/Sources/App/SkyAwareApp.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Background/BackgroundOrchestrator.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Background/BackgroundRefreshBudget.swift
  - /Users/justin/Code/project-arcus/Sources/Infrastructure/Location/BackgroundLocationContextReusePolicy.swift
  - /Users/justin/Code/project-arcus/Sources/Infrastructure/Location/LocationSession.swift
  - /Users/justin/Code/project-arcus/Sources/Infrastructure/Networking/HTTPDataDownloader.swift
  - /Users/justin/Code/project-arcus/Sources/Infrastructure/Scheduling/BackgroundScheduler.swift
  - /Users/justin/Code/project-arcus/Sources/Models/Health/BgHealthStore.swift
  - /Users/justin/Code/project-arcus/Sources/Models/StormSetup/StormSetupAlertEligibility.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/BackgroundLocationContextReusePolicyTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/BackgroundRefreshLifecycleTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/HomeIngestionCoordinatorTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/HTTPDataDownloaderTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/StormSetupAlertEligibilityTests.swift
- findings table: No credible bugs found (High: 0, Medium: 0, Low: 0).
- top finding: No credible bug confirmed; the deadline, cancellation, scheduler-successor, cached-location,
  and Storm Setup eligibility behavior matched the focused regression coverage added in the same commit window.
- top recommended fix: No fix recommended.
- best next fix: No fix recommended.
- watchlist: None; no low-confidence concern had enough local evidence to justify promotion.
- implementation is recommended: No
- validation: Unit-lane execution was attempted with the required iPhone 17 / iOS 26.5 destination, but
  CoreSimulatorService and Xcode/SwiftPM cache access were unavailable in the sandbox. No `.xcresult` test summary
  or pass/fail counts were produced.
- out-of-scope repositories intentionally not scanned: arcus-signal, ArcusCore, all other sibling repositories,
  and external services

## 2026-08-06T10:06:54-06:00
- Date: 2026-08-06T10:06:54-06:00
- Repository scanned: project-arcus
- Default branch: main (`origin/main`)
- Workflow reviewed: Weekly bug scan (audit-only)
- Commit window: after the 2026-07-30T10:08:10-06:00 audit marker through
  `63ddc0296592cf36ce26339d95d01b818d126c59` (2026-07-29T12:19:32-06:00); 0 commits.
- Fallback strategy: bounded current-state inspection of the three highest-risk areas: alert lifecycle and
  presentation, notification delivery/deduplication, and background refresh freshness/cancellation.
- Files inspected:
  - /Users/justin/Code/project-arcus/Sources/Repos/AlertRepo.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Alert/AlertPresentationOrdering.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/MorningGate.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/MorningEngine.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Meso/MesoGate.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Meso/MesoEngine.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Watch/WatchGate.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Watch/WatchEngine.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeGate.swift
  - /Users/justin/Code/project-arcus/Sources/Features/Background/BackgroundOrchestrator.swift
  - /Users/justin/Code/project-arcus/Sources/App/BackgroundRefreshLifecycle.swift
  - /Users/justin/Code/project-arcus/Sources/Infrastructure/Location/BackgroundLocationContextReusePolicy.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/MorningNotificationTests.swift
  - /Users/justin/Code/project-arcus/docs/plans/risk-profile-change-notifications-progress.md
- High-risk areas inspected:
  - alert terminal-state reconciliation, expiry filtering, geometry removal, and presentation order
  - morning, mesoscale discussion, watch, and risk-change notification delivery state and retry behavior
  - background work deadlines, cancellation recovery, successor scheduling, and cached-location freshness
- Findings:
  - Finding ID: BUG-ARCUS-NOTIFICATION-GATE-PREMATURE-DEDUPE
    Fingerprint: weekly-bug-scan|project-arcus|notification-gates|dedupe-state-committed-before-scheduling
    Repository: project-arcus
    Audit type: Weekly Bug Scan
    Title: Failed local notification scheduling permanently consumes the occurrence
    Status: NEW
    Severity: MEDIUM
    Confidence: HIGH
    First observed: 2026-08-06
    Last verified: 2026-08-06
    Affected files and symbols: `Sources/Notifications/Morning/MorningGate.swift` (`allow`),
      `Sources/Notifications/Morning/MorningEngine.swift` (`run`), with the same mechanism in `MesoGate`/`MesoEngine`
      and `WatchGate`/`WatchEngine`.
    Failure mode: each gate persists its delivered/deduplication stamp before the engine awaits
      `NotificationSending.send`; when scheduling returns `false`, the engine reports failure but the next eligible
      run is rejected as already delivered. Morning summaries are suppressed for the rest of the local day; meso and
      watch occurrences are suppressed indefinitely for the same event identity.
    Evidence: `MorningGate.allow` writes `skyaware.lastMorningNotifyLocalDay` before returning `true`, then
      `MorningEngine.run` awaits the sender. `MorningNotificationTests.engineReportsSchedulingFailure` proves the
      sender can return `false` but does not exercise a retry. The local risk-notification progress ledger explicitly
      records that morning, meso, and watch gates did not gain durable retry when risk-change delivery did.
    Blast radius: any authorization denial or `UNUserNotificationCenter.add` failure can lose one morning summary,
      mesoscale discussion, or watch notification on that device; no production or server data is corrupted.
    Minimal fix strategy: give these gates claim/finish semantics equivalent to the bounded risk-change gate, retaining
      failed occurrences for retry and marking them delivered only after scheduling succeeds. Keep each channel's
      existing key and retention rules.
    Required validation: deterministic failed-then-successful sender tests for morning, meso, and watch engines;
      duplicate suppression after success; concurrent-run claim tests; focused notification and background suites.
    Related GitHub issue: [#376](https://github.com/justinrooks/project-arcus/issues/376)
- Watchlist: None.
- Resolved findings: None.
- Top finding: BUG-ARCUS-NOTIFICATION-GATE-PREMATURE-DEDUPE.
- Best next fix: make notification delivery state reversible until local scheduling succeeds.
- Implementation recommended: Yes; tracked by [#376](https://github.com/justinrooks/project-arcus/issues/376).
- GitHub issues created: [#376](https://github.com/justinrooks/project-arcus/issues/376), labeled `bug`.
- GitHub issues updated: None.
- Existing issues referenced: None; connector-backed searches found no equivalent open or closed issue.
- Out-of-scope repositories: arcus-signal, ArcusCore, all sibling repositories, and external services.
- Skipped evidence: No sibling repository or external runtime was inspected. GitHub issue and pull-request
  deduplication was completed through the connected GitHub app because shell network access remained unavailable.

## 2026-08-13T10:08:19-06:00
- Date: 2026-08-13T10:08:19-06:00
- Repository scanned: project-arcus
- Default branch: main (`origin/main`)
- Workflow reviewed: Weekly bug scan (audit-only)
- Commit window: after the 2026-08-06T10:06:54-06:00 audit marker through
  `f222fdff802452119be82192cd49d8615c8c50f3` (2026-08-13T08:18:19-06:00); 2 commits
  (`5985b91d`, `f222fdff`).
- Files inspected:
  - /Users/justin/Code/project-arcus/Sources/Features/Diagnostics/LogViewerView.swift
  - /Users/justin/Code/project-arcus/Sources/Interfaces/Notification/NotificationGating.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/MorningGate.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Morning/MorningEngine.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Meso/MesoGate.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Meso/MesoEngine.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Watch/WatchGate.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Watch/WatchEngine.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/Sender.swift
  - /Users/justin/Code/project-arcus/Sources/App/Dependencies.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/LogViewerCancellationTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/MorningNotificationTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/MesoNotificationTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/AlertNotificationTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/UserDefaultsLocationUploadQueueStoreTests.swift
- High-risk areas inspected:
  - Log Viewer task ownership, detached-work cancellation, stale-result publication, and loading-state recovery
  - morning, mesoscale discussion, and watch notification claim, retry, persistence, and duplicate suppression
  - persisted location-upload queue round-trip coverage
- Findings: No new credible bugs found (HIGH: 0, MEDIUM: 0, LOW: 0).
- Watchlist: None.
- Resolved findings:
  - Finding ID: BUG-ARCUS-NOTIFICATION-GATE-PREMATURE-DEDUPE
    Fingerprint: weekly-bug-scan|project-arcus|notification-gates|dedupe-state-committed-before-scheduling
    Repository: project-arcus
    Audit type: Weekly Bug Scan
    Title: Failed local notification scheduling permanently consumes the occurrence
    Status: RESOLVED
    Severity: MEDIUM
    Confidence: HIGH
    First observed: 2026-08-06
    Last verified: 2026-08-13
    Affected files and symbols: `NotificationClaimState.claim`/`finish`, `MorningGate`, `MesoGate`, `WatchGate`,
      and their engines' `run` methods.
    Failure mode: The former implementation persisted deduplication before scheduling. Commit `f222fdff` replaces
      that path with in-flight claims which are persisted only after the sender reports success and released after
      failure.
    Evidence: Current `origin/main` engines call `finish` with the sender result; current gates delegate claim and
      finish state to `NotificationClaimState`; focused tests cover failed-then-successful retry, duplicate suppression
      after success, concurrent claim exclusion, and legacy persisted stamps.
    Blast radius: The prior lost-notification mechanism no longer exists on current `origin/main`; the remediation is
      limited to local morning, meso, and watch delivery state.
    Minimal fix strategy: Completed by `f222fdff`; no further fix recommended.
    Required validation: The focused simulator test run was attempted but could not start because the sandbox denied
      CoreSimulatorService and SwiftPM/Xcode cache access. No `.xcresult` counts were produced.
    Related GitHub issue: [#376](https://github.com/justinrooks/project-arcus/issues/376)
- Top finding: No credible new bug confirmed in the inspected commit window.
- Best next fix: No fix recommended.
- Implementation recommended: No.
- GitHub issues created: None.
- GitHub issues updated: None.
- Existing issues referenced: [#376](https://github.com/justinrooks/project-arcus/issues/376) for the resolved finding.
- Validation: Focused `SkyAware_Tests` execution was attempted for Log Viewer, morning, meso, and alert notification
  suites on iPhone 17 / iOS 26.5 / Debug. `xcodebuild` exited 74 before tests started because the sandbox denied
  CoreSimulatorService and SwiftPM/Xcode cache access. Result path:
  `/private/tmp/skyaware-results.GyseJx/weekly-bug-scan.xcresult`; no passed/failed/skipped counts were available.
- Out-of-scope repositories: arcus-signal, ArcusCore, all sibling repositories, and external services.
- Skipped evidence: No sibling repository, external service, physical device, or runtime behavior was inspected.

## 2026-08-20T10:07:42-06:00
- Date: 2026-08-20T10:07:42-06:00
- Repository scanned: project-arcus
- Default branch: main (`origin/main`)
- Workflow reviewed: Weekly bug scan (audit-only)
- Commit window: after the 2026-08-13T10:08:19-06:00 audit marker through
  `57b73e3a604c14c0d0e4d1791dc4e5464e81d47e` (2026-08-20T08:40:32-06:00); 3 commits
  (`e0d61412`, `56fa92a4`, `57b73e3a`).
- Files inspected:
  - /Users/justin/Code/project-arcus/Sources/Utilities/Core/WebContentRoute.swift
  - /Users/justin/Code/project-arcus/Sources/Interfaces/SPC/SpcSyncing.swift
  - /Users/justin/Code/project-arcus/Sources/Providers/SPC/SpcProvider+Syncing.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift
  - /Users/justin/Code/project-arcus/Sources/App/HomeRefreshV2/HomeSnapshot.swift
  - /Users/justin/Code/project-arcus/Sources/Models/Home/HomeProjection.swift
  - /Users/justin/Code/project-arcus/Sources/Repos/HomeProjectionStore.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeComposer.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeEngine.swift
  - /Users/justin/Code/project-arcus/Sources/Notifications/RiskChange/RiskChangeGate.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/WidgetRouteURLTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/HomeProjectionStoreTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/HomeRefreshPipelineTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/RiskChangeNotificationTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/SpcProviderSyncMapProductsTests.swift
  - /Users/justin/Code/project-arcus/Tests/UnitTests/StormSetupIngestionTests.swift
- High-risk areas inspected:
  - trusted-domain routing for the in-app web viewer, including subdomain and lookalike-host handling
  - per-domain SPC acceptance, rejection, persistence authority, freshness, and authoritative all-clear behavior
  - risk projection source/location identity, movement rebasing, notification coalescing, retry, and stale-pending removal
- Findings: No new credible bugs found (HIGH: 0, MEDIUM: 0, LOW: 0).
- Watchlist: None; no concern had enough local evidence to justify promotion.
- Resolved findings: None newly evaluated in this window.
- Top finding: No credible new bug confirmed in the inspected commit window.
- Best next fix: No fix recommended.
- Implementation recommended: No.
- GitHub issues created: None.
- GitHub issues updated: None.
- Existing issues referenced: None.
- Validation: Focused `SkyAware_Tests` execution was attempted for web-content policy, home projection/refresh,
  risk-change notification, SPC map sync, and Storm Setup ingestion on iPhone 17 / iOS 26.5 / Debug.
  `xcodebuild` exited 74 before tests started because the sandbox denied CoreSimulatorService and Xcode/SwiftPM
  cache access. Result path: `/private/tmp/skyaware-results.Mxt0Io/weekly-bug-scan.xcresult`; no finalized bundle
  or passed/failed/skipped counts were available.
- Out-of-scope repositories: arcus-signal, ArcusCore, all sibling repositories, and external services.
- Skipped evidence: No sibling repository, external service, physical device, or runtime behavior was inspected.
  Release-document-only changes in `57b73e3a` were reviewed for scope but did not introduce executable behavior.
