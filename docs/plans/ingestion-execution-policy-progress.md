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

Plans union provenance, while any background provenance selects background HTTP behavior. Context resolution occurs before the executor scopes HTTP mode. Scene activation constructs its full request before prime completes, causing avoidable second preparation.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#438](https://github.com/justinrooks/project-arcus/issues/438) — Add explicit ingestion execution class | Pending | None |
| 2 | [#436](https://github.com/justinrooks/project-arcus/issues/436) — Scope HTTP policy across location resolution | Pending | 01 |
| 3 | [#439](https://github.com/justinrooks/project-arcus/issues/439) — Reuse prime context for scene-active follow-up | Pending | 02 |
| 4 | [#437](https://github.com/justinrooks/project-arcus/issues/437) — Parallelize independent NWS zone-label requests | Pending | None |
| 5 | [#440](https://github.com/justinrooks/project-arcus/issues/440) — Define the foreground durable-context policy | Pending | 03 |

## Existing Code Map

- Plan merging: `Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift`
- Ownership/deadlines: `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- Execution policy: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Foreground lifecycle: `Sources/App/HomeRefreshPipeline.swift`
- Context/NWS: `Sources/Infrastructure/Location/LocationContextResolver.swift`, `Sources/Repos/NwsMetadataRepo.swift`

## Status Ledger

### [#438](https://github.com/justinrooks/project-arcus/issues/438) — Add explicit ingestion execution class
- Status: Pending
- Handoff: Preserve waiter/cancellation semantics and deliberately update mixed-provenance tests.

### [#436](https://github.com/justinrooks/project-arcus/issues/436) — Scope HTTP policy across location resolution
- Status: Pending

### [#439](https://github.com/justinrooks/project-arcus/issues/439) — Reuse prime context for scene-active follow-up
- Status: Pending
- Handoff: Preserve deferred movement refresh.

### [#437](https://github.com/justinrooks/project-arcus/issues/437) — Parallelize independent NWS zone-label requests
- Status: Pending

### [#440](https://github.com/justinrooks/project-arcus/issues/440) — Define the foreground durable-context policy
- Status: Pending decision gate
- Handoff: Stop before changing authorization, movement, capture, or upload timestamp semantics.

## Verification Ledger

No implementation validation yet.

