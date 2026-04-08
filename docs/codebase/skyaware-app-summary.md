# SkyAware App Codebase Summary

## High-Level Overview
SkyAware is an iOS weather-risk client centered on "what is happening where I am right now." The app resolves the user's live location into an H3 cell plus NWS county/fire-zone context, syncs SPC and Arcus feeds into SwiftData, and projects that state into a five-tab SwiftUI shell: Today, Alerts, Map, Outlooks, and Settings. The architectural shape is a single app target with strong runtime boundaries: transport clients, actor-isolated repos/providers, a shared dependency composition root in [Dependencies.swift](../../Sources/App/Dependencies.swift), and two main UI coordinators in [LocationSession.swift](../../Sources/Infrastructure/Location/LocationSession.swift) and [HomeRefreshPipeline.swift](../../Sources/App/HomeRefreshPipeline.swift).

## Dependencies

### Apple frameworks
- `SwiftUI` / `Observation` / `SwiftData` — Purpose: app UI, observable foreground state, and local persistence. Notes: this is a SwiftUI-first app with `@Observable` session/pipeline state and `@ModelActor` repos.
- `CoreLocation` / `BackgroundTasks` / `UserNotifications` / `UIKit` — Purpose: location, BG refresh, APNs/local notifications, and app delegate bridging. Notes: background location, app refresh, and notification registration are first-class platform features in [SkyAwareApp.swift](../../Sources/App/SkyAwareApp.swift) and [LocationManager.swift](../../Sources/Infrastructure/Location/LocationManager.swift).
- `MapKit` / `WeatherKit` / `OSLog` / `Security` — Purpose: risk-map rendering, current conditions, diagnostics, and Keychain-backed installation identity. Notes: WeatherKit is used for current weather and attribution, not as the main alert/risk source.

### External packages/libraries
- `SwiftyH3` — Purpose: H3 hashing for coarse location bucketing. Notes: it is the only external package visible in the project and is used by [SwiftyH3Hasher.swift](../../Sources/Infrastructure/Location/SwiftyH3Hasher.swift).

### Platform capabilities
- `APNs + WeatherKit entitlements` — Purpose: remote notifications and WeatherKit access. Notes: visible in [SkyAware.entitlements](../../SkyAware.entitlements).
- `Background modes: location, fetch, processing, remote-notification` — Purpose: ongoing location monitoring, BG refresh orchestration, and push-related behavior. Notes: declared in [Info.plist](../../Config/Info.plist).
- `iOS 18+, Swift 6` — Purpose: modern Apple-platform baseline. Notes: the project is iPhone/iPad only, iOS-only, with strict concurrency enabled in the project settings.

### Testing dependencies
- `Swift Testing` — Purpose: most unit/domain/infrastructure tests. Notes: coverage is strongest around repos, parsing, orchestration, and notification rules.
- `XCTest` — Purpose: UI tests. Notes: current UI automation is still mostly template-level launch coverage.

### Infrastructure/service dependencies
- `SPC (spc.noaa.gov)` — Purpose: convective outlooks, mesos, and map geometry.
- `NWS (api.weather.gov)` — Purpose: point metadata and zone context, especially county/fire-zone resolution.
- `WeatherKit` — Purpose: current local conditions and attribution.
- `Arcus Signal` — Purpose: active alert/watch data plus optional location-context upload for server-side notification infrastructure. Notes: the client path is real, but some server-notification behavior is only partially visible from app code.

## Features

### Today / Local Summary
This is the app's center of gravity. The Today tab combines location readiness, WeatherKit conditions, categorical/severe/fire risk, active local alerts, and latest outlook text into one foreground experience driven by [HomeView.swift](../../Sources/App/HomeView.swift), [SummaryView.swift](../../Sources/Features/Summary/SummaryView.swift), and [HomeRefreshPipeline.swift](../../Sources/App/HomeRefreshPipeline.swift).

It looks mature rather than aspirational: pull-to-refresh, throttling, loading overlays, and readiness-state handling are all implemented and backed by tests. The UI is effectively a projection of resolved `LocationContext` plus locally persisted risk/alert data.

### Active Alerts
The Alerts tab is a real feature area, not just a list screen. It supports watches and mesos, empty states, manual refresh, and detail drill-ins via [AlertView.swift](../../Sources/Features/Alert/AlertView.swift), [WatchDetailView.swift](../../Sources/Features/Alert/WatchDetailView.swift), and mesoscale detail cards.

Architecturally, this feature is split across two feed paths: Arcus-backed watch data and SPC-backed mesos. That split is coherent in the runtime model even if some older NWS watch-era code still remains in-tree.

### Onboarding / Permission Bootstrap
Onboarding is substantial and sequential: welcome, disclaimer, location permission, notification permission, APNs registration, and optional first location-context capture before flipping `onboardingComplete`. The flow in [OnboardingView.swift](../../Sources/Features/Onboarding/OnboardingView.swift) is tightly integrated with [LocationSession.swift](../../Sources/Infrastructure/Location/LocationSession.swift) and [RemoteNotificationRegistrar.swift](../../Sources/Notifications/RemoteNotificationRegistrar.swift).

This area looks mature, though denied/restricted-location remediation is less polished than first-run acquisition. There is support for opening Settings, but that path is not strongly surfaced from the restricted-location UI.

### Convective Outlooks
Outlooks are implemented as a standalone feature, with list/detail navigation, manual refresh, and summary-card reuse. The stack is backed by RSS ingest into SwiftData through [ConvectiveOutlookRepo.swift](../../Sources/Repos/ConvectiveOutlookRepo.swift) and exposed via SPC provider query surfaces.

This feels real but still evolving. The feature is solid functionally, yet it is somewhat more isolated than the Today/Alerts flows and shows signs of older UI scaffolding still lingering nearby.

### Layered Risk Map
The Map tab is more than decorative. It loads persisted SPC polygons, supports multiple selectable layers, builds overlays off the main thread, and renders a custom legend via [MapScreenView.swift](../../Sources/Features/Map/MapScreenView.swift).

It is clearly implemented, but it reads as a power-user tool more than a fully reactive live dashboard. A notable architectural caveat is that it appears to load once on appearance and does not obviously subscribe to freshness/scene-phase changes for automatic overlay refresh.

### Notifications, Background Refresh, and Diagnostics
SkyAware has a genuine background/runtime operations layer: cadence-based app refresh, location-change-triggered watch checks, morning/meso/watch notification engines, APNs token registration, and persisted background-run history. These flows are centered in [BackgroundOrchestrator.swift](../../Sources/Features/Background/BackgroundOrchestrator.swift), the notification engines under [Sources/Notifications](../../Sources/Notifications), and background diagnostics in [BgHealthDiagnosticsView.swift](../../Sources/Features/Diagnostics/BgHealthDiagnosticsView.swift).

This area is evolving rather than finished. The notification engines are well decomposed, but some settings are only partially wired, generic diagnostics are sparse, and server-originated push behavior is not fully visible from the client code.

## Workflows

### App Launch and Composition
Launch starts in [SkyAwareApp.swift](../../Sources/App/SkyAwareApp.swift): a single live dependency container is built, a shared `LocationSession` is created, the SwiftData model container is injected, and routing chooses onboarding or the main tab shell. The app delegate separately establishes notification-center delegate behavior for foreground presentation.

The important architectural implication is that composition is explicit and centralized. This is a strength: most runtime behavior can be traced back to `Dependencies.live()` rather than hidden app-global assembly.

### Location Resolution and Context Formation
Scene phase drives location mode selection in [LocationManager.swift](../../Sources/Infrastructure/Location/LocationManager.swift): active scenes use live updates, backgrounded scenes with Always auth use significant-location changes, and raw updates are filtered through [LocationProvider.swift](../../Sources/Providers/Location/LocationProvider.swift) for accuracy, throttling, cache restore, H3 hashing, and placemark enrichment.

`LocationContextResolver` then turns a snapshot into a richer `LocationContext` containing H3, county/fire-zone, and grid metadata. That context becomes the join point for nearly all downstream alert/risk behavior.

### Foreground Refresh and UI State Propagation
`HomeView` delegates most foreground behavior to [HomeRefreshPipeline.swift](../../Sources/App/HomeRefreshPipeline.swift). Triggers include first appearance, scene active, pull-to-refresh, periodic timer refresh, and context changes. The pipeline coalesces triggers, overlaps slow SPC sync with context preparation, syncs hot feeds, reads local SwiftData-backed snapshots, optionally fetches WeatherKit, and writes state back into Today/Alerts/Outlooks UI.

This is the core runtime workflow of the app. One subtle implication is that failure tends to preserve the last good UI state, which is good for stability but can conceal repeated sync failure from the user unless diagnostics are consulted.

### Persistence and Local Query Workflow
Network fetches pass through [HTTPDataDownloader.swift](../../Sources/Infrastructure/Networking/HTTPDataDownloader.swift), then into repo actors that parse, map, and upsert into SwiftData. After that, most UI paths query local repo state rather than waiting on fresh network responses.

That gives the app an offline-tolerant, cache-friendly posture. It also means repos are doing more than storage; they are effectively mini data services with parse, dedupe, freshness, and geospatial-query logic.

### Background App Refresh
The app registers `com.skyaware.app.refresh` and schedules future work through [BackgroundScheduler.swift](../../Sources/Infrastructure/Scheduling/BackgroundScheduler.swift). When invoked, [BackgroundOrchestrator.swift](../../Sources/Features/Background/BackgroundOrchestrator.swift) syncs slower feeds, resolves a fresh context, syncs hot feeds, reads local risk/alert state, runs notification engines, computes the next cadence, and records a `BgRunSnapshot`.

This workflow is architecturally strong and well tested. The main weakness is policy duplication: foreground and background refresh each keep their own last-sync timing state rather than sharing one canonical freshness service.

### Background Location Change and Watch Notification
A separate workflow handles significant location changes while backgrounded. After the location provider accepts an update, `BackgroundLocationChangeHandler` resolves context, syncs only hot feeds, reads current watches, and runs `WatchEngine`.

This is a nice example of scope-specific orchestration: it avoids the heavier BG refresh path and limits work to the alert type most likely to matter for sudden movement.

### APNs Registration and Arcus Subscription Context
Onboarding and Settings can request notification permission through [RemoteNotificationRegistrar.swift](../../Sources/Notifications/RemoteNotificationRegistrar.swift). Once the app has a token and a resolved location context, [LocationSnapshotPusher.swift](../../Sources/Infrastructure/Location/LocationSnapshotPusher.swift) can upload installation ID, APNs token, H3 cell, county/fire-zone, and subscription metadata to Arcus.

What is directly visible is registration and upload. What is not directly visible is a full client-side path for incoming remote-notification payload handling beyond token capture and foreground display behavior.

## Architectural Observations
The main pattern is "single target, strong runtime seams." Compile-time modularity is low, but runtime layering is fairly disciplined: clients fetch raw data, repos persist and query, providers orchestrate/coalesce, and UI state is concentrated in `LocationSession` and `HomeRefreshPipeline`. Actor isolation is used consistently for location, repos, providers, upload flows, and background orchestration, while UI-facing objects are explicitly `@MainActor`.

The biggest strengths are the location pipeline, the shared ingestion helpers, and the notification engine decomposition. The biggest weak spots are drift and inconsistency: repo/provider/client naming no longer maps perfectly to responsibility, preview safety depends on service-locator availability, foreground/background refresh freshness logic is duplicated, and several toggles/features exist in partial form. There is also visible migration drift from older NWS-watch plumbing toward Arcus-backed alert ingestion.

## Testing / Confidence Signals
Confidence is strongest in infrastructure and orchestration. There is solid test coverage around refresh coordination, location handling, HTTP retry/cache behavior, parser edges, repo selection logic, and notification-rule behavior, and the use of Swift Testing plus isolated in-memory SwiftData containers is a good maturity signal.

Confidence is weaker in end-to-end UX. UI tests are still largely template launch tests, many screens rely on previews rather than automation, and some suites are skipped or skeletal. This is a structural confidence read, not a pass/fail claim.

## Confidence / Unknowns
Directly supported by code:
- The app is a location-driven severe-weather client with real foreground refresh, background refresh, local notifications, risk mapping, and SwiftData-backed persistence.
- Arcus is the active watch/alert path, while SPC and NWS remain core data/context providers.
- Background refresh cadence, local context resolution, and notification engines are all implemented, not placeholder ideas.

Strong inferences:
- The codebase is mid-transition from older NWS-centric watch handling toward Arcus-backed alert infrastructure.
- Settings and diagnostics are carrying some internal-tooling burden that may not all be intended as polished user-facing product.
- The architecture values resilience and local reads over always-live network freshness.

Could not be determined confidently:
- Full server-push behavior beyond token registration and location-context upload.
- How CI actually executes UI automation versus the shared test plan.
- Whether some retained NWS-era code is deliberate fallback scaffolding or dead code.

## Suggested Documentation Artifacts
- ADR: "Why location context is modeled as H3 + NWS grid/county/fire-zone."
- ADR: "Why SwiftData repos also own parse/upsert/query logic instead of using separate mappers/services."
- ADR: "Foreground vs background refresh policy ownership and whether freshness state should be centralized."
- ADR: "Arcus migration: source of truth for watches/alerts and retirement plan for legacy NWS watch code."
- Feature brief: "Today tab data contract and readiness states."
- Feature brief: "Notifications matrix: morning, meso, watch, and server-assisted push."
- Workflow doc: "Location lifecycle from permission prompt to background significant-change monitoring."
- Workflow doc: "Background refresh execution, cadence decisioning, and diagnostics."
- Workflow doc: "APNs registration + installation identity + Arcus subscription/location upload."
