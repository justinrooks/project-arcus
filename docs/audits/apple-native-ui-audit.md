# Apple-Native UI Audit

Date: 2026-06-10

Scope: audit and planning only. No implementation changes are included.

## Executive Summary

**Apple-native maturity: 7/10**

SkyAware already has a strong foundation: the iOS 18 `Tab` API, independent `NavigationStack` ownership, native
refresh behavior, semantic SF Symbols, Dynamic Type adaptations on major screens, centralized Reduce Motion-aware
animation, continuous corners, and a clear severe-weather identity. The Summary content order also matches the
product's core question well.

The largest friction points are not a lack of Apple styling. They are places where custom presentation weakens
platform behavior or user trust:

- Map failures can appear as "no risk," and the warning legend can imply warning types that are not active.
- Warning priority is not guaranteed in Local Alerts or the Alerts tab.
- Several accessibility paths remove information or functionality.
- Settings, Outlooks, and onboarding expose implementation language and use more custom chrome than those utility
  surfaces need.
- Broad use of glass, shadows, chips, and semantic hazard colors risks making the surface system noisier and less
  meaningful over time.

The largest brand-preservation risks are:

- Flattening Storm Risk, Severe Risk, Fire Risk, atmospheric instrumentation, hatching, or map overlays into generic
  system rows.
- Applying Liquid Glass to every card instead of reserving it for navigation and floating controls.
- Reusing risk and hazard colors for settings, metadata, offline state, or generic emphasis.
- Treating Apple-native as visual imitation instead of predictable navigation, accessibility, state clarity, and
  interaction behavior.

## Findings

### 1. Navigation And Structure

#### NAV-1: Launch and onboarding presentation state is too implicit

- **File/component:** `Sources/App/SkyAwareApp.swift:183`, `Sources/App/SkyAwareApp.swift:208`,
  `Sources/Features/Onboarding/OnboardingView.swift:41`
- **Current issue:** Disclaimer and restricted-location sheets can compete, while the onboarding page `TabView`
  permits direct swiping between required and permission-dependent steps.
- **Why it feels less Apple-native:** Presentation priority and navigation state are encoded in independent booleans
  and page indexes instead of one explicit route or presented item.
- **Recommended direction:** Use one item-driven launch presentation state. Model onboarding steps with an enum and
  make button actions authoritative; do not allow gestures to bypass required sequencing.
- **Risk:** Medium
- **Implementation complexity:** Small to medium
- **Brand impact:** Strengthens trust without changing visual identity.

#### NAV-2: Utility screens use branded card stacks where native structure would be clearer

- **File/component:** `Sources/Features/Settings/SettingsView.swift:107`,
  `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookView.swift:50`,
  `Sources/Features/Alert/AlertView.swift:73`
- **Current issue:** Settings, Outlooks, and Alerts are composed as `ScrollView` card stacks with custom row
  navigation and repeated card chrome.
- **Why it feels less Apple-native:** Structured utility information benefits from native `List`, `Form`, `Section`,
  `LabeledContent`, `Toggle`, and `NavigationLink` behavior, especially for Dynamic Type and VoiceOver.
- **Recommended direction:** Move Settings to `Form` or inset-grouped `List`. Evaluate native sections for Outlooks
  and Alerts while preserving the existing domain-specific row content and SkyAware background.
- **Risk:** Medium
- **Implementation complexity:** Medium
- **Brand impact:** Strengthens the brand by reserving custom surfaces for weather meaning rather than settings
  plumbing.

### 2. Information Hierarchy

#### HIER-1: Warnings are not guaranteed to outrank watches

- **File/component:** `Sources/Features/Summary/ActiveAlertSummaryView.swift:53`,
  `Sources/Features/Summary/ActiveAlertSummaryView.swift:94`, `Sources/Features/Alert/AlertView.swift:25`
- **Current issue:** Alerts sort primarily by expiration and issue time. The Summary then limits the visible set,
  allowing a watch to displace a tornado or severe thunderstorm warning.
- **Why it feels less Apple-native:** The visual hierarchy does not reliably match the information's urgency. Native
  clarity starts with correct semantic ordering.
- **Recommended direction:** Add a presentation priority of warning, watch, then mesoscale discussion before temporal
  sorting. Use the same ordering helper in Summary and Alerts.
- **Risk:** High
- **Implementation complexity:** Small to medium
- **Brand impact:** Strongly strengthens SkyAware's severe-weather mission.

#### HIER-2: Offline presentation hides cached awareness data

- **File/component:** `Sources/Features/Badges/StormRiskBadgeView.swift:21`,
  `Sources/Features/Badges/SevereWeatherBadgeView.swift:21`,
  `Sources/Features/Summary/ActiveAlertSummaryView.swift:60`
- **Current issue:** Offline state replaces cached risk, atmosphere, fire, and alert content with generic offline
  cards, even while the copy says saved local data is being shown.
- **Why it feels less Apple-native:** The interface discards useful state during degradation instead of preserving
  content and adding a quiet status treatment.
- **Recommended direction:** Keep cached values visible, add a compact offline/freshness indicator, and distinguish
  stale, resolving, unavailable, and confirmed-empty states.
- **Risk:** High
- **Implementation complexity:** Medium
- **Brand impact:** Strongly strengthens cached-first, resolve-forward behavior.

#### HIER-3: Summary hero identity and accessibility sizing need one more pass

- **File/component:** `Sources/Features/Badges/StormRiskBadgeView.swift:31`,
  `Sources/Features/Badges/SevereWeatherBadgeView.swift:31`, `Sources/Utilities/Extensions/ext+View.swift:134`,
  `Sources/Utilities/Extensions/ext+Text.swift:16`
- **Current issue:** Resolved hero tiles omit the canonical `Storm Risk` and `Severe Risk` category labels. Tiles
  remain capped near 145 by 160 points and may shrink important text aggressively at large Dynamic Type sizes.
- **Why it feels less Apple-native:** Category and value are not consistently separated, and accessibility text is
  fitted into a fixed visual composition instead of receiving more space.
- **Recommended direction:** Preserve both custom tiles, add a quiet persistent category label, and allow tiles to
  grow vertically and use multiline text in accessibility layouts.
- **Risk:** Medium
- **Implementation complexity:** Medium
- **Brand impact:** Strengthens the canonical vocabulary and typography-led hierarchy.

#### HIER-4: Nested chrome competes with Summary content

- **File/component:** `Sources/Features/Summary/SummaryView.swift:285`,
  `Sources/Features/Summary/SummaryStatus.swift:117`, `Sources/Utilities/Extensions/ext+View.swift:120`
- **Current issue:** Current Conditions, the outer Risk Snapshot container, hero tiles, rails, and secondary cards can
  each carry their own background, border, and shadow.
- **Why it feels less Apple-native:** Multiple nested elevated surfaces make the hierarchy depend on containers rather
  than typography, spacing, and semantic color.
- **Recommended direction:** Remove one level of chrome from Current Conditions or the outer Risk Snapshot section.
  Keep the domain tiles and rails; reduce surrounding shadows and borders.
- **Risk:** Medium
- **Implementation complexity:** Medium
- **Brand impact:** Strengthens the atmospheric brand. Flattening the hero components themselves would risk it.

### 3. Native SwiftUI Components And Behaviors

#### NATIVE-1: The map layer control behaves like a custom modal launcher, not a current-state menu

- **File/component:** `Sources/Features/Map/MapScreenView.swift:99`, `Sources/Features/Map/Picker.swift:168`
- **Current issue:** The current layer trigger opens a large custom tile sheet for a single selection, obscuring most
  of the hero map.
- **Why it feels less Apple-native:** A current-state selection with six choices maps naturally to `Menu` plus
  `Picker`, while the warning overlay is a separate toggle.
- **Recommended direction:** Make the floating trigger a native `Menu` that shows the selected layer's semantic
  symbol, title, and selection state. Keep a sheet only if previews or advanced layer settings provide clear value.
- **Risk:** Medium
- **Implementation complexity:** Medium
- **Brand impact:** Preserves the map identity if semantic symbols and labels remain; replacing layer meaning with
  generic text alone would risk the brand.

#### NATIVE-2: The location reliability rail is a gesture pretending to be a control

- **File/component:** `Sources/Features/Summary/LocationReliabilitySummaryRailView.swift:50`,
  `Sources/Features/Summary/LocationReliabilitySummaryRailView.swift:70`
- **Current issue:** A child `Not Now` button is nested inside a parent `onTapGesture`, then the hierarchy is combined
  and marked as one button for accessibility.
- **Why it feels less Apple-native:** Native `Button` semantics, focus, activation, and separate actions are being
  recreated manually.
- **Recommended direction:** Make the primary rail action a real `Button` and keep `Not Now` as a distinct sibling
  button with its own accessibility element.
- **Risk:** High
- **Implementation complexity:** Small
- **Brand impact:** Preserves the custom rail while strengthening platform behavior.

#### NATIVE-3: Static metadata is styled as interactive glass

- **File/component:** `Sources/Features/Alert/WatchStatusChip.swift:93`,
  `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift:182`
- **Current issue:** Noninteractive status and metadata chips request interactive glass treatment.
- **Why it feels less Apple-native:** Interactive material should communicate affordance; static metadata should not
  look tappable.
- **Recommended direction:** Keep the custom chips but use noninteractive material. Replace imperative UIKit haptics
  in `Sources/Features/Map/Picker.swift:102` with SwiftUI `sensoryFeedback`.
- **Risk:** Low
- **Implementation complexity:** Small
- **Brand impact:** Preserves domain components and improves interaction honesty.

#### NATIVE-4: Settings confuses system authorization with user preference

- **File/component:** `Sources/Features/Settings/SettingsView.swift:302`,
  `Sources/Features/Settings/SettingsView.swift:237`,
  `Sources/Features/Settings/SettingsDiagnosticsView.swift:90`
- **Current issue:** Denied notification authorization writes stored notification preferences to `false`.
  Production Settings also exposes installation ID, APNs token, and H3 cell diagnostics.
- **Why it feels less Apple-native:** System permission and app preference are separate states. Raw implementation
  identifiers do not belong in a normal user-facing Settings hierarchy.
- **Recommended direction:** Preserve the user's choices, derive effective availability from authorization, and offer
  an `Open Settings` action. Gate diagnostics to debug builds or provide an intentional redacted support export.
- **Risk:** High
- **Implementation complexity:** Small to medium
- **Brand impact:** Strengthens privacy, trust, and predictable Settings behavior.

### 4. Typography

#### TYPE-1: Official narrative text is rendered like raw data

- **File/component:** `Sources/Features/Alert/AlertDetailView.swift:209`,
  `Sources/Features/MesoscaleDiscussion/MesoscaleDiscussionCard.swift:69`,
  `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift:123`
- **Current issue:** Full descriptions and discussions use monospaced body text.
- **Why it feels less Apple-native:** Long-form reading is harder and feels like a diagnostic console. Monospaced text
  is better reserved for identifiers, times, and compact technical values.
- **Recommended direction:** Use `.body` or `.callout` with normal proportional type for narrative products. Preserve
  monospaced digits for probabilities, times, and measurements.
- **Risk:** Medium
- **Implementation complexity:** Small
- **Brand impact:** Strengthens calm readability without simplifying the meteorological content.

#### TYPE-2: Onboarding is not resilient to accessibility text sizes

- **File/component:** `Sources/Features/Onboarding/WelcomeView.swift:13`,
  `Sources/Features/Onboarding/DisclaimerView.swift:13`,
  `Sources/Features/Onboarding/NotificationPermissionView.swift:16`
- **Current issue:** Long content, fixed 80 to 100 point symbols, large titles, multiple spacers, and bottom actions sit
  in non-scrollable vertical stacks.
- **Why it feels less Apple-native:** Essential actions can move off-screen on smaller devices or with large Dynamic
  Type.
- **Recommended direction:** Use a `ScrollView`, scale decorative symbols with `@ScaledMetric`, and pin the primary
  action with `safeAreaInset(edge: .bottom)`.
- **Risk:** High
- **Implementation complexity:** Medium
- **Brand impact:** Preserves onboarding tone while making it trustworthy and accessible.

### 5. Color And Materials

#### COLOR-1: Semantic hazard colors are reused outside their meaning

- **File/component:** `Sources/Features/Alert/WatchStatusChip.swift:34`,
  `Sources/Utilities/Core/AlertStyling.swift:27`, `Sources/Features/Summary/SummaryStatus.swift:343`,
  `Sources/Features/Settings/SettingsView.swift:110`
- **Current issue:** Certainty, urgency, flash-flood styling, offline state, and Settings section headings reuse wind,
  hail, tornado, fire, or enhanced-risk colors.
- **Why it feels less Apple-native:** Color stops acting as a stable semantic signal and becomes decorative
  categorization.
- **Recommended direction:** Create a neutral metadata palette for severity/certainty/urgency, a neutral offline
  treatment, and default Settings headings to primary or secondary text. Preserve actual hazard colors only for the
  hazards they represent.
- **Risk:** High
- **Implementation complexity:** Medium
- **Brand impact:** Strongly strengthens the SkyAware brand contract.

#### COLOR-2: Glass and surface chrome are too broadly opt-out

- **File/component:** `Sources/Utilities/Extensions/ext+View.swift:61`,
  `Sources/Utilities/Extensions/ext+View.swift:159`
- **Current issue:** `cardBackground` defaults to glass on iOS 26, so ordinary content cards, rows, settings sections,
  and metadata surfaces can all receive glass, border, and shadow treatment.
- **Why it feels less Apple-native:** Liquid Glass works best as a hierarchy and interaction material, not a blanket
  replacement for every content background.
- **Recommended direction:** Make glass opt-in. Use it for floating map controls, navigation chrome, and selected
  interactive surfaces. Keep semantic risk tiles and reading surfaces stable and mostly opaque.
- **Risk:** Medium
- **Implementation complexity:** Medium
- **Brand impact:** Prevents the brand from being washed into generic platform styling.

### 6. Shape, Spacing, And Layout

#### LAYOUT-1: The radius system is sound, but spacing remains feature-local

- **File/component:** `Sources/Utilities/Core/SkyAwareRadius.swift:10`, multiple feature files
- **Current issue:** Corner radii are centralized, while common insets and vertical rhythms are repeated as local
  values such as 10, 12, 14, 16, and 18.
- **Why it feels less Apple-native:** Small inconsistencies accumulate across cards, sheets, and rows even when each
  value is individually reasonable.
- **Recommended direction:** Introduce only a small spacing scale when implementation begins, and migrate opportunistically.
  Do not build a large design-token framework.
- **Risk:** Low
- **Implementation complexity:** Small to medium
- **Brand impact:** Preserves the existing soft surface language.

### 7. Map Experience

#### MAP-1: Failed map data can be presented as confirmed no risk

- **File/component:** `Sources/Features/Map/MapFeatureModel.swift:85`,
  `Sources/Features/Map/MapFeatureModel.swift:743`, `Sources/Features/Map/MapLegendView.swift:34`
- **Current issue:** Fetch failures collapse to empty arrays, and empty severe layers render labels such as `No
  tornado risk`.
- **Why it feels less Apple-native:** Loading, unavailable, stale, and confirmed-empty states are not distinguished.
  The interface presents false precision instead of an honest state.
- **Recommended direction:** Carry layer availability/freshness into `MapLayerScene` and show a quiet unavailable or
  saved-data state. Only say `No ... risk` after a successful empty result.
- **Risk:** High
- **Implementation complexity:** Medium
- **Brand impact:** Critical to trustworthy severe-weather awareness.

#### MAP-2: The warning legend can imply warnings that are not active

- **File/component:** `Sources/Features/Map/MapScreenView.swift:169`,
  `Sources/Features/Map/MapLegendView.swift:112`
- **Current issue:** Any warning overlay enables a static legend listing Tornado, Severe Thunderstorm, and Flash Flood.
- **Why it feels less Apple-native:** The legend appears to describe current state but actually describes all
  supported warning styles.
- **Recommended direction:** Build warning legend rows from the warning events currently rendered. Label a static
  reference explicitly as `Warning styles` if it is intentionally not stateful.
- **Risk:** High
- **Implementation complexity:** Small to medium
- **Brand impact:** Strongly strengthens precision and calm communication.

#### MAP-3: Accessibility adaptation removes map functionality and still relies on color

- **File/component:** `Sources/Features/Map/Picker.swift:189`,
  `Sources/Features/Map/RiskPolygonRenderer.swift:45`, `Sources/Features/Map/MapCanvasView.swift:18`
- **Current issue:** `Show Active Alerts` is hidden at accessibility text sizes. Probability polygons are primarily
  differentiated by color, and custom overlays have no VoiceOver summary describing the active layer or local
  relationship.
- **Why it feels less Apple-native:** Accessibility settings remove a control and core map meaning has no equivalent
  nonvisual representation.
- **Recommended direction:** Keep the toggle available in a native list/menu section. Add
  `accessibilityDifferentiateWithoutColor` styling for swatches and overlays, and provide an accessible layer summary
  outside the `MKMapView`.
- **Risk:** High
- **Implementation complexity:** Medium to large
- **Brand impact:** Strengthens the mission; do not remove the custom overlay system.

#### MAP-4: Controls and legends can crowd the map

- **File/component:** `Sources/Features/Map/MapScreenView.swift:139`,
  `Sources/Features/Map/MapLegendView.swift:67`, `Sources/Features/Map/MapLegendView.swift:95`,
  `Sources/Features/Map/Picker.swift:286`
- **Current issue:** Warning and layer legends can remain side by side at XXXL sizes, while the layer trigger and
  compact legend use 40 point minimum heights and the sheet close control is 34 by 34.
- **Why it feels less Apple-native:** Controls obscure the hero and miss the 44 point touch-target baseline.
- **Recommended direction:** Prefer a compact legend trigger sooner, test landscape and warning-plus-layer states,
  and make all controls at least 44 by 44. Use a native cancellation toolbar item in sheets.
- **Risk:** Medium
- **Implementation complexity:** Small
- **Brand impact:** Strengthens the map-first hierarchy.

### 8. Motion And Loading

#### MOTION-1: Motion policy is centralized but not universal

- **File/component:** `Sources/Utilities/Core/SkyAwareMotion.swift:19`,
  `Sources/Features/Onboarding/OnboardingView.swift:43`,
  `Sources/Features/Loading/Toast/ToastView.swift:56`
- **Current issue:** Summary and map transitions respect Reduce Motion, while onboarding and the toast subsystem use
  unconditional animation, including spring and movement transitions.
- **Why it feels less Apple-native:** System accessibility preferences are applied inconsistently across the app.
- **Recommended direction:** Route onboarding and toast transitions through `SkyAwareMotion`; use opacity-only
  transitions under Reduce Motion. Keep spinners secondary and inline.
- **Risk:** Medium
- **Implementation complexity:** Small
- **Brand impact:** Strengthens the calm motion language.

### 9. Accessibility

#### A11Y-1: Alert VoiceOver labels replace critical weather text

- **File/component:** `Sources/Features/Alert/AlertDetailView.swift:129`,
  `Sources/Features/Alert/AlertDetailView.swift:187`
- **Current issue:** Text containing instructions and summary content is assigned labels of only `Instructions` and
  `Summary`.
- **Why it feels less Apple-native:** VoiceOver may announce the replacement label instead of the actual critical
  weather content.
- **Recommended direction:** Remove the overriding labels or group a visible heading with the full text. Add focused
  accessibility tests for alert details.
- **Risk:** High
- **Implementation complexity:** Small
- **Brand impact:** Essential to the severe-weather mission.

#### A11Y-2: Several custom controls have underspecified semantics

- **File/component:** `Sources/Features/Summary/SummaryView.swift:207`,
  `Sources/Features/Map/Picker.swift:136`, `Sources/Features/Map/MapLegendView.swift:196`
- **Current issue:** Hero buttons rely on inferred multi-element labels, selected layers append `selected` to a string
  instead of using traits, and several legend rows lack explicit semantic labels.
- **Why it feels less Apple-native:** VoiceOver receives implementation-shaped fragments rather than concise
  label/value/state descriptions.
- **Recommended direction:** Give hero buttons explicit category labels and risk values, use `.isSelected` traits,
  and label legend rows with layer, level, and probability.
- **Risk:** Medium
- **Implementation complexity:** Small
- **Brand impact:** Strengthens clarity without visual change.

### 10. Copy And Terminology

#### COPY-1: Settings, Outlooks, and onboarding expose implementation language

- **File/component:** `Sources/Features/Settings/SettingsView.swift:124`,
  `Sources/Features/Settings/SettingsView.swift:136`,
  `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookView.swift:60`,
  `Sources/Features/Onboarding/OnboardingView.swift:161`
- **Current issue:** User-facing strings include `Meso Notifications`, `Server Notifications`, `Signal`, `Newest SPC
  product`, `sync completes`, `Finalizing device registration`, and `Capturing your first location context`.
- **Why it feels less Apple-native:** The copy describes subsystems and providers instead of the user's intent and
  current state.
- **Recommended direction:** Use `Mesoscale Discussion Alerts`, `Local Severe-Weather Alerts`, `Share Approximate
  Location for Alerts`, `Latest Outlook`, and progressive phrases such as `Getting alerts ready`.
- **Risk:** Medium
- **Implementation complexity:** Small
- **Brand impact:** Strongly strengthens the product voice.

#### COPY-2: Some detail screens invent precision when metadata is missing

- **File/component:** `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift:17`,
  `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift:28`
- **Current issue:** A missing day becomes `Day 1`, and a missing valid-until time becomes the publication time.
- **Why it feels less Apple-native:** The interface should omit unknown metadata rather than fabricate a complete
  presentation.
- **Recommended direction:** Preserve optional metadata through presentation and show only known values.
- **Risk:** Medium
- **Implementation complexity:** Small to medium
- **Brand impact:** Strengthens precision and trust.

## Prioritized Implementation Plan

### Quick Wins

1. Fix alert VoiceOver labels so critical text is read.
2. Convert the location reliability rail to native buttons with separate actions.
3. Restore 44 point touch targets for map controls and use a toolbar cancellation button.
4. Stop hiding `Show Active Alerts` at accessibility text sizes.
5. Replace internal copy in Settings, Outlooks, and onboarding.
6. Remove decorative orange from Settings and stop using interactive glass on static chips.
7. Make warning legend rows reflect warnings actually rendered.
8. Correct hero accessibility labels and preserve `Storm Risk` / `Severe Risk` category identity.

### Medium Polish

1. Convert Settings to `Form` or inset-grouped `List`.
2. Replace the map layer sheet with a native current-state `Menu` and selection model.
3. Reduce one level of Summary surface chrome and make glass opt-in.
4. Make onboarding scrollable, Dynamic Type-safe, and Reduce Motion-aware.
5. Use proportional body typography for official discussions and descriptions.
6. Preserve cached Summary content while offline and layer status on top.
7. Normalize semantic metadata colors without changing hazard colors.
8. Rework Alerts and Outlooks toward native sections while retaining domain rows.

### Larger Design/System Work

1. Add explicit unavailable, stale, resolving, and confirmed-empty map states.
2. Provide VoiceOver and Differentiate Without Color alternatives for map overlays.
3. Establish one alert presentation priority shared by Summary, Alerts, widgets, and future surfaces.
4. Audit iOS 26 glass usage across the app and define explicit content versus floating-control policy.
5. Add a small spacing scale only after repeated inconsistencies are confirmed during implementation.

### Do Not Do / Diminishing Returns

- Do not replace Storm Risk, Severe Risk, Fire Risk, Atmospheric Conditions, hatching, or warning geometry with
  generic rows.
- Do not redesign Summary into Apple Weather's forecast-card model.
- Do not collapse or reorder primary tabs without usage evidence.
- Do not apply Liquid Glass to every card because the API is available.
- Do not create a large design-system framework to replace a handful of spacing constants.
- Do not add decorative gradients, shimmer, springs, or motion that do not clarify state.
- Do not remove provider attribution from detail or legal surfaces where provenance matters; remove it from primary
  status copy where it does not help the user.

## Suggested GitHub Issues

### Issue 1: Enforce warning-first alert presentation

**Problem**

Summary and Alerts sort by time without guaranteeing warnings outrank watches.

**Proposed fix**

Add one shared alert presentation priority and apply warning, watch, then mesoscale ordering before temporal sorting.

**Acceptance criteria**

- Tornado and severe thunderstorm warnings always appear before watches.
- Summary limits are applied after priority sorting.
- Equal-priority items retain deterministic time ordering.
- Existing warning, watch, and meso styling remains unchanged.

**Files likely touched**

- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Alert/AlertView.swift`
- Alert presentation model/helper files

**Testing/previews needed**

- Unit tests covering mixed warning/watch/meso arrays.
- Summary and Alerts previews with more items than the visible limit.

### Issue 2: Preserve cached Summary content while offline

**Problem**

Offline cards replace cached severe-weather context even though cached-first behavior is a product requirement.

**Proposed fix**

Keep cached values rendered and add a compact offline/freshness treatment. Reserve replacement cards for genuinely
unavailable content.

**Acceptance criteria**

- Cached storm, severe, fire, atmosphere, and alert values remain visible offline.
- Offline status does not imply current freshness.
- Confirmed-empty and unresolved states remain distinct.
- Risk semantics and section order do not change.

**Files likely touched**

- `Sources/Features/Badges/StormRiskBadgeView.swift`
- `Sources/Features/Badges/SevereWeatherBadgeView.swift`
- `Sources/Features/Badges/FireWeatherRailView.swift`
- `Sources/Features/Badges/AtmosphereRailView.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Summary/SummaryStatus.swift`

**Testing/previews needed**

- Previews for cached-online, cached-offline, unresolved, and unavailable states.
- Focused presentation-state unit tests.

### Issue 3: Make map empty, unavailable, and warning states trustworthy

**Problem**

Layer failures can appear as no risk, and the warning legend lists supported warning types rather than active types.

**Proposed fix**

Carry map availability into scene state and derive warning legend rows from rendered warning events.

**Acceptance criteria**

- `No risk` appears only after a successful empty response.
- Failed or stale layers show calm, nontechnical state copy.
- Warning legend rows match warning types currently on the map.
- Cached overlays remain visible when appropriate.

**Files likely touched**

- `Sources/Features/Map/MapFeatureModel.swift`
- `Sources/Features/Map/MapScreenView.swift`
- `Sources/Features/Map/MapLegendView.swift`
- Map scene/state models

**Testing/previews needed**

- Unit tests for success-empty, failure, stale, and mixed-warning states.
- Map previews for every state.

### Issue 4: Make the map layer selector native and lightweight

**Problem**

A large custom sheet obscures the map for a simple current-layer selection.

**Proposed fix**

Use a `Menu` with a selection-aware `Picker` or menu buttons. Keep semantic symbols and move the active-alert toggle
to a native menu or settings section.

**Acceptance criteria**

- The trigger shows the current layer's symbol, title, and chevron.
- Selection is visible through native selected state and VoiceOver traits.
- `Show Active Alerts` remains available at all Dynamic Type sizes.
- The map remains visually dominant.

**Files likely touched**

- `Sources/Features/Map/MapScreenView.swift`
- `Sources/Features/Map/Picker.swift`
- `Tests/UnitTests/LayerPickerAdaptiveLayoutTests.swift`

**Testing/previews needed**

- Normal, landscape, XXXL, AX1, and AX3 previews.
- VoiceOver and touch-target checks.

### Issue 5: Add accessible alternatives for map overlays

**Problem**

Risk geography is conveyed visually through color and custom `MKOverlay` rendering.

**Proposed fix**

Add Differentiate Without Color treatments, explicit legend semantics, and an accessible selected-layer summary
outside the map canvas.

**Acceptance criteria**

- Legend rows announce layer, level, and probability.
- Overlay styles remain distinguishable with Differentiate Without Color.
- VoiceOver can discover the active layer and a concise description of available local map information.
- Hatching remains the canonical stronger-storm signal.

**Files likely touched**

- `Sources/Features/Map/MapCanvasView.swift`
- `Sources/Features/Map/RiskPolygonRenderer.swift`
- `Sources/Features/Map/MapLegendView.swift`
- `Sources/Features/Map/MapScreenView.swift`

**Testing/previews needed**

- VoiceOver manual pass.
- Differentiate Without Color screenshots.
- Light/dark and multiple layer previews.

### Issue 6: Modernize Settings structure and vocabulary

**Problem**

Settings uses heavy custom cards, generic orange emphasis, and subsystem language. Notification denial also clears
stored preferences instead of preserving intent.

**Proposed fix**

Adopt `Form`/`Section`/`LabeledContent`, neutral styling, user-centered labels, and an effective authorization state
that does not overwrite preferences. Gate or redact production diagnostics.

**Acceptance criteria**

- Notification denial does not destroy saved preference choices.
- An explicit action opens iOS Settings when authorization is denied.
- No primary Settings label includes `Signal`, `Server Notifications`, or unexplained `Meso`.
- Diagnostics are debug-only or intentionally redacted for support.

**Files likely touched**

- `Sources/Features/Settings/SettingsView.swift`
- `Sources/Features/Settings/SettingsDiagnosticsView.swift`
- Notification preference readers

**Testing/previews needed**

- Unit tests for authorization versus stored preferences.
- Settings previews for allowed, denied, and restricted location states.
- VoiceOver and large Dynamic Type review.

### Issue 7: Make onboarding native, accessible, and calm

**Problem**

Onboarding can be swiped out of sequence, clips at large text sizes, uses hand-drawn buttons, and does not consistently
respect Reduce Motion.

**Proposed fix**

Use enum-driven step state, scrollable pages, `safeAreaInset` actions, native prominent button styles, scaled artwork,
and shared motion policy.

**Acceptance criteria**

- Required steps cannot be bypassed by page swiping.
- Primary and secondary actions remain reachable at AX5 on a small iPhone.
- Reduce Motion removes page movement and spring behavior.
- Status copy is user-centered and nontechnical.

**Files likely touched**

- `Sources/Features/Onboarding/OnboardingView.swift`
- `Sources/Features/Onboarding/WelcomeView.swift`
- `Sources/Features/Onboarding/DisclaimerView.swift`
- `Sources/Features/Onboarding/LocationPermissionView.swift`
- `Sources/Features/Onboarding/OnboardingAlwaysUpgradeView.swift`
- `Sources/Features/Onboarding/NotificationPermissionView.swift`

**Testing/previews needed**

- UI tests for step sequencing and skip paths.
- AX1 through AX5 previews on a compact device.
- Reduce Motion manual pass.

### Issue 8: Restore semantic color and material discipline

**Problem**

Hazard colors are reused for metadata, offline state, and Settings, while glass is the default for broad content
surfaces.

**Proposed fix**

Create a neutral metadata/status palette, make glass opt-in, and reduce nested shadows without changing domain color
ladders.

**Acceptance criteria**

- Storm, severe threat, fire, meso, atmosphere, freshness, and offline colors remain distinct.
- Static chips do not use interactive glass.
- Risk and hazard colors are not used as generic accents.
- Summary risk tiles and map overlays retain their current semantic colors.

**Files likely touched**

- `Sources/Utilities/Extensions/ext+View.swift`
- `Sources/Utilities/Core/AlertStyling.swift`
- `Sources/Features/Alert/WatchStatusChip.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Settings/SettingsView.swift`

**Testing/previews needed**

- Light/dark screenshots for Summary, alert detail, Settings, and map controls.
- Contrast checks with Increase Contrast and Differentiate Without Color.

### Issue 9: Improve weather-product reading and VoiceOver semantics

**Problem**

Long official discussions use monospaced text, and alert accessibility labels can replace the critical content.

**Proposed fix**

Use proportional body styles for narrative text and explicit heading-content grouping for VoiceOver.

**Acceptance criteria**

- Instructions and summaries are read in full by VoiceOver.
- Long discussions use readable system body styles.
- Times, identifiers, measurements, and probabilities may retain monospaced digits.
- Missing Outlook metadata is omitted rather than fabricated.

**Files likely touched**

- `Sources/Features/Alert/AlertDetailView.swift`
- `Sources/Features/MesoscaleDiscussion/MesoscaleDiscussionCard.swift`
- `Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift`

**Testing/previews needed**

- VoiceOver manual pass for a warning, watch, meso, and outlook.
- Large Dynamic Type previews with long official text.
- Unit tests for missing Outlook metadata.

## Validation Notes

- Reviewed repository guidance, the North Star spec, branding guide, code-review guidance, and prior resolve-forward
  polish work.
- Inspected current SwiftUI source and UI reference screenshots in `docs/images`.
- No app code was changed.
- No build, test, or live Simulator pass was run because no Simulator was booted during this audit.
