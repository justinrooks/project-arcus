# Risk Profile Change Notifications Runbook

**Status:** Complete
**Applies to:** SkyAware iOS app
**Project:** `SkyAware.xcodeproj`
**Parent epic:** [#100](https://github.com/justinrooks/project-arcus/issues/100)

## Related Docs

- `AGENTS.md`
- `Sources/AGENTS.md`
- `docs/SkyAware North Star Spec.md`, especially Notifications
- `docs/architecture/timely-notifications-strategy.md`
- `docs/plans/risk-profile-change-notifications-progress.md`

## Purpose

Add best-effort local notifications when an accepted SPC refresh changes the current location's storm, severe, or
fire risk profile. One refresh produces at most one risk-change notification containing every changed risk dimension.

## Source-of-Truth Order

1. The active GitHub child issue for issue-specific scope and acceptance criteria.
2. This runbook for campaign-wide architecture, guardrails, and execution order.
3. The progress ledger for decisions and completed-work evidence.
4. Repository guidance and the North Star notification-copy rules.
5. Current production code and focused tests for behavior not explicitly changed by the issue.

## Required Read Order

Future implementers should read only:

1. `AGENTS.md` and `Sources/AGENTS.md`.
2. The active child issue.
3. This runbook.
4. The matching section in `risk-profile-change-notifications-progress.md`.
5. The likely files and focused tests named by the child issue.

Do not reload the full investigation or unrelated notification/server architecture.

## Minimal Implementation Prompt

> Implement the active child issue under #100. Read the issue, the risk-profile runbook, and progress ledger. Keep the
> change to one reviewable behavior, preserve the guardrails below, run the issue's focused tests plus a Debug build,
> and update the progress ledger with exact files, behavior, validation, and remaining risk. Stop when that issue's
> acceptance criteria are satisfied.

## Target Architecture

1. `HomeSnapshotStore` resolves the complete current storm, severe, and fire profile after SPC synchronization.
2. `HomeProjectionStore.updateSlowProducts` compares the previous and current complete profiles and persists the new
   values in the same actor-isolated operation.
3. The store returns an optional `RiskProfileChange`; first baseline, incomplete baseline, and unchanged profiles
   return no change.
4. `HomeIngestionExecutor` attaches only an accepted, successfully persisted change to `HomeSnapshot`.
5. Background orchestration passes the change to one local notification engine.
6. The engine composes one message for all changed dimensions and suppresses duplicate delivery per projection key.

Notification side effects belong in background orchestration, not ingestion or persistence.

## Risk Change Contract

- `RiskProfile` contains `stormRisk`, `severeRisk`, and `fireRisk`.
- `RiskProfileChange` contains previous/current profiles, changed dimensions, projection key, location summary, and
  deterministic fingerprints.
- Storm and fire changes compare their ordered categorical values.
- Severe changes include both primary hazard changes and probability changes. Normalize probability to whole-percent
  semantics before fingerprinting or presentation so floating-point noise cannot create notifications.
- Severe direction compares hazard priority first, then probability within the same hazard.
- A reversal is meaningful: `A -> B`, `B -> A`, and a later `A -> B` are distinct valid transitions.
- Comparison is scoped to the same `HomeProjection.projectionKey`; an unseen location seeds a baseline without sending.

## Required Guardrails

- Include storm, severe, and fire changes.
- Detect upgrades, downgrades, mixed-direction changes, and probability-only severe changes.
- One accepted ingestion snapshot may schedule at most one risk-change notification.
- Preserve the current slow-product persistence decision: rejected/failed map syncs must not advance the baseline or
  produce a delta.
- Keep local risk notifications independent of Arcus Signal subscriptions and approximate-location sharing.
- Default the user preference to enabled while respecting iOS notification authorization.
- Run from background refresh and significant-location-change handling only.
- Foreground refresh may advance the projection baseline but must not schedule a local notification.
- Keep background work short and cancellation-aware; do not wait in hopes of batching a later refresh.
- Use deterministic tests and existing fakes. Never call live SPC, NWS, WeatherKit, or Arcus Signal services.

## Forbidden Scope

- Server-side SPC ingestion, semantic diffing, or APNs delivery.
- Guaranteed or real-time delivery claims.
- Background cadence changes or adding slow products to `sessionTick`.
- Foreground notification banners.
- Quiet hours, cooldowns, daily caps, delayed cross-run aggregation, or notification history UI.
- Refactoring existing morning, meso, watch, projection, or refresh architecture beyond the active issue.

## Boundaries to Preserve

- `HomeProjectionStore` remains the atomic projection persistence boundary.
- `HomeIngestionExecutor` remains free of notification delivery side effects.
- `BackgroundOrchestrator` remains the central background-refresh coordinator.
- `BackgroundLocationChangeHandler` continues to join concurrent location-change work.
- Existing `NotificationRule` / `Gate` / `Composer` / `Engine` conventions remain recognizable.
- Existing morning, meso, watch, widget, cadence, and background-health behavior remains intact unless the active issue
  explicitly adds the risk-notification result to it.

## Sequential Execution

| Order | Work item | Preferred model | Stop condition |
|---:|---|---|---|
| 1 | [#308](https://github.com/justinrooks/project-arcus/issues/308) — Detect accepted risk profile changes atomically | `5.4 mini medium` | Store returns one deterministic delta while persisting the accepted profile. |
| 2 | [#309](https://github.com/justinrooks/project-arcus/issues/309) — Carry accepted risk changes through home ingestion | `5.4 mini medium` | `HomeSnapshot` carries only successfully persisted deltas. |
| 3 | [#310](https://github.com/justinrooks/project-arcus/issues/310) — Add the batched risk-change notification engine | `5.4 mini medium` | Pure rule, composer, per-projection gate, and engine tests pass. |
| 4 | [#311](https://github.com/justinrooks/project-arcus/issues/311) — Add the risk-change notification preference | `5.4 mini medium` | Default-enabled independent preference is represented in settings and provider state. |
| 5 | [#312](https://github.com/justinrooks/project-arcus/issues/312) — Run risk-change notifications from background refresh paths | `5.4 mini medium` | Both approved background paths send once when enabled and report delivery accurately. |

Execute sequentially. Do not begin the next issue until the current issue is validated and its progress entry is
updated.

## Verification Defaults

- Run the focused Swift Testing suite named by the active issue.
- Run a Debug simulator build after production changes.
- For issue 05, run the focused risk engine, background orchestrator, and location-change notification suites together.
- Inspect any produced `.xcresult` and report actual execution failures.
- Run a targeted `rg` sweep for stale preference keys, notification kinds, and pending planning placeholders at the end.
- Planning-only changes require document/link verification, not an app build.

## Quality Bar for `5.4 Mini Medium`

- One behavior change per issue and no unrelated cleanup.
- Prefer one to three production files; multiple tiny engine files are acceptable when preserving the repository's
  established notification layout.
- Keep production changes near 200 reviewed lines when practical.
- Use stable, explicit fingerprints rather than process-randomized hashing.
- Test baseline seeding, unchanged profiles, upgrades, downgrades, probability-only changes, batching, duplicates, and
  reversions at the layer that owns each behavior.
- Escalate issue 01 to `5.4 mini high` if actor-isolated return semantics become subtle. Consider `5.6 luna medium`
  only if unexpected SwiftData migration or cross-actor redesign becomes necessary; stop and re-plan first.
