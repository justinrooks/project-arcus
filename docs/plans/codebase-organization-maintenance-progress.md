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
| 1 | COM-01 | [#290](https://github.com/justinrooks/project-arcus/issues/290) | Extract Summary preview galleries | Pending | GPT-5.6 Luna / medium |
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

Status: Pending

### COM-02 / GitHub #291 - Split Home and Summary state test suites

Status: Pending

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
