# Ingestion Execution Policy Runbook

**Status:** Planned
**Applies to:** Foreground/background execution class, location-context networking, and context reuse latency
**Project:** `SkyAware.xcodeproj`
**Parent epic:** [#421](https://github.com/justinrooks/project-arcus/issues/421)

## Purpose

Make execution priority explicit and remove avoidable location/NWS latency without weakening background budgets, privacy, or hot-alert priority.

## Required Read Order

1. Active child issue.
2. This runbook.
3. `docs/plans/ingestion-execution-policy-progress.md`.
4. `AGENTS.md`, `Sources/AGENTS.md`, and named focused tests.

## Minimal Implementation Prompt

> Implement only the active execution-policy slice using `GPT-5.6 Terra` with medium reasoning. Preserve coordinator ownership and location privacy rules. Update the progress ledger with exact evidence and stop at the issue boundary.

## Target Contract

- Trigger provenance is diagnostic; execution class and deadline ownership are explicit.
- Foreground ownership wins latency policy in mixed pending work.
- Background budget survives only when every retained owner is background.
- One campaign applies its execution policy to context resolution and provider work.
- Scene-active follow-up reuses the prime context instead of repeating GPS/NWS resolution.

## Guardrails

- Do not replace `HomeIngestionCoordinator` or collapse prime/follow-up without Release/device evidence.
- Preserve request joining, cancellation, deferred location movement, upload timestamps, authorization rules, and background deadlines.
- Use structured concurrency only; no detached work.
- Durable foreground-context reuse requires a pure documented policy before implementation.

## Forbidden Scope

- Feed-state persistence, provider outcome redesign, UI transition work, map invalidation, cadence changes, or location-upload policy changes.

## Execution Sequence

| Order | Work item | Preferred model |
|---:|---|---|
| 1 | [#438](https://github.com/justinrooks/project-arcus/issues/438) — Add explicit ingestion execution class | `GPT-5.6 Terra / medium` |
| 2 | [#436](https://github.com/justinrooks/project-arcus/issues/436) — Scope HTTP policy across location resolution | `GPT-5.6 Terra / medium` |
| 3 | [#439](https://github.com/justinrooks/project-arcus/issues/439) — Reuse prime context for scene-active follow-up | `GPT-5.6 Terra / medium` |
| 4 | [#437](https://github.com/justinrooks/project-arcus/issues/437) — Parallelize independent NWS zone-label requests | `GPT-5.6 Terra / medium` |
| 5 | [#440](https://github.com/justinrooks/project-arcus/issues/440) — Define the foreground durable-context policy | `GPT-5.6 Terra / medium` |

## Verification Defaults

- Run coordinator, executor, pipeline, location resolver, and NWS repository suites named by the issue.
- Inspect finalized non-zero `.xcresult` bundles.
- Run a Debug build after production changes and `git diff --check`.
- Make latency claims only from signposts or Release/device evidence.

## Terra / Medium Quality Bar

One policy or latency behavior per issue. Stop if an issue requires more than five production files, changes upload semantics, or broadens location authorization behavior.

