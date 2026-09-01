# Ingestion Feed-State and Provenance Runbook

**Status:** Planned
**Applies to:** Durable feed metadata and Arcus/SPC transport provenance
**Project:** `SkyAware.xcodeproj`
**Parent epic:** [#426](https://github.com/justinrooks/project-arcus/issues/426)

## Purpose

Create a durable metadata sidecar and carry transport provenance through accepted canonical feed operations without changing scheduling yet.

## Required Read Order

1. Active child issue.
2. This runbook.
3. `docs/plans/ingestion-feed-state-provenance-progress.md`.
4. Cache-acceptance runbook and completed prerequisite issue handoffs.

## Minimal Implementation Prompt

> Implement only the active provenance slice using `GPT-5.6 Terra` with medium reasoning. Keep canonical repositories authoritative, keep the sidecar metadata-only, preserve cache on every non-accepted outcome, and stop at the issue boundary.

## Target Contract

- A versioned actor-owned sidecar stores attempt, network success, canonical acceptance, validity, transport source, generation, and failure classification.
- It contains no domain payloads and does not alter SwiftData schema version 3.
- Arcus and SPC outcomes retain live, 304, valid local cache, error fallback, rejection, failure, and cancellation provenance.
- Accepted generation advances only after canonical repository acknowledgement.

## Guardrails

- Follow the durable location-context sidecar pattern for versioning, corruption handling, bounded retention, and atomic replacement.
- Do not consolidate repository `ModelContext`s or introduce cross-actor transactions.
- Preserve current SPC staged-domain persistence.
- Never infer authoritative deletion from error fallback.

## Forbidden Scope

- Scheduling from the sidecar, global fallback-age rules, UI invalidation, SwiftData migration, or provider/repository ownership redesign.

## Execution Sequence

| Order | Work item | Preferred model |
|---:|---|---|
| 1 | [#441](https://github.com/justinrooks/project-arcus/issues/441) — Add a versioned feed-state sidecar | `GPT-5.6 Terra / medium` |
| 2 | [#444](https://github.com/justinrooks/project-arcus/issues/444) — Propagate Arcus transport provenance | `GPT-5.6 Terra / medium` |
| 3 | [#445](https://github.com/justinrooks/project-arcus/issues/445) — Propagate SPC text transport provenance | `GPT-5.6 Terra / medium` |
| 4 | [#443](https://github.com/justinrooks/project-arcus/issues/443) — Add transport provenance to SPC map outcomes | `GPT-5.6 Terra / medium` |

## Verification Defaults

- Sidecar tests cover round-trip, corruption, newer version, pruning, future dates, and concurrent updates.
- Provider/repository tests cover every transport source without live network.
- Run full unit lane when shared HTTP/provider contracts change; inspect `.xcresult`; run Debug build and `git diff --check`.

## Terra / Medium Quality Bar

Keep each vertical provenance path narrow. Stop before adding generalized cache frameworks, schema models, or scheduling behavior.

