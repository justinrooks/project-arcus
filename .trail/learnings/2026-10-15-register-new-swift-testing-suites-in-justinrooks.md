---
title: Register new Swift Testing suites in SkyAware
author: Justinrooks
date: 2026-10-15
branch: issue-695-redesign
touches:
  - SkyAware.xcodeproj/project.pbxproj
  - Sources/Features/Onboarding/OnboardingStepShell.swift
  - Tests/UnitTests/OnboardingSecondaryActionStyleTests.swift
---

## Decided
- When adding a unit-test source under `Tests/UnitTests`, exclude it from the `SkyAware` app target and add an explicit file reference/build entry to the `SkyAwareTests` Sources phase in `SkyAware.xcodeproj/project.pbxproj`.

## Tried and ruled out
- Adding a Swift Testing file under `Tests/UnitTests` alone did not make it part of the unit-test bundle; the full lane could pass without discovering the new suite.

## Watch out
- Verify focused result bundles report the intended nonzero test count and suite names. A passing broad lane does not prove a newly added test was compiled or discovered.
