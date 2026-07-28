# Background Refresh Reliability Runbook

**Status:** Planned

**Applies to:** SkyAware scheduled background app refresh, shared ingestion cancellation, location-context reuse,
and background health diagnostics

**Project:** `SkyAware.xcodeproj`

**Parent epic:** [#364](https://github.com/justinrooks/project-arcus/issues/364)

## Related documents

- `AGENTS.md`
- `Sources/AGENTS.md`
- `docs/audits/weekly-performance-audit.md`
- `docs/audits/codebase-architecture-recovery.md`
- `docs/plans/codebase-simplification-runbook.md`
- `docs/plans/codebase-simplification-progress.md`
- `docs/plans/physical-device-release-validation-runbook.md`
- `docs/plans/physical-device-release-validation-progress.md`
- GitHub issues #333, #335, #346, and #360

## Purpose

Restore the strongest background-refresh reliability SkyAware can achieve within Apple's discretionary scheduling
model. Keep one successor request pending, fit essential alert/risk work inside an explicit budget, stop work that
loses its final owner, avoid optional AQI cost, reuse safe location context, and record evidence that distinguishes
desired scheduling from actual execution.

This campaign continues, rather than reopens, completed issues #333 and #335. Those issues removed canceled waiters
and bounded the pending-upload pre-drain. They explicitly did not define active-run cancellation, a global deadline,
or global retry policy.

## Source-of-truth order

1. The active GitHub child issue for its exact review unit.
2. This runbook for campaign guardrails and ordering.
3. `background-refresh-reliability-progress.md` for current status and handoff evidence.
4. Current source and focused tests named by the active issue.
5. The architecture recovery and performance audits for investigation provenance.
6. The physical-device validation campaign for runtime evidence only.

When these sources conflict, stop and record the contradiction. Do not silently broaden the active issue.

## Required read order

1. `AGENTS.md` and `Sources/AGENTS.md`.
2. The active child issue.
3. This runbook.
4. The matching progress-ledger section.
5. Only the likely production files and focused tests named by the issue.

Do not repeat the original investigation or load unrelated Today, Map, widget, or server campaigns.

## Minimal implementation prompt

> Implement only the active child issue in the Background Refresh Reliability epic. Read the issue, this runbook,
> and its progress entry. Preserve the locked invariants, add deterministic characterization before changing
> lifecycle semantics, run and inspect the required validation, update the progress ledger, and stop. Do not continue
> to the next issue or perform adjacent cleanup.

## Target contract

1. A conservative successor `BGAppRefreshTaskRequest` is submitted before ingestion starts.
2. A completed run may authoritatively replace that fallback with the evaluated 20/40/60-minute cadence.
3. Background work uses one monotonic budget with time reserved for persistence and completion.
4. HTTP attempts and retry waits cannot exceed the remaining background budget.
5. AQI is foreground-only and never delays scheduled refresh or background location-change completion.
6. Optional Storm Setup enrichment is admitted only when budget remains and propagates background cancellation.
7. Canceling the final background owner cancels its unshared ingestion work; retained owners keep shared work alive.
8. Scheduled refresh can reuse a privacy-safe durable location/NWS context instead of demanding a five-minute fix.
9. Diagnostics distinguish run start, expiration, completion, desired cadence, and actual scheduler submission.
10. Physical-device evidence is captured by existing issue #360 after implementation, not simulated by unit tests.

## Required guardrails

- Preserve the established 20/40/60-minute cadence bands and their threat gates.
- Preserve one outstanding app-refresh request and the scheduler's authoritative replacement tolerance.
- Preserve hot-alert priority, atomic core projection commits, and accepted/rejected SPC batch semantics.
- Preserve morning, meso, risk-change coalescing, preference gates, and conservative notification behavior.
- Preserve the quota-one, five-second durable upload pre-drain and durable remainder from issue #335.
- Preserve useful shared ingestion when another foreground, remote-alert, location-change, or fire-and-forget owner
  still exists.
- Use structured concurrency and cancellation propagation. Do not introduce detached cleanup or enrichment work.
- Use `ContinuousClock` for runtime budgets; wall-clock `Date` remains appropriate for persisted timestamps.
- Keep foreground HTTP behavior unchanged unless an issue explicitly requires a shared correctness fix.
- Keep location data private. Do not add coordinates, alert payloads, tokens, or user identifiers to diagnostics.
- Use deterministic fakes. Tests must not call live WeatherKit, NWS, SPC, Arcus, AirNow, or APNs.
- Update the matching progress section before closing each child.

## Forbidden scope

- Arcus Signal, ArcusCore, endpoint, DTO, or server implementation changes.
- APNs architecture or notification-policy redesign.
- BGProcessingTask, continued-processing, or background-URLSession migration.
- Changes to cadence bands, jitter policy, or severe-weather product semantics.
- Removing WeatherKit or Storm Setup from foreground refresh.
- AQI persistence or a new background AQI mechanism.
- A new app-wide scheduler, ingestion framework, dependency framework, or event bus.
- Location-permission UX changes or broader location-sharing policy.
- Widget architecture, Today presentation, Map rendering, or unrelated cleanup.
- Duplicating physical-device issue #360; this campaign supplies the fixed build and required evidence fields.

## Current code boundaries to preserve

- `SkyAwareApp` owns SwiftUI background-task registration and scene lifecycle entry.
- `BackgroundScheduler` owns pending-request inspection, submission, and replacement policy.
- `BackgroundOrchestrator` owns background sequencing, cadence evaluation, notifications, and health outcomes.
- `HomeIngestionCoordinator` owns compatible-run joining, serialization, and pending-plan merging.
- `HomeIngestionExecutor` owns provider lanes, core commit, and optional enrichment.
- `URLSessionHTTPClient` owns request policy, retries, and cache fallback.
- `LocationSession` and `LocationContextResolver` own location lifecycle and accepted context formation.
- `GridPointProvider` and `NwsMetadataRepo` own NWS region metadata.
- `BgHealthStore` owns durable background diagnostics.

## Issue #367 location-context reuse policy

`BackgroundLocationContextReusePolicy` is a pure scheduled-refresh contract; it does not restore, persist, or
resolve a `LocationContext`. Its caller supplies authorization, cache state, movement evidence, and an explicit
evaluation time.

| Condition | Always authorization | When-In-Use authorization |
| --- | --- | --- |
| Complete cache; valid coordinates; age 0...90 minutes; accuracy `(0, 100]` meters; no movement evidence | Reuse cached context | Reuse cached context |
| Missing, corrupt, incomplete, stale, future-dated, invalid-coordinate, or unacceptable-accuracy cache | Attempt a fresh location | Skip location-dependent work |
| Significant-location change or explicit invalidation | Attempt a fresh location | Skip location-dependent work |
| Denied, restricted, not-determined, or unknown authorization | Skip location-dependent work | Skip location-dependent work |

The 90-minute cap is an explicit product privacy tolerance, not a bound on scheduler lateness. Apple's
[`earliestBeginDate`](https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate)
only prevents an earlier launch and does not guarantee a launch at that time. A delayed launch after 90 minutes
therefore deliberately skips location-dependent work under When-In-Use rather than presenting arbitrary stale
location. The 100-meter inclusive accuracy ceiling matches the accepted update gate. A significant-location change or
explicit invalidation wins over age and accuracy. When-In-Use never prescribes a fresh background fix or permission
prompt; #366 may wire eligible reuse only after it adds durable context storage and restoration.

## Issue #366 durable context integration

- Durable storage is a versioned `UserDefaults` record containing coordinates, timestamp, horizontal accuracy, H3,
  and machine NWS grid/region identifiers required to reconstruct `LocationContext`.
- It excludes placemark summaries, city/state, county/fire display labels, upload queue payloads, credentials, and
  tokens. Corrupt, partial, future-dated, invalid-coordinate, and incomplete-region records are deleted.
- Only `.backgroundRefresh` provenance invokes #367. An eligible record is returned directly; it must not trigger a
  location refresh, reverse-geocode, or NWS metadata request. Foreground, manual, onboarding, and location-change
  paths retain their existing resolver behavior.
- A newer snapshot with a changed H3 identity invalidates the durable record before fallible resolution. A newer
  snapshot with the same H3 identity can refresh recency and accuracy while preserving cached grid identifiers.

## Sequential execution

| Order | Work item | Preferred implementer | Stop condition |
| ---: | --- | --- | --- |
| 01 | [#371](https://github.com/justinrooks/project-arcus/issues/371) — Schedule the next app refresh before ingestion | `GPT-5.6 Terra / medium` | A fallback request exists before blocked work and success may replace it authoritatively. |
| 02 | [#374](https://github.com/justinrooks/project-arcus/issues/374) — Remove air quality from background ingestion | `GPT-5.6 Terra / medium` | Scheduled refresh and background location change make zero AQI requests; foreground behavior remains. |
| 03 | [#373](https://github.com/justinrooks/project-arcus/issues/373) — Define a global background refresh budget contract | `GPT-5.6 Terra / medium` | One tested monotonic budget exposes work, finalization, and admission decisions without changing providers. |
| 04 | [#368](https://github.com/justinrooks/project-arcus/issues/368) — Bound background HTTP retries by remaining task budget | `GPT-5.6 Terra / medium` | No background attempt or wait can cross the supplied deadline; foreground policy is unchanged. |
| 05 | [#370](https://github.com/justinrooks/project-arcus/issues/370) — Make optional enrichment deadline-aware and cancellation-transparent | `GPT-5.6 Terra / medium` | Optional work skips near deadline and background cancellation cannot become nominal success. |
| 06 | [#372](https://github.com/justinrooks/project-arcus/issues/372) — Characterize background ingestion ownership at expiration | `GPT-5.6 Terra / medium` | Tests lock background-only, shared, queued, and fire-and-forget ownership without production behavior changes. |
| 07 | [#369](https://github.com/justinrooks/project-arcus/issues/369) — Cancel unowned background ingestion without disrupting shared runs | `GPT-5.6 Terra / medium` | Final background-owner cancellation stops its run; retained owners and pending merging remain correct. |
| 08 | [#367](https://github.com/justinrooks/project-arcus/issues/367) — Define the background location-context reuse policy | `GPT-5.6 Terra / medium` | Authorization, age, movement, and missing-cache decisions are explicit and deterministically tested. |
| 09 | [#366](https://github.com/justinrooks/project-arcus/issues/366) — Reuse durable location and NWS region context | `GPT-5.6 Terra / medium` | Eligible scheduled runs avoid fresh-location and redundant NWS prerequisites while invalid context refreshes safely. |
| 10 | [#365](https://github.com/justinrooks/project-arcus/issues/365) — Record truthful background execution and scheduling diagnostics | `GPT-5.6 Terra / medium` | Start, phase, expiration, completion, and scheduler submission are distinguishable without private payloads. |

Execute sequentially unless a child issue explicitly declares independence. Stop after each issue for human review.
After issue 10, existing issue #360 owns physical-device Release evidence for backlog, expiration, and actual cadence.

## Model guidance

All issues are intentionally scoped for `GPT-5.6 Terra / medium`. No issue currently requires GPT-5.6 Sol:

- scheduling recurrence is isolated before budget work;
- the budget contract is defined before HTTP and enrichment integration;
- ownership characterization is separate from active-run cancellation;
- location policy is defined before persistence/reuse.

Stop and propose `GPT-5.6 Sol / high` only if issue 07 reveals an uncharacterized multi-owner actor race that cannot
be expressed with the named coordinator boundary, or issue 09 requires an unplanned SwiftData migration crossing
more than five production files. The escalation report must name the ambiguity, affected files, and why another
Terra-sized slice cannot contain it. Do not silently upgrade.

## Verification defaults

- Set `ISSUE_RESULTS="$(mktemp -d /private/tmp/skyaware-results.XXXXXX)"`.
- Use iPhone 17 or iPhone 17 Pro on iOS 26.5 when available.
- Run the focused suites named by the active issue during iteration.
- Run a Debug build after production changes.
- Run the full `SkyAwareTests` lane once for scheduler, HTTP, coordinator, persistence, or cross-lifecycle changes.
- Inspect every finalized `.xcresult` and report exact passed, failed, and skipped counts.
- Run `git diff --check`.
- Planning-only and test-characterization-only issues do not require an app build unless production seams change.
- Do not claim cadence, energy, expiration, or future scheduling improvement without issue #360 physical-device
  evidence.

## Quality bar for GPT-5.6 Terra medium

- One behavior or contract slice per issue.
- Prefer one to three production files and a diff near 200 changed lines when practical.
- Do not touch more than five production files without stopping to re-plan.
- Add characterization before changing scheduler, cancellation, or location policy.
- Favor a narrow value/lease/deadline contract over a generic framework.
- Preserve error distinctions; do not turn cancellation or deadline exhaustion into success.
- Record exact validation in the progress ledger and stop when acceptance criteria are met.
