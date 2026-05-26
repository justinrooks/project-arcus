# Location Hardening Progress

## Current Status

Created the durable implementation plan and GitHub tracking structure for the location upload hardening work.

Primary plan:
- `plans/Location Upload Hardening Plan.md`

GitHub tracking:
- Parent: https://github.com/justinrooks/project-arcus/issues/178
- Project: Project Arcus
- Labels applied to parent and all sub-issues: `iOS`, `feature`

No production code has been changed for this initiative yet.

## Issue Map

| Issue | Title | Status | Notes |
| --- | --- | --- | --- |
| #178 | Location upload hardening and reliability | Created | Parent issue with native GitHub sub-issues linked. |
| #179 | Characterize current location upload flows with tests | Ready | First implementation issue. Add tests only unless minimal test seam changes are justified. |
| #180 | Fix background significant-location-change context freshness | Pending | Depends on characterization coverage from #179. |
| #181 | Make location context resolution side-effect free | Pending | Should happen after SLC freshness is locked down. |
| #182 | Add location upload deduplication and source attribution | Pending | Depends on explicit upload seam from #181. |
| #183 | Persist pending location uploads and retry intents | Pending | Depends on upload request model/dedupe semantics. |
| #184 | Split preference sync from location snapshot upload | Pending | May need server contract decision. Keep adapter if backend endpoint is not ready. |
| #185 | Wire APNs token and lifecycle upload queue drains | Pending | Depends on persisted queue and coordinator seam. |
| #186 | Add location upload diagnostics and end-to-end validation coverage | Pending | Final hardening and verification pass. |

## Key Findings To Preserve

- Background significant-location-change ingestion currently maps to `.currentPrepared`, so it can reuse stale `LocationSession.currentContext` even after Core Location delivered a new background update.
- `LocationContextResolver.resolveContext(...)` currently enqueues upload as a side effect.
- `LocationSession.pushServerNotificationPreferenceUpdate(...)` can double enqueue when it resolves from `currentSnapshot`, because resolution already enqueues and the method then explicitly enqueues.
- `LocationSnapshotPusher` skips upload when APNs token is missing, and that skipped attempt is not persisted.
- Upload retry is in-memory only.
- Payload `source` is currently `"unknown"`.
- Settings preference sync and location snapshot upload are coupled through `forceUpload`, especially when disabling location sharing.

## Relevant Files

- `Sources/Infrastructure/Location/LocationContextResolver.swift`
- `Sources/Infrastructure/Location/LocationSession.swift`
- `Sources/Infrastructure/Location/LocationSnapshotPusher.swift`
- `Sources/Infrastructure/Location/HTTPLocationSnapshotUploader.swift`
- `Sources/Infrastructure/Location/LocationManager.swift`
- `Sources/Providers/Location/LocationProvider.swift`
- `Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
- `Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift`
- `Sources/App/HomeRefreshPipeline.swift`
- `Sources/Features/Background/BackgroundOrchestrator.swift`
- `Sources/Features/Background/BackgroundLocationChangeHandler.swift`
- `Sources/Features/Settings/SettingsView.swift`
- `Sources/Features/Onboarding/OnboardingView.swift`
- `Sources/Notifications/RemoteNotificationRegistrar.swift`

## Relevant Tests

Likely test files for the first few issues:
- `Tests/UnitTests/LocationProviderTests.swift`
- `Tests/UnitTests/LocationManagerTests.swift`
- `Tests/UnitTests/HomeIngestionCoordinatorTests.swift`
- `Tests/UnitTests/HomeRefreshPipelineTests.swift`
- `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`
- `Tests/UnitTests/AlertNotificationTests.swift`
- `Tests/UnitTests/RemoteNotificationRegistrarTests.swift`

## Validation Expectations

Use focused Swift Testing runs for each issue. Do not claim tests passed unless they were run.

Preferred local simulator guidance from `AGENTS.md`:
- iPhone 17 or iPhone 17 Pro where available.

Example focused commands from the parent plan:
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/LocationManagerTests test`
- `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:SkyAwareTests/LocationProviderTests test`

If a test run creates an `.xcresult`, inspect failures before reporting status.

## Working Tree Notes

At the time this progress document was created:
- `plans/Location Upload Hardening Plan.md` is new from this effort.
- `plans/LocationHardeningProgress.md` is new from this effort.
- `docs/audits/weekly-contract-drift-audit.md` was already modified before this planning work and should not be touched unless a later task explicitly requires it.

## Quality Guidance

Agents should follow:
- `AGENTS.md`
- `Sources/AGENTS.md`
- `plans/Location Upload Hardening Plan.md`
- SwiftUI Expert guidance when lifecycle or SwiftUI-facing code is touched.
- SwiftUI UI Patterns guidance when Settings, onboarding, app lifecycle, or environment-injected services are touched.

Keep views thin. Put upload policy in testable services/coordinators, not SwiftUI body logic.

## Next Step

Start with issue #179:
- https://github.com/justinrooks/project-arcus/issues/179

Objective:
- Add characterization tests for current location upload behavior before changing production semantics.

Important constraint:
- #179 should not fix the behavior yet. It should prove and document the current behavior so #180 and later changes can be made with confidence.
