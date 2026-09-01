# Ingestion Durable Scheduling Runbook

**Status:** Planned
**Applies to:** Location-scoped durable refresh admission and feed-specific HTTP fallback policy
**Project:** `SkyAware.xcodeproj`
**Parent epic:** [#423](https://github.com/justinrooks/project-arcus/issues/423)

## Purpose

Drive hot, map, outlook, and weather admission from durable accepted feed state and replace ambiguous fallback with feed-specific policy.

## Required Read Order

1. Active child issue.
2. This runbook.
3. `docs/plans/ingestion-durable-scheduling-progress.md`.
4. Feed-state/provenance runbook and completed prerequisite issue handoffs.

## Minimal Implementation Prompt

> Implement only the active scheduling slice using `GPT-5.6 Terra` with medium reasoning. Schedule from accepted location-scoped state, never from attempt completion, preserve background budgets, update the ledger, and stop.

## Target Contract

- Accepted freshness survives process restart and is scoped by feed and location identity.
- Failed, rejected, or fallback-only attempts remain retry eligible.
- Maps and outlooks retain independent cadence.
- Weather acceptance follows successful durable projection acknowledgement.
- Each client has an explicit evidence-backed fallback policy; there is no global safety-critical age.

## Guardrails

- Feed state remains metadata only.
- Preserve forced-refresh semantics, targeted remote-alert distinction, background cadence, and canonical cache.
- Do not let fallback responses reconcile authoritative empty/deletion.
- Policy work may split again if feed evidence differs materially.

## Forbidden Scope

- UI redesign, map reload wiring, coordinator replacement, schema migration, or global cache framework.

## Execution Sequence

| Order | Work item | Preferred model |
|---:|---|---|
| 1 | [#447](https://github.com/justinrooks/project-arcus/issues/447) — Drive hot scheduling from durable feed state | `GPT-5.6 Terra / medium` |
| 2 | [#446](https://github.com/justinrooks/project-arcus/issues/446) — Drive map and outlook scheduling independently from durable state | `GPT-5.6 Terra / medium` |
| 3 | [#448](https://github.com/justinrooks/project-arcus/issues/448) — Drive WeatherKit scheduling from durable state | `GPT-5.6 Terra / medium` |
| 4 | [#442](https://github.com/justinrooks/project-arcus/issues/442) — Define feed-specific HTTP fallback age policies | `GPT-5.6 Terra / medium` |

## Verification Defaults

- Disk close/reopen tests are mandatory for durable admission.
- Cover location changes, forced runs, partial failures, fallback, future timestamps, and cancellation.
- Run full unit lane for shared scheduling/policy changes; inspect `.xcresult`; run Debug build and `git diff --check`.

## Terra / Medium Quality Bar

One feed family or policy decision per issue. Stop if a single fallback-policy issue cannot remain evidence-backed and reviewable.

