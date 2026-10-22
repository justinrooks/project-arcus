---
title: Keep timing measurements out of default unit lane
author: Justinrooks
date: 2026-10-22
branch: issue-767
touches:
  - AGENTS.md
  - SkyAware.xcodeproj/xcshareddata/xcschemes/SkyAware.xcscheme
  - Tests/SkyAware_Tests.xctestplan
  - ci_scripts/verify_xcresult.sh
  - tools/ci/run_test_lane.sh
  - Tests/SkyAware_Performance.xctestplan
---

## Decided
- Keep the six issue-767 timing measurements in the on-demand performance lane and explicitly exclude them from the default unit runner.
- Verify performance results by exact test identifiers and zero skips; verify unit results by asserting those six identifiers are absent.

## Tried and ruled out
- The legacy flat selectedTests list did not reliably represent the mixed Swift Testing and XCTest measurement set on this Xcode version; it launched only a subset. Keep explicit `-only-testing` identifiers in the runner.
- The default test-plan skippedTests entries did not reliably exclude all six from execution, so the unit runner also carries explicit `-skip-testing` identifiers.

## Watch out
- The repository's Xcode result summary and RTK wrapper can report contradictory counts. Treat finalized xcresult summary and test trees as authoritative.
