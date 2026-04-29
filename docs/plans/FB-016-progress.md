# FB-016 Progress Log

## Overview

FB-016 adds a restrained location permission upgrade nudge to SkyAware.

Implementation should proceed one issue at a time under epic `#143 Epic: FB-016 Location Permission Upgrade Nudge`, following `docs/plans/FB-016-issue-runbook.md`.

Primary source of truth:
- `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/Efforts/Notes/FB-016 Location Permission Upgrade Nudge.md`

Related GitHub issues:
- `justinrooks/project-arcus#143` - `Epic: FB-016 Location Permission Upgrade Nudge`
- `justinrooks/project-arcus#144` - `FB-016: Add location reliability model and ask ledger`
- `justinrooks/project-arcus#145` - `FB-016: Expose authorization and accuracy reliability state`
- `justinrooks/project-arcus#146` - `FB-016: Add onboarding Always upgrade branch`
- `justinrooks/project-arcus#147` - `FB-016: Add Settings Alerts / Location Reliability section`
- `justinrooks/project-arcus#148` - `FB-016: Add Summary rail eligibility and rail UI`
- `justinrooks/project-arcus#149` - `FB-016: Add Summary explanation sheet and Always request flow`
- `justinrooks/project-arcus#150` - `FB-016: Add validation coverage for location reliability nudges`

---

## Global Decisions

- The Summary rail is only for current While Using authorization during qualifying elevated risk.
- Qualifying risk includes:
  - storm risk Marginal, Slight, Enhanced, Moderate, or High
  - severe risk Hail or Tornado
- Reduced Accuracy is Settings-only in v1 and does not trigger the Summary rail.
- The Summary rail impression counts as one post-onboarding ask when shown.
- The ask budget is three total asks, lifetime-per-install.
- Permission upgrade/downgrade churn does not reset the ask budget.
- `Not Now` counts against the ask budget and suppresses same-day repeats.
- The next ask requires a later qualifying day and at least 24 hours since the previous counted rail impression.
- The Summary rail opens a lightweight in-app explanation sheet.
- The explanation sheet includes a Current / Recommended status row, `Enable Always`, and `Not Now`.
- The app should use the native Always upgrade prompt when iOS allows it and fall back to system Settings only when needed.
- The onboarding While Using branch is part of v1.
- The onboarding branch does not count toward the post-onboarding ask budget.
- User-facing copy should frame the request around more reliable background severe-weather alerts, not technical location permission mechanics.
- FB-016 is app-only unless a future issue explicitly says otherwise.
- Use GPT-5.3-Codex for implementation sub-issues unless a later issue explicitly becomes visual design exploration.

---

## Current Status

- Epic `#143` and all sub-issues `#144` through `#150` have been created.
- Sub-issues `#144` through `#150` are attached as real GitHub sub-issues under epic `#143`.
- Feature brief includes an issue execution reference map and Codex model guidance.
- Implementation has not started.
- First issue to implement: `#144`.

---

## Issue #144 - Add Location Reliability Model and Ask Ledger

### Status
- Completed

### Scope completed
- Defined a small app-layer `LocationReliabilityState` model with UI-consumable fields for:
  - authorization
  - accuracy
  - recommended state
  - upgrade availability
  - next action
- Added deterministic Summary rail eligibility helpers and decision reasons for:
  - While Using authorization gate
  - elevated-risk gating
  - ask-cap exhaustion
  - same-day suppression
  - next qualifying day rule
  - minimum 24-hour separation between counted impressions
- Included `.slight` in elevated-risk eligibility.
- Added persisted post-onboarding ask ledger state with lightweight preferences storage via a live `UserDefaults.shared` factory path:
  - lifetime-per-install ask count
  - last counted Summary rail impression timestamp
  - last counted qualifying day
  - same-day suppression day
- Kept implementation app-layer/domain-only with no Settings, Summary rail UI, onboarding UI, or direct Core Location prompting changes.

### Relevant feature brief sections
- `Decision`
- `Permission Reliability Model`
- `APIs / Services Impact`
- `Constraints / Invariants`
- `Acceptance Criteria`
- `Done Means`

### Model recommendation
- GPT-5.3-Codex

### Tests
- Added focused unit coverage under `LocationReliabilityTests` for:
  - ask count increments and cap exhaustion
  - same-day suppression
  - next qualifying day + 24-hour minimum gap
  - quiet day behavior
  - `.slight` elevated-risk eligibility

### Verification
- Ran:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2" -only-testing:SkyAwareTests/LocationReliabilityTests test`
- Result:
  - `TEST SUCCEEDED`

### Handoff notes
- Reliability model and ask ledger seams are now available for consumption by:
  - `#145` (authorization + accuracy exposure)
  - `#147` (Settings reliability surface)
  - `#148` (Summary rail eligibility + UI)
  - `#149` (Summary explanation sheet actions)
- `LocationReliabilityAskLedger.live()` is the intended production entry point for shared defaults usage.
- No UI or prompt-flow wiring was added in this slice by design.

---

## Issue #145 - Expose Authorization and Accuracy Reliability State

### Status
- Completed

### Scope completed
- Extended `LocationManager` to expose and refresh `accuracyAuthorization` alongside `authStatus`.
- Updated `LocationSession` to track both authorization and accuracy state and expose a UI-consumable `reliabilityState`.
- Ensured auth + accuracy refresh together when Core Location authorization changes.
- Preserved `requestAlwaysAuthorizationUpgradeIfNeeded()` behavior (native request only from `.authorizedWhenInUse`).
- Preserved existing background mode selection and monitoring behavior.

### Relevant feature brief sections
- `Decision`
- `Permission Reliability Model`
- `Settings: Alerts / Location Reliability`
- `Constraints / Invariants`
- `Dependencies`
- `Done Means`

### Model recommendation
- GPT-5.3-Codex

### Key implementation notes
- Kept Core Location details behind `LocationManager`/`LocationSession` boundaries so feature views can consume reliability state without direct `CLLocationManager` access.
- Added focused reliability mapping tests for authorization + accuracy combinations used by upcoming Settings/Summary work.

### Files changed
- `Sources/Infrastructure/Location/LocationManager.swift`
- `Sources/Infrastructure/Location/LocationSession.swift`
- `Tests/UnitTests/LocationManagerTests.swift`

### Tests
- Added:
  - `LocationReliabilityStateTests` coverage for:
    - While Using + Precise mapping
    - Always + Reduced mapping
    - Missing accuracy -> Unknown mapping
- Updated:
  - `LocationManagerTests` coverage for:
    - authorization-change updates to cached accuracy
    - `LocationSession` reliability state updates from auth+accuracy changes

### Verification
- Ran:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2" -only-testing:SkyAwareTests/LocationManagerTests test`
- Result:
  - `TEST SUCCEEDED`

### Out of scope / intentionally deferred
- Settings Alerts / Location Reliability UI remains in `#147`.
- Summary rail UI and explanation sheet remain in `#148`/`#149`.
- Onboarding branch changes remain in `#146`.

### Handoff to next issue
- `LocationSession.reliabilityState` is now available as the intended app-layer source for Settings/Summary reliability presentation.
- Reduced Accuracy remains Settings-only for v1; no Summary rail behavior was added here.
- Specialist skills:
  - `swift-concurrency-expert` considered applicable and followed for callback/state propagation consistency.
  - `build-ios-apps:swiftui-ui-patterns` not applicable because this issue made no SwiftUI UI changes.

---

## Issue #146 - Add Onboarding Always Upgrade Branch

### Status
- Not Started

### Planned scope
- Replace the current immediate Always re-prompt after While Using with a dedicated explanatory onboarding page.
- Provide `Enable Always` and skip/not-now actions.
- Use reliability-oriented copy about more reliable background severe-weather alerts.
- Preserve notification onboarding and onboarding completion behavior.
- Ensure this branch does not count toward the post-onboarding ask budget.

### Relevant feature brief sections
- `Decision`
- `Target Behavior`
- `Onboarding Branch`
- `Constraints / Invariants`
- `Acceptance Criteria`
- `Done Means`

### Model recommendation
- GPT-5.3-Codex

### Expected verification
- Focused behavior or UI smoke coverage for the onboarding branch.
- Existing first-launch skip path still reaches the main app.

### Handoff notes
- Existing `OnboardingView` already calls `requestAlwaysAuthorizationUpgradeIfNeeded()` immediately after While Using. This issue should replace that behavior, not add a duplicate prompt path.

---

## Issue #147 - Add Settings Alerts / Location Reliability Section

### Status
- Not Started

### Planned scope
- Add an Alerts / Location Reliability section in Settings.
- Display current authorization and accuracy state.
- Show state-specific reliability copy.
- Surface Reduced Accuracy / Precise Location as a Settings concern.
- Offer native Always request when useful and system Settings fallback when needed.
- Ensure viewing Settings does not consume the Summary rail ask budget.

### Relevant feature brief sections
- `Decision`
- `Settings: Alerts / Location Reliability`
- `Target Behavior`
- `Constraints / Invariants`
- `Acceptance Criteria`
- `Done Means`

### Model recommendation
- GPT-5.3-Codex

### Expected verification
- Tests or focused UI validation for Settings state copy and action availability where practical.
- Existing Settings notification/location preference behavior remains stable.

### Handoff notes
- Coordinate with #144 and #145 reliability state.
- Keep user-visible copy non-technical.

---

## Issue #148 - Add Summary Rail Eligibility and Rail UI

### Status
- Not Started

### Planned scope
- Add a compact Summary reliability rail using existing SkyAware rail patterns.
- Compute rail eligibility from reliability state, storm risk, severe threat, and ask ledger state.
- Show only for While Using plus qualifying elevated risk.
- Count a rail impression as an ask.
- Include a clear `Not Now` dismiss affordance.
- Suppress same-day repeats after impression, dismissal, or action.

### Relevant feature brief sections
- `Decision`
- `Target Behavior`
- `Summary Page Rail`
- `Constraints / Invariants`
- `Acceptance Criteria`
- `Done Means`

### Model recommendation
- GPT-5.3-Codex

### Expected verification
- Unit tests for rail eligibility, including `.slight`, hail/tornado severe risk, non-qualifying states, Reduced Accuracy-only, and cap exhaustion.
- Manual or UI validation that the rail fits the Summary layout without disturbing loading states.

### Handoff notes
- Prefer having `HomeView` compute/pass a small rail state and callbacks into `SummaryView`.
- Keep `SummaryView` value-driven.
- Do not implement the full explanation sheet body unless a minimal stub is needed for tap wiring.

---

## Issue #149 - Add Summary Explanation Sheet and Always Request Flow

### Status
- Not Started

### Planned scope
- Add the lightweight in-app explanation sheet opened from the Summary rail.
- Include Current / Recommended status row.
- Include reliability-oriented copy, `Enable Always`, and `Not Now`.
- Wire `Enable Always` to the native Always upgrade path when available.
- Fall back gracefully to system Settings when needed.
- Preserve same-day suppression after action.

### Relevant feature brief sections
- `Decision`
- `Target Behavior`
- `Summary Page Rail`
- `Onboarding Branch`
- `Constraints / Invariants`
- `Acceptance Criteria`
- `Done Means`

### Model recommendation
- GPT-5.3-Codex

### Expected verification
- Tests or UI smoke validation that tapping the rail opens the sheet.
- Validation that `Enable Always` uses the existing request path from While Using.
- Validation that `Not Now` dismisses and preserves suppression.

### Handoff notes
- Keep sheet content focused and app-styled.
- Avoid technical copy.
- Share small local components with onboarding only if it naturally reduces duplication without broadening scope.

---

## Issue #150 - Add Validation Coverage for Location Reliability Nudges

### Status
- Not Started

### Planned scope
- Add final focused tests and validation coverage across the completed FB-016 slices.
- Cover reliability state mapping, Summary rail eligibility, ask ledger behavior, onboarding branch behavior, and Settings/Summary gates.
- Add UI smoke tests only where unit tests cannot prove user-visible behavior cleanly.

### Relevant feature brief sections
- `Acceptance Criteria`
- `Done Means`
- `Constraints / Invariants`
- `Risks / Edge Cases`

### Model recommendation
- GPT-5.3-Codex

### Expected verification
- Focused Swift Testing coverage for deterministic logic.
- Existing onboarding and tab navigation UI tests remain stable.
- No tests depend on live network feeds or real device permission prompts.

### Handoff notes
- Do not broaden this into a full UI test rewrite.
- This issue should close validation gaps left by #144 through #149, not rework completed implementation.

---

## Progress Entry Template

Use this shape when completing each issue:

```markdown
## Issue #NNN - Issue Title

### Status
- Completed

### Scope completed
- Brief sections advanced:
  - ...
- Issue requirements completed:
  - ...

### Key implementation notes
- ...

### Files changed
- ...

### Tests
- Added:
  - ...
- Updated:
  - ...

### Verification
- How to verify:
  1. ...
- Expected result:
  - ...

### Out of scope / intentionally deferred
- ...

### Risks or follow-ups
- ...

### Handoff to next issue
- The next issue should assume:
  - ...
- Watch out for:
  - ...
- Recommended next step:
  - ...
```
