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
