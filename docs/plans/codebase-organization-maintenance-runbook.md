# Codebase Organization Maintenance Runbook

**Status:** Planned

**Applies to:** Project Arcus / SkyAware iOS app, widgets, and tests

**Project:** `justinrooks/project-arcus`

**Parent epic:** [#289](https://github.com/justinrooks/project-arcus/issues/289)

## Purpose

Reduce oversized, mixed-responsibility Swift files without changing user-visible behavior, runtime contracts, persistence,
or concurrency semantics. Prefer more focused files over fewer catch-all files, while keeping each implementation slice
small enough for direct human review.

## Source Of Truth

Use this order when evidence conflicts:

1. The current GitHub child issue.
2. `AGENTS.md`, the nearest nested `AGENTS.md`, and `tasks/lessons.md`.
3. Existing production behavior and focused tests.
4. This runbook and `docs/plans/codebase-organization-maintenance-progress.md`.
5. Apple SwiftUI and Swift Concurrency guidance referenced by the issue.

## Required Read Order

1. `AGENTS.md`
2. The nearest nested `AGENTS.md`
3. `tasks/lessons.md`
4. The current GitHub issue
5. This runbook
6. `docs/plans/codebase-organization-maintenance-progress.md`
7. Only the production and test files named by the issue

Do not reload the original audit or unrelated feature folders unless repository evidence shows the issue boundary is
wrong. Future prompts should point to these sources rather than reproducing them.

## Minimal Prompt Contract

Ask the implementer to:

- complete only the selected GitHub issue;
- follow the required read order;
- preserve behavior and actor isolation;
- run the issue's focused verification, then a Debug build when production files changed;
- update only that issue's progress-ledger entry;
- stop and report if the diff exceeds the issue boundary or five production files.

## Guardrails

- This is organization maintenance, not an architecture rewrite.
- Preserve public and internal API shapes unless the issue explicitly permits a visibility adjustment required by file
  extraction.
- Preserve SwiftUI identity, state ownership, navigation, accessibility, previews, and rendering behavior.
- Preserve actor ownership, cancellation, retry, ordering, freshness, cache, and persistence semantics.
- Keep pure presentation transformations pure and `Sendable` where already applicable.
- Prefer moving existing declarations intact before considering internal cleanup.
- Do not add protocols, dependency injection, type erasure, or generic abstractions merely to split files.
- One issue normally maps to one PR and one coherent review unit.
- Update the progress ledger before completion.

## Forbidden Scope

- User-visible redesign, copy changes, or new features.
- Swift 6.2 migration, approachable-concurrency settings, or default actor isolation changes.
- Broad directory renames such as `Repos` to `Repositories`.
- Provider, server, transport, database-schema, or notification-contract changes.
- Opportunistic formatting and unrelated warning cleanup.
- Combining later issues because adjacent files are already open.

## Current Boundaries To Preserve

- Summary presentation policy remains separate from providers and persistence.
- `MapFeatureModel` remains main-actor isolated; scene planning remains actor-isolated.
- `HomeIngestionExecutor` remains the ingestion sequencing and freshness owner.
- `LocationSnapshotPusher` remains the queue/retry/coalescing synchronization owner.
- Widget components remain inside the widget target with existing family behavior.
- Storm Setup detail presentation remains deterministic, pure transformation logic.
- Tests remain Swift Testing suites and must not enter the application target.

## Sequential Execution

Issues 01-06 are low-risk reductions that make later production refactors easier to review. Issues 07-13 should run in
order unless the progress ledger records a safe exception.

| Order | Work item | Preferred model | Legacy fallback | Stop condition |
|---:|---|---|---|---|
| 1 | [#290](https://github.com/justinrooks/project-arcus/issues/290) — Extract Summary preview galleries | `GPT-5.6 Luna / medium` | `GPT-5.4 mini / medium` | Preview fixtures live separately; Summary production behavior and build are unchanged. |
| 2 | [#291](https://github.com/justinrooks/project-arcus/issues/291) — Split Home/Summary state test suites | `GPT-5.6 Luna / high` | `GPT-5.4 mini / high` | Each suite has a subject-aligned file and focused tests pass. |
| 3 | [#292](https://github.com/justinrooks/project-arcus/issues/292) — Split location provider and context resolver tests | `GPT-5.6 Luna / high` | `GPT-5.4 mini / high` | Provider and resolver suites are independently navigable and pass. |
| 4 | [#293](https://github.com/justinrooks/project-arcus/issues/293) — Split home refresh pipeline tests and support fakes | `GPT-5.6 Luna / high` | `GPT-5.4 mini / high` | Pipeline suites and reusable fakes have narrow ownership and pass. |
| 5 | [#294](https://github.com/justinrooks/project-arcus/issues/294) — Split map feature model tests and support fakes | `GPT-5.6 Luna / high` | `GPT-5.4 mini / high` | Map behavior suites and fakes are separated without coverage loss. |
| 6 | [#295](https://github.com/justinrooks/project-arcus/issues/295) — Split mixed SPC/repository synchronization tests | `GPT-5.6 Luna / high` | `GPT-5.4 mini / high` | Severe, storm, and SPC sync suites live in subject-aligned files and pass. |
| 7 | [#296](https://github.com/justinrooks/project-arcus/issues/296) — Decompose Primary Awareness presentation files | `GPT-5.6 Terra / high` | `GPT-5.3-Codex / high` | Policy, display models, components, and previews are separated with identical behavior. |
| 8 | [#297](https://github.com/justinrooks/project-arcus/issues/297) — Decompose map model and render planning files | `GPT-5.6 Sol / high` | `GPT-5.3-Codex / xhigh` | Main-actor model, scene state, planner, and pure plan builder have explicit file ownership. |
| 9 | [#298](https://github.com/justinrooks/project-arcus/issues/298) — Extract Storm Setup ingestion responsibilities | `GPT-5.6 Sol / xhigh` | `GPT-5.3-Codex / xhigh` | Executor sequencing is intact and Storm Setup lane logic has a focused owner. |
| 10 | [#299](https://github.com/justinrooks/project-arcus/issues/299) — Separate location upload persistence from queue coordination | `GPT-5.6 Sol / xhigh` | `GPT-5.3-Codex / xhigh` | Queue actor behavior is unchanged and persistence DTO/storage ownership is explicit. |
| 11 | [#300](https://github.com/justinrooks/project-arcus/issues/300) — Split widget rendering components by widget domain | `GPT-5.6 Luna / high` | `GPT-5.4 mini / high` | All widget families compile and render from focused component files. |
| 12 | [#301](https://github.com/justinrooks/project-arcus/issues/301) — Extract Storm Setup detail presentation builders | `GPT-5.6 Terra / high` | `GPT-5.3-Codex / high` | Ingredient, advanced-row, and formatting logic have semantic owners with unchanged output. |
| 13 | [#302](https://github.com/justinrooks/project-arcus/issues/302) — Resolve URL session metrics collector concurrency warning | `GPT-5.6 Sol / high` | `GPT-5.3-Codex / xhigh` | The warning is removed with proven synchronization and no unchecked shortcut without justification. |

## Token-Conscious Execution

- Use the smallest recommended model; escalate only when repository evidence crosses the issue boundary.
- Start from the issue, this runbook, the current ledger entry, and named files. Do not rescan the repository.
- Prefer `rg` and targeted line ranges. Do not reread unchanged files during the same task.
- For file-extraction issues, move declarations intact first. Avoid spending tokens redesigning correct code.
- Run focused tests during iteration and one required build at the end; do not repeatedly run the full suite.
- Record decisions and exact validation once in the progress ledger so later agents do not reconstruct them.
- Stop at the issue's acceptance criteria. Do not begin the next issue in the same task.

## Verification Defaults

- Planning-only changes: verify links, issue bodies, and stale placeholders; do not build.
- Test-only organization: run the moved suites and confirm target membership; a full app build is optional unless project
  membership changed.
- Production file extraction: run focused tests named by the issue, then the repository Debug build.
- Widget extraction: build the app and widget extension; inspect representative previews when available.
- Concurrency work: build with existing complete strict-concurrency settings and run focused networking tests.
- Never use live WeatherKit, NWS, SPC, or Arcus Signal calls in tests.

## Quality Bar

- One responsibility boundary per issue.
- Prefer one to three production files changed; do not exceed five without stopping for review.
- Preserve behavior before improving style.
- Keep diffs reviewable and avoid formatting churn.
- No new warnings.
- Progress entry contains changed files, preserved behavior, exact validation, residual risk, and handoff notes.
