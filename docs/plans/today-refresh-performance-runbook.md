# Today Refresh Performance Runbook

**Status:** Planned
**Applies to:** SkyAware iOS Today foreground refresh and Summary rendering
**Project:** `SkyAware.xcodeproj`
**Parent epic:** [#318](https://github.com/justinrooks/project-arcus/issues/318)

## Related Docs

- `AGENTS.md`
- `Sources/AGENTS.md`
- `docs/SkyAware North Star Spec.md`
- `docs/codebase/skyaware-app-summary.md`
- `docs/audits/swiftui-performance-audit.md`
- `docs/plans/today-state-flow-runbook.md`
- `docs/plans/today-state-flow-progress.md`
- `docs/plans/today-refresh-performance-progress.md`
- GitHub epic [#248](https://github.com/justinrooks/project-arcus/issues/248) and completed issues
  [#253](https://github.com/justinrooks/project-arcus/issues/253),
  [#254](https://github.com/justinrooks/project-arcus/issues/254), and
  [#258](https://github.com/justinrooks/project-arcus/issues/258)

## Purpose

Make foreground Today refresh measurably faster and visually stable. Preserve the reliable unified ingestion pipeline
while eliminating partial SwiftData publication, unnecessary serial waits, structural SwiftUI swaps, and scroll-driven
render churn.

## Source-of-Truth Order

1. The active GitHub child issue for issue-specific scope and acceptance criteria.
2. This runbook for campaign-wide architecture, guardrails, and execution order.
3. The progress ledger for investigation evidence, decisions, and completed-work validation.
4. The North Star specification and completed Today state-flow campaign for product behavior.
5. Current production code and focused tests for behavior not explicitly changed by the active issue.

## Required Read Order

Future implementers should read only:

1. `AGENTS.md` and `Sources/AGENTS.md`.
2. The active child issue.
3. This runbook.
4. The matching section in `today-refresh-performance-progress.md`.
5. The likely files and focused tests named by the child issue.

Do not reload the full audit or unrelated server, notification, background, Map, or Outlook architecture.

## Minimal Implementation Prompt

> Implement the active child issue under the Today Refresh Performance epic. Read the issue, runbook, and matching
> progress entry. Keep the change to one reviewable behavior, preserve the guardrails below, run the focused tests and
> required build or profiling validation, then update the progress ledger with exact files, behavior, evidence, and
> residual risk. Stop when this issue's acceptance criteria are satisfied; do not continue to the next issue.

## Target Architecture

1. `HomeRefreshPipeline` remains the main-actor owner of user-visible Today refresh state.
2. `HomeIngestionCoordinator` continues to merge compatible requests and serialize conflicting campaigns.
3. `HomeIngestionExecutor` preserves hot-alert priority while using structured concurrency for independent work.
4. A new projection is not display-ready until a coherent visible snapshot is committed.
5. Core weather, risk, and hot-alert projection changes publish through one actor-isolated save per visible snapshot.
6. Optional enrichment does not determine when core Today content becomes visible.
7. SwiftUI sections retain stable outer identity; content changes occur inside stable layout slots.
8. Continuous scroll geometry invalidates only the smallest necessary header subtree and does not repeatedly animate
   layout across the Summary hierarchy.

## Required Guardrails

- Preserve cache-forward behavior: useful cached content remains visible during refresh and partial failure.
- Preserve alert freshness, authoritative-empty, location-ownership, and equivalent-snapshot suppression semantics.
- Preserve hot-alert priority and request coalescing; do not make all feeds race without resource and ordering policy.
- Use structured concurrency only. Do not introduce `Task.detached`, fire-and-forget enrichment, actor opt-outs, or
  unchecked sendability.
- Keep `HomeProjectionStore` actor-isolated. Do not move `ModelContext` across actor boundaries.
- Preserve accepted/rejected SPC persistence and risk-profile-change notification semantics.
- Avoid a SwiftData schema change for projection readiness unless the active issue proves it necessary and stops for
  explicit re-planning.
- Preserve Reduce Motion, Dynamic Type, alert sheet/navigation behavior, section ordering, and accessibility IDs.
- Use deterministic fakes and synchronization gates in tests. Never use live WeatherKit, NWS, SPC, or Arcus feeds.
- Make performance claims only from Release/device Instruments evidence or explicit signpost timings.
- Update the matching progress ledger section before closing each child issue.

## Forbidden Scope

- Arcus Signal server, API, APNs, notification, or feed-contract changes.
- Background refresh cadence, significant-location-change policy, or widget behavior changes.
- Broad Today visual redesign, new loading theatrics, or global animation-token changes.
- Provider rewrites, repository migrations, or third-party dependencies.
- Map, Outlook, Settings, or Alert Center redesign.
- Opportunistic cleanup outside the active issue.

## Boundaries to Preserve

- `HomeRefreshPipeline` owns visible state publication and lifecycle entry points.
- `HomeIngestionCoordinator` owns request compatibility, joining, and pending work.
- Provider and repository actors own mutable ingestion state and persistence.
- `HomeSnapshotStore` remains the read/assembly boundary for current domain data.
- `HomeProjectionStore` remains the durable Today projection boundary.
- `HomeView` maps raw pipeline/cache state into canonical Today display state.
- `SummaryView` and child cards render that state without redefining refresh business semantics.

## Sequential Execution

| Order | Work item | Preferred model | Stop condition |
|---:|---|---|---|
| 1 | [#319](https://github.com/justinrooks/project-arcus/issues/319) — Establish Today refresh performance baselines | `GPT-5.6 Luna / medium` | Baseline traces and state/save timelines are recorded in the progress ledger. |
| 2 | [#320](https://github.com/justinrooks/project-arcus/issues/320) — Publish coherent Home projections atomically | `GPT-5.6 Terra / medium` | No-cache refresh cannot expose a partial projection; one coherent core save is observed. |
| 3 | [#321](https://github.com/justinrooks/project-arcus/issues/321) — Keep Local Alerts structurally stable across content changes | `GPT-5.6 Luna / medium` | The outer Local Alerts surface retains identity across populated/empty transitions. |
| 4 | [#322](https://github.com/justinrooks/project-arcus/issues/322) — Reserve a stable Storm Setup section slot | `GPT-5.6 Luna / medium` | Loading-to-visible Storm Setup does not insert an unreserved section. |
| 5 | [#323](https://github.com/justinrooks/project-arcus/issues/323) — Parallelize independent ingestion work within priority lanes | `GPT-5.6 Luna / medium` | Independent provider waits overlap without changing results, freshness, or progress semantics. |
| 6 | [#324](https://github.com/justinrooks/project-arcus/issues/324) — Run optional enrichment concurrently | `GPT-5.6 Luna / medium` | Storm Setup and AQI no longer add their latencies serially. |
| 7 | [#325](https://github.com/justinrooks/project-arcus/issues/325) — Publish core Today content before optional enrichment | `GPT-5.6 Terra / medium` | Core content commits first; enrichment follows through an owned, stable staged update. |
| 8 | [#326](https://github.com/justinrooks/project-arcus/issues/326) — Isolate continuous Today header rendering | `GPT-5.6 Luna / medium` | Scroll progress no longer drives broad Summary layout animation or confirmed derivation hotspots. |
| 9 | [#327](https://github.com/justinrooks/project-arcus/issues/327) — Prove end-to-end Today refresh smoothness | `GPT-5.6 Luna / medium` | The scenario matrix, focused tests, build, and before/after device traces are complete. |

Execute sequentially. Do not begin the next issue until the current issue is validated and its ledger entry is updated.

Terra is intentional for issues 02 and 07. Issue 02 crosses SwiftData save/query visibility and Today state semantics.
Issue 07 crosses structured-concurrency ownership, coordinator sequencing, failure behavior, and staged UI publication.
Those tasks materially benefit from the stronger model. No issue requires Sol if these boundaries remain intact. Stop and
re-plan before upgrading to Sol or expanding either issue beyond five production files.

## Verification Defaults

- Use an iPhone 17 or iPhone 17 Pro simulator on iOS 26.5 for deterministic tests and Debug builds.
- Inspect every generated `.xcresult` and report actual test counts and failures.
- Use Release configuration on a physical device for SwiftUI Instruments and Animation Hitches validation.
- Capture cold no-cache launch, warm cached foreground activation, pull-to-refresh, alerts-to-empty, Storm Setup
  loading-to-visible, partial failure, and rapid background/foreground scenarios.
- Record projection save count, time to first useful content, time to coherent core commit, optional-enrichment latency,
  relevant body-update counts, hitch count, and total hitch time when Instruments exposes them.
- Run `git diff --check` after source or test changes.
- Planning-only work requires document/link verification, not an app build.

## Quality Bar for `GPT-5.6 Luna / Medium`

- One observable behavior change per issue; no unrelated cleanup.
- Prefer one to three production files and keep the reviewed diff near 200 lines when practical.
- Write deterministic state-sequence or gate-based concurrency tests; do not assert elapsed wall-clock timing.
- Preserve current public/domain contracts unless the issue explicitly changes a narrow internal contract.
- Treat an existing passing test as evidence only for what it actually renders or observes.
- Stop when the active acceptance criteria are met. Record follow-up findings instead of implementing the next slice.
- If SwiftData migration, coordinator redesign, cross-actor ownership ambiguity, or more than five production files is
  required, stop and re-plan rather than improvising a larger architecture.
