# AGENTS.md — SkyAware Repository Guidance

## Purpose
- This file defines durable repository guidance for Codex and other agents working in this repo.
- Keep changes aligned with the existing architecture, coding patterns, and product goals.
- Prefer concrete repo-specific guidance over generic advice.

## Project Structure
- Root Xcode project lives at `SkyAware.xcodeproj`.
- App source lives in `Sources`.
- Shared assets and previews live in `Resources`.
- Config plist files live in `Config`.
- Tests live in:
  - `Tests/UnitTests`
  - `Tests/UITests`
- Release artifacts live in `release`.
- Legal and policy documents live in `legal`.
- CI helper scripts live in `tools/ci`.
- Source-specific agent guidance lives in `Sources/AGENTS.md`.
- UI reference screenshots live in `docs/images`.
  - Use them to preserve visual consistency when building or revising UI.
  - Treat them as reference material, not as a source of exact truth unless the task explicitly says to match them.

## Build, Test, and Development Commands
- Build (Debug):
  `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Test-lane policy (Debug, simulator):
  - `SkyAware_Tests` is the default regression suite and is required for normal implementation and CI validation:
    `tools/ci/run_test_lane.sh unit`
  - During implementation, run focused regression selections through the same runner so native XCResult verification remains active; run the full unit lane for final regression validation. For example:
    `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/SevereRiskRepoActiveSelectionTests`
  - `SkyAware_Performance` is an optional measurement suite. Run it during performance investigations or when a
    change could affect measured behavior; run the regression suite as well when validating such a change:
    `tools/ci/run_test_lane.sh performance`
  - Focused measurements use target-qualified selectors through the same runner, with XCResult verification narrowed
    to the selected expected set. For example:
    `tools/ci/run_test_lane.sh performance -only-testing:SkyAwarePerformanceTests/MapSceneWarmingMeasurementTests`
  - `SkyAware_UI_Smoke` remains a separate UI navigation smoke lane:
    `tools/ci/run_test_lane.sh ui-navigation`
  - The runner accepts focused `xcodebuild test` selection arguments after the lane name. It creates a fresh
    `.xcresult` bundle and invokes `ci_scripts/verify_xcresult.sh` for every lane. Focused runs must still use this
    runner and its native result verification.
- Evidence reporting: report the exact lane and command, finalized result, logical test counts and parameter-expanded count when available, simulator/runtime, configuration, plan, and `.xcresult` path. Regression results are deterministic behavior evidence. Performance measurements are environment-dependent diagnostics; include the test, environment, and available measurement attachments, and do not present a passing measurement suite as proof of a performance improvement by itself.
- Deterministic tests use stubs/fakes and make no intentional live WeatherKit, NWS, SPC, Arcus, or APNs requests.
- `SkyAware_UI_Smoke` provides simulator UI navigation evidence. Unit and performance lanes do not establish rendered UI, physical-device behavior, or Instruments/device performance evidence.
- Resolve Swift package dependencies:
  `xcodebuild -resolvePackageDependencies -project SkyAware.xcodeproj`
- Open in Xcode:
  `xed SkyAware.xcodeproj`

## Platform and Architecture Constraints
- Swift 6+, iOS 18+ only.
- SwiftUI-first.
- Keep changes aligned with the existing app, server, and shared architecture boundaries in this repository.
- Avoid deprecated APIs and cross-platform assumptions unless the task explicitly requires them.
- Do not introduce cross-actor `ModelContext` misuse.

## Coding Conventions
- Indent with 4 spaces.
- Wrap lines around 120 columns when practical.
- Keep imports ordered and tidy.
- Naming:
  - Types use PascalCase.
  - Functions and properties use lowerCamelCase.
  - Test types end with `Tests` or `UITests`.

## Testing Expectations
- Use Swift Testing (`import Testing`).
- When hand-editing `project.pbxproj` test membership exception lists, preserve Xcode's filename ordering (for example, `ArcusMesoClientTests.swift` follows the `Alert*` entries). Commit verified ordering-only normalization rather than repeatedly reverting it and leaving the committed project out of order.
- Do not hit live WeatherKit, NWS, or SPC feeds in tests.
- Stub or fake providers and network boundaries.
- When adding UI, include a smoke UI test for the main navigation or happy path when practical.
- Keep accessibility identifiers stable when they are used for UI testing.
- Prefer iPhone 17 or iPhone 17 Pro on iOS 26.5 for local simulator runs when available.
- If test execution produces an `.xcresult`, inspect it and report failures and coverage impact when available.
- Mirror production namespaces when adding tests.

## Definition of Done
- The change should compile unless the task explicitly requests draft-only output.
- Validate the smallest relevant scope before finishing.
- Prefer minimal diffs that solve the problem cleanly.
- Do not claim tests passed unless you ran them.
- Do not claim coverage changed unless you measured it.

## Commit and PR Guidance
- Commits should target a single-line imperative summary .
  - Example: `Fix bug preventing watches from loading`
- PRs should summarize intent, list user-visible changes, and note validation performed.
- For UI changes, include screenshots when the workflow calls for them.
- Call out risk areas and rollback considerations when they matter.

## Security and Configuration
- Keep private keys, WeatherKit credentials, and secrets out of the repo.
- Use local developer provisioning and per-user secure storage.
- Verify `Info.plist` changes and secrets templates before sharing builds.
- Do not log sensitive location or alert data in production code.
- Preserve the privacy-first handling of location, alert, and weather data across all repository changes.

## Related Guidance
- For code review tasks, follow `docs/code_review.md`.
- For product behavior and meteorological meaning, follow `docs/product/north-star.md`.
- For brand identity, terminology, and communication, follow `docs/brand/brand-and-voice.md`.
- For visual and interaction design, start with `docs/design/README.md`, which routes to the relevant surface guidance.
- For design, UI, brand, screenshots, marketing visuals, and user-facing copy, follow `docs/SkyAware North Star Spec.md`.

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
