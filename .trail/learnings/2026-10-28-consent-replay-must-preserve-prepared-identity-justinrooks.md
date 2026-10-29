---
title: Consent replay must preserve prepared identity and follow-up intent
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
SkyAware #794 records successful dedupe from the actual prepared transfer, not historical queue consent or completion-time settings. If current intent differs from an active transfer sharing its historical coalescing key, retain one follow-up and keep its durable pending record until that work completes. Invalidate semantic dedupe on effective consent transitions, including replay and suppressed work. Stepped recording transports exercise both opt-in and opt-out round trips.

## Tried and ruled out
Comparing saved request consent to current settings at completion can falsely acknowledge an opt-out even though the transport sent opt-in. Fixing dedupe identity alone still drops same-key follow-up intent. Keeping successful semantic entries across true/false/true transitions can suppress the final intent.

## Watch out
trail check in 0.22 reports lexical conflicts for these safety tests against unrelated location/manual-refresh/test-wrapper notes and against the earlier 0.6.0 enrollment baseline. The owner explicitly selected 0.7.0 for #794. The changes retain the existing test runner, enrollment/redirect protections, and original UI refresh ownership. These are documented false positives, not exemptions from real privacy or test-evidence invariants.
