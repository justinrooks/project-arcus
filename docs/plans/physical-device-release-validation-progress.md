# Physical-Device Release Validation Progress

## Overview

This ledger tracks the deferred physical-device Release validation from issue #345 as a separate, ordered campaign.
It records capture cohorts, scenario preparation, trace and rendered artifacts, deterministic gates, blockers,
comparability, and final qualification.

**Epic status:** Planned

**Primary GitHub epic:** [#346](https://github.com/justinrooks/project-arcus/issues/346)

## Global decisions

- This is validation-only work. It does not reopen the Today optimization campaign.
- Issues execute one at a time after the privacy-safe evidence lane and preparation contract are complete.
- USB is the preferred capture transport; the selected transport remains fixed within a cohort.
- The stock SwiftUI template did not expose app signposts in the July 2026 captures.
- A supplemental Logging trace exposed signposts but also captured private location-derived endpoint text. Logging
  traces are forbidden until a privacy-safe signpost-only lane is proven.
- Existing UI-test controls may support explicitly disclosed setup. They do not convert fixture state into genuine
  provider or production-state performance evidence.
- New fixture or provider infrastructure is out of scope for scenario issues.
- Historical iOS 26.5.2 evidence is not directly comparable with current iOS 26.6 evidence.
- The historical warm and pull raw traces remain invalid for direct reanalysis.
- The known #344 cancellation-race failure remains separate and must not be fixed or retried here.

## Current state summary

Issue #345 established a working Release build/install path and captured partial physical-device evidence on Js14Max.
The valid SwiftUI traces expose current hitch and SwiftUI metrics but not app signposts. A separate Logging trace
exposed an 86.771 ms `Today Visible Commit` to first-following `Today Summary Render` interval for one warm activation,
then triggered the privacy stop because its log store contained private location-derived endpoint text. No separate
screen recording exists.

The focused deterministic bundle finalized at 269 passed, one known cancellation-race failure, and zero skipped.
Every remaining scenario is currently blocked, fixture-qualified, or non-comparable rather than complete.

## Issue sequence

| Order | Issue | Status | Dependency |
| ---: | --- | --- | --- |
| 00 | [#346](https://github.com/justinrooks/project-arcus/issues/346) — Epic | Planned | #345 handoff |
| 01 | [#347](https://github.com/justinrooks/project-arcus/issues/347) — Establish a privacy-safe physical-device evidence lane | Planned | None |
| 02 | [#348](https://github.com/justinrooks/project-arcus/issues/348) — Lock scenario preparation and evidence classification | Planned | 01 |
| 03 | [#349](https://github.com/justinrooks/project-arcus/issues/349) — Capture cold launch with no usable Today cache | Planned | 01, 02 |
| 04 | [#350](https://github.com/justinrooks/project-arcus/issues/350) — Capture warm cached launch and foreground activation | Planned | 03 |
| 05 | [#351](https://github.com/justinrooks/project-arcus/issues/351) — Capture pull-to-refresh with useful cached content | Planned | 04 |
| 06 | [#352](https://github.com/justinrooks/project-arcus/issues/352) — Capture Local Alerts populated to authoritative empty | Planned | 05 |
| 07 | [#353](https://github.com/justinrooks/project-arcus/issues/353) — Capture Storm Setup loading to success | Planned | 06 |
| 08 | [#354](https://github.com/justinrooks/project-arcus/issues/354) — Capture Storm Setup loading to terminal failure | Planned | 07 |
| 09 | [#355](https://github.com/justinrooks/project-arcus/issues/355) — Capture partial core-provider failure with useful cache | Planned | 08 |
| 10 | [#356](https://github.com/justinrooks/project-arcus/issues/356) — Capture rapid background and foreground lifecycle changes | Planned | 09 |
| 11 | [#357](https://github.com/justinrooks/project-arcus/issues/357) — Capture scroll reversal and partial header condense | Planned | 10 |
| 12 | [#358](https://github.com/justinrooks/project-arcus/issues/358) — Capture refresh completion while scrolling | Planned | 11 |
| 13 | [#359](https://github.com/justinrooks/project-arcus/issues/359) — Capture Reduce Motion and accessibility Dynamic Type | Planned | 12 |
| 14 | [#360](https://github.com/justinrooks/project-arcus/issues/360) — Capture background upload backlog and task-budget behavior | Planned | 13 |
| 15 | [#361](https://github.com/justinrooks/project-arcus/issues/361) — Qualify and close the physical-device evidence matrix | Planned | 03-14 |

## Existing evidence map

- Historical campaign and #319/#327 evidence: `docs/plans/today-refresh-performance-progress.md`
- Architecture campaign and #345 roll-up: `docs/plans/codebase-simplification-progress.md`
- Trace recorder:
  `/Users/justin/Code/SwiftUI-Agent-Skill/swiftui-expert-skill/scripts/record_trace.py`
- Trace analyzer:
  `/Users/justin/Code/SwiftUI-Agent-Skill/swiftui-expert-skill/scripts/analyze_trace.py`
- Visible publication: `Sources/App/HomeRefreshPipeline.swift`
- Summary render: `Sources/Features/Summary/SummaryView.swift`
- Projection saves: `Sources/Repos/HomeProjectionStore.swift`
- Scroll boundary: `Sources/App/TodayTabView.swift`
- Background timing: `Sources/Features/Background/BackgroundOrchestrator.swift`
- Durable upload draining: `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`

## Capture cohort ledger

No campaign cohort has started. Issue 01 must append the first cohort manifest before scenario preparation.

| Cohort | Source / worktree | Xcode / SDK | Release app / signing | Device / OS / transport | Template | Artifact root |
| --- | --- | --- | --- | --- | --- | --- |
| Pending | Not captured | Not captured | Not captured | Not captured | Not proven | Not created |

## Investigation notes

- Clean uninstall is the only current way to guarantee an empty projection store without mutating persistence.
- Uninstall also removes app-container preferences and may change system authorization state.
- `Clear Network Cache` removes only `URLCache`; it does not clear `HomeProjection`.
- Release has an onboarding-only UI-test override, but evidence using it must disclose the setup and cannot infer
  genuine provider behavior from fixture controls.
- USB makes destructive setup and network-condition changes safer because Instruments does not depend on Wi-Fi.
- `xctrace record` accepts an additional instrument or a template path. Issue 01 must prove a SwiftUI plus
  signpost-only configuration without an app-log store before scenario capture.

## Status ledger

### Issue #347 — 01: Establish a privacy-safe physical-device evidence lane

- **Status:** Planned
- **Goal:** Prove the common device, Release, signpost, SwiftUI, hitch, analysis, recording, and privacy workflow.
- **Required result:** A warm smoke trace exposes the required lanes and payload-free signposts without app logs.
- **Stop condition:** Any capture path includes private log payloads or lacks required physical-device lanes.

### Issue #348 — 02: Lock scenario preparation and evidence classification

- **Status:** Planned
- **Goal:** Approve deterministic preparation recipes and classification rules before device mutation.
- **Required result:** Every scenario has an allowed control class, destructive approval gate, proof boundary, and
  exact stop condition.
- **Stop condition:** A scenario requires production/debug fixture infrastructure or server manipulation.

### Issue #349 — 03: Capture cold launch with no usable Today cache

- **Status:** Planned
- **Goal:** Capture a normal Release cold Today launch from an empty usable projection state.
- **Required result:** Separate valid trace and video, exact empty-state preparation, commit/render timing, projection
  saves, SwiftUI and hitch metrics.
- **Stop condition:** Onboarding, location authorization, background population, or destructive setup cannot be
  controlled honestly.

### Issue #350 — 04: Capture warm cached launch and foreground activation

- **Status:** Planned
- **Goal:** Prove useful cached content remains visible while activation refresh settles.
- **Required result:** Valid trace and video with cache-visible preparation, activation window, commit/render timing,
  projection saves, and responsiveness metrics.
- **Stop condition:** Useful cache or rendered retention cannot be established without private evidence.

### Issue #351 — 05: Capture pull-to-refresh with useful cached content

- **Status:** Planned
- **Goal:** Record manual refresh while useful cache remains visible through core and enrichment publication.
- **Required result:** Valid trace and video with exact gesture, publication window, projection saves, and hitch data.
- **Stop condition:** The intended refresh window cannot be isolated or the trace fails one controlled recapture.

### Issue #352 — 06: Capture Local Alerts populated to authoritative empty

- **Status:** Planned
- **Goal:** Capture a genuine populated-to-confirmed-empty transition without structural replacement.
- **Required result:** Trace, rendered evidence, and deterministic contract evidence remain separately identified.
- **Stop condition:** Live state does not transition and no approved safe control exists.

### Issue #353 — 07: Capture Storm Setup loading to success

- **Status:** Planned
- **Goal:** Record stable Storm Setup slot identity through loading to genuine success.
- **Required result:** Valid trace, video, request/save window, terminal state, and residual limitation.
- **Stop condition:** Only fresh-cache skip or fixture-only success is available.

### Issue #354 — 08: Capture Storm Setup loading to terminal failure

- **Status:** Planned
- **Goal:** Record stable Storm Setup slot identity through loading to terminal failure.
- **Required result:** Valid trace, video, failure window, terminal semantics, and residual limitation.
- **Stop condition:** Failure requires provider, network, or server manipulation outside approved controls.

### Issue #355 — 09: Capture partial core-provider failure with useful cache

- **Status:** Planned
- **Goal:** Record degraded publication while useful same-location cached sections remain visible.
- **Required result:** Valid trace and video correlated with deterministic failure-retention contracts.
- **Stop condition:** A genuine partial failure cannot be induced safely.

### Issue #356 — 10: Capture rapid background and foreground lifecycle changes

- **Status:** Planned
- **Goal:** Record lifecycle churn without stale or superseded publication replacing newer visible state.
- **Required result:** Valid trace, video, lifecycle/signpost sequence, and responsiveness metrics.
- **Stop condition:** The lifecycle sequence or intended run cannot be resolved unambiguously.

### Issue #357 — 11: Capture scroll reversal and partial header condense

- **Status:** Planned
- **Goal:** Measure scroll/reversal updates while validating narrow header invalidation and stable content identity.
- **Required result:** Valid trace and separate video with exact gesture script and hitch/SwiftUI metrics.
- **Stop condition:** The physical SwiftUI lane is missing or video cannot establish the visual assertion.

### Issue #358 — 12: Capture refresh completion while scrolling

- **Status:** Planned
- **Goal:** Align refresh completion with active scrolling and verify position and section identity remain stable.
- **Required result:** Valid trace and video with an unambiguous completion-during-scroll window.
- **Stop condition:** Completion cannot be aligned deterministically without a new control point.

### Issue #359 — 13: Capture Reduce Motion and accessibility Dynamic Type

- **Status:** Planned
- **Goal:** Record representative physical-device rendered behavior under Reduce Motion and accessibility Dynamic Type.
- **Required result:** Separate recordings, exact system settings, layout result, and residual limitations.
- **Stop condition:** Required settings or recording cannot be completed without changing the capture cohort.

### Issue #360 — 14: Capture background upload backlog and task-budget behavior

- **Status:** Planned
- **Goal:** Distinguish bounded drain, ingestion, cancellation, task outcome, and durable remainder.
- **Required result:** Valid trace and deterministic evidence with privacy-safe backlog preparation. On one Release
  SHA, record the local background diagnostic's start/end state, terminal outcome, desired cadence date (not an Apple
  launch claim), fallback/authoritative scheduling outcomes, upload-drain and unified-ingestion durations/outcomes,
  and durable upload remainder.
- **Stop condition:** Reproduction requires unsafe location, upload-queue, preference, token, or server mutation.

### Issue #361 — 15: Qualify and close the physical-device evidence matrix

- **Status:** Planned
- **Goal:** Audit every result and close the campaign without category or comparability errors.
- **Required result:** Final matrix, cohort metadata, artifact inventory, focused test counts, historical limits, and
  residual blockers are durable.
- **Stop condition:** Any completed scenario lacks a finalized trace or required rendered evidence.

## Verification ledger

| Date | Issue | Validation | Result |
| --- | --- | --- | --- |
| 2026-07-26 | #346 | Epic/child link and label inspection; stale-placeholder search; `git diff --check`; source/test/project/CI diff guard | Passed: #346 open with 15 linked unchecked children (#347-#361); no stale GitHub placeholders; documentation-only campaign files |

## Handoff notes

- Begin with issue 01; do not prepare a scenario first.
- Use a cable unless the approved capture cohort deliberately chooses wireless.
- Keep one scenario per trace and one scenario issue active at a time.
- Record a blocker rather than adding a fixture or manipulating a provider.
- Stop after updating this ledger for the active issue.
