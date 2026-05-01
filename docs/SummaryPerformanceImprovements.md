# Summary Performance Improvements

## 1. Executive Summary

The rough startup experience is likely caused by a small set of state and identity boundaries rather than by a need for redesign.

`SummaryView` currently swaps between a dedicated `LoadingView` and the full summary hierarchy when `showsEmptyResolving` changes. That matches the brand rule for true empty startup, but the swap is root-level and only animated by the parent `VStack`, so any borderline transition from "no meaningful content" to "first useful content" can feel like a hard replacement instead of the summary resolving into place.

The code already supports cached-first behavior upstream: `HomeView` prefers cached `HomeProjection` data, then falls back to fresh pipeline state after the current context resolves. The best improvement path is therefore not a new architecture. It is to tighten state boundaries, keep the summary structure visible as soon as any useful content exists, stabilize loading-to-content transitions inside existing sections, and avoid broad refresh treatment that blurs or swaps more UI than necessary.

The highest-value implementation should preserve the existing visual identity and content order while making startup feel like this sequence:

1. Empty launch shows the existing atmospheric resolving screen.
2. First useful cached or primed content appears in the normal Summary layout.
3. Fresh data resolves in place through subtle opacity/blur and header status text.
4. Empty/loading/error section states keep stable dimensions and avoid abrupt card swaps.

## 2. Findings

### Visual Continuity

#### Finding: Root-level loading/content swap is the sharpest transition

- Severity: High
- Evidence from code:
  - `SummaryView` branches at the top of `body`: `if showsEmptyResolving { LoadingView(...) } else { SummaryStatus(...) ... }` in `Sources/Features/Summary/SummaryView.swift` lines 201-306.
  - `showsEmptyResolving` becomes false as soon as any meaningful content exists: `snap`, `weather`, risks, `outlook`, or alerts in lines 101-115.
  - The only animation on this structural branch is `.animation(..., value: showsEmptyResolving)` on the outer `VStack` in line 313.
- Why it affects user experience:
  - SwiftUI sees two different root subtrees. The resolving screen and the full summary do not share view identity, so the first content arrival can feel like a screen replacement.
  - The brand guide explicitly says state changes should feel like the app is becoming more accurate, not reloading. This branch risks the opposite at the exact first-impression moment.
- Risk of changing it:
  - Medium. The full-screen resolving screen is a locked design decision for true no-cache startup, so the fix must not remove it. The safe change is to make the exit transition softer and ensure the summary appears only when meaningful content exists.

#### Finding: Local Alerts swaps between different card types

- Severity: Medium
- Evidence from code:
  - `localAlertsPresentationState` drives a `switch` that returns `unavailableCard`, `ActiveAlertSummaryView(isLoading:)`, `ActiveAlertSummaryView(alerts:)`, or `emptySectionCard` in `SummaryView.swift` lines 246-280.
  - `.loading` uses `ActiveAlertSummaryView`, while `.empty` uses a generic `emptySectionCard` unless offline in lines 253-280.
- Why it affects user experience:
  - The Local Alerts section can change not just content, but container structure, actions, padding, and section affordances. That makes the screen feel like cards are being removed and inserted instead of resolving in place.
- Risk of changing it:
  - Medium. Local Alerts has real semantic states. The safe implementation keeps the existing labels and messages, but narrows the branch so the section container remains stable when moving from loading to empty or alerts.

#### Finding: Outlook loading and pending states also use different structures

- Severity: Medium
- Evidence from code:
  - `SummaryView` renders `OutlookSummaryCard(outlook:)`, `OutlookSummaryCard(isLoading: true)`, or `emptySectionCard(title: "Outlook Pending", ...)` in lines 283-303.
  - `OutlookSummaryCard` already has an `isLoading` path and placeholder support in `Sources/Features/Summary/OutlookSummaryCard.swift` lines 17-25 and 87-88.
- Why it affects user experience:
  - The section changes from a real Outlook card to a generic empty card when loading finishes without an outlook. That can create a late layout and hierarchy jump.
- Risk of changing it:
  - Low to Medium. `OutlookSummaryCard` already supports nil outlook and loading. The safe direction is to reuse it for pending state rather than inventing a new presentation.

#### Finding: Status message identity intentionally forces transitions

- Severity: Low
- Evidence from code:
  - `SummaryStatusSecondaryLine` applies `.id(displayedMessage)` to the message text in `SummaryStatus.swift` line 258.
  - Its transition offsets old and new messages vertically when Reduce Motion is off in lines 243-252.
- Why it affects user experience:
  - This is localized and mostly aligned with the motion guide, but frequent task churn can make the header feel busy during startup.
- Risk of changing it:
  - Low. Do not remove the transition. If runtime review shows chatter, tune only the rotation cadence or message changes.

### Perceived Performance

#### Finding: Cached-first behavior exists, but `SummaryView` still treats "any content" as the only threshold

- Severity: High
- Evidence from code:
  - `HomeView` chooses cached projections before pipeline fallback in `Sources/App/HomeView.swift` lines 54-88.
  - `hasMeaningfulSummaryContent` is based on `displayedProjection != nil || usesPipelineSummaryFallback` in lines 132-140.
  - `SummaryView` independently recomputes meaningful content from individual optionals in `SummaryView.swift` lines 101-115.
- Why it affects user experience:
  - Two similar thresholds exist in different layers. If they diverge, the tab bar dimming, bootstrap overlay, and Summary body can disagree about whether the user is in empty startup or cached-forward mode.
  - The UX cost is perceived hesitation: the app may stay in a blocking state longer than necessary or leave it with a hard visual jump.
- Risk of changing it:
  - Medium. The safest improvement is to add tests around the existing thresholds before changing behavior.

#### Finding: Refresh state applies all resolving sections during foreground refresh

- Severity: Medium
- Evidence from code:
  - `beginForegroundRefresh()` starts `.finalizing` with `SummarySection.resolveForwardSections` in `HomeRefreshPipeline.swift` lines 298-303.
  - `finishForegroundRefresh()` resolves all sections together in lines 305-310.
  - Individual `SummaryView` sections blur/opacity when `resolutionState.isResolving(...)` is true in `SummaryView.swift` lines 152, 157, 178, 195, 255, 263, 279, 288, 295, and 302.
- Why it affects user experience:
  - Even if only part of the data is actually stale or changing, all sections can visually degrade. That makes the app feel slower because stable cached content looks unresolved.
- Risk of changing it:
  - Medium to High. This touches refresh semantics, not just UI. It should be a separate slice handled by a stronger model with tests.

#### Finding: Pull-to-refresh can force a waiting refresh path

- Severity: Low to Medium
- Evidence from code:
  - `.refreshable` calls `forceRefreshCurrentContext(showsLoading: true, ...)` in `HomeView.swift` lines 197-202.
  - `forceRefreshCurrentContext` forwards `waitsForCompletion: showsLoading` in `HomeRefreshPipeline.swift` lines 156-159.
  - `submit` runs synchronously when `waitsForCompletion` is true in lines 234-238.
- Why it affects user experience:
  - This is expected for pull-to-refresh completion semantics, but it makes section-level resolving behavior more important. The visible screen should remain useful while the refresh awaits completion.
- Risk of changing it:
  - Low if left alone. Do not change refresh mechanics unless profiling shows main-actor blocking or UI unresponsiveness.

### SwiftUI Rendering Efficiency

#### Finding: `HomeView` repeatedly derives DTO arrays and projections in computed properties

- Severity: Medium
- Evidence from code:
  - `cachedOutlookDTOs` maps `cachedOutlooks.map(\.dto)` every body evaluation in `HomeView.swift` lines 50-52.
  - `displayedProjection` maps all cached projections to records before selecting one in lines 54-58.
  - `summaryContentView` reads many computed properties into local lets in lines 340-358.
- Why it affects user experience:
  - These computations are not huge by themselves, but they sit on the startup render path and are reevaluated as observed state changes. On a cold launch with SwiftData query updates, location state changes, and refresh state changes, the repeated mapping can contribute to visible hesitation.
- Risk of changing it:
  - Medium. Avoid ad hoc `@State` caches. Prefer small helper functions that select from existing query results without extra intermediate arrays, or move precomputation to an existing projection boundary if clearly justified.

#### Finding: Scroll geometry writes state on every geometry change

- Severity: Medium
- Evidence from code:
  - `onScrollGeometryChange` assigns `todayHeaderCondenseProgress = normalizedProgress` unconditionally in `HomeView.swift` lines 190-195.
  - `SummaryStatus` animates multiple layout properties when `condenseProgress` changes in `SummaryStatus.swift` lines 31-88.
- Why it affects user experience:
  - This can create unnecessary invalidations during scroll and immediately after startup if geometry settles. It is not the main cold-start problem, but it can add noise to the first interaction.
- Risk of changing it:
  - Low. Only assign when the value meaningfully changes, such as after quantizing or checking a small epsilon.

#### Finding: Some formatting and derived metric work happens during view recomputation

- Severity: Low
- Evidence from code:
  - `SummaryStatus` uses a static `MeasurementFormatter`, which is good, but formats temperature through a computed property in `SummaryStatus.swift` lines 20-29 and 177-179.
  - `AtmosphereRailView` constructs `metrics` as a fresh array with formatted strings each body pass in `Sources/Features/Badges/AtmosphereRailView.swift` lines 22-108 and renders it in lines 181-189.
  - `ActiveAlertSummaryView` sorts in `init`, not directly in `body`, in `ActiveAlertSummaryView.swift` lines 23-37. That is acceptable for small arrays but still runs whenever the parent recreates the view.
- Why it affects user experience:
  - These are not severe, but they are startup-path work. Keep them in mind if Instruments shows render cost in these views.
- Risk of changing it:
  - Low. Do not prematurely optimize. Only move derived values if there is measured cost or if a local cleanup also improves transition stability.

### State Modeling

#### Finding: Summary state is split between readiness, resolution, cached projection presence, and local meaningful content

- Severity: High
- Evidence from code:
  - `HomeView.readinessState` is derived in `HomeView.swift` lines 121-130.
  - `HomeView.isEmptyResolvingSummary` uses `showsBootstrapLoading` in lines 136-141 and 413-421.
  - `SummaryView.showsEmptyResolving` independently checks meaningful content and refresh/readiness in `SummaryView.swift` lines 101-115.
  - `SummaryView.localAlertsPresentationState` derives a separate alert display state in lines 93-99 and 338-356.
- Why it affects user experience:
  - Multiple derived state machines can temporarily disagree during startup. That is how you get tab-bar dimming, body loading, header status, and section placeholders that do not feel coordinated.
- Risk of changing it:
  - Medium. The smallest safe step is to test current state combinations and then either pass a single explicit "bootstrap resolving" boolean into `SummaryView` or align the helper logic exactly.

#### Finding: Error state is mostly implicit in Summary UI

- Severity: Medium
- Evidence from code:
  - `HomeRefreshPipeline.runRefresh` logs failures but does not expose an error state to `SummaryView` in `HomeRefreshPipeline.swift` lines 271-277.
  - `SummaryView` has loading, empty, unavailable, offline, and pending presentations, but no explicit refresh-error presentation in `SummaryView.swift` lines 201-306.
- Why it affects user experience:
  - A failed refresh with cached content should continue showing cached content, which is good. But if no cached content exists and refresh fails, the visual state may fall through to generic pending/empty states that can look like successful absence rather than unresolved data.
- Risk of changing it:
  - Medium. Do not add new error UI in the first slice. First document and test the current behavior; then consider a small header-only status if existing model state already exposes it elsewhere.

### Async/Concurrency Behavior

#### Finding: UI-facing refresh model is correctly main-actor isolated

- Severity: Low
- Evidence from code:
  - `HomeRefreshPipeline` is `@MainActor @Observable` in `HomeRefreshPipeline.swift` lines 50-52.
  - `HomeLocationContextPreparing` is `@MainActor` in lines 17-29.
  - Fire-and-forget refresh tasks capture `[weak self]` and return to `@MainActor` in lines 240-244, 323-325, and 366-380.
- Why it affects user experience:
  - This is good for SwiftUI state correctness. It means implementation should not move UI state mutation off-main or introduce detached tasks casually.
- Risk of changing it:
  - High if handled carelessly. Keep UI state updates on the main actor.

#### Finding: Refresh orchestration awaits coordinator work from a main-actor model

- Severity: Medium
- Evidence from code:
  - `runRefresh` awaits `environment.coordinator.enqueueAndWait(...)` from `HomeRefreshPipeline` in `HomeRefreshPipeline.swift` lines 247-263.
  - It then applies the snapshot on the main actor in lines 383-406.
- Why it affects user experience:
  - Awaiting itself does not block the main thread, assuming the coordinator does real work off-main. The important risk is not the await; it is any synchronous work done before/after the await on the main actor.
- Risk of changing it:
  - Medium. Do not change this without profiling or coordinator evidence. Validate that expensive parsing/network work stays outside the main actor.

#### Finding: `SummaryStatusSecondaryLine` uses a cancellable `.task(id:)` correctly, but its state key includes a time-sensitive `Date`

- Severity: Low
- Evidence from code:
  - `.task(id: taskState)` runs `updateDisplayedMessage()` in `SummaryStatus.swift` lines 275-286.
  - `taskState` includes `recentCompletedDeadline: Date?` in lines 280-286 and 338-342.
- Why it affects user experience:
  - The task is structured safely and cancellation-aware. The only concern is churn: if `recentCompletedDeadline` changes frequently, the message task restarts.
- Risk of changing it:
  - Low. Leave it unless logs or `_logChanges()` show message-task churn during startup.

### Brand/Design Alignment

#### Finding: The existing direction matches the brand, but execution is too binary in a few places

- Severity: High
- Evidence from code and docs:
  - The North Star spec says to show a dedicated full-screen resolving state only when no meaningful cached content exists and to resolve cached content in place.
  - `LoadingView` already implements the preferred title, ambient glow, and ghosted summary structure in `LoadingView.swift` lines 21-147.
  - `SummaryView` already uses section-level resolving modifiers in `SummaryView.swift` lines 152-157, 178-195, 255-302.
- Why it affects user experience:
  - The pieces are right, but the state transitions are not yet consistently local. The product can still feel like it is reloading rather than sharpening.
- Risk of changing it:
  - Low to Medium. Keep the same components and tune how they are composed.

#### Finding: Loading copy is mostly aligned; one placeholder still uses "Loading"

- Severity: Low
- Evidence from code:
  - `SummaryReadinessState` uses aligned copy in `SummaryView.swift` lines 17-30.
  - `AtmosphereRailView.atmosphereSummary` returns "Loading atmospheric metrics..." when weather is nil in `AtmosphereRailView.swift` lines 22-25.
- Why it affects user experience:
  - The brand guide discourages generic loading language. This line may be hidden by placeholder treatment, but if exposed to VoiceOver or during a render edge case, it breaks the intended voice.
- Risk of changing it:
  - Low. Replace only if visible or accessibility-exposed in the target flow; otherwise avoid churn.

## 3. Recommended Plan

### Slice 1: Lock Current State Behavior With Focused Tests

- Goal: Preserve intended cached-first behavior before touching UI composition.
- Files likely touched:
  - `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
  - `Sources/Features/Summary/SummaryView.swift`
  - `Sources/App/HomeView.swift`
- Specific implementation steps:
  - Add or extend tests for `HomeView.showsBootstrapLoading(readinessState:resolutionState:hasProjection:)`.
  - Add tests for `SummaryView.localAlertsPresentationState(readinessState:hasActiveAlerts:isLocationUnavailable:)`.
  - Add a small testable helper if needed for `SummaryView`'s empty resolving decision. Keep it static and pure.
  - Cover these cases: no cache plus active refresh, no cache plus ready, cache plus active refresh, location unavailable, active alerts while loading, empty alerts after local data load.
- Acceptance criteria:
  - Tests describe when full-screen resolving is allowed.
  - No production behavior changes.
  - Existing tests still pass.
- Risk level: Low
- Suggested model for implementation: Smaller/cheaper model
- Suggested intelligence level: Medium

### Slice 2: Soften Empty-Resolving Exit Without Redesign

- Goal: Make the transition from `LoadingView` to normal Summary content feel like a resolve-forward continuation.
- Files likely touched:
  - `Sources/Features/Summary/SummaryView.swift`
  - Possibly `Sources/Features/Loading/LoadingView.swift`
- Specific implementation steps:
  - Keep `LoadingView` for true empty startup.
  - Add an explicit transition to the full Summary content branch that uses opacity and a very small blur-to-sharp effect, respecting Reduce Motion.
  - Avoid movement-heavy transitions and avoid changing spacing, content order, colors, labels, or component structure.
  - Consider extracting the non-loading branch into a private `summaryContent` builder inside `SummaryView` only if it reduces branch noise without changing layout.
- Acceptance criteria:
  - Empty startup still shows `LoadingView`.
  - Cached or first resolved content appears as the existing Summary screen, not a redesigned screen.
  - Reduce Motion uses opacity-only behavior.
  - No section order or text changes except transition mechanics.
- Risk level: Medium
- Suggested model for implementation: Smaller/cheaper model
- Suggested intelligence level: Medium

### Slice 3: Stabilize Local Alerts and Outlook Section Containers

- Goal: Reduce abrupt section swaps by keeping existing section containers stable across loading, empty, cached, and resolved states.
- Files likely touched:
  - `Sources/Features/Summary/SummaryView.swift`
  - `Sources/Features/Summary/ActiveAlertSummaryView.swift`
  - `Sources/Features/Summary/OutlookSummaryCard.swift`
- Specific implementation steps:
  - For Local Alerts, prefer `ActiveAlertSummaryView` for loading, alerts, offline, and empty-with-no-alerts where it can preserve the same header/container. If an empty message is still required, add it inside the existing alert card rather than swapping to `emptySectionCard`.
  - Keep `unavailableCard` for location unavailable unless a stable unavailable variant already exists in `ActiveAlertSummaryView`.
  - For Outlook, prefer `OutlookSummaryCard(outlook: nil, isLoading: false, ...)` for pending if its existing nil summary and disabled button match current copy. If copy must remain "Outlook Pending", add a narrow pending initializer/property rather than using a generic card.
  - Add transitions only inside the section content, not around the whole Summary screen.
- Acceptance criteria:
  - Local Alerts no longer changes between generic card and alert card solely because loading resolved to empty.
  - Outlook no longer changes between outlook card and generic empty card solely because loading resolved to pending.
  - Existing labels, order, actions, and visual style remain essentially unchanged.
- Risk level: Medium
- Suggested model for implementation: Smaller/cheaper model for view cleanup; stronger model if adding state cases
- Suggested intelligence level: Medium

### Slice 4: Narrow Unnecessary Render Invalidations

- Goal: Reduce avoidable Summary redraws during startup and first scroll without changing product behavior.
- Files likely touched:
  - `Sources/App/HomeView.swift`
  - Possibly `Sources/Features/Summary/SummaryStatus.swift`
- Specific implementation steps:
  - In `onScrollGeometryChange`, only assign `todayHeaderCondenseProgress` when the new value differs meaningfully from the current value.
  - Review `displayedProjection` and `cachedOutlookDTOs` for avoidable intermediate arrays. Prefer selecting from query results before mapping to DTO/record where possible.
  - Do not add generic caching state. Keep helper logic pure and deterministic.
  - Optionally add temporary `_logChanges()` during local investigation only; do not commit debug logging.
- Acceptance criteria:
  - Scrolling still condenses the header identically to users.
  - No new state source is introduced.
  - Startup Summary inputs remain the same values for the same cached/query/pipeline state.
- Risk level: Low to Medium
- Suggested model for implementation: Smaller/cheaper model
- Suggested intelligence level: Medium

### Slice 5: Audit Refresh Section Resolution Granularity

- Goal: Ensure refresh visual treatment matches sections that are actually resolving.
- Files likely touched:
  - `Sources/App/HomeRefreshPipeline.swift`
  - `Sources/Features/Summary/SummaryResolving.swift`
  - `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- Specific implementation steps:
  - Inspect what `foregroundPrime` and follow-up refresh actually update.
  - Determine whether `.finalizing` should mark every `SummarySection.resolveForwardSections`, or whether existing provider tasks can map to narrower sections.
  - If narrowing is justified by current pipeline data, update `resolutionState.begin/finish` calls with precise sections.
  - Add tests for `SummaryResolutionState` task/section behavior before changing it.
- Acceptance criteria:
  - Stable cached sections are not visually blurred unless their backing provider is actively resolving.
  - Active messages still correspond to actual work.
  - Refresh completion clears all resolving sections reliably.
- Risk level: Medium to High
- Suggested model for implementation: Stronger model
- Suggested intelligence level: High

### Slice 6: Final UX and Concurrency Review

- Goal: Verify that implementation improved perceived performance without violating Swift 6 correctness or SkyAware design rules.
- Files likely touched:
  - Review only unless defects are found
- Specific implementation steps:
  - Run focused unit tests.
  - Build the app for the preferred simulator.
  - Exercise cold no-cache startup, cached startup, foreground refresh, pull-to-refresh, offline cached mode, and location unavailable.
  - Inspect any `.xcresult` if tests fail.
  - Use Instruments only if visible jank remains after code-level fixes.
- Acceptance criteria:
  - Summary looks essentially the same.
  - Startup and refresh transitions feel smoother.
  - No main-actor or Sendable diagnostics are introduced.
  - No new dependencies, architecture, or broad refactors.
- Risk level: Low for review, variable for follow-up fixes
- Suggested model for implementation: Strongest available model
- Suggested intelligence level: High

## 4. Implementation Tasks for a Smaller Model

### Task 1: Add Focused State Tests Before UI Changes

Inspect these files:

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/App/HomeView.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`

Goal:

- Add tests that lock down when Summary may show full-screen empty resolving and how Local Alerts chooses loading, unavailable, alerts, and empty states.

Guardrails:

- Do not change production behavior unless a pure helper is needed for testability.
- Do not add UI snapshots.
- Do not introduce new dependencies.
- Keep helpers static, pure, and local to the existing types.

Validation:

- Run `swift test` if available for these unit tests, or the smallest relevant Xcode test command for `HomeViewLoadingOverlayStateTests`.
- Report any tests that cannot run and why.

### Task 2: Add a Gentle Transition Around Summary Empty-Resolving Exit

Inspect these files:

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Loading/LoadingView.swift`
- `Sources/Features/Summary/SummaryResolving.swift`

Goal:

- Make the existing transition from `LoadingView` to normal Summary content less abrupt.

Guardrails:

- Do not remove `LoadingView`.
- Do not change Summary content order, labels, colors, card radii, typography, or data flow.
- Respect `accessibilityReduceMotion`.
- Use opacity and, only when Reduce Motion is false, a subtle blur-to-sharp transition. No slide, bounce, scale, or spring-heavy motion.
- Keep the change inside `SummaryView` unless a tiny reusable transition helper in `SummaryResolving.swift` is cleaner.

Validation:

- Build the app.
- Manually verify no-cache startup still shows the existing resolving screen.
- Manually verify first content appears as the same Summary layout.
- Verify Reduce Motion does not use blur/motion-heavy transition.

### Task 3: Keep Local Alerts Container Stable Between Loading and Empty

Inspect these files:

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`

Goal:

- Avoid swapping from `ActiveAlertSummaryView(isLoading: true)` to a generic `emptySectionCard` when local alerts resolve empty.

Guardrails:

- Do not redesign Local Alerts.
- Keep the `Local Alerts` label.
- Keep the existing empty message meaning.
- Do not change alert row layout or sheet behavior.
- Do not change unavailable-location behavior unless the existing alert card can represent it with no visual redesign.

Validation:

- Build the app.
- Verify loading alerts, no active alerts, active alerts, offline alerts, and location unavailable.
- Verify VoiceOver still has sensible labels for empty and loading states.

### Task 4: Keep Outlook Container Stable Between Loading and Pending

Inspect these files:

- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/OutlookSummaryCard.swift`

Goal:

- Avoid swapping from `OutlookSummaryCard(isLoading: true)` to a generic `emptySectionCard` when no outlook is available after loading.

Guardrails:

- Do not change the Outlook section position.
- Do not change navigation destination behavior when an outlook exists.
- Do not add new summary copy unless required to preserve the current "Outlook Pending" semantics.
- Do not introduce a new card style.

Validation:

- Build the app.
- Verify outlook present, outlook loading, and outlook pending states.
- Verify the disabled "Read full outlook" path cannot navigate when `outlook == nil`.

### Task 5: Reduce Scroll Condense State Churn

Inspect these files:

- `Sources/App/HomeView.swift`
- `Sources/Features/Summary/SummaryStatus.swift`

Goal:

- Prevent unnecessary `todayHeaderCondenseProgress` writes during scroll geometry updates.

Guardrails:

- Do not change the visual condense range or thresholds.
- Do not remove `onScrollGeometryChange`.
- Do not introduce timers or async work.
- Use a small equality/epsilon guard before assigning state.

Validation:

- Build the app.
- Scroll the Summary screen and verify the Current Conditions header condenses the same way.
- Verify no visible snapping is introduced.

### Task 6: Review Refresh Resolution Granularity

Inspect these files:

- `Sources/App/HomeRefreshPipeline.swift`
- `Sources/Features/Summary/SummaryResolving.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`

Goal:

- Determine whether foreground refresh should mark all Summary sections as resolving or only sections tied to active provider work.

Guardrails:

- Do not change refresh behavior unless the existing request flow clearly supports narrower section tracking.
- Keep `HomeRefreshPipeline` main-actor isolated.
- Do not use `Task.detached`.
- Do not mutate SwiftUI-visible state off the main actor.
- Add or update tests for every changed resolution-state transition.

Validation:

- Run focused unit tests for `SummaryResolutionState`.
- Build the app.
- Manually verify cached content remains visible during foreground refresh.
- Verify resolving blur clears after success and failure.

## 5. Validation Checklist

### Build Checks

- Run `xcodebuild -project SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`.
- Run focused unit tests for `HomeViewLoadingOverlayStateTests`.
- If an `.xcresult` is produced on failure, inspect it before declaring the result.
- Confirm there are no new Swift concurrency warnings or Sendable diagnostics.

### Runtime Checks

- Launch the app with no useful cached projection and confirm the existing full-screen resolving presentation appears.
- Launch with cached `HomeProjection` data and confirm the Summary screen appears immediately.
- Confirm tab bar dimming only appears during true empty resolving.
- Confirm the Summary screen content order remains:
  1. Current Conditions
  2. Risk Snapshot
  3. Location reliability rail when eligible
  4. Local Alerts
  5. Outlook Summary
  6. Attribution

### Startup Behavior Checks

- Verify first content arrival crossfades/resolves softly rather than popping.
- Verify `Current Conditions` status text updates without layout collapse.
- Verify no section briefly shows a misleading successful empty state before data resolution finishes.
- Verify startup does not perform visible spinner-first behavior.

### Cached-Content Behavior Checks

- With cached content and active refresh, confirm cached risk, weather, alerts, and outlook remain visible.
- Confirm resolving treatment is subtle: blur no more than the existing `SkyAwareMotion.resolvingBlur` and opacity no lower than the existing resolving modifier.
- Confirm offline cached mode shows the offline token and cached content rather than blocking startup.

### Refresh Behavior Checks

- Pull to refresh on the Summary screen.
- Background and foreground the app to trigger foreground refresh.
- Change location context if practical.
- Confirm refresh status appears in the header area, not as a floating overlay.
- Confirm sections clear resolving treatment after refresh success and after refresh failure.

### Accessibility/Dynamic Type Checks

- Enable Reduce Motion and verify transitions become opacity-only or otherwise motion-reduced.
- Test at large Dynamic Type sizes and confirm loading, empty, and resolved cards do not overlap.
- Verify placeholder/ghost views are accessibility-hidden where decorative.
- Verify disabled actions, such as missing outlook navigation, are announced as unavailable or dimmed.
- Verify icon-only or icon-supported controls retain accessible labels/hints.

### Dark Mode / Light Mode Checks

- Verify no-cache resolving screen in dark and light mode.
- Verify cached resolving blur/opacity in dark and light mode.
- Verify Local Alerts empty/loading/alerts states in dark and light mode.
- Verify Outlook present/loading/pending states in dark and light mode.
- Confirm semantic risk colors are unchanged.

## 6. Do Not Change

- Do not redesign the Summary screen.
- Do not change the Summary information hierarchy or canonical content order.
- Do not change SkyAware color semantics, risk colors, typography scale, corner radius system, or card style.
- Do not replace the existing full-screen resolving concept for true no-cache startup.
- Do not add spinners, flashy shimmer, bounce, strong spring motion, or movement-heavy transitions.
- Do not add new dependencies.
- Do not introduce a new architecture or new orchestration layer.
- Do not move provider, parsing, persistence, or refresh orchestration into `SummaryView`.
- Do not mutate SwiftUI-visible state off the main actor.
- Do not introduce `Task.detached` for UI state.
- Do not broaden location, notification, or background refresh behavior.
- Do not change navigation flow to Map, Alerts, Outlooks, Settings, or detail sheets.
- Do not change user-facing labels unless a targeted copy fix is explicitly part of a slice.
- Do not remove offline behavior or cached-content fallback behavior.
- Do not commit temporary `_logChanges()` or debug instrumentation.
