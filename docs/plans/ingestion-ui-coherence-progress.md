# Ingestion UI Coherence Progress

## Overview

Tracks a consistent cache-forward loading, refresh, transition, accessibility, and evidence campaign across Home, Alerts, Outlook, Map, and details.

**Epic status:** Planned
**Primary GitHub epic:** [#422](https://github.com/justinrooks/project-arcus/issues/422)

## Global Decisions

- Preserve useful cached content during every attempt and failure.
- Activity is shown around content; it does not replace content.
- UI derives truth from accepted cache contracts.
- Motion is local, value-scoped, optional, and Reduce Motion aware.
- Completed Today issue #253 is precedent, not scope to redo.
- No Liquid Glass or global animation-framework campaign.
- All implementation uses `GPT-5.6 Terra / medium`.

## Current State

Home combines SwiftData and pipeline state, while feature tabs use differing loading, empty, stale, and failure semantics. Map can clear or lag during reload. Existing Today motion cleanup is narrower than the desired cross-feature contract.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#453](https://github.com/justinrooks/project-arcus/issues/453) — Define atomic visible-revision contract | Ready for commit | Cache acceptance contract |
| 2 | [#458](https://github.com/justinrooks/project-arcus/issues/458) — Introduce focused Home presentation-state derivation | Ready for commit | 01 and persistence gating |
| 3 | [#449](https://github.com/justinrooks/project-arcus/issues/449) — Stabilize Today cache-to-refresh transitions | Pending | 02 and keyed Home observation |
| 4 | [#457](https://github.com/justinrooks/project-arcus/issues/457) — Unify refresh affordances and status feedback | Pending | 01 |
| 5 | [#454](https://github.com/justinrooks/project-arcus/issues/454) — Normalize Alerts and Outlook loading states | Pending | 01 and typed feed outcomes |
| 6 | [#459](https://github.com/justinrooks/project-arcus/issues/459) — Refine map loading and accepted-generation transitions | Pending | Reactive map invalidation |
| 7 | [#462](https://github.com/justinrooks/project-arcus/issues/462) — Codify restrained cross-feature motion | Pending | 01; may begin early |
| 8 | [#463](https://github.com/justinrooks/project-arcus/issues/463) — Refine cached-detail navigation transitions | Pending | Reactive detail decision |
| 9 | [#461](https://github.com/justinrooks/project-arcus/issues/461) — Add a presentation-state preview matrix | Pending | 02–08 incrementally |
| 10 | [#460](https://github.com/justinrooks/project-arcus/issues/460) — Validate accessibility, hitches, and transition behavior | Pending | Implemented UI scope |

## Existing Code Map

- Home orchestration/presentation: `Sources/App/HomeView.swift`, `Sources/App/HomeRefreshPipeline.swift`
- Today composition: `Sources/App/TodayTabView.swift`, Summary feature views
- Alerts/Outlook: corresponding feature views and presentation-state types
- Map: `Sources/Features/Map/MapScreenView.swift`, `Sources/Features/Map/MapFeatureModel.swift`
- Product guidance: `docs/SkyAware North Star Spec.md`

## Status Ledger

### [#453](https://github.com/justinrooks/project-arcus/issues/453) — Define atomic visible-revision contract
- Status: Ready for commit after human review, independent review, and focused/full unit validation.
- Contract: `HomeVisiblePresentation` owns one location-scoped `HomeVisibleRevision`. Its core fields come
  solely from an accepted persisted `HomeProjectionRecord`; refresh source, activity, and failure are
  separate metadata. The view may render a retained revision with failure/offline/unavailable status.
- Promotion: a `commitCore` acknowledgement may promote core only when that commit accepted weather
  or slow products. A hot-alert-only prime may update accepted alerts, but cannot certify weather,
  storm, severe, or fire risk. Accepted enrichment may update AQI/Storm Setup only and cannot change
  the core risk/weather fields. Progress and rejected or failed candidates never promote content.
- Context: compare the record's projection key to the currently presented location before promotion.
  A different key clears the visible revision immediately; late old-context results are ignored.
  A persisted fallback is eligible only when no revision is displayed, for that same key, and with
  a core acceptance timestamp. Older same-key accepted commits cannot replace a newer core.
  Refresh lifecycle events carry both an attempt ID and their location key, so superseded attempts
  cannot change a new context's activity or outcome. Without a resolved context, no prior location's
  risk is treated as current.
- Persistence availability is location-scoped and separate from accepted content. A successful
  same-key read may clear an unavailable status without replacing the accepted core revision.
- Empty: nil core values count as authoritative empty only after weather, slow-product, and alert
  acceptance markers exist. An absent record or missing markers remain unresolved; failure is a
  separate outcome. Optional enrichment does not participate in core emptiness.
- Handoff: #458 should derive this state from keyed repository observations; #449 should route the
  executor's accepted publication through the same persistence authority. Neither should feed
  transient pipeline risk/weather values directly into the visible revision.

### [#458](https://github.com/justinrooks/project-arcus/issues/458) — Introduce focused Home presentation-state derivation
- Status: Ready for commit after human review of the corrected change.
- Home derives one visible core revision from the keyed accepted projection. Same-context observation gaps
  retain the prior accepted revision; a different context clears it. Hot-alert and optional-enrichment
  writes may advance only their sections, while refresh/activity metadata remains separate. Transient
  pipeline risk and weather values no longer arbitrate production Home content.
- Independent review found that the first warm revision was rendered before it was retained. The
  observation now seeds that revision on initial render; a hosted regression test covers the first
  same-context gap and subsequent location-key change. The reviewer confirmed the correction, and
  human review is complete. The user reports tests passing; no newer result bundle was available
  locally, so the verification ledger below remains the inspectable evidence.

### [#449](https://github.com/justinrooks/project-arcus/issues/449) — Stabilize Today cache-to-refresh transitions
- Status: Pending
- Handoff: Do not duplicate completed issue #253 without regression evidence.

### [#457](https://github.com/justinrooks/project-arcus/issues/457) — Unify refresh affordances and status feedback
- Status: Pending

### [#454](https://github.com/justinrooks/project-arcus/issues/454) — Normalize Alerts and Outlook loading states
- Status: Pending

### [#459](https://github.com/justinrooks/project-arcus/issues/459) — Refine map loading and accepted-generation transitions
- Status: Pending

### [#462](https://github.com/justinrooks/project-arcus/issues/462) — Codify restrained cross-feature motion
- Status: Pending

### [#463](https://github.com/justinrooks/project-arcus/issues/463) — Refine cached-detail navigation transitions
- Status: Pending

### [#461](https://github.com/justinrooks/project-arcus/issues/461) — Add a presentation-state preview matrix
- Status: Pending

### [#460](https://github.com/justinrooks/project-arcus/issues/460) — Validate accessibility, hitches, and transition behavior
- Status: Pending validation gate

## Verification Ledger

- #458 corrected focused Home suites finalized at
  `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.mPbqQj/unit.xcresult`:
  15 test cases and 18 parameterized executions passed, 0 failures or skips. The corrected Debug
  iPhone 17 simulator build and `git diff --check` passed.
- The corrected selected navigation smoke finalized at
  `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.d35ZwC/ui-navigation.xcresult`:
  1 executed, 0 passed, 1 failed, 0 skipped. Its failure reports a
  `SkyAwareWidgetsExtension` startup crash in `_EXRunningExtension._start` before navigation
  assertions. The pre-correction navigation result at
  `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.qYzpbk/ui-navigation.xcresult`
  passed 1/1 but is not evidence for the corrected source.
- The pre-correction full #458 unit lane finalized at
  `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.ZWKqVy/unit.xcresult`:
  1,201 test cases, 1,173 passed, 28 failed, 0 skipped. All 28 failures report a single runner
  crash in `HomeProjectionStoreScalingMeasurementTests.fetchProjections(from:)` during a Core Data
  SQLite fetch; this lane is not passing evidence for the corrected source.
- #453 final focused Swift Testing suite:
  `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/HomeVisibleRevisionTests`;
  finalized Debug iPhone 17 (iOS 26.5) result at
  `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.dhj9JS/unit.xcresult`.
  Passed: 9 test cases, 12 parameterized executions, 0 failures or skips.
- Complete unit lane finalized at
  `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.L9ZqMu/unit.xcresult`:
  1,195 test cases and 1,230 parameterized executions passed, 0 failures or skips.
- Selected `SkyAwareUITests.testTabNavigationLoadsEachPrimaryView` smoke test passed before the
  final pure-model offline/persistence-state adjustment, with a finalized result at
  `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.RVRC5Z/ui-navigation.xcresult`.
  A final rerun could not launch the simulator test runner and reached no test case; it is not
  passing post-change UI evidence. The unit lane compiled the final source in Debug.
