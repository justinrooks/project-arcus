# Codebase Simplification Progress

## Overview

This ledger tracks the ordered implementation of findings F-01 through F-10 from the architecture recovery audit.
It is the durable record for issue status, changed files, concepts removed, exact validation, runtime evidence,
residual risk, and handoff.

**Audit source SHA:** `0697e440689cada99d03a67e7aa935d87656803c`

**Epic status:** Planned

**Primary GitHub epic:** [#329](https://github.com/justinrooks/project-arcus/issues/329)

## Global decisions

- The audit and roadmap are authoritative evidence; do not repeat the investigation.
- The user clarified that Xcode Cloud owns release marketing/build numbers. Checked-in values are placeholders.
  Monitor only app/widget marketing-version and build-number parity.
- Preserve the current G5 architecture. This campaign tightens semantics and removes pathways; it does not replace
  ownership boundaries.
- Split waiter cancellation and background budget work into characterization/contract and implementation issues.
- Split current-architecture docs, Xcode Cloud release policy, validation lanes, and physical-device evidence.
- Existing API URL issue [#245](https://github.com/justinrooks/project-arcus/issues/245) is adjacent but out of scope
  for composition-policy cleanup.
- Existing issue [#327](https://github.com/justinrooks/project-arcus/issues/327) closed the Today performance campaign
  with incomplete physical-device evidence. Issue 16 is validation-only follow-up, not new optimization work.
- No issue currently requires GPT-5.6 Sol. Stop and justify a re-plan before any upgrade.

## Current state summary

The recovered architecture is coherent: manual composition constructs actor-isolated providers and repositories;
`LocationSession` owns UI location lifecycle; `HomeIngestionCoordinator` serializes and joins foreground,
background, significant-location, and APNs work; `HomeIngestionExecutor` commits a durable core projection before
optional enrichment; SwiftUI and widgets consume location-scoped truth.

The current defects are narrow:

- Map warning and AQI edges collapse unavailable/skipped into empty.
- Coordinator waiters outlive canceled callers.
- Background upload draining is unbounded and begins outside the cancellation handler.
- Protocol defaults can weaken atomicity or silently discard side effects/callbacks.
- Today display arbitration is distributed through `HomeView`.
- Obsolete Home and unreachable composition paths remain.
- Current architecture, campaign status, release ownership, and validation evidence are not recorded consistently.

## Locked behavior invariants

- Cached-first and resolve-forward Today behavior.
- Useful same-location stale content during partial failure.
- Authoritative-empty alerts.
- Location/projection/source/revision and presentation identities.
- Unified ingestion and hot-alert priority.
- Atomic Home core and accepted/rejected SPC persistence.
- Stable Local Alerts and Storm Setup structure.
- Core publication before optional enrichment.
- Storm Setup expiry/backoff/freshness.
- Risk-change coalescing and 20/40/60 cadence.
- Widget freshness, polygon holes, privacy-first location, and conservative notifications.

## Protected boundaries

- Explicit `Dependencies.live()` composition.
- `LocationSession` UI ownership.
- Actor and `@ModelActor` repository ownership.
- Coordinator plan compatibility, joining, serialization, and one pending merge.
- Structured executor provider/enrichment tasks.
- `HomeProjectionStore` durable truth.
- `HomeRefreshPipeline` visible submission/publication ownership.
- SPC transaction semantics and all distinct identity concepts.

## Issue sequence

| Order | Issue | Finding | Preferred model | Status | Dependency |
| ---: | --- | --- | --- | --- | --- |
| 00 | [#329](https://github.com/justinrooks/project-arcus/issues/329) — Epic | F-01-F-10 | Coordination | Planned | Audit/roadmap |
| 01 | [#330](https://github.com/justinrooks/project-arcus/issues/330) — Preserve cached warnings | F-01 | `GPT-5.6 Terra / medium` | Planned | None |
| 02 | [#331](https://github.com/justinrooks/project-arcus/issues/331) — Preserve same-location AQI | F-02 | `GPT-5.6 Terra / medium` | Planned | 01 vocabulary only |
| 03 | [#332](https://github.com/justinrooks/project-arcus/issues/332) — Characterize waiter cancellation | F-03 | `GPT-5.6 Terra / medium` | Planned | None |
| 04 | [#333](https://github.com/justinrooks/project-arcus/issues/333) — Cancel waiters safely | F-03 | `GPT-5.6 Terra / medium` | Planned | 03 |
| 05 | [#334](https://github.com/justinrooks/project-arcus/issues/334) — Define bounded upload drain | F-04 | `GPT-5.6 Terra / medium` | Planned | None |
| 06 | [#335](https://github.com/justinrooks/project-arcus/issues/335) — Integrate background cancellation/budget | F-03, F-04 | `GPT-5.6 Terra / medium` | Planned | 04, 05 |
| 07 | [#336](https://github.com/justinrooks/project-arcus/issues/336) — Require atomic core commits | F-05 | `GPT-5.6 Terra / medium` | Planned | None |
| 08 | [#337](https://github.com/justinrooks/project-arcus/issues/337) — Collapse coordinator protocol | F-06 | `GPT-5.6 Luna / medium` | Planned | 04 |
| 09 | [#338](https://github.com/justinrooks/project-arcus/issues/338) — Require explicit side effects | F-06 | `GPT-5.6 Luna / medium` | Planned | 05, 06 |
| 10 | [#339](https://github.com/justinrooks/project-arcus/issues/339) — Centralize Today display selection | F-07 | `GPT-5.6 Terra / medium` | Planned | 02 |
| 11 | [#340](https://github.com/justinrooks/project-arcus/issues/340) — Remove obsolete Home artifacts | F-08 | `GPT-5.6 Luna / medium` | Planned | 10 |
| 12 | [#341](https://github.com/justinrooks/project-arcus/issues/341) — Clarify Arcus live composition | F-09 | `GPT-5.6 Luna / medium` | Planned | 09 |
| 13 | [#342](https://github.com/justinrooks/project-arcus/issues/342) — Align architecture/status docs | F-10 | `GPT-5.6 Luna / medium` | Planned | 01-12 or explicit interim state |
| 14 | [#343](https://github.com/justinrooks/project-arcus/issues/343) — Document Xcode Cloud ownership/parity | F-10 correction | `GPT-5.6 Luna / medium` | Planned | 13 |
| 15 | [#344](https://github.com/justinrooks/project-arcus/issues/344) — Make validation lanes explicit | F-10 | `GPT-5.6 Luna / medium` | Planned | 14 |
| 16 | [#345](https://github.com/justinrooks/project-arcus/issues/345) — Capture physical-device evidence | Runtime gap | `GPT-5.6 Terra / medium` | Planned | 15 |

## Existing code map

- Map outcomes: `Sources/Features/Map/MapFeatureModel.swift`
- Today trigger/publication: `Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift`,
  `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`, `Sources/App/HomeRefreshPipeline.swift`
- Coordinator: `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- Background sequencing: `Sources/Features/Background/BackgroundOrchestrator.swift`
- Durable uploads: `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`
- Projection contract: `Sources/Repos/HomeProjectionStore.swift`
- Composition/configuration: `Sources/App/Dependencies.swift`, `Sources/App/ArcusSignalConfiguration.swift`
- Today presentation: `Sources/App/HomeView.swift`, `Sources/App/HomeView+PresentationState.swift`
- Obsolete Home model: `Sources/App/HomeRefreshV2/HomeScreenModel.swift`
- Focused tests: `Tests/UnitTests/MapFeatureModelWarningsTests.swift`,
  `Tests/UnitTests/StormSetupIngestionTests.swift`, `Tests/UnitTests/HomeRefreshPipelineTests.swift`,
  `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`,
  `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`,
  `Tests/UnitTests/LocationProviderTests.swift`, `Tests/UnitTests/HomeProjectionStoreTests.swift`

## Investigation notes and contradictions

- F-01 and F-02 are current source-backed defects, not generic freshness refactors.
- F-03 needs explicit waiter ownership; a canceled waiter must not automatically cancel a shared useful run.
- F-04 must preserve the intentional pre-ingestion and early-exit upload attempt. Issue 06 may bound it, not reorder
  it without new evidence and re-planning.
- F-05 production atomicity is correct; only the protocol default/fake contract is weaker.
- F-07 must yield a pure value selector, not another observable view model.
- F-10's build-number provenance concern is superseded by the user's Xcode Cloud correction. Only parity is a
  current repository invariant.
- Issue #245 changes the API URL scheme; issue 12 changes missing-configuration composition policy. Do not merge
  them.
- Issue #327 is closed, but its progress ledger records incomplete Release/device evidence. Issue 16 records that
  gap only; it must not propose new micro-optimizations without regression evidence.

## Status ledger

### Issue #330 — 01: Preserve cached warnings when warning lookup fails

- **Status:** Implemented; simulator execution blocked by CoreSimulator service availability.
- **Goal:** Distinguish warning-query failure/cancellation from confirmed empty.
- **Concept removed:** `[]` as both failure and authoritative empty.
- **Changed files:** `MapFeatureModel.swift`, `MapScenePlanner.swift`, `MapRenderPlan.swift`, and
  `MapFeatureModelWarningsTests.swift`.
- **Proof added:** Sequential success → failure preserves warning overlays and legends while thematic data refreshes,
  including after layer selection; success → confirmed empty clears warning slices; cancellation restores the prior
  selected scene.
- **Validation:** Debug build for `platform=iOS Simulator,name=iPhone 17,OS=26.5` succeeded on 2026-07-23. The
  focused map test command compiled the updated app and test targets, but CoreSimulator was unavailable before test
  execution and produced no readable `.xcresult`; `xcrun simctl list devices available` reported a refused
  CoreSimulator service connection.
- **Residual risk / handoff:** Re-run the focused map suites, inspect their `.xcresult`, and run the map UI smoke
  once CoreSimulator is available. The requested `SkyAwareUITests` smoke command also cannot run because that target
  is not a member of the `SkyAware` scheme's test plan. No SPC persistence, MapKit reconciliation, or scene-cache
  work was added.

### Issue #331 — 02: Preserve same-location AQI when refresh produces no value

- **Status:** Implemented; simulator validation blocked
- **Goal:** Preserve same-key AQI across skipped/failed refreshes while isolating location changes.
- **Concept removed:** `nil` as updated-empty, skipped, and failed.
- **Required proof:** hot tick, failure, success, location change, and stale run/key tests.
- **Evidence:** Home enrichment now publishes a two-case AQI replace/preserve outcome. Deterministic executor and
  pipeline coverage characterizes hot-tick skip, failed and empty responses, replacement, same-key retention,
  location clearing, mismatched run/key rejection, and superseded enrichment. Debug simulator build passed on
  2026-07-23. Focused unit and Today UI commands built but could not execute because CoreSimulatorService was
  unavailable; their staged result bundles have no `Info.plist`, so `xcresulttool` cannot inspect them.
- **Handoff:** No AQI persistence or server/ArcusCore contract work.

### Issue #332 — 03: Characterize ingestion waiter cancellation

- **Status:** Implemented; simulator execution blocked by CoreSimulator service availability.
- **Goal:** Lock current shared-run behavior and expose orphaned waiter callbacks before #333 changes semantics.
- **Changed files:** `HomeIngestionCoordinatorTests.swift` adds deterministic pre-cancel, active, pending,
  compatible/last-waiter, callback-lifetime, and finish/cancel ordering coverage. `HomeIngestionCoordinator.swift`
  has a Debug-only waiter-storage/pending-plan observation seam, explicitly authorized for this characterization and
  compiled out of Release builds.
- **Evidence:** Canceled callers are currently stored and resolve with the shared snapshot; active canceled waiters
  remain eligible for explicitly emitted progress and staged publications; canceled pending waiters remain stored
  through the queued run; and canceling a waiter does not cancel coordinator-owned fire-and-forget work. #333 must
  invert only waiter resumption/removal and callback eligibility while preserving shared work.
- **Validation:** The focused coordinator command on `platform=iOS Simulator,name=iPhone 17,OS=26.5` compiled the
  updated app and test targets on 2026-07-24, but CoreSimulatorService refused its connection before test execution.
  The resulting `/private/tmp/SkyAware-332-coordinator-20260724T0002.xcresult` has no `Info.plist`, so
  `xcresulttool` cannot inspect it. `xcrun simctl list devices available` reported the same service refusal.
  `git diff --check` passed with the final diff.
- **Handoff:** Re-run the focused suite and inspect its `.xcresult`; #333 owns cancellation handling, waiter removal,
  callback suppression, and exactly-once resumption. No plan compatibility, pending merge, executor, or trigger
  behavior changed.

### Issue #333 — 04: Cancel waiters without canceling shared ingestion runs

- **Status:** Planned
- **Goal:** Remove canceled waiters promptly and resume continuations exactly once.
- **Concept removed:** Waiters that outlive caller interest.
- **Required proof:** issue 03 tests pass; canceled callbacks stop; shared useful work continues.
- **Handoff:** Do not change plan satisfaction, merging, provider orchestration, or trigger count.

### Issue #334 — 05: Define bounded pending-upload drain semantics

- **Status:** Planned
- **Goal:** Give the durable drainer an explicit quota/deadline outcome and durable remainder.
- **Concept removed:** "Drain everything" as the only operation.
- **Required proof:** backlog, retry, missing token, cancellation, and remaining-queue tests.
- **Handoff:** Do not change background ordering in this issue.

### Issue #335 — 06: Put background refresh under cancellation and drain budgets

- **Status:** Planned
- **Goal:** Cover pre-drain with OS cancellation and preserve ingestion/notification budget.
- **Concept removed:** Uncanceled, unbounded pre-handler work.
- **Required proof:** early exit, expiration during drain, ingestion start, health, cadence, and device backlog timing.
- **Handoff:** Preserve pre-ingestion attempt and durable queued remainder.

### Issue #336 — 07: Require atomic Home core commits across conformers

- **Status:** Planned
- **Goal:** Remove decomposed default `commitCore` behavior.
- **Concept removed:** One API name with multiple transaction semantics.
- **Required proof:** production/fake failure atomicity, skipped slices, authoritative empty, risk delta.
- **Handoff:** Do not redesign projection schema/readiness or split the store.

### Issue #337 — 08: Collapse Home ingestion coordination to one semantic operation

- **Status:** Planned
- **Goal:** Remove overload defaults that discard progress/publication.
- **Concept removed:** Multiple semantic entry surfaces for one request.
- **Required proof:** all callers reach the canonical operation with callbacks intact.
- **Handoff:** Mechanical contract cleanup only; preserve compatibility/merge behavior.

### Issue #338 — 09: Require explicit upload and preference side effects

- **Status:** Planned
- **Goal:** Make every live/no-op side-effect choice explicit at composition.
- **Concept removed:** Silent critical no-op protocol conformance.
- **Required proof:** conformance inventory and upload/preference integration tests.
- **Handoff:** No payload, endpoint, or ArcusCore work.

### Issue #339 — 10: Centralize Today display selection in a pure value

- **Status:** Planned
- **Goal:** Replace per-slice cache/key/stage arbitration with one pure presentation snapshot.
- **Concept removed:** Duplicated display-selection branches.
- **Required proof:** no cache, matching/stale cache, stages, failure, empty, and location-transition matrix.
- **Handoff:** No new observable owner, query-scope change, animation redesign, or Summary restructuring.

### Issue #340 — 11: Remove obsolete Home model and inert pipeline policies

- **Status:** Planned
- **Goal:** Delete `HomeScreenModel` and unread pipeline initializer arguments.
- **Concept removed:** One obsolete owner and six inert policy knobs.
- **Required proof:** reference scan, trigger/timing tests, Debug build, full unit target.
- **Handoff:** Split into two commits/checkpoints if the mechanical diff becomes noisy.

### Issue #341 — 12: Make Arcus live composition fail-fast and explicit

- **Status:** Planned
- **Goal:** Use one configuration resolution and one explicit live/no-op policy.
- **Concept removed:** Unreachable degraded-production branch.
- **Required proof:** missing/malformed/valid URL configuration and onboarding availability tests.
- **Handoff:** Do not change the URL scheme or absorb issue #245.

### Issue #342 — 13: Align current architecture and campaign-status documentation

- **Status:** Planned
- **Goal:** Make current architecture and top-level campaign statuses agree with source and detailed ledgers.
- **Concept removed:** Multiple unlabeled current-architecture/status truths.
- **Required proof:** link/status review and `git diff --check`.
- **Handoff:** Preserve historical audits as point-in-time evidence.

### Issue #343 — 14: Document Xcode Cloud release ownership and app/widget parity

- **Status:** Planned
- **Goal:** Record Xcode Cloud ownership, app/widget parity, and `Unreleased` policy.
- **Concept removed:** Checked-in placeholder numbers treated as release provenance.
- **Required proof:** app/widget values match; release docs describe the automation boundary; `git diff --check`.
- **Handoff:** Do not investigate or normalize placeholder values.

### Issue #344 — 15: Make unit and UI validation lanes explicit

- **Status:** Planned
- **Goal:** Record or configure the intended unit/UI invocations and `.xcresult` inspection.
- **Concept removed:** Ambiguous "tests passed" provenance.
- **Required proof:** both plan commands are runnable and every result bundle is inspected.
- **Handoff:** No test-warning cleanup or live-network tests.

### Issue #345 — 16: Capture remaining physical-device Release evidence

- **Status:** Planned
- **Goal:** Close the explicit validation gap left by closed issue #327.
- **Concept removed:** Runtime conclusions without comparable Release/device evidence.
- **Required proof:** cold/no-cache, authoritative-empty, Storm states, partial failure, lifecycle, scrolling,
  warm/manual, and BG backlog artifacts on a consistent device/configuration.
- **Handoff:** Validation only; create optimization work only if a measured regression exists.

## Verification ledger

### Audit baseline

- Debug build: passed; inspected `debug-build.xcresult`.
- Focused architecture suites: 303 passed, 0 failed/skipped; inspected result.
- Full `SkyAwareTests`: 888 passed, 0 failed/skipped; inspected result.
- `SkyAware_All_Tests` navigation smoke: 1 passed, 0 failed/skipped; inspected result.
- No intentional live WeatherKit, NWS, SPC, Arcus, or APNs request.

### Campaign execution

| Issue | Focused tests | Debug build | Full unit | UI | Device/trace | `.xcresult` inspected |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | Pending | Pending | Not required by default | Pending | Not required | Pending |
| 02 | Pending | Pending | Not required by default | Pending | Not required | Pending |
| 03 | Pending | N/A unless needed | Pending | N/A | N/A | Pending |
| 04 | Pending | Pending | Pending | N/A | Optional | Pending |
| 05 | Pending | Pending | Pending | N/A | N/A | Pending |
| 06 | Pending | Pending | Pending | N/A | Pending | Pending |
| 07 | Pending | Pending | Pending | N/A | N/A | Pending |
| 08 | Pending | Pending | Pending | N/A | N/A | Pending |
| 09 | Pending | Pending | Pending | N/A | N/A | Pending |
| 10 | Pending | Pending | Pending | Pending | Evidence before performance claim | Pending |
| 11 | Pending | Pending | Pending | N/A | N/A | Pending |
| 12 | Pending | Pending | Pending | N/A | N/A | Pending |
| 13 | `git diff --check` | N/A | N/A | N/A | N/A | N/A |
| 14 | `git diff --check`; parity check | N/A | N/A | N/A | N/A | N/A |
| 15 | Pending | N/A | Pending | Pending | N/A | Pending |
| 16 | Focused regression gates | Release | As needed | Scenario fixtures | Pending | Pending |

## Handoff rules

- Update only the active issue section and verification row.
- Record exact changed files, concepts/pathways removed, commands, counts, `.xcresult` summaries, and residual risks.
- Do not mark work complete from source inspection, a merged PR, or "tests added."
- Keep simulator, UI, physical-device, Instruments, and comparable before/after evidence distinct.
- Stop at the active issue's acceptance criteria and wait for review.
- Record contradictions and stop conditions; do not create speculative follow-up issues.
