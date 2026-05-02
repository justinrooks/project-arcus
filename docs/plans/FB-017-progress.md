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
- Completed (2026-05-01)

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
- Added app-owned snapshot translation at `Sources/App/HomeRefreshV2/WidgetSnapshotBuilder.swift`.
- `WidgetSnapshotBuilder` accepts existing derived app state inputs (risk values, active watches/mesos, freshness timestamp, availability) and produces `WidgetSnapshot` display-only output.
- Storm and severe risk snapshot fields now reuse existing in-app badge semantics:
  - storm: `StormRiskLevel.message` + `StormRiskLevel.rawValue`
  - severe: `SevereWeatherThreat.message` + `SevereWeatherThreat.priority`
- Combined widget alert selection is deterministic and scoped to the approved v1 order:
  1. tornado
  2. severe thunderstorm
  3. flooding
  4. mesoscale discussion
  5. watch
- Expired alerts are filtered from active widget state using alert `validEnd` before selection/counting.
- Hidden alerts are represented as `hiddenAlertCount = activeCount - 1` when a selected alert exists.
- Builder emits explicit unavailable snapshots through the #154 model (`WidgetSnapshot.unavailable(...)`) and uses `WidgetFreshnessState.from(...)` for fresh/stale evaluation at the 30-minute threshold.
- Added deterministic tests at `Tests/UnitTests/WidgetSnapshotBuilderTests.swift` for:
  - normal
  - no-alert
  - multiple-alert
  - priority order
  - hidden count
  - expired-alert filtering
  - stale state
  - unavailable state
- Updated `SkyAware.xcodeproj/project.pbxproj` file-system synchronized target membership exceptions so `WidgetSnapshotBuilderTests.swift` compiles only in `SkyAwareTests`, matching the existing project pattern.
- Skill gate notes:
  - `swift-concurrency-expert` evaluated as applicable (shared Sendable snapshot values across app/widget boundaries); implementation kept the builder value-only and deterministic without introducing actor/model-context changes.
  - `build-ios-apps:swiftui-ui-patterns` not applicable in #156 because this slice is builder/state logic only (no widget SwiftUI view work).
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:SkyAwareTests/WidgetSnapshotBuilderTests -only-testing:SkyAwareTests/WidgetSnapshotTests test` succeeded.
- Explicitly deferred per plan:
  - ingestion snapshot write wiring (#157)
  - latest projection fallback (#158)
  - APNs snapshot write/reload wiring (#159)
  - widget UI/rendering/routing work (#160+)

---

## Issue #157 - Integrate widget snapshot writes into ingestion

### Status
- Completed (2026-05-01)

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
- Integrated widget snapshot refresh into the existing app-owned ingestion/projection completion seam in `HomeIngestionExecutor.persistProjection(...)`.
- Added an app-owned refresh seam at `Sources/App/HomeRefreshV2/WidgetSnapshotRefreshCoordinator.swift` that:
  - builds derived snapshots via `WidgetSnapshotBuilder` (#156),
  - writes snapshots through `WidgetSnapshotStore` (#155),
  - requests targeted `WidgetCenter.shared.reloadTimelines(ofKind:)` reloads.
- Added widget kind constants at `Shared/SkyAwareWidgetKind.swift` for targeted reload routing:
  - risk/location projection updates -> Storm Risk + Severe Risk + Combined (+ current placeholder kind),
  - active-alert-only projection updates -> Combined (+ current placeholder kind).
- Kept widget extension passive and avoided any widget-initiated ingestion, location, notification, or network work.
- APNs-specific widget refresh wiring remains deferred to #159:
  - normal ingestion path explicitly excludes `.remoteHotAlertReceived` / `.remoteHotAlertOpened` provenance from #157 snapshot refresh scope.
- Wired dependency composition in `Sources/App/Dependencies.swift`:
  - instantiate `WidgetSnapshotStore` when App Group storage is available,
  - inject optional widget snapshot refresher into `HomeIngestionExecutor.Environment`,
  - log and continue safely if the app-group store is unavailable.
- Added focused tests at `Tests/UnitTests/WidgetSnapshotRefreshCoordinatorTests.swift`:
  - risk projection writes snapshot + targeted multi-kind reload requests,
  - active-alert projection writes snapshot + Combined-targeted reload requests,
  - remote hot-alert plans excluded from normal ingestion widget refresh scope.
- Updated test fixture wiring for `HomeIngestionExecutor.Environment` additions:
  - `Tests/UnitTests/HomeRefreshPipelineTests.swift`
  - `Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift`
- Updated `SkyAware.xcodeproj/project.pbxproj` membership exception lists for the new unit test file.
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:SkyAwareTests/WidgetSnapshotRefreshCoordinatorTests -only-testing:SkyAwareTests/HomeRefreshPipelineTests test` succeeded.
- Explicitly deferred per plan:
  - latest projection fallback for widget refresh reliability (#158),
  - APNs-driven widget snapshot write + targeted reload wiring (#159),
  - widget UI/rendering/routing work (#160+).

---

## Issue #158 - Add latest projection fallback for widgets

### Status
- Completed (2026-05-01)

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
- Added a narrow latest-projection fallback read API to `Sources/Repos/HomeProjectionStore.swift`:
  - `latestProjectionForWidgetSnapshotRefresh()`
- Kept existing context-specific behavior unchanged:
  - `projection(for:)` key-based reads remain the same.
  - existing projection update/write paths remain the same.
- Latest fallback selection is deterministic and intentionally narrow for widget refresh use:
  1. `updatedAt` descending
  2. `createdAt` descending
  3. `projectionKey` ascending (stable tie-break)
- Added focused tests in `Tests/UnitTests/HomeProjectionStoreTests.swift`:
  - deterministic latest selection when timestamps tie
  - non-regression proving context-specific `projection(for:)` reads are unaffected by fallback support
- Skill gate notes:
  - `swift-concurrency-expert` evaluated as applicable (actor-isolated projection store API for background/APNs-adjacent usage); change kept actor boundaries and value semantics intact with no new cross-actor mutable sharing.
  - `build-ios-apps:swiftui-ui-patterns` not applicable for #158 (no SwiftUI/widget UI layout changes).
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:SkyAwareTests/HomeProjectionStoreTests test` succeeded.
- Explicitly deferred per plan:
  - APNs-driven widget snapshot write/reload wiring (#159)
  - widget UI/rendering/routing work (#160+)

---

## Issue #159 - Wire APNs-driven widget snapshot refresh

### Status
- Completed (2026-05-01)

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
- Wired APNs-driven widget refresh at the existing remote-alert completion seam in:
  - `Sources/App/RemoteHotAlertHandler.swift`
- Added a narrow APNs widget-refresh collaborator:
  - `RemoteAlertWidgetSnapshotRefreshDriver`
  - `LatestHomeProjectionReading` protocol (implemented by `HomeProjectionStore`)
- APNs flow behavior now:
  1. Existing remote alert ingestion completes via `coordinator.enqueueAndWait(...)`.
  2. Handler attempts widget refresh by reading `latestProjectionForWidgetSnapshotRefresh()` (#158 fallback).
  3. On success, uses existing #157 coordinator path (`WidgetSnapshotRefreshCoordinator`) with scope `.activeAlertProjection`.
  4. Scope `.activeAlertProjection` preserves targeted reload behavior (`combined` + `placeholder`) via `reloadTimelines(ofKind:)`.
- Preserved existing semantics:
  - no changes to APNs fetch-result mapping (`newData` / `noData` / `failed`)
  - no changes to notification-open focus behavior
  - no changes to ingestion lane selection or background handling contracts
  - widget refresh failures are logged and do not fail APNs ingestion/notification handling
- App wiring updates:
  - `Sources/App/SkyAwareApp.swift` now installs `RemoteHotAlertHandler` with a driver that uses:
    - app `HomeProjectionStore`
    - `WidgetSnapshotRefreshCoordinator` + `WidgetSnapshotStore` (App Group)
- Focused tests added/updated in `Tests/UnitTests/RemoteHotAlertHandlerTests.swift`:
  - APNs receipt triggers widget refresh attempt
  - notification-open path triggers widget refresh attempt
  - widget refresh failure does not change APNs receipt behavior
  - APNs driver uses latest-projection fallback and `.activeAlertProjection` targeted scope
  - APNs driver no-ops when no latest projection is available
- Validation runs:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:SkyAwareTests/RemoteHotAlertHandlerTests test` succeeded.
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:SkyAwareTests/WidgetSnapshotRefreshCoordinatorTests test` succeeded.
- Skill gate notes:
  - `swift-concurrency-expert` applied (actor/APNs/background-adjacent flow). Implementation keeps actor boundaries explicit and avoids cross-actor mutable sharing.
  - `build-ios-apps:swiftui-ui-patterns` not applicable for #159 (no SwiftUI widget UI/layout changes in this issue slice).
- Deferred per plan:
  - widget UI/rendering work (#160-#163)
  - Summary tap routing integration (#164)
  - final closeout validation (#165)

---

## Issue #160 - Add shared widget rendering components and previews

### Status
- Completed (2026-05-01)

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
- Added shared widget rendering primitives in `WidgetsExtension`:
  - `WidgetRiskBadgeView` for storm/severe badge-like display
  - `WidgetFreshnessLineView` for concise `Updated ...` freshness copy
  - `WidgetStaleStateView` for explicit stale presentation
  - `WidgetUnavailableStateView` for unavailable fallback copy
  - `WidgetCompactAlertRowView` and `WidgetNoAlertStateView` for large Combined alert/no-alert states
- Added reusable visual style mapping in `WidgetsExtension/WidgetRenderingStyle.swift`:
  - risk-severity icon/tint/chip mapping for storm and severe states
  - compact alert row icon/tint mapping with severity fallback
  - preserves meaning with iconography + text, not color alone
- Added realistic preview snapshot fixtures in `WidgetsExtension/WidgetPreviewFixtures.swift`:
  - `normal`
  - `noAlert`
  - `stale`
  - `unavailable`
  - `multipleAlerts`
- Added a preview gallery harness in `WidgetsExtension/WidgetRenderingPreviewGallery.swift` covering:
  - full-color normal/no-alert/stale/unavailable/multiple-alert states
  - tinted/accented + accessibility dynamic type
  - vibrant/clear rendering mode
  - light-scheme validation
- Updated placeholder widget rendering in `WidgetsExtension/SkyAwareWidgetsBundle.swift` to use shared rendering components and fixtures only.
- Added shared freshness copy formatter in `Shared/WidgetFreshnessFormatter.swift` so rendering copy is reusable and deterministic.
- Intentionally did not implement future issue scope:
  - no registration/exposure of final Storm/Severe/Combined widgets (#161-#163)
  - no Summary tap-routing work (#164)
  - no snapshot pipeline, ingestion, APNs, or WidgetCenter behavior changes
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded (widget extension + app compile).

---

## Issue #161 - Implement small Storm Risk widget

### Status
- Completed (2026-05-01)

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

### Handoff notes
- Replaced placeholder-only widget bundle registration with a real small Storm Risk widget in `WidgetsExtension/SkyAwareWidgetsBundle.swift`:
  - widget kind: `SkyAwareWidgetKind.stormRisk`
  - family support: `.systemSmall` only
  - gallery copy:
    - name: `Storm Risk`
    - description: `See current local storm risk.`
- Added a passive snapshot-driven timeline provider (`StormRiskProvider`) that:
  - reads from the App Group snapshot store (`WidgetSnapshotStore`) added in #155
  - uses shared snapshot model (`WidgetSnapshot`) from #154
  - never initiates ingestion, location, notification, network, or SwiftData workflows
  - refreshes passively on a 15-minute timeline policy to keep stale-state presentation honest over time
  - falls back to shared unavailable copy/state when snapshot data is missing/corrupt
- Added a dedicated small widget rendering adapter in `WidgetsExtension/WidgetRenderingComponents.swift`:
  - `WidgetStormRiskSmallView(snapshot:)`
  - single-signal Storm Risk-first layout
  - stale, unavailable, and fresh presentations using shared rendering components from #160
  - preserves meaning with iconography + text, not color alone
- Extended preview fixtures in `WidgetsExtension/WidgetPreviewFixtures.swift` with `stormRiskPlaceholder` for placeholder/gallery previews.
- Updated preview coverage in `WidgetsExtension/WidgetRenderingPreviewGallery.swift` for Storm Risk small states:
  - normal
  - stale
  - unavailable
  - placeholder
  - gallery-style no-alert state
  - tinted + accessibility dynamic type
  - vibrant/clear rendering mode
  - light scheme
- Skill gate notes:
  - `build-ios-apps:swiftui-ui-patterns` applied for small-surface hierarchy, resilience, and preview/state coverage.
  - `swift-concurrency-expert` evaluated as applicable for timeline/provider seam; no new async actor-boundary changes were required beyond keeping provider/store use value-oriented and passive.
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded.
- Explicitly deferred per issue scope:
  - small Severe Risk widget (#162)
  - large Combined widget (#163)
  - Summary tap-routing integration work (#164)
  - any snapshot model/store/builder/ingestion/APNs/WidgetCenter behavior changes beyond minimal compile-compatible read-only consumption

---

## Issue #162 - Implement small Severe Risk widget

### Status
- Completed (2026-05-01)

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

### Handoff notes
- Added a real small Severe Risk widget registration in `WidgetsExtension/SkyAwareWidgetsBundle.swift` alongside the existing Storm Risk widget:
  - widget kind: `SkyAwareWidgetKind.severeRisk`
  - family support: `.systemSmall` only
  - gallery copy:
    - name: `Severe Risk`
    - description: `See current local severe weather risk.`
- Added a passive snapshot-driven timeline provider (`SevereRiskProvider`) that mirrors #161 behavior:
  - reads from App Group snapshot storage via `WidgetSnapshotStore` (#155)
  - consumes shared snapshot model state from #154
  - does not initiate ingestion, location, notification, network, or SwiftData workflows
  - keeps timeline policy passive (`.after(now + 15 minutes)`) so stale-state presentation remains honest over time
  - falls back to the shared unavailable state/copy when snapshot data is missing or corrupt
- Added a dedicated severe small-surface rendering adapter in `WidgetsExtension/WidgetRenderingComponents.swift`:
  - `WidgetSevereRiskSmallView(snapshot:)`
  - `WidgetSevereRiskBadgeCard`
  - mirrors in-app Severe badge semantics at widget size using severe icon + label + concise severe summary + freshness
  - preserves meaning with iconography and text (not color-only)
  - supports fresh, stale, and unavailable states
- Extended preview fixtures in `WidgetsExtension/WidgetPreviewFixtures.swift` with `severeRiskPlaceholder`.
- Expanded preview coverage in `WidgetsExtension/WidgetRenderingPreviewGallery.swift` for Severe Risk small states:
  - normal
  - stale
  - unavailable
  - placeholder
  - gallery-style no-alert state
  - tinted + accessibility dynamic type
  - vibrant/clear rendering mode
  - light scheme
- Skill gate notes:
  - `build-ios-apps:swiftui-ui-patterns` applied for small-surface hierarchy and state-preview resilience.
  - `swift-concurrency-expert` evaluated as applicable for the provider/timeline seam; no new actor-boundary changes were required beyond passive value-oriented snapshot reads.
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded.
- Explicitly deferred per issue scope:
  - large Combined widget implementation (#163)
  - Summary tap-routing integration work (#164)
  - any snapshot model/store/builder/ingestion/APNs/WidgetCenter behavior changes beyond minimal compile-compatible read-only consumption

---

## Issue #163 - Implement large Combined widget

### Status
- Completed (2026-05-01)

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

### Handoff notes
- Added large Combined widget registration in `WidgetsExtension/SkyAwareWidgetsBundle.swift`:
  - widget kind: `SkyAwareWidgetKind.combined`
  - family support: `.systemLarge` only
  - gallery copy:
    - name: `Combined`
    - description: `See local risk and the highest-priority active alert.`
- Added passive snapshot-driven timeline provider (`CombinedProvider`) mirroring the existing small-widget provider behavior:
  - reads from App Group snapshot storage via `WidgetSnapshotStore` (#155)
  - consumes shared derived snapshot state from #154/#156
  - does not initiate ingestion, location, notification, network, or SwiftData workflows
  - keeps timeline policy passive (`.after(now + 15 minutes)`) and normalizes freshness state from timestamp for stale handling
  - falls back to shared unavailable state/copy when snapshot data is missing/corrupt
- Added large-surface Combined rendering adapter in `WidgetsExtension/WidgetRenderingComponents.swift`:
  - `WidgetCombinedLargeView(snapshot:)`
  - `WidgetCombinedLargeCard`
  - shows storm risk and severe risk via shared risk badge components from #160
  - shows exactly one alert row via `selectedAlert` and `WidgetCompactAlertRowView` (no list rendering)
  - shows compact `+N more` using `hiddenAlertCount` when lower-priority active alerts are hidden
  - shows deterministic no-alert, stale, and unavailable states via shared rendering components
  - preserves meaning with iconography + text, not color-only semantics
- Extended fixtures/previews for Combined states:
  - `WidgetsExtension/WidgetPreviewFixtures.swift`: added `combinedPlaceholder`
  - `WidgetsExtension/WidgetRenderingPreviewGallery.swift`: added Combined previews for:
    - normal
    - multiple alerts
    - no alerts
    - stale
    - unavailable
    - placeholder
    - gallery-like state
    - tinted + accessibility dynamic type
    - clear rendering mode
    - light scheme
- Skill gate notes:
  - `build-ios-apps:swiftui-ui-patterns` applied for large-widget hierarchy and legibility/state coverage.
  - `swift-concurrency-expert` evaluated as applicable for provider/timeline seam; implementation remained passive and value-oriented with no new actor-boundary changes.
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded.
- Explicitly deferred per scope:
  - Summary tap routing work (#164)
  - final closeout validation coverage and docs (#165)
  - any snapshot model/store/builder/ingestion/APNs/WidgetCenter behavior changes beyond compile-compatible passive read consumption

---

## Issue #164 - Wire Summary tap routing for widgets

### Status
- Completed (2026-05-01)

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
- Added a minimal shared widget route helper at `Shared/WidgetRouteURL.swift`:
  - canonical v1 route shape: `skyaware://widget/summary`
  - destination parsing is intentionally shallow and accepts only Summary in FB-017.
- Wired widget tap URLs for all three FB-017 widgets in `WidgetsExtension/SkyAwareWidgetsBundle.swift` using WidgetKit-native routing:
  - Storm Risk
  - Severe Risk
  - Combined
  - each now applies `.widgetURL(WidgetRouteURL.url(for: entry.snapshot.destination))`.
- Preserved shallow destination shape from snapshot state:
  - `WidgetSnapshot.destination` remains `WidgetSummaryDestination.summary` in v1.
  - no per-alert, badge-specific, or widget-specific route branching was introduced.
- Added Summary fallback routing handling in `Sources/App/HomeView.swift`:
  - `onOpenURL` parses widget route via `WidgetRouteURL.destination(from:)`.
  - Summary destination maps to `.today` tab selection (Summary surface) for warm foreground and cold launch paths where HomeView is presented.
  - unknown/non-widget routes are ignored.
- Added focused tests in `Tests/UnitTests/WidgetRouteURLTests.swift` covering:
  - URL generation for Summary route
  - URL parsing for Summary destination
  - rejection of non-widget routes
  - HomeView Summary-tab fallback mapping
  - no-op behavior for unknown widget paths
- Skill gate notes:
  - `build-ios-apps:swiftui-ui-patterns` applied (widget tap affordance and SwiftUI URL event wiring).
  - `swift-concurrency-expert` evaluated; no new async actor-boundary behavior was introduced in this issue slice.
- Validation run:
  - `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:SkyAwareTests/WidgetRouteURLTests test` succeeded.
- Explicitly deferred to FB-018 per plan:
  - per-alert deep linking
  - per-widget destination branching
  - badge-specific routing
  - alert-detail validation and fallback logic for stale/missing targets

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
