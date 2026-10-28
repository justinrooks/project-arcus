---
title: Enrollment test membership and redirect guard satisfy prior learnings
author: Justinrooks
date: 2026-10-28
branch: issue-796
touches:
  - SkyAware.xcodeproj/project.pbxproj
  - SkyAware.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
  - Sources/App/ArcusSignalConfiguration.swift
  - Sources/Infrastructure/Activity/ForegroundActivityReporter.swift
  - Sources/Infrastructure/Location/HTTPDevicePreferenceSyncUploader.swift
  - Sources/Infrastructure/Location/HTTPLocationSnapshotUploader.swift
  - Sources/Infrastructure/Networking/HTTPDataDownloader.swift
  - Sources/Notifications/RemoteNotificationRegistrar.swift
  - Tests/UnitTests/ForegroundActivityReporterTests.swift
  - Tests/UnitTests/NwsHttpClientTests.swift
---

## Decided
The #796 change explicitly registers InstallationEnrollmentTests.swift in both required Xcode membership exception lists; native focused XCResult discovers the new suite. The three uploaders send only to installation v2 routes and share an enrollment authority. The existing URLSession task delegate refuses installation POST redirects before any destination request.

## Tried and ruled out
trail check reported lexical conflicts against the older test-membership learning and the new redirect learning. These matches are false positives: project membership is explicitly updated, and redirect refusal is implemented in the common transport instead of duplicated in each uploader. No learning policy is being overridden.

## Watch out
Review Xcode membership through native test discovery, not merely the presence of a Swift test file. Verify redirect confinement through the delegate protocol witness and a native synthetic redirect probe; checking the initial URL or assuming header stripping protects enrollment JSON is insufficient.
