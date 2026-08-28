# Air Quality Cache-Forward Runbook

**Status:** Planned

**Applies to:** SkyAware Today air-quality persistence, ingestion, and presentation

**Project:** `SkyAware.xcodeproj`

**Parent epic:** [#404](https://github.com/justinrooks/project-arcus/issues/404)

## Related documents

- `AGENTS.md`
- `Sources/AGENTS.md`
- `tasks/lessons.md`
- `docs/plans/air-quality-cache-forward-progress.md`
- `docs/plans/today-state-flow-runbook.md`
- `docs/plans/today-refresh-performance-runbook.md`
- `docs/SkyAware North Star Spec.md`
- `docs/code_review.md`

## Purpose

Make Today display the current location's durable cached AQI immediately, keep it visible while the foreground AQI
request is pending or unavailable, and quietly replace it when a newer accepted observation arrives. Complete the
existing cache-forward architecture instead of adding a second cache or presentation state machine.

## Source-of-truth order

1. The active GitHub child issue for its exact review unit.
2. This runbook for campaign guardrails and ordering.
3. `air-quality-cache-forward-progress.md` for accepted decisions, evidence, and handoff state.
4. Current production source and focused tests.
5. The closed AQI-preservation issue #331 for historical scope only; it intentionally excluded persistence.

If these sources conflict, stop and record the contradiction. Do not expand the active issue to resolve adjacent
architecture or product questions.

## Required read order

1. `AGENTS.md`, `Sources/AGENTS.md`, and relevant entries in `tasks/lessons.md`.
2. The active child issue.
3. This runbook and the matching progress section.
4. Only the likely production files and focused tests named by the issue.

Do not repeat the original investigation or inspect Arcus Signal internals. The consumed AQI contract is already
known and no server change is required.

## Minimal implementation prompt

> Implement only the active child issue in the Air Quality Cache-Forward epic. Read the issue, runbook, and matching
> progress entry. Preserve location identity and staged core-before-enrichment publication, add deterministic proof,
> run the issue's exact validation, inspect every `.xcresult`, update the progress ledger, and stop. Do not continue
> to the next issue or perform adjacent cleanup.

## Target contract

1. `HomeProjectionStore` owns durable location-scoped AQI alongside other Today projection slices.
2. Only a successful accepted AQI response updates the durable slice; skipped, empty, failed, and canceled work
   preserves it.
3. An older `observedAt` cannot replace a newer cached observation.
4. `HomeIngestionExecutor` preserves core-before-enrichment publication and publishes the value accepted by durable
   storage.
5. `HomePresentationSnapshot` prefers a matching live AQI and otherwise falls back to the selected projection AQI.
6. Location changes never expose the prior location's AQI.
7. The Atmospheric Conditions rail keeps its current stable AQI identity and reduce-motion-aware settle animation.

## Required guardrails

- Persist primitive optional fields with a computed `AirQualityCurrentResponse` interface. Do not persist the
  ArcusCore `Codable` value directly in SwiftData.
- Prove insert/save, fetch/reconstruction, disk close/reopen, nil/default state, independent locations, and migration
  from the previous production schema.
- Preserve every non-AQI projection slice and its timestamps during AQI writes.
- Treat persistence failure as degraded durability: log it and retain the live value for the current session.
- Preserve `.replace` versus `.preserve`, visible-submission rejection, refresh-key isolation, and structured
  concurrency.
- Keep ingestion preference-independent. `alwaysShowAirQuality` remains a presentation preference.
- Use deterministic fakes. Do not call live Arcus, WeatherKit, NWS, SPC, or APNs in tests.
- Keep each issue within one reviewable behavior slice and update the progress ledger before closing it.

## Forbidden scope

- ArcusCore or Arcus Signal changes.
- HTTP cache policy, endpoint, retry, timeout, or URL changes.
- A generic enrichment cache, repository framework, observable owner, or event bus.
- New loading, stale, offline, badge, or status UI.
- Atmospheric Conditions redesign or animation changes unless the final visual check proves the existing transition
  violates the acceptance criteria and the issue is explicitly re-scoped.
- Storm Setup, weather, alert, risk, widget, background cadence, notification, or location-policy changes.
- Unrelated SwiftData schema cleanup or Home refactoring.

## Boundaries to preserve

- `HomeProjectionStore` remains durable Today projection ownership.
- `HomeIngestionCoordinator` remains run serialization and joining ownership.
- `HomeIngestionExecutor` retains structured optional enrichment after durable core publication.
- `HomeRefreshPipeline` retains visible submission/publication ownership and location-change clearing.
- `HomePresentationSnapshot` remains the pure cached/live arbitration boundary.
- `AtmosphericConditionsCard` remains a thin presentation consumer.

## Sequential execution

| Order | Work item | Preferred implementer | Dependency | Stop condition |
| ---: | --- | --- | --- | --- |
| 01 | [#405](https://github.com/justinrooks/project-arcus/issues/405) — Persist AQI in the Home projection | `GPT-5.6 Terra / medium` | None | Durable, monotonic, location-scoped AQI survives migration and disk reopen without changing other slices. |
| 02 | [#406](https://github.com/justinrooks/project-arcus/issues/406) — Persist accepted AQI enrichment | `GPT-5.6 Terra / medium` | 01 | Successful enrichment writes and publishes the accepted value; unavailable outcomes preserve cache. |
| 03 | [#407](https://github.com/justinrooks/project-arcus/issues/407) — Roll cached AQI forward in Today | `GPT-5.6 Terra / medium` | 02 | Cached AQI remains visible until matching fresh AQI quietly replaces it, with location isolation. |

Execute sequentially and stop after each issue for human review.

## Verification defaults

- Run the active issue's focused Swift Testing suites during iteration.
- Use `tools/ci/run_test_lane.sh unit` for the final persistence/presentation slice and inspect the finalized
  `.xcresult`; require a known successful result and nonzero test count.
- Run a Debug build after every production change.
- Run `tools/ci/run_test_lane.sh ui-navigation` only for the final presentation slice; it is navigation evidence,
  not proof of AQI cache behavior.
- Perform a manual simulator warm-launch check after issue 03: cached AQI is present before a delayed fresh response,
  and the replacement produces no missing-value flash.
- Perform a manual cached-location switch check to prove no cross-location leakage.
- Run `git diff --check` and review changed files after every issue.

## Quality bar for GPT-5.6 Terra / medium

- One semantic boundary per issue, ideally one to three production files.
- Characterize existing behavior before changing it.
- Prefer the smallest explicit method and value transformation over a new abstraction.
- Keep production changes near 200 lines or less when practical; test and frozen migration fixtures may exceed that
  only when required for disk-backed proof.
- Stop and re-plan before changing more than five production files, introducing a custom migration plan, changing a
  cross-repository contract, or adding a second user-visible behavior.
