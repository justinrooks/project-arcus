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

Status: Pending

### COM-04 / GitHub #293 - Split home refresh pipeline tests and fakes

Status: Pending

### COM-05 / GitHub #294 - Split map feature model tests and fakes

Status: Pending

### COM-06 / GitHub #295 - Split mixed SPC and repository sync tests

Status: Pending

### COM-07 / GitHub #296 - Decompose Primary Awareness presentation files

Status: Pending

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
