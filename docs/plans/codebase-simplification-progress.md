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
| 10 | [#339](https://github.com/justinrooks/project-arcus/issues/339) — Centralize Today display selection | F-07 | `GPT-5.6 Terra / medium` | Implemented | 02 |
| 11 | [#340](https://github.com/justinrooks/project-arcus/issues/340) — Remove obsolete Home artifacts | F-08 | `GPT-5.6 Luna / medium` | Implemented | 10 |
| 12 | [#341](https://github.com/justinrooks/project-arcus/issues/341) — Clarify Arcus live composition | F-09 | `GPT-5.6 Luna / medium` | Planned | 09 |
| 13 | [#342](https://github.com/justinrooks/project-arcus/issues/342) — Align architecture/status docs | F-10 | `GPT-5.6 Luna / medium` | Planned | 01-12 or explicit interim state |
| 14 | [#343](https://github.com/justinrooks/project-arcus/issues/343) — Document Xcode Cloud ownership/parity | F-10 correction | `GPT-5.6 Luna / medium` | Complete | 13 |
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

- **Status:** Implemented and validated.
- **Goal:** Remove canceled waiters promptly and resume continuations exactly once.
- **Changed files:** `HomeIngestionCoordinator.swift` wraps canonical waiter registration in a task-cancellation
  handler and removes/resumes the actor-owned waiter through dictionary removal. `HomeIngestionCoordinatorTests.swift`
  inverts the #332 characterization matrix and adds repeated-cancellation coverage.
- **Behavior:** Cancellation removes the waiter before resuming `CancellationError`; callbacks and `finishRun` only
  see retained waiters. Active and pending coordinator work, including fire-and-forget work, remains unchanged.
- **Validation:** Xcode `SkyAware_Tests` passed 900/900 tests with no failures or skips on iPhone 17 / iOS 26.5 on
  2026-07-24. The inspected result bundle is
  `Test-SkyAware-2026.07.24_09-43-09--0600.xcresult`; all 15 `HomeIngestionCoordinatorTests`, including the
  pre-cancel, active/pending callback suppression, retained-waiter, last-waiter, finish-before-cancel, and repeated
  cancellation cases, passed. Debug app and test-target builds also succeeded.
- **Required proof:** issue 03 tests pass; canceled callbacks stop; shared useful work continues.
- **Handoff:** Do not change plan satisfaction, merging, provider orchestration, or trigger count.

### Issue #334 — 05: Define bounded pending-upload drain semantics

- **Status:** Complete
- **Goal:** Give the durable drainer an explicit quota/deadline outcome and durable remainder.
- **Concept removed:** "Drain everything" as the only operation.
- **Changed files:** `LocationSnapshotPusher.swift` adds the Sendable budget/outcome contract and bounded actor drain;
  no-op/test conformers implement the new requirement; `LocationProviderTests.swift` covers quota, deadline,
  missing-token, retry, cancellation, and durable-redrain behavior.
- **Behavior:** A bounded drain admits at most its explicit durable-request quota before its monotonic deadline, reports
  `.drained` only when actor-owned durable state is empty, and retains failed, cancelled, expired, or never-admitted
  requests. Existing no-argument draining, retry constants, coalescing, semantic deduplication, and background
  ordering are unchanged.
- **Validation:** Focused `LocationProviderTests` passed 67/67 with no failures or skips on iPhone 17 / iOS 26.5;
  inspected result bundle: `Test-SkyAware-2026.07.24_09-55-46--0600.xcresult`. Focused consumer regression,
  `SkyAware_Tests`, and Debug build commands completed successfully; `git diff --check` passed.
- **Handoff:** #335 should call `drainPendingUploads(using:)` with its own explicit quota and deadline. It owns
  background cancellation scope, ordering, and policy; this issue does not select them.

### Issue #335 — 06: Put background refresh under cancellation and drain budgets

- **Status:** Complete
- **Goal:** Cover pre-drain with OS cancellation and preserve ingestion/notification budget.
- **Concept removed:** Uncanceled, unbounded pre-handler work.
- **Changed files:** `BackgroundOrchestrator.swift` moves the bounded pre-ingestion upload attempt inside the
  cancellation handler; `BackgroundOrchestratorCadenceTests.swift` covers budget forwarding, ordering, remaining
  outcomes, and cancellation during drain or ingestion.
- **Behavior:** Background refresh admits one durable upload request with a monotonic deadline five seconds after the
  drain begins, then continues ingestion for `.remaining` unless the task was cancelled. Cancellation before or after
  that await records the existing cancelled health outcome and 20-minute recovery cadence; pre-ingestion and
  early-exit attempt ordering, successful 20/40/60 cadence, notification, retry, persistence, and shared-run
  ownership remain unchanged.
- **Validation:** Focused `BackgroundOrchestratorCadenceTests` passed 26/26; prerequisite
  `HomeIngestionCoordinatorTests` and `LocationProviderTests` passed 82/82; full `SkyAwareTests` passed 910/910,
  all with no failures or skips on iPhone 17 / iOS 26.5. Inspected result bundles:
  `Test-SkyAware-2026.07.24_10-40-13--0600.xcresult`, `Test-SkyAware-2026.07.24_10-43-21--0600.xcresult`, and
  `Test-SkyAware-2026.07.24_10-44-41--0600.xcresult`. Debug simulator build and `git diff --check` passed.
- **Remaining evidence:** Physical-device backlog and OS-expiration timing remain unmeasured; the five-second deadline
  bounds cooperative drain admission and retry backoff, not an in-flight non-cooperative network operation.

### Issue #336 — 07: Require atomic Home core commits across conformers

- **Status:** Implemented
- **Goal:** Removed decomposed default `commitCore` behavior.
- **Concept removed:** One API name with multiple transaction semantics.
- **Changes:** `HomeProjectionPersisting` now requires explicit core-transaction ownership; production retains its one
  model-actor `Projection Core Save`; `ThrowingHomeProjectionStore` explicitly fails before publication; the new
  value-state actor fake stages all slices and publishes once after deterministic failure checks.
- **Required proof:** Failure after weather, slow-product, or hot-alert staging leaves prior fake state unchanged;
  successful commits preserve skipped weather, clear authoritative-empty alerts/mesos, and derive risk deltas from
  the prior committed profile.
- **Validation:** Focused `HomeProjectionStoreTests` and `StormSetupIngestionTests` passed 59/59; full
  `SkyAwareTests` passed 912/912, both with no failures or skips on iPhone 17 / iOS 26.5. Inspected result bundles:
  `Test-SkyAware-2026.07.24_11-41-54--0600.xcresult` and
  `Test-SkyAware-2026.07.24_11-45-18--0600.xcresult`. Debug simulator build and `git diff --check` passed.
- **Handoff:** #337 may address ingestion-coordinator protocol overloads; do not redesign projection schema,
  readiness, executor flow, or split the store.

### Issue #337 — 08: Collapse Home ingestion coordination to one semantic operation

- **Status:** Complete (2026-07-24)
- **Goal:** Removed overload defaults that could discard progress or publication.
- **Concept removed:** Multiple semantic protocol entry surfaces for one ingestion request.
- **Implementation:** `HomeIngestionCoordinating` now requires only request-based `enqueueAndWait(_:progress:publication:)`.
  Trigger, request-only, and progress-only forms are forwarding conveniences; concrete fire-and-forget submission
  remains on `HomeIngestionCoordinator`. Every production and test conformer explicitly implements the canonical
  operation. Contract coverage proves request/context and callback forwarding through an existential.
- **Validation:** Focused coordinator/pipeline/remote suites passed 79/79; background/alert suites passed 38/38;
  Debug simulator build passed; full `SkyAwareTests` passed 913/913. All runs had zero failures and skips on
  iPhone 17 / iOS 26.5. Inspected result bundles:
  `Test-SkyAware-2026.07.24_12-13-28--0600.xcresult`,
  `Test-SkyAware-2026.07.24_12-00-11--0600.xcresult`, and
  `/private/tmp/issue337-full-tests.xcresult`. `git diff --check` passed.
- **Handoff:** #338 owns only explicit location-upload and preference side effects; do not expand this contract
  migration into that cleanup. Compatibility, joining, pending merge, publication identity, cancellation, triggers,
  and result satisfaction remain unchanged.

### Issue #338 — 09: Require explicit upload and preference side effects

- **Status:** Implemented; simulator test execution pending host repair
- **Goal:** Make every live/no-op side-effect choice explicit at composition.
- **Concept removed:** Silent critical no-op protocol conformance and initializer-selected upload no-ops.
- **Changes:** `LocationUploadCoordinating` now requires location enqueue, preference enqueue, legacy drain, and
  bounded drain from every conformer. Its sole convenience forwards a missing preference override as `nil`.
  `LocationSnapshotPusher`, `LocationSession`, and `BackgroundOrchestrator` now require their side-effect
  dependencies. Snapshot-only tests and the `LocationSession` preview explicitly choose named no-ops; live
  composition continues selecting both HTTP uploaders when configured and the named coordinator no-op otherwise.
- **Validation:** `git diff --check`, conformance/construction inventories, and an iPhone 17 / iOS 26.5 Debug build
  passed. Focused location/uploader, background, and full `SkyAwareTests` commands compiled but did not execute:
  Xcode exited after writing unfinalized result-bundle staging directories (no `Info.plist` or inspectable test
  counts), even after booting the simulator. Re-run those commands after repairing the local test runner.
- **Handoff:** #341 alone owns missing-configuration/live-composition policy. No payload, endpoint, ArcusCore, or
  API URL work is included here.

### Issue #339 — 10: Centralize Today display selection in a pure value

- **Status:** Implemented
- **Goal:** Replace per-slice cache/key/stage arbitration with one pure presentation snapshot.
- **Evidence:** `HomePresentationSnapshot` receives copied cache/pipeline values and an explicit clock sample, then
  selects the projection, summary values, alert collections, Storm Setup, AQI, and location time zone. `HomeView`
  supplies that single value to Today, Alerts, the badge, readiness, and reliability logic.
- **Characterization:** `HomeViewStateTests` covers stale-location isolation, matching committed authoritative-empty
  alert/meso values, same-location AQI publication, and the UI-test static-alert override. Existing projection,
  Storm Setup, alert ownership, pipeline, and Today surface suites retain the surrounding matrix coverage.
- **Validation:** The focused command compiled the app and affected test target on iPhone 17 / iOS 26.5, but its
  finalized result bundle reports 0 executed tests with an unknown result; simulator execution remains unavailable.
  The Debug build command produced an unfinalized result bundle, so it cannot be inspected.
- **Handoff:** No new observable owner, query-scope change, animation redesign, Summary restructuring, or #340 cleanup.

### Issue #340 — 11: Remove obsolete Home model and inert pipeline policies

- **Status:** Implemented (2026-07-24).
- **Goal:** Delete `HomeScreenModel` and unread pipeline initializer arguments.
- **Concept removed:** One obsolete owner and six inert policy knobs:
  `minimumForegroundRefreshInterval`, `minimumRefreshDistanceMeters`, `alertRefreshPolicy`, `mapProductRefreshPolicy`,
  `outlookRefreshPolicy`, and `weatherKitRefreshPolicy`.
- **Changed files:** Deleted `HomeRefreshV2/HomeScreenModel.swift`; removed only the six inert arguments from
  `HomeRefreshPipeline.init`; this ledger records the completed issue.
- **Behavior:** No trigger, timing, visible-state, persistence, or concurrency behavior changed. The 120-second
  `foregroundTimerInterval` remains stored and used by the pipeline timer. Foreground location thresholds remain in
  `HomeRefreshPolicies`, and alert/map/outlook/WeatherKit policies remain owned by `HomeIngestionExecutor`.
- **Validation:** Repository scans found no `HomeScreenModel` reference after deletion and no removed initializer label
  in `HomeRefreshPipeline`. On iPhone 17 / iOS 26.5, focused `HomeRefreshPipelineTests`, `HomeViewStateTests`, and
  `ForegroundRefreshPolicyTests` passed 55/55; inspected bundle:
  `/tmp/project-arcus-340-focused.xcresult`. Debug build passed with zero warnings/errors; inspected bundle:
  `/tmp/project-arcus-340-build.xcresult`. Full `SkyAwareTests` passed 912/912 with zero failures/skips; inspected
  bundle: `/tmp/project-arcus-340-unit.xcresult`. `git diff --check` passed.
- **Handoff:** No call-site, project-file, test, Arcus composition (#341), or policy-ownership change was needed.

### Issue #341 — 12: Make Arcus live composition fail-fast and explicit

- **Status:** Implemented (2026-07-24).
- **Goal:** Resolve one required Arcus base URL for every live Arcus client and uploader.
- **Concept removed:** The duplicate optional configuration lookup and unreachable degraded-production no-op branch.
- **Behavior:** `Dependencies.live()` now resolves `ArcusSignalConfiguration.baseURL()` once, then passes that URL to
  alerts, Storm Setup, AQI, location snapshots, and device preferences. Invalid production configuration still fails
  before dependencies escape; preview and test composition retain explicit named no-ops. Onboarding's existing
  remote-setup eligibility/configuration decision is characterized without changing its flow.
- **Validation:** `ArcusSignalConfigurationTests`, `ArcusHttpClientTests`,
  `HTTPLocationSnapshotUploaderTests`, `HTTPDevicePreferenceSyncUploaderTests`,
  `LaunchPresentationStateTests`, `OnboardingStepTests`, and `OnboardingRemoteSetupDecisionTests` passed 23 logical
  tests / 30 parameterized runs with zero failures on iPhone 17 / iOS 26.5; inspected bundle:
  `/tmp/project-arcus-341-focused.xcresult`. Debug build passed; inspected bundle:
  `/tmp/project-arcus-341-build.xcresult`.
- **Handoff:** No API host, scheme, path, payload, build-setting, ArcusCore, or #245 work was included.

### Issue #342 — 13: Align current architecture and campaign-status documentation

- **Status:** Complete
- **Goal:** Make current architecture and top-level campaign statuses agree with source and detailed ledgers.
- **Concept removed:** Multiple unlabeled current-architecture/status truths.
- **Changed documents:** Current G5 app summary; organization, Today state-flow, and Today performance top-level
  runbooks/progress tables; July 12 performance-audit supersession annotation.
- **Validation:** Verified changed source links resolve; checked GitHub issue status for #289, #248, #318, and #327;
  compared top-level tables with detailed ledgers; confirmed the remaining physical-device evidence is explicit and
  assigned to #345; ran stale-status searches and `git diff --check`.
- **Handoff:** Historical audits and baselines remain point-in-time evidence. #343 release/version ownership, #344
  validation lanes, and #345 physical-device capture work remain out of scope.

### Issue #343 — 14: Document Xcode Cloud release ownership and app/widget parity

- **Status:** Complete
- **Goal:** Recorded Xcode Cloud ownership, app/widget parity, and the `Unreleased` policy without assigning a future
  release number.
- **Concept removed:** Checked-in placeholder numbers treated as release provenance.
- **Changed documents:** Release-readiness policy, release PR checklist, canonical changelog, derived release and
  TestFlight notes.
- **Validation:** Confirmed prerequisite #342 at `3320572a`; inspected #343 as open; reviewed
  `v1.1.0(94)..HEAD` and the supporting changes for #328, #330, #331, and #335; ran `xcodebuild -showBuildSettings`
  for `SkyAware` and `SkyAwareWidgetsExtension` in Debug and Release (each resolved
  `MARKETING_VERSION = 1.1.0`, `CURRENT_PROJECT_VERSION = 80`); verified release-note claims are derived from the
  changelog; ran release-policy search, `git diff --check`, changed-file review, and source/project/CI diff guard.
- **Handoff:** The archive script is documented only as generating `WhatToTest.en-US.txt`; downstream upload/delivery
  remains unproven repository evidence. Do not investigate or normalize placeholders; #344 and #345 remain separate.

### Issue #344 — 15: Make unit and UI validation lanes explicit

- **Status:** Validation executed; unit lane has one failing test and requires follow-up outside this documentation slice.
- **Goal:** Make the intended unit/UI invocations and `.xcresult` inspection durable and unambiguous.
- **Concept removed:** Ambiguous "tests passed" provenance.
- **Changed files:** `AGENTS.md` is the canonical runnable procedure; `README.md` points to it instead of providing a
  contradictory default-plan command. Test plans and the shared scheme were verified and remain unchanged.
- **Validation commands:** Created fresh result root `/private/tmp/skyaware-344-results.FsBxsb`. Unit lane:
  `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_Tests -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" -only-testing:SkyAwareTests -resultBundlePath /private/tmp/skyaware-344-results.FsBxsb/unit.xcresult test`.
  UI lane:
  `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -testPlan SkyAware_All_Tests -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5" -only-testing:SkyAwareUITests/SkyAwareUITests/testTabNavigationLoadsEachPrimaryView -resultBundlePath /private/tmp/skyaware-344-results.FsBxsb/ui-navigation.xcresult test`.
- **Result inspection:** `xcrun xcresulttool get test-results summary --path ... --compact` and
  `xcrun xcresulttool get test-results tests --path ... --compact` inspected both finalized bundles; both contained
  `Info.plist`. Unit: `SkyAware_Tests`, Debug, iPhone 17 / iOS 26.5, 919 passed, 1 failed, 0 skipped, 920 total;
  `HomeIngestionCoordinatorTests.finishBeforeCancel_waiterCompletesSuccessfully()` failed with
  `CancellationError()`. Bundle: `/private/tmp/skyaware-344-results.FsBxsb/unit.xcresult`. UI:
  `SkyAware_All_Tests`, Debug, iPhone 17 / iOS 26.5, exactly 1 passed, 0 failed, 0 skipped; the named navigation
  smoke is present and passed. Bundle: `/private/tmp/skyaware-344-results.FsBxsb/ui-navigation.xcresult`.
- **Evidence boundary:** Unit and simulator UI evidence are recorded separately. No physical-device or Instruments
  evidence was collected; those claims remain owned by #345. Deterministic test source and the selected smoke use
  stubs/fakes and make no intentional live WeatherKit, NWS, SPC, Arcus, or APNs requests.
- **Scope checks:** `git diff --check` passed and the forbidden production/test/project diff was empty. The requested
  `plutil -lint` commands report `Unexpected character {` because both existing `.xctestplan` files are JSON rather
  than plist XML; no configuration change was made.
- **Handoff:** Do not retry or rewrite the failing test in this issue; no test-warning cleanup, live-network tests,
  physical-device validation, Release profiling, or Instruments work is included.

### Issue #345 — 16: Capture remaining physical-device Release evidence

- **Status:** Partial trace-only evidence; semantic/visual matrix and deterministic result bundle remain blocked
- **Goal:** Close the explicit validation gap left by closed issue #327.
- **Concept removed:** Runtime conclusions without comparable Release/device evidence.
- **Required proof:** cold/no-cache, authoritative-empty, Storm states, partial failure, lifecycle, scrolling,
  warm/manual, and BG backlog artifacts on a consistent device/configuration.
- **2026-07-24 preflight:** Source `7a7f92065d5d9945aabb59b75d50982e3df638ec` contains prerequisite
  `7a7f9206`; worktree was clean on `329-epic-systematically-simplify-skyaware-architecture` (ahead 3). Xcode
  `26.6 (17F113)`, iPhoneOS SDK `26.5`; templates `SwiftUI` and `Animation Hitches` were available. `Js14Max`
  (`00008120-001A744E1193C01E`, iOS 26.6) appeared under `devices offline` from
  `record_trace.py --list-devices`, not `devices`. Therefore no Release build, signing inspection, install, launch,
  trace, or screen recording was attempted; a simulator is not a substitute.
- **Historical artifact recheck:** `/private/tmp/SkyAware-319-traces/warm-events-launch-20260719.trace` failed
  `analyze_trace.py --list-runs` with `Export failed: Trace is malformed - run data is missing`.
  `/private/tmp/SkyAware-319-traces/pull-events-20260719.trace` failed with `Export failed: Document Missing
  Template Error`. The ledger's #319 warm/pull metric summaries remain historical summaries only. They cannot support
  a direct comparison, independently analyzable baseline, or iOS 26.6 comparison (the historical device OS was
  iOS 26.5.2).
- **Focused deterministic gate:** Invoked the exact #345 selected-suite command with result path
  `/private/tmp/skyaware-345-results.dGPvic/focused.xcresult`. Xcode left only `Data/` and `Staging/1_Test`; the
  required `Info.plist` was absent, so both `xcresulttool get test-results summary --compact` and `tests --compact`
  failed. Counts and the known #344 cancellation race are therefore **not determined** by this pass; no retry or
  test/source change was made. This is a result-bundle finalization/infrastructure blocker, not evidence that the
  known cancellation test passed or failed.
- **Scenario result:** all required Release/device scenarios are blocked by the same precondition: connect, unlock,
  and trust `Js14Max` until it appears under `devices`, then keep its OS/build metadata stable for the entire matrix.
  Existing failure/empty/backlog transitions additionally lack safe, reproducible device fixtures or control points;
  do not add one in this issue or mutate server/persisted user data.
- **Artifacts:** fresh unused capture root `/private/tmp/SkyAware-345.t1KHRi` (`derived`, `traces`, `analysis`,
  `recordings`) and incomplete focused result root `/private/tmp/skyaware-345-results.dGPvic` remain outside source
  control. No trace, analysis JSON/Markdown, Release app, or recording artifact exists.
- **2026-07-24 device/build recovery attempt:** Js14Max subsequently appeared online under `devices` at iOS 26.6.
  Release build command:
  `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -configuration Release -destination "platform=iOS,id=00008120-001A744E1193C01E" -derivedDataPath /private/tmp/SkyAware-345.t1KHRi/derived build`.
  Its apparent product directory `/private/tmp/SkyAware-345.t1KHRi/derived/Build/Products/Release-iphoneos/SkyAware.app`
  contains resources and `embedded.mobileprovision`, but lacks `Info.plist` and a signed executable;
  `codesign --display --verbose=4` reports `bundle format unrecognized, invalid, or unsuitable`. It cannot establish
  install/source provenance, so no install, launch, or trace was attempted.
- **2026-07-24 successful Release provenance:** User-built Release artifact
  `/private/tmp/SkyAware-345-manual-derived/Build/Products/Release-iphoneos/SkyAware.app` verifies with
  `codesign --verify --deep --strict`; bundle `com.skyaware.app`, version `1.1.0` (80), signed by Apple Development
  team `YVC4WFW94T`, was installed on Js14Max at 17:06:10 MDT. This is the same source SHA; the only worktree
  changes were this issue's documentation files.
- **Current trace-only captures:** `warm-foreground-20260724T230650Z.trace` finalized with one SwiftUI run
  (97.790079 s): 10,961 body updates, 94 high-severity SwiftUI events, 22 app hitches / 462.64 ms total / 83.35 ms
  worst, plus one 289.24 ms microhang. `pull-refresh-launch-20260724T231500Z.trace` finalized with one 45.447359 s
  run: 11,654 body updates, 89 high-severity events, 16 app hitches / 270.97 ms total / 66.68 ms worst, no hangs.
  Analyses reside beside the traces under `/private/tmp/SkyAware-345.t1KHRi/analysis/`. Neither trace contains a
  `com.skyaware.app` signpost or log, so no visible-commit/render boundary or projection-save count is available;
  no separate screen recording exists. These measurements are non-comparable trace-only evidence, not completed
  semantic or visual scenarios and not an optimization claim.
- **2026-07-26 continuation:** HEAD remained `7a7f92065d5d9945aabb59b75d50982e3df638ec`; the continuation began
  with the two prior #345 ledger edits and an unrelated user-owned performance-audit edit already present. CoreDevice
  and `xctrace` both reported Js14Max online, paired, booted, Developer Mode enabled, and connected over the local
  network. Xcode stayed `26.6 (17F113)`, SDK 26.5, and the device stayed iPhone 14 Pro Max / iOS 26.6 (`23G71`).
  Fresh roots: `/private/tmp/SkyAware-345-20260726.REBf1C` and
  `/private/tmp/skyaware-345-results-20260726.5091YV`.
- **Deterministic result:** the exact twelve-suite focused bundle finalized and was inspected: Debug, iPhone 17
  simulator / iOS 26.5, 270 total, 269 passed, 1 failed, 0 skipped. The failure was the known #344
  `HomeIngestionCoordinatorTests.finishBeforeCancel_waiterCompletesSuccessfully()` `CancellationError()` race; it
  was neither retried nor fixed.
- **Current Release provenance:** fresh physical-device Release build succeeded and CoreDevice installed/launched
  `com.skyaware.app` 1.1.0 (80). Binary/dSYM UUID:
  `151E8EF4-F43D-357E-855B-3585296DC8E7`. Host strict verification returned `CSSMERR_TP_NOT_TRUSTED` with zero valid
  local signing identities, while the device accepted the exact artifact; this is recorded as a provenance
  limitation, not normalized away.
- **Current warm evidence:** `traces/warm-foreground-20260726T162500Z.trace` under the fresh capture root finalized
  as one 40.623579-second physical-device SwiftUI run: five View Body Update events, 47 high-severity events, seven
  app hitches / 141.73 ms total / 25.02 ms worst, and one 328.24 ms microhang. Analysis is under the fresh
  `analysis/` directory. The stock SwiftUI template had no signpost store.
- **Supplemental signposts and stop:** `traces/warm-foreground-logging-20260726T162900Z.trace` finalized with the
  required signpost schemas. The intended activation window was 219,189.595-227,054.907 ms; `Today Visible Commit`
  at 226,968.136 ms preceded the first following `Today Summary Render` by 86.771 ms, with two Core saves and one
  Storm Setup save in the window. No screen recording exists. Scoped log export contained private location-derived
  endpoint text, which is intentionally omitted; this triggered the issue's privacy stop condition. No more device
  captures were attempted.

| Required scenario | 2026-07-26 result |
|---|---|
| Cold launch with no usable Today cache | Blocked — no safe no-cache/onboarding control point. |
| Warm cached launch and foreground activation | Blocked — valid trace/signpost evidence, but no rendered proof and invalid historical baseline. |
| Pull-to-refresh with useful cached content | Blocked — prior trace lacks signposts/video; privacy stop prevented recapture. |
| Local Alerts populated to authoritative empty | Blocked — no safe existing fixture/control point. |
| Storm Setup loading to success | Blocked — success/save observed, but no rendered slot evidence. |
| Storm Setup loading to terminal failure | Blocked — no safe failure/timeout control point. |
| Partial core-provider failure with useful cache | Blocked — no safe provider-failure control point. |
| Rapid background/foreground lifecycle changes | Blocked — no dedicated trace/video before privacy stop. |
| Scroll, reversal, and partial-condense refresh | Blocked — no dedicated trace/video before privacy stop. |
| Refresh completion while scrolling | Blocked — no deterministic completion alignment plus video. |
| Reduce Motion and representative accessibility Dynamic Type | Blocked — no physical-device rendered recording. |
| Background upload backlog and task-budget behavior | Blocked — unsafe durable location-state mutation would be required. |

- **Handoff:** Validation only. Re-run preflight only after the device is online, then build/install one Release
  provenance, capture one scenario per finalized SwiftUI trace, and inspect each trace immediately. Do not create
  optimization work or claim a before/after result without a valid same-environment baseline.

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
| 14 | `git diff --check`; `xcodebuild -showBuildSettings` parity: app/widget Debug and Release both `1.1.0` / `80`; release-doc consistency search; source/project/CI diff guard | N/A | N/A | N/A | N/A | N/A |
| 15 | `SkyAware_Tests`: 919 passed, 1 failed, 0 skipped; `SkyAware_All_Tests` smoke: 1 passed, 0 failed, 0 skipped | N/A | 919 passed, 1 failed, 0 skipped; inspected `/private/tmp/skyaware-344-results.FsBxsb/unit.xcresult` | 1 passed, 0 failed, 0 skipped; inspected `/private/tmp/skyaware-344-results.FsBxsb/ui-navigation.xcresult` | N/A | Both finalized bundles inspected with `xcresulttool`; unit lane remains incomplete |
| 16 | 269 passed, 1 known #344 cancellation-race failure, 0 skipped | Fresh Release built, installed, and smoke-launched; host trust-chain verification failed | Not run | Blocked: no safe fixtures/control points for all transitions | Partial: valid warm SwiftUI and supplemental signpost traces; no screen recording; privacy stop applied | Finalized focused bundle inspected |

## Handoff rules

- Update only the active issue section and verification row.
- Record exact changed files, concepts/pathways removed, commands, counts, `.xcresult` summaries, and residual risks.
- Do not mark work complete from source inspection, a merged PR, or "tests added."
- Keep simulator, UI, physical-device, Instruments, and comparable before/after evidence distinct.
- Stop at the active issue's acceptance criteria and wait for review.
- Record contradictions and stop conditions; do not create speculative follow-up issues.
