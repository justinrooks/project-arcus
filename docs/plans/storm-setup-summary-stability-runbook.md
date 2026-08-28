# Storm Setup Summary Stability Runbook

**Status:** Planned

**Applies to:** Project Arcus / SkyAware Today Storm Setup summary

**Project:** `justinrooks/project-arcus`

**Parent epic:** [#411](https://github.com/justinrooks/project-arcus/issues/411)

## Purpose

Make the Today Storm Setup section structurally stable whenever the user enables Storm Setup. Background refresh,
eligibility, and endpoint outcomes may change the card's content, but only an explicit switch-off or unavailable
location removes the section. Replace the redacted full-card placeholder with compact, truthful status states while
preserving fresh-cache presentation and existing request policy.

## Source Of Truth

Use this order when evidence conflicts:

1. The current GitHub child issue.
2. `docs/SkyAware North Star Spec.md`, especially Loading and Resolving guidance.
3. This runbook and `docs/plans/storm-setup-summary-stability-progress.md`.
4. Existing Storm Setup fetch/display policy and settings behavior.
5. Existing focused presentation, section-plan, HomeView, and UI tests.

Issue #322 is predecessor evidence, not the target contract. It stabilized loading-to-visible identity while preserving
conditional hiding. This campaign changes enabled-state visibility semantics.

## Required Read Order

1. `AGENTS.md`
2. `Sources/AGENTS.md`
3. `tasks/lessons.md`
4. The current GitHub issue
5. This runbook
6. `docs/plans/storm-setup-summary-stability-progress.md`
7. Only the production and test files named by the current issue

Future prompts should point to those sources rather than repeat the investigation.

## Minimal Prompt Contract

- Implement only the current child issue.
- Preserve the state matrix and guardrails below.
- Run the issue's focused checks and inspect finalized, non-zero `.xcresult` evidence.
- Update only the current issue section and verification row in the progress ledger.
- Stop for human review; do not continue into the next issue.

## Target State Contract

| Condition | Today presentation |
| --- | --- |
| Storm Setup disabled | Hidden immediately |
| Location unavailable | Hidden; existing location guidance remains authoritative |
| Enabled, fetch-eligible refresh active, no usable result | Compact analyzing state |
| Enabled, fresh displayable result | Full navigable Storm Setup card |
| Enabled, fresh result suppressed by display policy | Compact no-notable-setup state |
| Enabled, current inputs are not fetch eligible | Compact analysis-not-needed state |
| Enabled, eligible refresh ends without usable data | Compact unavailable state |
| Enabled, fresh displayable cache during refresh | Keep the full cached card visible |

The main switch is the section-visibility opt-in. Detailed Ingredients remains stored while the main switch is off,
becomes effective when the main switch is enabled, and continues to force fetch/display according to current policy.

## Locked Copy Intent

Exact wording may be tightened during rendered review, but semantics must remain distinct:

- Analyzing: work is actively resolving; do not expose generic `Loading` copy or fake ingredient rows.
- No notable setup: a fresh result exists but does not qualify for full display.
- Analysis not needed: current local policy inputs do not justify a request.
- Unavailable: an eligible attempt ended without usable guidance; do not claim quiet weather.

Keep the visible `Storm Setup` label in every enabled state. Status states are not navigation controls. The full result
remains one accessible navigation control.

## Required Guardrails

- Preserve the existing `stormSetupEnabled` and `detailedIngredientsEnabled` keys and `@AppStorage` ownership.
- Preserve enable-triggered refresh behavior in `HomeView`; disabling need not cancel an in-flight request.
- Preserve `StormSetupFetchPolicy` and `StormSetupDisplayPolicy` as the eligibility authorities.
- Preserve fresh-cache selection, H3 isolation, expiration, timeout, cancellation, backoff, persistence, and background
  behavior.
- Never display expired Storm Setup guidance to avoid a visual transition.
- Preserve the `.stormSetup` section identity across every enabled state.
- Keep fresh displayable cached content visible during refresh; never replace it with an analyzing card.
- Use calm, weather-specific resolving language consistent with the North Star spec.
- Respect Dynamic Type, VoiceOver, Increase Contrast, dark appearance, and Reduce Motion.
- Keep state derivation pure and deterministic; SwiftUI renders the selected state and forwards navigation intent.

## Forbidden Scope

- AQI/Storm Setup enrichment publication decoupling.
- Home ingestion, endpoint, timeout, cache, persistence, or schema changes.
- Expired-data presentation.
- Settings layout, labels, keys, defaults, or new toggles.
- Atmospheric Conditions ordering or redesign.
- Storm Setup detail redesign or ingredient-content changes.
- General Summary animation, section ordering, or refresh refactors.
- New protocols, view models, or generic loading frameworks without a current consumer.

If independent Storm Setup publication is later authorized, plan it separately and use `gpt-5.6-sol` at high
reasoning because it crosses structured concurrency, staged publication, cancellation, and main-actor state.

## Current Boundaries To Preserve

- Settings UI: `Sources/Features/Settings/SettingsView.swift`
- Settings refresh trigger: `Sources/App/HomeView.swift` and `Sources/App/HomeView+PresentationState.swift`
- Fetch/display policy: `Sources/Models/StormSetup/StormSetupPreferences.swift`
- Summary state and section selection: `Sources/Features/Summary/SummaryView.swift`
- Presentation/section contract: `Sources/Features/StormSetup/StormSetupPresentation.swift`
- Card rendering: `Sources/Features/StormSetup/StormSetupSummaryCard.swift`
- Existing state tests: `Tests/UnitTests/SummaryViewLoadingStateTests.swift`
- Existing section tests: `Tests/UnitTests/SummarySectionPlanTests.swift`
- Existing settings tests: `Tests/UnitTests/HomeViewStateTests.swift`
- Existing UI fixtures: `Sources/App/SkyAwareApp.swift` and `Tests/UITests/SkyAwareUITests.swift`

## Sequential Execution

Run child issues strictly in order.

| Order | Work item | Recommended model | Stop condition |
| ---: | --- | --- | --- |
| 1 | [#412](https://github.com/justinrooks/project-arcus/issues/412) — Define the stable summary-state contract | `gpt-5.6-terra` / medium | Pure state matrix and focused tests pass; runtime UI is unchanged. |
| 2 | [#413](https://github.com/justinrooks/project-arcus/issues/413) — Render compact enabled states on Today | `gpt-5.6-terra` / medium | Today renders stable enabled states, removes the redacted placeholder, and passes focused tests/build. |
| 3 | [#414](https://github.com/justinrooks/project-arcus/issues/414) — Verify settings transitions and accessibility | `gpt-5.6-terra` / medium | Deterministic toggle/state coverage and rendered accessibility evidence pass; campaign ledger is complete. |

Terra medium is sufficient for all three slices: they are bounded SwiftUI/pure-state/test tasks and deliberately avoid
concurrency or persistence ownership changes. No issue in this campaign requires Sol.

## Verification Defaults

- Use Swift Testing for pure state and section-plan coverage.
- Use deterministic fixtures; never call live Arcus Signal, NWS, SPC, or WeatherKit services.
- Run the smallest focused suite during implementation, then `tools/ci/run_test_lane.sh unit` and a Debug simulator
  build before completing the behavior issue.
- Use `tools/ci/run_test_lane.sh ui-navigation` or a narrower deterministic UI command when the issue adds UI coverage.
- Inspect every generated `.xcresult`; report exact executed, passed, failed, and skipped counts.
- Exercise light/dark appearance, accessibility Dynamic Type, VoiceOver semantics, and Reduce Motion through previews or
  deterministic UI evidence where the current issue requires it.
- Run `git diff --check` for every issue.
- Planning-only changes require link/placeholder verification, not app tests.

## Quality Bar For 5.6 Terra Medium

- One behavior or validation slice per issue.
- Prefer one to three production files and stay under roughly 200 changed lines where practical.
- No unrelated cleanup, formatting churn, or abstraction work.
- Preserve established switch, navigation, cache, and policy behavior unless the issue explicitly changes it.
- Treat tests as behavioral contracts, not implementation snapshots.
- Stop and escalate if the slice requires ingestion/publication changes, stale-data policy, or more than five production
  files.
