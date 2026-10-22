---
title: Cloud regression coverage contract and action routing
author: Justinrooks
date: 2026-10-22
branch: issue-768
touches:
  - ci_scripts/ci_post_xcodebuild.sh
  - ci_scripts/verify_xcresult.sh
  - tools/ci/README.md
  - tools/ci/run_test_lane.sh
---

## Decided
Issue #768 adds a required regression coverage contract to the Xcode Cloud SkyAware_Tests action: validate CI_TEST_PLAN against the XCResult plan, target, five stable sentinels, a documented minimum logical count, and the known gated skip. Keep the separate SkyAware_UI_Smoke action on native result checks for its own plan and target. This issue explicitly supersedes issue #767's earlier conclusion that no verifier script behavior change was needed.

## Tried and ruled out
Routing every test-without-building action through the regression contract rejects the documented UI smoke plan. Inferring the action from its result would allow a wrong plan to masquerade as the UI action; use Xcode Cloud's CI_TEST_PLAN environment value and compare it with the bundle. Do not duplicate the six measurement identifiers in the Cloud contract: PERFORMANCE_TESTS compile-time partitioning keeps them out of SkyAwareTests, while the local runner still asserts their absence.

## Watch out
Keep Build 238 device, runtime, and Xcode values explicitly historical; repository artifacts do not establish current external Cloud settings. The 1,470 logical-test floor is a tolerant bound based on the post-extraction expected 1,479 cases, not a frozen total. Do not claim Cloud time or compute savings before a post-change action provides that evidence.
