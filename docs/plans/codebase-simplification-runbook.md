# Codebase Simplification Runbook

**Status:** Planned

**Applies to:** SkyAware iOS architecture simplification findings F-01 through F-10

**Project:** `SkyAware.xcodeproj`

**Parent epic:** [#329](https://github.com/justinrooks/project-arcus/issues/329)

## Related documents

- `AGENTS.md`
- `Sources/AGENTS.md`
- `docs/audits/codebase-architecture-recovery.md`
- `docs/plans/codebase-simplification-roadmap.md`
- `docs/plans/codebase-simplification-progress.md`
- `docs/SkyAware North Star Spec.md`
- `docs/code_review.md`

## Purpose

Execute the recovered simplification roadmap as small, ordered review units. Remove lossy absence semantics,
unowned cancellation paths, weaker test contracts, silent protocol behavior, obsolete generation artifacts, and
documentation ambiguity without replacing the current G5 architecture.

This runbook converts the twelve roadmap candidates into sixteen smaller issues. Cancellation and background budget
work are split into characterization and implementation. Documentation status, release policy, simulator/CI
validation, and physical-device evidence are separated because they have different owners and proof.

## Authoritative correction

The user clarified that checked-in marketing versions and build numbers are Xcode Cloud placeholders. Do not
investigate or reconcile distribution build-number provenance. The repository-owned invariant is only:

- the app and widget marketing versions match;
- the app and widget build numbers match.

This correction overrides the build-number-provenance concern in F-10 and CS-11. Preserve the contradiction as a
point-in-time audit finding; do not create speculative work from it.

## Source-of-truth order

1. The active GitHub child issue for its exact review unit.
2. This runbook for campaign guardrails, ordering, and the Xcode Cloud correction.
3. `codebase-simplification-roadmap.md` for evidence and acceptance detail.
4. `codebase-simplification-progress.md` for completed validation and handoff state.
5. `codebase-architecture-recovery.md` for finding provenance.
6. Current source and focused tests for behavior not explicitly changed by the active issue.

When these sources conflict, stop and record the contradiction. Do not resolve it by inventing another issue or
broadening the active issue.

## Required read order

Future implementers should read only:

1. `AGENTS.md` and the nearest scoped `AGENTS.md`.
2. The active child issue.
3. This runbook.
4. The matching roadmap section and progress-ledger section.
5. The likely production files and focused tests named by the issue.

Do not repeat the architecture investigation, reload unrelated campaign history, or inspect Arcus Signal/ArcusCore
unless the active issue explicitly says a consumed contract must be verified.

## Minimal implementation prompt

> Implement only the active child issue in the Codebase Simplification epic. Read the issue, runbook, matching
> roadmap section, and progress entry. Add the required characterization first, preserve the locked invariants, run
> the exact focused validation, inspect every generated `.xcresult`, update the progress ledger, and stop. Do not
> continue to the next issue or perform adjacent cleanup.

## Target architecture

The target is the current architecture with fewer ambiguous pathways:

1. Map warning and AQI publication distinguish preserve/unavailable from authoritative empty.
2. Coordinator waiter lifetime is separate from shared ingestion-run lifetime.
3. Background upload draining is bounded and covered by OS cancellation without losing durable queued work.
4. Every core projection conformer preserves production atomicity.
5. Critical coordinator/upload/preference protocols have one explicit semantic contract.
6. Today display selection is one pure value transformation, not a second observable owner.
7. Obsolete Home and unreachable composition paths are removed only after their dependencies are explicit.
8. Architecture, campaign status, Xcode Cloud ownership, validation lanes, and runtime evidence have one durable
   recording location.

## Required guardrails

- Preserve cached-first and resolve-forward Today behavior.
- Preserve useful same-location stale content on partial failure.
- Preserve authoritative-empty alert behavior.
- Preserve location, projection, provider freshness, alert series/revision, SwiftUI, map-plan, and widget identities.
- Preserve foreground/background/remote ingestion convergence and hot-alert priority.
- Preserve atomic production Home core and accepted/rejected SPC persistence.
- Preserve stable Local Alerts and Storm Setup identity.
- Preserve core publication before optional enrichment.
- Preserve Storm Setup expiry, H3, monotonic freshness, and failed-attempt backoff.
- Preserve risk-change coalescing and 20/40/60-minute background cadence.
- Preserve widget freshness, polygon interior rings, privacy-first location handling, and conservative notifications.
- Use structured concurrency. Do not introduce `Task.detached`, unchecked sendability, or cross-actor
  `ModelContext`.
- Use deterministic fakes. Do not call live WeatherKit, NWS, SPC, Arcus, or APNs in tests.
- Update the matching progress section before closing each child.

## Forbidden scope

- A new app-wide architecture, DI framework, repository framework, global event bus, or module extraction.
- Arcus Signal or ArcusCore implementation changes.
- API URL scheme changes; existing issue
  [#245](https://github.com/justinrooks/project-arcus/issues/245) owns that adjacent concern.
- APNs alias, legacy location-source, endpoint, or DTO retirement.
- Provider rewrites, projection schema redesign, Map scene-cache redesign, or notification-policy redesign.
- Home query narrowing or Map scene-warming removal without new runtime evidence.
- Reopening completed organization, Today state-flow/performance, Map, notification, location-hardening, or Storm
  Setup campaigns.
- Marketing/build-number provenance investigation. Monitor app/widget parity only.
- Test-warning cleanup unless a dedicated issue is approved after this campaign.
- Opportunistic formatting, file splitting, or cleanup outside the active issue.

## Boundaries to preserve

- `Dependencies.live()` remains explicit manual composition.
- `LocationSession` remains the UI-facing location lifecycle owner.
- Actor and `@ModelActor` repositories retain mutable-state and persistence ownership.
- `HomeIngestionCoordinator` retains plan compatibility, joining, serialization, and one merged pending plan.
- `HomeIngestionExecutor` retains structured provider-lane and enrichment orchestration.
- `HomeProjectionStore` retains durable Today projection ownership.
- `HomeRefreshPipeline` retains visible submission and staged publication ownership.
- `HomeView` remains the presentation consumer; issue 10 may extract only a pure selector/value.
- SPC accepted/rejected batch semantics and rollback remain unchanged.

## Sequential execution

| Order | Work item | Preferred implementer | Stop condition |
| ---: | --- | --- | --- |
| 01 | [#330](https://github.com/justinrooks/project-arcus/issues/330) — Preserve cached warnings when warning lookup fails | `GPT-5.6 Terra / medium` | Confirmed empty clears while failure/unavailable/cancellation preserves prior warnings. |
| 02 | [#331](https://github.com/justinrooks/project-arcus/issues/331) — Preserve same-location AQI when refresh produces no value | `GPT-5.6 Terra / medium` | Hot-only and failed refreshes preserve same-key AQI; location change still isolates it. |
| 03 | [#332](https://github.com/justinrooks/project-arcus/issues/332) — Characterize ingestion waiter cancellation | `GPT-5.6 Terra / medium` | Deterministic tests lock waiter/run ownership and finish/cancel races without production edits. |
| 04 | [#333](https://github.com/justinrooks/project-arcus/issues/333) — Cancel waiters without canceling shared ingestion runs | `GPT-5.6 Terra / medium` | Canceled waiters resume once and stop callbacks; useful shared runs continue. |
| 05 | [#334](https://github.com/justinrooks/project-arcus/issues/334) — Define bounded pending-upload drain semantics | `GPT-5.6 Terra / medium` | Drainer exposes a bounded outcome and durable remainder under deterministic tests. |
| 06 | [#335](https://github.com/justinrooks/project-arcus/issues/335) — Put background refresh under cancellation and drain budgets | `GPT-5.6 Terra / medium` | OS cancellation covers pre-drain and ingestion retains budget without reordering policy. |
| 07 | [#336](https://github.com/justinrooks/project-arcus/issues/336) — Require atomic Home core commits across conformers | `GPT-5.6 Terra / medium` | No conformer can inherit decomposed partial-save semantics. |
| 08 | [#337](https://github.com/justinrooks/project-arcus/issues/337) — Collapse coordination to one semantic protocol operation | `GPT-5.6 Luna / medium` | No overload default can discard progress or publication. |
| 09 | [#338](https://github.com/justinrooks/project-arcus/issues/338) — Require explicit upload and preference side effects | `GPT-5.6 Luna / medium` | Critical no-ops are named at composition rather than inherited silently. |
| 10 | [#339](https://github.com/justinrooks/project-arcus/issues/339) — Centralize Today display selection in a pure value | `GPT-5.6 Terra / medium` | One pure selector replaces per-slice branches without creating state ownership. |
| 11 | [#340](https://github.com/justinrooks/project-arcus/issues/340) — Remove obsolete Home model and inert pipeline policies | `GPT-5.6 Luna / medium` | Dead symbols/arguments are gone with zero trigger or timing change. |
| 12 | [#341](https://github.com/justinrooks/project-arcus/issues/341) — Make Arcus live composition fail-fast and explicit | `GPT-5.6 Luna / medium` | One URL resolution and one live/no-op policy remain; #245 stays untouched. |
| 13 | [#342](https://github.com/justinrooks/project-arcus/issues/342) — Align architecture and campaign-status documentation | `GPT-5.6 Luna / medium` | Current docs/status headers match G5 and detailed ledgers; historical audits stay historical. |
| 14 | [#343](https://github.com/justinrooks/project-arcus/issues/343) — Document Xcode Cloud release ownership and version parity | `GPT-5.6 Luna / medium` | Build provenance is out of scope; app/widget parity and `Unreleased` policy are explicit. |
| 15 | [#344](https://github.com/justinrooks/project-arcus/issues/344) — Make unit and UI validation lanes explicit | `GPT-5.6 Luna / medium` | Intended unit/UI commands and `.xcresult` inspection are durable and unambiguous. |
| 16 | [#345](https://github.com/justinrooks/project-arcus/issues/345) — Capture remaining physical-device Release evidence | `GPT-5.6 Terra / medium` | The incomplete evidence from #327 is recorded without inventing optimization work. |

Execute sequentially unless a child issue states an independent prerequisite. Stop after each issue and wait for
human review.

## Model guidance

No issue currently requires GPT-5.6 Sol. The two original Sol candidates were split:

- waiter cancellation characterization is separate from its production change;
- upload-drain contract definition is separate from background orchestration integration.

Terra medium is appropriate for contained semantic, SwiftData, actor-lifecycle, and trace-interpretation work. Luna
medium is appropriate for mechanical protocol cleanup, dead-code removal, composition cleanup, documentation, and
validation-lane wiring.

If an issue exposes unresolved shared-run cancellation policy, actor reentrancy across more than the named boundary,
or a multi-lifecycle race that cannot be characterized deterministically, stop and propose Sol with the specific
ambiguity, expected files, and why Terra medium cannot safely complete it. Do not silently upgrade.

## Verification defaults

- Use iPhone 17 or iPhone 17 Pro on iOS 26.5 when available.
- Run only the focused suites in the active issue during iteration.
- Run a Debug build after production changes.
- Run the full `SkyAwareTests` target once for persistence, coordinator, or cross-call-site contract changes.
- Use `SkyAware_All_Tests` only when the active issue affects UI behavior or validates the UI lane.
- Inspect every generated `.xcresult` and record actual counts/failures.
- Run `git diff --check`.
- Use Release configuration and the same physical device for comparable performance evidence.
- Planning/documentation-only issues do not require an app build.

## Quality bar for GPT-5.6 Luna/Terra medium

- One behavior or contract slice per issue.
- Prefer one to three production files and a reviewable diff near 200 changed lines when practical.
- Add characterization before changing semantics.
- Remove a concept, pathway, ambiguity, or false contract; do not add architecture for naming symmetry.
- Keep issue-specific evidence in the issue and progress ledger instead of copying the audit.
- Stop when acceptance criteria are satisfied.
- If more than five production files, a schema migration, cross-repository change, or a second behavior becomes
  necessary, stop and re-plan.
