# Ingestion Reactive Consumers Progress

## Overview

Tracks accepted-generation invalidation, bounded Home observation, cache retention, detail reconciliation, and final cache-consumer evidence.

**Epic status:** Planned
**Primary GitHub epic:** [#424](https://github.com/justinrooks/project-arcus/issues/424)

## Global Decisions

- Generations trigger rereads; they do not carry domain data.
- Map preserves its current scene until replacement is ready.
- Home query narrowing precedes retention cleanup.
- Details remain immediately cache-seeded and perform no navigation-time networking.
- Outlook issuance switching is out of scope.
- All implementation uses `GPT-5.6 Terra / medium`.

## Current State

Map reloads on scene activation rather than accepted feed changes. Home observes all retained projections and outlooks. Details are fast value-based snapshots but open alert content cannot reconcile accepted revisions.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#452](https://github.com/justinrooks/project-arcus/issues/452) — Invalidate the visible map from accepted generations | Pending | Durable feed generations |
| 2 | [#455](https://github.com/justinrooks/project-arcus/issues/455) — Introduce keyed Home projection observation | Pending | Persistence-gated publication |
| 3 | [#456](https://github.com/justinrooks/project-arcus/issues/456) — Add explicit Home projection retention | Pending | 02 and measurement |
| 4 | [#451](https://github.com/justinrooks/project-arcus/issues/451) — Reconcile open alert detail with accepted revisions | Pending optional | Durable hot generation |
| 5 | [#450](https://github.com/justinrooks/project-arcus/issues/450) — Prove end-to-end cache consumer behavior | In validation — evidence incomplete | 01–04 shipped scope |

## Existing Code Map

- Map: `Sources/Features/Map/MapScreenView.swift`, `Sources/Features/Map/MapFeatureModel.swift`
- Home cache selection: `Sources/App/HomeView.swift`, `Sources/App/HomeView+PresentationState.swift`
- Projection persistence: `Sources/Repos/HomeProjectionStore.swift`
- Details: Alert and Outlook feature views

## Status Ledger

### [#452](https://github.com/justinrooks/project-arcus/issues/452) — Invalidate the visible map from accepted generations
- Status: Implemented — awaiting human review
- Handoff: The map observes persisted accepted feed generation events while active and rereads canonical providers for convective map, fire map, meso, and alert changes. Other feed attempts and acceptances do not invalidate it; existing scene replacement preserves the current map while reads resolve.

### [#455](https://github.com/justinrooks/project-arcus/issues/455) — Introduce keyed Home projection observation
- Status: Implemented — no SwiftData schema change
- Handoff: Home uses one plain, newest-first `@Query` over all retained projections. Current-location and startup display readiness are selected in memory through `HomeProjectionRecord.newestDisplayReady(in:)`, preserving legacy partial-risk and nil-weather cache behavior while avoiding unsupported custom-type predicates. The actor fallback uses the same sorted descriptor. This read is intentionally unbounded until issue #456 adds explicit retention; retain that dependency when sequencing #456.

### [#456](https://github.com/justinrooks/project-arcus/issues/456) — Add explicit Home projection retention
- Status: Implemented — ready for commit
- Handoff: On initial observation and each keyed Home location-context change, the projection store records the active row's view and retains that row, the newest display-ready startup fallback, and up to 10 recent display-ready projections whose newest update or view is within 30 days. Stale projection IDs are staged per SwiftData store in UserDefaults and are deleted only on a later sweep if they remain outside the retention set, including when no active row exists yet. `HomeProjectionRetentionCoordinator` in its own source file provides a per-store async lease that serializes active-context publication with deletion and view updates without blocking the MainActor during SwiftData work. No canonical feed stores or SwiftData schema are changed. Retention waits for a resolved Home context, cancels superseded location work, and rolls back if cancellation arrives before save.

### [#451](https://github.com/justinrooks/project-arcus/issues/451) — Reconcile open alert detail with accepted revisions
- Status: Implemented — awaiting human review
- Handoff: Alert detail remains immediately seeded from its selected cached DTO. While open, each alert-detail entry point observes accepted `arcus.alert` and `arcus.alerts` generations, rereads the canonical local alert by stable ID, and replaces its detail only when that same identity has a newer accepted revision. Unrelated feeds, absent/rejected rereads, mismatched identities, and older or unversioned candidates retain the visible detail; dismissal or navigation away cancels the view-scoped observation task.

### [#450](https://github.com/justinrooks/project-arcus/issues/450) — Prove end-to-end cache consumer behavior
- Status: In validation — do not close. The physical-device warm and cold captures below cover core publication and a warm Map/detail navigation pass, but not every acceptance scenario or request count.
- Device/build: iPhone 14 Pro Max, iOS 27.0.1, SkyAware 1.3.0 (1), Release; executable SHA-256 `27b5558ecf2dbc6e3f013c89c3e3aad8f8d3fb093d45b17676559505189fb7a5`.
- Warm cache: a 46.231 s SwiftUI/signpost trace recorded a populated Today render at 1.404 s, core projection saves, a Today visible commit at 5.641 s, and a subsequent Today render at 5.971 s. A separate 30.562 s Time Profiler trace contains 6,185 SkyAware samples. A 29 s iPhone screen recording shows populated Today, Map with a Severe Risk scene, selection of the Hail layer, a populated cached convective-outlook detail, and return to Today. The video and traces are separate sessions; their timestamps cannot be correlated.
- Cold cache: after the user-approved uninstall/reinstall of the same Release build, a 56.287 s SwiftUI/signpost launch trace recorded core projection saves at 26.482 s and 27.859 s, Today visible commit at 28.121 s, and Today render at 28.264 s, all relative to trace start. A local-only follow-up screenshot showed populated Today after relaunch. Trace start is not a precise app-start timestamp, so these values are not claimed as launch-to-cache latency.
- Offline fallback (user-reported, 2026-09-29): with the phone in Airplane Mode, the UI continued showing the last known accepted data. This supports cache retention during complete connectivity loss, but was not captured in the agent's device trace. Airplane Mode disables all provider connectivity, so this is not a provider-specific partial-failure test.
- Partial-provider simulation (iPhone 17 simulator, Debug): a deterministic ingestion test seeds an accepted Home projection, fails only the SPC map sync, and accepts the outlook sync. It verifies retained risk and visible core, an available outlook, failed-map versus accepted-outlook freshness, and retry of only the failed map feed. This covers the requested controlled failure without live providers or further physical-device testing. The separate cached-outlook UI test verifies presentation, not failure injection.
- Raw evidence is local-only at `/private/tmp/skyaware-450.meeUCj/`: `warm-cache.trace`, `warm-cpu.trace`, `cold-cache.trace`, `warm-map-detail.mp4`, and `analysis/`. The video SHA-256 is `c86f0ed9c248056864ecbf34d4c3358117a94d001c545c384ed853a9c672fcd2`. The custom trace templates contain SwiftUI/signpost or Time Profiler stores only, with no `os-log` or `os-log-arg` stores. Do not commit the raw captures: they may reveal private location or weather context.
- Remaining evidence: merged-ownership behavior was not exercised in this simulator pass; no exact live request count, map-ready timing, detail-opening latency, or proof of zero navigation-time requests. A warm screenshot/recording demonstrates no observed blank replacement during the sampled path, not a guarantee across refreshes.

## Verification Ledger

- [#455](https://github.com/justinrooks/project-arcus/issues/455): focused `HomeViewKeyedProjectionObservationTests` passed (2 tests, 0 failures, 0 skipped) on iPhone 17, iOS 26.5, Debug: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.eYPkL6/unit.xcresult`. The full unit lane passed (1,188 tests, 0 failures, 0 skipped) on the same simulator and configuration: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.tjwVGk/unit.xcresult`. `git diff --check` passes.
- [#456](https://github.com/justinrooks/project-arcus/issues/456): after extracting the coordinator to its own source file, focused `HomeProjectionStoreTests` passed twice (55 tests each, 0 failures, 0 skipped) on iPhone 17, iOS 26.5, Debug: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.mLdmcc/unit.xcresult` and `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.5C6E5x/unit.xcresult`. The full unit lane passed (1,210 tests, 0 failures, 0 skipped) on the same simulator and configuration: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.hAIurQ/unit.xcresult`. The Debug iPhone 17 simulator build succeeded, and `git diff --check` passed.
- [#450](https://github.com/justinrooks/project-arcus/issues/450): the focused alert-detail, map-scene, keyed-Home, alert-ownership, and projection-store unit suites passed (84 tests, 0 failures, 0 skipped) on iPhone 17, iOS 26.5, Debug: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.SzASN6/unit.xcresult`. The full unit lane failed (1,270 passed, 2 failed, 0 skipped): `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.gXqNdt/unit.xcresult`. `LocationContextResolverTests/resolvesLocationLabelsConcurrently()` timed out waiting for both zone requests; `LocationProviderTests/snapshotPusher_boundedDrainPreservesQueuedWork()` was marked as a crash. The matching crash report shows a `SequencedHomeIngestionCoordinator` test-helper precondition (`received more requests than snapshots`) on a `HomeRefreshPipeline` task; attribution to the named location test is not established. Do not treat the full lane as passing. The first UI-lane attempt was sandbox-blocked; the next was intentionally interrupted after discovering `SkyAware_UI_Smoke.xctestplan` currently selects 33 tests despite repository guidance describing one navigation test. Neither is valid UI evidence.
- [#450](https://github.com/justinrooks/project-arcus/issues/450): the explicitly selected `SkyAwareUITests/testTabNavigationLoadsEachPrimaryView()` navigation smoke passed (1 test, 0 failures, 0 skipped) on iPhone 17, iOS 26.5, Debug: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.AYKsHX/ui-navigation.xcresult`.
- [#450](https://github.com/justinrooks/project-arcus/issues/450): after the simulator-only partial-provider test was added, the exact focused unit selector passed (1 test, 0 failures, 0 skipped): `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.Rili6U/unit.xcresult`. The final full unit lane passed (1,273 tests, 0 failures, 0 skipped) on iPhone 17, iOS 26.5, Debug: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.aZJRV0/unit.xcresult`. The earlier selector lacking `()` matched zero tests and is not evidence. The two exact simulator UI selectors produced 1 pass (`testOutlookDetailOpensFromTheLatestOutlookRow`) and 1 failure (`testMapLayerPickerCyclesThroughEveryLayerAndIgnoresDuplicateSelection`): `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.1C4JMp/ui-navigation.xcresult`. The Map test failed because its existing assertion could not find the `Show Active Alerts` switch in the layer menu; it does not inject a provider failure. The cached-outlook UI test verifies presentation only. No physical-device tests were run for this addition.
