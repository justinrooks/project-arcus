# Storm Setup Summary Stability Progress

## Overview

This ledger tracks the campaign to keep the Today Storm Setup section stable whenever the feature is enabled and to
replace its redacted full-card placeholder with compact, truthful status presentations.

**Epic status:** Planned

**Primary GitHub epic:** [#411](https://github.com/justinrooks/project-arcus/issues/411)

## Global Decisions

- The main Storm Setup switch becomes the section-visibility opt-in.
- Only switch-off or unavailable location removes the section.
- Background outcomes change content within the stable section.
- Fresh displayable cached content remains visible during refresh.
- Detailed Ingredients retains its current stored/effective semantics and refresh trigger.
- Status states distinguish analyzing, no notable setup, analysis not needed, and unavailable.
- Expired guidance is never shown for visual continuity.
- Existing fetch/display policy remains authoritative.
- No AQI publication, ingestion, persistence, endpoint, Settings-layout, or Atmospheric Conditions work belongs here.
- Every child issue targets `gpt-5.6-terra` with medium reasoning; no campaign issue requires Sol.

## Current State Summary

Today currently reserves `.stormSetup` only for loading and visible content. With Storm Setup enabled and no selected
payload, any Home refresh produces a full-sized placeholder whose fake title, prose, ingredient rows, and source line
are redacted. A fresh displayable cache stays visible during refresh. When refresh completes without displayable data,
the section disappears.

The loading predicate is global `isRefreshInFlight`, not Storm Setup-specific. The UI already has the policy inputs
needed to distinguish request eligibility and fresh-but-suppressed results without changing ingestion. Enabling Storm
Setup or enabling Detailed Ingredients while Storm Setup is on schedules a refresh; disabling immediately suppresses
presentation and does not schedule a compensating request.

Closed predecessor #322 stabilized loading-to-visible section identity while preserving conditional hiding. This
campaign changes the enabled-state visibility contract and therefore does not duplicate #322.

## Issue Sequence

| Order | Issue | Title | Recommended model | Status | Dependency |
| ---: | --- | --- | --- | --- | --- |
| 0 | [#411](https://github.com/justinrooks/project-arcus/issues/411) | Epic: Stabilize the Today Storm Setup section | Coordination only | Planned | None |
| 1 | [#412](https://github.com/justinrooks/project-arcus/issues/412) | 01: Define the stable Storm Setup summary-state contract | `gpt-5.6-terra` / medium | Planned | Epic |
| 2 | [#413](https://github.com/justinrooks/project-arcus/issues/413) | 02: Render compact enabled Storm Setup states on Today | `gpt-5.6-terra` / medium | Planned | #412 |
| 3 | [#414](https://github.com/justinrooks/project-arcus/issues/414) | 03: Verify Storm Setup settings transitions and accessibility | `gpt-5.6-terra` / medium | Planned | #413 |

## Existing Code Map

- Settings storage/UI: `Sources/Features/Settings/SettingsView.swift`
- Settings observation/refresh: `Sources/App/HomeView.swift`
- Settings transition policy: `Sources/App/HomeView+PresentationState.swift`
- Fetch/show policy: `Sources/Models/StormSetup/StormSetupPreferences.swift`
- Summary state/composition: `Sources/Features/Summary/SummaryView.swift`
- Summary presentation contract: `Sources/Features/StormSetup/StormSetupPresentation.swift`
- Summary card: `Sources/Features/StormSetup/StormSetupSummaryCard.swift`
- State/section tests: `Tests/UnitTests/SummaryViewLoadingStateTests.swift` and
  `Tests/UnitTests/SummarySectionPlanTests.swift`
- Settings tests: `Tests/UnitTests/HomeViewStateTests.swift`
- UI fixture/coverage: `Sources/App/SkyAwareApp.swift` and `Tests/UITests/SkyAwareUITests.swift`

## Investigation Notes

- `StormSetupSummaryCard` applies `.placeholder` to its complete content subtree, including the visible section label.
- The placeholder is redaction plus opacity animation, not progressive field loading.
- `SummaryView.stormSetupSlotState` returns loading whenever the feature is enabled, data is absent, location is usable,
  and the global Home refresh is active.
- Existing unexpired selected content remains full and navigable while refresh is active.
- A present unexpired payload that display policy suppresses is currently hidden rather than treated as loading.
- Storm Setup and AQI are published as joined optional enrichment; decoupling them is a separate concurrency campaign.
- The five-second foreground timeout and all cache/backoff behavior are outside this campaign.
- Existing UI coverage for disabling Storm Setup across tabs is commented out and must not be revived blindly; issue 03
  should use the smallest deterministic seam that proves the new contract.

## Status Ledger

### Issue #412 — 01: Define the stable Storm Setup summary-state contract

- Status: Awaiting human review
- Goal: Define one pure state matrix that makes every enabled terminal state explicit without changing runtime UI.
- Expected files: Storm Setup presentation/state policy and focused unit tests.
- Handoff: Added a pure `StormSetupSummaryState` selector covering hidden, analyzing, guidance, no-notable-setup,
  analysis-not-needed, and unavailable outcomes. DEBUG force display bypasses only the feature switch, never location
  unavailability. Runtime rendering remains unchanged.

### Issue #413 — 02: Render compact enabled Storm Setup states on Today

- Status: Planned
- Goal: Render the contract in the stable `.stormSetup` section and remove the redacted full-card loading state.
- Expected files: Summary composition, Storm Setup card rendering, previews, and focused state/section tests.
- Handoff: Pending issue 01.

### Issue #414 — 03: Verify Storm Setup settings transitions and accessibility

- Status: Planned
- Goal: Prove main-switch, Detailed Ingredients, cache-refresh, Dynamic Type, VoiceOver, appearance, and Reduce Motion
  behavior with deterministic evidence.
- Expected files: Existing test fixtures and UI/unit coverage; production behavior changes are forbidden.
- Handoff: Pending issue 02.

## Verification Ledger

| Issue | Focused tests | Debug build | Full unit lane | UI/accessibility evidence | Result bundle |
| --- | --- | --- | --- | --- | --- |
| 01 | 22 passed, 0 failed, 0 skipped | Compiled in focused Debug test lane | Deferred to issue 02 | Not required | `skyaware-results.2vqC6y/unit.xcresult` |
| 02 | Pending | Required | Required | Preview/render review | Pending |
| 03 | Pending | Required if test support changes | Required | Required | Pending |

## Handoff Notes

- Execute one issue at a time and stop for human review.
- Update only the active issue ledger and verification row.
- Record changed files, behavior, exact executed/passed/failed/skipped counts, `.xcresult` path, and residual risk.
- Do not mark completion from process exit status or `** TEST SUCCEEDED **` alone.
- Stop and re-plan if any issue requires ingestion/publication changes, expired-data display, Settings redesign, or more
  than five production files.
