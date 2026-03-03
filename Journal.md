# Journal.md

## 1) The Big Picture

SkyAware is the weather app version of that friend who texts you before the storm hits, not after. It pulls severe-weather signals from SPC and NWS, keeps an eye on your local risk, and tries to surface the useful stuff without forcing you to read a meteorology textbook. The goal is simple: fewer surprises, faster decisions.

## 2) Architecture Deep Dive

Think of the app like an airport control tower:
- Providers are radar feeds (SPC, NWS, WeatherKit, location).
- Repos are the flight strips where current truth is stored.
- Policies decide cadence (how often we should check the sky).
- Orchestrator is air traffic control: it coordinates refreshes, gates work, and triggers notifications.
- SwiftUI views are the departure board: they should display state clearly, not run the airport.

A key pattern here is separating "fetch/store logic" from "rendering logic." Views stay declarative; engines/providers/repos do real work.

## 3) The Codebase Map

- `/Users/justin/Code/project-arcus/SkyAware/Sources/App`
App lifecycle and dependency composition (`SkyAwareApp`, `Dependencies`, app delegate glue).

- `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers`
External data ingestion and sync paths (SPC, NWS, location).

- `/Users/justin/Code/project-arcus/SkyAware/Sources/Repos`
Persistence-facing repositories over SwiftData.

- `/Users/justin/Code/project-arcus/SkyAware/Sources/Features`
SwiftUI features/screens (home, onboarding, settings, diagnostics, maps, summary).

- `/Users/justin/Code/project-arcus/SkyAware/Sources/Notifications`
Notification pipeline pieces (rules, gates, composers, sender, and APNs registration coordinator).

- `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests`
Deterministic Swift Testing suites for policy, parsing, repo behavior, and utilities.

## 4) Tech Stack & Why

- SwiftUI
Fast iteration, clear declarative UI, and modern iOS-native patterns.

- Swift Concurrency (`async/await`)
Better cancellation and readability than callback pyramids.

- SwiftData
Native persistence with lightweight modeling and query ergonomics.

- OSLog
Structured logging that works in production and diagnostics tooling.

- BackgroundTasks
Essential for periodic refresh and notification relevance when the app is not foregrounded.

## 5) The Journey

### 2026-02-22: APNs registration integration

Bug-shaped problem:
Notification permission existed, but remote registration never happened, so no APNs device token was captured.

What changed:
- Added `/Users/justin/Code/project-arcus/SkyAware/Sources/Notifications/RemoteNotificationRegistrar.swift` to centralize:
  - permission request flow
  - `registerForRemoteNotifications()` calls
  - token formatting/storage (`apnsDeviceToken`)
- Added `/Users/justin/Code/project-arcus/SkyAware/Sources/App/SkyAwareAppDelegate.swift` to receive:
  - `didRegisterForRemoteNotificationsWithDeviceToken`
  - `didFailToRegisterForRemoteNotificationsWithError`
- Wired app lifecycle in `/Users/justin/Code/project-arcus/SkyAware/Sources/App/SkyAwareApp.swift` to register on active state when authorized.
- Wired onboarding/settings to use one shared registration path.
- Added unit tests for APNs token hex formatting.

Aha moment:
`UNUserNotificationCenter` authorization and APNs registration are two separate doors. Permission alone does not hand you a token; `registerForRemoteNotifications()` is the second key turn.

Gotcha:
"APNs key" and "APNs device token" are not the same thing.
- APNs Auth Key (`.p8`) is created in Apple Developer and used by your server.
- Device token is issued per app/device/environment and received on-device via app delegate callback.

### 2026-02-23: H3 phase 1 (location pipeline only)

Goal:
Adopt H3 in a low-risk way by enriching location snapshots with a stable H3 cell id, without changing existing polygon hit-testing logic yet.

What changed:
- Added SwiftyH3 package dependency to the app target.
- Extended `LocationSnapshot` with `h3Cell`.
- Added a `LocationHashing` seam with `SwiftyH3Hasher` default implementation.
- Updated `LocationProvider` to compute H3 during accepted location updates and background placemark refresh.
- Added unit test coverage for hash enrichment via injected mock hasher.

Why this phase works:
It gives us immediate value (consistent geospatial bucketing key for future server APIs) while avoiding a risky rewrite of core in-polygon detection in one jump.

Gotcha:
H3 is a coarse spatial index, not exact geometry truth. It is excellent for partitioning/filtering and fast lookup, but boundary-accurate containment still needs exact polygon checks unless we explicitly accept approximation tradeoffs.

### 2026-02-23: Surfaced H3 diagnostics in Settings

Goal:
Make the new H3 index visible in-app for fast validation, just like APNs token visibility helped validate push plumbing.

What changed:
- Wired `/Users/justin/Code/project-arcus/SkyAware/Sources/App/HomeView.swift` to pass the existing `LocationClient` into `SettingsView`.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Settings/SettingsView.swift` to:
  - read the latest location snapshot on appear
  - subscribe to location updates while Settings is visible
  - render `h3Cell` in the Onboarding Debug section as monospaced, selectable text

Why this helps:
Now we can quickly confirm H3 generation on real movement/device flows without attaching a debugger or digging through logs.

Gotcha:
The settings panel can only show an H3 value after at least one accepted location snapshot exists, so "No location hash yet" is expected on fresh launch or denied location access.

### 2026-02-23: Location snapshot server push pipeline

Goal:
Guarantee that every accepted location snapshot update can be forwarded to a backend endpoint from one consistent choke point in the pipeline.

What changed:
- Added runtime-configured endpoint support via `LOCATION_PUSH_URL` build setting -> `Info.plist` `LocationPushURL`.
- Added a location snapshot push payload that includes:
  - coordinates + accuracy
  - timestamp
  - placemark summary
  - `h3Cell`
  - APNs device token
- Added a queued `LocationSnapshotPusher` actor with retry behavior.
- Added `HTTPLocationSnapshotUploader` to POST JSON to the configured endpoint.
- Wired `LocationProvider.saveAndYieldSnapshot(...)` to enqueue push work every time a snapshot is saved.
- Wired `Dependencies.live()` to enable/disable this path based on whether endpoint config exists.

Why this helps:
By attaching push at `saveAndYieldSnapshot`, we avoid fragmented “did we remember to send here too?” logic. One gate, consistent behavior.

Gotcha:
If `LOCATION_PUSH_URL` is empty or invalid, pushing is intentionally disabled (no-op pusher), so local development keeps working without backend setup.

### 2026-02-23: Added NWS county/zone/fireZone to pushed location payload

Goal:
Enrich each pushed location snapshot with the currently resolved NWS region identifiers so backend workflows can join location updates to county/zone-level alert logic immediately.

What changed:
- Added an actor-safe `NwsGridRegionContext` cache in `/Users/justin/Code/project-arcus/SkyAware/Sources/Repos/NwsMetadataRepo.swift`.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/NWS/GridPointProvider.swift` to refresh that cache whenever a new `GridPointSnapshot` is resolved.
- Extended `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/Location/LocationProvider.swift` push payload with:
  - `county`
  - `zone`
  - `fireZone`
- Wired `/Users/justin/Code/project-arcus/SkyAware/Sources/App/Dependencies.swift` so `LocationSnapshotPusher` reads region context from `NwsMetadataRepo` at enqueue time.
- Expanded `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/LocationProviderTests.swift` to assert these fields are included in the uploaded payload.

Why this helps:
The backend now receives both a coarse spatial key (`h3Cell`) and the NWS operational region IDs in the same event, which reduces lookup work and keeps event processing deterministic.

Gotcha:
These region fields are optional and depend on recent gridpoint resolution, so early app lifecycle events may legitimately send `null` values until NWS metadata has been fetched.

### 2026-02-23: Added stable installation identity for server payloads

Goal:
Give backend ingestion a stable per-install identity that survives APNs token rotation, while still shipping the current APNs token for push delivery.

What changed:
- Added Keychain-backed installation identity creation/lookup in `/Users/justin/Code/project-arcus/SkyAware/Sources/Notifications/RemoteNotificationRegistrar.swift`.
- Bootstrapped identity on app activation in `/Users/justin/Code/project-arcus/SkyAware/Sources/App/SkyAwareApp.swift`.
- Extended `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/Location/LocationProvider.swift` payload with `installationId`.
- Surfaced Installation ID in Settings diagnostics at `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Settings/SettingsView.swift`.
- Added tests in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/RemoteNotificationRegistrarTests.swift` and updated payload assertions in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/LocationProviderTests.swift`.

Why this helps:
`installationId` now acts like the durable mailing address label on the package, while APNs token remains the route-of-the-day. The server can upsert by installation and treat token updates as normal churn.

Gotcha:
If Keychain persistence fails (rare, but possible), the app still generates an in-memory ID for that launch so payloads keep flowing. It just won’t be stable across relaunch until persistence succeeds.

### 2026-03-02: Map "time travel" bug in risk layers (old + new polygons together)

Bug-shaped problem:
The map could show overlapping historical and current polygons at the same time (especially noticeable in fire risk), because active-window filtering alone does not guarantee "latest issuance only."

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Repos/FireRiskRepo.swift` so `getLatestMapData` now:
  - buckets by `riskLevel`
  - keeps only the freshest record per bucket (prefers newer `issued`, then `valid`, then `expires`)
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Repos/StormRiskRepo.swift` to use the same recency tie-breaker (it previously preferred `valid`, which is often identical across issuances).
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Repos/SevereRiskRepo.swift` to dedupe by true display bucket (`type + probability`) instead of `type + key` (where `key` already includes `issued`, which accidentally preserves old versions).
- Added regression tests in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/MapDataFreshnessRepoTests.swift` for fire, storm, and severe map products.

Aha moment:
“Active right now” and “latest version” are different filters. Think of it like airport departure boards: two gate updates can both be valid timestamps, but only one is the current truth.

Gotcha:
Using `valid` as the primary freshness signal is brittle for SPC products because updates can share the same valid window. `issued` is the better primary key for recency.

## 6) Engineer's Wisdom

- Keep lifecycle side effects out of SwiftUI view `body`.
Use an app delegate bridge for push callbacks; keep views focused on rendering.

- Centralize permission + registration logic.
When multiple screens can request notification access, one coordinator prevents drift.

- Log intent, not noise.
Log when registration is attempted and why (`scene-active`, `permission-request`), then future debugging gets much easier.

- Test small pure pieces aggressively.
A tiny token-formatting test catches easy-to-miss backend integration bugs early.

## 7) If I Were Starting Over...

- I would define a typed `AppSettings` key registry early instead of raw string keys scattered across files.
- I would add a lightweight diagnostics panel for permission status + APNs token from day one.
- I would establish one canonical "notifications bootstrap" path at app launch to avoid behavior fragmentation across onboarding, settings, and background flows.
