# Risk Profile Change Notifications Progress

## Overview

This ledger tracks the local SkyAware risk-profile change notification campaign. It is the durable handoff record for
implementation status, validation evidence, decisions, and deferred work.

**Epic status:** Planned  
**Primary GitHub epic:** [#100](https://github.com/justinrooks/project-arcus/issues/100)

## Global Decisions

- Include storm, severe, and fire risk in one profile.
- Treat severe hazard and probability changes as meaningful; normalize probabilities to whole percentages.
- Notify for upgrades, downgrades, mixed changes, and later reversions.
- Compare and persist atomically inside `HomeProjectionStore`.
- Seed new or incomplete per-projection baselines without notifying.
- Run notification delivery after background refresh and background significant-location-change ingestion.
- Do not send foreground local notifications.
- Default the independent preference to enabled.
- Batch all changes from one accepted ingestion snapshot into one notification; do not aggregate across executions.
- Keep this client-only and best effort. Server-side SPC/APNs reliability is separate work.

## Current State Summary

The unified ingestion path already resolves all three risk values and persists them in `HomeProjection`. Background
refresh receives the complete snapshot but invokes only morning and meso engines. Significant-location-change handling
invokes only the watch engine. Notification settings have no risk-change preference, and no semantic old/new delta is
returned from slow-product persistence.

The projection store is the correct comparison seam because its actor can read the previous profile, persist the new
profile, and return the accepted delta atomically. Ingestion should transport that delta; orchestration should own
notification side effects.

## Issue Sequence

| Order | Issue | Title | Preferred model | Status | Dependency |
|---:|---|---|---|---|---|
| 0 | [#100](https://github.com/justinrooks/project-arcus/issues/100) | Epic: Send Notification when Risk Changes | Coordination | Planned | Approved product decisions |
| 1 | [#308](https://github.com/justinrooks/project-arcus/issues/308) | Detect accepted risk profile changes atomically | `5.4 mini medium` | Planned | None |
| 2 | [#309](https://github.com/justinrooks/project-arcus/issues/309) | Carry accepted risk changes through home ingestion | `5.4 mini medium` | Planned | #308 |
| 3 | [#310](https://github.com/justinrooks/project-arcus/issues/310) | Add the batched risk-change notification engine | `5.4 mini medium` | Complete | #308-#309 |
| 4 | [#311](https://github.com/justinrooks/project-arcus/issues/311) | Add the risk-change notification preference | `5.4 mini medium` | Planned | None; execute after #310 |
| 5 | [#312](https://github.com/justinrooks/project-arcus/issues/312) | Run risk-change notifications from background refresh paths | `5.4 mini medium` | Planned | #308-#311 |

## Existing Code Map

- Risk loading: `Sources/App/HomeRefreshV2/HomeSnapshotStore.swift`
- Snapshot contract: `Sources/App/HomeRefreshV2/HomeSnapshot.swift`
- Accepted persistence decision: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Projection model/store: `Sources/Models/Home/HomeProjection.swift`, `Sources/Repos/HomeProjectionStore.swift`
- Background refresh: `Sources/Features/Background/BackgroundOrchestrator.swift`
- Background location changes: `Sources/Features/Background/BackgroundLocationChangeHandler.swift`
- Notification contracts/engines: `Sources/Notifications`, `Sources/Interfaces/Notification`
- Dependency composition/settings provider: `Sources/App/Dependencies.swift`
- User preference UI: `Sources/Features/Settings/SettingsView.swift`
- Focused persistence tests: `Tests/UnitTests/HomeProjectionStoreTests.swift`
- Existing executor harness: `Tests/UnitTests/StormSetupIngestionTests.swift`
- Background and notification tests: `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`,
  `Tests/UnitTests/AlertNotificationTests.swift`, `Tests/UnitTests/RemoteNotificationRegistrarTests.swift`

## Investigation Notes

- `HomeSnapshotStore` loads storm, severe, and fire values together for a resolved location.
- `HomeIngestionExecutor.slowProductPersistenceDecision` already blocks projection/widget advancement for rejected or
  failed SPC map synchronization.
- `HomeProjection.projectionKey` includes H3, county, forecast zone, and fire zone identity.
- `SevereWeatherThreat` equality includes its associated probability; SPC values are discrete but should still be
  normalized before fingerprinting and user-facing formatting.
- Existing notification engines separate rule, gate, composer, and sender behavior and use deterministic identifiers.
- A per-projection last-delivered current fingerprint suppresses duplicate shared-snapshot evaluation without blocking
  a profile that returns after an intervening change.
- iOS background refresh remains opportunistic. This campaign improves awareness when refresh runs; it does not create
  guaranteed delivery.

## Status Ledger

### Issue #308 — 01: Detect accepted risk profile changes atomically

- Status: Complete
- Scope: Domain profile/change contract and atomic projection-store comparison/persistence.
- Validation target: `HomeProjectionStoreTests` and Debug build.
- Handoff: Do not add notification side effects or change slow-product eligibility.

### Issue #309 — 02: Carry accepted risk changes through home ingestion

- Status: Complete
- Scope: Optional delta on `HomeSnapshot`, populated only by successful authorized persistence.
- Validation target: focused ingestion tests and Debug build.
- Handoff: Preserve widgets, refresh publication, and rejected/failed map-sync behavior.

### Issue #310 — 03: Add the batched risk-change notification engine

- Status: Complete
- Scope: Notification kind, rule, one-message composer, per-projection duplicate gate, engine, and deterministic tests.
- Validation target: `RiskChangeNotificationTests` and Debug build.
- Handoff: Do not wire background execution or settings yet.

### Issue #311 — 04: Add the risk-change notification preference

- Status: Planned
- Scope: Default-enabled independent setting, provider state, authorization-aware presentation, and focused tests.
- Validation target: notification preference tests and Debug build.
- Handoff: Do not change Arcus Signal subscription/location-sharing semantics.

### Issue #312 — 05: Run risk-change notifications from background refresh paths

- Status: Planned
- Scope: Dependency composition, background refresh/location-change invocation, preference enforcement, and outcome
  reporting.
- Validation target: risk engine, orchestrator cadence, and location-change notification tests plus Debug build.
- Handoff: Stop when both approved background paths are covered; do not add foreground or server delivery.

## Verification Ledger

| Date | Issue | Verification | Result |
|---|---|---|---|
| 2026-07-15 | Planning | Source-backed investigation, epic/label review, and approved product decisions | Complete |
| 2026-07-15 | #308 | `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/HomeProjectionStoreTests test`; `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`; `git diff --check` | Passed |
| 2026-07-15 | #309 | Files: `Sources/App/HomeRefreshV2/HomeSnapshot.swift`, `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`, `Sources/App/HomeRefreshV2/HomeStormSetupIngestion.swift`, `Sources/Repos/HomeProjectionStore.swift`, `Tests/UnitTests/StormSetupIngestionTests.swift`, `docs/plans/risk-profile-change-notifications-progress.md`; behavior: carry an accepted, successfully persisted risk-profile delta through home ingestion while preserving rejected/failed map-sync and persistence-failure nil semantics; commands: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/StormSetupIngestionTests test`, `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`, `git diff --check` | Passed |
| 2026-07-15 | #310 | Files: `Sources/Interfaces/Notification/NotificationRuleEvaluating.swift`, `Sources/Notifications/NotificationsCore.swift`, `Sources/Notifications/RiskChange/RiskChangeContext.swift`, `Sources/Notifications/RiskChange/RiskChangeRule.swift`, `Sources/Notifications/RiskChange/RiskChangeGate.swift`, `Sources/Notifications/RiskChange/RiskChangeComposer.swift`, `Sources/Notifications/RiskChange/RiskChangeEngine.swift`, `Sources/Utilities/Extensions/Logger+Extension.swift`, `Tests/UnitTests/RiskChangeNotificationTests.swift`; behavior: add a pure risk-change notification engine with deterministic event IDs, per-projection duplicate suppression, reversible gate state, ordered storm/severe/fire copy, and location-aware subtitle fallback; commands: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/RiskChangeNotificationTests test`, `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`, `git diff --check` | Passed |

## Handoff Notes

- Execute issues sequentially and update the matching ledger section before closing each issue.
- Record exact files, observable behavior, commands, test execution results, `.xcresult` findings, and deferred work.
- Stop and re-plan if work requires server changes, cross-run delayed aggregation, foreground delivery, cadence changes,
  SwiftData migration, or broad notification architecture refactoring.
