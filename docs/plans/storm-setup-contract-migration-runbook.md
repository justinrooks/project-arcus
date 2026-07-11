# Storm Setup Contract Migration Runbook

**Status:** Planned

**Applies to:** Project Arcus / SkyAware Storm Setup

**Project:** `justinrooks/project-arcus`

**Parent epic:** [#283](https://github.com/justinrooks/project-arcus/issues/283)

## Purpose

Migrate Project Arcus from its local two-response Storm Setup integration to the public ArcusCore
`StormSetupCurrentResponse` returned by `GET /api/v1/storm-setup/current`. Preserve the existing Storm Setup summary,
detail navigation, layout, labels, and cache-forward behavior while removing every app-side request and lifecycle
dependency on `GET /api/v1/dev/anvil/profile-analysis`.

Dependency adoption and baseline ArcusCore contract fixtures are handled separately by the project owner. This campaign
starts with presentation alignment.

## Source Of Truth

Use this order when evidence conflicts:

1. The current GitHub child issue.
2. ArcusCore `0.4.1` public Storm Setup types.
3. Arcus Signal `StormSetupCurrentResponse` route and provider tests.
4. This runbook and `docs/plans/storm-setup-contract-migration-progress.md`.
5. Existing Project Arcus presentation behavior and focused tests.

## Required Read Order

1. `AGENTS.md`
2. `Sources/AGENTS.md`
3. `tasks/lessons.md`
4. The current GitHub issue
5. This runbook
6. `docs/plans/storm-setup-contract-migration-progress.md`
7. The production and test files named by the issue

Future implementation prompts should point to those sources instead of reproducing the investigation.

## Target Contract And Flow

```text
HomeView
  -> HomeRefreshPipeline
  -> HomeIngestionExecutor
  -> StormSetupQuerying
  -> StormSetupHTTPClient
  -> GET /api/v1/storm-setup/current?h3=<signed Int64 decimal>
  -> ArcusCore.StormSetupCurrentResponse
  -> HomeProjectionStore
  -> StormSetup summary/detail presentation
  -> existing SwiftUI
```

Consume these ArcusCore types directly:

- `StormSetupCurrentResponse`
- `StormSetupCurrentSetupResponse`
- `StormSetupTornadoIngredientsResponse`
- `TornadoRawParameters`
- `TornadoViabilityReport` and `TornadoViabilityDetails`
- `IngredientSupport`, `SnapshotConfidence`, and `TornadoViabilityLimiter`
- `AnvilAnalyzeProfileResponse` and its nested public DTOs

Do not create a parallel app-local transport graph.

## Locked Decisions

- The owner will update ArcusCore and establish dependency availability before this campaign begins.
- Decode the current endpoint directly as `ArcusCore.StormSetupCurrentResponse`.
- Use ArcusCore `.moderate`; present it with the existing user-facing medium-confidence wording.
- Let ArcusCore decode externally tagged `TornadoViabilityRealization` and
  `TornadoViabilityFailureMode`. Do not recreate their Codable behavior.
- Preserve numeric SHIP in Detailed Ingredients using `profileAnalysis.ship`.
- Do not derive categorical SHIP support from the numeric value.
- `Primary drivers` has no authoritative replacement in the public contract. Defer its redesign and do not synthesize
  values from similarly named viability fields.
- `profileAnalysis == nil` is a valid successful aggregate response. Never carry an older profile into a newer
  aggregate response.
- The app is deployed to one development device. Prefer clearing/reinstalling local data over building a broad
  production SwiftData migration framework solely for obsolete short-lived Storm Setup cache fields.
- Preserve the primary endpoint's H3 validation, freshness, foreground timeout, cancellation, failed-attempt backoff,
  newer-response check, and fresh-cache fallback.
- `Detailed Ingredients` remains a presentation preference. It must no longer control whether a second request runs.

## Guardrails

- One Storm Setup HTTP request per eligible refresh.
- No calls to `dev/anvil/profile-analysis` after cutover.
- No Arcus Signal changes unless direct evidence shows the public contract cannot satisfy the agreed UI.
- No UI redesign, navigation change, label rewrite, icon change, or layout restructuring.
- No speculative compatibility decoder for old and new server payloads.
- No custom unknown-enum fallback around ArcusCore in this campaign. The app and server are coordinated, single-device
  development deployments; add compatibility only if a real mixed-version requirement appears.
- Keep app-specific formatting, accessibility copy, and enum-to-label mapping in Project Arcus.
- Preserve Swift 6 actor isolation: ingestion in its actor, projection persistence in its model actor, observable UI
  state on the main actor.
- Update `docs/plans/storm-setup-contract-migration-progress.md` before completing each issue.

## Forbidden Scope

- Primary Drivers redesign or replacement.
- New Storm Setup visual hierarchy.
- New settings or feature flags.
- Arcus Signal endpoint/provider changes.
- General home-refresh refactors.
- Long-lived schema migration infrastructure for a one-device development cache.
- Retaining obsolete Anvil code for hypothetical future use.

## Current Boundaries To Preserve

- Networking: `Sources/Clients/StormSetupClient.swift`
- Fetch seam: `Sources/Interfaces/StormSetup/StormSetupQuerying.swift`
- Orchestration: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Snapshot/main-actor publication: `Sources/App/HomeRefreshV2/HomeSnapshot.swift` and
  `Sources/App/HomeRefreshPipeline.swift`
- Persistence: `Sources/Models/Home/HomeProjection.swift` and `Sources/Repos/HomeProjectionStore.swift`
- Presentation: `Sources/Features/StormSetup/StormSetupPresentation.swift` and
  `Sources/Features/StormSetup/StormSetupDetailPresentation.swift`
- UI: existing Storm Setup views remain render-only consumers.

## Sequential Execution

Run child issues strictly in order. Do not remove the old profile path until the aggregate response is decoded,
presented, persisted, and published through the runtime path.

| Order | Work item | Preferred model | Stop condition |
|---:|---|---|---|
| 1 | [#284](https://github.com/justinrooks/project-arcus/issues/284) — Align Storm Setup presentation with ArcusCore | `5.4 mini medium` | Presentation tests pass using ArcusCore values; runtime unchanged. |
| 2 | [#285](https://github.com/justinrooks/project-arcus/issues/285) — Decode the aggregate response in the primary client | `5.4 mini medium` | Current client/protocol return the ArcusCore response; old orchestration still compiles. |
| 3 | [#286](https://github.com/justinrooks/project-arcus/issues/286) — Persist one aggregate Storm Setup payload | `5.4 mini medium` | Projection store atomically reads/writes the aggregate payload. |
| 4 | [#287](https://github.com/justinrooks/project-arcus/issues/287) — Cut ingestion and observable state to one request | `5.6 luna medium` | One request owns refresh/cache/error state; no profile result branch remains. |
| 5 | [#288](https://github.com/justinrooks/project-arcus/issues/288) — Remove Anvil plumbing and complete the dead-code audit | `5.4 mini medium` | No direct or indirect app dependency on the development endpoint remains. |

## Verification Defaults

- Use Swift Testing and deterministic HTTP fakes; never call live Arcus Signal endpoints in tests.
- Run the focused suites named by the current issue, then a Debug build.
- For the final issue, run the broader Storm Setup, home ingestion, pipeline, projection-store, and presentation suites.
- Inspect an `.xcresult` when a test command produces one and report failures accurately.
- Verify endpoint removal with targeted `rg` searches.
- Planning-only changes require document/link verification, not an app build.

## Quality Bar

For `5.4 mini medium` execution:

- One behavior change per issue.
- Prefer one to three production files; stop before unrelated cleanup.
- Use the exact ArcusCore property named by the issue.
- Add behavior-focused tests before deleting old coverage.
- Do not preserve two-request abstractions after their final consumer is gone.
- Escalate only the ingestion/pipeline cutover to `5.6 luna medium`; it spans actor state, cache roll-forward, request
  results, and main-actor publication.
