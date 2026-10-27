---
title: "Research 785: pending location supersession can strand Home waiters"
author: Justinrooks
date: 2026-10-24
branch: issue-779
---

## Decided
Research #785 at main 65086366ba45 reproduced one client-only defect, tracked as native child #786. HomeIngestionCoordinator preserves an explicit-location waiter's original plan when newer location-bearing work replaces the sole pending plan. Finishing the replacement can leave remainingWaiters=1 with pendingPlan=nil. A temporary Swift 6 executable compiled the unchanged coordinator and trigger files with synthetic dependencies and continuation gates; both explicit-context and production-shaped background-location replacement reproduced it. No implementation was made. The authoritative report is https://github.com/justinrooks/project-arcus/issues/785#issuecomment-6391043100.

## Tried and ruled out
Existing #333 caller-cancellation and #369 active-background ownership fixes are not the missing behavior; both are closed and preserve useful shared work. The existing newest-location test uses fire-and-forget requests and cannot observe a leaked continuation. Ten selected existing suites passed: 312 logical tests, 360 parameter-expanded executions, zero failures. RTK summaries incorrectly reported failures from passing lines; finalized XCResult and verify_xcresult.sh supplied the evidence.

## Watch out
Preserve newest-location-wins coalescing and complete superseded callers exactly once; do not execute obsolete locations merely to satisfy them. Home activity counts unwind only after follow-up awaits terminate, so the defect can suppress deferred movement refresh. Device incidence was not measured. Separate widget writers lack an obvious shared revision fence, but their overlapping publication schedule remains an unconfirmed risk with a bounded test proposal, not a second confirmed issue. This was research-only; #786 requires human implementation authorization.
