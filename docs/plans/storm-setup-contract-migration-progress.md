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

- Status: Complete
- Outcome: The primary Storm Setup client now decodes `ArcusCore.StormSetupCurrentResponse` directly, preserves the existing H3 request shape, headers, retry handling, and HTTP error mapping, and accepts a nil `profileAnalysis` as a successful response.
- Validation: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:SkyAwareTests/StormSetupHTTPClientTests test` passed. `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build` passed.
- Handoff: Keep the legacy ingestion bridge in place for #286 so the compile-safe staged cutover remains isolated.

### Issue #286 — 03: Persist one aggregate Storm Setup payload

- Status: Complete
- Outcome: `HomeProjection` now persists a single `ArcusCore.StormSetupCurrentResponse` per projection key and derives the legacy `stormSetup` / profile-analysis record fields from that aggregate. The ingestion executor writes the aggregate directly, and the separate profile-analysis persistence path is now a compatibility no-op.
- Validation:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:SkyAwareTests/HomeProjectionStoreTests test`
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build`
  - The focused test command compiled cleanly, but simulator app launch failed in CoreSimulator before execution on the current machine.
- Handoff: Prefer reinstall/clear over generalized legacy-cache migration work. No generalized SwiftData migration layer was added.

### Issue #287 — 04: Cut Storm Setup ingestion to one request

- Status: Complete
- Outcome: Home ingestion now evaluates one aggregate Storm Setup request and carries the
  `StormSetupCurrentResponse` through snapshot publication, projection persistence, pipeline state, and HomeView
  selection. The active path no longer starts or coordinates the profile-analysis request, matches independent
  timestamps, merges partial outcomes, or lets Detailed Ingredients change network eligibility. Aggregate profile
  data remains presentation-driven, and an aggregate with `profileAnalysis == nil` replaces older profile data.
  Legacy profile plumbing remains compile-safe for #288 cleanup but is not consulted by the active refresh path.
- Validation:
  - Debug build passed with `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -configuration Debug build`.
  - Focused ingestion test compilation passed; simulator test execution could not progress past Xcode test-runner setup on the available simulator. The captured xcresult bundles contain no executed test failures.
  - HomeRefreshPipelineTests and HomeViewLoadingOverlayStateTests were not completed because the same simulator test-runner condition prevented execution.
- Handoff: #288 may remove the now-unused profile client, compatibility state, and superseded tests. Do not expand this issue into dead-file cleanup.

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
| 2026-07-10 | #285 | `StormSetupHTTPClientTests` and `xcodebuild ... build` | Complete |
| 2026-07-10 | #286 | `HomeProjectionStoreTests` compile/launch attempt and `xcodebuild ... build` | Complete |
| 2026-07-10 | #287 | Debug build; focused test-runner attempts with captured xcresult bundles | Build complete; test execution blocked by simulator runner startup |

## Handoff Notes

- Start only after the owner has made ArcusCore `0.4.1` available to the project.
- Execute issues sequentially.
- Update this ledger with changed files, behavior, exact tests, `.xcresult` evidence, and remaining risks before closing
  each issue.
- Stop and re-plan if implementation requires server changes, mixed-version compatibility, UI redesign, or broad
  SwiftData migration infrastructure.
