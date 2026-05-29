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
