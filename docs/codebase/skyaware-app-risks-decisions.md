# SkyAware Architectural Risks, Undocumented Decisions, and Simplification Targets

This note builds on [SkyAware App Codebase Summary](./skyaware-app-summary.md) and focuses on the areas that matter most for future architecture work: where the design is at risk, which decisions clearly exist but are not yet written down, and where simplification would buy the most leverage.

Reviewed against the app codebase on 2026-03-30.

## 1. The 5 Most Important Architectural Risks

### 1. Refresh ownership is duplicated across foreground and background paths
Why it matters:
Foreground and background refresh each maintain their own freshness bookkeeping. That makes behavior harder to reason about, increases the chance of phase-specific bugs, and makes it unclear which path is authoritative when feeds fail or get retried.

Evidence:
- [HomeRefreshPipeline.swift](../../SkyAware/Sources/App/HomeRefreshPipeline.swift) keeps `lastHotFeedSyncAt`, `lastMapProductSyncAt`, `lastOutlookSyncAt`, and `lastWeatherKitSyncAt`.
- [HomeRefreshPipeline.swift](../../SkyAware/Sources/App/HomeRefreshPipeline.swift) marks those timestamps in `markHotFeedSyncIfNeeded`, `markMapProductSyncIfNeeded`, and `markOutlookSyncIfNeeded`.
- [BackgroundOrchestrator.swift](../../SkyAware/Sources/Features/Background/BackgroundOrchestrator.swift) separately keeps `lastMapProductSyncAt` and `lastOutlookSyncAt`.
- [BackgroundOrchestrator.swift](../../SkyAware/Sources/Features/Background/BackgroundOrchestrator.swift) independently evaluates and updates those timestamps in `syncSlowFeeds(now:)`.

Architectural implication:
The app has policy objects, but not a single shared freshness authority.

### 2. Dependency access is crash-prone and hidden behind a service locator
Why it matters:
The environment-based `Dependencies` object gives the app convenient wiring, but many lookups trap with `fatalError`. That creates avoidable runtime fragility, especially in previews, diagnostics, and future feature work.

Evidence:
- [Dependencies.swift](../../SkyAware/Sources/App/Dependencies.swift) exposes many `fatalError` accessors such as `modelContainer`, `weatherClient`, and `spcMapData`.
- [MapScreenView.swift](../../SkyAware/Sources/Features/Map/MapScreenView.swift) reaches directly into `deps.spcMapData`.
- [MapScreenView.swift](../../SkyAware/Sources/Features/Map/MapScreenView.swift) defines a `#Preview` that injects `LocationSession.preview` but not live dependencies.
- [AttributionView.swift](../../SkyAware/Sources/Features/Settings/AttributionView.swift) reaches directly into `dependencies.weatherClient`.
- [AttributionView.swift](../../SkyAware/Sources/Features/Settings/AttributionView.swift) also defines a preview with no dependency injection.

Architectural implication:
The composition root is good, but the access pattern makes the UI layer more brittle than it needs to be.

### 3. The NWS-to-Arcus alert migration is incomplete and leaves conceptual dead weight behind
Why it matters:
The app has already operationally moved watches to Arcus, but enough NWS watch-era code remains that a new contributor could easily misunderstand the system boundary or accidentally revive a retired path.

Evidence:
- [WatchRepo.swift](../../SkyAware/Sources/Repos/WatchRepo.swift) refreshes watches via `ArcusClient`.
- [NWSWatchParser.swift](../../SkyAware/Sources/Infrastructure/Parsing/NWS/NWSWatchParser.swift) is explicitly deprecated with `"Use the Arcus instead"`.
- [NwsClient.swift](../../SkyAware/Sources/Clients/NwsClient.swift) still exposes `fetchActiveAlertsJsonData`.
- [NwsProvider.swift](../../SkyAware/Sources/Providers/NWS/NwsProvider.swift) still exists, but only `NwsMetadataProviding` is visibly active.
- [NwsProviderSyncTests.swift](../../SkyAware/Tests/UnitTests/NwsProviderSyncTests.swift) contains commented-out tests for the old watch-sync behavior.

Architectural implication:
This is transition-state architecture, not a settled boundary.

### 4. DTO identity rules are inconsistent across feature areas
Why it matters:
Stable identity affects SwiftUI list diffing, caching, equality reasoning, and how easy it is to safely merge data across refresh cycles. Right now, some DTOs preserve source identity while others generate new UUIDs every time they are projected.

Evidence:
- [WatchRowDTO.swift](../../SkyAware/Sources/Models/Watches/WatchRowDTO.swift) uses a stable upstream `String` id.
- [MdDTO.swift](../../SkyAware/Sources/Models/Meso/MdDTO.swift) creates `self.id = UUID()`.
- [ConvectiveOutlookDTO.swift](../../SkyAware/Sources/Models/Convective/ConvectiveOutlookDTO.swift) creates `self.id = UUID()`.
- [StormRiskDTO.swift](../../SkyAware/Sources/Models/Categorical/StormRiskDTO.swift) defaults `id` to a new UUID.
- [FireRiskDTO.swift](../../SkyAware/Sources/Models/Fire/FireRiskDTO.swift) defaults `id` to a new UUID.

Architectural implication:
Identity is currently a per-feature convention rather than a standard.

### 5. Some user-facing settings do not cleanly map to runtime behavior
Why it matters:
Settings are part of the product contract. If toggles exist but do not gate the behavior users think they control, the app becomes harder to trust and harder to maintain.

Evidence:
- [SettingsView.swift](../../SkyAware/Sources/Features/Settings/SettingsView.swift) exposes `Server Notifications` and `Send Location to Signal`.
- [SettingsView.swift](../../SkyAware/Sources/Features/Settings/SettingsView.swift) routes all toggle enable events through `handleNotificationToggle`.
- [SettingsView.swift](../../SkyAware/Sources/Features/Settings/SettingsView.swift) `handleNotificationToggle` only re-requests notification auth/registration.
- [LocationSnapshotPusher.swift](../../SkyAware/Sources/Infrastructure/Location/LocationSnapshotPusher.swift) reads `serverNotificationEnabled` only as `isSubscribed`.
- [LocationSnapshotPusher.swift](../../SkyAware/Sources/Infrastructure/Location/LocationSnapshotPusher.swift) does not read `sendL8ntoSignal` at all.

Architectural implication:
The settings model and the runtime model are not yet aligned one-to-one.

## 2. The 5 Most Important Undocumented Decisions

### 1. Why `LocationContext` is the app's true unit of readiness
Decision hiding in the code:
The app does not treat raw coordinates as sufficient. The real contract is "location + H3 + county + fire zone + grid metadata."

Evidence:
- [LocationContextResolver.swift](../../SkyAware/Sources/Infrastructure/Location/LocationContextResolver.swift) defines `LocationContext` with snapshot, `h3Cell`, and `grid`.
- [LocationContextResolver.swift](../../SkyAware/Sources/Infrastructure/Location/LocationContextResolver.swift) defines `refreshKey` around H3, county, fire zone, and grid key.
- [LocationContextResolver.swift](../../SkyAware/Sources/Infrastructure/Location/LocationContextResolver.swift) rejects contexts missing H3 or missing county/fire-zone metadata.
- [LocationSnapshotPusher.swift](../../SkyAware/Sources/Infrastructure/Location/LocationSnapshotPusher.swift) uploads H3 plus county/fire-zone metadata as part of the server-facing payload.

Why it should be documented:
This is the most important data contract in the app. It explains why location flows are stricter than "we have latitude/longitude."

### 2. Why the app is local-first instead of live-response-driven
Decision hiding in the code:
The system is designed so UI usually reads persisted local state after sync, not direct network responses.

Evidence:
- [ConvectiveOutlookRepo.swift](../../SkyAware/Sources/Repos/ConvectiveOutlookRepo.swift) fetches, parses, maps, and stores outlooks locally.
- [HomeIngestionSupport.swift](../../SkyAware/Sources/App/HomeIngestionSupport.swift) reads location-scoped snapshots from provider query surfaces, not from a one-shot network response object.
- [SpcProvider+SpcRiskQuerying.swift](../../SkyAware/Sources/Providers/SPC/SpcProvider+SpcRiskQuerying.swift) queries repo-backed provider surfaces.
- [ArcusAlertProvider.swift](../../SkyAware/Sources/Providers/ArcusAlertProvider.swift) returns locally queryable watch DTOs after sync.

Why it should be documented:
This choice affects caching, error handling, offline behavior, and where future features should hook into the system.

### 3. Why Arcus is the alert source of truth while NWS remains a metadata/context source
Decision hiding in the code:
Arcus is the operational alert/watch path, while NWS is primarily used for point and zone metadata.

Evidence:
- [WatchRepo.swift](../../SkyAware/Sources/Repos/WatchRepo.swift) refreshes with `ArcusClient`.
- [ArcusSignalConfiguration.swift](../../SkyAware/Sources/App/ArcusSignalConfiguration.swift) defines both alert and location-snapshot endpoints for Arcus.
- [NwsProvider.swift](../../SkyAware/Sources/Providers/NWS/NwsProvider.swift) exposes `NwsMetadataProviding` rather than an active watch path.
- [NWSWatchParser.swift](../../SkyAware/Sources/Infrastructure/Parsing/NWS/NWSWatchParser.swift) is deprecated in favor of Arcus.

Why it should be documented:
Without an explicit ADR, the repository still looks like it supports two alert systems equally.

### 4. Why feeds are split into hot products and slow products
Decision hiding in the code:
The app treats mesos/watches as hot feeds and outlook/map products as slower products with different refresh economics.

Evidence:
- [HomeRefreshPipeline.swift](../../SkyAware/Sources/App/HomeRefreshPipeline.swift) branches between `supportsSlowFeeds`, `isHotFeedsOnly`, and separate sync steps.
- [HomeIngestionSupport.swift](../../SkyAware/Sources/App/HomeIngestionSupport.swift) has dedicated `syncHotFeeds`, `readLocationScopedSnapshot`, and `readHotFeedSnapshot`.
- [BackgroundOrchestrator.swift](../../SkyAware/Sources/Features/Background/BackgroundOrchestrator.swift) syncs slow feeds first, then hot feeds, then local reads and notifications.

Why it should be documented:
This decision drives latency, battery use, perceived freshness, and the entire cadence design.

### 5. Why notifications are built from rule/gate/composer/sender engines
Decision hiding in the code:
Morning, meso, and watch notifications all use the same port-driven decomposition.

Evidence:
- [MorningEngine.swift](../../SkyAware/Sources/Notifications/Morning/MorningEngine.swift) depends on `rule`, `gate`, `composer`, and `sender`.
- [MesoEngine.swift](../../SkyAware/Sources/Notifications/Meso/MesoEngine.swift) uses the same pattern.
- [WatchEngine.swift](../../SkyAware/Sources/Notifications/Watch/WatchEngine.swift) uses the same pattern.
- [Sender.swift](../../SkyAware/Sources/Notifications/Sender.swift) provides the shared sending implementation.

Why it should be documented:
This is one of the cleanest architectural patterns in the app and should be preserved intentionally.

## 3. The 5 Highest-Value Areas to Simplify or Standardize

### 1. Centralize freshness state and retry semantics
Why it is high value:
It would reduce duplication, clarify the source of truth for feed recency, and make both debugging and future background behavior much easier.

Evidence:
- [HomeRefreshPipeline.swift](../../SkyAware/Sources/App/HomeRefreshPipeline.swift) manages foreground freshness locally.
- [BackgroundOrchestrator.swift](../../SkyAware/Sources/Features/Background/BackgroundOrchestrator.swift) manages background freshness locally.
- [HomeRefreshPipeline.swift](../../SkyAware/Sources/App/HomeRefreshPipeline.swift) marks sync timestamps before work executes, which can suppress retries even when the work fails.

Suggested direction:
Introduce a shared freshness coordinator or feed-state store that both foreground and background paths consult and update.

### 2. Standardize dependency injection and preview behavior
Why it is high value:
This would remove a class of crashes, make previews trustworthy, and make the architecture easier for contributors to follow.

Evidence:
- [Dependencies.swift](../../SkyAware/Sources/App/Dependencies.swift) uses `fatalError` accessors extensively.
- [MapScreenView.swift](../../SkyAware/Sources/Features/Map/MapScreenView.swift) and [AttributionView.swift](../../SkyAware/Sources/Features/Settings/AttributionView.swift) depend on those accessors from the UI.
- [MapScreenView.swift](../../SkyAware/Sources/Features/Map/MapScreenView.swift) and [AttributionView.swift](../../SkyAware/Sources/Features/Settings/AttributionView.swift) declare previews without fully wiring dependencies.

Suggested direction:
Pick one of two models and commit to it: explicit typed feature dependencies, or a preview-safe dependency container with non-crashing test doubles.

### 3. Standardize DTO identity and projection rules
Why it is high value:
It affects UI stability, merging behavior, and how easy it is to understand whether a refresh replaced data or just re-projected it.

Evidence:
- [MdDTO.swift](../../SkyAware/Sources/Models/Meso/MdDTO.swift), [ConvectiveOutlookDTO.swift](../../SkyAware/Sources/Models/Convective/ConvectiveOutlookDTO.swift), [StormRiskDTO.swift](../../SkyAware/Sources/Models/Categorical/StormRiskDTO.swift), and [FireRiskDTO.swift](../../SkyAware/Sources/Models/Fire/FireRiskDTO.swift) all rely on UUID-based DTO identity.
- [WatchRowDTO.swift](../../SkyAware/Sources/Models/Watches/WatchRowDTO.swift) preserves external identity instead.
- [ConvectiveOutlookDTO.swift](../../SkyAware/Sources/Models/Convective/ConvectiveOutlookDTO.swift) also embeds parsing behavior via `OutlookParser` in a DTO extension.

Suggested direction:
Adopt one rule for DTO identity and one rule for where parsing/formatting helpers live.

### 4. Standardize feature flags and user settings around real runtime behavior
Why it is high value:
It would tighten the product contract and reduce confusion for both users and developers.

Evidence:
- [SettingsView.swift](../../SkyAware/Sources/Features/Settings/SettingsView.swift) contains commented-out AI summary settings.
- [DiagnosticsView.swift](../../SkyAware/Sources/Features/Diagnostics/DiagnosticsView.swift) contains mostly placeholder sections and a disabled `Force Refresh`.
- [CadenceSandboxView.swift](../../SkyAware/Sources/Features/Diagnostics/CadenceSandboxView.swift) is fully commented out.
- [SettingsView.swift](../../SkyAware/Sources/Features/Settings/SettingsView.swift) exposes toggles whose behavior does not cleanly map to a dedicated runtime owner.

Suggested direction:
Classify each setting as active, experimental, internal-only, or retired, and trim the UI to match that status.

### 5. Standardize naming around `Client`, `Repo`, `Provider`, and `Engine`
Why it is high value:
The app already has good runtime seams, but the names no longer teach contributors the system correctly.

Evidence:
- [ConvectiveOutlookRepo.swift](../../SkyAware/Sources/Repos/ConvectiveOutlookRepo.swift) is not just a repo; it also parses and maps.
- [NwsMetadataRepo.swift](../../SkyAware/Sources/Repos/NwsMetadataRepo.swift) is not persistence-backed at all; it is an in-memory fetch/cache actor.
- [NwsProvider.swift](../../SkyAware/Sources/Providers/NWS/NwsProvider.swift) is much narrower than the name suggests.
- [MorningEngine.swift](../../SkyAware/Sources/Notifications/Morning/MorningEngine.swift), [MesoEngine.swift](../../SkyAware/Sources/Notifications/Meso/MesoEngine.swift), and [WatchEngine.swift](../../SkyAware/Sources/Notifications/Watch/WatchEngine.swift) actually have very crisp responsibilities by comparison.

Suggested direction:
Either rename the layers to match their real roles or define a short architecture glossary and enforce it for new code.
