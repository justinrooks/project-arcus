# Location Hardening Progress

## Current Status

The location upload hardening implementation has completed the original #179-#186 sequence and received an
end-to-end validation review. The review found the architecture materially improved, but not ready to call complete
until the follow-up findings below are addressed.

Primary plan:
- `plans/Location Upload Hardening Plan.md`

GitHub tracking:
- Parent: https://github.com/justinrooks/project-arcus/issues/178
- Project: Project Arcus
- Labels applied to parent and all sub-issues: `iOS`, `feature`

Validation status from review:
- Focused location/upload/ingestion/registrar suites passed locally: 91 passed, 0 failed.
- Full `SkyAwareTests` failed locally: 426 passed, 1 failed in `RemoteNotificationRegistrarTests/storeDeviceToken_notifiesObserverOncePerStoreEvent`.
- Xcode Cloud validation remains pending until the full unit target is green.

## Issue Map

| Issue | Title | Status | Notes |
| --- | --- | --- | --- |
| #178 | Location upload hardening and reliability | Open | Parent issue with native GitHub sub-issues linked. |
| #179 | Characterize current location upload flows with tests | Completed | Original characterization slice. |
| #180 | Fix background significant-location-change context freshness | Completed | Background SLC now maps to latest accepted snapshot preparation. |
| #181 | Make location context resolution side-effect free | Completed | Uploads are no longer resolver side effects. |
| #182 | Add location upload deduplication and source attribution | Completed | Source attribution and dedupe are implemented; reason attribution remains #191. |
| #183 | Persist pending location uploads and retry intents | Completed with follow-up | Missing-token and retry persistence are implemented; cancellation backoff follow-up is #190. |
| #184 | Split preference sync from location snapshot upload | Completed with follow-up | Legacy adapter remains; opt-out/no-context gap is #187 and duplicate enable path is #189. |
| #185 | Wire APNs token and lifecycle upload queue drains | Completed | Token, scene-active, and background-refresh drains are wired. |
| #186 | Add location upload diagnostics and end-to-end validation coverage | Completed with follow-up | Focused suites pass; full unit target failure is #188 and H3 logging cleanup is #192. |

## Final Review Follow-Up Issue Map

| Issue | Severity | Title | Status | Notes |
| --- | --- | --- | --- | --- |
| #187 | P1 | Ensure opt-out preference sync cannot be dropped without location context | Created | `LocationSession` currently drops legacy preference sync when no context/snapshot can be resolved. |
| #188 | P1 | Make RemoteNotificationRegistrar token observer test deterministic under full unit runs | Created | Full unit run failed due to a timing-sensitive observer assertion. |
| #189 | P2 | Avoid duplicate Settings location-sharing enable uploads | Created | Settings enable-sharing path can call both legacy preference sync and normal current-location upload. |
| #190 | P2 | Respect cancellation during location upload retry backoff | Created | Retry backoff uses `try? Task.sleep`, swallowing cancellation and continuing upload attempts. |
| #191 | P2 | Add reason attribution to location upload requests | Created | Upload model has source/force but lacks the planned reason semantics. |
| #192 | P3 | Stop logging raw H3 cells on location upload success | Created | `HTTPLocationSnapshotUploader` logs raw H3 cell values publicly. |

## Key Findings To Preserve

- Background significant-location-change ingestion currently maps to `.currentPrepared`, so it can reuse stale `LocationSession.currentContext` even after Core Location delivered a new background update.
- `LocationContextResolver.resolveContext(...)` currently enqueues upload as a side effect.
- `LocationSession.pushServerNotificationPreferenceUpdate(...)` can double enqueue when it resolves from `currentSnapshot`, because resolution already enqueues and the method then explicitly enqueues.
- `LocationSnapshotPusher` skips upload when APNs token is missing, and that skipped attempt is not persisted.
- Upload retry is in-memory only.
- Payload `source` is currently `"unknown"`.
- Settings preference sync and location snapshot upload are coupled through `forceUpload`, especially when disabling location sharing.
- Final review finding: opt-out/preference sync must not be dropped when no current location context exists.
- Final review finding: token observer tests must be deterministic under full-suite contention.
- Final review finding: Settings enable-sharing should not emit duplicate legacy location payloads.
- Final review finding: upload retry backoff must respect cancellation.
- Final review finding: upload requests need reason attribution, not only source attribution.
- Final review finding: upload success logs must not expose raw H3 cells.

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

Relevant test files for the hardening and follow-up issues:
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

- `plans/Location Upload Hardening Plan.md` tracks the original hardening plan plus final validation follow-ups.
- `plans/LocationHardeningProgress.md` tracks issue status, review findings, and validation evidence.
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

Address the final review follow-up issues before considering #178 complete:
- #187: Ensure opt-out preference sync cannot be dropped without location context.
- #188: Make the APNs token observer test deterministic and restore full-unit validation.
- #189: Avoid duplicate Settings location-sharing enable uploads.
- #190: Respect cancellation during upload retry backoff.
- #191: Add upload reason attribution.
- #192: Stop logging raw H3 cells.
