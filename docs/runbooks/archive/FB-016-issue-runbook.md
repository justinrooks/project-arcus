# FB-016 Issue Runbook

**Status:** Active  
**Applies To:** Epic `#143 Epic: FB-016 Location Permission Upgrade Nudge`  
**Project:** SkyAware  
**Related Docs:**
- `AGENTS.md`
- `Sources/AGENTS.md`
- `docs/plans/FB-016-progress.md`
- `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/Efforts/Notes/FB-016 Location Permission Upgrade Nudge.md`

This document defines how to execute one issue at a time for FB-016 location permission reliability nudges.

---

## Purpose

Implement one incremental issue under epic `#143 Epic: FB-016 Location Permission Upgrade Nudge` in a way that aligns with the feature brief and the current SkyAware app architecture.

This runbook exists to keep implementation:
- issue-scoped
- sequential
- testable
- verifiable
- traceable across product intent, GitHub issues, and app source

> Do not treat a single issue as permission to build the full permission nudge feature all at once.  
> Implement the current slice cleanly, leave a durable handoff, and move to the next issue only after verification.

---

## Source of Truth

Treat these inputs with the following authority:

1. The relevant repo `AGENTS.md` and `Sources/AGENTS.md`  
   Repo-wide and app-layer standing rules.

2. `docs/plans/FB-016-issue-runbook.md`  
   The execution contract for how FB-016 issues should be worked.

3. `FB-016 Location Permission Upgrade Nudge.md`  
   The product and behavior source of truth for location reliability nudges.

4. `docs/plans/FB-016-progress.md`  
   The durable implementation ledger and issue-to-issue handoff record.

5. The current GitHub issue under epic `#143 Epic: FB-016 Location Permission Upgrade Nudge`  
   The implementation slice for the current run.

---

## Required Read Order

Read in this order before doing any implementation work:

1. `AGENTS.md`
2. `Sources/AGENTS.md`
3. `docs/plans/FB-016-issue-runbook.md`
4. The relevant sections of the feature brief: `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/Efforts/Notes/FB-016 Location Permission Upgrade Nudge.md`
5. `docs/plans/FB-016-progress.md`
6. The current GitHub issue under epic `#143 Epic: FB-016 Location Permission Upgrade Nudge`
7. The relevant app source, models, views, persistence, tests, and configuration touched by that issue

FB-016 is app-only unless a future issue explicitly says otherwise. Do not inspect or modify other repositories for this feature.

---

## Scope Rules

Implement **only** the current issue's scope.

### Required

- Stay aligned with `FB-016 Location Permission Upgrade Nudge.md`.
- Treat the current GitHub issue as the implementation slice for this run.
- Keep changes incremental and reviewable.
- Leave the codebase in a clean state for the next issue.
- Update `docs/plans/FB-016-progress.md` before finishing.
- Preserve existing onboarding completion, location monitoring, background refresh, alert display, and notification behavior unless the current issue explicitly changes it.
- Keep Summary rail behavior restrained by the FB-016 eligibility and ask-budget rules.
- Keep user-facing copy centered on reliable background severe-weather alerts, not technical permission mechanics.
- Use GPT-5.3-Codex for implementation unless a later issue explicitly becomes visual design exploration.
- Evaluate whether `swift-concurrency-expert` applies before implementation and before final verification.
- Evaluate whether `build-ios-apps:swiftui-ui-patterns` applies before implementation and before final verification.

### Forbidden

- Do not jump ahead and implement future issues early.
- Do not distribute multiple issues across agents in parallel.
- Do not refactor unrelated app areas unless a small local change is strictly required to complete the current issue cleanly.
- Do not build a generic permissions framework.
- Do not make `SummaryView` reach directly into `LocationSession`, `CLLocationManager`, or `UserDefaults`.
- Do not trigger Summary rail prompts for Reduced Accuracy alone in v1.
- Do not count onboarding Always education against the post-onboarding ask budget.
- Do not block onboarding or app usage if the user declines Always or Precise location.
- Do not add server API changes, APNs behavior changes, or alert targeting changes.
- Do not use a model above GPT-5.3-Codex by default.

If a future-facing seam is required, keep it:
- minimal
- local
- easy to extend later

Document the deferred remainder clearly in `docs/plans/FB-016-progress.md`.

---

## Working Style

Prefer:
- simple solutions
- readable code
- narrow app-layer seams
- deterministic eligibility helpers
- testable ask-ledger behavior
- `UserDefaults.shared` for lightweight per-install preference state
- existing `LocationManager` / `LocationSession` permission boundaries
- value-driven Summary inputs from `HomeView`
- existing SkyAware card, rail, sheet, and onboarding visual patterns

Avoid:
- broad permission abstraction frameworks
- UI-driven Core Location plumbing
- repeated native prompts without user context
- hidden ask-count loopholes
- brittle UI tests around real system permission prompts
- broad Settings or onboarding redesigns
- technical user-visible copy such as "authorization state" or "Core Location"

The Summary rail should be a situational reliability cue, not a nag banner.

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
- mapping existing permission, onboarding, Settings, Summary, or test patterns
- reviewing nearby SwiftUI layout conventions
- checking existing deterministic test patterns
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
- `FB-016 Location Permission Upgrade Nudge.md`
- `docs/plans/FB-016-progress.md`
- the current GitHub issue
- the existing app code paths, models, views, persistence, tests, and configuration touched by that issue

### 2. Identify what matters now

Identify:
- which parts of the feature brief are relevant to the current issue
- which parts of the current issue are already partially implemented, if any
- what existing seams, models, views, environment dependencies, preferences, tests, or permission paths are most relevant
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
- `@Observable` state shared with SwiftUI
- `Sendable` models crossing concurrency boundaries
- Core Location callbacks or authorization state propagation
- SwiftData repositories or `@ModelActor`

Use `build-ios-apps:swiftui-ui-patterns` when the issue touches:
- SwiftUI views
- onboarding pages
- Settings sections
- sheets
- Summary rail UI
- `@State`, `@Binding`, `@Environment`, `@AppStorage`, or `@Observable`
- view extraction or layout changes
- user-facing controls such as `Enable Always` or `Not Now`

For each applicable skill:
- read the skill before implementation
- use it to evaluate the issue-scoped plan
- apply only guidance relevant to the current issue
- record any important skill-driven decisions in `docs/plans/FB-016-progress.md`

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

- `LocationManager` remains the Core Location wrapper.
- `LocationSession` remains the app-facing location state boundary.
- Settings, Summary, and onboarding should consume a small UI-friendly reliability model rather than raw Core Location mechanics.
- Summary rail state should be computed above `SummaryView` and passed down as value state plus callbacks.
- Ask counting and suppression are local per-install preference state.
- Reduced Accuracy is Settings-only in v1.
- The onboarding Always branch is part of v1 and does not count toward the post-onboarding ask budget.

### Summary rail eligibility

The Summary rail appears only when all of these are true:

- location authorization is currently While Using
- qualifying risk is present:
  - storm risk is Marginal, Slight, Enhanced, Moderate, or High
  - or severe risk is Hail or Tornado
- the lifetime-per-install post-onboarding ask cap has not been exhausted
- the current qualifying day is not suppressed
- at least 24 hours have elapsed since the last counted rail impression

### Ask-budget constraints

- A Summary rail impression counts as an ask when shown.
- Tapping is not required to spend the ask.
- `Not Now` does not refund the ask.
- The ask cap is three total post-onboarding asks, lifetime-per-install.
- Permission upgrade/downgrade churn does not reset the ask budget.
- The next ask requires a later qualifying day and a minimum 24-hour gap.

### UX constraints

- The Summary rail is not a modal blocker.
- The explanation sheet should be lightweight and app-styled.
- User-visible copy should talk about more reliable background severe-weather alerts.
- The app must remain usable with While Using, reduced accuracy, denied, restricted, or not-determined location states.
- Prompt copy must not imply guaranteed warning delivery or perfect safety.

### Verification constraints

- Each issue must leave behind a reliable way to prove progress against both the feature brief and the GitHub issue.
- Prefer deterministic tests for eligibility, state mapping, ask counting, and suppression.
- Use UI tests only when they prove user-visible navigation or first-run flow behavior more directly than unit tests.
- Do not depend on live system permission prompts in tests when deterministic seams can prove the behavior.

### Quality constraints

- Prefer simple, readable, maintainable code over cleverness.
- Keep concurrency, Core Location, SwiftUI observation, and preference behavior explicit and easy to reason about.
- Keep changes reviewable and scoped.

---

## Testing Expectations

Add meaningful tests for the current issue and keep them scoped to the slice being implemented.

Tests should prove the behavior introduced or changed by the current issue, not attempt to cover the full feature prematurely.

Add or update tests for whichever of these apply to the issue:

- reliability state mapping
- accuracy authorization mapping
- native Always request gating
- Settings copy/action state
- Summary rail eligibility
- `.slight` risk eligibility
- severe hail/tornado eligibility
- Reduced Accuracy non-eligibility for Summary rail
- ask count persistence
- same-day suppression
- next qualifying day behavior
- lifetime-per-install cap exhaustion
- onboarding While Using branch behavior
- explanation sheet action handling

Prefer focused unit tests and targeted UI smoke tests over broad, brittle end-to-end tests.

If the current issue introduces a seam that later issues will depend on, stabilize that seam with tests now rather than leaving it implicit.

Tests must pass before the issue is considered complete.

---

## Progress Verification Expectations

Each issue must leave behind a clear way to verify progress against both:
- `FB-016 Location Permission Upgrade Nudge.md`
- the current GitHub issue description

Verification may come from:
- deterministic unit tests
- focused UI tests
- previews
- repeatable manual verification steps
- app behavior in simulator
- logs, when relevant

If the issue does not naturally create a user-visible change yet, do not invent unnecessary demo UI. Use the smallest intentional verification path that proves the work is functioning and aligned with the brief.

---

## Progress Log Requirements

At the end of the issue, update `docs/plans/FB-016-progress.md` with:

- what was completed
- which parts of the feature brief were advanced
- which files were changed
- which tests were added or updated
- how to verify the work
- what remains intentionally out of scope
- any handoff notes or cautions for the next issue
- which specialist skills were used or why they were not applicable

Append or update the relevant issue section without removing prior issue history unless a section is clearly obsolete or incorrect.

---

## Definition of Done

The current issue is complete only when all of the following are true:

- the implementation aligns with the current GitHub issue scope
- the implementation advances the relevant parts of `FB-016 Location Permission Upgrade Nudge.md`
- future issues were not implemented early unless a small supporting seam was strictly required
- any such seam is minimal, local, and clearly documented in `docs/plans/FB-016-progress.md`
- the code follows existing project conventions and stays simple, readable, and maintainable
- the implementation does not introduce speculative abstractions or unnecessary architecture
- meaningful tests were added or updated for the current issue
- all affected tests pass
- the issue leaves behind a clear verification path against both the feature brief and the GitHub issue
- `docs/plans/FB-016-progress.md` was updated with an accurate handoff for the next issue
- applicable specialist skills were used to review the plan and final implementation
- if a specialist skill was not applicable, the reason is clear from the issue scope
- the affected project builds successfully
- the change leaves the codebase in a clean state for the next incremental issue

---

## Final Deliverables

In the final response for the current issue, provide:

1. a brief summary of what was implemented
2. which parts of `FB-016 Location Permission Upgrade Nudge.md` were advanced
3. which parts of the current GitHub issue were completed
4. any assumptions, tradeoffs, or intentionally deferred work
5. the key files changed
6. the tests added or updated, and what they prove
7. exact steps to verify the implementation now
8. confirmation that `docs/plans/FB-016-progress.md` was updated
9. any handoff notes or cautions for the next issue
10. which specialist skills were used, what they changed about the implementation, or why they were not applicable

---

## Suggested Launcher Prompt

Use a short launcher prompt rather than pasting this whole runbook every time.

Example:

```text
Read:
1. `AGENTS.md`
2. `Sources/AGENTS.md`
3. `docs/plans/FB-016-issue-runbook.md`

Then execute the current GitHub issue under epic `#143 Epic: FB-016 Location Permission Upgrade Nudge` by following the runbook's required read order, planning steps, testing expectations, progress-log updates, and definition of done.
```
