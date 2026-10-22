---
title: Document the three SkyAware validation lanes
author: Justinrooks
date: 2026-10-22
branch: issue-767
touches:
  - AGENTS.md
  - README.md
  - tools/ci/README.md
  - tools/ci/run_test_lane.sh
---

## Decided
Repository-owned agent guidance and the CI README define the local lane policy: run SkyAware_Tests for full regression validation, choose SkyAware_Performance for performance investigations or changes affecting measured behavior, and keep SkyAware_UI_Smoke separate. Focused selections use tools/ci/run_test_lane.sh so each result receives native XCResult verification.

## Tried and ruled out
The runner already exposed unit, performance, and ui-navigation with the required result verification, so no script behavior change or extra test framework was needed. The root README's description of SkyAware_All_Tests as the UI smoke lane was stale; SkyAware_UI_Smoke is the dedicated navigation lane.

## Watch out
Regression counts are deterministic behavior evidence. Performance measurements depend on simulator and host conditions; report their environment and attachments without treating a pass as proof of improvement. Keep historical audit evidence and Xcode Cloud topology changes in their existing records and #768 scope.
