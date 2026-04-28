# FB-013 Issue Runbook

**Status:** Active  
**Applies To:** Epic `#131 [Epic] Add active warning geometry to the map`  
**Project:** SkyAware / Arcus Signal  
**Related Docs:**
- `AGENTS.md`
- `docs/plans/FB-013-progress.md`
- `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/+/FB-013 Add Active Warning Geometry.md`
- `/Users/justin/Code/arcus-signal/AGENTS.md`
- `/Users/justin/Code/arcus-signal/docs/architecture.md`
- `/Users/justin/Code/arcus-signal/docs/epics-stories.md`

This document defines how to execute one issue at a time for FB-013 active warning geometry.

---

## Purpose

Implement one incremental issue under epic `#131 [Epic] Add active warning geometry to the map` in a way that aligns with the feature brief and the current app/server architecture.

This runbook exists to keep implementation:
- issue-scoped
- sequential
- testable
- verifiable
- traceable across the app and server repos

> Do not treat a single issue as permission to build the full warning geometry feature all at once.  
> Implement the current slice cleanly, leave a durable handoff, and move to the next issue only after verification.

---

## Source of Truth

Treat these inputs with the following authority:

1. The relevant repo `AGENTS.md`  
   Repo-wide standing rules and conventions.

2. `docs/plans/FB-013-issue-runbook.md`  
   The execution contract for how FB-013 issues should be worked.

3. `FB-013 Add Active Warning Geometry.md`  
   The product and architecture source of truth for active warning geometry.

4. `docs/plans/FB-013-progress.md`  
   The durable implementation ledger and issue-to-issue handoff record.

5. The current GitHub issue under epic `#131 [Epic] Add active warning geometry to the map`  
   The implementation slice for the current run.

6. For the server issue only, Arcus Signal docs:
   - `/Users/justin/Code/arcus-signal/AGENTS.md`
   - `/Users/justin/Code/arcus-signal/docs/architecture.md`
   - `/Users/justin/Code/arcus-signal/docs/epics-stories.md`

---

## Required Read Order

Read in this order before doing any implementation work:

1. The current repo `AGENTS.md`
2. `docs/plans/FB-013-issue-runbook.md`
3. The relevant sections of the feature brief: `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/+/FB-013 Add Active Warning Geometry.md`
4. `docs/plans/FB-013-progress.md`
5. the current GitHub issue under epic `#131 [Epic] Add active warning geometry to the map`
6. the relevant code paths, models, map rendering, persistence, tests, and supporting docs touched by that issue

For `justinrooks/arcus-signal#48`, also read before implementation:

1. `/Users/justin/Code/arcus-signal/AGENTS.md`
2. `/Users/justin/Code/arcus-signal/docs/architecture.md`
3. `/Users/justin/Code/arcus-signal/docs/epics-stories.md`

---

## Scope Rules

Implement **only** the current issue's scope.

### Required

- Stay aligned with `FB-013 Add Active Warning Geometry.md`.
- Treat the current GitHub issue as the implementation slice for this run.
- Keep changes incremental and reviewable.
- Leave the codebase in a clean state for the next issue.
- Update `docs/plans/FB-013-progress.md` before finishing.
- Preserve existing alert notification behavior unless a later issue explicitly changes it.
- Keep warning geometry render-only in v1.
- Evaluate whether `swift-concurrency-expert` applies before implementation and before final verification.
- Evaluate whether `build-ios-apps:swiftui-ui-patterns` applies before implementation and before final verification.

### Forbidden

- Do not jump ahead and implement future issues early.
- Do not distribute multiple issues across agents in parallel.
- Do not refactor unrelated areas unless a small local change is strictly required to complete the current issue cleanly.
- Do not rename the app's `Watch` model just because it now carries warnings.
- Do not introduce tap/select behavior for warning polygons.
- Do not add watch polygon rendering.
- Do not change meso rendering.
- Do not add revision-level geometry persistence unless a future issue explicitly requires it.
- Do not introduce speculative GIS, map-layer, or payload abstraction frameworks.

If a future-facing seam is required, keep it:
- minimal
- local
- easy to extend later

Document the deferred remainder clearly in `docs/plans/FB-013-progress.md`.

---

## Working Style

Prefer:
- simple solutions
- readable code
- narrow seams
- incremental transport and persistence changes
- deterministic map overlay identities
- SwiftData as the local cache source
- explicit lifecycle filtering over clever inference
- smaller file sizes, 600+ line files are hard to follow

Avoid:
- broad alert model renames
- generic GIS systems
- speculative map-layer frameworks
- duplicate app/server payload drift
- UI-driven network reads
- broad rewrites done "while here"

Warning geometry should be a baseline overlay above thematic map layers, not a new mutually exclusive `MapLayer`.

Offline map behavior must come from SwiftData-backed alert state, not URLCache-only behavior.

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
- mapping current payload, persistence, or map overlay flow
- reviewing existing tests and verification patterns
- checking nearby SwiftData or MapKit behavior relevant to the issue
- validating a small proposed seam against surrounding code

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
- `FB-013 Add Active Warning Geometry.md`
- `docs/plans/FB-013-progress.md`
- the current GitHub issue
- the existing code paths, models, map rendering, persistence, tests, and supporting documentation touched by that issue

### 2. Identify what matters now

Identify:
- which parts of the feature brief are relevant to the current issue
- which parts of the current issue are already partially implemented, if any
- what existing seams, models, repositories, map planners, overlays, renderers, tests, or server payload paths are most relevant
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

### 4.5 Skill evaluation gates

Before coding, decide whether the current issue requires either specialist skill.

Use `swift-concurrency-expert` when the issue touches:
- async/await flows
- actors or `@MainActor`
- SwiftData repositories or `@ModelActor`
- `Sendable` or `Codable` models crossing concurrency boundaries
- map/model state loaded asynchronously
- server Swift concurrency, Vapor async handlers, or queue jobs

Use `build-ios-apps:swiftui-ui-patterns` when the issue touches:
- SwiftUI views
- picker or sheet UI
- map screen composition
- `@State`, `@Binding`, `@Environment`, or `@Observable`
- view extraction or layout changes
- user-facing controls such as the warning geometry toggle

For each applicable skill:
- read the skill before implementation
- use it to evaluate the issue-scoped plan
- apply only guidance relevant to the current issue
- record any important skill-driven decisions in `docs/plans/FB-013-progress.md`

Do not use either skill as permission to broaden scope.

### 5. Implement

Implement in small, reviewable steps.

Prefer extending existing patterns over inventing new ones.

### 6. Ask questions only when necessary

Stop to ask questions only if a missing decision would materially affect:
- the current issue's scope
- a durable model or persistence shape
- a public or cross-cutting API contract
- a user-visible behavior that would be costly to reverse later

Otherwise proceed with explicit assumptions.

---

## Implementation Constraints

### Architectural direction to preserve

Keep this direction in mind even when only implementing one slice:

- `DeviceAlertPayload.geometry` is the shared app/server contract.
- Nil geometry means no renderable warning polygon.
- Server serves latest available series geometry from `arcus_geolocation.geometry`.
- App persists geometry in SwiftData.
- Map renders active warnings from SwiftData-backed alert state.
- Warning geometry is a default-on baseline overlay above thematic map layers.
- Warning geometry is render-only in v1.

### Scope constraints

- Do not implement future issues just because the brief describes them.
- Do not replace large portions of the current map or alert paths preemptively unless the current issue explicitly requires it.
- Record deferred work clearly in `docs/plans/FB-013-progress.md`.

### Architecture constraints

- Do not build broad framework-style abstractions for GIS geometry, map layers, overlay planning, or alert payloads unless the current issue truly requires them.
- Prefer small concrete types and narrow seams over generic systems.
- Avoid MVVM or heavier UI abstractions unless the current issue clearly benefits from them.

### Migration constraints

- Keep SwiftData changes optional/defaulted where practical.
- Avoid destructive local model changes.
- Do not rename existing persisted alert models as part of this feature.
- Keep transitional code intentional and easy to remove later.

### Verification constraints

- Each issue must leave behind a reliable way to prove progress against both the feature brief and the GitHub issue.
- Prefer real app behavior, existing surfaces, map rendering, tests, previews, or logs over throwaway demo scaffolding.
- Do not add debug or verification UI unless it is the smallest intentional way to verify the issue and is consistent with the brief.

### Quality constraints

- Prefer simple, readable, maintainable code over cleverness.
- Keep concurrency, persistence, MapKit, and SwiftUI observation behavior explicit and easy to reason about.
- Keep changes reviewable and scoped.

---

## Testing Expectations

Add meaningful tests for the current issue and keep them scoped to the slice being implemented.

Tests should prove the behavior introduced or changed by the current issue, not attempt to cover the full warning geometry feature prematurely.

Add or update tests for whichever of these apply to the issue:

- shared payload decoding and compatibility
- server payload row mapping and endpoint response behavior
- SwiftData model or persistence behavior
- active warning geometry filtering
- map polygon mapping and stable overlay identity
- warning style mapping
- map scene composition and overlay ordering
- picker toggle behavior
- offline SwiftData-backed rendering behavior
- regression coverage for existing alert or map behavior touched by the issue

Prefer focused unit tests and targeted integration tests over broad, brittle end-to-end tests.

If the current issue changes:
- concurrency
- persistence
- payload contracts
- map overlay identity
- map scene composition

then add tests that make those rules explicit.

If the current issue introduces a seam that later issues will depend on, stabilize that seam with tests now rather than leaving it implicit.

Tests must pass before the issue is considered complete.

---

## Progress Verification Expectations

Each issue must leave behind a clear way to verify progress against both:
- `FB-013 Add Active Warning Geometry.md`
- the current GitHub issue description

Verification may come from:
- real app behavior
- map rendering
- an existing app surface
- logs
- previews
- test harnesses
- repeatable manual verification steps
- server response inspection

If the issue does not naturally create a user-visible change yet, do not invent unnecessary demo UI. Use the smallest intentional verification path that proves the work is functioning and aligned with the brief.

---

## Progress Log Requirements

At the end of the issue, update `docs/plans/FB-013-progress.md` with:

- what was completed
- which parts of the feature brief were advanced
- which files were changed
- which tests were added or updated
- how to verify the work
- what remains intentionally out of scope
- any handoff notes or cautions for the next issue

Append or update the relevant issue section without removing prior issue history unless a section is clearly obsolete or incorrect.

For `justinrooks/arcus-signal#48`, update this progress file from the Project Arcus repo even though the implementation lives in `/Users/justin/Code/arcus-signal`.

---

## Definition of Done

The current issue is complete only when all of the following are true:

- the implementation aligns with the current GitHub issue scope
- the implementation advances the relevant parts of `FB-013 Add Active Warning Geometry.md`
- future issues were not implemented early unless a small supporting seam was strictly required
- any such seam is minimal, local, and clearly documented in `docs/plans/FB-013-progress.md`
- the code follows existing project conventions and stays simple, readable, and maintainable
- the implementation does not introduce speculative abstractions, framework-style map systems, or unnecessary architecture
- meaningful tests were added or updated for the current issue
- all affected tests pass
- the issue leaves behind a clear verification path against both the feature brief and the GitHub issue
- `docs/plans/FB-013-progress.md` was updated with an accurate handoff for the next issue
- applicable specialist skills were used to review the plan and final implementation
- if a specialist skill was not applicable, the reason is clear from the issue scope
- the affected project builds successfully
- the change leaves the codebase in a clean state for the next incremental issue

---

## Final Deliverables

In the final response for the current issue, provide:

1. a brief summary of what was implemented
2. which parts of `FB-013 Add Active Warning Geometry.md` were advanced
3. which parts of the current GitHub issue were completed
4. any assumptions, tradeoffs, or intentionally deferred work
5. the key files changed
6. the tests added or updated, and what they prove
7. exact steps to verify the implementation now
8. confirmation that `docs/plans/FB-013-progress.md` was updated
9. any handoff notes or cautions for the next issue
10. which specialist skills were used, what they changed about the implementation, or why they were not applicable

---

## Suggested Launcher Prompt

Use a short launcher prompt rather than pasting this whole runbook every time.

Example:

```text
Read:
1. `AGENTS.md`
2. `docs/plans/FB-013-issue-runbook.md`

Then execute the current GitHub issue under epic `#131 [Epic] Add active warning geometry to the map` by following the runbook's required read order, planning steps, testing expectations, progress-log updates, and definition of done.
```
