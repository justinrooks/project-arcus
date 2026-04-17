# FB-010 Issue Runbook

**Status:** Active  
**Applies To:** Epic `#108 [Epic] Fix App Data Ingestion`  
**Project:** SkyAware  
**Related Docs:**
- `AGENTS.md`
- `docs/architecture/FB-010 Streamline SkyAware Data Ingestion.md`
- `docs/plans/FB-010-progress.md`

This document defines how to execute one issue at a time for the FB-010 ingestion redesign.

---

## Purpose

Implement one incremental issue under epic `#108 [Epic] Fix App Data Ingestion` in a way that aligns with the architecture and constraints defined in `FB-010 Streamline SkyAware Data Ingestion.md`.

This runbook exists to keep implementation:
- issue-scoped
- sequential
- testable
- verifiable
- traceable across issues

> Do not treat a single issue as permission to build the full ingestion redesign all at once.  
> Implement the current slice cleanly, leave a durable handoff, and move to the next issue only after verification.

---

## Source of Truth

Treat these inputs with the following authority:

1. `AGENTS.md`  
   Repo-wide standing rules and conventions.

2. `docs/plans/FB-010-issue-runbook.md`  
   The execution contract for how FB-010 issues should be worked.

3. `FB-010 Streamline SkyAware Data Ingestion.md`  
   The architectural source of truth for the ingestion redesign.

4. `docs/plans/FB-010-progress.md`  
   The durable implementation ledger and issue-to-issue handoff record.

5. The current GitHub issue under epic `#108 [Epic] Fix App Data Ingestion`  
   The implementation slice for the current run.

---

## Required Read Order

Read in this order before doing any implementation work:

1. `AGENTS.md`
2. `docs/plans/FB-010-issue-runbook.md`
3. `FB-010 Streamline SkyAware Data Ingestion.md`
4. `docs/plans/FB-010-progress.md`
5. the current GitHub issue under epic `#108 [Epic] Fix App Data Ingestion`
6. the relevant code paths, models, views, persistence, tests, and supporting documentation touched by that issue

---

## Scope Rules

Implement **only** the current issue’s scope.

### Required

- Stay aligned with `FB-010 Streamline SkyAware Data Ingestion.md`.
- Treat the current GitHub issue as the implementation slice for this run.
- Keep changes incremental and reviewable.
- Leave the codebase in a clean state for the next issue.
- Update `docs/plans/FB-010-progress.md` before finishing.
- Use the Swift Concurrency Expert skill to ensure all code changes are concurrency safe
- use the SwiftUI UI Patterns skill to ensure that all code changes follow swiftui best practices

### Forbidden

- Do not jump ahead and implement future issues early.
- Do not distribute multiple issues across agents in parallel.
- Do not refactor unrelated areas unless a small local change is strictly required to complete the current issue cleanly.
- Do not build the final generalized ingestion architecture unless the current issue explicitly requires it.
- Do not introduce speculative framework-style abstractions.

If a future-facing seam is required, keep it:
- minimal
- local
- easy to extend later

Document the deferred remainder clearly in `docs/plans/FB-010-progress.md`.

---

## Working Style

Prefer:
- simple solutions
- readable code
- narrow seams
- incremental migration
- explicit behavior over cleverness

Avoid:
- god objects
- speculative abstractions
- generic ingestion “platforms”
- unnecessary UI architecture
- broad rewrites done “while here”

Keep UI reads sourced from SwiftData. Do not introduce new direct network reads from UI code.

When the issue touches execution flow, treat `HomeRefreshV2` as the target path.

Do not preserve a long-lived dual-ingestion architecture beyond what is needed for development of the current issue.

---

## Sequential Execution Model

Work **one issue at a time**, sequentially.

Do not attempt to execute multiple issues in parallel under a parent coordinator.

Parallelism is allowed **only inside the current issue** and only for narrow investigation or isolated subtasks.

---

## Delegated Agent Rules

If delegated agents or subtasks are available, use them only when they reduce context sprawl and improve quality for the **current issue**.

### Good delegated tasks

- tracing a specific code path relevant to the current issue
- mapping current models, persistence, or data flow for the current issue
- reviewing existing tests, previews, or verification patterns
- checking nearby UI or diagnostics surfaces relevant to verification
- validating a small proposed seam or refactor against surrounding code

### Do not delegate

- overall architecture
- final issue planning
- final API or model design
- cross-issue sequencing decisions
- final integration decisions

Delegated work should stay scoped and concise.

The primary executor remains responsible for:
- reconciling findings
- resolving conflicts
- producing one coherent implementation for the current issue

---

## Execution Sequence

Before making code changes for the current issue:

### 1. Inspect inputs

Inspect the relevant sections of:
- `FB-010 Streamline SkyAware Data Ingestion.md`
- `docs/plans/FB-010-progress.md`
- the current GitHub issue
- the existing code paths, models, views, persistence, tests, and supporting documentation touched by that issue

### 2. Identify what matters now

Identify:
- which parts of the feature brief are relevant to the current issue
- which parts of the current issue are already partially implemented, if any
- what existing seams, models, coordinators, repos, actors, views, or diagnostics surfaces are most relevant
- what must change now versus what should remain deferred to later issues

### 3. Produce a pre-implementation plan

Before coding, produce:
- a concise findings summary
- an issue-scoped implementation plan
- a short ambiguity/risk list
- any assumptions to be made
- a progress-verification plan explaining how the issue will be checked against both the brief and the issue once implemented

### 4. Evaluate the plan before coding

Evaluate the plan and:
- remove anything that reaches beyond the current issue without strong justification
- remove speculative abstractions or premature architecture
- check for conflicts with the feature brief, prior progress log entries, or existing code conventions
- verify that the plan leaves a clean handoff for the next issue
- simplify the design if it is becoming broader than the issue requires

### 5. Implement

Implement in small, reviewable steps.

Prefer extending existing patterns over inventing new ones.

### 6. Ask questions only when necessary

Stop to ask questions only if a missing decision would materially affect:
- the current issue’s scope
- a durable model or persistence shape
- a public or cross-cutting API contract
- a behavior that would be costly to reverse later

Otherwise proceed with explicit assumptions.

---

## Implementation Constraints

### Architectural direction to preserve

Keep this direction in mind even when only implementing one slice:

- unified trigger entry
- one ingestion coordinator
- one ingestion process
- one cached home projection as the launch source

### Scope constraints

- Do not implement future issues just because the brief describes them.
- Do not replace large portions of the current ingestion path preemptively unless the current issue explicitly requires it.
- Record deferred work clearly in `docs/plans/FB-010-progress.md`.

### Architecture constraints

- Do not build broad framework-style abstractions for triggers, lanes, plan merging, deltas, or diagnostics unless the current issue truly requires them.
- Prefer small concrete types and narrow seams over generic systems.
- Avoid MVVM or heavier UI abstractions unless the current issue clearly benefits from them.

### Migration constraints

- Avoid partial rewrites that leave old and new paths competing without a clear reason.
- Keep transitional code intentional and easy to remove later.

### Verification constraints

- Each issue must leave behind a reliable way to prove progress against both the feature brief and the GitHub issue.
- Prefer real app behavior, existing surfaces, diagnostics, logs, previews, or tests over throwaway demo scaffolding.
- Do not add debug or verification UI unless it is the smallest intentional way to verify the issue and is consistent with the brief.

### Quality constraints

- Prefer simple, readable, maintainable code over cleverness.
- Keep concurrency, persistence, and observation behavior explicit and easy to reason about.
- Keep changes reviewable and scoped.

---

## Testing Expectations

Add meaningful tests for the current issue and keep them scoped to the slice being implemented.

Tests should prove the behavior introduced or changed by the current issue, not attempt to cover the full ingestion redesign prematurely.

Add or update tests for whichever of these apply to the issue:

- ingestion planning or trigger submission behavior
- coordinator or queue behavior
- SwiftData model or persistence behavior
- home projection creation, update, merge, or lookup behavior
- UI loading or projection-driven rendering behavior
- offline/runtime-state behavior
- diagnostics or verification surfaces introduced by the issue
- regression coverage for the path being migrated or replaced

Prefer focused unit tests and targeted integration tests over broad, brittle end-to-end tests.

If the current issue changes:
- concurrency
- persistence
- projection ownership
- trigger/coalescing behavior

then add tests that make those rules explicit.

If the current issue introduces a seam that later issues will depend on, stabilize that seam with tests now rather than leaving it implicit.

When the current issue replaces or redirects an existing path, add regression coverage that makes the intended new path explicit and helps prevent accidental fallback to the old behavior.

Tests must pass before the issue is considered complete.

---

## Progress Verification Expectations

Each issue must leave behind a clear way to verify progress against both:
- `FB-010 Streamline SkyAware Data Ingestion.md`
- the current GitHub issue description

Verification may come from:
- real app behavior
- an existing app surface
- a diagnostics or settings surface
- logs
- previews
- test harnesses
- repeatable manual verification steps

If the issue does not naturally create a user-visible change yet, do not invent unnecessary demo UI. Use the smallest intentional verification path that proves the work is functioning and aligned with the brief.

---

## Progress Log Requirements

At the end of the issue, update `docs/plans/FB-010-progress.md` with:

- what was completed
- which parts of the feature brief were advanced
- which files were changed
- which tests were added or updated
- how to verify the work
- what remains intentionally out of scope
- any handoff notes or cautions for the next issue

Append or update the relevant issue section without removing prior issue history unless a section is clearly obsolete or incorrect.

---

## Definition of Done

The current issue is complete only when all of the following are true:

- the implementation aligns with the current GitHub issue scope
- the implementation advances the relevant parts of `FB-010 Streamline SkyAware Data Ingestion.md`
- future issues were not implemented early unless a small supporting seam was strictly required
- any such seam is minimal, local, and clearly documented in `docs/plans/FB-010-progress.md`
- the code follows existing project conventions and stays simple, readable, and maintainable
- the implementation does not introduce speculative abstractions, framework-style ingestion systems, or unnecessary architecture
- meaningful tests were added or updated for the current issue
- all affected tests pass
- the issue leaves behind a clear verification path against both the feature brief and the GitHub issue
- `docs/plans/FB-010-progress.md` was updated with an accurate handoff for the next issue
- the project builds successfully
- when an old path was redirected, replaced, or partially retired by the issue, the intended new path is explicit in code and protected by tests where appropriate
- the change leaves the codebase in a clean state for the next incremental issue

---

## Final Deliverables

In the final response for the current issue, provide:

1. a brief summary of what was implemented
2. which parts of `FB-010 Streamline SkyAware Data Ingestion.md` were advanced
3. which parts of the current GitHub issue were completed
4. any assumptions, tradeoffs, or intentionally deferred work
5. the key files changed
6. the tests added or updated, and what they prove
7. exact steps to verify the implementation now
8. confirmation that `docs/plans/FB-010-progress.md` was updated
9. any handoff notes or cautions for the next issue

---

## Suggested Launcher Prompt

Use a short launcher prompt rather than pasting this whole runbook every time.

Example:

```text
Read:
1. `AGENTS.md`
2. `docs/plans/FB-010-issue-runbook.md`

Then execute the current GitHub issue under epic `#108 [Epic] Fix App Data Ingestion` by following the runbook’s required read order, planning steps, testing expectations, progress-log updates, and definition of done.
