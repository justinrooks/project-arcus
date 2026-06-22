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
