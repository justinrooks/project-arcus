# SkyAware Timely Notifications Strategy Brief (LLM Handoff)

## Intention
Build a reliable, near-real-time severe weather alerting system for SkyAware that can notify users quickly when their current location is affected by mesos, watches, or warnings, while respecting iOS platform constraints, user privacy, and App Store policy.

## App Context
SkyAware is an iOS weather safety app using SPC/NWS data for location-aware alerting.
Current implementation relies primarily on iOS background refresh scheduling (`BGAppRefreshTask`) plus in-app sync logic.

## Current State Snapshot
- App currently uses background task scheduling and a background orchestrator for SPC/NWS sync and notification decisions.
- App does not currently have an APNs remote-notification pipeline implemented for server-driven event pushes.
- Entitlements currently include WeatherKit but not Critical Alerts entitlement.
- Background modes include `fetch`, `processing`, and `location`.

## Core Learnings
- `BGAppRefreshTask` is best-effort, not a strict interval timer.
- iOS cannot guarantee deterministic background execution every X minutes for standard apps.
- `BGProcessingTask` is also policy/condition dependent and not a hard real-time trigger.
- If timely background alerts are required, the primary pattern is backend event detection plus APNs push delivery.
- Silent push (`content-available`) is useful but opportunistic and can be throttled.
- Foreground polling can be faster, but it does not solve background timeliness.
- Critical Alerts can break through mute/Focus, but require Apple approval and careful use policy.

## Product Goal Clarification
Primary user value:
- Notify users as quickly as possible when their current location enters or is already in an active meso/watch/warning event.

## High-Level Architecture (Recommended)
1. Feed Ingestion Service
- Poll SPC/NWS sources frequently (for example, 30-60 seconds).
- Normalize raw data into a single internal event schema.

2. Event State Engine
- Deduplicate event updates.
- Track lifecycle state transitions: `new`, `updated`, `cancelled`, `expired`.
- Version each event revision for idempotent notifications.

3. Geospatial Targeting
- Convert event polygons to indexed cells.
- Match impacted cells to active device presence records.
- Run final precision check (point-in-polygon) near boundaries when needed.

4. Notification Policy Engine
- Apply per-event rules by severity/type.
- Map to APNs interruption level (`active`, `time-sensitive`, `critical` where approved).
- Enforce cooldowns and anti-spam logic.

5. Push Delivery Service
- Send APNs notifications using token auth over HTTP/2.
- Batch sends via queue workers.
- Retry transient failures and tombstone invalid tokens.
- Persist delivery outcomes for audit/dedupe.

6. App Sync API
- On notification open, app fetches canonical event state from backend.
- Keep client local cache consistent with server truth.

7. Observability plus SLOs
- Track ingestion latency, match latency, push acceptance, and user engagement.
- Define target SLOs (for example: event ingestion to APNs accepted under p95 threshold).

## Geospatial Index Strategy

### NWS Grid (Practical V1 Option)
- Candidate `cell_id`: `office/gridX/gridY`.
- Good fit because SkyAware already resolves NWS points metadata.
- Caveat: coarse-cell boundaries can produce false positives/negatives.
- Mitigation: run final point-in-polygon check for edge candidates before push.

### H3/S2 (General-Purpose Option)
- H3 (Uber): hierarchical global index with mostly hexagonal cells.
- S2 (Google): hierarchical global index based on spherical projection onto cube faces.
- Both support fast:
  - `lat/lon -> cell_id` (device presence)
  - `polygon -> [cell_id...]` (event coverage)
  - set-based matching (`event_cells` join `device_cells`)
- Practical recommendation: pick one system and one resolution for v1, then tune.

### What3words Fit Check
- Usually not ideal for backend alert targeting.
- It is optimized for human-readable addressing, not high-throughput polygon matching.
- Adds proprietary/vendor dependency and licensing considerations.
- Better fit for this scenario: NWS grid or H3/S2 plus geometry refinement.

## How H3/S2 Works in This Pipeline
1. Presence ingest:
- App sends location to backend via HTTPS.
- Backend maps `lat/lon` to one `cell_id` at chosen resolution.
- Store `device_id`, `apns_token`, `cell_id`, `updated_at`, preferences.

2. Event ingest:
- New/updated SPC/NWS polygon arrives.
- Backend polyfills polygon into `event_cells`.

3. Targeting:
- Query devices where `device.cell_id IN event_cells`.
- Optional precision refinement:
- exact point-in-polygon check for boundary risk reduction.

4. Delivery:
- Deduplicate via (`device_id`, `event_id`, `revision`, `channel`).
- Apply policy and send APNs.

5. Cleanup:
- Expire stale presence records by TTL.
- Remove invalid APNs tokens.

## Accessing H3 (Implementation Notes)
- H3 core is a C library.
- Use official docs for install and community-maintained language bindings.
- For C# backend, use a C# binding and hide it behind an internal abstraction.

Suggested server abstraction:
- `toCell(lat, lon) -> cell_id`
- `polyfill(polygon) -> [cell_id]`
- `neighbors(cell_id, k) -> [cell_id]`

Guidance:
- Use H3 server-side first (no iOS dependency required).
- Keep a `GeoIndexService` interface so you can swap binding/provider later.
- Keep one canonical resolution per alerting pipeline in v1.

## Device Location Presence Model
Important principle:
- Devices do not send location to APNs.
- Devices send location presence to SkyAware backend via HTTPS.

Presence update triggers:
1. App launch and app foreground.
2. Significant movement threshold.
3. Periodic heartbeat while app is actively used.
4. Optional significant-location-change background updates (requires appropriate permission mode).

Presence payload should include:
- APNs token
- User alert preferences
- Last known location or derived cell
- Timestamp/version/app build metadata

## iOS Permission and Accuracy Tradeoff
- With only When-In-Use location, background location freshness may become stale.
- For strongest current-location alert quality, an optional Always Allow location mode may be needed.
- UX and privacy messaging should be explicit and user-controlled.

## Critical Alerts (Detailed Guidance)
What it is:
- Notification class that can bypass mute/Focus and play sound for urgent scenarios.

Why relevant:
- Potentially appropriate for severe weather emergencies when justified.

Constraints:
- Requires Apple’s Critical Alerts entitlement approval.
- Must be narrowly scoped and policy-driven to avoid misuse.
- Should include fallback behavior when users disable critical alerts.

Practical policy suggestion:
- Candidate: high-severity warnings.
- Usually non-critical: informational updates and many mesos.
- Consider Time Sensitive for important but not emergency-level events.

## Suggested Technology Stack
Server language/runtime:
- C# with ASP.NET Core is a strong fit.

Core components:
- API plus workers: ASP.NET Core
- Database: PostgreSQL + PostGIS
- Cache/presence acceleration: Redis
- Queue: Service Bus or SQS
- APNs sender: dedicated service for reliability and isolation

Cloud recommendation:
- Azure is a natural fit for C# teams.
- AWS is equally viable if team infra maturity is stronger there.

## Delivery Reliability Principles
- Idempotency key per (`device_id`, `event_id`, `revision`, `channel`).
- Separate ingestion, targeting, and sending into independent workers.
- Use dead-letter queues for failed sends.
- Backoff/retry on transient provider failures.
- Periodic cleanup for stale presence and invalid tokens.

## Security and Privacy Principles
- Minimize retention of precise location.
- Prefer coarse cell storage for targeting where possible.
- Encrypt sensitive data at rest and in transit.
- Keep auditable access to notification and location pipelines.

## Minimum Viable Rollout Plan
Phase 1:
- Backend ingestion plus event normalization plus APNs visible notifications for warnings.
- Device presence API and token registration.

Phase 2:
- Cell-based geospatial matching plus meso/watch routing.
- Dedupe, cooldowns, and delivery analytics.

Phase 3:
- Optional silent push prefetch optimization.
- Critical Alerts request and gated rollout if approved.

Phase 4:
- Advanced policy tuning with user controls and reliability SLO dashboards.

## Risks to Plan Around
- Apple background execution unpredictability if relying on client-only refresh.
- Location freshness degradation without always-on permission.
- Over-notification risk without strict dedupe and policy tuning.
- Boundary misclassification if using only coarse cells without precision check.

## Open Questions for Next Design Session
1. Exact notification policy matrix by event type and severity.
2. User permission UX for Always location vs When-In-Use.
3. Geographic indexing choice for v1 (NWS grid only vs H3/S2 hybrid).
4. Data retention windows for device presence and delivery logs.
5. Critical Alerts qualification strategy and fallback behavior.

## LLM Starter Prompt (Copy/Paste)
You are helping design the SkyAware backend alerting platform.
Goal: near-real-time location-based meso/watch/warning notifications for iOS users.
Constraints:
- iOS BGAppRefresh is best-effort and cannot guarantee strict intervals.
- APNs is the primary background delivery mechanism.
- Silent pushes are opportunistic.
Current preference:
- C# ASP.NET Core backend
- PostgreSQL/PostGIS + Redis + queue workers
- NWS grid-based cell strategy for v1 with geometry refinement near boundaries
- Evaluate H3 for generalized long-term indexing and scaling
Please produce:
1. A concrete v1 architecture diagram and service boundaries.
2. DB schema draft (devices, presence, events, event revisions, deliveries).
3. Ingestion-to-delivery pipeline with idempotency and retries.
4. Notification policy matrix for meso/watch/warning using active/time-sensitive/critical.
5. API contract draft for device registration and presence updates.
6. A phased implementation plan with operational metrics and SLOs.

## Useful References
- H3 Installation: https://h3geo.org/docs/installation
- H3 Bindings: https://h3geo.org/docs/community/bindings/
