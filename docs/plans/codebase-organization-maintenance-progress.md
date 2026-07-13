# Codebase Organization Maintenance Progress

This is the durable, token-conscious handoff ledger for the codebase organization maintenance campaign.

## Overview

- Epic status: Planned
- Primary GitHub epic: [#289](https://github.com/justinrooks/project-arcus/issues/289)
- Scope: Project Arcus only
- Baseline: 306 Swift files; 61 at or above 300 lines, 36 at or above 500, and 15 at or above 1,000
- Completed before this campaign: accidental `AirQualityHTTPClientTests.swift` application-target membership was fixed by
  the project owner

## Global Decisions

- Organize by responsibility and change reason, not a hard line-count limit.
- Preserve existing architecture boundaries and behavior.
- Split the broad test-organization item into five subject-specific review units.
- Use GPT-5.6 Luna for mechanical movement, Terra for semantic decomposition, and Sol for actor/concurrency-sensitive
  work; use the fallback recorded in the runbook when GPT-5.6 is unavailable.
- One issue per task and normally one issue per PR.
- Update this ledger rather than repeating investigation context in prompts or issue comments.

## Current State Summary

- Summary files mix presentation policy, SwiftUI components, and large preview galleries.
- `MapFeatureModel.swift` combines main-actor feature state, scene DTOs, actor planning, and pure plan construction.
- `HomeIngestionExecutor.swift` contains a disproportionately large Storm Setup lane implementation.
- `LocationSnapshotPusher.swift` combines queue coordination, payload construction, persistence DTOs, and storage.
- Widget rendering is collected in a 1,000-line component warehouse.
- Storm Setup detail presentation is cohesive but contains several semantic builder/formatting units.
- Several test files contain multiple unrelated suites and extensive reusable fakes.
- The Debug build succeeds but reports a mutable-Sendable warning in `URLSessionTaskMetricsCollector`.

## Issue Sequence

| Order | ID | GitHub | Title | Status | Model |
|---:|---|---|---|---|---|
| 1 | COM-01 | [#290](https://github.com/justinrooks/project-arcus/issues/290) | Extract Summary preview galleries | Complete | GPT-5.6 Luna / medium |
| 2 | COM-02 | [#291](https://github.com/justinrooks/project-arcus/issues/291) | Split Home and Summary state test suites | Pending | GPT-5.6 Luna / high |
| 3 | COM-03 | [#292](https://github.com/justinrooks/project-arcus/issues/292) | Split location provider and resolver tests | Pending | GPT-5.6 Luna / high |
| 4 | COM-04 | [#293](https://github.com/justinrooks/project-arcus/issues/293) | Split home refresh pipeline tests and fakes | Pending | GPT-5.6 Luna / high |
| 5 | COM-05 | [#294](https://github.com/justinrooks/project-arcus/issues/294) | Split map feature model tests and fakes | Pending | GPT-5.6 Luna / high |
| 6 | COM-06 | [#295](https://github.com/justinrooks/project-arcus/issues/295) | Split mixed SPC and repository sync tests | Pending | GPT-5.6 Luna / high |
| 7 | COM-07 | [#296](https://github.com/justinrooks/project-arcus/issues/296) | Decompose Primary Awareness presentation files | Pending | GPT-5.6 Terra / high |
| 8 | COM-08 | [#297](https://github.com/justinrooks/project-arcus/issues/297) | Decompose map model and render planning files | Pending | GPT-5.6 Sol / high |
| 9 | COM-09 | [#298](https://github.com/justinrooks/project-arcus/issues/298) | Extract Storm Setup ingestion responsibilities | Pending | GPT-5.6 Sol / xhigh |
| 10 | COM-10 | [#299](https://github.com/justinrooks/project-arcus/issues/299) | Separate location upload persistence from queue coordination | Pending | GPT-5.6 Sol / xhigh |
| 11 | COM-11 | [#300](https://github.com/justinrooks/project-arcus/issues/300) | Split widget rendering components by domain | Pending | GPT-5.6 Luna / high |
| 12 | COM-12 | [#301](https://github.com/justinrooks/project-arcus/issues/301) | Extract Storm Setup detail presentation builders | Pending | GPT-5.6 Terra / high |
| 13 | COM-13 | [#302](https://github.com/justinrooks/project-arcus/issues/302) | Resolve URL session metrics collector concurrency warning | Pending | GPT-5.6 Sol / high |

## Existing Code Map

- Summary: `Sources/Features/Summary/SummaryView.swift`, `PrimaryAwarenessPanel.swift`
- Map: `Sources/Features/Map/MapFeatureModel.swift`, `MapScreenView.swift`
- Home ingestion: `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- Location upload: `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`
- Widgets: `WidgetsExtension/WidgetRenderingComponents.swift`
- Storm Setup presentation: `Sources/Features/StormSetup/StormSetupDetailPresentation.swift`
- Networking warning: `Sources/Infrastructure/Networking/HTTPDataDownloader.swift`
- Large tests: `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`, `LocationProviderTests.swift`,
  `HomeRefreshPipelineTests.swift`, `MapFeatureModelTests.swift`, and `SevereRiskRepoRefreshTornadoRiskTests.swift`

## Investigation Notes

- File extraction alone is insufficient when a file contains multiple change reasons; split at semantic ownership seams.
- Explicit `@MainActor`, actor, cancellation, and `Sendable` boundaries are required under the current Swift 6.0 project
  settings and must not be weakened.
- Preview extraction is intentionally first because it removes substantial navigation noise with minimal behavioral risk.
- Test decomposition precedes production decomposition so focused suites and reusable fakes are easier to locate during
  later work.

## Status Ledger

### COM-01 / GitHub #290 - Extract Summary preview galleries

Status: Complete

Files changed:

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/SummaryView+Previews.swift`
- `Sources/Features/Summary/PrimaryAwarenessPanel.swift`
- `Sources/Features/Summary/PrimaryAwarenessPanel+Previews.swift`
- `docs/plans/codebase-organization-maintenance-progress.md`

Preserved behavior: moved all 26 Summary preview scenarios, the Summary preview content/data fixtures, and the single
Primary Awareness Panel preview gallery/card fixture without renaming scenarios, changing values, traits, access, or
production APIs. New files are under the synchronized `Sources` group for the `SkyAware` application target only.

Validation: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`

Residual risk: GitHub issue metadata could not be fetched from this environment; implementation followed the supplied
issue objective and required scope. Preview declarations were compared line-for-line with the original blocks.

Handoff: issue #290 is complete; do not begin #291 in this task.

### COM-02 / GitHub #291 - Split Home and Summary state test suites

Status: Complete

Files changed:

- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift` — removed after all declarations moved cleanly.
- `Tests/UnitTests/HomeViewStateTests.swift` — HomeView refresh triggers, projection launch, and outlook display suites.
- `Tests/UnitTests/HomeRefreshPolicyTests.swift` — foreground refresh policy suite.
- `Tests/UnitTests/SummaryViewLocalAlertsStateTests.swift` — Summary local-alert and local-alert display-state suites.
- `Tests/UnitTests/SummaryViewLoadingStateTests.swift` — Summary resolving, risk-placeholder, content-presentation, and resolution-state suites.
- `Tests/UnitTests/TodayContentStateTests.swift` — Today content, surface-flow, and visible-weather suites.
- `Tests/UnitTests/SummaryRefreshPolicyTests.swift` — outlook and WeatherKit refresh policy suites.
- `SkyAware.xcodeproj/project.pbxproj` — synchronized-folder membership for the six new test files in both target exception sets.
- `docs/plans/codebase-organization-maintenance-progress.md` — this COM-02 ledger entry.

Suites moved:

- `HomeViewRefreshTriggerTests`, `HomeViewProjectionLaunchTests`, `HomeViewOutlookDisplayTests` → `HomeViewStateTests.swift`
- `ForegroundRefreshPolicyTests` → `HomeRefreshPolicyTests.swift`
- `SummaryViewLocalAlertsTests`, `LocalAlertsDisplayStateTests` → `SummaryViewLocalAlertsStateTests.swift`
- `SummaryViewEmptyResolvingTests`, `SummaryViewRiskPlaceholderPresentationTests`, `SummaryContentPresentationStateTests`, `SummaryResolutionStateTests` → `SummaryViewLoadingStateTests.swift`
- `TodayContentStateTests`, `TodaySurfaceStateFlowTests`, `TodayVisibleWeatherStateTests` → `TodayContentStateTests.swift`
- `OutlookRefreshPolicyTests`, `WeatherKitRefreshPolicyTests` → `SummaryRefreshPolicyTests.swift`

Behavior preserved: the pre-edit inventory contained 15 suites and 99 tests; the post-edit inventory contains the same 15 suites and 99 tests. Every suite declaration, test name, trait, serialization/actor annotation, test body, assertion, fixture, and declaration order was moved intact. No production files changed.

Validation:

- Inventory comparison: exact suite-block comparison against `HEAD` reported 15 pre-edit suites, 15 post-edit suites, 99 pre-edit tests, 99 post-edit tests, no missing suites, no extra suites, no changed declarations.
- Focused command: `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' test -derivedDataPath /private/tmp/project-arcus-291-derived-2 -resultBundlePath /tmp/project-arcus-291-final.xcresult -only-testing:SkyAwareTests/HomeViewRefreshTriggerTests -only-testing:SkyAwareTests/HomeViewProjectionLaunchTests -only-testing:SkyAwareTests/SummaryViewLocalAlertsTests -only-testing:SkyAwareTests/LocalAlertsDisplayStateTests -only-testing:SkyAwareTests/SummaryViewEmptyResolvingTests -only-testing:SkyAwareTests/SummaryViewRiskPlaceholderPresentationTests -only-testing:SkyAwareTests/SummaryContentPresentationStateTests -only-testing:SkyAwareTests/TodayContentStateTests -only-testing:SkyAwareTests/TodaySurfaceStateFlowTests -only-testing:SkyAwareTests/HomeViewOutlookDisplayTests -only-testing:SkyAwareTests/ForegroundRefreshPolicyTests -only-testing:SkyAwareTests/SummaryResolutionStateTests -only-testing:SkyAwareTests/OutlookRefreshPolicyTests -only-testing:SkyAwareTests/WeatherKitRefreshPolicyTests -only-testing:SkyAwareTests/TodayVisibleWeatherStateTests` — **TEST SUCCEEDED** on iPhone 17 / iOS 26.5.
- Result inspection: `xcrun xcresulttool get test-results tests --path /tmp/project-arcus-291-final.xcresult --compact` reported a passed test plan, 15 suites, 99 cases, and zero failures.

Target-membership evidence: the fresh `SkyAwareTests.SwiftFileList` contains all six new test files; the fresh `SkyAware.SwiftFileList` contains none of the six and no deleted original file. The project file lists each new path in both the `SkyAware` exclusion set and the `SkyAwareTests` inclusion set.

Residual risks and handoff: GitHub issue metadata could not be fetched because the GitHub API/page cache was unavailable; implementation followed the supplied issue objective and repository runbook. The full target compilation emitted existing unrelated warnings in `MesoNotificationTests.swift`, `RemoteNotificationRegistrarTests.swift`, and the simulator asset catalog; none were caused by this movement. Issue #291 is complete; do not begin #292 in this task.

### COM-03 / GitHub #292 - Split location provider and resolver tests

Status: Complete

Files changed:

- `Tests/UnitTests/LocationProviderTests.swift` — provider suite and provider-only support declarations remain focused in the original provider file.
- `Tests/UnitTests/LocationContextResolverTests.swift` — new resolver-focused file containing the resolver suite, serialized trait, tests, and resolver-only support declarations.
- `SkyAware.xcodeproj/project.pbxproj` — synchronized-folder membership for the new resolver test file in both target exception sets.
- `docs/plans/codebase-organization-maintenance-progress.md` — this COM-03 ledger entry.

Suites and support declarations moved:

- `LocationContextResolverTests` and its 10 tests moved to `LocationContextResolverTests.swift` unchanged.
- Resolver-only support moved intact: `TestError`, `AuthorizationState`, `AuthorizationRequestState`, `TestGeocoder`, `TestHasher`, `waitUntil`, `RefreshRequestTracker`, `MockSnapshotCache`, `ResolverNwsClient`, and `makePointPayload`.
- `LocationProviderTests` retains its 58 tests, 20 nested provider support declarations, and the provider-only `waitUntilLocationSnapshot` helper. No shared support file was needed.

Behavior preserved: the pre-edit inventory contained 2 suites and 68 tests (58 provider, 10 resolver); the post-edit inventory contains the same declarations and counts. Exact comparisons against `HEAD` matched the provider prefix, suite/test inventory, and support-declaration inventory; the resolver segment was moved intact with only two pre-existing trailing-whitespace markers removed. Test names, traits, bodies, assertions, fixture values, async behavior, and production code were unchanged.

Validation:

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SkyAwareTests/LocationProviderTests -resultBundlePath /tmp/project-arcus-292-location-provider.xcresult test` — **TEST SUCCEEDED**; 58 passed, 0 failed, 0 skipped on iPhone 17 / iOS 26.5.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SkyAwareTests/LocationContextResolverTests -resultBundlePath /tmp/project-arcus-292-location-resolver.xcresult test` — **TEST SUCCEEDED**; 10 passed, 0 failed, 0 skipped on iPhone 17 / iOS 26.5.
- `xcrun xcresulttool get test-results summary --path /tmp/project-arcus-292-location-provider.xcresult --compact` and the resolver equivalent — both reported `result: Passed` with zero failures.
- `git diff --check` plus the equivalent check for the untracked resolver file — passed. Final diff contains only test organization, synchronized-folder membership, and this ledger entry; no assertion or production-code changes.

Target-membership evidence: the generated `SkyAwareTests.SwiftFileList` contains both `LocationContextResolverTests.swift` and `LocationProviderTests.swift`; the generated `SkyAware.SwiftFileList` contains neither. The project file lists both test paths in the `SkyAware` exclusion set and the `SkyAwareTests` inclusion set.

Residual risks and handoff: no production behavior or coverage semantics changed. `xcresulttool get test-results tests` could not be used because this Xcode version attempted to materialize `TestReport` without permission; the supported summary reader and xcodebuild results were inspected successfully. Issue #292 is complete; do not begin #293 in this task.

### COM-04 / GitHub #293 - Split home refresh pipeline tests and fakes

Status: Complete

Files changed:

- `Tests/UnitTests/HomeRefreshPipelineTests.swift` — retains the pipeline suite and all pipeline-only support declarations.
- `Tests/UnitTests/SkyAwareAppActivationCleanupTests.swift` — activation-cleanup suite moved intact from the mixed source file.
- `SkyAware.xcodeproj/project.pbxproj` — synchronized-folder membership for the activation-cleanup test file in both target exception sets.
- `docs/plans/codebase-organization-maintenance-progress.md` — this COM-04 ledger entry.

Suites and support declarations moved:

- `SkyAwareAppActivationCleanupTests` and its one test moved to `SkyAwareAppActivationCleanupTests.swift` unchanged.
- `HomeRefreshPipelineTests` remains in `HomeRefreshPipelineTests.swift` with all 35 tests unchanged.
- Pipeline-only support remains private to its owning file: `RecordingHomeIngestionCoordinator`,
  `SequencedHomeIngestionCoordinator`, `AsyncGate`, `CompletionFlag`, `TestFailure`, `FakeLocationSession`,
  `FakeWeatherClient`, `FakeSpcProvider`, `RecordingWidgetSnapshotRefresher`, `FakeAlertProvider`, `waitUntil`, and
  the six pipeline fixture/environment helpers. No support declaration was shared by the resulting suites, so no
  generic or unnecessary support file was introduced.

Async behavior preserved: `.serialized`, `@MainActor`, task creation, polling, gate opening, serialization, the
10-millisecond polling sleep, and all one-second/default and five-second explicit timeouts remain unchanged. No
production files or test semantics changed.

Validation:

- Pre/post inventory comparison using the `awk` suite/test extractor reported an exact match: 2 suites and 36 tests;
  the pipeline declaration comparison and activation-suite block comparison also matched, ignoring only the moved
  file-separator blank line.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/project-arcus-293-derived -resultBundlePath /private/tmp/project-arcus-293-pipeline.xcresult -only-testing:SkyAwareTests/HomeRefreshPipelineTests test` — **TEST SUCCEEDED**; 35 passed, 0 failed, 0 skipped on iPhone 17 / iOS 26.5.
- `xcrun xcresulttool get test-results summary --path /private/tmp/project-arcus-293-pipeline.xcresult --compact` — `result: Passed`, 35 passed, 0 failed, 0 skipped.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/project-arcus-293-derived -resultBundlePath /private/tmp/project-arcus-293-activation.xcresult -only-testing:SkyAwareTests/SkyAwareAppActivationCleanupTests test` — **TEST SUCCEEDED**; 1 passed, 0 failed, 0 skipped on iPhone 17 / iOS 26.5.
- `xcrun xcresulttool get test-results tests --path /private/tmp/project-arcus-293-activation.xcresult --compact` — activation suite and test both reported `Passed`; the summary subcommand was also attempted but hit Xcode's TestReport materialization permission error.
- `git diff --check` — passed.

Target-membership evidence: the generated `SkyAwareTests.SwiftFileList` contains both `HomeRefreshPipelineTests.swift` and
`SkyAwareAppActivationCleanupTests.swift`; the generated `SkyAware.SwiftFileList` contains neither. The project file
lists the new path in the `SkyAware` exclusion set and the `SkyAwareTests` synchronized-folder membership set.

Residual risks and handoff: the focused runs compile the synchronized test target and emitted existing unrelated
warnings, including `HTTPDataDownloader.swift`'s mutable Sendable property and warnings in other test files. No
assertion, timeout, async ordering, production, or application-target changes were introduced. Issue #293 is complete;
do not begin #294 in this task.

### COM-05 / GitHub #294 - Split map feature model tests and fakes

Status: Complete

Files changed:

- `Tests/UnitTests/MapFeatureModelTests.swift` — retains the original `MapFeatureModelTests` suite with 24 reload/results, failure, summary, stale-data, and partial-result tests.
- `Tests/UnitTests/MapFeatureModelSceneTests.swift` — layer selection, stacking, scene caching, refetch, in-flight reload follow-up, and center-coordinate tests, with scene-only stores and counting service kept private.
- `Tests/UnitTests/MapFeatureModelWarningsTests.swift` — warning composition, geometry toggling, warning legends, warning-query failure, and overlay-revision tests.
- `Tests/UnitTests/MapFeatureModelTestSupport.swift` — shared map/alert stubs, result store, call counter, reload gate, queued reload service, shared fixtures, and common scene assertions.
- `SkyAware.xcodeproj/project.pbxproj` — synchronized-folder membership for the original suite and three new test files in both target exception sets.
- `docs/plans/codebase-organization-maintenance-progress.md` — this COM-05 ledger entry.

Behavior families and support declarations moved: the pre-edit suite was divided into reload/results (24 tests), scene/caching (7 tests), and warning/legend (15 tests). Shared support is limited to declarations used by multiple suites: `StubSpcMapData`, `StubArcusAlertQuerying`, `MutableResultMapDataStore`, `MutableResultSpcMapData`, `MapDataCallCounter`, `ReloadGate`, `QueuedReloadSpcMapData`, `StubError`, and common map fixtures/assertions. `CountingSpcMapData`, `MutableMapDataStore`, and `MutableSpcMapData` remain private to the scene suite.

Async and actor behavior preserved: all three suites remain `@MainActor`; the result stores, call counter, reload gate, checked continuations, queued first/second results, task creation, and follow-up-fetch sequencing were moved without semantic edits. No explicit cancellation-specific test existed before this issue, so none was introduced.

Validation:

- Pre/post test-block inventory: 46 tests before and after; zero missing, extra, or changed test names/bodies. `git diff --check` passed.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/project-arcus-294-derived -resultBundlePath /private/tmp/project-arcus-294-map-2.xcresult -only-testing:SkyAwareTests/MapFeatureModelTests test` — **TEST SUCCEEDED**; 24 passed, 0 failed, 0 skipped.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/project-arcus-294-derived -resultBundlePath /private/tmp/project-arcus-294-scene.xcresult -only-testing:SkyAwareTests/MapFeatureModelSceneTests test` — **TEST SUCCEEDED**; 7 passed, 0 failed, 0 skipped.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/project-arcus-294-derived -resultBundlePath /private/tmp/project-arcus-294-warnings.xcresult -only-testing:SkyAwareTests/MapFeatureModelWarningsTests test` — **TEST SUCCEEDED**; 15 passed, 0 failed, 0 skipped.
- `xcrun xcresulttool get test-results summary --path /private/tmp/project-arcus-294-map-2.xcresult --compact` — `result: Passed`, 24 passed, 0 failed, 0 skipped.
- `xcrun xcresulttool get test-results summary --path /private/tmp/project-arcus-294-scene.xcresult --compact` — `result: Passed`, 7 passed, 0 failed, 0 skipped.
- `xcrun xcresulttool get test-results summary --path /private/tmp/project-arcus-294-warnings.xcresult --compact` — `result: Passed`, 15 passed, 0 failed, 0 skipped.

Target-membership evidence: `/private/tmp/project-arcus-294-derived/.../SkyAwareTests.SwiftFileList` contains `MapFeatureModelTests.swift`, `MapFeatureModelSceneTests.swift`, `MapFeatureModelTestSupport.swift`, and `MapFeatureModelWarningsTests.swift`; the corresponding `SkyAware.SwiftFileList` contains only production `Sources/Features/Map/MapFeatureModel.swift` for the `MapFeatureModel` search and no test paths. The project file lists all four test paths in both synchronized target sets.

Residual risks and handoff: the initial post-split compile caught a misplaced private `makeMeso` fixture; it was moved intact to the warning suite before the final runs. Existing unrelated build warnings remain, including `HTTPDataDownloader.swift` mutable Sendable state and warnings in other test files. No production map code, assertions, task timing, or fake behavior changed. Issue #294 is complete; do not begin #295 in this task.

### COM-06 / GitHub #295 - Split mixed SPC and repository sync tests

Status: Complete

Files changed:

- Tests/UnitTests/SevereRiskRepoRefreshTornadoRiskTests.swift — retains the severe-risk repository suite and its original eight tests.
- Tests/UnitTests/StormRiskRepoRefreshCategoricalRiskTests.swift — contains the storm-risk repository suite and its original three tests, with its categorical client and fixtures private.
- Tests/UnitTests/SpcProviderSyncMapProductsTests.swift — contains the SPC map synchronization suite and its original 22 tests, with counting/scripted clients, provider factory, container, and map fixtures private.
- Tests/UnitTests/SpcRiskTestSupport.swift — contains only the genuinely shared severe/categorical SPC clients used by repository setup and map synchronization tests.
- SkyAware.xcodeproj/project.pbxproj — adds all four test paths to both synchronized target exception sets.
- docs/plans/codebase-organization-maintenance-progress.md — this COM-06 ledger entry.

Suites and support declarations moved: 33 tests were retained across SevereRiskRepoRefreshTornadoRiskTests (8), StormRiskRepoRefreshCategoricalRiskTests (3), and SpcProviderSyncMapProductsTests (22). The shared MockClient and CategoricalMockClient remain distinct; FireMockClient, CountingMapSyncClient, ScriptedMapSyncClient, the provider factory/container, and SPC map-data fixtures remain private to the SPC synchronization file. Private GeoJSON/date builders remain private to each suite file to avoid collisions with existing test-local builders.

Behavior preserved: suite names, test names, traits, assertions, fixtures, scripted responses, call counts, actor isolation, async ordering, and persistence-failure/cancellation semantics were moved without production-code changes. No tests were deleted, duplicated, disabled, or added to the application target.

Validation:

- Pre/post suite and test inventory comparison: 3 suites and 33 tests before and after; zero missing, extra, or changed suite/test declarations. git diff --check passed.
- xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/project-arcus-295-derived-3 -resultBundlePath /private/tmp/project-arcus-295-3.xcresult -only-testing:SkyAwareTests/SevereRiskRepoRefreshTornadoRiskTests -only-testing:SkyAwareTests/StormRiskRepoRefreshCategoricalRiskTests -only-testing:SkyAwareTests/SpcProviderSyncMapProductsTests test — TEST SUCCEEDED; 33 passed, 0 failed, 0 skipped on iPhone 17 / iOS 26.5.
- xcrun xcresulttool get test-results summary --path /private/tmp/project-arcus-295-3.xcresult --compact — result: Passed, 33 passed, 0 failed, 0 skipped.

Target-membership evidence: /private/tmp/project-arcus-295-derived-3/Build/Intermediates.noindex/SkyAware.build/Debug-iphonesimulator/SkyAwareTests.build/Objects-normal/arm64/SkyAwareTests.SwiftFileList contains all four new/retained test paths; the corresponding SkyAware.SwiftFileList contains none of those test paths. The project file lists all four paths in both synchronized target exception sets.

Residual risks and handoff: the first focused compile caught module-visible fixture-name collisions and a generated helper-spacing typo; both were corrected without changing test bodies or behavior. The validation build emitted existing unrelated warnings, including HTTPDataDownloader.swift mutable Sendable state and RemoteNotificationRegistrarTests.swift type-inference warnings. No production code changed. Issue #295 is complete; do not begin #296 in this task.

### COM-07 / GitHub #296 - Decompose Primary Awareness presentation files

Status: Complete

Files changed:

- `Sources/Features/Summary/PrimaryAwarenessPanel.swift` retains only the named panel composition and its existing
  input-to-row presentation wiring.
- `Sources/Features/Summary/PrimaryAwarenessPresentation.swift` owns primary-state resolution, alert precedence,
  destinations, and accessibility contracts.
- `Sources/Features/Summary/SupportingRiskRowDisplayModel.swift` owns supporting-risk display mapping and presentation
  modes.
- `Sources/Features/Summary/PrimaryAwarenessHeroView.swift` owns the primary hero component and its local optional
  accessibility-hint modifier.
- `Sources/Features/Summary/AwarenessSupportRow.swift` owns the supporting-row component and its layout metrics.
- `docs/plans/codebase-organization-maintenance-progress.md` records COM-07 completion.

Behavior and accessibility preserved: alert precedence, risk mapping, loading and offline presentation, destinations,
button actions, map-layer selection, view identity, environment dependencies, labels, values, hints, traits, and Reduce
Motion behavior are unchanged. The COM-01 preview file remains unchanged and compiles with the app target.

Visibility changes: `PrimaryAwarenessHeroView` and `AwarenessSupportRow` changed from file-private to module-internal
only because `PrimaryAwarenessPanel` now composes them from another file. No existing policy or display-model access
level changed.

Validation:

- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17"
  -only-testing:SkyAwareTests/SummaryAwarenessPanelTests -only-testing:SkyAwareTests/TodayContentStateTests test`
  — passed, 34 tests, 0 failures; result bundle
  `Test-SkyAware-2026.07.13_08-34-13--0600.xcresult` inspected with `xcresulttool`.
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17"
  build` — succeeded.
- The Debug target Swift file list includes `PrimaryAwarenessPanel+Previews.swift` and all four extracted files.
- Pre- and post-edit declaration inventories match, with declarations redistributed to their stated responsibilities.
- `git diff --check` passed.

Residual risks and handoff: this is a mechanical file split; focused presentation tests and the Debug build cover the
compiled contracts, but no manual preview rendering pass was performed. Existing unrelated build warning remains in
`HTTPDataDownloader.swift` for mutable state in a `Sendable` metrics collector. COM-07 is complete; do not begin COM-08
or GitHub #297 in this task.

### COM-08 / GitHub #297 - Decompose map model and render planning files

Status: Pending

### COM-09 / GitHub #298 - Extract Storm Setup ingestion responsibilities

Status: Pending

### COM-10 / GitHub #299 - Separate location upload persistence from queue coordination

Status: Pending

### COM-11 / GitHub #300 - Split widget rendering components by domain

Status: Pending

### COM-12 / GitHub #301 - Extract Storm Setup detail presentation builders

Status: Pending

### COM-13 / GitHub #302 - Resolve URL session metrics collector concurrency warning

Status: Pending

## Verification Ledger

| Date | Scope | Evidence |
|---|---|---|
| 2026-07-12 | Investigation baseline | Debug iPhone 17 simulator build succeeded; one concurrency warning recorded for COM-13. |

## Handoff Notes

- Read only the selected issue entry and named files after completing the required read order.
- Record newly discovered coupling here; do not silently enlarge the active issue.
- If an extraction changes behavior, stop and restore behavior before proceeding.
