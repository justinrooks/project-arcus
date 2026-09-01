# Ingestion Cache Acceptance Runbook

**Status:** Planned
**Applies to:** SkyAware provider outcomes, canonical acceptance, Home projection publication, and AQI enrichment
**Project:** `SkyAware.xcodeproj`
**Parent epic:** [#425](https://github.com/justinrooks/project-arcus/issues/425)

## Purpose

Make cache-forward behavior truthful: failed, rejected, partial, or unpersisted candidates never replace the last accepted UI slice or advance freshness.

## Source-of-Truth Order

1. The active child issue.
2. This runbook.
3. `docs/plans/ingestion-cache-acceptance-progress.md`.
4. `AGENTS.md`, `Sources/AGENTS.md`, and current focused tests.

## Minimal Implementation Prompt

> Implement only the active child issue. Read its body, this runbook, and its progress entry. Use `GPT-5.6 Terra` with medium reasoning. Preserve accepted cache during every attempt, run focused deterministic tests, update the progress ledger, and stop when the issue acceptance criteria pass.

## Target Contract

- Attempt, transport response, canonical acceptance, and projection publication are distinct.
- A complete hot projection advances only after location-scoped Arcus and meso acceptance.
- Map and outlook admission and freshness remain independent.
- A projection-backed UI replacement is eligible only after `HomeProjectionStore` acknowledges its save.
- AQI and core data never publish as live-only replacements after persistence failure.

## Guardrails

- Preserve `HomeIngestionCoordinator` ownership, joining, cancellation, pending-run, and deadline behavior.
- Preserve canonical repository actors and `HomeProjectionStore` actor isolation.
- Do not introduce a SwiftData schema change or cross-`ModelActor` transaction.
- Preserve accepted/rejected SPC map-domain semantics and useful canonical data for background evaluation.
- Never use live endpoints in tests.
- Reference completed AQI issue #331 as prerequisite behavior; do not reopen its same-location preservation scope.

## Forbidden Scope

- Durable feed-state sidecar, transport-age policy, foreground execution-class changes, UI redesign, map invalidation, or detail navigation work.
- Broad provider abstraction or coordinator replacement.

## Execution Sequence

| Order | Work item | Preferred model |
|---:|---|---|
| 1 | [#428](https://github.com/justinrooks/project-arcus/issues/428) — Reject malformed SPC text feeds | `GPT-5.6 Terra / medium` |
| 2 | [#429](https://github.com/justinrooks/project-arcus/issues/429) — Add typed Arcus and meso sync outcomes | `GPT-5.6 Terra / medium` |
| 3 | [#430](https://github.com/justinrooks/project-arcus/issues/430) — Require coherent hot-feed acceptance | `GPT-5.6 Terra / medium` |
| 4 | [#433](https://github.com/justinrooks/project-arcus/issues/433) — Add typed outlook outcome and in-flight joining | `GPT-5.6 Terra / medium` |
| 5 | [#434](https://github.com/justinrooks/project-arcus/issues/434) — Separate map and outlook refresh clocks | `GPT-5.6 Terra / medium` |
| 6 | [#427](https://github.com/justinrooks/project-arcus/issues/427) — Make manual outlook refresh honor its outcome | `GPT-5.6 Terra / medium` |
| 7 | [#435](https://github.com/justinrooks/project-arcus/issues/435) — Return explicit projection commit acknowledgement | `GPT-5.6 Terra / medium` |
| 8 | [#432](https://github.com/justinrooks/project-arcus/issues/432) — Gate core UI replacement on projection acknowledgement | `GPT-5.6 Terra / medium` |
| 9 | [#431](https://github.com/justinrooks/project-arcus/issues/431) — Remove AQI live-only publication fallback | `GPT-5.6 Terra / medium` |

## Verification Defaults

- Run the smallest focused Swift Testing suites named by the active issue through `tools/ci/run_test_lane.sh unit`.
- Inspect finalized `.xcresult` evidence and report exact non-zero counts.
- Run the full unit lane once for issues that change shared provider/executor contracts.
- Run a Debug simulator build after production changes and `git diff --check`.

## Terra / Medium Quality Bar

- One behavior per issue, normally one to five production files and near 200 changed lines.
- Prefer explicit `Sendable` outcomes and structured concurrency.
- Stop and re-plan before schema migration, coordinator redesign, or broader persistence ownership changes.

