# Resolve-Forward UI Polish Playbook

Use this playbook when implementing GitHub issues #195 through #201.

The work is visual polish for the existing cached-first, resolve-forward Summary experience. It is not a loading architecture project. Do not change what loads, when it loads, how providers refresh, how data is persisted, or how alerts/risk/weather are resolved.

## Issue Set

| Order | Issue | Title | Dependency |
|---|---:|---|---|
| 1 | [#195](https://github.com/justinrooks/project-arcus/issues/195) | [UI Polish] Standardize Summary resolving header language | None |
| 2 | [#196](https://github.com/justinrooks/project-arcus/issues/196) | [UI Polish] Add consistent Summary resolve-forward transition primitives | Should precede #197, #198, #200 |
| 3 | [#197](https://github.com/justinrooks/project-arcus/issues/197) | [UI Polish] Polish risk badge resolve-forward transitions | Prefer after #196 |
| 4 | [#198](https://github.com/justinrooks/project-arcus/issues/198) | [UI Polish] Stabilize Local Alerts resolving and empty states | Prefer after #196 |
| 5 | [#199](https://github.com/justinrooks/project-arcus/issues/199) | [UI Polish] Smooth Current Conditions resolve-forward updates | Best after #195 |
| 6 | [#200](https://github.com/justinrooks/project-arcus/issues/200) | [UI Polish] Normalize secondary Summary resolving states | Prefer after #196 |
| 7 | [#201](https://github.com/justinrooks/project-arcus/issues/201) | [UI Polish] Align cold-start resolving screen with SkyAware visual direction | Independent, last |

## Required Read Order

Before touching code for any issue, read:

1. `AGENTS.md`
2. `Sources/AGENTS.md`
3. `tasks/lessons.md`
4. The current GitHub issue body
5. `docs/plans/resolve-forward-ui-polish-progress.md`
6. `docs/SkyAware North Star Spec.md`
7. `docs/SkyAware Branding and Design Guide.md`
8. The relevant Summary/loading files for the issue

For Local Alerts work, also read:

- `docs/LifecycleInvestigationNotes.md`

For cold-start resolving work, also read widget rendering files only as visual reference:

- `WidgetsExtension/WidgetRenderingComponents.swift`
- `WidgetsExtension/WidgetRenderingStyle.swift`

## Non-Negotiables

- Do not change provider behavior.
- Do not change refresh orchestration.
- Do not change refresh timing.
- Do not change loading timing.
- Do not change what loads when.
- Do not change persistence.
- Do not change alert/risk/weather business logic.
- Do not introduce new data dependencies.
- Do not add a blocking splash when cached Summary content exists.
- Do not alter widget code unless an issue explicitly asks for a widget implementation change.
- Do not use provider names, system jargon, or debug language in user-facing copy.

This is polish work. If the implementation starts needing architecture, stop and re-plan. Architecture changes for a visual issue are usually a smell wearing a tie.

## Design North Star

SkyAware is a severe-weather awareness app, not a generic weather app.

The Summary resolve-forward experience should feel:

- calm
- clear
- professional
- coherent
- trustworthy
- increasingly accurate as data resolves

Prefer:

- stable containers
- typography-led hierarchy
- subtle opacity lift
- restrained blur-to-clear
- crossfades where they clarify state
- neutral freshness language
- semantic color only

Avoid:

- spinners as the default answer
- shimmer or flashy loading ornament
- noisy state labels
- provider/system language
- fake `All Clear` placeholders
- whole-card dimming when inner content can resolve cleanly
- layout jumps that make content feel rebuilt

## Current Implementation Map

Primary Summary surfaces:

- `Sources/App/HomeView.swift`
- `Sources/App/HomeRefreshPipeline.swift`
- `Sources/App/HomeRefreshV2/HomeSnapshot.swift`
- `Sources/App/HomeRefreshV2/HomeSnapshotStore.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/SummaryResolving.swift`
- `Sources/Features/Loading/LoadingView.swift`

Section components:

- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`
- `Sources/Features/Badges/FireWeatherRailView.swift`
- `Sources/Features/Badges/AtmosphereRailView.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Summary/OutlookSummaryCard.swift`

Motion and surfaces:

- `Sources/Utilities/Core/SkyAwareMotion.swift`
- `Sources/Utilities/Extensions/ext+View.swift`

Relevant tests:

- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`

## Per-Issue Workflow

1. Read the required docs and the current progress file.
2. Inspect the exact files listed in the issue scope.
3. Write down the smallest implementation plan in the progress file before editing if the issue touches more than one component.
4. Keep changes scoped to the issue.
5. Prefer existing modifiers, colors, radius, motion, and component patterns.
6. Add or adjust focused tests only where state helpers or deterministic presentation logic changes.
7. Run the smallest relevant validation before finishing.
8. Update `docs/plans/resolve-forward-ui-polish-progress.md` before final response.

## Validation Expectations

At minimum:

- Build the app target when production Swift changes are made.
- Run focused tests when helper logic changes.
- Inspect relevant previews when the issue changes SwiftUI layout or copy.
- Manually inspect the affected Summary states in Simulator when practical.

Use this build command unless a newer repo-local command supersedes it:

```sh
xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build
```

For issue-specific validation, follow the GitHub issue body. Do not claim tests, builds, screenshots, or simulator validation unless they actually ran.

## Progress Handoff Requirement

Before finishing any issue, update:

- `docs/plans/resolve-forward-ui-polish-progress.md`

Record:

- issue status
- files changed
- behavior intentionally preserved
- validation run
- screenshots or previews inspected, if any
- deferred work
- risk notes for the next issue

The next agent should be able to resume without reading your mind. We are good, but not telepathic. Yet.

