---
up: "[[Feature Candidates]]"
related:
created: 2026-04-13
tags:
  - skyaware
---
## **Decision**
---
- Use a cached home projection as the launch source for the app.
- If a cached home projection exists, render it immediately on launch and refresh in the background, surfacing updates as soon as they are available.
- If no cached home projection exists yet, show the initial [`LoadingView`](../../Sources/Features/Loading/LoadingView.swift) while the app builds that projection for the first time.
- Keep raw product caches in SwiftData, but avoid rebuilding the home experience from multiple live reads on every launch.
- Normalize all ingestion entry points through one ingestion coordinator and one ingestion process.
- Let each trigger create a different ingestion plan, but do not create separate ingestion implementations for foreground, background, location, and remote push paths.
- Remote hot-alert ingestion must distinguish between push receipt and user-open-from-push flows.
- When a user opens the app from an APNs alert notification, the alerted warning should already be available locally or should be the highest-priority pending work so it becomes available immediately on open.
- Treat `Offline` as a communication of the app's current ability to reach the network and obtain fresh data.
- Do not derive `Offline` from stale data age.
- Do not show staleness in the main user-facing experience.
- Treat `Offline` as runtime state layered on top of the cached home projection rather than persisted freshness state.
- Use `NWPathMonitor` as the general connectivity signal for non-hot paths.
- For the hot alert lane, also consider the app's ability to reach Arcus Signal and obtain fresh alert data.
- Track freshness internally by lane for scheduling, diagnostics, and administrative troubleshooting.
- Current freshness lanes are:
  - `hot alerts` for watches and mesos
  - `slow products` for outlooks and map-driven risk products
  - `weather` for WeatherKit-backed conditions

# **Problem**
---
SkyAware's data ingestion process is complex. It's triggered by views and location changes, and stored in various places in the app. This information is eventually compiled and processed into what is displayed for the user. It's the building block of everything in the app. It is ultimately stored locally in SwiftData tables, and then consumed by the UI from these tables. The process is inefficient and duplicative, and can be improved so that we are fetching less, and able to understand the entire process better.

The faster we are able to get data in, the faster we can update the app's state and communicate important time sensitive data to the user. This is the corner stone of the entire app so it needs to be fast, efficient, & reliable.
# **Goals**
---
1. Simplify the ingestion process
2. Make the process able to quietly update SwiftData in the background
3. Remove the "loading" screens. Initial "putting it all together" the first time the app loads can remain, but it should just periodically refresh the SwiftData "cache" in the background, quietly.
4. Display a simple "offline" token when no connection exists, but show data for last known good location and weather details.
5. Warnings need a hot load path that is on a totally different schedule than other products
6. All paths flow thru the same ingestion flow. Location change, app load, & background.
# **Non-Goals**
---
- Don't rebuild the app
- Avoid creating a god object
- don’t add new features
# **Done When**
---
1. UI loads from SwiftData
2. No more loading screens except for the initial “setting it up” screen
3. App start, background, location changes, & remote APNs all follow the ingestion flow
4. Data is fresh
5. Offline badge shows when not connected
# **Users / Consumers**
---
- Users shouldn't really notice anything of note, ideally the data is loaded quietly and reliably in the background and the data just "magically" surfaces to the user in the UI.
- The entire app will consume this data after it's been populated into the SwiftData datastore.
# **Proposed Solutions**
---
## **A) Solution 1**
I think a dedicated actor is the right play here. It can hold state and operate threaded with concurrency.

Clients should stay dumb and have zero logic. Repos only interact with data layer

I want this solution to assume that all UI components will read from the database and not make direct network calls. This is pretty much how it happens, but want to ensure that we don't have "pretty much" situations going forward. We need to identify the products, their target paths and then pull them. We created a few file stubs to evaluate against.

Avoid god objects and try to decompose into buildable pieces.

The home projection should be the launch source. The app should load from that cached projection first, then refresh any necessary products in the background and update the projection as new data becomes available.

### **Home Projection Contract**
- The home projection should contain the user-facing data needed to render the primary local summary quickly from cache.
- Persist the home projection as a SwiftData model so the app can launch directly from it and update it incrementally over time.
- The projection should include:
  - current location details
  - latitude / longitude
  - H3 cell
  - resolved local zone metadata
  - current weather
  - storm risk
  - severe risk
  - fire risk
  - active local alerts
  - active local mesos
- Keep projections keyed by location context so the app can support multiple locations in the future.
- On launch, if a projection exists for the current location context, open with it. If one does not exist for the current location context, create it.
- The app should treat the projection as incrementally mergeable. Each lane may update its portion of the projection as new data becomes available rather than forcing a full rebuild every time.
- If the user moves to a new location, the projection for that location should reflect the local alerts, mesos, and risk profile for the new context without requiring slow products to reload first.
- The coordinator result should stay simple and reliability-focused. Prefer lightweight success / updated / no-change style outcomes with errors logged rather than a large, brittle result taxonomy.
- APNs-specific dedupe and authoritative warning state should lean on server-managed identifiers and revisions, while the client still ensures the local projection reflects the latest relevant warning state.
- UI observation should prefer native SwiftUI observation patterns and stay as lightweight as possible. Do not introduce MVVM or heavier abstractions unless they provide a clear reliability or responsiveness benefit.
- The app may evolve to support multiple saved locations later, but the current launch behavior should remain focused on the current resolved location context.

### **Projection Merge And Diff Contract**
- Treat the home projection as a keyed record composed of lane-owned slices rather than as a monolithic object that must always be rebuilt from scratch.
- Projection identity should come from the resolved local context for the current location.
- If a projection already exists for the current location context, update that projection in place.
- If no projection exists for the current location context, create a new projection and allow lanes to fill in incrementally.
- Lane ownership should stay simple:
  - `location`
    - owns the resolved local context, coordinates, H3 cell, and zone metadata
  - `weather`
    - owns current weather fields
  - `hot alerts`
    - owns active local alerts and active local mesos
  - `slow products`
    - owns local storm, severe, and fire risk projection data
- Lane merges should only replace the fields owned by that lane.
- A hot-alert refresh should replace the local alert and meso slice atomically without disturbing weather or risk data.
- A weather refresh should replace only the weather slice.
- A slow-product refresh should replace only the local risk slice.
- A location-context change should select or create a different keyed projection for that location and then allow hot alerts, weather, and risk to merge into it as they become available.
- Each successful ingestion run should produce a lightweight projection delta.
- The delta should summarize:
  - which lanes changed
  - whether the projection was newly created
  - whether the location context changed
  - meaningful local changes such as:
    - risk profile changed
    - alerts added, removed, or revised
    - mesos added or removed
- The delta should stay intentionally lightweight and should not become a second full projection model.
- Downstream consumers such as future local risk-change notifications should read the projection delta rather than re-querying providers or re-diffing the full app state.
- UI should continue to observe the current projection through native SwiftUI observation and swap in the updated projection as soon as the coordinator commits it.
- Keep the ingestion result compact and reliability-focused. It should be able to answer:
  - was a projection written or updated
  - which lanes changed
  - what meaningful local delta occurred
  - whether the hot-alert state materially changed for APNs continuation handling

### **Minimal SwiftData Projection Schema**
- The SwiftData projection model should separate:
  - identity and lookup fields
  - cached user-facing payload fields
  - bookkeeping timestamps
- Minimal identity and lookup fields should include:
  - `id`
  - `latitude`
  - `longitude`
  - `h3Cell`
  - `countyCode`
  - `forecastZone`
  - `fireZone`
  - `placemarkSummary`
  - `timeZoneId` if readily available from the resolved grid metadata
- A single generic `zone` field is likely too coarse for SkyAware because the app already reasons about county, forecast zone, and fire zone separately.
- Minimal bookkeeping fields should include:
  - `locationTimestamp`
  - `createdAt`
  - `updatedAt`
  - `lastViewedAt` or equivalent if we want lightweight future support for multiple saved locations and projection cleanup
- The projection model must also persist the cached payload slices that power the home experience:
  - current weather
  - storm risk
  - severe risk
  - fire risk
  - active local alerts
  - active local mesos
- Keep this schema pragmatic.
- Do not try to persist every field from the underlying provider and repo models if the home projection does not need them to render quickly.

Offline should be based on whether the app can currently reach live network services and obtain fresh data. Cached data may still be shown while offline.

For non-hot paths, a lightweight `NWPathMonitor` signal is sufficient. For the hot alert lane, the app should also account for whether Arcus Signal is reachable so warning delivery does not rely only on local path status.

Freshness should remain an internal concern. It should guide ingestion policy, background scheduling, and diagnostics, but should not become a trust-eroding badge in the primary user experience.

Notifications should be treated as downstream consumers of ingestion rather than part of the ingestion core. Notification policy is its own area of work, but ingestion must guarantee that it checks for the latest available data before any notification is generated.

### **Notifications As Downstream Consumers**
- Ingestion should never directly own notification policy.
- A separate downstream notification step may run after ingestion completes for eligible triggers.
- Notification evaluation must only use data that was just refreshed or explicitly verified by the ingestion run.
- Notification failures should be logged, but should not fail the ingestion run itself.
- Prefer passing already refreshed data into downstream notification consumers rather than having notification engines perform new fetches of their own.
- Preserve the current engine-style decomposition where it helps:
  - rule
  - gate
  - composer
  - sender
- `MorningEngine`
  - remains client-side
  - should be triggered by background execution any time between 7am and 11am local
  - must only run after ingestion has verified the latest available data for that notification window
- `MesoEngine`
  - is expected to migrate to the server over time
  - client-side meso notification logic should be treated as transitional
- `WatchEngine`
  - has effectively been replaced by the server-driven path
  - client-side watch notification logic should be removed from the app as part of this ingestion project
- Client-side meso notification cleanup is out of scope for this effort and should be treated as separate work.
- Foreground and manual refresh paths should not emit notifications.
- `background refresh`
  - may evaluate downstream morning notification paths after ingestion has verified the latest available data
- `background location change`
  - should focus on ingestion and projection refresh for the new context
- `remote hot alert received`
  - primary purpose is cache warming and projection continuity
  - should not create duplicate local notifications by default when APNs has already delivered the warning
- `remote hot alert opened`
  - primary purpose is ensuring the alerted warning is locally available and visible in-app
  - should not trigger a second local notification path
- Notification settings should gate which downstream notification families are evaluated.

### **Future Notification Seed**
- Plant a future client-side local notification path for meaningful local risk-profile changes.
- Example cases:
  - moving from thunderstorms to marginal storm risk
  - a tornado probability area begins covering the user's location
- This should be treated as a separate downstream consumer of ingestion results, not as part of the ingestion core.
- It should compare the previously projected local risk profile to the newly projected local risk profile and only notify on meaningful changes.

### **Trigger Rules**
- `bootstrap`
  - used when no cached home projection exists
  - may block while creating the first usable projection
  - may prompt for location if needed
- `foreground activate`
  - render cached projection immediately if available
  - run opportunistic refresh work silently in the background
  - if no cached projection exists, treat this as `bootstrap`
- `manual refresh`
  - force refresh all lanes
  - acts as a safety valve to ensure the freshest available app-wide state
- `session tick`
  - opportunistic active-app refresh
  - should stay lean and focus on hot-path work
- `foreground location change`
  - resolve the new location context
  - refresh hot-path data, weather, and re-evaluate the risk profile for the new location
  - do not refresh slow products by default
- `background refresh`
  - silent refresh path used during background execution
  - should ensure the latest available information has been fetched before any notification work begins
  - may refresh any due lanes
- `background location change`
  - silent refresh path
  - should check the hot path, weather, and re-evaluate the risk profile for the new location
  - should not refresh slow products
- `remote hot alert received`
  - silent push-driven refresh path
  - should enter the same ingestion flow
  - should focus on the hot path and projection update
  - should prioritize making the alerted warning available locally before the user opens the app
- `remote hot alert opened`
  - foreground continuation of the same alert-driven path
  - should verify that the alerted warning is available locally and visible when the user opens from the notification
  - should take precedence over ordinary foreground opportunistic work

### **Lane Rules**
- `hot alerts`
  - watches and mesos
  - separate cadence and handling from slower feeds
  - should be included in every ingestion plan
- `slow products`
  - outlooks and map-driven risk products
- `weather`
  - WeatherKit-backed summary conditions

### **Precedence And Coalescing Rules**
- The ingestion coordinator should allow only one active ingestion run at a time.
- Additional triggers should not start parallel ingestion implementations. They should be absorbed or merged into a pending follow-up plan.
- Coalescing should be based on plan coverage, not just enum ordering.
- Merge rules:
  - the newest location-bearing trigger wins for location context
  - lane requirements are unioned
  - force semantics may only escalate, never downgrade
  - weaker opportunistic work may be absorbed by stronger queued or active work
- `manual refresh`
  - highest user-driven precedence
  - upgrades the next run to a full forced refresh of all lanes
- `bootstrap`
  - absorbs opportunistic triggers while the first usable projection is being built
  - should not be displaced by passive tick-style work
- `session tick`
  - lowest precedence
  - should be absorbed by any stronger active or pending plan
- `foreground activate`
  - should absorb `session tick`
  - may be absorbed by stronger location-driven or manual work
- `foreground location change`
  - should not be dropped when it carries a newer location context than the active plan
  - should queue a follow-up run if needed to rebuild the projection for the newer location
- `background refresh`
  - may absorb weaker opportunistic background work when it already covers the required lanes
  - must still ensure data is refreshed before any downstream notification work begins
- `background location change`
  - should not be dropped if it represents a newer location context than the active background plan
  - should merge into a follow-up plan for hot path, weather, and risk re-evaluation
- `remote hot alert received`
  - must not be absorbed by weaker opportunistic work
  - should upgrade pending work to a forced hot-alert verification path
  - should remain lean so APNs-driven refreshes stay fast and reliable
- `remote hot alert opened`
  - should be treated as highest-priority pending follow-up work for app-open continuity after a push notification tap
  - should supersede ordinary `foreground activate` opportunistic work while still using the same ingestion coordinator

### **Trigger Wiring And Coordinator Shape**
- Keep one public ingestion coordinator as the single entry point for all app-layer triggers.
- That coordinator should serialize ingestion work and own only:
  - active run state
  - pending merged follow-up plan
  - trigger submission and coalescing
  - dispatching a concrete ingestion plan to the execution layer
- Do not let the coordinator absorb unrelated responsibilities such as notification policy, background scheduling, or SwiftUI loading presentation.
- Start with the smallest practical shape:
  - a thin single-flight queue actor that owns one active run and one pending merged plan
  - the existing `HomeRefreshV2` execution path performs the actual ingestion work for a concrete plan
- Only extract a separate planner type if the plan-building logic becomes noisy enough to justify it.
- The execution layer should:
  - perform one ingestion plan
  - sync the required lanes
  - write SwiftData caches and the keyed home projection
  - return a lightweight ingestion result and projection delta
- The coordinator should expose two call styles:
  - `enqueue`
    - fire-and-forget for opportunistic paths such as scene active, session tick, and passive location change handling
  - `enqueueAndWait`
    - used when the caller needs completion semantics
    - examples:
      - bootstrap
      - manual refresh
      - background refresh
      - background location change
      - remote hot alert received
      - remote hot alert opened
- Waiting should mean:
  - wait for the run that satisfies the submitted request
  - not necessarily a brand new dedicated run if an active or pending plan already covers the submitted work
- The coordinator's internal state should stay small:
  - `activePlan`
  - `activeTask`
  - `pendingPlan`
  - lightweight waiter bookkeeping for callers that need a completion result
- `pendingPlan` should carry merged requirements, not just the last trigger enum:
  - required lanes
  - force flags
  - newest location-bearing requirement
  - trigger provenance flags such as:
    - background
    - manual
    - remote hot alert received
    - remote hot alert opened
  - optional remote alert payload context
- The merge rules should remain simple:
  - hot alerts are always included
  - union lane requirements
  - only escalate force semantics
  - newest location-bearing request wins
  - stronger trigger provenance may upgrade pending work
  - weaker opportunistic requests never downgrade active or pending work
- A remote hot-alert trigger received during a background refresh should normally merge into that same ingestion run rather than forcing a separate specialized path.
- The practical effect is:
  - if a background refresh is already running, merge the remote hot-alert requirement into it and load the full background plan
  - only queue an immediate follow-up hot-alert verification if the active run has already passed the hot-alert portion and can no longer satisfy the remote request
- Keep trigger adapters thin:
  - `HomeView` / foreground scene handling
    - submit `foreground activate`
    - submit `manual refresh`
    - submit `session tick`
    - submit `foreground location change`
  - background app refresh handler
    - submit `background refresh`
    - await result
    - then run downstream notification and cadence logic
  - background location change handler
    - submit `background location change`
    - await result
  - APNs background receipt
    - submit `remote hot alert received`
    - await result for `UIBackgroundFetchResult`
  - notification-open path
    - submit `remote hot alert opened`
    - await result before driving the user to the warned event if needed
- This keeps all ingestion work in one place while preserving trigger-specific side effects outside the coordinator.

### **Implementation Direction**
- Treat `HomeRefreshV2` as the target path for this work.
- It is acceptable to cut directly from the current V1 flow to the new V2 ingestion flow once the pieces are in place and validated.
- Do not preserve a long-lived dual-ingestion architecture beyond what is needed during development.

Inputs to address:
- spc convective outlooks ~3 hrs
- Spc map products ~2 hrs 
- Spc mesos - ~60 min
- Spc fire risk ~2 hrs
- Arcus signal alerts - hot load
- Apple weather - 30 minutes
# **APIs / Services Impact**
---
- May need to create API endpoints to support hot load paths.
- Remote hot-alert payloads should include the alert identifier and timestamp from the server.
- The app should use that payload to request a fast single-alert endpoint so the warned event can be loaded locally with minimal delay.
# **Risks / Edge Cases**
---
- Stale data
- fetching on location changes.
- need to take into account our background cadence rules that are based on being in a warning
# **Observability**
---
- Log it like everything else for now.
- Surface lane freshness and degraded/stale conditions in diagnostics, settings, or logs rather than the primary summary UI.
- Add a simple diagnostics view reachable from Settings that shows each ingestion lane/source and its last successful load time.
# **MVP Slice (v1)**
---
1. Shift the slower feeds
2. Shift the hot feeds
3. Implement the remote refresh (APNs)

# **Proposed Issue Breakdown**
---
1. Define and Persist the Home Projection in SwiftData
2. Build the Unified Home Ingestion Queue on `HomeRefreshV2`
3. Load the Home Experience from the Cached Projection
4. Route Foreground Triggers Through the Unified Ingestion Flow
5. Route Background Refresh and Background Location Changes Through the Unified Ingestion Flow
6. Implement Remote Hot-Alert Ingestion for APNs Receipt and Open
7. Add Runtime Offline State and Surface the Offline Token
8. Remove Client-Side Watch Notifications from the App
9. Add Ingestion Diagnostics in Settings
# **Open Questions**
---
1. How should trigger wiring and coalescing be implemented in code so all entry points normalize into one pending-plan ingestion coordinator?
2. What is the minimal SwiftData projection schema needed to persist keyed home projections cleanly without over-modeling the app state?
