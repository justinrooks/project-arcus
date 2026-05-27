# Resolve-Forward UI Polish Progress

This is the durable handoff ledger for GitHub issues #195 through #201.

Update this file after each issue is implemented. Keep entries factual: what changed, what was validated, what was deliberately left alone, and what the next session should know.

## Current Status

| Order | Issue | Title | Status | Notes |
|---|---:|---|---|---|
| 1 | [#195](https://github.com/justinrooks/project-arcus/issues/195) | Standardize Summary resolving header language | Complete | Secondary status line stabilized to one calm global message with reduced churn. |
| 2 | [#196](https://github.com/justinrooks/project-arcus/issues/196) | Add consistent Summary resolve-forward transition primitives | Complete | Added small shared resolve-forward style primitive and normalized Summary section resolve transitions. |
| 3 | [#197](https://github.com/justinrooks/project-arcus/issues/197) | Polish risk badge resolve-forward transitions | Not started | Prefer after #196. |
| 4 | [#198](https://github.com/justinrooks/project-arcus/issues/198) | Stabilize Local Alerts resolving and empty states | Not started | Prefer after #196. Read `docs/LifecycleInvestigationNotes.md`. |
| 5 | [#199](https://github.com/justinrooks/project-arcus/issues/199) | Smooth Current Conditions resolve-forward updates | Not started | Best after #195. |
| 6 | [#200](https://github.com/justinrooks/project-arcus/issues/200) | Normalize secondary Summary resolving states | Not started | Prefer after #196. |
| 7 | [#201](https://github.com/justinrooks/project-arcus/issues/201) | Align cold-start resolving screen with SkyAware visual direction | Not started | Independent and intentionally last. |

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

## Next Recommended Issue

Start with [#197](https://github.com/justinrooks/project-arcus/issues/197), then [#198](https://github.com/justinrooks/project-arcus/issues/198), then [#200](https://github.com/justinrooks/project-arcus/issues/200).

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
