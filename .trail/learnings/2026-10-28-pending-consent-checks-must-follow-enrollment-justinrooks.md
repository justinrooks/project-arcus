---
title: Pending consent checks must follow enrollment waits
author: Justinrooks
date: 2026-10-28
branch: issue-794
touches:
  - SkyAware.xcodeproj/project.pbxproj
  - SkyAware.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
  - Sources/Infrastructure/Location/HTTPDevicePreferenceSyncUploader.swift
  - Sources/Infrastructure/Location/HTTPLocationSnapshotUploader.swift
  - Sources/Infrastructure/Location/LocationSnapshotPusher.swift
  - Tests/UnitTests/InstallationEnrollmentTests.swift
  - Tests/UnitTests/LocationProviderTests.swift
  - docs/security/installation-enrollment.md
---

## Decided
SkyAware #794 uses ArcusCore 0.7.0 while retaining its legacy DTOs and authenticated v2 routes. The v3 revision authority and route migration belong to #798. Pending location work must recheck current sharing and Core Location authorization before every further transfer, including force uploads, retry backoff, and source fallback. Preference replay uses current subscription and authorization; saved queue consent is historical metadata.

## Tried and ruled out
Checking only before invoking an uploader leaves enrollment as a suspension point that can stale consent. HTTP uploaders accept payload preparation after enrollment. Suppressed work is discarded without recording successful-upload dedupe state. Unit queue fixtures must explicitly grant location permission when expecting a location transfer.

## Watch out
An HTTP request already handed to transport cannot be recalled or ordered by these client checks. Signal #379 and SkyAware #798 own v3 monotonic acceptance. Do not claim APNs recall, production verification, or v3 adoption from #794 tests. The durable queue encoding stays unchanged.
