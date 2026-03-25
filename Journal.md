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

### 2026-03-25: The cancelled watch that politely refused to leave

Bug-shaped problem:
Yesterday's Arcus fix got halfway to the finish line. We stopped *inserting* cancelled payloads, which is good, but `WatchRepo.refresh` still had the memory of an elephant and the delete instincts of a goldfish. If a watch was already stored from an earlier active revision, a later `Cancel` payload would be ignored instead of evicting the old record. Result: a dead watch could keep haunting the app until its original `ends` time expired.

What changed:
- Updated [/Users/justin/.codex/worktrees/08ad/project-arcus/SkyAware/Sources/Repos/WatchRepo.swift](/Users/justin/.codex/worktrees/08ad/project-arcus/SkyAware/Sources/Repos/WatchRepo.swift) so refreshes first identify Arcus payloads that should no longer persist, delete matching stored watches by series id, and only then upsert the still-active ones.
- Extended [/Users/justin/.codex/worktrees/08ad/project-arcus/SkyAware/Tests/UnitTests/WatchRepoRefreshTests.swift](/Users/justin/.codex/worktrees/08ad/project-arcus/SkyAware/Tests/UnitTests/WatchRepoRefreshTests.swift) with a regression case that starts with a persisted active watch, feeds in a cancellation revision, and proves the repo no longer returns that watch as active.

Aha moment:
Filtering and reconciliation are cousins, not twins. "Don't add the bad thing" sounds right until you remember the bad thing might already be sitting in your database eating snacks.

Gotcha:
Any feature that treats `refresh` like a full truth sync needs to think in both directions: what's new to insert, and what is now false enough to delete. Otherwise stale data gets nine lives for free.

### 2026-03-24: The case of the watch that was updated but refused to say so

Bug-shaped problem:
After the Arcus watch migration, the detail screen checked for `"UPDATE"` while the live payloads and preview fixtures said `"Update"`. That meant revised watches walked into the UI wearing an update badge invisibility cloak. At the same time, the repo was trusting every decoded Arcus payload with valid timestamps, even though the contract already says alerts can arrive in `Cancelled` state.

What changed:
- Added a case-insensitive `isUpdateMessage` helper in `/Users/justin/Code/project-arcus/SkyAware/Sources/Models/Watches/WatchRowDTO.swift`.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Alert/WatchDetailView.swift` to use that helper instead of a hard-coded uppercase comparison.
- Hardened `/Users/justin/Code/project-arcus/SkyAware/Sources/Repos/WatchRepo.swift` to skip non-active and cancel-type Arcus payloads before they ever hit persistence.
- Added regression coverage in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/WatchRowDTOTests.swift` and `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/WatchRepoRefreshTests.swift`.

Aha moment:
String casing bugs are the software equivalent of a fake mustache. The data is technically the same person, but the guard at the door still says, "Never seen them before." Normalizing the message type at the edge keeps display code from playing guess-the-capitalization.

Gotcha:
Time-window checks are necessary, but not sufficient. If an upstream system sends a cancellation with a still-future `ends` value, date math alone will happily keep a dead alert shambling around the app like a weather zombie.

### 2026-03-20: Added an on-device cache eject button for network debugging

Bug-shaped problem:
When simulator and physical-device behavior disagree, "same endpoint" is not enough evidence. A cached body can make two runs look like twins from across the room while one of them is quietly replaying yesterday's weather.

What changed:
- Wired the `Clear Cache` action in `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Diagnostics/DiagnosticsView.swift`.
- The button now clears `URLCache.shared`, which is the same shared cache installed in live dependencies for network traffic.

Aha moment:
ETag and HTTP caching are like a very eager intern who keeps handing you the last report because it "looked close enough." Most of the time that is great. During payload forensics, it is maddening. A one-tap cache reset turns the investigation back into a science experiment instead of a ghost story.

Gotcha:
Clearing the cache guarantees the next request is not served from the app's stored `URLCache`, but it does not magically fix server-side differences. If the next response is still weird, the problem moved from "stale local copy" to "real live payload."

### 2026-03-20: The missing `ugc` mystery that was really a contract mismatch

Bug-shaped problem:
`WatchRepo.refresh(...)` was throwing a parsing error on the decode line with `Missing key 'ugc'`. At first glance it looked like the repo was broken, but the real culprit was one layer upstream: `DeviceAlertPayload` treated `ugc` as mandatory even though Arcus can send cell-based alert matches without that field. Classic detective-story twist: the body was in the repo, but the murder happened in the model.

What changed:
- Relaxed `/Users/justin/Code/project-arcus/SkyAware/Sources/Models/Watches/DeviceAlertPayload.swift` so `ugc` and `h3Cells` can be absent in the incoming JSON.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Repos/WatchRepo.swift` to normalize missing geo arrays to empty arrays when building `Watch` models.
- Fixed local filtering so a watch can match by H3 cell even when `ugcZones` is empty.
- Added regression coverage in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/DeviceAlertPayloadTests.swift` and `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/WatchRepoActiveTests.swift`.

Aha moment:
There are two very different questions hidden in one payload:
1. "Can I decode this record?"
2. "Does this record apply to the current location?"

We were accidentally answering the second question during decoding by requiring `ugc` up front. That is like refusing to open a package because the shipping label is smudged, even though the GPS tracker inside is working fine.

Gotcha:
Even after decoding was fixed, the repo still had a trapdoor: it immediately skipped any watch with empty `ugcZones`, which meant cell-only matches would quietly vanish. When data can match through multiple geospatial paths, the filter logic has to respect all of them, not just the old county-zone route.

### 2026-03-18: The fake empty payload trap in Arcus alert fetching

Bug-shaped problem:
When the app tried to fetch Arcus alerts before an `h3Cell` existed, the client returned `Data()`. That made a request precondition problem dress up like a JSON parsing failure, which is the software equivalent of blaming the waiter when the kitchen never got the ticket.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Clients/ArcusClient.swift` to throw a real request error when `h3Cell` is missing instead of returning an empty payload.
- Added a dedicated `missingH3Cell` case and localized messaging in `/Users/justin/Code/project-arcus/SkyAware/Sources/Utilities/Core/SkyAwareErrors.swift`.

Aha moment:
Empty data is not a neutral fallback. It is a disguise. Once the client throws the right error at the boundary, the rest of the pipeline stops inventing a parsing mystery that never happened.

Gotcha:
This kind of bug is sneaky because logs make it look like "the server sent junk" when the real issue is "we asked too early." Guarding preconditions with explicit errors keeps debugging short and sane.

### 2026-03-09: Networking got faster, calmer, and less chatty

Bug-shaped problem:
Data refreshes could feel slow under normal load and brittle under bad network conditions. We were also doing avoidable duplicate NWS work when multiple triggers fired close together.

What changed:
- Upgraded `/Users/justin/Code/project-arcus/SkyAware/Sources/Infrastructure/Networking/HTTPDataDownloader.swift` with:
  - task-local execution context (`foreground` vs `background`)
  - policy-driven timeout/retry profiles
  - retry handling for 429/503 with `Retry-After` support + jitter
  - HTTP 304 cache revalidation path (`cacheRevalidated304`)
  - final-attempt cache fallback path for retryable failures (`cacheFallback`)
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/SPC/SpcProvider+Syncing.swift` to:
  - run text sync lanes concurrently (convective + meso)
  - fan out map product sync with a fixed max concurrency of 3
  - preserve existing in-flight coalescing and cooldown behavior
- Updated foreground/background call sites:
  - `/Users/justin/Code/project-arcus/SkyAware/Sources/App/HomeView.swift` sets foreground mode and parallelizes independent refresh stages
  - `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Background/BackgroundOrchestrator.swift` sets background mode for orchestration calls
- Reduced avoidable NWS traffic:
  - `/Users/justin/Code/project-arcus/SkyAware/Sources/Clients/NwsClient.swift` now requests active alerts with tighter recommended filters
  - `/Users/justin/Code/project-arcus/SkyAware/Sources/Utilities/Core/RefreshKey.swift` now quantizes to 4-decimal coordinate precision
  - `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/NWS/NwsProvider.swift` now coalesces in-flight same-location syncs and adds a short cooldown gate
- Added/updated tests:
  - new downloader coverage in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/HTTPDataDownloaderTests.swift`
  - new NWS dedupe/cooldown coverage in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/NwsProviderSyncTests.swift`
  - updated query and SPC concurrency tests in existing suites

Aha moment:
The fastest request is the one you never send. Bounded parallelism plus dedupe beats both pure serial and "spawn everything now" approaches.

Gotcha:
The new downloader tests used a shared `URLProtocol` stub store, and Swift Testing runs suites concurrently by default. Tests were intermittently failing with `NSURLErrorDomain -1011` because they were resetting each other's stub queues. Marking that suite `.serialized` fixed the flake.

### 2026-03-08: Background runs had amnesia about location

Bug-shaped problem:
Background refreshes were hitting the `"No location snapshot available; rechecking in 20m"` path too often after cold launches. The orchestrator was fine; the memory was not. `LocationProvider` kept `lastSnapshot` only in RAM, so a fresh process started with an empty brain.

What changed:
- Added snapshot caching seams in `/Users/justin/Code/project-arcus/SkyAware/Sources/Ifrastructure/Location/LocationSnapshotCache.swift`:
  - `LocationSnapshotCaching` protocol
  - `LocationSnapshotCache` (persist/restore with a versioned key)
  - `NoOpLocationSnapshotCache` for deterministic/non-persistent contexts
- Wired `LocationProvider` to:
  - restore cached snapshot at init
  - persist every accepted snapshot in `saveAndYieldSnapshot(...)`
- Wired production DI in `/Users/justin/Code/project-arcus/SkyAware/Sources/App/Dependencies.swift` to use `LocationSnapshotCache`.
- Added tests in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/LocationProviderTests.swift` for:
  - cache restore on startup
  - cache write on accepted update

Aha moment:
Background orchestration wasn't the broken part. It was like calling a chef into the kitchen and finding the pantry empty every morning. Persisting the last known location snapshot turns that pantry light on before the first recipe starts.

Gotcha:
Making persistence the global default would leak state into tests and make them flaky. The `NoOp` default keeps tests clean, and live dependencies opt into persistence explicitly.

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
- Added runtime-configured Arcus signal base URL support via `ARCUS_SIGNAL_URL` build setting -> `Info.plist` `ArcusSignalURL`.
- Added a location snapshot push payload that includes:
  - coordinates + accuracy
  - timestamp
  - placemark summary
  - `h3Cell`
  - APNs device token
- Added a queued `LocationSnapshotPusher` actor with retry behavior.
- Added `HTTPLocationSnapshotUploader` to POST JSON to the configured Arcus signal host, appending `/api/v1/devices/location-snapshots` itself.
- Wired `LocationProvider.saveAndYieldSnapshot(...)` to enqueue push work every time a snapshot is saved.
- Wired `Dependencies.live()` to enable/disable this path based on whether endpoint config exists.

Why this helps:
By attaching push at `saveAndYieldSnapshot`, we avoid fragmented “did we remember to send here too?” logic. One gate, consistent behavior.

Gotcha:
If `ARCUS_SIGNAL_URL` is empty or invalid, pushing is intentionally disabled (no-op pusher), so local development keeps working without backend setup. Arcus alert fetching still defaults to the production host unless a custom base URL is configured.

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

### 2026-03-05: Procedural CIG map hatching (texture layer, not caution tape)

Bug-shaped problem:
Intensity overlays needed to feel informative, but previous options risked visual mud in dark mode or “warning tape” stripes in light mode.

What changed:
- Added typed map overlays so map rendering can distinguish `probability` polygons from `intensity(level:)` polygons without guessing from titles.
- Added a procedural hatch renderer that clips diagonal lines to polygon paths and scales spacing/line width by `zoomScale` for crisp output.
- Added a zoom gate so hatch only appears at regional+ zoom; zoomed-out views stay clean.
- Added dark-mode hatch tint logic that lifts toward near-white (instead of darkening toward black), so texture remains legible on dark basemaps.
- Updated map overlay sync so signatures include geometry + style metadata (kind/colors/hatch recipe), avoiding stale styles and unnecessary remove/re-add churn.

Aha moment:
MapKit overlay polish is mostly math and restraint: one clip, one bounded draw pass, and enough spacing to read as texture instead of signage.

Gotcha:
Identity-only overlay comparisons break once overlays are regenerated wrappers. Signature-based diffing has to include style tokens, not just coordinates.

### 2026-03-05: CIG label plumbing fix (`LABEL="CIG1"` now renders hatch)

Bug-shaped problem:
We added hatch rendering, but CIG overlays still didn’t appear because the `LABEL` value (`CIG1`) wasn’t being carried through the severe-shape map pipeline.

What changed:
- `SevereRiskShapeDTO` now preserves the raw severe label and exposes `intensityLevel` parsing from `CIG1/2/3`.
- Severe map freshness bucketing now includes intensity level so CIG buckets don’t collapse into generic `percent(0)` buckets.
- Severe polygon subtitle metadata now includes `cigLevel`, and map overlay assembly converts those polygons into intensity overlays drawn above base probability overlays.

Aha moment:
If your renderer logic depends on a token (`CIG1`) but your mapper strips that token, the renderer is innocent and the pipeline is guilty.

### 2026-03-05: CIG persistence key collision (the “invisible overlay” sequel)

Bug-shaped problem:
Even after label plumbing worked, some CIG polygons still vanished because `SevereRisk.key` only differentiated `SIGN` labels. If a `CIG1` row shared `type + issued + dn` with a non-CIG row, one could overwrite the other at persistence time.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Models/Severe/SevereRisk.swift` key generation to include `_CIG1/_CIG2/_CIG3` suffixes (and keep `_SIGN`) when present.
- Added regression coverage in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/MapDataFreshnessRepoTests.swift` to verify CIG keys stay distinct for the same issuance/DN bucket.

Aha moment:
Rendering bugs can start in storage. If unique keys collapse distinct semantics, the map never gets a chance to draw what was lost.

### 2026-03-05: Polygon style warning flood cleanup

Bug-shaped problem:
Console logs were flooded with “Unknown polygon title encountered while styling,” even when polygons had explicit SPC `fill/stroke` metadata and rendered correctly.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/PolygonStyleProvider.swift` to short-circuit fallback style parsing when both SPC overrides are present.
- Downgraded unknown fallback logging from warning-level to debug-level so expected fallback cases don’t spam warning noise.

Aha moment:
If fallback is unconditional, logs become lies. Good observability starts with only evaluating fallbacks when you truly need them.

### 2026-03-05: Legend cleanup for CIG/intensity rows

Bug-shaped problem:
Even after initial CIG filtering, intensity artifacts could still show in legend as `0%` severe entries depending on feed shape.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapScreenView.swift` to filter severe legend candidates by excluding intensity rows and zero-percent entries.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapLegendView.swift` with the same defensive filter so CIG/intensity rows are suppressed at render time too.

Aha moment:
For UI cleanup, put guardrails at both the data ingress and the rendering boundary; one filter is brittle, two are resilient.

### 2026-03-05: Explicit CIG layer precedence

Bug-shaped problem:
When multiple intensity overlays overlap (e.g., `CIG1` with nested `CIG2/CIG3`), visual priority depended on incidental polygon order.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapScreenView.swift` to sort intensity overlays by level before rendering so draw order is deterministic:
  - bottom: `CIG1`
  - middle: `CIG2`
  - top: `CIG3`

Aha moment:
In map rendering, “severity” has to be encoded as draw order, not just color tokens.

### 2026-03-05: Swift 6 concurrency cleanup in `RiskPolygonRenderer`

Bug-shaped problem:
`RiskPolygonRenderer` was reading `UIScreen.main.traitCollection` while drawing hatch strokes. Under strict Swift 6 concurrency, that crosses into main-actor isolated UI API from a nonisolated renderer context and triggers warnings.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/RiskPolygonRenderer.swift` to build hatch color with `UIColor(dynamicProvider:)` and trait-based resolution.
- Removed direct `UIScreen.main` access from rendering code.
- Kept the same visual intent:
  - dark mode still lifts hatch toward near-white
  - light mode still darkens hatch slightly toward black

Aha moment:
Trait-driven dynamic colors are the safer bridge here: the system gives you appearance context at resolve-time, so you don’t need to reach for global UI state.

### 2026-03-05: Legend hatch explainer + shared swatch style

Bug-shaped problem:
The map gained procedural hatching, but the legend only explained probability colors. Users had no in-context explanation for what texture meant.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapLegendView.swift` to add a second mini-section beneath severe probability rows.
- Added a compact `HatchSwatchView` and explanatory copy:
  - `Hatching`
  - `Stronger storms possible`
- Wired the swatch to `HatchStyle.default` so legend texture angle/spacing/line width/opacity stay aligned with map hatching tokens.

Aha moment:
Legends are product affordances, not decoration. If a map uses a second visual channel (texture), the legend needs to decode it where the decision happens.

### 2026-03-05: Legend hatching visibility wiring fix

Bug-shaped problem:
After legend refactors, the hatching explainer row stopped showing even when CIG intensity overlays were active.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapScreenView.swift` so selected severe legend data includes intensity rows for the active threat type.
- Kept probability row filtering inside the legend itself, so UI still hides CIG rows but can correctly detect `hasHatching`.
- Removed stale `isCigOrZeroPercent` helper from `MapScreenView` after the wiring change.

Aha moment:
If a child view derives feature flags from incoming data, upstream filtering can silently disable valid UI states.

### 2026-03-05: Layered CIG hatch recipes (single legend swatch)

Bug-shaped problem:
The first hatch implementation proved the concept, but overlapping `CIG1`, `CIG2`, and `CIG3` could look too similar and the legend only previewed one pattern. In stacked areas, that made intensity layering feel flatter than intended.

What changed:
- Expanded `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/HatchStyle.swift` with per-style dash and phase controls (`dashPattern`, `lineOffset`) so each CIG level has a distinct visual recipe.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/RiskPolygonRenderer.swift` to render dashed/offset hatch lines procedurally (still clipped to polygon path), and fixed a double-adjust bug so styles are applied exactly once.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapLegendView.swift` so the legend keeps one hatch row but the swatch layers all three recipes, matching what users can see on-map in overlap zones.
- Updated overlay signature hashing in `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapCanvasView.swift` to include dash/offset style fields, preventing stale-style reuse during overlay sync.

Aha moment:
When multiple textures can stack, uniqueness is not just an art decision. It is a data-encoding requirement, and it needs to be preserved in both renderer math and diffing identity.

### 2026-03-05: Map performance pass - off-main rebuild + key-based overlay sync

Bug-shaped problem:
Switching map layers could feel sticky because we were rebuilding polygons/overlays on the main actor, and overlay syncing used expensive geometry hashing every update.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapScreenView.swift` to move map render-state construction into a cancelable background task (`Task.detached`), then publish final UI state on `MainActor`.
- Added keyed polygon output in `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapPolygonMapper.swift` (`MapPolygonEntry`, `KeyedMapPolygons`) so overlays can be matched by stable IDs instead of geometry scans.
- Reworked `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapCanvasView.swift` + `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapCoordinator.swift` to cache/reuse overlays by key, remove/add only deltas, and reorder only when key order actually changes.
- Added deterministic key regression coverage in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/MapPolygonMapperTests.swift`.

Aha moment:
We were asking the UI thread to be both chef and waiter. Once prep moved off-main and overlay identity became key-based, the main thread got back to serving frames instead of chopping vegetables.

Gotcha:
Detached-task cancellation semantics matter. Wrapping detached work inside another task can accidentally let canceled rebuilds keep burning CPU in the background.

### 2026-03-05: Same-key overlay refresh bug (stale polygons/colors)

Bug-shaped problem:
Our key-based cache was too trusting. If SPC shipped a corrected polygon with the same coarse key (`layer/risk/issued/index`), we reused the old overlay object and kept drawing stale geometry/style on the map.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapCoordinator.swift` with an overlay render-signature (geometry + style) and a `resolvedOverlay` path that only reuses cached overlays when signatures still match.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapCoordinator.swift` registration so replacing a key drops old object-identifier mappings. That lets sync remove outdated map overlays even when the key is unchanged.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Map/MapCanvasView.swift` to use signature-aware resolution during sync instead of unconditional key-based reuse.
- Added `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/RiskPolygonOverlayTests.swift` coverage for same-key reuse, geometry-change replacement, and style-change replacement.

Aha moment:
Cache keys are passports, not fingerprints. If the passport says the traveler is the same but the face changed, you still need the biometric check.

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
- **Bug squash (empty-token location push retries)**: location snapshot uploads were attempted even when APNs token storage was still empty, creating guaranteed-invalid payloads and unnecessary retry noise. `LocationSnapshotPusher.enqueue` now trims/guards token presence and skips upload until registration provides a real token, with unit coverage to prevent regressions.

### 2026-03-18: Unit test suite drift after the Arcus alert pivot

Bug-shaped problem:
The test suite had a couple of fossils from before the alert-source migration. One location-cache test used a hard-coded ancient timestamp without pinning the provider clock, and the `NwsProvider.sync` tests still expected live alert-fetch traffic even though that watch-refresh path is intentionally disabled right now.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/LocationProviderTests.swift` so the cache-restore test injects a matching `nowProvider`, which makes it test freshness logic instead of accidentally testing the wall clock on Justin's laptop.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/NwsProviderSyncTests.swift` so the assertions match the current migration state: `NwsProvider.sync` should not hit the NWS alerts endpoint while watch refresh is turned off.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift` so the cadence harness uses an Arcus-capable watch provider for the orchestrator while still satisfying the existing watch-engine interface.

Aha moment:
Tests can lie in two directions. Sometimes they miss a regression; other times they faithfully guard behavior that the app no longer wants. Migration work leaves behind both kinds of ghosts.

### 2026-03-18: Onboarding now waits for the real handoff, not the optimistic one

Bug-shaped problem:
The onboarding flow was moving on vibes. Location advanced after a half-second timer instead of the user’s real choice, and notifications considered the job "done" as soon as we asked iOS to register for remote notifications. That meant the first location snapshot upload could get dropped in the crack between "permission granted" and "APNs token actually arrived."

What changed:
- Refactored `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Onboarding/OnboardingView.swift` so the parent owns the async orchestration and the child permission views stay mostly presentational.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Onboarding/LocationPermissionView.swift` to stop auto-advancing on a fixed delay.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Onboarding/NotificationPermissionView.swift` to show progress while setup is finishing instead of instantly exiting.
- Extended `/Users/justin/Code/project-arcus/SkyAware/Sources/Notifications/RemoteNotificationRegistrar.swift` with a real "wait for token" path.
- Extended `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/Location/LocationProvider.swift` with a targeted replay hook so onboarding can push the latest snapshot once the token is finally in hand.

Aha moment:
There’s a huge difference between "I asked the OS for a thing" and "the thing exists now." Permission flows are distributed systems wearing a friendly UI costume.

### 2026-03-18: The placeholder home screen was a permission handoff bug in disguise

Bug-shaped problem:
After onboarding, the app could land on `HomeView` with a perfectly good cached location name but still show loading placeholders for risk and weather. That looked like "data never loaded," but the real problem was subtler: the first summary refresh lived in the same scene-phase task that also re-checked location authorization. If the user had granted "When In Use," the app treated that as a cue to escalate again, which made the handoff fragile right when we needed the first refresh to stick.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/App/HomeView.swift` so interactive location prompting only happens when authorization is actually `.notDetermined`.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Infrastructure/Location/LocationManager.swift` so a plain authorization check no longer auto-escalates `authorizedWhenInUse` into a fresh "Always Allow" request.
- Added a focused regression test in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift` to lock in the "only prompt when not determined" rule.

Aha moment:
Not every empty screen is a data bug. Sometimes the network already did its job and the UI still looks blank because a lifecycle task got interrupted at exactly the wrong moment.

### 2026-03-18: Naming cleanup for grid-region identifiers

Bug-shaped problem:
The code was using `county` and `zone` in places where we really meant "county UGC code" and "forecast zone." That works until the Arcus migration shows up and suddenly everyone has to stop and ask, "wait, which zone is this one?"

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Models/GridPointSnapshot.swift` to rename `county` -> `countyCode` and `zone` -> `forecastZone`.
- Carried the same vocabulary through `/Users/justin/Code/project-arcus/SkyAware/Sources/Repos/NwsMetadataRepo.swift`, `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/NWS/GridPointProvider.swift`, `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/NWS/NwsProvider.swift`, `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/ArcusAlertProvider.swift`, and `/Users/justin/Code/project-arcus/SkyAware/Sources/Infrastructure/Location/LocationSnapshotPusher.swift`.
- Preserved the existing push payload wire keys (`county`, `zone`) via `CodingKeys` so naming got clearer in Swift without silently changing the server contract.

Aha moment:
Bad names are like mislabeled drawers in a workshop. You can still build something, but every trip to the toolbox costs extra thought.

### 2026-03-18: Foreground startup should not wait on one stream to wake up

Bug-shaped problem:
After a TestFlight update, the app could open with the chrome fully rendered but no fresh data on screen until the user force-quit and relaunched. The sneaky part was that nothing "crashed" at all. Foreground refresh was simply riding on the location update stream, so if that first post-update launch did not hand us an immediate snapshot, the network bootstrap never really got its starting pistol.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/App/HomeView.swift` so activation does three separate things instead of one tangled thing:
  - asks for location authorization only when the scene is actually active
  - updates location-manager mode for the current scene phase
  - proactively refreshes from the best available snapshot (provider cache first, already-rendered state second) before settling into the live update stream
- Added `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift` coverage for the bootstrap snapshot selection logic, so we preserve the "provider snapshot wins, rendered snapshot is fallback" contract.

Aha moment:
An async stream is a great conveyor belt, but it is a terrible ignition switch. If first-launch freshness depends on the belt moving, the app can look frozen even when every individual component is technically healthy.

### 2026-03-19: Morning background update used a stale location

Bug-shaped problem:
The morning summary pipeline was doing something that looked responsible but was actually a little too optimistic. `BackgroundOrchestrator` asked for a location snapshot, then refreshed only the placemark text for those coordinates. That meant a background run could cheerfully use yesterday's coordinates if the cached snapshot was old. The sneaky sequel: even when we explicitly asked Core Location for a one-shot refresh, `LocationProvider` could still suppress that update as "too soon" because its normal burst-throttle logic had no idea this was a deliberate refresh request.

What changed:
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Features/Background/BackgroundOrchestrator.swift` so the background job asks for a fresh device location before risk queries, trusts only recent snapshots, and skips location-dependent work entirely when the only available snapshot is stale.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Infrastructure/Location/LocationManager.swift` so one-shot refreshes flow through a clearly marked path and only resolve after the provider has processed the update.
- Updated `/Users/justin/Code/project-arcus/SkyAware/Sources/Providers/Location/LocationProvider.swift` so explicitly requested refreshes bypass the normal burst throttle and actually become the new snapshot, even if the user has not moved far enough to satisfy the foreground streaming heuristics.
- Added regression coverage in `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift` and `/Users/justin/Code/project-arcus/SkyAware/Tests/UnitTests/LocationProviderTests.swift` for three cases: fresh refresh wins, recent cache fallback is allowed, and stale cache causes the background notification path to skip instead of bluffing.

Aha moment:
"We requested a fresh location" is only a receipt. The real contract is stricter: did a new fix get accepted, and is it recent enough that we'd be comfortable putting it into a notification?
