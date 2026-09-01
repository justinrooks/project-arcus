# Ingestion Durable Scheduling Progress

## Overview

Tracks durable location-scoped refresh admission and explicit per-feed fallback policy.

**Epic status:** Planned
**Primary GitHub epic:** [#423](https://github.com/justinrooks/project-arcus/issues/423)

## Global Decisions

- Schedule from accepted state, not attempt completion.
- Failed, rejected, and fallback-only attempts remain retry eligible.
- Map, outlook, hot, and weather state remain distinct and location-scoped where applicable.
- No single global fallback age.
- All implementation uses `GPT-5.6 Terra / medium`.

## Current State

Executor freshness is process-local. App restart loses admission state. Maps and outlooks share a slow clock. URL cache fallback has no explicit feed-specific acceptance-age contract.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#447](https://github.com/justinrooks/project-arcus/issues/447) — Drive hot scheduling from durable feed state | Pending | Feed-state/provenance epic |
| 2 | [#446](https://github.com/justinrooks/project-arcus/issues/446) — Drive map and outlook scheduling independently from durable state | Pending | Feed-state/provenance epic |
| 3 | [#448](https://github.com/justinrooks/project-arcus/issues/448) — Drive WeatherKit scheduling from durable state | Pending | Feed-state sidecar and projection acknowledgement |
| 4 | [#442](https://github.com/justinrooks/project-arcus/issues/442) — Define feed-specific HTTP fallback age policies | Pending | 01–03 evidence |

## Existing Code Map

- Admission: `Sources/App/HomeRefreshV2/HomeFreshnessState.swift`, `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Policy: `Sources/Policies/RefreshPolicy.swift`
- Transport fallback: `Sources/Infrastructure/Networking/HTTPDataDownloader.swift`
- Durable metadata: new feed-state sidecar from predecessor epic

## Status Ledger

### [#447](https://github.com/justinrooks/project-arcus/issues/447) — Drive hot scheduling from durable feed state
- Status: Pending
- Handoff: Targeted remote alerts do not mark complete hot state fresh.

### [#446](https://github.com/justinrooks/project-arcus/issues/446) — Drive map and outlook scheduling independently from durable state
- Status: Pending

### [#448](https://github.com/justinrooks/project-arcus/issues/448) — Drive WeatherKit scheduling from durable state
- Status: Pending

### [#442](https://github.com/justinrooks/project-arcus/issues/442) — Define feed-specific HTTP fallback age policies
- Status: Pending policy gate
- Handoff: Split by feed if evidence cannot support one reviewable issue.

## Verification Ledger

No implementation validation yet.

