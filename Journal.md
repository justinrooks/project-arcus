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

### 2026-03-03: UI casing consistency pass across all SwiftUI views

Bug-shaped problem:
Several views were forcing uppercase presentation (`.textCase(.uppercase)`, `uppercased()` labels, and all-caps badge text), which made the UI feel visually inconsistent across cards and chips.

What changed:
- Reviewed every `View`/`ViewModifier` file under `/Users/justin/Code/project-arcus/SkyAware/Sources`.
- Removed uppercase display transforms in summary headers, product headers, map legend headers, and alert section chips.
- Converted hardcoded all-caps UI strings to sentence case where they were stylistic (for example, `IN ZONE` -> `In zone`, `MD 123` -> `Meso 123`, `OK` -> `Ok` in diagnostics badges).
- Added a small risk-level formatter in `ConvectiveOutlookDetailView` to translate abbreviated risk tokens (`MRGL`, `SLGT`, `ENH`, `MDT`) into sentence-cased display labels.

Aha moment:
Uppercase can look "urgent," but when everything is urgent, nothing is. Sentence case improved scannability without changing layout or behavior.

Gotcha:
Not all uppercase text should be normalized. Domain acronyms and proper nouns (like NOAA/NWS/SPC/APNs) are intentional and were left intact.

### 2026-03-03: Atmosphere rail polish + Liquid Glass metric tiles

Bug-shaped problem:
`AtmosphereRailView` looked like a rough prototype next to the fire/storm/severe rails. It had raw stacked values, little hierarchy, and no cohesive chip treatment, so the section felt unfinished.

What changed:
- Rebuilt `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Badges/AtmosphereRailView.swift` to match the established badge/rail visual language:
  - clear lead icon chip
  - strong headline (`Atmospheric Snapshot`)
  - concise secondary summary line with update time
  - consistent 2-column metric tiles for dew point, humidity, wind, and pressure
- Added a small metric tile component with monospaced values and concise secondary context (wind direction, pressure trend).
- Grouped metric chips in `GlassEffectContainer` on iOS 26+ and kept fallback behavior through shared `skyAwareChip`.
- Stayed inside the existing risk-based color system by tinting surfaces from the current `FireRiskLevel` colors.

Aha moment:
Visual quality jumped once the rail stopped being “a row of numbers” and became “a headline plus scannable tiles.” Same data, way better cognitive ergonomics.

Gotcha:
Using random IDs inside metric `ForEach` would make tile identity unstable and cause unnecessary re-renders. Stable identity based on metric title keeps updates predictable.

### 2026-03-04: Dew point explainer tip on Atmosphere rail

Bug-shaped problem:
The dew point value was visually emphasized (orange + bold), but tapping it did nothing. We were effectively highlighting a mystery number with no built-in explanation.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Badges/AtmosphereRailView.swift` so the entire dew point tile is now a tappable button.
- Added a compact popover tip anchored to that tile with plain-language dew point guidance and a simple comfort scale.
- Added a typed metric identity (`AtmosphereMetricKind`) instead of relying on string comparisons for dew-point-specific styling/behavior.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Summary/SummaryView.swift` to re-enable interaction for the atmosphere rail after weather loads (`.allowsHitTesting(!isWeatherLoading)`), while still keeping loading-state behavior safe.

Aha moment:
If a metric is "important enough to color," it is usually "important enough to explain." A tiny inline explainer beats sending users to a full-screen glossary.

Gotcha:
The summary screen had interaction disabled for this rail, so even a perfectly wired button in the rail would never fire. Wiring the tap correctly required both local tile changes and parent-level hit-testing behavior.

### 2026-03-04: Atmosphere rail metric tiles switched to true Liquid Glass chips

Bug-shaped problem:
We wrapped the metrics in `GlassEffectContainer`, but each tile itself was still just plain content. In other words: we built a fancy glass display case and put cardboard labels inside it.

What changed:
- Refactored `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Badges/AtmosphereRailView.swift` metric tiles to render as real glass chips on iOS 26+ using `.glassEffect(...)` with a consistent rounded-rect shape.
- Kept fallback visuals for pre-iOS 26 using a material-backed rounded tile.
- Made the entire dew point tile the interaction surface and applied interactive glass only to that tile.
- Introduced light tinting derived from `FireRiskLevel.tint` so `level` is now meaningful and styling stays consistent with the existing risk palette.

Aha moment:
`GlassEffectContainer` only pays off when the children are actually glass. Once each metric became a chip, the whole section started behaving like one coherent surface instead of isolated text blocks.

Gotcha:
If only the value text is tappable, users miss the affordance. Making the whole dew point chip the tap target improved both usability and visual consistency.

### 2026-03-04: Atmosphere rail cleanup pass (API + tip robustness)

Bug-shaped problem:
The view had a couple of “leftover scaffold” patterns: a `GlassEffectContainer` without glass children, an unused `level` input, and dew-point tip logic that parsed numbers from display text.

What changed:
- Removed the inert `GlassEffectContainer` wrapper from `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Badges/AtmosphereRailView.swift`.
- Removed the unused `level` parameter from `AtmosphereRailView` and updated callsites/previews.
- Replaced dew point parsing-from-string with direct numeric plumbing (`numericValue`) so tip guidance is driven by real data, not formatted text.
- Updated `DewPointTipView` layout to a fixed-width non-scrolling popover so all explanatory text is visible at once.

Aha moment:
UI text formatting is presentation, not source-of-truth data. Once we stopped parsing the string, the tip logic became both safer and easier to reason about.

Gotcha:
“Looks fine right now” helper wrappers can quietly become dead code as the UI evolves. Small cleanup passes keep SwiftUI views honest and easier to maintain.

### 2026-03-04: Severe risk overlap ordering bug (2% beating 5% tornado)

Bug-shaped problem:
Some locations inside overlapping tornado probability polygons could show `2%` instead of `5%`. The app was pulling both, but when risk type tied (tornado vs tornado), selection order depended on fetch order.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Repos/SevereRiskRepo.swift` `active(asOf:for:)` sorting so it now ranks by:
  - threat type priority (tornado > hail > wind)
  - then probability (higher first)
  - then issuance recency (`issued`, `valid`, `expires`) for deterministic tie breaks
- Added `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/SevereRiskRepoActiveSelectionTests.swift` with regression coverage for:
  - overlapping tornado `2%` and `5%` polygons selecting `5%`
  - overlapping hail and wind polygons selecting the higher probability within each type
  - cross-type behavior staying intact (tornado still outranks hail per existing threat-priority rule)

Aha moment:
“Severity category” and “severity magnitude” are two different axes. We were sorting on category only, which is like ranking restaurants by cuisine but ignoring the actual rating.

Gotcha:
Any tie in your comparator is a hidden product decision. If that tie-breaker is implicit, users eventually discover it in the weirdest edge case.

### 2026-03-04: Parallel test flake from shared in-memory SwiftData containers

Bug-shaped problem:
`SevereRiskRepo` tests could fail in Xcode "run all tests" even when they passed in isolation. The root cause was shared in-memory `ModelContainer` reuse across test suites, which let concurrently running suites stomp on each other’s state.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/TestStore.swift` so `container(for:)` now returns a fresh in-memory container per call instead of caching by model key.

Aha moment:
In-memory test DB caching looks fast and harmless until parallel execution shows up. Determinism beats tiny setup savings in test infrastructure.

Gotcha:
`@Suite(.serialized)` only serializes within that suite. It does not protect you from other suites mutating the same shared store at the same time.

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
