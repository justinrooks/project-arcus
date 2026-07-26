# SkyAware App Codebase Summary

## High-Level Overview

SkyAware is an iOS severe-weather awareness client centered on what is happening at the user's current location. It
resolves location into an H3 cell plus NWS county/fire-zone context, persists risk and alert state in SwiftData, and
projects that state through Today, Alerts, Map, Outlooks, and Settings. The current architecture generation is **G5**:
explicit composition, actor-owned ingestion and persistence, cache-first reads, and stable SwiftUI presentation.

The principal runtime owners are [Dependencies.swift](../../Sources/App/Dependencies.swift),
[LocationSession.swift](../../Sources/Infrastructure/Location/LocationSession.swift), and
[HomeRefreshPipeline.swift](../../Sources/App/HomeRefreshPipeline.swift). UI-facing owners use main-actor isolation;
repositories and ingestion/upload coordination retain their actor or `ModelActor` boundaries.

## Dependencies and Capabilities

### Apple frameworks

- `SwiftUI`, `Observation`, and `SwiftData` provide the UI, observable presentation state, and local persistence.
- `CoreLocation`, `BackgroundTasks`, `UserNotifications`, and `UIKit` provide location, background execution,
  notification delivery, and app-delegate bridging.
- `MapKit`, `WeatherKit`, `OSLog`, and `Security` provide map rendering, current conditions, diagnostics, and
  secure installation identity.

### External packages

- `SwiftyH3` provides coarse H3 location bucketing through
  [SwiftyH3Hasher.swift](../../Sources/Infrastructure/Location/SwiftyH3Hasher.swift).
- `ArcusCore` provides the Arcus client contract consumed by the app's explicit live composition.

### Platform capabilities

- APNs and WeatherKit entitlements are declared in [SkyAware.entitlements](../../SkyAware.entitlements).
- Location, fetch, processing, and remote-notification background modes are declared in
  [Info.plist](../../Config/Info.plist).
- The app targets iOS 18+ with Swift 6 concurrency checking.

## Current G5 Runtime Architecture

### Composition and location context

[SkyAwareApp.swift](../../Sources/App/SkyAwareApp.swift) constructs one live dependency container through
`Dependencies.live()`. Live Arcus configuration resolves one shared base URL and fails fast when required configuration
is absent; preview and test composition use explicit upload no-ops rather than silently degrading production behavior.

[LocationSession.swift](../../Sources/Infrastructure/Location/LocationSession.swift) is the main owner of the current
location context and its lifecycle. It coordinates authorization and location updates, then hands resolved context to
the refresh and upload boundaries. Location snapshots remain privacy-scoped: H3 and NWS context support the app's
alert/risk work without exposing raw location data to ordinary UI state.

### Unified ingestion and persistence

[HomeIngestionCoordinator.swift](../../Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift) merges compatible
requests and serializes conflicting campaigns. [HomeIngestionExecutor.swift](../../Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift)
performs the unified ingestion work used by foreground refresh, background refresh, significant-location changes, and
remote hot-alert handling.

Core weather, slow-product, and hot-alert updates persist atomically before a projection becomes Today-ready. Optional
enrichment follows as an owned staged update, so it does not delay the first coherent core publication. Cached content
therefore remains available while refreshes resolve forward and partial failures do not discard useful state.

### Today presentation

[HomeRefreshPipeline.swift](../../Sources/App/HomeRefreshPipeline.swift) is the main-actor owner of visible Today
publication and lifecycle entry points. [HomeView+PresentationState.swift](../../Sources/App/HomeView+PresentationState.swift)
defines `HomePresentationSnapshot`, the pure selection value consumed by
[HomeView.swift](../../Sources/App/HomeView.swift). This keeps cache/pipeline arbitration out of individual Today
sections: views render a stable selected presentation instead of independently choosing per-slice display values.

Local Alerts and Storm Setup retain stable outer SwiftUI identities across their relevant content transitions. The Map
feature is a main-actor presentation owner with separately planned/rendered geometry; it reads persisted risk data
rather than acting as a second ingestion path.

### Background, uploads, and remote alerts

[BackgroundOrchestrator.swift](../../Sources/Features/Background/BackgroundOrchestrator.swift) brings background work
through the same ingestion path and honors cancellation. Its current cancellation handling includes a bounded
one-upload/five-second pending-upload pre-drain before subsequent background work. Durable location and preference
upload records are separated from queue coordination in
[LocationUploadPersistenceModels.swift](../../Sources/Infrastructure/Location/LocationUploadPersistenceModels.swift),
[LocationUploadQueueStore.swift](../../Sources/Infrastructure/Location/LocationUploadQueueStore.swift), and
[LocationSnapshotPusher.swift](../../Sources/Infrastructure/Location/LocationSnapshotPusher.swift).

[SkyAwareAppDelegate.swift](../../Sources/App/SkyAwareAppDelegate.swift) actively routes supported remote hot-alert
payloads to [RemoteHotAlertHandler.swift](../../Sources/App/RemoteHotAlertHandler.swift), which converges on unified
ingestion rather than maintaining a separate alert-refresh path. The app's code establishes its client-side contract;
deployed Arcus Signal behavior beyond consumed contracts remains outside this repository's authority.

### Widgets and tests

Widget rendering is split into focused domain components under [WidgetsExtension](../../WidgetsExtension), preserving
family-specific behavior without one catch-all renderer. Test coverage is substantive rather than template-only:
[SkyAwareUITests.swift](../../Tests/UITests/SkyAwareUITests.swift) covers navigation, onboarding, Map, Today, Alerts,
accessibility, and Storm Setup, alongside Swift Testing coverage for domain, persistence, ingestion, and presentation
boundaries.

## Product Surfaces

Today is the primary severe-weather surface: it presents cached risk, active local alerts, conditions, and outlook
content immediately when available, then resolves forward through the unified ingestion pipeline. Alerts provides
watch/meso detail and manual refresh; Outlooks and Map consume persisted SPC-derived products; Settings and onboarding
own permissions, notification registration, and diagnostics. WeatherKit supplies current conditions and attribution,
while SPC, NWS, and Arcus supply the app's distinct risk, context, and alert inputs.

## Historical Evidence and Remaining Unknowns

Earlier architecture summaries, state-flow baselines, and performance investigations remain useful point-in-time
evidence. They are not descriptions of the current G5 implementation where later completed ledgers or source supersede
them.

The remaining material confidence gap is comparable physical-device Release evidence for parts of the Today refresh
scenario matrix. Implementation completion does not convert that missing evidence into a performance claim; follow-up
issue [#345](https://github.com/justinrooks/project-arcus/issues/345) owns those captures. This repository also cannot
prove deployed Arcus Signal behavior beyond the contracts the client consumes.
