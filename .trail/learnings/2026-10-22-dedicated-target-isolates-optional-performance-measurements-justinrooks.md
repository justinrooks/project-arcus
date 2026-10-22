---
title: Dedicated target isolates optional performance measurements
author: Justinrooks
date: 2026-10-22
branch: issue-767
touches:
  - AGENTS.md
  - SkyAware.xcodeproj/project.pbxproj
  - SkyAware.xcodeproj/xcshareddata/xcschemes/SkyAware.xcscheme
  - Tests/SkyAware_Tests.xctestplan
  - Tests/UnitTests/HomeProjectionStoreScalingMeasurementTests.swift
  - Tests/UnitTests/MapAcceptedUpdateMeasurementTests.swift
  - Tests/UnitTests/MapSceneWarmingMeasurementTests.swift
  - Tests/UnitTests/RiskPolygonOverlayTests.swift
  - ci_scripts/verify_xcresult.sh
  - tools/ci/run_test_lane.sh
---

## Decided
Issue #767 uses a dedicated SkyAwarePerformanceTests target and performance test plan so developers choose the performance lane explicitly. Keep the default SkyAware_Tests plan focused on regression tests. Compile-time target conditions keep timing measurements out of the ordinary unit bundle while retaining their regression counterparts there.

## Tried and ruled out
A flat selectedTests list did not reliably execute the mixed XCTest and Swift Testing measurements on this Xcode version. Plan skip lists alone were also insufficient for excluding them from the ordinary unit run. Exact native result verification checks the performance target and all six measurement identifiers.

## Watch out
Earlier issue-767 learning about flat-plan selector limitations described the initial workaround, not the final architecture. The dedicated target and compile-time partition supersede that workaround. Do not infer that adding performance cases to the default target is required.
