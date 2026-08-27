# Physical-Device Release Validation Runbook

**Status:** Retired — superseded by targeted workflow validation

**Applies to:** SkyAware iOS Today and background physical-device Release validation

**Project:** `SkyAware.xcodeproj`

**Parent epic:** [#346](https://github.com/justinrooks/project-arcus/issues/346)

## Retirement decision

This campaign was retired on 2026-08-26 and epic #346 was closed as **not planned**. Repeated physical-device attempts
established that the combined SwiftUI, hitch, signpost, privacy, cohort, and genuine-provider-state evidence contract
was disproportionate and often unreproducible. Closing the campaign does not convert incomplete traces into successful
evidence and does not create a new performance claim.

Issues #347, #348, #352-#356, #360, and #361 were closed as not planned. Issues #349-#351 and #357-#359 were retained
as independent, targeted-validation candidates using deterministic tests, fixture-driven rendered evidence, and
repeatable XCTest metrics where stable. Physical-device profiling is now optional and should begin only from a concrete
workflow question supported by a user report, production diagnostic, code-level mechanism, or repeatable measurement.

The procedures below remain preserved as historical evidence and privacy/comparability guidance. They are not a
current release gate or an instruction to resume the full scenario matrix.

## Related documents

- `AGENTS.md`
- `Sources/AGENTS.md`
- `docs/plans/physical-device-release-validation-progress.md`
- `docs/plans/today-refresh-performance-runbook.md`
- `docs/plans/today-refresh-performance-progress.md`
- `docs/plans/codebase-simplification-runbook.md`
- `docs/plans/codebase-simplification-progress.md`
- GitHub issues #318, #319, #327, #329, and #345

## Purpose

Capture the physical-device Release evidence deferred by issue #345 as small, scenario-specific review units. Each
scenario must finish as **Complete**, **Blocked**, or **Not comparable**. Missing control points remain blockers; they
must never become optimistic runtime claims.

This is a validation campaign, not a performance-optimization or feature campaign.

## Source-of-truth order

1. The active child issue for its exact scenario and stop conditions.
2. This runbook for campaign-wide evidence, privacy, and comparability rules.
3. `physical-device-release-validation-progress.md` for the current capture cohort and completed evidence.
4. `today-refresh-performance-progress.md` and `codebase-simplification-progress.md` for historical findings.
5. Current source, signposts, and focused deterministic tests for contracts not changed by this campaign.

Historical ledger summaries are evidence only for what they recorded. Invalid raw traces remain invalid.

## Required read order

1. `AGENTS.md` and `Sources/AGENTS.md`.
2. The active child issue.
3. This runbook.
4. The matching section in `physical-device-release-validation-progress.md`.
5. Only the relevant historical ledger section, production symbols, and focused tests named by the issue.

Do not repeat the Today architecture investigation or reopen completed optimization work.

## Minimal implementation prompt

> Implement only the active child issue in the Physical-Device Release Validation epic. Read the issue, runbook, and
> matching progress section. Confirm the capture cohort before touching the device, obtain approval for destructive
> preparation, capture one scenario per trace, analyze it immediately, record rendered evidence separately, update
> the progress ledger, and stop. Do not change product behavior or continue to another scenario.

## Evidence contract

Every result must be classified separately:

- **Deterministic:** focused tests proving state, ownership, persistence, or cancellation contracts.
- **Trace:** finalized physical-device Instruments data proving runtime timing and responsiveness.
- **Rendered:** a separate screen recording proving visible layout, identity, and motion behavior.
- **Fixture-qualified:** evidence whose state was prepared with an explicit non-production control.
- **Historical:** persisted measurements whose raw artifacts or environment prevent current reanalysis.
- **Blocker:** the exact attempted preparation, missing control point, environment, and next required condition.

Deterministic tests do not prove rendering. Videos do not prove timing. Traces do not prove semantic correctness.
Fixture-qualified evidence must not be relabeled as a production-state measurement.

## Capture cohort

Before the first scenario, record and lock:

- source SHA and worktree state;
- Xcode and SDK versions;
- Release configuration;
- absolute `.app` path, executable hash, bundle version, signing identity, and installation command;
- device name, model, UDID, OS version/build, connection transport, and trust state;
- Instruments template or template path and tool-script SHAs;
- artifact root and UTC cohort start.

Use one source, build, device, OS, toolchain, transport, and template for comparable traces. If any changes, begin a
new cohort. Do not silently merge cohorts.

USB is preferred for this campaign because it keeps CoreDevice and Instruments available while Wi-Fi conditions are
changed. Record the transport and do not switch between USB and wireless inside a cohort.

## Separate native screen-recording transfer workflow

Rendered evidence is a separate, non-concurrent pass; it is never recorded while Instruments is tracing. Before
starting, confirm that the visible state contains no private coordinates, location-derived endpoints, alert content,
tokens, or identifiers. Start and stop the device's native Control Center screen recording manually, then review the
recording on-device before transfer. Transfer the approved clip over the locked USB connection using Finder or Image
Capture into the cohort's external artifact root, with a UTC scenario identifier. Do not use cloud sharing, add the
recording to source control, or delete the device copy without explicit approval. Record the clip as **Rendered**
evidence only; it does not establish trace timing or performance.

## Required guardrails

- Preserve cached-first and resolve-forward Today behavior.
- Preserve useful same-location cached content during partial failure.
- Preserve authoritative-empty alerts and atomic core publication.
- Preserve core visibility before optional enrichment.
- Preserve stable Local Alerts, Storm Setup, scroll, and accessibility identity.
- Preserve lifecycle supersession and background upload budget semantics.
- Keep all trace, analysis, result-bundle, and recording artifacts outside source control.
- Use the physical device and Release configuration for runtime evidence.
- Use the SwiftUI template with a signpost-only instrument only if the privacy smoke proves it does not collect an
  app-log store. An `os-log` or `os-log-arg` schema is a privacy failure; do not inspect log entries or payloads.
- Create the signpost-only instrument through Instruments' native template editor: start from SwiftUI, add only
  `os_signposts`, filter it to subsystem `com.skyaware.app` and category `app.homeRefresh`, and save the template
  outside the repository. Do not add Points of Interest or any Logging instrument.
- Capture screen recordings separately when concurrent recording could perturb performance.
- Analyze and validate every trace before starting the next scenario.
- Keep coordinates, endpoints derived from location, alert content, tokens, and user identifiers out of artifacts and
  documentation.
- Obtain explicit approval before uninstalling the app, clearing app data, changing permissions, or mutating durable
  device state.

## Forbidden scope

- Production optimization, feature work, architecture changes, or unrelated cleanup.
- Arcus Signal, WeatherKit, NWS, SPC, APNs, or production-server manipulation.
- New production/debug fixtures or provider seams inside a scenario issue.
- Unsafe persisted-location, upload-queue, credential, or preference mutation.
- Simulator performance substituted for physical-device evidence.
- Repeated retries intended to erase a deterministic failure.
- Before/after claims across invalid raw traces, different OS versions, or different capture cohorts.
- Changes to concurrency, isolation, persistence, notification, provider, or upload behavior.

If new validation infrastructure becomes necessary, close the scenario with a precise blocker and propose a separate,
explicitly approved tooling issue. Do not absorb it into the scenario.

## Boundaries to preserve

- `HomeRefreshPipeline` owns visible Today publication and emits `Today Visible Commit`.
- `SummaryView` renders coherent state and emits `Today Summary Render`.
- `HomeProjectionStore` owns durable projections and projection-save signposts.
- `HomeIngestionCoordinator` and the executor retain run ownership, supersession, and staged publication.
- `TodayTabView` retains the narrow `summary-scroll` header observation boundary.
- `BackgroundOrchestrator` retains `Background Run` and `Unified Background Ingestion`.
- `LocationSnapshotPusher` retains quota-one, five-second bounded draining and durable remainder.

## Sequential execution

| Order | Work item | Preferred implementer | Stop condition |
| ---: | --- | --- | --- |
| 01 | [#347](https://github.com/justinrooks/project-arcus/issues/347) — Establish a privacy-safe physical-device evidence lane | `GPT-5.6 Terra / medium` | SwiftUI, hitch, and signpost data analyze without collecting app logs. |
| 02 | [#348](https://github.com/justinrooks/project-arcus/issues/348) — Lock scenario preparation and evidence classification | `GPT-5.6 Terra / medium` | Every scenario has an approved preparation class, destructive gate, and stop condition. |
| 03 | [#349](https://github.com/justinrooks/project-arcus/issues/349) — Capture cold launch with no usable Today cache | `GPT-5.6 Terra / medium` | Valid trace and video exist, or the location/onboarding control blocker is exact. |
| 04 | [#350](https://github.com/justinrooks/project-arcus/issues/350) — Capture warm cached launch and foreground activation | `GPT-5.6 Terra / medium` | Cache retention, commit/render timing, and rendered stability are recorded. |
| 05 | [#351](https://github.com/justinrooks/project-arcus/issues/351) — Capture pull-to-refresh with useful cached content | `GPT-5.6 Terra / medium` | Core publication, enrichment, trace metrics, and rendered stability are recorded. |
| 06 | [#352](https://github.com/justinrooks/project-arcus/issues/352) — Capture Local Alerts populated to authoritative empty | `GPT-5.6 Terra / medium` | Genuine transition evidence exists, or the missing safe control is exact. |
| 07 | [#353](https://github.com/justinrooks/project-arcus/issues/353) — Capture Storm Setup loading to success | `GPT-5.6 Terra / medium` | Stable-slot success evidence exists, or the preparation blocker is exact. |
| 08 | [#354](https://github.com/justinrooks/project-arcus/issues/354) — Capture Storm Setup loading to terminal failure | `GPT-5.6 Terra / medium` | Terminal-failure evidence exists, or the missing safe failure control is exact. |
| 09 | [#355](https://github.com/justinrooks/project-arcus/issues/355) — Capture partial core-provider failure with useful cache | `GPT-5.6 Terra / medium` | Degraded cached behavior is recorded, or the provider-control blocker is exact. |
| 10 | [#356](https://github.com/justinrooks/project-arcus/issues/356) — Capture rapid background and foreground lifecycle changes | `GPT-5.6 Terra / medium` | Supersession signposts, trace metrics, and rendered result are recorded. |
| 11 | [#357](https://github.com/justinrooks/project-arcus/issues/357) — Capture scroll reversal and partial header condense | `GPT-5.6 Terra / medium` | Header behavior, SwiftUI updates, hitches, and rendered identity are recorded. |
| 12 | [#358](https://github.com/justinrooks/project-arcus/issues/358) — Capture refresh completion while scrolling | `GPT-5.6 Terra / medium` | Completion alignment, scroll stability, trace metrics, and video are recorded. |
| 13 | [#359](https://github.com/justinrooks/project-arcus/issues/359) — Capture Reduce Motion and accessibility Dynamic Type | `GPT-5.6 Terra / medium` | Separate physical-device rendered evidence covers both settings. |
| 14 | [#360](https://github.com/justinrooks/project-arcus/issues/360) — Capture background upload backlog and task-budget behavior | `GPT-5.6 Terra / medium` | One Release SHA's local diagnostic records drain/ingestion phases, terminal state, durable remainder, desired cadence (not an Apple launch claim), and fallback/authoritative scheduler outcomes—or the safe-capture blocker is exact. |
| 15 | [#361](https://github.com/justinrooks/project-arcus/issues/361) — Qualify and close the physical-device evidence matrix | `GPT-5.6 Terra / medium` | Every scenario and artifact passes category, privacy, and comparability review. |

Execute one child at a time. Issues 03-14 do not begin until issues 01 and 02 are complete.

## Verification defaults

- Run the focused deterministic bundle defined by the active issue and inspect its finalized `.xcresult`.
- Do not call the full unit lane green while the known #344 cancellation-race failure remains unresolved.
- Build and install the exact Release app once per capture cohort.
- Validate every trace with `--list-runs`, filtered `--list-signposts`, relevant `--list-logs` only when privacy-safe,
  and full JSON/Markdown analysis.
- Pair `Today Visible Commit` with the first following `Today Summary Render`.
- Record projection saves, SwiftUI/high-severity events, app hitches, hangs, and scenario timing only when exposed.
- Run `git diff --check`, stale-placeholder checks, and source/test/project/CI diff guards after documentation work.

## Quality bar

- One scenario per issue.
- Exact commands, metadata, UTC timestamps, paths, and analyzer results.
- One controlled recapture at most after an invalid or unfinalized trace.
- No private payloads in documentation.
- No claims beyond the evidence category.
- Stop immediately when the issue's acceptance condition or stop condition is reached.
