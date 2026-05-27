# Resolve-Forward UI Polish Progress

This is the durable handoff ledger for GitHub issues #195 through #201.

Update this file after each issue is implemented. Keep entries factual: what changed, what was validated, what was deliberately left alone, and what the next session should know.

## Current Status

| Order | Issue | Title | Status | Notes |
|---|---:|---|---|---|
| 1 | [#195](https://github.com/justinrooks/project-arcus/issues/195) | Standardize Summary resolving header language | Complete | Secondary status line stabilized to one calm global message with reduced churn. |
| 2 | [#196](https://github.com/justinrooks/project-arcus/issues/196) | Add consistent Summary resolve-forward transition primitives | Complete | Added small shared resolve-forward style primitive and normalized Summary section resolve transitions. |
| 3 | [#197](https://github.com/justinrooks/project-arcus/issues/197) | Polish risk badge resolve-forward transitions | Complete | Added badge-local resolve placeholders and calm content crossfades while keeping risk semantics unchanged. |
| 4 | [#198](https://github.com/justinrooks/project-arcus/issues/198) | Stabilize Local Alerts resolving and empty states | Complete | Local Alerts keeps a stable container with inner-state crossfade, clearer copy, and cleaner offline VoiceOver grouping. |
| 5 | [#199](https://github.com/justinrooks/project-arcus/issues/199) | Smooth Current Conditions resolve-forward updates | Complete | Current Conditions now keeps cached weather identity stable while resolve-forward updates settle in place. |
| 6 | [#200](https://github.com/justinrooks/project-arcus/issues/200) | Normalize secondary Summary resolving states | Complete | Fire/Atmosphere/Outlook now use calmer shared resolve-forward language and stable unresolved placeholders. |
| 7 | [#201](https://github.com/justinrooks/project-arcus/issues/201) | Align cold-start resolving screen with SkyAware visual direction | Complete | Cold-start `LoadingView` now uses full-surface atmospheric treatment, calmer hierarchy, and abstract ghost structure without behavior changes. |

## Global Constraints

- Visual representation only.
- Preserve cached-first, resolve-forward behavior.
- Preserve full-screen resolving only for true empty/no-cache startup.
- Do not change data flow, provider behavior, refresh orchestration, refresh timing, persistence, notification behavior, or business logic.
- Do not alter widget code unless a future issue explicitly changes the scope.

## Baseline Audit Artifacts

- Audit drafts: `docs/audits/resolve-forward-ui-polish-issues.md`
- Agent playbook: `docs/plans/resolve-forward-ui-polish-playbook.md`
- Design spec: `docs/SkyAware North Star Spec.md`
- Full design guide: `docs/SkyAware Branding and Design Guide.md`
- Local Alerts prior investigation: `docs/LifecycleInvestigationNotes.md`

## Implementation Log

## Issue #195 - Standardize Summary resolving header language

Status: Complete
Date: 2026-05-27

### Scope Completed

- Updated Summary resolving copy to the preferred calm language family and removed generic "everything ready" phrasing.
- Stabilized the Summary header secondary status line to a single primary active message instead of rotating among concurrent tasks.
- Kept recent-completion messaging subtle and non-repetitive by suppressing completion echo for `.finalizing`.
- Ensured settled condition text reappears as soon as active resolving ends so the header reads as becoming more accurate, not reloading.
- Updated focused unit tests for `SummaryResolutionState` status-message behavior.

### Files Changed

- `Sources/Features/Summary/SummaryResolving.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`

### Behavior Preserved

- Data flow unchanged.
- Provider behavior unchanged.
- Refresh orchestration unchanged.
- Refresh timing unchanged.
- Loading timing unchanged.
- What loads when unchanged.
- Persistence unchanged.
- Business logic unchanged.

### Validation

- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: Success (`** BUILD SUCCEEDED **`).
- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests test`
- Result: Success (`** TEST SUCCEEDED **`).
- xcresult: `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.27_11-10-42--0600.xcresult`
- Screenshots/previews inspected: Not run in this pass.

### Deferred Work

- Manual visual pass in Summary previews and Simulator states (ready/loading/cached refresh/offline/location unavailable/Reduce Motion/larger Dynamic Type) remains for follow-up polish verification.

### Handoff Notes

- #196 should build transition primitives on top of this calmer single-message behavior; avoid reintroducing multi-message rotation in the header.
- `primaryActiveMessage` is now the intended entry point when a single resolving message is needed.

## Issue #196 - Add consistent Summary resolve-forward transition primitives

Status: Complete
Date: 2026-05-27

### Scope Completed

- Refined shared motion constants for resolve-forward polish to reduce heavy dim/blur that could read as disabled.
- Added a narrow Summary-specific resolve-forward style primitive:
  - `SummaryResolveForwardStyle.subtle` for stable-card, inner-content lift with no blur.
  - `SummaryResolveForwardStyle.blurLift` for sections where restrained blur-to-clear still improves clarity.
- Updated `summaryResolving` to use the new style primitive while preserving explicit Reduce Motion handling.
- Applied animated placeholder settling to Summary risk/rail/outlook loading paths to reserve space and reduce abrupt transitions.
- Updated Summary section usage to align with consistent resolve-forward language:
  - Risk badges + Fire rail keep `blurLift`.
  - Atmosphere rail, Local Alerts, and Outlook use `subtle`.

### Files Changed

- `Sources/Utilities/Core/SkyAwareMotion.swift`
- `Sources/Features/Summary/SummaryResolving.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/OutlookSummaryCard.swift`

### New/Refined Transition Primitives

- `SummaryResolveForwardStyle` enum in `SummaryResolving.swift`.
- Refined shared constants in `SkyAwareMotion`:
  - `resolvingBlur` lowered to `1.8`
  - `resolvingOpacity` lifted to `0.90`
  - added `resolvingSubtleOpacity = 0.94`
  - `placeholderOpacity` lifted to `0.90`

### Sections Updated To Use Primitive

- `SummaryView` risk snapshot:
  - Storm Risk badge (`blurLift`)
  - Severe Risk badge (`blurLift`)
  - Fire Risk rail (`blurLift`)
  - Atmospheric rail (`subtle`)
- `ActiveAlertSummaryView` host transition in `SummaryView` (`subtle` while alerts resolve)
- `OutlookSummaryCard` host transition in `SummaryView` (`subtle`)
- `OutlookSummaryCard` placeholder settling set to animated

### Behavior Preserved

- Data flow unchanged.
- Provider behavior unchanged.
- Refresh orchestration unchanged.
- Refresh timing unchanged.
- Loading timing unchanged.
- What loads when unchanged.
- Persistence unchanged.
- Business logic unchanged.
- Section order and interactions unchanged.

### Validation

- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: Success (`** BUILD SUCCEEDED **`).
- Screenshots/previews inspected: Not run in this pass.

### Validation Not Run

- Focused unit tests were not run because no deterministic state/business logic changed.
- Manual simulator state matrix (loaded/partial/cached refresh/offline/Reduce Motion/large Dynamic Type) not run in this pass.

### Deferred Work

- Manual visual QA pass across Summary states and dynamic type sizes to confirm no edge-case layout shift under mixed resolving.
- Optional follow-up adjustment for alert section inner transition intensity if #198 reveals state-specific roughness.

### Handoff Notes

- For #197 (risk badges):
  - Reuse `summaryResolving(..., style: .blurLift)` for badge-level resolve-forward by default; only move to `.subtle` if a specific badge treatment adds too much blur in dark mode.
  - Keep placeholder reservation behavior and avoid introducing spinner-first badge states.
- For #198 (Local Alerts):
  - Treat `style: .subtle` as baseline for resolve-forward while loading/empty/alerts branches swap.
  - Keep container stable and favor content crossfades inside the card; do not shift back to whole-card dimming semantics.
- For #200 (secondary Summary states):
  - Default secondary sections to `style: .subtle` unless a section has clear readability justification for `blurLift`.
  - Reuse animated placeholders where skeleton text is already present to minimize layout jumps.

## Issue #197 - Polish risk badge resolve-forward transitions

Status: Complete
Date: 2026-05-27

### Scope Completed

- Replaced risk-badge unresolved placeholder redaction with explicit in-badge resolve-forward placeholder content so unresolved state no longer reads like confirmed `All Clear`.
- Kept Storm Risk and Severe Risk structurally parallel with the same state model:
  - `offline` (existing offline card, unchanged),
  - `resolving placeholder` (neutral badge surface + resolving copy),
  - `resolved` (semantic risk colors + normal risk copy).
- Added calm, non-dramatic content crossfades for icon/message/summary updates in both badges to smooth cached → freshly resolved changes.
- Updated Summary risk badge host behavior to:
  - pass explicit resolving/placeholder flags into both badges,
  - use `.summaryResolving(..., style: .subtle)` for already-resolved badge refreshes,
  - avoid extra whole-badge dim/blur during unresolved placeholder phase.
- Added preview rows in both badge files to exercise resolving placeholder and resolving-with-data states.

### Files Changed

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`

### How Badge Resolving Works Now

- Missing risk data while online shows a neutral, stable badge with resolving language (`Resolving/Refining ...`) instead of fallback semantic risk values.
- Once data is present, badges transition into semantic risk content with gentle content opacity transitions.
- While fresh data continues to resolve on already-populated badges, Summary applies the #196 resolve-forward primitive in `.subtle` mode so badges feel active, not disabled.

### Behavior Preserved

- Risk scoring unchanged.
- Risk mapping unchanged.
- Map layer selection unchanged.
- Provider behavior unchanged.
- Refresh orchestration unchanged.
- Refresh timing unchanged.
- Loading timing unchanged.
- What loads when unchanged.
- Persistence unchanged.
- Business logic unchanged.
- Existing badge tap behavior and accessibility hints unchanged.
- Semantic risk colors unchanged for resolved states.
- Offline badge state remains distinct from resolving state.

### Validation

- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: Success (`** BUILD SUCCEEDED **`).
- Previews updated for resolving paths in both badge components.

### Validation Not Run

- Focused tests not run because no scoring, mapping, provider, orchestration, or deterministic helper logic changed.
- Manual simulator visual matrix not run in this pass:
  - unresolved → resolved
  - cached → refreshed
  - offline cards
  - light/dark
  - Reduce Motion
  - larger Dynamic Type stacked hero tiles

### Deferred Work

- Manual before/after screenshot capture for Summary hero area across the full visual matrix listed above.

### Handoff Notes

- For #198 and #200:
  - Keep using `SummaryResolveForwardStyle.subtle` as the default when content is already present and refining.
  - Prefer section-local resolving placeholders over fallback semantic content + heavy redaction when unresolved state could imply a false calm.
  - If additional resolve-forward placeholders are added elsewhere, match this badge pattern: neutral surface, stable dimensions, concise progressive language, and restrained transitions.

## Issue #198 - Stabilize Local Alerts resolving and empty states

Status: Complete
Date: 2026-05-27

### Scope Completed

- Kept `ActiveAlertSummaryView` as the single Local Alerts presentation container and preserved its existing explicit content states (`loading`, `empty`, `alerts`, `offline`).
- Stabilized inner-state transition rendering by routing state swaps through a dedicated `contentStateContainer` `ZStack` so only the content region crossfades while the card container stays visually stable.
- Preserved and clarified resolve-forward tone with distinct checking vs no-alert states:
  - checking: `Checking local alerts` + `Bringing in local alerts…`
  - empty: `No Active Alerts` + calm explanatory copy
- Fixed user-facing copy defect in alert section label: `Watches & Warningso` -> `Watches & Warnings`.
- Improved VoiceOver grouping for offline state by combining label + message into a single accessibility element, matching the loading/empty treatment.

### Files Changed

- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `docs/plans/resolve-forward-ui-polish-progress.md`

### Behavior Preserved

- Alert ingestion unchanged.
- Arcus/SPC/NWS orchestration unchanged.
- Alert sorting/filtering unchanged.
- Refresh timing unchanged.
- Loading timing unchanged.
- What loads when unchanged.
- Notification behavior unchanged.
- Persistence unchanged.
- Business logic unchanged.
- Existing alert row interactions, detail sheets, and Alert Center navigation behavior unchanged.
- Offline-vs-cached alert behavior unchanged.

### Validation

- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: Success (`** BUILD SUCCEEDED **`).
- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -only-testing:SkyAwareTests/HomeViewLoadingOverlayStateTests test`
- Result: Success (`** TEST SUCCEEDED **`).
- xcresult: `/Users/justin/Library/Developer/Xcode/DerivedData/SkyAware-agjazkpfcnuppmaofanownrwirhh/Logs/Test/Test-SkyAware-2026.05.27_11-33-05--0600.xcresult`

### Validation Not Run

- Manual simulator visual matrix for all requested Local Alerts states (checking, no-alert, watches-only, mesos-only, mixed, offline, location unavailable, cached refresh), Reduce Motion, larger Dynamic Type, and VoiceOver playback was not run in this pass.

### Deferred Work

- Perform a manual visual QA pass across the Local Alerts state matrix to confirm transition feel under real runtime state changes (especially empty -> populated with multiple rows and dynamic type edge sizes).

### Handoff Notes

- For #200, reuse the same section pattern used here:
  - keep a stable outer card/container;
  - transition only inner state content;
  - avoid additional whole-card dimming when a section already has an explicit resolving state.

## Review Fix - [P2] Local Alerts collapses before fade completes

Status: Complete
Date: 2026-05-27

### Finding Fixed

- Fixed Local Alerts content-height snapping when transitioning away from populated alerts so outgoing rows can complete the intended fade without abrupt clipping/cropping.

### Files Changed

- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `docs/plans/resolve-forward-ui-polish-progress.md`

### Behavior Preserved

- Alert ingestion unchanged.
- Arcus/SPC/NWS orchestration unchanged.
- Alert sorting/filtering unchanged.
- Refresh/loading timing unchanged.
- What loads when unchanged.
- Notification behavior unchanged.
- Persistence unchanged.
- Business logic unchanged.
- Existing loading/empty/alerts/offline state semantics unchanged.
- Alert Center button behavior unchanged.
- VoiceOver grouping unchanged.

### Validation

- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: Success (`** BUILD SUCCEEDED **`).

### Visual Validation

- Manual simulator visual validation: Not run in this pass.

### Remaining Risks

- The transition-height hold duration tracks the current Local Alerts layer-change timing (`0.32s`, `0.01s` with Reduce Motion). If motion timing changes later, this duration should be updated to stay aligned.

## Issue #199 - Smooth Current Conditions resolve-forward updates

Status: Complete
Date: 2026-05-27

### Scope Completed

- Kept Current Conditions anchored on location while weather refines by caching the last resolved weather payload for visual continuity during active resolve-forward refreshes.
- Stabilized temperature/icon rendering when weather is temporarily missing by reserving a constant footprint and using calm value/icon transitions instead of abrupt disappear/reappear behavior.
- Prevented settled condition-line flicker/collapse during active refresh by continuing to display the last known condition text with subtle de-emphasis while resolving.
- Tightened long placemark behavior in compact/condensed layouts by forcing one-line truncation for non-stacked hero layout and preserving two-line support only in stacked Dynamic Type layouts.
- Preserved existing offline token UI, popover behavior, and header condense motion.

### Files Changed

- `Sources/Features/Summary/SummaryStatus.swift`
- `docs/plans/resolve-forward-ui-polish-progress.md`

### Behavior Preserved

- WeatherKit fetching unchanged.
- Location resolution unchanged.
- Provider behavior unchanged.
- Refresh orchestration unchanged.
- Refresh timing unchanged.
- Loading timing unchanged.
- What loads when unchanged.
- Persistence unchanged.
- Business logic unchanged.
- Offline token interaction and copy unchanged.
- Condensing header behavior unchanged.

### Validation

- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: Success (`** BUILD SUCCEEDED **`).

### Validation Not Run

- Focused tests not run because no deterministic helper/business logic changed.
- Manual Simulator/previews matrix not run in this pass (ready, missing weather -> resolved, cached refresh, offline token, location unavailable, long placemark, light/dark, Reduce Motion, larger Dynamic Type).

### Deferred Work

- Manual visual QA pass across the full Current Conditions state matrix, especially compact-width long placemark + offline token and large Dynamic Type stacked layouts.

### Handoff Notes

- #200 can reuse the same approach used here for secondary/status surfaces: keep stable container geometry, avoid hiding settled text just because background resolve is active, and prefer gentle de-emphasis over collapse.
- If secondary sections need freshness copy later, keep it neutral and scoped (for example using existing per-section timestamps only) rather than broad cross-section `Updated` language.

## Issue #200 - Normalize secondary Summary resolving states

Status: Complete
Date: 2026-05-27

### Scope Completed

- Normalized Fire Risk unresolved behavior to use an explicit, calm resolve-forward placeholder rail instead of redacting a semantic `No Fire Risk` fallback.
- Kept Fire Risk offline treatment distinct and preserved fire semantic colors for resolved states.
- Updated Atmospheric Conditions unresolved copy to calm resolve-forward language and removed generic loading phrasing.
- Updated Outlook Summary unresolved/pending language to user-facing resolve-forward phrasing and removed sync-mechanic wording.
- Kept Outlook header stable as `Outlook Summary` across pending/resolved states to reduce visual churn.
- Added focused Outlook and Fire previews for unresolved states to support visual verification paths.
- Aligned secondary section transitions with existing #196 pattern by keeping Fire resolve-forward host treatment subtle when data already exists.

### Files Changed

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Badges/FireWeatherRailView.swift`
- `Sources/Features/Badges/AtmosphereRailView.swift`
- `Sources/Features/Summary/OutlookSummaryCard.swift`

### How Secondary Resolving States Work Now

- Fire Risk:
  - offline: existing offline card remains unchanged and distinct;
  - unresolved online: neutral resolving rail with stable height/copy;
  - resolved: existing semantic fire-risk rail.
- Atmospheric Conditions:
  - unresolved online: same rail layout and metric footprint with calm resolve-forward copy;
  - offline: existing offline card unchanged and distinct.
- Outlook Summary:
  - unresolved initial/pending states now describe local resolve-forward progress without provider/sync language;
  - title remains stable while body text resolves into live summary when available.

### Behavior Preserved

- Fire risk logic unchanged.
- WeatherKit fetching unchanged.
- Outlook sync behavior unchanged.
- Provider behavior unchanged.
- Refresh orchestration unchanged.
- Refresh timing unchanged.
- Loading timing unchanged.
- What loads when unchanged.
- Persistence unchanged.
- Business logic unchanged.
- Existing tap/navigation behavior unchanged.

### Validation

- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: Success (`** BUILD SUCCEEDED **`).

### Validation Not Run

- Focused tests were not run because no deterministic helper/business logic changed.
- Manual Simulator/previews matrix across light/dark, Reduce Motion, and larger Dynamic Type states was not run in this pass.

### Deferred Work

- Manual visual QA for the full requested matrix:
  - Fire unresolved/resolved/offline
  - Atmosphere unresolved/resolved/offline
  - Outlook missing/loading/pending/resolved
  - cached refresh behavior
  - light/dark, Reduce Motion, larger Dynamic Type

## Review Fix - [P1] Missing risk data after completed local-data attempt appears indefinitely resolving

Status: Complete
Date: 2026-05-27

### Finding Fixed

- Resolved the risk-placeholder gating bug where `stormRisk`, `severeRisk`, or `fireRisk` being `nil` always showed resolving copy, even after local-data completion and Summary readiness.

### Files Changed

- `Sources/Features/Summary/SummaryView.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`

### Behavior Preserved

- Risk scoring unchanged.
- Risk mapping unchanged.
- Provider behavior unchanged.
- Refresh orchestration/timing unchanged.
- Loading timing unchanged.
- What loads when unchanged.
- Persistence unchanged.
- Business logic unchanged.
- Offline behavior preserved.
- Map tap behavior preserved.

### Validation Run

- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -only-testing:SkyAwareTests/SummaryViewRiskPlaceholderPresentationTests test`

### Remaining Risks

- Visual nuance for ready-with-missing-risk fallback relies on existing safe fallback values (`.allClear` / `.clear`) without an explicit "data unavailable" affordance; this preserves current product semantics but should be reviewed in UI QA for trust/readability.

### Handoff Notes

- For #201 cold-start resolving:
  - Reuse this issue’s calm secondary language conventions (resolve-forward, user-facing, no sync/system phrasing).
  - Preserve stable titles/surfaces during resolving where possible so the cold-start view feels like the same visual system, not a separate loading mode.

## Issue #201 - Align cold-start resolving screen with SkyAware visual direction

Status: Complete
Date: 2026-05-27

### Scope Completed

- Reworked cold-start `LoadingView` visual treatment to a full-surface atmospheric blue base that matches the newer Summary/widget-era SkyAware visual direction.
- Shifted loading hierarchy to typography-first messaging with calm, user-facing resolve-forward copy and no generic loading/system language.
- Replaced the old icon-centric ghost stack with a more abstract structural ghost composition so unresolved context reads as atmospheric structure, not fake loaded data.
- Kept motion low-frequency and atmospheric (subtle glow drift + pulse) with explicit Reduce Motion static fallback.
- Added focused `LoadingView` previews for dark mode and Reduce Motion inspection.

### Files Changed

- `Sources/Features/Loading/LoadingView.swift`
- `docs/plans/resolve-forward-ui-polish-progress.md`

### Behavior Preserved

- `LoadingView` appearance gating unchanged (still true empty/no-cache startup only).
- Cached-first Summary bypass behavior unchanged.
- Data flow unchanged.
- Provider behavior unchanged.
- Refresh orchestration unchanged.
- Refresh timing unchanged.
- Loading timing unchanged.
- What loads when unchanged.
- Persistence unchanged.
- Business logic unchanged.
- Widget code unchanged.

### Validation

- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: Success (`** BUILD SUCCEEDED **`).
- Previews updated/available for:
  - light mode
  - dark mode
  - Reduce Motion

### Validation Not Run

- Manual true no-cache and cached-launch simulator walkthrough was not run in this pass.
- Manual transition walkthrough from cold-start resolving into Summary was not run in this pass.
- Manual larger Dynamic Type simulator pass was not run in this pass.

### Remaining Visual Risks / Final Polish Notes

- The atmospheric ghost abstraction is intentionally less data-like; final tuning may still benefit from screenshot review on-device to ensure the blur level is neither too soft in dark mode nor too bright in light mode.
- If future polish wants further consistency with Summary surfaces, adjust only visual constants inside `LoadingView`; do not expand full-screen loading to cached starts.

### Final Handoff Summary (#195-#201)

- The complete #195-#201 sequence is now implemented as scoped visual polish while preserving cached-first, resolve-forward architecture and behavior.
- Summary resolving language, transition primitives, hero badges, local alerts, current conditions, secondary sections, and cold-start empty-state visuals now present a calmer, more coherent, typography-led system.
- No issue in this sequence changed providers, orchestration, timing, persistence, or business logic.

## Review Fix - P1 stale cross-location weather during resolve-forward

Status: Complete
Date: 2026-05-27

### Finding Fixed

- Prevented stale cached weather from being shown when Summary location context changes while weather is temporarily unresolved during an active refresh.

### Files Changed

- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Tests/UnitTests/SummaryStatusWeatherRetentionTests.swift`
- `docs/plans/resolve-forward-ui-polish-progress.md`

### Behavior Preserved

- Same-location resolve-forward smoothing remains: cached Current Conditions can remain visible while fresh weather resolves.
- WeatherKit fetching unchanged.
- Location resolution unchanged.
- Provider behavior unchanged.
- Refresh orchestration unchanged.
- Refresh timing unchanged.
- Loading timing unchanged.
- What loads when unchanged.
- Persistence unchanged.
- Business logic unchanged.

### Validation

- Ran focused tests for the new deterministic retention helper.
- Ran required build:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

### Remaining Risks

- Identity uses quantized coordinates + placemark summary from `LocationSnapshot`; if future requirements decouple displayed placemark from snapshot identity, this guard may need to align with a different canonical context key.

## Handoff Template

Copy this section when completing an issue.

```md
## Issue #NNN - Title

Status: Complete / Partial / Blocked
Date: YYYY-MM-DD

### Scope Completed

- ...

### Files Changed

- `path/to/file.swift`

### Behavior Preserved

- Data flow unchanged.
- Provider behavior unchanged.
- Refresh timing unchanged.
- Business logic unchanged.

### Validation

- Ran: `...`
- Result: ...
- Screenshots/previews inspected: ...
- Not run: ... because ...

### Deferred Work

- ...

### Handoff Notes

- ...
```

## Final Taste-Polish Handoff - Resolve-Forward Summary + Cold Start

Status: Complete
Date: 2026-05-27

### Notes Addressed

- Reduced cold-start `LoadingView` visual mass by lowering the fixed minimum height (`560` -> `500`) while preserving full-surface presentation and existing appearance gating.
- Removed the cold-start material mini-card treatment and shifted to typography-led integrated messaging over the atmospheric surface to avoid card-on-card feel.
- Updated remaining user-facing resolve-forward copy on Summary/risk/secondary surfaces to the canonical family:
  - `Getting storm risk…`
  - `Getting severe risk…`
  - `Getting fire risk…`
  - `Getting outlook details…`
  - `Getting atmospheric details…`
- Replaced user-facing `server is offline` strings on Summary-adjacent surfaces with connection-return language centered on saved local data.
- Tuned unresolved risk placeholder backgrounds (Storm/Severe/Fire) from neutral gray-white into restrained atmospheric blue/slate gradients to feel integrated without implying resolved risk semantics.
- Restored limited specificity for recent completion status (`Updated conditions`, `Got storm risk`, `Checked local alerts`) while preserving prior churn controls and timing window.
- Kept the hidden `00°` weather-width placeholder and explicitly marked both hidden placeholder elements as `accessibilityHidden(true)` to prevent leakage.
- Renamed the `LoadingView` Reduce Motion preview to avoid claiming behavior that cannot be forced via a writable environment key in this toolchain (`Reduce Motion (Name Only)`).

### Notes Intentionally Left Unchanged

- `LoadingView` still uses a minimum height floor (now lower) instead of fully dynamic geometry math to keep launch layout stable and avoid introducing additional complexity/risk in this polish-only pass.

### Files Changed

- `Sources/Features/Loading/LoadingView.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/SummaryResolving.swift`
- `Sources/Features/Summary/OutlookSummaryCard.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`
- `Sources/Features/Badges/FireWeatherRailView.swift`
- `Sources/Features/Badges/AtmosphereRailView.swift`
- `docs/plans/resolve-forward-ui-polish-progress.md`

### Validation Run

- Ran string-level inspection for targeted copy regressions:
  - no remaining user-facing `server is offline` strings in Summary/loading/risk/secondary surfaces
  - no remaining user-facing `Resolving`/`Refining` language in those surfaces
- Ran: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Result: Success (`** BUILD SUCCEEDED **`).

### Remaining Risks

- Visual tone and spacing for the lighter-weight cold-start message region still needs final simulator eyes-on across smallest iPhone heights, dark mode, and large Dynamic Type to confirm perceived balance after lowering minimum height.
