# Background Refresh Reliability Progress

## Overview

This ledger tracks the ordered campaign to make SkyAware background refresh recurring, bounded,
cancellation-safe, location-efficient, and diagnostically truthful.

**Epic status:** Planned

**Primary GitHub epic:** [#364](https://github.com/justinrooks/project-arcus/issues/364)

## Global decisions

- `GPT-5.6 Terra / medium` is the workhorse for every child issue.
- No issue currently requires GPT-5.6 Sol; the runbook defines explicit escalation thresholds.
- Completed issues #333 and #335 are prerequisites. They are not reopened or duplicated.
- Schedule the next request before ingestion, then authoritatively replace it after successful cadence evaluation.
- Use a soft work deadline with finalization reserve rather than trying to consume all runtime granted by iOS.
- Remove AQI from scheduled refresh and background location-change work; foreground AQI remains unchanged.
- Keep risk-profile detection and notifications. Their local computation is not the dominant budget cost.
- Preserve shared useful ingestion, but cancel work after its final background owner disappears.
- Define the location-context staleness/authorization matrix before implementing reuse.
- Existing issue #360 owns physical-device Release evidence after the production slices land.

## Current state summary

The app registers one SwiftUI `.appRefresh` task and reschedules only after `BackgroundOrchestrator.run()` returns.
The orchestrator performs a bounded upload drain, unified all-lane ingestion, notification evaluation, health
persistence, and cadence calculation. Unified ingestion requires fresh location, resolves NWS metadata, refreshes
hot and slow products, optionally refreshes WeatherKit, commits the risk projection, and waits for Storm Setup and
AQI enrichment.

The current background HTTP policy permits four attempts with 5/10/15-second retry delays. No global deadline
connects the OS cancellation signal, HTTP retries, optional enrichment, and finalization. Canceling an ingestion
waiter removes that waiter but intentionally leaves coordinator-owned work running. Diagnostics record only
completed/caught outcomes and store a desired next date before scheduler submission occurs.

## Locked behavior invariants

- Threat-driven 20/40/60-minute cadence.
- One pending app-refresh request and authoritative replacement tolerance.
- Quota-one, five-second pending-upload pre-drain with durable remainder.
- Unified ingestion, hot-alert priority, and one merged pending plan.
- Atomic Home core projection and accepted/rejected SPC map persistence.
- Core publication before optional enrichment.
- Useful shared runs survive while another legitimate owner remains.
- Morning, meso, risk-change, preference, coalescing, and notification semantics.
- Privacy-first location handling and no private diagnostic payloads.

## Issue sequence

| Order | Issue | Preferred model / intelligence | Status | Dependency |
| ---: | --- | --- | --- | --- |
| 00 | [#364](https://github.com/justinrooks/project-arcus/issues/364) — Epic | Coordination | Planned | Investigation |
| 01 | [#371](https://github.com/justinrooks/project-arcus/issues/371) — Schedule the next app refresh before ingestion | `GPT-5.6 Terra / medium` | Planned | #335 |
| 02 | [#374](https://github.com/justinrooks/project-arcus/issues/374) — Remove air quality from background ingestion | `GPT-5.6 Terra / medium` | Planned | None |
| 03 | [#373](https://github.com/justinrooks/project-arcus/issues/373) — Define a global background refresh budget contract | `GPT-5.6 Terra / medium` | Planned | 01 |
| 04 | [#368](https://github.com/justinrooks/project-arcus/issues/368) — Bound background HTTP retries by remaining task budget | `GPT-5.6 Terra / medium` | Planned | 03 |
| 05 | [#370](https://github.com/justinrooks/project-arcus/issues/370) — Make optional enrichment deadline-aware and cancellation-transparent | `GPT-5.6 Terra / medium` | Planned | 03, 04 |
| 06 | [#372](https://github.com/justinrooks/project-arcus/issues/372) — Characterize background ingestion ownership at expiration | `GPT-5.6 Terra / medium` | Planned | #333, #335 |
| 07 | [#369](https://github.com/justinrooks/project-arcus/issues/369) — Cancel unowned background ingestion without disrupting shared runs | `GPT-5.6 Terra / medium` | Planned | 06 |
| 08 | [#367](https://github.com/justinrooks/project-arcus/issues/367) — Define the background location-context reuse policy | `GPT-5.6 Terra / medium` | Planned | 03 |
| 09 | [#366](https://github.com/justinrooks/project-arcus/issues/366) — Reuse durable location and NWS region context | `GPT-5.6 Terra / medium` | Planned | 08 |
| 10 | [#365](https://github.com/justinrooks/project-arcus/issues/365) — Record truthful background execution and scheduling diagnostics | `GPT-5.6 Terra / medium` | Planned | 01, 03-09 |

## Existing code map

- Task registration and recurrence: `Sources/App/SkyAwareApp.swift`
- Scheduler policy: `Sources/Infrastructure/Scheduling/BackgroundScheduler.swift`
- Background sequence and cadence: `Sources/Features/Background/BackgroundOrchestrator.swift`
- Trigger plans: `Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift`
- Shared run ownership: `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- Provider lanes and enrichment: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`,
  `Sources/App/HomeRefreshV2/HomeStormSetupIngestion.swift`
- HTTP policy and retries: `Sources/Infrastructure/Networking/HTTPDataDownloader.swift`
- Location context: `Sources/Infrastructure/Location/LocationSession.swift`,
  `Sources/Infrastructure/Location/LocationContextResolver.swift`,
  `Sources/Infrastructure/Location/LocationSnapshotCache.swift`
- NWS region metadata: `Sources/Providers/NWS/GridPointProvider.swift`, `Sources/Repos/NwsMetadataRepo.swift`
- Health persistence/UI: `Sources/Models/Health/BgRunSnapshot.swift`,
  `Sources/Models/Health/BgHealthStore.swift`,
  `Sources/Features/Diagnostics/BgHealthDiagnosticsView.swift`
- Focused tests: `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`,
  `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`,
  `Tests/UnitTests/StormSetupIngestionTests.swift`,
  `Tests/UnitTests/HTTPDataDownloaderTests.swift`,
  `Tests/UnitTests/LocationContextResolverTests.swift`

## Investigation notes

- Apple recommends scheduling the successor at the beginning of recurring SwiftUI app-refresh work. Current code
  schedules only after the entire orchestrator returns.
- The current request graph can exceed a short app-refresh window before retry paths are considered.
- AQI runs for every weather-lane plan even when WeatherKit freshness suppresses its own request. It is uncached,
  inherits background retry policy, and blocks final snapshot completion.
- Storm Setup and AQI run concurrently, but both remain a structured completion barrier after core publication.
- Risk-change evaluation itself is local and comparatively cheap. Do not remove it as a budget shortcut.
- Background refresh requires a fresh location and accepts cached location only within five minutes. When-In-Use
  authorization does not keep the location manager running in background.
- `GridPointProvider` writes `lastSnapshot` but does not reuse it; region labels add sequential NWS dependencies.
- Waiter cancellation is prompt after issue #333, but active coordinator work intentionally retains independent
  ownership. Issue 07 changes only the final-owner case after issue 06 characterization.
- Health records omit abrupt termination and conflate desired scheduling with successful scheduler submission.

## Status ledger

### Issue #371 — 01: Schedule the next app refresh before ingestion

- **Status:** Completed (2026-07-28)
- **Goal:** Keep a successor request pending even if ingestion expires or fails.
- **Required proof:** submission precedes blocked work; evaluated success may replace the fallback; cancellation and
  failure leave a valid successor.
- **Implementation:** `BackgroundRefreshLifecycle` awaits conservative ensure scheduling before orchestration, then
  submits the evaluated `Outcome.next` authoritatively. `BackgroundScheduler` now reports submission/preservation
  outcomes and restores the prior request if an authoritative replacement is rejected.
- **Validation:** `BackgroundSchedulerReplacementPolicyTests` and `BackgroundRefreshLifecycleTests` passed 12/12 on
  iPhone 17, iOS 26.5, Debug (`/private/tmp/skyaware-results.9OwyAN/background-refresh-lifecycle.xcresult`). The
  full `SkyAwareTests` lane passed 931/931 on the same simulator/configuration
  (`/private/tmp/skyaware-results.b2ldLY/unit.xcresult`); the result bundle's per-configuration counter reports 938
  parameterized runs. Debug build passed on iPhone 17.
- **Residual risk:** System submission remains discretionary; physical-device cadence evidence remains deferred to
  issue #360. Do not change cadence bands or global work budgets.

### Issue #374 — 02: Remove air quality from background ingestion

- **Status:** Completed (2026-07-28)
- **Goal:** Make AQI foreground-only.
- **Required proof:** scheduled refresh and background location change issue zero AQI requests; foreground activation,
  manual refresh, and location change retain existing AQI behavior.
- **Implementation:** `HomeIngestionExecutor` now requests AQI only for weather-lane plans classified by its existing
  execution-mode policy as foreground. Background plans continue through the same structured Storm Setup enrichment
  and weather paths, while publishing AQI `.preserve` without querying the provider.
- **Validation:** `StormSetupIngestionTests` passed 38/38 on iPhone 17, iOS 26.5, Debug
  (`/private/tmp/skyaware-results.voWwAj/air-quality-background-policy.xcresult`). The full `SkyAwareTests` lane
  passed 938/938 on the same simulator/configuration (`/private/tmp/skyaware-results.h2B6kg/unit.xcresult`); its
  per-configuration counter reports 945 parameterized runs. Debug build passed on iPhone 17.
- **Residual risk:** Physical-device runtime impact remains unproven; issue #360 owns that evidence.
- **Handoff:** No AQI persistence, endpoint, DTO, or presentation changes.

### Issue #373 — 03: Define a global background refresh budget contract

- **Status:** Completed (2026-07-28)
- **Goal:** Establish one monotonic work deadline with reserved finalization time.
- **Required proof:** deterministic remaining-time and admission decisions at boundaries.
- **Implementation:** `BackgroundRefreshBudget` defines the soft 30-second completion window, five-second
  finalization reserve, derived 25-second work deadline, nonnegative remaining durations, and explicit optional-work
  admission decisions. The unused value remains ready for #368 and #370 integration.
- **Validation:** `BackgroundRefreshBudgetTests` passed 9/9 on iPhone 17, iOS 26.5, Debug
  (`/private/tmp/skyaware-results.sPqYN2/background-refresh-budget.xcresult`). Debug build passed on iPhone 17.
- **Handoff:** Contract/policy only; do not rewrite providers in this issue.

### Issue #368 — 04: Bound background HTTP retries by remaining task budget

- **Status:** Completed (2026-07-28)
- **Goal:** Prevent a request or retry wait from crossing the background deadline.
- **Required proof:** attempt count, retry delay, Retry-After, cancellation, cache fallback, and foreground-policy
  regression tests.
- **Implementation:** `BackgroundOrchestrator` creates one standard #373 budget per scheduled run and scopes it through
  the coordinator's child executor task. Budgeted background HTTP caps per-attempt timeout, races an in-flight
  `URLSession` operation against the monotonic remaining work time, refuses retry waits without a usable subsequent
  window, and preserves eligible GET cache fallback. Deadline exhaustion is recorded across non-throwing provider
  boundaries so the executor cannot publish a nominal-success snapshot, while queued coordinator follow-ups retain
  their submitted execution context. Merging scheduled work with an unbudgeted background trigger preserves the
  scheduled budget regardless of submission order. Foreground requests do not join a budgeted active run; they are
  queued as an unbudgeted follow-up, and waiter eligibility prevents the expired background result from resolving
  that owner. Foreground and unbudgeted-background policy paths otherwise remain unchanged.
- **Validation:** `HTTPDataDownloaderTests` passed **15 / 15** with **0 failed, 0 skipped** on iPhone 17, iOS 26.5,
  Debug (`/private/tmp/skyaware-results.nI9gjk/http-budget.xcresult`). Focused downloader/coordinator/executor
  correction tests passed **90 / 90** with **0 failed, 0 skipped**
  (`/private/tmp/skyaware-results.7waSyp/deadline-correction.xcresult`). Debug build passed on iPhone 17. Full
  `SkyAwareTests` passed with **0 failed, 0 skipped** on iPhone 17, iOS 26.5, Debug; the result summary reports
  **961 passed** (the device-configuration counter reports 968 parameterized runs)
  (`/private/tmp/skyaware-results.aT8RML/unit.xcresult`).
- **Correction validation:** coordinator budget/ownership tests passed **25 / 25** with **0 failed, 0 skipped**
  on iPhone 17, iOS 26.5, Debug
  (`/private/tmp/skyaware-results.aT8RML/coordinator-budget-merge.xcresult`).
- **Handoff:** No endpoint-specific retry exceptions.

### Issue #370 — 05: Make optional enrichment deadline-aware and cancellation-transparent

- **Status:** Completed (2026-07-28)
- **Goal:** Admit optional Storm Setup only with sufficient budget and preserve cancellation as cancellation.
- **Required proof:** near-deadline skip, mid-request cancellation, successful enrichment, and core completion.
- **Implementation:** `HomeIngestionExecutor` now admits background Storm Setup using the configured five-second Storm
  Setup timeout as the `BackgroundRefreshBudget` estimate. Insufficient work time returns the already-published core
  snapshot without a provider request or enrichment publication. After joined optional work, background parent
  cancellation and HTTP deadline exhaustion throw `CancellationError` before a nominal enrichment publication; the
  foreground Storm Setup timeout and nonthrowing cancellation policy remain unchanged.
- **Validation:** `StormSetupIngestionTests` and `BackgroundOrchestratorCadenceTests` passed **68 / 68** with
  **0 failed, 0 skipped** on iPhone 17, iOS 26.5, Debug
  (`/private/tmp/skyaware-results.oMZrlo/optional-enrichment.xcresult`). Full `SkyAwareTests` passed **965 / 965**
  with **0 failed, 0 skipped** on the same simulator/configuration; the device-configuration counter reports
  **972** parameterized runs (`/private/tmp/skyaware-results.DjzvwF/unit.xcresult`). Debug build passed on iPhone 17.
- **Handoff:** AQI remains foreground-only; #369 still owns active-run ownership changes. No detached enrichment was
  introduced.

### Issue #372 — 06: Characterize background ingestion ownership at expiration

- **Status:** Completed (2026-07-28)
- **Goal:** Lock the ownership matrix before active-run cancellation semantics change.
- **Ownership matrix:**
  - **Pre-canceled background waiter:** the waiter is removed with `CancellationError`; its accepted coordinator run
    still completes today. #369 must resolve this through serialized state: cancel if removal leaves the final
    background owner after submission, but preserve exactly-once success if completion wins first.
  - **Only active background waiter canceled:** the waiter is removed and the executor remains uncanceled through
    completion today. #369 must cancel this final cancelable background-owner case.
  - **Compatible foreground session-tick waiter joins a background-originated run:** canceling the background waiter
    leaves the foreground waiter to complete; the executor remains uncanceled. #369 must preserve this shared work.
  - **Background fire-and-forget submission:** a joining foreground waiter may cancel, while the explicit submission
    keeps the executor running. #369 must preserve explicit fire-and-forget work.
  - **Queued background follow-up waiter canceled:** the waiter receives `CancellationError`, no later callbacks,
    and its pending background plan still starts after the active run completes. #369 must retain the established
    pending-plan behavior until it has explicit ownership evidence; this issue does not redesign queued work.
  - **Finish-before-cancel and repeated cancel:** existing coordinator tests prove successful completion wins once
    finish removes the waiter, and duplicate cancellation resumes a waiter only once while the shared executor stays
    active. These remain invariants for #369.
- **Validation:** Debug `SkyAware_Tests` focused coordinator and background-cadence suites passed **47 / 47** with
  **0 failed, 0 skipped** on iPhone 17 / iOS 26.5. Result bundle:
  `/private/tmp/skyaware-results.2oCz5g/background-ownership.xcresult`.
- **Handoff:** Test-only characterization. No Debug seam was necessary; #369 owns the intentional transition for
  the final background-only active owner.

### Issue #369 — 07: Cancel unowned background ingestion without disrupting shared runs

- **Status:** Implemented; simulator validation blocked (2026-07-28)
- **Goal:** Stop a run after its final background owner cancels while retaining useful shared work.
- **Required proof:** real executor cancellation reaches HTTP/enrichment; retained owners finish; continuations resume
  once; pending-plan semantics remain.
- **Implementation:** `HomeIngestionCoordinator` now classifies a plain background waiter as cancelable, records
  explicit `enqueue(...)` ownership for active and pending runs, and cancels only the current active task after the
  final cancelable active waiter disappears. Foreground, remote-alert, location, and explicit owners retain shared
  work; pending plans and their execution contexts remain untouched until normal `finishRun` advancement.
- **Tests:** Updated the two #372 expectations for pre-canceled and sole active background waiters. Added
  foreground/remote-alert/location/explicit-pending retention coverage and a coordinator-to-blocked-Storm-Setup
  cancellation test using actor acknowledgements.
- **Validation:** Debug build completed on iPhone 17. The requested focused test invocation compiled and installed
  the test bundle but the simulator runner remained at `wait_for_debugger`; its result bundles were not finalized
  and `xcresulttool` could not inspect counts. Result directory:
  `/private/tmp/skyaware-results.5twe3Z`. `git diff --check` passed.
- **Handoff:** No ownership race requires Sol/high: the existing actor, active task, and run number serialize the
  cancellation/completion path. Full-unit validation remains blocked on the simulator runner and must be rerun before
  closing the issue; no physical-device claim is made.

### Issue #367 — 08: Define the background location-context reuse policy

- **Status:** Completed (2026-07-28)
- **Goal:** Make authorization, age, accuracy, movement, and cache-miss decisions explicit.
- **Required proof:** a pure deterministic policy matrix, including stale/travel and When-In-Use cases.
- **Implementation:** Added the pure `Sendable` `BackgroundLocationContextReusePolicy`. Complete, valid cached context
  may reuse only through an inclusive 90-minute explicit product privacy tolerance and inclusive 100-meter accuracy
  boundary with no
  movement/invalidation evidence. Always authorization otherwise attempts fresh location; When-In-Use reuses only an
  eligible cache and otherwise skips location-dependent work. Denied, restricted, not-determined, and unknown states
  skip without a prompt. Invalid coordinates, future timestamps, non-finite/nonpositive accuracy, incomplete context,
  and corrupt cache never reuse.
- **Tests:** Added `BackgroundLocationContextReusePolicyTests` covering authorization, cache, age and accuracy
  boundaries, all 20/40/60-minute cadence bands, invalid values, movement/invalidation, stale travel risk, future timestamps, and fixed-input
  determinism. `SkyAware.xcodeproj` excludes the new test source from the app target as required by its synchronized
  test-folder membership configuration.
- **Validation:** `BackgroundLocationContextReusePolicyTests` passed **10 / 10** with **0 failed, 0 skipped** on
  iPhone 17, iOS 26.5, Debug
  (`/private/tmp/skyaware-results.9Svt2U/location-policy-privacy-tolerance.xcresult`). Debug build passed
  on iPhone 17. `git diff --check` passed.
- **Residual risk:** `earliestBeginDate` does not bound scheduler delay. A launch beyond the 90-minute product privacy
  tolerance intentionally skips location-dependent work under When-In-Use; this issue supplies no physical-device,
  persistence, resolver, or NWS-reuse evidence.
- **Handoff:** #366 may map durable cache restoration into this input contract and invoke the result. No permission UX,
  persistence, live resolver, trigger, ingestion, or NWS changes were included.

### Issue #366 — 09: Reuse durable location and NWS region context

- **Status:** Implemented; simulator test finalization pending
- **Goal:** Avoid unnecessary fresh-location and NWS metadata prerequisites when issue 08 allows reuse.
- **Required proof:** process-relaunch cache restoration, stable-location reuse, invalid/moved context refresh,
  corrupted-cache fallback, and privacy-safe persistence.
- **Implementation:** Added versioned `UserDefaults` durable context persistence in `LocationSnapshotCache.swift` and
  wired it through `LocationSession`, `HomeIngestionExecutor`, and `Dependencies`. Scheduled refresh is selected only
  from background provenance (never the shared `(true, false)` request shape), applies #367, directly restores an
  eligible context, and skips resolver/geocoder/NWS calls. Any newer snapshot in a different H3 identity invalidates
  the durable record before fallible resolution; a stable newer snapshot refreshes the persisted timestamp/accuracy
  while retaining truthful cached NWS identifiers.
- **Privacy:** The record includes only coordinates, timestamp, accuracy, H3, and machine NWS grid/region fields.
  It excludes placemark summaries, city/state, county/fire display labels, notification payloads, credentials, and
  upload-queue fields. Corrupt, partial, future-dated, invalid-coordinate, and incomplete-region records are removed.
- **Tests:** Added durable-cache process-restoration, raw-persistence privacy, and invalid-record tests to
  `LocationContextResolverTests.swift`. Debug build passed on iPhone 17, Debug. The focused simulator test command
  created `/private/tmp/skyaware-results.8ggUPt/location-context.xcresult`, but the bundle remained in staging and
  did not produce an inspectable final result; no pass/fail count is claimed. Full unit lane remains pending.
- **Residual risk:** Physical-device behavior remains owned by #360. Finish simulator test finalization and the full
  unit lane before closing the issue; no scheduler cadence or energy claim is supported by this implementation.
- **Handoff:** Stop and re-plan before a schema migration or more than five production files.

### Issue #365 — 10: Record truthful background execution and scheduling diagnostics

- **Status:** Implemented; focused simulator validation passed; full unit lane did not finalize.
- **Contract:** `BgHealthStore` persists a run ID at start, finalizes that same record with success, skip, failure,
  cancellation, or expiration, and retains unfinished starts. It separately stores the desired cadence date, fallback
  and authoritative scheduler outcomes, and categorical upload-drain and unified-ingestion phase results/durations.
- **Privacy:** The persisted contract contains only the local diagnostic run ID, categorical states, dates, and
  durations; it contains no coordinates, placemarks, alert content, URLs, tokens, or credentials.
- **Validation:** `BackgroundOrchestratorCadenceTests` and `BackgroundRefreshLifecycleTests` passed **36 / 36** with
  **0 failed, 0 skipped** on iPhone 17, iOS 26.5, Debug
  (`/private/tmp/skyaware-results.3TQkO3/background-diagnostics-review.xcresult`). `BgHealthStoreTests` separately
  passed **5 / 5** with **0 failed, 0 skipped** on the same simulator and configuration, including current-schema
  reopen and legacy-schema migration coverage
  (`/private/tmp/skyaware-rereview-365.wsBH0A/health-store.xcresult`). The full `SkyAwareTests` lane compiled but did
  not produce a finalized result bundle
  (`/private/tmp/skyaware-results.i0pbM9/unit-review.xcresult`), so no full-lane count is claimed. `git diff --check`
  passed.
- **Handoff:** #360 must capture one post-fix Release SHA's local diagnostic record: started/ended timestamps and
  terminal state; desired cadence date (not an Apple launch claim); fallback and authoritative scheduler outcomes;
  upload-drain duration plus drained/remaining outcome; unified-ingestion duration plus terminal outcome; and any
  durable upload remainder. Keep device artifacts free of coordinates, alert content, requests, URLs, tokens, and
  identifiers other than the local diagnostic run ID.

## Verification ledger

| Issue | Focused tests | Full unit lane | Build | Physical-device evidence |
| ---: | --- | --- | --- | --- |
| 01 | Passed (12/12) | Passed (931/931) | Passed | Deferred to #360 |
| 02 | Pending | Pending | Pending | Not required |
| 03 | Pending | Pending | Pending | Deferred to #360 |
| 04 | Pending | Pending | Pending | Deferred to #360 |
| 05 | Passed (68/68) | Passed (965/965) | Passed | Deferred to #360 |
| 06 | Pending | Not required unless production seam changes | Conditional | Not required |
| 07 | Pending | Pending | Pending | Deferred to #360 |
| 08 | Pending | Conditional | Conditional | Deferred to #360 |
| 09 | Pending | Pending | Pending | Deferred to #360 |
| 10 | Pending | Pending | Pending | Required by #360 |

## Handoff notes

- Implement one issue at a time and update its ledger section with exact files, behavior, test counts, result-bundle
  paths, residual risk, and next dependency.
- Do not begin issue #360's post-fix runtime capture until issues 01-10 are complete on one source SHA.
- If issue #360 cannot observe scheduled-versus-actual cadence after issue 10, record the exact missing instrumentation
  rather than inferring reliability.
