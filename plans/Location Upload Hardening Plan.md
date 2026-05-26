# Location Upload Hardening Plan

## Purpose

SkyAware depends on fresh server-side location registration for accurate, timely Arcus Signal notifications. The current pipeline usually works, but it mixes context resolution, upload side effects, preference synchronization, and ingestion orchestration in ways that make reliability hard to reason about and hard to test.

This plan breaks the hardening work into reviewable sub-issues. Each sub-issue should be sized for Codex 5.3 medium and should leave the app compiling with focused unit tests.

## Current Architecture Summary

- `LocationManager` owns Core Location mode transitions:
  - active scenes use live foreground updates
  - background scenes with Always authorization use significant-location-change monitoring
- `LocationProvider` accepts, throttles, hashes, caches, and placemark-enriches raw location updates.
- `LocationSession` stores `currentSnapshot` and `currentContext`.
- `HomeIngestionCoordinator` serializes foreground, background, location-change, and remote-alert ingestion.
- `HomeIngestionExecutor` resolves a `LocationContext` based on the trigger's `HomeIngestionLocationRequest`.
- `LocationContextResolver.resolveContext(...)` enriches a snapshot, resolves grid metadata, creates `LocationContext`, and currently enqueues an upload as a side effect.
- `LocationSnapshotPusher` builds `LocationSnapshotPushPayload`, gates on APNs token and `sendL8ntoSignal`, then uploads with in-memory retries.

## Critical Findings To Address

1. Background significant-location-change ingestion can use stale `currentContext`.
   - `.backgroundLocationChange` maps to `.currentPrepared`.
   - `HomeIngestionExecutor` immediately returns existing `currentContext`.
   - The freshly accepted SLC snapshot may not become the context used for server upload, alert sync, or watch evaluation.

2. Context resolution has an implicit upload side effect.
   - Any successful `resolveContext(...)` enqueues upload.
   - This makes call sites harder to reason about, causes duplicate uploads, and makes tests assert incidental behavior.

3. Preference updates can double enqueue.
   - `pushServerNotificationPreferenceUpdate(...)` resolves missing context, which already enqueues, then explicitly enqueues again.

4. Upload retry is memory-only.
   - After `[0, 5, 15]` seconds, failed uploads are lost.
   - Missing APNs token also drops the attempt permanently.

5. Preference synchronization is coupled to location upload.
   - Disabling sharing uses `forceUpload: true` with a full location payload.
   - This may be deliberate for unregister semantics, but it is privacy-sensitive and operationally muddy.

6. Server diagnostics are weak.
   - Payload `source` is always `"unknown"`.
   - Upload attempts do not expose a stable reason/source/result model that can be unit tested or logged consistently.

## Target Architecture

### Design Goals

- Resolve location context explicitly.
- Push location explicitly.
- Never let a background location-change flow use stale context.
- Make every upload attempt traceable by source and reason.
- Persist retry intent across transient failures, APNs token delays, launches, and background refreshes.
- Keep SwiftUI views thin; UI should trigger app services, not encode upload policy.
- Preserve privacy controls and make opt-out semantics obvious.
- Keep implementation incremental and testable.

### Proposed Shape

Introduce a small upload orchestration layer:

```swift
enum LocationUploadSource: String, Sendable, Codable {
    case foregroundPrime
    case foregroundActivate
    case foregroundLocationChange
    case manualRefresh
    case backgroundRefresh
    case backgroundLocationChange
    case onboarding
    case settingsPreference
    case apnsTokenRefresh
    case retry
}

enum LocationUploadReason: String, Sendable, Codable {
    case locationResolved
    case locationChanged
    case preferenceChanged
    case tokenBecameAvailable
    case retry
}

struct LocationUploadRequest: Sendable, Codable, Equatable {
    let context: LocationContext
    let source: LocationUploadSource
    let reason: LocationUploadReason
    let forceUpload: Bool
    let requestedAt: Date
}
```

`LocationContextResolver` should only resolve context. A dedicated `LocationUploadCoordinator` or hardened `LocationSnapshotPusher` API should accept explicit upload requests, deduplicate them, persist pending work, and produce testable outcomes.

Do not overbuild this. The goal is a clear seam, not a distributed system cosplay.

## Implementation Sequence

### Issue 1: Add Characterization Tests And Flow Matrix

Goal: lock down current behavior before changing architecture.

Scope:
- Add unit tests around `HomeIngestionPlan` location request mapping.
- Add tests proving `.backgroundLocationChange` currently returns existing `currentContext`.
- Add tests proving foreground fresh prepare resolves and enqueues.
- Add tests proving `pushServerNotificationPreferenceUpdate(...)` can double enqueue when resolving from snapshot.
- Add tests proving missing APNs token drops upload.
- Add a short markdown flow matrix under `plans/` or `docs/architecture/` if useful.

Validation:
- Run the smallest relevant Swift Testing suite, likely `LocationManagerTests`, `LocationProviderTests`, `HomeIngestionCoordinatorTests`, and `HomeRefreshPipelineTests`.

Acceptance Criteria:
- Tests demonstrate the current failure mode without changing production behavior.
- Tests use fakes/stubs, no live network, no Core Location dependency.
- No production code changes unless needed for test access and justified.

### Issue 2: Fix Background Significant-Location-Change Freshness

Goal: make background SLC ingestion resolve and push the fresh accepted snapshot, not stale `currentContext`.

Recommended implementation:
- Add a location request mode that resolves from the latest snapshot even when a current context exists, for example:
  - `HomeIngestionLocationRequest.prepare(requiresFreshLocation: false, showsAuthorizationPrompt: false, preferCurrentContext: false)`, or
  - `HomeIngestionLocationRequest.resolveCurrentSnapshot(maximumAcceptedLocationAge:)`
- Map `.backgroundLocationChange` to this stronger request.
- Consider mapping `.foregroundLocationChange` similarly if the current context is stale relative to the new snapshot.
- Keep `.sessionTick`, remote-alert paths, and low-risk refreshes on `.currentPrepared`.

Validation:
- Add a unit test where `currentContext` is old, `currentSnapshot` has a new H3, and `.backgroundLocationChange` uses the new context.
- Add a unit test that watch/background ingestion receives the new location snapshot.
- Add a unit test that `.sessionTick` still reuses current prepared context.

Acceptance Criteria:
- Background SLC never short-circuits to stale context when a newer accepted snapshot exists.
- Existing foreground/timer behavior does not become more chatty by accident.

### Issue 3: Make Context Resolution Side-Effect Free

Goal: separate `LocationContextResolver` from upload policy.

Recommended implementation:
- Remove `contextPusher.enqueue(context)` from `LocationContextResolver.resolveContext(...)`.
- Add explicit upload calls at the orchestration points that should publish location.
- Introduce a narrow protocol, such as:

```swift
protocol LocationUploadCoordinating: Sendable {
    func enqueue(_ request: LocationUploadRequest) async
}
```

- Keep `LocationContextResolver` focused on:
  - authorization
  - snapshot freshness
  - placemark enrichment
  - H3 and grid metadata validation

Validation:
- Update resolver tests to assert resolution returns context but does not push by itself.
- Add executor/session tests proving intended triggers explicitly enqueue upload.
- Add tests proving preference update does not double enqueue.

Acceptance Criteria:
- No hidden upload side effects remain in context resolution.
- Every upload call site carries explicit `source`, `reason`, and `forceUpload`.

### Issue 4: Add Upload Deduplication And Source Attribution

Goal: avoid redundant uploads while preserving reliability.

Recommended implementation:
- Include `source` in `LocationSnapshotPushPayload` instead of `"unknown"`.
- Deduplicate upload requests by semantic key:
  - installation ID
  - APNs token
  - H3 cell
  - county
  - fire zone
  - forecast zone
  - subscription state
  - authorization state
  - force flag
- Use a short dedupe window for non-forced uploads.
- Never dedupe forced preference/unsubscribe uploads unless the full semantic key and preference state are identical.

Validation:
- Unit test foreground prime + follow-up coalescing.
- Unit test different H3/county/fire zone is not deduped.
- Unit test preference state changes are not deduped.
- Unit test payload `source` matches request source.

Acceptance Criteria:
- Repeated identical location resolution does not spam the server.
- Meaningful location/preference changes still upload immediately.

### Issue 5: Persist Pending Uploads And Retry Intents

Goal: make upload delivery survive transient failures, app suspension, relaunch, and missing APNs token.

Recommended implementation:
- Add a small persistence abstraction:

```swift
protocol LocationUploadQueueStoring: Sendable {
    func loadPendingRequests() async -> [PersistedLocationUploadRequest]
    func savePendingRequests(_ requests: [PersistedLocationUploadRequest]) async
}
```

- Store minimal pending upload requests, not arbitrary runtime state.
- Back with app-group `UserDefaults` or a small JSON file in app support/app group. Prefer the simplest implementation that is deterministic in tests.
- Persist requests when:
  - APNs token is missing
  - network upload fails after immediate retry budget
  - upload is cancelled
- Drain pending requests on:
  - foreground activation
  - background refresh start
  - APNs token registration
  - settings preference update

Validation:
- Unit test missing APNs token persists request.
- Unit test token arrival drains pending request.
- Unit test network failure persists request.
- Unit test successful retry removes request.
- Unit test queue preserves latest meaningful location while coalescing obsolete duplicates.

Acceptance Criteria:
- No upload attempt disappears solely because token/network was temporarily unavailable.
- Queue behavior is deterministic and fully fakeable in unit tests.

### Issue 6: Split Preference Synchronization From Location Snapshot Upload

Goal: make server subscription/privacy state explicit.

Recommended implementation:
- Add a dedicated registration/preferences request path if server support exists or can be added:
  - installation ID
  - APNs token
  - server notification enabled
  - location upload enabled
  - authorization state
  - app/build/environment
- If server API is not ready, isolate the current forced full-location upload behind a named adapter with a TODO and tests.
- Update settings/onboarding call sites so UI toggles call semantic methods:
  - `syncNotificationPreference(...)`
  - `syncLocationSharingPreference(...)`
  - `enqueueCurrentLocationUpload(...)`

Validation:
- Unit test disabling location sharing does not accidentally enqueue a normal location upload.
- Unit test unsubscribe/preference sync still reaches server even when `sendL8ntoSignal` is false.
- Unit test enabling sharing requests upload only after context/token requirements are satisfied or queues pending work.

Acceptance Criteria:
- Preference sync semantics are understandable from method names.
- Privacy-sensitive forced upload behavior is either removed or explicitly contained.

### Issue 7: Wire Token And Lifecycle Drains

Goal: close the obvious retry triggers.

Recommended implementation:
- Inject upload coordinator into `RemoteNotificationRegistrar` or notify a narrow callback when token changes.
- On APNs token storage, drain pending uploads and enqueue current context if appropriate.
- On scene active, drain pending uploads after token registration attempt.
- On background refresh, drain pending uploads before/after fresh context resolution.
- Avoid doing live service work directly in SwiftUI `body`; keep lifecycle actions in app/session services.

Validation:
- Unit test APNs token callback fires once per stored token.
- Unit test scene-active registration path triggers queue drain through a fake coordinator.
- Unit test no drain occurs when notifications are denied and no token exists, except persisted work remains queued.

Acceptance Criteria:
- Token arrival no longer leaves previous upload attempts stranded.
- Lifecycle drains are idempotent and testable.

### Issue 8: Add Diagnostics And Final End-To-End Validation

Goal: make the hardened pipeline observable and prove the target flows.

Recommended implementation:
- Add structured logs for upload request accepted/skipped/deduped/persisted/drained/succeeded/failed.
- Consider a lightweight diagnostics model for Settings diagnostics if existing patterns fit.
- Add end-to-end unit tests with fakes for:
  - foreground activation
  - manual refresh
  - foreground location change
  - background app refresh
  - background significant-location change
  - onboarding with delayed APNs token
  - settings opt in/out
  - network failure then retry

Validation:
- Run focused unit tests.
- Run full unit test suite if feasible.
- Build the app.
- Inspect any `.xcresult` if test execution creates one.

Acceptance Criteria:
- Each critical path has deterministic unit coverage.
- Logs identify why an upload did or did not happen without exposing sensitive location details.
- App compiles cleanly.

## Recommended Test Matrix

| Flow | Expected Upload Behavior | Required Tests |
| --- | --- | --- |
| Foreground activation | Fresh context resolved and upload requested once after dedupe | prime/follow-up dedupe, source attribution |
| Manual refresh | Fresh context resolved and upload requested | explicit source/reason |
| Foreground timer | Reuses current context; upload only if context must be resolved | no redundant upload |
| Foreground location change | New accepted H3 resolves new context and uploads | new H3/new refresh key |
| Background app refresh | Fresh context requested; upload queued or sent | background source, no prompt |
| Background SLC | Fresh accepted snapshot resolves new context; upload requested | stale-context regression test |
| Onboarding | waits for APNs token when possible; queues if missing | delayed token drain |
| Settings enable server notifications | preference sync and current location upload if allowed | no duplicate enqueue |
| Settings disable location sharing | preference sync survives location-upload gate | privacy/force semantics |
| Network failure | persisted and retried later | retry persistence |

## Non-Goals

- Do not redesign alert sync, SPC sync, or WeatherKit refresh policy.
- Do not introduce a database if a small deterministic queue store is sufficient.
- Do not add broad UI redesign work.
- Do not add live-network tests.
- Do not rely on background execution being guaranteed by iOS.

## Execution Notes For Agents

- Read `AGENTS.md`, `Sources/AGENTS.md`, and this plan before starting.
- Use Swift Testing (`import Testing`) for unit tests.
- Prefer protocol seams and fakes over live system services.
- Keep each issue small and reviewable.
- Run the smallest relevant tests before finishing.
- Unit tests must also be validated in Xcode Cloud before considering implementation work fully done. Local focused tests are necessary for fast iteration, but Xcode Cloud is the source-of-truth validation environment for this hardening effort.
- Do not claim a build or test passed unless it was actually run.
- Treat `LocationContextResolver` and `LocationSnapshotPusher` as high-risk seams; avoid unrelated refactors.
- For any SwiftUI/lifecycle-facing change, follow the SwiftUI Expert and SwiftUI UI Patterns guidance:
  - keep views thin
  - use environment-injected services intentionally
  - keep async lifecycle work in `.task`, `onChange`, app/session services, or injected coordinators
  - avoid deprecated SwiftUI APIs

## GitHub Issue Breakdown

Parent issue:
- Location upload hardening and reliability

Sub-issues:
1. Characterize current location upload flows with tests
2. Fix background significant-location-change context freshness
3. Make location context resolution side-effect free
4. Add upload deduplication and source attribution
5. Persist pending uploads and retry intents
6. Split preference sync from location snapshot upload
7. Wire APNs token and lifecycle queue drains
8. Add diagnostics and end-to-end validation coverage

Each sub-issue should include:
- Target agent: Codex 5.3 medium
- Scope
- Acceptance criteria
- Validation commands
- Link back to this plan
