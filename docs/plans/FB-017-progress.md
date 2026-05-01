# FB-017 Progress Log

## Overview

FB-017 adds SkyAware home screen widgets.

Implementation should proceed one issue at a time under epic `#11 [Epic] FB-017 Widgets`, following `docs/plans/FB-017-issue-runbook.md`.

Primary source of truth:
- `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/Efforts/Notes/FB-017 Widgets.md`

Related follow-up:
- `/Users/justin/Library/Mobile Documents/iCloud~md~obsidian/Documents/Second Brain/Efforts/Notes/FB-018 Widget Deep Linking.md`

Related GitHub issues:
- `justinrooks/project-arcus#11` - `[Epic] FB-017 Widgets`
- `justinrooks/project-arcus#153` - `FB-017: Add widget target and App Group plumbing`
- `justinrooks/project-arcus#154` - `FB-017: Add derived widget snapshot model`
- `justinrooks/project-arcus#155` - `FB-017: Add app-group widget snapshot store`
- `justinrooks/project-arcus#156` - `FB-017: Add widget snapshot builder and alert priority`
- `justinrooks/project-arcus#157` - `FB-017: Integrate widget snapshot writes into ingestion`
- `justinrooks/project-arcus#158` - `FB-017: Add latest projection fallback for widgets`
- `justinrooks/project-arcus#159` - `FB-017: Wire APNs-driven widget snapshot refresh`
- `justinrooks/project-arcus#160` - `FB-017: Add shared widget rendering components and previews`
- `justinrooks/project-arcus#161` - `FB-017: Implement small Storm Risk widget`
- `justinrooks/project-arcus#162` - `FB-017: Implement small Severe Risk widget`
- `justinrooks/project-arcus#163` - `FB-017: Implement large Combined widget`
- `justinrooks/project-arcus#164` - `FB-017: Wire Summary tap routing for widgets`
- `justinrooks/project-arcus#165` - `FB-017: Add widget state and refresh validation`

---

## Global Decisions

- V1 includes exactly three widgets:
  - small Storm Risk
  - small Severe Risk
  - large Combined
- Storm Risk and Severe Risk widgets mirror their corresponding in-app badge semantics.
- The Combined widget shows storm risk, severe risk, and one active local alert row.
- The Combined alert row should match one line of the in-app active local alerts view as closely as WidgetKit allows.
- If multiple active local alerts exist, Combined shows only the most severe.
- V1 alert priority is:
  1. tornado
  2. severe thunderstorm
  3. flooding
  4. mesoscale discussion
  5. watch
- Hidden lower-priority active alerts use a compact `+N more` indicator.
- Widget snapshots older than 30 minutes are stale.
- Stale snapshots remain visible but must be marked stale.
- Freshness copy should use concise timestamp language such as `Updated 2:14 PM`.
- Unavailable current readouts use `Open SkyAware to update local risk.`
- Widget taps open Summary in FB-017.
- Widget deep linking is deferred to FB-018.
- The widget extension reads app-owned derived snapshots from an App Group container.
- The widget extension must not initiate ingestion, location workflows, notification registration, or network fetches.
- Widget snapshots contain derived display state only, not raw location, APNs tokens, or unnecessary full alert payload bodies.
- The app writes widget snapshots after risk or active alert state changes.
- The APNs-driven alert update path must update the widget snapshot and request targeted WidgetKit timeline reloads.
- APNs refresh is split into two slices:
  - latest projection fallback
  - APNs-driven snapshot write and reload wiring
- Use GPT-5.3-Codex with medium reasoning for implementation sub-issues unless a later issue explicitly justifies a different model.

---

## Current Status

- Epic `#11` has been repurposed from the older severe-threat-only scope to the full FB-017 widget scope.
- FB-017 runbook and progress documents have been created.
- Sub-issues `#153` through `#165` have been created.
- Sub-issues `#153` through `#165` are attached as real GitHub sub-issues under epic `#11`.
- Epic `#11` and sub-issues `#153` through `#165` have been added to the Project Arcus GitHub Project.
- Implementation has not started.
- First issue to implement: `#153`.

---

## Codebase Investigation Notes

- No WidgetKit target exists yet.
- `SkyAware.xcodeproj` is hand-maintained; there is no XcodeGen or SwiftPM app package manifest driving targets.
- `SkyAware.entitlements` currently contains APNs and WeatherKit entitlements, but no App Group entitlement.
- Existing `UserDefaults.shared` uses the suite `com.justinrooks.skyaware`; it should not be repurposed as the widget App Group store.
- Relevant existing app paths:
  - `Sources/App/HomeRefreshV2/HomeSnapshot.swift`
  - `Sources/App/HomeRefreshV2/HomeSnapshotStore.swift`
  - `Sources/Repos/HomeProjectionStore.swift`
  - `Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift`
  - `Sources/App/RemoteHotAlertHandler.swift`
  - `Sources/App/SkyAwareAppDelegate.swift`
  - `Sources/App/HomeRefreshPipeline.swift`
  - `Sources/App/HomeView.swift`
  - `Sources/Features/Badges/StormRiskBadgeView.swift`
  - `Sources/Features/Badges/SevereWeatherBadgeView.swift`
  - `Sources/Features/Summary/ActiveAlertSummaryView.swift`
  - `Sources/Features/Alert/AlertRowView.swift`
- Existing value shapes likely relevant to snapshot generation:
  - `HomeSnapshot`
  - `WatchRowDTO`
  - `MdDTO`
  - `StormRiskLevel`
  - `SevereWeatherThreat`
- The current APNs path already funnels remote alert work through `RemoteHotAlertHandler` and `HomeIngestionCoordinator`.
- A latest projection fallback is needed because an APNs-triggered refresh may not have a current foreground `HomeSnapshot` context available.
- `HomeProjectionStore` currently reads by context; widget refresh needs a safe latest-projection read path before APNs wiring can be reliable.

---

## Issue #153 - Add widget target and App Group plumbing

### Status
- Completed (2026-05-01)

### Scope
- Add the WidgetKit extension target.
- Add required target membership, bundle id, plist/configuration, and project settings.
- Add App Group entitlements for the app and widget extension.
- Add a minimal placeholder widget that compiles.
- Do not implement final widget UI or snapshot behavior yet.

### Relevant feature brief sections
- `Dependencies`
- `Constraints / Invariants`
- `Done Means`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- This issue establishes the target/configuration foundation for all later widget work.
- Implemented a new `SkyAwareWidgetsExtension` WidgetKit extension target in `SkyAware.xcodeproj` with:
  - bundle id `com.skyaware.app.widgets`
  - extension plist `Config/WidgetExtension-Info.plist`
  - extension entitlements `Config/SkyAwareWidgets.entitlements`
  - app embed phase (`Embed App Extensions`) and target dependency wiring
- Added App Group entitlement `group.com.skyaware.app` to both:
  - `SkyAware.entitlements` (app)
  - `Config/SkyAwareWidgets.entitlements` (widget extension)
- Added a minimal passive placeholder widget at `WidgetsExtension/SkyAwareWidgetsBundle.swift` to validate target plumbing only.
- Intentionally deferred all future-scope work:
  - derived widget snapshot model (#154)
  - app-group snapshot store (#155)
  - ingestion/APNs refresh wiring (#157-#159)
  - final widget UI, previews, and routing/deep linking (#160+ / FB-018)
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded with widget extension embedded.

---

## Issue #154 - Add derived widget snapshot model

### Status
- Completed (2026-05-01)

### Scope
- Define Codable, Sendable widget snapshot value types.
- Include derived display state for storm risk, severe risk, selected alert row, hidden-alert count, stale/unavailable flags, freshness timestamp, and Summary routing destination.
- Keep raw location, tokens, and full alert payload bodies out of the snapshot.
- Add focused unit tests for encoding, decoding, stale threshold behavior, and unavailable fallback state.

### Relevant feature brief sections
- `Widget Refresh Direction`
- `Constraints / Invariants`
- `Acceptance Criteria`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- Added a shared widget snapshot transport contract at `Shared/WidgetSnapshot.swift`, compiled into both the app and widget extension targets.
- Snapshot types are `Codable`, `Sendable`, and value-only:
  - `WidgetSnapshot`
  - `WidgetRiskDisplayState`
  - `WidgetSelectedAlertRowDisplayState`
  - `WidgetFreshnessState`
  - `WidgetAvailabilityState`
  - `WidgetSummaryDestination`
- The model now explicitly represents:
  - storm risk and severe risk display label/severity
  - Combined selected alert row display fields
  - hidden alert count
  - freshness timestamp and explicit freshness state (`fresh`, `stale`, `unavailable`)
  - unavailable fallback state/copy (`Open SkyAware to update local risk.`)
  - Summary routing destination at the model level only
- Privacy guardrails in model shape:
  - no raw location fields
  - no APNs token fields
  - no full alert payload-body fields
- Added focused tests at `Tests/UnitTests/WidgetSnapshotTests.swift` covering:
  - deterministic encode/decode round-trip
  - 30-minute stale threshold behavior
  - unavailable fallback snapshot state/copy
  - derived-only payload shape assertions
- Project membership updates:
  - added `Shared/` root group to `SkyAware` and `SkyAwareWidgetsExtension` file-system synchronized target membership
  - added `UnitTests/WidgetSnapshotTests.swift` to file-system membership exceptions for app/tests target handling
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SkyAwareTests/WidgetSnapshotTests/encodedPayload_isDerivedOnly test` succeeded.
- Deferred to later issues as planned:
  - app-group snapshot storage (#155)
  - snapshot builder/priority logic (#156)
  - ingestion/APNs writes and WidgetCenter reload wiring (#157-#159)
  - widget UI/rendering/timeline and Summary routing integration (#160+)

---

## Issue #155 - Add app-group widget snapshot store

### Status
- Completed (2026-05-01)

### Scope
- Add a small App Group-backed snapshot store.
- Support atomic-enough read/write behavior for Codable snapshots.
- Expose app-side write and widget-side read entry points without coupling the widget to SwiftData or ingestion.
- Add focused tests for missing snapshot, corrupt data, read/write round trip, and stale metadata preservation.

### Relevant feature brief sections
- `Widget Refresh Direction`
- `Constraints / Invariants`
- `Dependencies`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- Added shared App Group-backed snapshot persistence at `Shared/WidgetSnapshotStore.swift` for use by both app and widget targets.
- Store behavior is intentionally narrow and independent from SwiftData, network, location, notification, and ingestion APIs:
  - app-side write via `write(_:)`
  - widget-side read via `load()`
- Uses App Group container `group.com.skyaware.app` by default and writes to `widget-snapshot.json`.
- Added deterministic load outcomes:
  - `.missing` when no snapshot exists
  - `.corrupt` when data is unreadable/invalid
  - `.snapshot(WidgetSnapshot)` when decode succeeds
- Snapshot writes use atomic file replacement (`Data.write(..., options: [.atomic])`) and preserve existing freshness metadata exactly as stored in `WidgetSnapshot`.
- Kept widget storage fully separate from `UserDefaults.shared`.
- Added focused tests at `Tests/UnitTests/WidgetSnapshotStoreTests.swift`:
  - missing snapshot -> `.missing`
  - corrupt/unreadable data -> `.corrupt`
  - write/read round-trip equality
  - stale freshness metadata preservation
- Updated `SkyAware.xcodeproj/project.pbxproj` test membership exception lists to include `WidgetSnapshotStoreTests.swift`, matching existing file-system-synced target patterns.
- Skill gate notes:
  - `swift-concurrency-expert` evaluated as applicable (cross-target shared value + strict concurrency compile rules); no async actor boundary changes were needed beyond removing unnecessary `Sendable` conformance from the store wrapper.
  - `build-ios-apps:swiftui-ui-patterns` not applicable for this issue slice (no SwiftUI/widget UI work in #155).
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:SkyAwareTests/WidgetSnapshotStoreTests test` succeeded.
- Deferred exactly as planned:
  - snapshot builder and alert priority logic (#156)
  - ingestion/APNs snapshot write wiring and widget reload requests (#157-#159)
  - widget UI, timeline presentation, and routing work (#160+)

---

## Issue #156 - Add widget snapshot builder and alert priority

### Status
- Not started

### Scope
- Build derived widget snapshots from existing app projection/state values.
- Reuse existing storm and severe risk semantics.
- Select the Combined alert row with the approved priority order.
- Compute `+N more`.
- Filter expired alerts out of active widget state.
- Add deterministic tests for normal, no-alert, multiple-alert, priority, hidden count, expired-alert, stale, and unavailable states.

### Relevant feature brief sections
- `Target Behavior`
- `Widget Design Principles`
- `Constraints / Invariants`
- `Acceptance Criteria`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- This should be the single app-owned place that translates rich app state into widget-safe display state.

---

## Issue #157 - Integrate widget snapshot writes into ingestion

### Status
- Not started

### Scope
- Write updated widget snapshots after app-owned risk or active alert projection changes.
- Request targeted WidgetKit timeline reloads for affected widget kinds.
- Avoid duplicate ingestion, location, notification registration, or network work from widget code.
- Add focused tests around write/reload triggering where practical.

### Relevant feature brief sections
- `Widget Refresh Direction`
- `Constraints / Invariants`
- `Acceptance Criteria`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- This is the normal app ingestion/projection path, separate from APNs fallback and APNs-driven refresh wiring.

---

## Issue #158 - Add latest projection fallback for widgets

### Status
- Not started

### Scope
- Add a narrow latest-projection read path suitable for widget snapshot refresh.
- Use it when APNs/background refresh paths lack a current foreground context.
- Preserve existing context-specific projection behavior.
- Add focused tests proving latest projection selection is deterministic and does not disturb existing projection reads.

### Relevant feature brief sections
- `Widget Refresh Direction`
- `Risks / Edge Cases`
- `Acceptance Criteria`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- This is the first half of APNs refresh work. Do it before APNs wiring so the handler has a reliable source for widget snapshots.

---

## Issue #159 - Wire APNs-driven widget snapshot refresh

### Status
- Not started

### Scope
- Extend the remote alert/APNs handling path so completed alert refresh work updates the widget snapshot.
- Use the latest projection fallback when needed.
- Request targeted WidgetKit timeline reloads after writing the snapshot.
- Preserve existing notification, ingestion, and background handling semantics.
- Add focused tests around APNs-triggered snapshot writes and targeted reload requests.

### Relevant feature brief sections
- `Widget Refresh Direction`
- `Constraints / Invariants`
- `Acceptance Criteria`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- This is the second half of APNs refresh work. It should consume the latest-projection fallback rather than invent another projection path.

---

## Issue #160 - Add shared widget rendering components and previews

### Status
- Not started

### Scope
- Add reusable widget rendering components for risk badges, freshness, unavailable/stale state, and compact alert row display.
- Add realistic preview fixtures for normal, no-alert, stale, unavailable, and multiple-alert states.
- Ensure components are resilient in light, dark, tinted, clear, and accessibility text settings as far as WidgetKit previews allow.

### Relevant feature brief sections
- `Widget Design Principles`
- `Widget Gallery Presentation`
- `Acceptance Criteria`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- Shared widget components should adapt app badge semantics for WidgetKit without making the small widgets cramped dashboards.

---

## Issue #161 - Implement small Storm Risk widget

### Status
- Not started

### Scope
- Implement the small Storm Risk widget using shared snapshot state and rendering components.
- Match the in-app Storm Risk badge semantics and visual language as closely as WidgetKit allows.
- Include stale, unavailable, and placeholder/gallery states.
- Add focused validation through previews and build/test coverage.

### Relevant feature brief sections
- `Goals`
- `Target Behavior`
- `Widget Gallery Presentation`
- `Acceptance Criteria`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

---

## Issue #162 - Implement small Severe Risk widget

### Status
- Not started

### Scope
- Implement the small Severe Risk widget using shared snapshot state and rendering components.
- Match the in-app Severe Risk badge semantics and visual language as closely as WidgetKit allows.
- Include stale, unavailable, and placeholder/gallery states.
- Add focused validation through previews and build/test coverage.

### Relevant feature brief sections
- `Goals`
- `Target Behavior`
- `Widget Gallery Presentation`
- `Acceptance Criteria`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

---

## Issue #163 - Implement large Combined widget

### Status
- Not started

### Scope
- Implement the large Combined widget.
- Show storm risk, severe risk, freshness, and one prioritized active local alert row.
- Show deterministic no-alert, stale, unavailable, placeholder, and `+N more` states.
- Preserve meaning without relying only on color.
- Add focused preview/build validation.

### Relevant feature brief sections
- `Goals`
- `Target Behavior`
- `Widget Design Principles`
- `Acceptance Criteria`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

---

## Issue #164 - Wire Summary tap routing for widgets

### Status
- Not started

### Scope
- Ensure all widgets open SkyAware to Summary in FB-017.
- Add the minimal route representation needed by widget entries.
- Preserve Summary fallback behavior for cold launch and warm foreground.
- Do not implement FB-018 per-alert or per-widget deep linking.
- Add focused validation where practical.

### Relevant feature brief sections
- `Target Behavior`
- `Constraints / Invariants`
- `Done Means`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- Keep route design compatible with future FB-018 deep linking, but do not build those destinations here.

---

## Issue #165 - Add widget state and refresh validation

### Status
- Not started

### Scope
- Add final validation coverage for major widget states.
- Verify snapshot generation, snapshot storage, stale handling, unavailable handling, APNs-driven refresh, targeted reload requests, Summary routing, and widget gallery metadata.
- Add or update documentation/handoff notes for refresh limits and known WidgetKit constraints.
- Confirm the app remains functional when widgets are never added.

### Relevant feature brief sections
- `Acceptance Criteria`
- `Done Means`
- `Risks / Edge Cases`

### Model recommendation
- GPT-5.3-Codex, medium reasoning

### Handoff notes
- This is the closeout issue. It should verify the whole feature rather than adding new user-facing scope.
