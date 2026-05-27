# Resolve-Forward UI Polish Issue Drafts

GitHub CLI was available locally, but the active token was invalid, so these are draft issues ready to paste into GitHub.

Suggested labels, where available: `design`, `ui-polish`, `summary`, `tech-debt`, `codex-ready`.

## Issue 1

Title: `[UI Polish] Standardize Summary resolving header language`

## Recommended model
Codex 5.3

## Recommended reasoning
Medium

## Problem
The Summary header currently carries multiple responsibilities at once: location, readiness, active resolving messages, recent completion messages, offline state, and settled condition text. `SummaryStatusSecondaryLine` can rotate between active messages every few seconds, then briefly repeat the last task message after completion. During refresh, the settled condition line is hidden, which can make the header feel like it is reloading instead of becoming more accurate.

## Why now
The resolve-forward model is correct, but the header should feel like one calm global status surface. A more stable hierarchy would improve trust, reduce visual churn, and avoid the sense that unrelated sections are competing to narrate themselves.

## Scope
Likely files/components:
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/SummaryResolving.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`

## Non-goals
- Do not change data flow.
- Do not change provider behavior.
- Do not change refresh timing.
- Do not change business logic.
- Do not redesign the whole Summary screen.
- Do not add new status sources or new network dependencies.

## Proposed approach
Audit the current header text hierarchy and make the active resolving line behave as one calm global message. Prefer a single visible resolving message at a time, with less message rotation and no developer/system phrasing. Keep the location as the primary settled identity. Use existing `SummaryResolutionState` and existing readiness state only.

Recommended copy direction:
- `Getting your conditions ready`
- `Updating your conditions`
- `Getting storm risk`
- `Bringing in local alerts`

Avoid adding provider names, feed names, or generic `Loading`/`Fetching` language.

## Acceptance criteria
- The Summary header shows one calm resolving/status line, not several competing status concepts.
- Active resolving text does not rotate so frequently that it reads as jitter.
- Recent-completion behavior does not make the same section appear to start loading again.
- Settled condition text returns cleanly after resolving completes.
- Location unavailable and offline states remain clearly distinct.
- Existing readiness and resolving semantics remain unchanged.

## Validation
- Build `SkyAware` for an iOS Simulator target.
- Inspect Summary previews that exercise ready, loading, offline, and location-unavailable states.
- Run focused unit tests for Summary readiness/loading helpers if touched.
- Manually inspect the Today tab during cold start, cached start, manual refresh, and foreground refresh.
- Inspect light mode, dark mode, Reduce Motion, and larger Dynamic Type.

## Risks / edge cases
- Over-suppressing status can hide useful activity.
- Over-animation can make the header feel nervous.
- Long location names plus status text can truncate poorly.
- Offline and stale-ish copy can imply data is fresh when only cached content is visible.

## Issue 2

Title: `[UI Polish] Add consistent Summary resolve-forward transition primitives`

## Recommended model
Codex 5.3

## Recommended reasoning
Medium

## Problem
Summary sections currently use a mix of redacted placeholders, full-card opacity, blur, inline explicit loading states, and pending text. Risk, fire, and atmosphere sections use placeholder redaction plus `summaryResolving`; Local Alerts uses explicit content states and an opacity transition; Outlook uses card-level placeholder and pending copy. The result is visually coherent enough to function, but not coherent enough to feel intentionally designed.

## Why now
A shared visual treatment would make resolve-forward updates feel like the app is refining the local picture instead of several components independently reloading.

## Scope
Likely files/components:
- `Sources/Features/Summary/SummaryResolving.swift`
- `Sources/Utilities/Core/SkyAwareMotion.swift`
- `Sources/Utilities/Extensions/ext+View.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`
- `Sources/Features/Badges/FireWeatherRailView.swift`
- `Sources/Features/Badges/AtmosphereRailView.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Summary/OutlookSummaryCard.swift`

## Non-goals
- Do not change data flow.
- Do not change provider behavior.
- Do not change refresh timing.
- Do not change business logic.
- Do not redesign the whole Summary screen.
- Do not replace the cached-first model with a blocking loading state.

## Proposed approach
Create or refine a small shared resolve-forward visual vocabulary for Summary sections. Prefer stable containers with inner-content crossfade, subtle opacity lift, and optional blur-to-clear where it adds clarity. Avoid whole-card dimming when a child already has a clear resolving state. Keep Reduce Motion support explicit.

The implementation should be conservative: centralize constants and modifiers only where it removes real inconsistency. Do not introduce a large UI framework.

## Acceptance criteria
- Summary sections use a consistent resolving language: stable container, calm inner transition, and no spinner-first behavior.
- Resolve-forward transitions respect Reduce Motion.
- Placeholder/resolving visuals reserve enough space to prevent obvious layout jumps.
- Existing section order and interactions remain unchanged.
- No section appears disabled unless it is intentionally unavailable.
- The visual style works in light and dark mode.

## Validation
- Build `SkyAware` for an iOS Simulator target.
- Inspect Summary previews for loaded, partially loaded, offline, and Dynamic Type states.
- Manually record or observe cached launch and manual refresh on the Today tab.
- Verify no new animation jank when multiple sections resolve together.
- Inspect iPhone 17 or iPhone 17 Pro simulator if available.

## Risks / edge cases
- A shared modifier can accidentally flatten important section-specific semantics.
- Too much blur can read as disabled or stale.
- Crossfades can hide real alert appearance if overused.
- Fixed placeholder heights can break at accessibility text sizes.

## Issue 3

Title: `[UI Polish] Polish risk badge resolve-forward transitions`

## Recommended model
Codex 5.3

## Recommended reasoning
Medium

## Problem
Storm Risk and Severe Risk are the primary severe-weather signals, but their resolving states are currently represented by rendering a fallback value and applying placeholder/redaction and section resolving effects from the parent. Icon, label, summary, color, and opacity can all change at once when data resolves. That can make the most important area feel jumpy instead of confidently updating.

## Why now
Risk badges define the first impression of the Summary screen. Their updates should feel deliberate, stable, and trustworthy.

## Scope
Likely files/components:
- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`
- `Sources/Utilities/Extensions/ext+View.swift`
- `Sources/Utilities/Core/SkyAwareMotion.swift`
- Existing badge previews in the same files

## Non-goals
- Do not change risk scoring.
- Do not change map layer selection.
- Do not change provider behavior.
- Do not change refresh timing.
- Do not redesign the whole Summary screen.
- Do not add new risk categories or alter color semantics.

## Proposed approach
Keep the existing badge layout and semantic color system, but make placeholder, resolving, stale/offline-adjacent, and resolved states visually aligned. Consider moving the resolving representation closer to the badge content instead of relying only on parent-level redaction and blur. Use subtle crossfades or content transitions for label/icon/value changes. Keep badge dimensions stable.

Use the recent widget direction as inspiration for semantic glow and full-surface polish, but do not copy widget layouts into the app.

## Acceptance criteria
- Storm Risk and Severe Risk maintain stable dimensions while resolving.
- Icon, label, summary, and color changes feel intentional and calm.
- Placeholder/resolving states do not look like false `All Clear` risk.
- Offline styling remains distinct from resolving.
- The two badges transition consistently with each other.
- Risk colors remain semantic and are not reused as generic decoration.

## Validation
- Build `SkyAware` for an iOS Simulator target.
- Inspect badge previews across storm and severe risk levels.
- Manually inspect Today during cached launch and manual refresh.
- Check light mode, dark mode, Reduce Motion, and accessibility Dynamic Type where badges stack.
- Capture before/after screenshots for the Summary hero area.

## Risks / edge cases
- A placeholder that resembles `All Clear` can create false calm.
- Strong glow or animation can make severe-weather UI feel theatrical.
- Text can truncate when risk summaries include probabilities.
- Stacked Dynamic Type layout may expose height mismatches.

## Issue 4

Title: `[UI Polish] Stabilize Local Alerts resolving and empty states`

## Recommended model
Codex 5.3

## Recommended reasoning
Medium

## Problem
Local Alerts has the right conceptual states, but it remains one of the most sensitive resolve-forward surfaces. It needs to clearly distinguish checking latest alerts, no active alerts, active alerts, unavailable location, and offline. The current implementation already uses an internal content state and crossfade, but the visual language still risks reading as either false calm or a partially loaded card during startup and refresh.

## Why now
Alerts are high-trust content. The UI must avoid both noisy alert drama and premature reassurance while alerts are unresolved.

## Scope
Likely files/components:
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Features/Summary/SummaryResolving.swift`
- `Tests/UnitTests/HomeViewLoadingOverlayStateTests.swift`
- `docs/LifecycleInvestigationNotes.md` as prior audit context

## Non-goals
- Do not change alert ingestion.
- Do not split Arcus/SPC/NWS refresh orchestration.
- Do not change alert sorting or filtering.
- Do not change refresh timing.
- Do not change notification behavior.
- Do not redesign the full Alerts tab.

## Proposed approach
Refine only the visual representation of the existing Local Alerts states. Keep the card container stable and transition inner content only. Ensure the checking state does not look like a final no-alert state, and the no-alert state does not appear until existing state says it should. Review the current label/copy for polish, including obvious user-facing typos, but keep wording calm and concise.

Do not change whether cached alerts appear offline unless product explicitly approves that behavior separately.

## Acceptance criteria
- Checking/updating alerts is visually distinct from `No Active Alerts`.
- Active alert rows enter without resizing or jolting the card more than necessary.
- No-alert state does not imply alerts are fresh while alert resolving is active.
- Offline and location-unavailable states remain visually distinct.
- Alert Center affordance appears only where it makes visual and semantic sense.
- VoiceOver reads loading, empty, offline, and populated states cleanly.

## Validation
- Build `SkyAware` for an iOS Simulator target.
- Manually inspect Today with no alerts, watches only, mesos only, both watches and mesos, offline, and location unavailable.
- Run focused Summary loading/local alert state tests if any helpers change.
- Inspect Reduce Motion and large Dynamic Type.
- Capture screenshots of checking, no-alert, active-alert, and offline states.

## Risks / edge cases
- False calm if `No Active Alerts` appears while checks are still resolving.
- Overly dramatic styling can make normal watch/meso states feel like warnings.
- Inner transitions can still cause height jumps if rows are not reserved carefully.
- Offline messaging can hide useful cached alert context, but changing that is a behavior decision and out of scope.

## Issue 5

Title: `[UI Polish] Smooth Current Conditions resolve-forward updates`

## Recommended model
Codex 5.3

## Recommended reasoning
Medium

## Problem
Current Conditions combines location, temperature, condition icon, condition text, offline token, and resolving status. Temperature and icon changes use opacity transitions, while the settled condition line disappears during active refresh. Location and status text can swap based on readiness and placemark availability. The area can feel more like a status console than a stable weather-aware header.

## Why now
Current Conditions is the user's anchor for the Summary screen. It should show cached/local context immediately and then refine in place without looking like the entire header is being rebuilt.

## Scope
Likely files/components:
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/SummaryView.swift`
- `Sources/Models/SummaryWeather.swift`
- Existing Summary previews

## Non-goals
- Do not change WeatherKit fetching.
- Do not change location resolution.
- Do not change refresh timing.
- Do not add new provider calls.
- Do not redesign the whole Summary screen.

## Proposed approach
Keep the existing data inputs and layout, but refine the visual state transitions for temperature, icon, condition text, and location/status copy. Prefer layout-stable placeholders and subtle content transitions. If freshness/as-of language is shown, use existing timestamps only and keep it neutral, such as `As of 3:42 PM`, rather than broad `Updated` language that implies every section refreshed.

## Acceptance criteria
- Temperature, condition icon, and condition text update without visible layout jump.
- The header remains anchored on location when cached content exists.
- Resolving status does not cause the condition line to flicker or collapse.
- Offline token remains compact and clear.
- Long placemark names and large Dynamic Type do not overlap the weather value.

## Validation
- Build `SkyAware` for an iOS Simulator target.
- Inspect Summary previews for ready, loading, offline, and location unavailable.
- Manually inspect Today during cached launch, cold start, and manual refresh.
- Check light mode, dark mode, Reduce Motion, and accessibility Dynamic Type.

## Risks / edge cases
- `Updated` copy can imply all sections are fresh when only conditions changed.
- Too much persistent freshness text can add clutter.
- Location names can crowd temperature on compact widths.
- Hiding condition text during refresh can read as missing data.

## Issue 6

Title: `[UI Polish] Normalize secondary Summary resolving states`

## Recommended model
Codex 5.3

## Recommended reasoning
Medium

## Problem
Secondary sections such as Fire Risk, Atmospheric Conditions, and Outlook Summary are visually quieter than the hero area, which is correct, but their resolving and pending language is inconsistent. Atmospheric Conditions currently has generic loading phrasing, Outlook uses sync-oriented pending language, and section-level placeholders differ from Local Alerts and risk badges.

## Why now
Secondary sections should support the severe-weather picture without competing with it. Consistent quiet resolving states would reduce noise and make the Summary screen feel more coherent.

## Scope
Likely files/components:
- `Sources/Features/Badges/FireWeatherRailView.swift`
- `Sources/Features/Badges/AtmosphereRailView.swift`
- `Sources/Features/Summary/OutlookSummaryCard.swift`
- `Sources/Features/Summary/SummaryView.swift`
- Relevant previews in those files

## Non-goals
- Do not change fire risk logic.
- Do not change WeatherKit fetching.
- Do not change outlook sync behavior.
- Do not change refresh timing.
- Do not redesign the full Outlooks tab.
- Do not introduce new data dependencies.

## Proposed approach
Align secondary resolving states with the shared Summary transition style from the earlier primitive work. Replace generic or system-ish visual language with calm user-facing states in the issue implementation. Keep secondary sections visually subordinate to the risk badges and Local Alerts. Use stable rail/card heights where practical without breaking Dynamic Type.

## Acceptance criteria
- Fire, atmosphere, and outlook sections use a consistent calm resolving treatment.
- Atmospheric loading state avoids generic `Loading` phrasing in user-facing text.
- Outlook pending/resolving language does not expose sync mechanics.
- Secondary sections do not compete visually with Storm Risk, Severe Risk, or active Local Alerts.
- Placeholders reserve reasonable space and avoid abrupt height changes.

## Validation
- Build `SkyAware` for an iOS Simulator target.
- Inspect Fire, Atmosphere, and Outlook previews.
- Manually inspect Today with missing weather, missing outlook, offline, and fully resolved content.
- Check light mode, dark mode, Reduce Motion, and large Dynamic Type.

## Risks / edge cases
- Quiet states can become too subtle and look broken.
- Fixed heights can truncate explanatory text.
- Outlook copy can accidentally imply no outlook exists when it simply has not resolved locally.
- Fire risk colors must remain semantically distinct from storm/severe risk colors.

## Issue 7

Title: `[UI Polish] Align cold-start resolving screen with SkyAware visual direction`

## Recommended model
Codex 5.3

## Recommended reasoning
Medium

## Problem
The cold-start `LoadingView` is already limited to no meaningful cached content, which matches the resolve-forward model. Visually, it uses a ghost Summary stack, accent glows, and a weather icon. It should be reviewed against the newer polished blue/dark SkyAware direction so the no-cache startup state feels like the same product as the Summary and recent widget work.

## Why now
The full-screen resolving state is the first impression when the app has no useful cache. It should feel calm, severe-weather-aware, and consistent without encouraging a return to blocking loading for cached starts.

## Scope
Likely files/components:
- `Sources/Features/Loading/LoadingView.swift`
- `Sources/Utilities/Core/SkyAwareMotion.swift`
- `docs/SkyAware Branding and Design Guide.md`
- `docs/SkyAware North Star Spec.md`
- Widget rendering files only as visual inspiration:
  - `WidgetsExtension/WidgetRenderingComponents.swift`
  - `WidgetsExtension/WidgetRenderingStyle.swift`

## Non-goals
- Do not change when `LoadingView` appears.
- Do not add a blocking splash for cached content.
- Do not change refresh orchestration.
- Do not change loading timing.
- Do not redesign the Summary screen.
- Do not copy widget layouts directly into the app.

## Proposed approach
Keep the existing no-cache-only behavior. Refine the visual treatment toward a full-surface atmospheric blue base, subtle semantic glow, typography-led hierarchy, and calm motion. Keep the ghost Summary hint if it helps continuity, but ensure it does not look like real partially loaded content. Preserve Reduce Motion support.

## Acceptance criteria
- Cold-start resolving feels visually aligned with the current SkyAware design direction.
- The screen still clearly communicates that SkyAware is getting local conditions ready.
- Motion remains calm and respects Reduce Motion.
- The ghost content reads as atmospheric context, not fake data.
- Cached launch still bypasses this full-screen resolving state when meaningful content exists.

## Validation
- Build `SkyAware` for an iOS Simulator target.
- Inspect `LoadingView` preview in light and dark mode.
- Manually test a true no-cache startup if practical.
- Verify cached startup still shows Summary content immediately.
- Capture screenshots for light/dark and Reduce Motion review.

## Risks / edge cases
- Making the screen too beautiful can incentivize overuse; behavior must remain unchanged.
- Ghost placeholders can be mistaken for real content.
- Strong glow can feel flashy rather than trustworthy.
- Cold-start copy must avoid generic loading or provider language.
