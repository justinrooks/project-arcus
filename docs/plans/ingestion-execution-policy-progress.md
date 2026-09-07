# Ingestion Execution Policy Progress

## Overview

Tracks explicit execution ownership and removal of avoidable foreground context latency.

**Epic status:** Planned
**Primary GitHub epic:** [#421](https://github.com/justinrooks/project-arcus/issues/421)

## Global Decisions

- Provenance remains diagnostic; execution class and deadline ownership are independent.
- Foreground owner wins mixed-run latency policy.
- Prime/follow-up remains until Release/device evidence justifies replacement.
- Prime context should feed the follow-up.
- Durable foreground context requires a policy decision before implementation.
- All implementation uses `GPT-5.6 Terra / medium`.

## Current State

Plans merge provenance independently from execution class, with foreground ownership selecting foreground HTTP behavior and clearing retained background deadlines. The executor scopes HTTP mode across context resolution and provider work. Scene activation constructs its full request before prime completes, causing avoidable second preparation.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#438](https://github.com/justinrooks/project-arcus/issues/438) — Add explicit ingestion execution class | Awaiting human review | None |
| 2 | [#436](https://github.com/justinrooks/project-arcus/issues/436) — Scope HTTP policy across location resolution | Implemented locally; awaiting human review | 01 |
| 3 | [#439](https://github.com/justinrooks/project-arcus/issues/439) — Reuse prime context for scene-active follow-up | Pending | 02 |
| 4 | [#437](https://github.com/justinrooks/project-arcus/issues/437) — Parallelize independent NWS zone-label requests | Ready for commit | None |
| 5 | [#440](https://github.com/justinrooks/project-arcus/issues/440) — Define the foreground durable-context policy | Implemented locally; awaiting human review | 03 |

## Existing Code Map

- Plan merging: `Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift`
- Ownership/deadlines: `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- Execution policy: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Foreground lifecycle: `Sources/App/HomeRefreshPipeline.swift`
- Context/NWS: `Sources/Infrastructure/Location/LocationContextResolver.swift`, `Sources/Repos/NwsMetadataRepo.swift`

## Status Ledger

### [#438](https://github.com/justinrooks/project-arcus/issues/438) — Add explicit ingestion execution class
- Status: Implemented locally; complete unit validation passed; awaiting human review.
- Handoff: Execution class now merges independently from provenance; preserve waiter/cancellation semantics.

### [#436](https://github.com/justinrooks/project-arcus/issues/436) — Scope HTTP policy across location resolution
- Status: Implemented locally; focused validation passed; awaiting human review.

### [#439](https://github.com/justinrooks/project-arcus/issues/439) — Reuse prime context for scene-active follow-up
- Status: Implemented locally; awaiting human review.
- Handoff: Scene-active follow-up now receives the context resolved by prime; preserve deferred movement refresh.

### [#437](https://github.com/justinrooks/project-arcus/issues/437) — Parallelize independent NWS zone-label requests
- Status: Ready for commit.

### [#440](https://github.com/justinrooks/project-arcus/issues/440) — Define the foreground durable-context policy
- Status: Implemented locally; awaiting human re-review.
- Handoff: Current v1 durable entries explicitly reject the fast path because they cannot prove capture authorization
  or current grid compatibility. A future versioned cache and trusted current H3 plus NWS `(gridId, gridX, gridY)`
  evidence may permit only a
  complete, same-authorization, at-most-15-second context with no movement evidence. Reuse has no upload side effect
  and requires an independent refresh-behind; all other authorized cases resolve fresh. Runtime reuse remains out of scope.

## Verification Ledger

### [#438](https://github.com/justinrooks/project-arcus/issues/438)
- `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/HomeIngestionCoordinatorTests` — passed.
- `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/HomeRefreshPipelineTests` — 100 executed, 100 passed.
- `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/StormSetupIngestionTests` — 47 executed, 47 passed.
- `tools/ci/run_test_lane.sh unit` — 1,096 executed, 1,096 passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" build` — passed.
- `git diff --check` — passed.

### [#436](https://github.com/justinrooks/project-arcus/issues/436)
- `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/HomeRefreshPipelineTests` — 71 executed, 71 passed; finalized result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.gKlyx7/unit.xcresult`.
- `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/HomeIngestionCoordinatorTests -only-testing:SkyAwareTests/LocationContextResolverTests -only-testing:SkyAwareTests/NwsHttpClientTests` — 46 executed, 46 passed; finalized result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.v6aT8t/unit.xcresult`.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" build` — passed.
- `git diff --check` — passed.

### [#439](https://github.com/justinrooks/project-arcus/issues/439)
- `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/HomeRefreshPipelineTests` — 72 executed, 72 passed; finalized result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.mdY9yo/unit.xcresult`.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build` — passed.
- `git diff --check` — passed.

### [#437](https://github.com/justinrooks/project-arcus/issues/437)
- `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/LocationContextResolverTests` — 11 executed, 11 passed; finalized result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.cz6Vom/unit.xcresult`.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" build` — passed.
- `git diff --check` — passed.

### [#440](https://github.com/justinrooks/project-arcus/issues/440)
- `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/ForegroundDurableContextReusePolicyTests` — 10 executed,
  10 passed; finalized result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.xeaLkb/unit.xcresult`.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" build` — passed.
- `git diff --check` — passed.
