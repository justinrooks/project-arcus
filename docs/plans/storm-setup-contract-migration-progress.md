# Storm Setup Contract Migration Progress

## Overview

This ledger tracks Project Arcus migration to ArcusCore `StormSetupCurrentResponse` and removal of the app's direct
`dev/anvil/profile-analysis` integration.

**Epic status:** Planned

**Primary GitHub epic:** [#283](https://github.com/justinrooks/project-arcus/issues/283)

## Global Decisions

- Dependency adoption is owner-managed and precedes issue 01.
- The app decodes ArcusCore's aggregate response directly.
- `.moderate` is the contract value and retains the existing medium-confidence user-facing wording.
- ArcusCore owns the externally tagged viability enum Codable behavior.
- Numeric SHIP remains in the Detailed Ingredients profile section.
- Primary Drivers redesign is deferred; no inferred replacement is allowed.
- A newer aggregate with nil profile analysis must not reuse an older cached profile.
- Reinstall/clear local development data if removal of obsolete cached properties requires it; do not build an
  elaborate migration framework for this single-device deployment.
- Existing Storm Setup UI structure and cache-forward behavior remain intact.

## Current State Summary

Project Arcus currently makes two independent requests, persists two payloads, maintains two refresh/backoff state
graphs, validates run/valid-time/forecast-hour agreement, and merges the values in detail presentation. ArcusCore
`0.4.1` and the current Arcus Signal response provide setup metadata, canonical/diagnostic ingredients, optional
profile analysis, and tornado viability in one response.

The public contract fully replaces every value obtained from the development profile endpoint. Two old presentation
values are not exact contract matches: Primary Drivers is absent, and categorical SHIP support is absent. This
campaign defers Primary Drivers and preserves numeric SHIP.

## Issue Sequence

| Order | Issue | Title | Preferred model | Status | Dependency |
|---:|---|---|---|---|---|
| 0 | [#283](https://github.com/justinrooks/project-arcus/issues/283) | Epic: Migrate Storm Setup to the ArcusCore aggregate contract | Coordination only | Planned | Owner dependency update |
| 1 | [#284](https://github.com/justinrooks/project-arcus/issues/284) | Align Storm Setup presentation with ArcusCore | `5.4 mini medium` | Complete | Presentation path aligned with ArcusCore values |
| 2 | [#285](https://github.com/justinrooks/project-arcus/issues/285) | Decode the aggregate response in the primary client | `5.4 mini medium` | Planned | #284 |
| 3 | [#286](https://github.com/justinrooks/project-arcus/issues/286) | Persist one aggregate Storm Setup payload | `5.4 mini medium` | Planned | #285 |
| 4 | [#287](https://github.com/justinrooks/project-arcus/issues/287) | Cut Storm Setup ingestion to one request | `5.6 luna medium` | Planned | #286 |
| 5 | [#288](https://github.com/justinrooks/project-arcus/issues/288) | Remove Anvil plumbing and audit the final behavior | `5.4 mini medium` | Planned | #287 |

## Existing Code Map

- Contract dependency: `SkyAware.xcodeproj` and `Package.resolved`
- Current endpoint client: `Sources/Clients/StormSetupClient.swift`
- Development endpoint client: `Sources/Clients/StormSetupProfileAnalysisClient.swift`
- Local DTOs: `Sources/Models/StormSetup/StormSetupDTO.swift` and
  `Sources/Models/StormSetup/StormSetupProfileAnalysisDTO.swift`
- Merge/cache policy: `Sources/Models/StormSetup/StormSetupProfileAnalysisPolicy.swift`
- Ingestion: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Persistence: `Sources/Models/Home/HomeProjection.swift` and `Sources/Repos/HomeProjectionStore.swift`
- Observable state: `Sources/App/HomeRefreshPipeline.swift` and `Sources/App/HomeView.swift`
- Presentation: `Sources/Features/StormSetup/StormSetupPresentation.swift` and
  `Sources/Features/StormSetup/StormSetupDetailPresentation.swift`

## Investigation Notes

- The exact join occurs in `HomeIngestionExecutor.refreshStormSetupIfNeeded` after parallel primary/profile outcomes.
- `StormSetupProfileAnalysisPolicy` exists to match independently fetched source times and becomes obsolete atomically.
- `SnapshotConfidence.moderate` does not match the old local string normalizer's `medium` case.
- `TornadoViabilityRealization` and `TornadoViabilityFailureMode` use one-key object payloads; direct ArcusCore decoding
  avoids local wire-shape drift.
- `profileAnalysis.ship` is the authoritative source for the existing numeric SHIP detail row.
- Strict ArcusCore enums create mixed-version deployment coupling, but no mixed-version production requirement exists
  for this single-device development deployment.

## Status Ledger

### Issue #284 — 01: Align Storm Setup presentation with ArcusCore

- Status: Complete
- Outcome: Storm Setup summary and detail presentation now consume ArcusCore aggregate values on the new presentation path while preserving the existing DTO-backed runtime path for the staged cutover.
- Validation: `StormSetupPresentationTests`, `StormSetupDetailPresentationTests`, and a Debug build all passed. No `.xcresult` failures were reported.
- Handoff: Preserve the existing view structure and keep the next issue scoped to the client cutover.

### Issue #285 — 02: Decode the aggregate response in the primary client

- Status: Planned
- Outcome: Pending
- Validation: Pending
- Handoff: Keep old orchestration temporarily so the client cutover remains reviewable.

### Issue #286 — 03: Persist one aggregate Storm Setup payload

- Status: Planned
- Outcome: Pending
- Validation: Pending
- Handoff: Prefer reinstall/clear over generalized legacy-cache migration work.

### Issue #287 — 04: Cut Storm Setup ingestion to one request

- Status: Planned
- Outcome: Pending
- Validation: Pending
- Handoff: Preserve H3, freshness, timeout, cancellation, backoff, and cache-forward semantics.

### Issue #288 — 05: Remove Anvil plumbing and audit the final behavior

- Status: Planned
- Outcome: Pending
- Validation: Pending
- Handoff: Delete obsolete tests only after equivalent aggregate behavior is covered.

## Verification Ledger

| Date | Issue | Verification | Result |
|---|---|---|---|
| 2026-07-10 | Planning | Investigation across Project Arcus, ArcusCore, and the relevant Arcus Signal route/tests | Complete |
| 2026-07-10 | #284 | `StormSetupPresentationTests`, `StormSetupDetailPresentationTests`, and `xcodebuild ... build` | Complete |

## Handoff Notes

- Start only after the owner has made ArcusCore `0.4.1` available to the project.
- Execute issues sequentially.
- Update this ledger with changed files, behavior, exact tests, `.xcresult` evidence, and remaining risks before closing
  each issue.
- Stop and re-plan if implementation requires server changes, mixed-version compatibility, UI redesign, or broad
  SwiftData migration infrastructure.
