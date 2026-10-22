---
title: Validate focused performance lane selections against xcresult membership
author: Justinrooks
date: 2026-10-22
branch: issue-767
touches:
  - AGENTS.md
  - Tests/SkyAware_Tests.xctestplan
  - tools/ci/README.md
  - tools/ci/run_test_lane.sh
---

## Decided
The dedicated performance target can support focused `-only-testing` and `-skip-testing` selections when the runner maps target-qualified selectors to the canonical planned measurement IDs and verifies the exact remaining XCResult membership. Keep the unit plan free of duplicate skip lists and preserve verifier-side exclusion checks.

## Tried and ruled out
Keeping performance selection full-suite-only would avoid selector parsing, but it unnecessarily blocks targeted investigations. Retaining both plan and runner skip lists duplicates the compile-time target boundary without improving result validation.

## Watch out
Trail check may flag the new target and verifier arrangement because older learnings describe the pre-split workaround. Those conflicts are stale relative to the dedicated target decision: the unit lane should exclude the performance IDs through native XCResult verification, while the performance lane verifies only the requested subset. Record this rationale in the PR description when those lexical conflicts remain.
