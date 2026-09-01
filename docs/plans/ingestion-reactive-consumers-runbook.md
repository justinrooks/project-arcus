# Ingestion Reactive Consumers Runbook

**Status:** Planned
**Applies to:** Map invalidation, keyed Home projection observation, projection retention, cached detail reconciliation, and end-to-end evidence
**Project:** `SkyAware.xcodeproj`
**Parent epic:** [#424](https://github.com/justinrooks/project-arcus/issues/424)

## Purpose

Make UI consumers react efficiently to accepted cached generations without adding navigation-time network work or treating metadata as domain data.

## Required Read Order

1. Active child issue.
2. This runbook.
3. `docs/plans/ingestion-reactive-consumers-progress.md`.
4. Completed cache-acceptance and feed-state issue handoffs.

## Minimal Implementation Prompt

> Implement only the active consumer slice using `GPT-5.6 Terra` with medium reasoning. Re-read accepted cache after invalidation, preserve stable view/navigation identity, run deterministic tests, update the ledger, and stop.

## Target Contract

- Feed generations are invalidation hints, never domain payloads.
- Visible map reloads only after relevant accepted generations and preserves its current scene until replacement is ready.
- Home observes the active projection plus one startup fallback rather than all historical projections.
- Projection retention is explicit and separate from query narrowing.
- Alert details render immediately from cached DTOs and may reconcile accepted revisions by stable identity.

## Guardrails

- Preserve map camera, selected layer, canonical repository reads, cache-first detail navigation, and current outlook issuance semantics.
- Do not auto-roll an open outlook detail to a new issuance.
- No visual redesign or global motion work; that belongs to the UI coherence epic.
- Make performance claims only from Release/device evidence.

## Forbidden Scope

- Provider scheduling, transport policy, SwiftData schema migration, navigation-time networking, or broad tab redesign.

## Execution Sequence

| Order | Work item | Preferred model |
|---:|---|---|
| 1 | [#452](https://github.com/justinrooks/project-arcus/issues/452) — Invalidate the visible map from accepted generations | `GPT-5.6 Terra / medium` |
| 2 | [#455](https://github.com/justinrooks/project-arcus/issues/455) — Introduce keyed Home projection observation | `GPT-5.6 Terra / medium` |
| 3 | [#456](https://github.com/justinrooks/project-arcus/issues/456) — Add explicit Home projection retention | `GPT-5.6 Terra / medium` |
| 4 | [#451](https://github.com/justinrooks/project-arcus/issues/451) — Reconcile open alert detail with accepted revisions | `GPT-5.6 Terra / medium` |
| 5 | [#450](https://github.com/justinrooks/project-arcus/issues/450) — Prove end-to-end cache consumer behavior | `GPT-5.6 Terra / medium` |

## Verification Defaults

- Deterministic map, Home state, retention, and detail tests.
- Disk-backed retention tests and finalized non-zero `.xcresult` evidence.
- Final child uses a physical Release device for warm/cold cache, partial failure, merge, map-visible acceptance, and detail navigation.
- Debug build and `git diff --check` for implementation slices.

## Terra / Medium Quality Bar

Keep view observation narrow and identity stable. Stop before combining data flow with visual polish or broad feature redesign.

