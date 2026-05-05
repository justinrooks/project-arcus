# FB-017 Issue Runbook

**Status:** Active  
**Applies To:** Epic `#11 [Epic] FB-017 Widgets`  
**Project:** SkyAware  
**Related Docs:**
- `AGENTS.md`
- `Sources/AGENTS.md`
- `docs/plans/FB-017-progress.md`
- `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/Efforts/Notes/FB-017 Widgets.md`
- `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/Efforts/Notes/FB-018 Widget Deep Linking.md`

This document defines how to execute one issue at a time for FB-017 widgets.

---

## Purpose

Implement one incremental issue under epic `#11 [Epic] FB-017 Widgets` in a way that aligns with the feature brief, Apple's WidgetKit constraints, and the current SkyAware app architecture.

This runbook exists to keep implementation:
- issue-scoped
- sequential
- testable
- verifiable
- traceable across product intent, GitHub issues, and app source

> Do not treat a single issue as permission to build the full widget feature all at once.  
> Implement the current slice cleanly, leave a durable handoff, and move to the next issue only after verification.

---

## Source of Truth

Treat these inputs with the following authority:

1. The relevant repo `AGENTS.md` and `Sources/AGENTS.md`  
   Repo-wide and app-layer standing rules.

2. `docs/plans/FB-017-issue-runbook.md`  
   The execution contract for how FB-017 issues should be worked.

3. `FB-017 Widgets.md`  
   The product, behavior, design, refresh, and privacy source of truth for widgets.

4. `docs/plans/FB-017-progress.md`  
   The durable implementation ledger and issue-to-issue handoff record.

5. The current GitHub issue under epic `#11 [Epic] FB-017 Widgets`  
   The implementation slice for the current run.

6. `FB-018 Widget Deep Linking.md`  
   Follow-up reference only. Deep linking is out of scope for FB-017.

---

## Required Read Order

Read in this order before doing any implementation work:

1. `AGENTS.md`
2. `Sources/AGENTS.md`
3. `docs/plans/FB-017-issue-runbook.md`
4. The relevant sections of the feature brief: `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/Efforts/Notes/FB-017 Widgets.md`
5. `docs/plans/FB-017-progress.md`
6. The current GitHub issue under epic `#11 [Epic] FB-017 Widgets`
7. The relevant app source, models, views, persistence, tests, target configuration, and entitlement files touched by that issue

FB-017 is app-only unless a future issue explicitly says otherwise. Do not inspect or modify server repositories for this feature.

---

## Scope Rules

Implement **only** the current issue's scope.

### Required

- Stay aligned with `FB-017 Widgets.md`.
- Treat the current GitHub issue as the implementation slice for this run.
- Keep changes incremental and reviewable.
- Leave the codebase in a clean state for the next issue.
- Update `docs/plans/FB-017-progress.md` before finishing.
- Keep v1 to three widgets:
  - small Storm Risk
  - small Severe Risk
  - large Combined
- Keep Storm Risk and Severe Risk semantics aligned with the existing in-app badges.
- Keep the Combined widget alert row aligned with one line of the in-app active local alerts view.
- Show only the highest-priority active alert in Combined, using the v1 priority order:
  1. tornado
  2. severe thunderstorm
  3. flooding
  4. mesoscale discussion
  5. watch
- Show a compact hidden-alert count such as `+N more` when lower-priority active alerts are hidden.
- Treat snapshots older than 30 minutes as stale and visibly mark them stale.
- Use `Updated 2:14 PM`-style freshness copy.
- Use `Open SkyAware to update local risk.` for unavailable current readouts.
- Keep every widget tap routed to Summary in FB-017.
- Use app-owned derived snapshots in an App Group container.
- Keep the widget extension passive: it reads snapshots and provides timelines.
- Write widget snapshots from app-owned risk and alert state after ingestion/projection updates.
- Wire the APNs-driven alert path so alert updates write widget snapshots and request targeted WidgetKit reloads.
- Store derived display state only in widget snapshots.
- Use GPT-5.3-Codex with medium reasoning for implementation sub-issues unless the current issue explicitly justifies a different model.
- Evaluate whether `swift-concurrency-expert` applies before implementation and before final verification.
- Evaluate whether `build-ios-apps:swiftui-ui-patterns` applies before implementation and before final verification.

### Forbidden

- Do not jump ahead and implement future issues early.
- Do not distribute multiple issues across agents in parallel.
- Do not refactor unrelated app areas unless a small local change is strictly required to complete the current issue cleanly.
- Do not implement more than the three v1 widgets.
- Do not add Lock Screen widgets, StandBy widgets, Live Activities, complications, interactive controls, or extra-large iPad widgets.
- Do not implement FB-018 deep linking in FB-017.
- Do not route widgets to per-alert, badge-specific, or configuration-specific destinations in FB-017.
- Do not make the widget extension initiate ingestion, location workflows, notification registration, or network fetches.
- Do not make the widget extension read raw SwiftData alert records directly unless the app-owned snapshot path proves impossible.
- Do not store raw user location, APNs tokens, or unnecessary full alert payload bodies in widget snapshots.
- Do not add a server endpoint solely for widgets unless existing shared app state cannot satisfy WidgetKit constraints.
- Do not imply real-time warning delivery or live radar-like freshness.

If a future-facing seam is required, keep it:
- minimal
- local
- easy to extend later

Document the deferred remainder clearly in `docs/plans/FB-017-progress.md`.

---

## Working Style

Prefer:
- simple solutions
- readable code
- narrow app-layer seams
- WidgetKit-native timelines
- targeted `WidgetCenter` reloads
- deterministic snapshot generation
- Codable value snapshots
- App Group storage owned by the main app
- existing risk, badge, and alert projection models
- realistic widget preview fixtures
- layouts that survive light, dark, tinted, clear, and accessibility text settings

Avoid:
- widget-only risk interpretations
- broad target/project rewrites
- raw SwiftData access from the extension
- background refresh duplication
- network reads from widgets
- storing private or oversized alert payloads in snapshots
- miniature-dashboard designs inside small widgets
- alert text density that makes the large widget noisy

The widget extension should be a presentation surface for app-owned state, not another ingestion pipeline wearing a tiny hat.

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
- mapping existing projection, ingestion, APNs, routing, or badge rendering behavior
- reviewing Xcode project target and entitlement patterns
- checking existing SwiftUI/WidgetKit preview conventions
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
- `FB-017 Widgets.md`
- `docs/plans/FB-017-progress.md`
- the current GitHub issue
- the existing app code paths, models, views, persistence, target configuration, entitlements, tests, and WidgetKit-adjacent code touched by that issue

### 2. Identify what matters now

Identify:
- which parts of the feature brief are relevant to the current issue
- which parts of the current issue are already partially implemented, if any
- what existing seams, models, projections, views, ingestion paths, APNs handlers, tests, or configuration files are most relevant
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
- `Sendable` or `Codable` models crossing concurrency boundaries
- SwiftData repositories or `@ModelActor`
- APNs/background ingestion paths
- WidgetKit timeline providers that cross async boundaries

Use `build-ios-apps:swiftui-ui-patterns` when the issue touches:
- SwiftUI views
- WidgetKit SwiftUI views
- previews
- layout, typography, color, iconography, or visual states
- `@State`, `@Binding`, `@Environment`, `@AppStorage`, or `@Observable`
- view extraction or reusable rendering components

For each applicable skill:
- read the skill before implementation
- use it to evaluate the issue-scoped plan
- apply only guidance relevant to the current issue
- record any important skill-driven decisions in `docs/plans/FB-017-progress.md`

Do not use either skill as permission to broaden scope.

### 5. Implement

Implement in small, reviewable steps.

Prefer extending existing patterns over inventing new ones.

### 6. Ask questions only when necessary

Stop to ask questions only if a missing decision would materially affect:
- the current issue's scope
- a durable model or persistence shape
- target configuration or entitlement strategy
- a public or cross-cutting API contract
- a user-visible behavior that would be costly to reverse later

### 7. Verify

Run the smallest meaningful verification for the issue:
- focused unit tests for models, stores, builders, priority rules, stale handling, and APNs snapshot refresh paths
- focused build/test coverage for WidgetKit target configuration
- preview/snapshot/manual checks for widget layout issues when UI changes are involved
- app build checks when project, entitlement, target, routing, or shared-source changes are involved

Do not claim tests passed unless they were actually run.

### 8. Update progress

Before finishing the issue:
- update `docs/plans/FB-017-progress.md`
- record files changed
- record tests run and results
- record deferred scope
- record handoff notes for the next issue

---

## Implementation Sequence

Work these issues in order unless the epic owner explicitly changes the order:

1. `#153 FB-017: Add widget target and App Group plumbing`
2. `#154 FB-017: Add derived widget snapshot model`
3. `#155 FB-017: Add app-group widget snapshot store`
4. `#156 FB-017: Add widget snapshot builder and alert priority`
5. `#157 FB-017: Integrate widget snapshot writes into ingestion`
6. `#158 FB-017: Add latest projection fallback for widgets`
7. `#159 FB-017: Wire APNs-driven widget snapshot refresh`
8. `#160 FB-017: Add shared widget rendering components and previews`
9. `#161 FB-017: Implement small Storm Risk widget`
10. `#162 FB-017: Implement small Severe Risk widget`
11. `#163 FB-017: Implement large Combined widget`
12. `#164 FB-017: Wire Summary tap routing for widgets`
13. `#165 FB-017: Add widget state and refresh validation`

---

## Expected End State

FB-017 is done when:
- SkyAware exposes the agreed v1 WidgetKit set.
- Widget data comes from app-owned derived snapshots.
- The Storm Risk and Severe Risk widgets match in-app badge semantics.
- The large Combined widget shows both risks and one prioritized active alert row.
- Stale and unavailable states are honest and legible.
- Widget taps open Summary.
- APNs-driven alert updates refresh the widget snapshot and request targeted timeline reloads.
- The implementation includes focused validation and progress log handoff notes.
