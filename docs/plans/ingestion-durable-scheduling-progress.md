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

Coherent hot admission now uses location-scoped durable accepted state. Map and outlook admission use independent durable SPC feed records. Weather scheduling remains process-local. URL cache fallback has no explicit feed-specific acceptance-age contract.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#447](https://github.com/justinrooks/project-arcus/issues/447) — Drive hot scheduling from durable feed state | Implemented; awaiting human review | Feed-state/provenance epic |
| 2 | [#446](https://github.com/justinrooks/project-arcus/issues/446) — Drive map and outlook scheduling independently from durable state | Implemented; awaiting human review | Feed-state/provenance epic |
| 3 | [#448](https://github.com/justinrooks/project-arcus/issues/448) — Drive WeatherKit scheduling from durable state | Pending | Feed-state sidecar and projection acknowledgement |
| 4 | [#442](https://github.com/justinrooks/project-arcus/issues/442) — Define feed-specific HTTP fallback age policies | Pending | 01–03 evidence |

## Existing Code Map

- Admission: `Sources/App/HomeRefreshV2/HomeFreshnessState.swift`, `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Policy: `Sources/Policies/RefreshPolicy.swift`
- Transport fallback: `Sources/Infrastructure/Networking/HTTPDataDownloader.swift`
- Durable metadata: new feed-state sidecar from predecessor epic

## Status Ledger

### [#447](https://github.com/justinrooks/project-arcus/issues/447) — Drive hot scheduling from durable feed state
- Status: Implemented; awaiting human review
- Handoff: Coherent hot attempts and projection-acknowledged acceptance use a location-scoped feed-state record. Fallback, failure, cancellation, and projection failure remain retry eligible after restart. Targeted-only remote alerts do not advance coherent hot state.

### [#446](https://github.com/justinrooks/project-arcus/issues/446) — Drive map and outlook scheduling independently from durable state
- Status: Implemented; awaiting human review
- Handoff: Map admission requires accepted convective and fire records; Outlook has a separate accepted record. Admitted attempts become retry eligible if interrupted, and failed records remain due after restart. Forced slow refresh still attempts both feeds.

### [#448](https://github.com/justinrooks/project-arcus/issues/448) — Drive WeatherKit scheduling from durable state
- Status: Pending

### [#442](https://github.com/justinrooks/project-arcus/issues/442) — Define feed-specific HTTP fallback age policies
- Status: Pending policy gate
- Handoff: Split by feed if evidence cannot support one reviewable issue.

## Verification Ledger

- [#447](https://github.com/justinrooks/project-arcus/issues/447): focused `HomeRefreshPipelineTests` lane passed (91 tests), full unit lane passed (1,258 tests), and Debug simulator build passed; both finalized `.xcresult` bundles reported zero failures and skips.
- [#446](https://github.com/justinrooks/project-arcus/issues/446): focused slow-admission and SPC provider lanes passed (137 tests), full unit lane passed (1,264 tests), and Debug simulator build passed. Final unit result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.2hN0pN/unit.xcresult` (zero failures and skips).
