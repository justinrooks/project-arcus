# AGENTS.md — SkyAware Repository Guidance

## Context Discovery

- Consult [README.md](README.md) for repository orientation and [docs/README.md](docs/README.md) to locate authoritative local knowledge.
- Follow [Prompt_Fu's shared engineering principles](https://github.com/justinrooks/Prompt_Fu/blob/main/docs/engineering.md) and use its [knowledge index](https://github.com/justinrooks/Prompt_Fu/blob/main/docs/README.md) to locate applicable guidance and reusable capabilities.
- For cross-system work, consult the [Arcus ecosystem overview](https://github.com/justinrooks/Prompt_Fu/blob/main/docs/arcus/README.md). Verify implementation claims and contracts against their owning repositories.
- Apply [Sources/AGENTS.md](Sources/AGENTS.md) when working in the app source. Load only relevant documents; historical plans and audits are not automatically current authority.
- For code review, consult [local review guidance](docs/code_review.md). For user-facing work, consult the product, brand, and design authorities linked from the knowledge index.
- If shared guidance or local context tools are unavailable, state the limitation and proceed only where local evidence is sufficient.

## Repository and Platform

- Xcode project: `SkyAware.xcodeproj`; app source: `Sources/`; widgets: `WidgetsExtension/`; shared code: `Shared/`.
- Assets and previews: `Resources/`; configuration: `Config/`; tests: `Tests/UnitTests/` and `Tests/UITests/`.
- Swift 6+, iOS 18+ for the app, SwiftUI-first. Respect the deployment targets of individual Xcode targets and Swift concurrency boundaries.
- Avoid deprecated APIs and cross-platform assumptions unless explicitly required. Do not introduce cross-actor `ModelContext` misuse.
- Use four-space indentation, approximately 120-column lines when practical, tidy imports, PascalCase types, lowerCamelCase functions/properties, and `Tests` or `UITests` suffixes for test types.

## Build and Validation

- Open: `xed SkyAware.xcodeproj`
- Resolve packages: `xcodebuild -resolvePackageDependencies -project SkyAware.xcodeproj`
- Build (Debug): `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

Use the [CI and test-lane procedures](tools/ci/README.md) for simulator validation and evidence requirements:

| Lane | Command | Policy |
| --- | --- | --- |
| `SkyAware_Tests` | `tools/ci/run_test_lane.sh unit` | Required regression lane for normal implementation and CI; run the full lane for final regression validation. |
| `SkyAware_Performance` | `tools/ci/run_test_lane.sh performance` | Optional measurement lane; use for performance investigations or changes affecting measured behavior, alongside regression validation. |
| `SkyAware_UI_Smoke` | `tools/ci/run_test_lane.sh ui-navigation` | Separate simulator UI navigation evidence. |

- Use the runner for focused selections as well as complete lanes; it creates a fresh `.xcresult` and invokes native verification via `ci_scripts/verify_xcresult.sh`. Do not bypass it.
- Focused regression example: `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/SevereRiskRepoActiveSelectionTests`.
- Focused measurement example (target-qualified): `tools/ci/run_test_lane.sh performance -only-testing:SkyAwarePerformanceTests/MapSceneWarmingMeasurementTests`.
- Prefer iPhone 17 or iPhone 17 Pro on iOS 26.5 for local simulator runs when available.
- Use Swift Testing (`import Testing`), mirror production namespaces, and stub or fake providers and network boundaries. Deterministic tests must not intentionally make live WeatherKit, NWS, SPC, Arcus, or APNs requests.
- Preserve Xcode filename ordering when hand-editing test membership exception lists in `project.pbxproj` (for example, `ArcusMesoClientTests.swift` follows the `Alert*` entries). Commit verified ordering-only normalization rather than repeatedly reverting it.
- For new UI, include a smoke test of the main navigation or happy path when practical; keep existing test-dependent accessibility identifiers stable.
- Keep tests and test infrastructure compatible and efficient with Xcode Cloud.
- Validate proportionately to the change. Normal implementation must compile. Inspect finalized results and report commands, lane, outcome, counts (including parameter-expanded counts when available), simulator/runtime, configuration, plan, `.xcresult` path, failures and coverage impact when measured. Never claim execution or coverage that was not obtained.
- Regression, simulator UI, physical-device, and performance evidence are distinct. Passing measurement tests alone do not prove a performance improvement; report the environment and available measurement attachments.

## SwiftUI Specialist

For substantive SwiftUI implementation, architectural review, or performance investigation, use Apple's `swiftui-specialist` skill when available. Apply it to composition, Observation and state ownership, lifecycle, navigation, rendering efficiency, and native API usage.

The skill is framework guidance, not authority to redesign SkyAware. Preserve canonical state ownership, cache-forward presentation, Swift 6 concurrency guarantees, deployment targets, and established design language. Favor evidence-backed changes over stylistic refactoring. Do not invoke the skill for unrelated backend, persistence, or infrastructure work. If unavailable, proceed with standard project guidance and disclose its absence.

## Security and Configuration

- Keep private keys, WeatherKit credentials, and secrets out of the repository. Use local developer provisioning and per-user secure storage.
- Verify `Info.plist` changes and secrets templates before sharing builds.
- Do not log sensitive location or alert data in production code; preserve privacy-first handling of location, alert, and weather data.

## GitHub and Delivery

Use the applicable shared workflows and skills in Prompt_Fu, including its [GitHub workflow guidance](https://github.com/justinrooks/Prompt_Fu/blob/main/codex/context/github-workflows.md). Use short imperative commit summaries and the repository's [PR template](.github/pull_request_template.md). Include screenshots for UI changes when the workflow calls for them, and report material risks, rollback considerations, and actual validation evidence.

<!-- trail:start -->
## Trail — repo context graph

This repo is indexed in `graft/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `trail map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `trail ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `trail grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `trail skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `trail callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `graft/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `trail ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `trail build` (deterministic,
no API key, $0).
<!-- trail:end -->
