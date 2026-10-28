---
title: Confine installation enrollment secrets and preserve retry authority
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
SkyAware #796 consumes ArcusCore 0.6.0 enrollment types. One shared coordinator persists a 32-byte base64url credential before enrollment, persists acknowledgment separately, and shares pending enrollment across callers. A separate Keychain marker makes credential loss fail closed. Queued installation UUIDs must match current durable authority. Only installation writes move to authenticated v2; public weather APIs retain their versions.

## Tried and ruled out
Checking the initial HTTPS origin is insufficient: native Foundation forwards a credential-bearing JSON POST body on a cross-origin 307 even when it strips Authorization. Refuse every redirect for POSTs under /v2/devices/ and /api/v2/devices/ in the existing URLSession task delegate. Compare retry JSON as decoded shared DTOs, not raw bytes whose key ordering is unspecified.

## Watch out
Compatible Signal v2 deployment is required before device installation/release. Shared contract availability permits authorized client development ahead of deployment. Authentication does not solve #794 client consent replay or Signal #379 in-flight consent ordering. Retain shared enrollment ownership until unwind even if a caller cancels; canceled callers must not make a protected write. Use isolated Keychain services in tests so no default production credential is touched.
