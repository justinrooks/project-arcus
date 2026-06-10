# Apple-Native UI Alignment Runbook

Use this runbook to execute the Apple-native UI alignment epic derived from
`docs/audits/apple-native-ui-audit.md`.

This is a focused refinement of the existing SkyAware experience. It is not a redesign, an Apple Weather clone, or
permission to replace domain-specific severe-weather components with generic system UI.

## GitHub Coordination

- Parent epic: [#216](https://github.com/justinrooks/project-arcus/issues/216)
- Project: [Project Arcus](https://github.com/users/justinrooks/projects/1)
- Native sub-issues: #217 through #244, ordered as listed below

## Source Of Truth

- Audit: `docs/audits/apple-native-ui-audit.md`
- Progress ledger: `docs/plans/apple-native-ui-alignment-progress.md`
- Product direction: `docs/SkyAware North Star Spec.md`
- Brand guidance: `docs/SkyAware Branding and Design Guide.md`
- Repository guidance: `AGENTS.md` and `Sources/AGENTS.md`

## Required Read Order

Before implementing any work item:

1. Read `AGENTS.md`.
2. Read `Sources/AGENTS.md`.
3. Read `tasks/lessons.md`.
4. Read the current GitHub issue.
5. Read this runbook.
6. Read `docs/plans/apple-native-ui-alignment-progress.md`.
7. Read the relevant audit finding in `docs/audits/apple-native-ui-audit.md`.
8. Inspect the exact production and test files named by the issue.

## Non-Negotiables

- Preserve SkyAware's severe-weather awareness mission and canonical vocabulary.
- Preserve custom risk badges, threat visuals, map overlays, hatching, and atmospheric identity.
- Preserve cached-first, resolve-forward behavior.
- Never communicate risk, availability, freshness, or selection by color alone.
- Do not invent hazard semantics or fabricate missing weather metadata.
- Do not turn utility-screen modernization into a broad app architecture refactor.
- Do not apply Liquid Glass broadly. Use it only where hierarchy or interaction justifies it.
- Do not create a large token or design-system framework for this epic.
- Do not change provider, persistence, notification delivery, or refresh behavior unless an issue explicitly requires
  a narrow state correction.
- Keep each issue independently reviewable. Do not pull later visual polish into an earlier correctness issue.

## Working Rules

- Execute work items in the listed order unless the progress ledger documents a safe exception.
- One issue should normally produce one focused PR.
- Add deterministic tests when presentation ordering, derived state, or accessibility strings can be tested without
  live providers.
- Use previews and Simulator checks for layout, Dynamic Type, color scheme, and Reduce Motion work.
- Update the progress ledger before finishing every issue.
- Record deviations, discovered coupling, deferred work, and validation evidence for the next agent.

## Model Guidance

- `gpt-5.4-mini / medium`: narrow SwiftUI, copy, semantics, or deterministic helper changes.
- `gpt-5.4-mini / high`: small scope with subtle state or accessibility behavior.
- `gpt-5.4 / medium`: multi-component UI/state work or shared surface policy.
- `gpt-5.4 / high`: map state architecture or accessibility work with MapKit/custom rendering.

Escalate only when repository evidence shows the assigned issue crosses the stated boundary. Do not enlarge scope
preemptively.

## Ordered Work Items

| Order | ID | GitHub | Title | Model | Audit coverage | Dependency |
|---:|---|---|---|---|---|---|
| 1 | AN-01 | [#217](https://github.com/justinrooks/project-arcus/issues/217) | Enforce warning-first alert presentation | gpt-5.4-mini / high | HIER-1 | None |
| 2 | AN-02 | [#218](https://github.com/justinrooks/project-arcus/issues/218) | Preserve critical alert text for VoiceOver | gpt-5.4-mini / medium | A11Y-1 | AN-01 preferred |
| 3 | AN-03 | [#219](https://github.com/justinrooks/project-arcus/issues/219) | Convert the location reliability rail to native buttons | gpt-5.4-mini / medium | NATIVE-2 | None |
| 4 | AN-04 | [#220](https://github.com/justinrooks/project-arcus/issues/220) | Separate notification preference from authorization | gpt-5.4-mini / high | NATIVE-4 | None |
| 5 | AN-05 | [#221](https://github.com/justinrooks/project-arcus/issues/221) | Remove raw diagnostics from production Settings | gpt-5.4-mini / medium | NATIVE-4 | AN-04 preferred |
| 6 | AN-06 | [#222](https://github.com/justinrooks/project-arcus/issues/222) | Make launch and onboarding presentation state explicit | gpt-5.4 / medium | NAV-1 | None |
| 7 | AN-07 | [#223](https://github.com/justinrooks/project-arcus/issues/223) | Make onboarding resilient to Dynamic Type | gpt-5.4-mini / high | TYPE-2 | AN-06 |
| 8 | AN-08 | [#224](https://github.com/justinrooks/project-arcus/issues/224) | Apply Reduce Motion to onboarding and toasts | gpt-5.4-mini / medium | MOTION-1 | AN-06 |
| 9 | AN-09 | [#225](https://github.com/justinrooks/project-arcus/issues/225) | Replace implementation language in user-facing copy | gpt-5.4-mini / medium | COPY-1 | AN-06 preferred |
| 10 | AN-10 | [#226](https://github.com/justinrooks/project-arcus/issues/226) | Preserve optional Outlook metadata truthfully | gpt-5.4-mini / medium | COPY-2 | AN-09 preferred |
| 11 | AN-11 | [#227](https://github.com/justinrooks/project-arcus/issues/227) | Use proportional typography for weather narratives | gpt-5.4-mini / medium | TYPE-1 | None |
| 12 | AN-12 | [#228](https://github.com/justinrooks/project-arcus/issues/228) | Preserve cached Summary content while offline | gpt-5.4 / medium | HIER-2 | None |
| 13 | AN-13 | [#229](https://github.com/justinrooks/project-arcus/issues/229) | Restore Summary hero category identity at large text sizes | gpt-5.4 / medium | HIER-3 | AN-12 preferred |
| 14 | AN-14 | [#230](https://github.com/justinrooks/project-arcus/issues/230) | Define explicit semantics for custom controls | gpt-5.4-mini / high | A11Y-2 | AN-03, AN-13 |
| 15 | AN-15 | [#231](https://github.com/justinrooks/project-arcus/issues/231) | Restore semantic color discipline | gpt-5.4 / medium | COLOR-1 | AN-12 |
| 16 | AN-16 | [#232](https://github.com/justinrooks/project-arcus/issues/232) | Make static chips noninteractive and modernize haptics | gpt-5.4-mini / medium | NATIVE-3 | AN-15 preferred |
| 17 | AN-17 | [#233](https://github.com/justinrooks/project-arcus/issues/233) | Make Liquid Glass opt-in | gpt-5.4 / medium | COLOR-2 | AN-15 |
| 18 | AN-18 | [#234](https://github.com/justinrooks/project-arcus/issues/234) | Reduce nested Summary surface chrome | gpt-5.4 / medium | HIER-4 | AN-17 |
| 19 | AN-19 | [#235](https://github.com/justinrooks/project-arcus/issues/235) | Move Settings to native Form structure | gpt-5.4 / medium | NAV-2 | AN-04, AN-05, AN-09, AN-15, AN-17 |
| 20 | AN-20 | [#236](https://github.com/justinrooks/project-arcus/issues/236) | Native-align the Alerts list structure | gpt-5.4-mini / high | NAV-2 | AN-01, AN-02, AN-17 |
| 21 | AN-21 | [#237](https://github.com/justinrooks/project-arcus/issues/237) | Native-align the Outlooks list structure | gpt-5.4-mini / high | NAV-2 | AN-09, AN-10, AN-11, AN-17 |
| 22 | AN-22 | [#238](https://github.com/justinrooks/project-arcus/issues/238) | Distinguish map unavailable, stale, and confirmed-empty states | gpt-5.4 / high | MAP-1 | None |
| 23 | AN-23 | [#239](https://github.com/justinrooks/project-arcus/issues/239) | Build the warning legend from rendered warnings | gpt-5.4-mini / high | MAP-2 | AN-22 |
| 24 | AN-24 | [#240](https://github.com/justinrooks/project-arcus/issues/240) | Replace the map layer sheet with a native current-state menu | gpt-5.4 / medium | NATIVE-1 | AN-16, AN-22 |
| 25 | AN-25 | [#241](https://github.com/justinrooks/project-arcus/issues/241) | Add accessible equivalents for map overlays | gpt-5.4 / high | MAP-3 | AN-22, AN-24 |
| 26 | AN-26 | [#242](https://github.com/justinrooks/project-arcus/issues/242) | Reduce map control and legend crowding | gpt-5.4-mini / high | MAP-4 | AN-23, AN-24, AN-25 |
| 27 | AN-27 | [#243](https://github.com/justinrooks/project-arcus/issues/243) | Add a minimal spacing scale during final polish | gpt-5.4-mini / medium | LAYOUT-1 | AN-18, AN-19, AN-20, AN-21, AN-26 |
| 28 | AN-28 | [#244](https://github.com/justinrooks/project-arcus/issues/244) | Run the Apple-native acceptance matrix | gpt-5.4 / medium | All findings | AN-01 through AN-27 |

## Work Item Contracts

### AN-01: Warning-First Alert Presentation

Create one deterministic presentation ordering helper: warning, watch, mesoscale discussion, then temporal tie-breakers.
Use it in Summary and Alerts. Include unit coverage proving a warning cannot be displaced by a watch.

Likely files: `ActiveAlertSummaryView.swift`, `AlertView.swift`, shared alert presentation helper, unit tests.

### AN-02: Alert Detail VoiceOver Content

Remove accessibility labels that replace instruction or summary text. Group headings with full visible content where
needed. Add focused accessibility representation tests if the current test architecture supports them.

Likely files: `AlertDetailView.swift`, alert detail tests or previews.

### AN-03: Native Reliability Rail Actions

Replace the parent tap gesture with a real primary `Button`. Keep `Not Now` as a distinct sibling action and distinct
accessibility element. Preserve visual styling and business behavior.

Likely files: `LocationReliabilitySummaryRailView.swift`, focused tests/previews.

### AN-04: Notification Preference And Authorization

Do not erase stored notification choices when system authorization is denied. Derive effective availability from
authorization and provide an `Open Settings` recovery action.

Likely files: `SettingsView.swift`, notification settings state/helpers, unit tests.

### AN-05: Production Diagnostics Boundary

Remove raw installation ID, APNs token, and H3 identifiers from normal production Settings. Gate diagnostics to debug
builds or expose only an intentional redacted support surface.

Likely files: `SettingsView.swift`, `SettingsDiagnosticsView.swift`, build-configuration tests/previews.

### AN-06: Explicit Launch And Onboarding Routing

Replace competing launch booleans with one item-driven presentation state. Model onboarding steps with an enum and
make buttons authoritative; prevent swipe gestures from bypassing required sequencing.

Likely files: `SkyAwareApp.swift`, `OnboardingView.swift`, launch/onboarding state tests.

### AN-07: Adaptive Onboarding Layout

Make long onboarding content scrollable, scale decorative symbols, and keep the primary action reachable with
`safeAreaInset`. Verify small devices and accessibility Dynamic Type.

Likely files: onboarding step views and previews.

### AN-08: Reduce Motion Coverage

Route onboarding and toast transitions through `SkyAwareMotion`. Under Reduce Motion, use opacity-only or no movement
transitions. Preserve duration and state behavior otherwise.

Likely files: `SkyAwareMotion.swift`, `OnboardingView.swift`, `ToastView.swift`, previews/tests.

### AN-09: User-Facing Vocabulary

Replace subsystem/provider phrasing in Settings, Outlooks, and onboarding with the canonical calm vocabulary in the
audit. Do not remove provenance from detail/legal surfaces where it is useful.

Likely files: `SettingsView.swift`, `ConvectiveOutlookView.swift`, `OnboardingView.swift`, string tests/previews.

### AN-10: Truthful Outlook Metadata

Keep day and valid-until metadata optional through presentation. Omit unknown fields instead of inventing `Day 1` or
reusing publication time.

Likely files: `ConvectiveOutlookDetailView.swift`, presentation model/helpers, unit tests.

### AN-11: Narrative Typography

Use proportional dynamic text styles for full weather narratives. Keep monospaced digits only for compact technical
values, times, identifiers, and measurements.

Likely files: alert, mesoscale discussion, and convective outlook detail views; previews.

### AN-12: Cached Summary While Offline

Keep cached risk, atmosphere, fire, and alert content visible offline. Add quiet freshness/offline treatment and
distinguish stale, resolving, unavailable, and confirmed-empty presentation without changing refresh architecture.

Likely files: risk badges, Summary alert/status components, focused presentation state tests.

### AN-13: Summary Hero Identity And Dynamic Type

Keep persistent `Storm Risk` and `Severe Risk` category labels. Allow hero tiles to grow vertically and wrap important
text at accessibility sizes without flattening the custom tile design.

Likely files: storm/severe badge views, shared text/view modifiers, previews.

### AN-14: Custom Control Semantics

Give hero buttons concise category/value labels, use selected traits for map choices, and give legend rows explicit
layer/level/probability semantics. Avoid replacing useful child content with generic labels.

Likely files: `SummaryView.swift`, map picker and legend views, accessibility tests/previews.

### AN-15: Semantic Color Discipline

Create a small neutral metadata/offline palette. Stop using tornado, wind, hail, fire, or risk colors for certainty,
urgency, Settings headings, or generic state. Preserve actual hazard colors.

Likely files: `AlertStyling.swift`, `WatchStatusChip.swift`, `SummaryStatus.swift`, `SettingsView.swift`, color tests.

### AN-16: Honest Chips And Native Haptics

Remove interactive glass from static metadata/status chips. Replace imperative UIKit haptics in the map picker with
SwiftUI `sensoryFeedback`. Preserve domain-specific chip shapes and labels.

Likely files: `WatchStatusChip.swift`, `ConvectiveOutlookDetailView.swift`, `Picker.swift`, previews.

### AN-17: Opt-In Glass Policy

Change shared card surfaces so glass is explicit rather than the default. Reserve it for navigation, floating map
controls, and selected interactive surfaces. Keep reading and semantic risk surfaces stable.

Likely files: `ext+View.swift`, affected call sites, broad preview/build validation.

### AN-18: Summary Surface Hierarchy

Remove one layer of chrome from Current Conditions or the outer Risk Snapshot. Retain custom risk tiles and rails;
make typography and spacing carry more hierarchy than borders and shadows.

Likely files: `SummaryView.swift`, `SummaryStatus.swift`, shared view modifiers, previews.

### AN-19: Native Settings Structure

Move Settings to `Form` or inset-grouped `List` with native sections, labels, toggles, links, and toolbar behavior.
Preserve SkyAware background/identity and the corrected permission model.

Likely files: `SettingsView.swift`, Settings subviews, UI tests/previews.

### AN-20: Native Alerts Structure

Use native list/section/navigation behavior for Alerts while preserving domain-specific alert rows and warning-first
ordering. Verify swipe, focus, Dynamic Type, and empty states.

Likely files: `AlertView.swift`, alert row components, UI tests/previews.

### AN-21: Native Outlooks Structure

Use native list/section/navigation behavior for Outlooks while preserving risk graphics, provider attribution, and
domain row content. Verify optional metadata and long text.

Likely files: `ConvectiveOutlookView.swift`, row components, UI tests/previews.

### AN-22: Trustworthy Map Availability

Carry availability and freshness into the rendered map scene. Distinguish loading, unavailable, saved/stale, and
successful empty results. Only show `No ... risk` after a successful empty response.

Likely files: `MapFeatureModel.swift`, map scene/state models, `MapLegendView.swift`, deterministic unit tests.

### AN-23: Stateful Warning Legend

Build warning legend rows from warning events currently rendered. If a static reference remains, label it explicitly
as `Warning styles`.

Likely files: `MapScreenView.swift`, `MapLegendView.swift`, warning legend tests/previews.

### AN-24: Native Map Layer Menu

Replace the large single-selection sheet with a `Menu` and `Picker` showing current layer symbol, title, and selected
state. Keep active-warning overlay control available and preserve map semantic imagery.

Likely files: `MapScreenView.swift`, `Picker.swift`, selection tests/previews.

### AN-25: Accessible Map Equivalents

Keep warning controls available at accessibility sizes. Add Differentiate Without Color treatments and an accessible
summary outside `MKMapView` describing the active layer, availability, and local relationship.

Likely files: `Picker.swift`, `RiskPolygonRenderer.swift`, `MapCanvasView.swift`, map accessibility model/tests.

### AN-26: Map Control And Legend Layout

Use compact legend presentation earlier, ensure every control meets 44 by 44 points, use native cancellation toolbar
actions where sheets remain, and verify landscape plus warning-and-layer combinations.

Likely files: `MapScreenView.swift`, `MapLegendView.swift`, `Picker.swift`, previews/UI tests.

### AN-27: Minimal Spacing Scale

Add only a small shared spacing scale based on repeated values confirmed during earlier work. Migrate touched
Apple-native surfaces opportunistically; do not perform a repository-wide token rewrite.

Likely files: a small core spacing type and already-touched feature files.

### AN-28: Acceptance Matrix

Run the final cross-surface verification matrix and fix only regressions introduced by this epic. Confirm canonical
copy, semantic colors, native navigation behavior, Dynamic Type, VoiceOver, Reduce Motion, Differentiate Without
Color, touch targets, small-device layouts, landscape map layouts, dark mode, cached/offline states, and map
availability states.

Likely files: tests/previews/docs plus narrowly scoped regression fixes.

## Validation Baseline

Use the smallest relevant validation for each issue, then run the app build for production Swift changes:

```sh
xcodebuild -project SkyAware.xcodeproj -scheme SkyAware \
  -destination "platform=iOS Simulator,name=iPhone 17" build
```

Where practical, include:

- focused Swift Testing suites for deterministic state and ordering
- previews for light/dark and representative data states
- small iPhone and accessibility Dynamic Type
- VoiceOver inspection for changed semantics
- Reduce Motion and Differentiate Without Color
- landscape for map changes
- screenshots for material, hierarchy, and layout issues

Do not claim validation that did not run.

## Progress Handoff

Before finishing an issue, update `docs/plans/apple-native-ui-alignment-progress.md` with:

- status and date
- files changed
- behavior intentionally preserved
- validation performed and results
- preview/simulator/accessibility states inspected
- deferred work
- risks or discoveries that affect later issues
- whether the next dependency is safe to start
