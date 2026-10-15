---
title: SkyAware Map Design
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - design
  - map
  - mapkit
  - swiftui
---

# SkyAware Map Design

## Purpose

This document defines the canonical visual and interaction design for SkyAware's Map experience.

The Map provides spatial context for severe-weather awareness.

It helps users understand where relevant forecast risks, severe hazards, mesoscale discussions, and official warning areas exist relative to their location.

This document owns:

- Map visual hierarchy and composition.
- Map presentation and camera behavior.
- Layer selection and navigation controls.
- Weather and warning overlay presentation.
- Probability and categorical color representation.
- Conditional-intensity hatching.
- Map legends and explanations.
- Compact awareness summaries.
- Native materials and floating controls.
- Map-specific accessibility.
- Visual consistency and validation.

This document does not redefine meteorological interpretation, source-data processing, polygon eligibility, accepted-state ownership, or persistence.

Related documentation:

- [Design System](README.md)
- [Foundations](foundations.md)
- [North Star](../product/north-star.md)
- [Brand and Voice](../brand/brand-and-voice.md)
- [Today](today.md)
- [States and Accessibility](states-accessibility.md)
- [Visual Review](visual-review.md)

The North Star owns weather meaning.

Foundations owns shared visual principles.

This document owns their application to Map.

---

# 1. Design Intent

The Map is a severe-weather awareness surface, not a general-purpose weather explorer.

Its purpose is to answer:

- What risk or hazard is being displayed?
- Where does that risk exist?
- How does it relate to my location?
- What do the colors and textures mean?
- Are official warning areas visible?
- Where can I find additional explanation?

The Map should feel:

- Clear.
- Calm.
- Precise.
- Spatially understandable.
- Meteorologically trustworthy.
- Native to Apple platforms.
- Consistent with SkyAware's identity.

## Primary Principle

**The map is the hero, not the controls.**

Risk polygons, warning areas, geographic context, and the user's location should remain the primary visual content.

Controls, legends, and summaries should help interpret that information without dominating it.

## Immediate Comprehension

A user should be able to identify the selected Map layer and understand the basic color meaning within approximately two seconds.

Detailed meteorological interpretation may require additional explanation.

The primary Map experience should not.

---

# 2. Map Information Hierarchy

The Map uses three conceptual visual layers.

## Level 0: Geographic Canvas

The geographic map provides spatial context.

It should remain visible and understandable beneath weather overlays.

## Level 1: Meteorological Information

Examples:

- Categorical storm-risk polygons.
- Severe-hazard probability polygons.
- Conditional-intensity hatching.
- Fire-weather risk polygons.
- Mesoscale discussion areas.
- Active warning polygons.

These are the Map's primary information.

They must retain established semantic meaning.

## Level 2: Interpretation and Controls

Examples:

- Layer selector.
- Warning-overlay visibility control.
- Map legends.
- Compact awareness summary.
- Legend or awareness detail sheets.

These elements should remain compact, readable, and appropriately positioned.

They must not unnecessarily obscure the map.

## Hierarchy Rule

Weather information determines importance.

Do not give navigation controls stronger visual prominence than the data being explored.

Do not create multiple competing floating panels when the existing controls can communicate the same information.

---

# 3. Geographic Canvas

SkyAware uses an established MapKit-based geographic presentation.

Preserve the existing map implementation and its selected native map appearance unless a separate product decision changes it.

## Geographic Context

The map should provide enough geographic detail for users to understand:

- Their approximate location.
- Relevant surrounding areas.
- The spatial extent of weather risks.
- The relationship between nearby boundaries and the selected weather layer.

Avoid excessive map styling that competes with meteorological overlays.

## Current Location

Preserve the established current-location indicator and location context.

Do not introduce a custom location symbol merely for visual consistency with Today.

Use established native MapKit behavior where it provides the intended information.

## Map Interaction

Preserve existing:

- Panning.
- Zooming.
- Map exploration.
- Selected-layer behavior.
- Established camera state.

Do not replace native gestures with unnecessary custom interaction handling.

The user should remain in control of the geographic area they are examining.

---

# 4. Camera and Viewport Behavior

Map camera behavior is part of the user's interaction state.

It must remain stable during routine weather-data updates.

## Initial Location

The established behavior uses an initial location-based map center when appropriate.

That initial positioning must not become continuous automatic recentering.

## Preserve User Exploration

Once the user has moved or zoomed the map, routine data refreshes must not unexpectedly reset the camera.

Preserve the current:

- Map center.
- Zoom level.
- User-selected geographic context.

A change in weather data does not automatically authorize a viewport change.

## Layer Changes

Changing the selected weather layer should preserve established camera behavior.

Do not automatically return to the user's location when switching layers.

## Scope Boundary

Do not introduce:

- A new recenter button.
- Automatic follow-location behavior.
- New camera animations.
- New zoom defaults.
- Unrequested region-fitting behavior.

These require explicit product decisions.

A visual redesign is not authorization to modify the map's navigation model.

---

# 5. Supported Map Layers

The established Map experience supports the following user-selectable layers.

| Layer | User-facing name | Purpose |
| --- | --- | --- |
| Categorical | Severe Risk | SPC categorical convective risk |
| Wind | Wind | Severe wind probabilities |
| Hail | Hail | Severe hail probabilities |
| Tornado | Tornado | Tornado probabilities |
| Mesoscale | Mesoscale | Mesoscale discussion areas |
| Fire | Fire | Fire-weather risk areas |

The current selection menu uses concise names.

Legends may use more descriptive titles such as "Wind Risk" or "Tornado Risk" when that improves interpretation.

## Layer Boundaries

Each layer must preserve its established meteorological meaning.

Do not change a layer's contents merely to simplify legend styling.

Do not merge different hazard types into one visual interpretation.

Do not introduce additional layers without an explicit product decision.

## Existing Functionality

Preserve the current layer-selection and navigation relationships.

For example:

- Storm Risk on Today opens the categorical layer.
- Severe Risk opens the relevant hazard layer.
- Fire Risk opens the fire layer.

Do not change these destinations during visual refinement.

---

# 6. Layer Selector

The Map layer selector is the primary control for choosing displayed weather data.

The approved interaction uses a single, combined native menu control.

## 6.1 Structure

The visible selector contains:

1. Semantic layer icon.
2. Current selected-layer title.
3. Trailing downward chevron.

The control communicates both:

- What layer is currently displayed.
- That the user can select another layer.

## 6.2 User-Facing Language

Use:

"Severe Risk"

for the categorical layer.

Do not expose:

"Categorical"

as the primary selector label.

Use the established layer names rather than inventing alternate wording.

## 6.3 Interaction

Use the existing native menu behavior.

The selected layer should remain visually and accessibly identifiable.

Do not replace the menu with:

- A custom full-screen picker.
- A separate settings screen.
- A collection of floating layer buttons.
- An always-visible layer toolbar.
- A decorative control that imitates native menu behavior.

Preserve native selection feedback where appropriate.

## 6.4 Visual Treatment

The selector should:

- Float lightly above the map.
- Remain readable over variable geography.
- Use appropriate native material behavior.
- Maintain sufficient touch-target size.
- Avoid excessive padding.
- Remain visually subordinate to the map.

The selected-layer title is more important than decorative control styling.

## 6.5 Accessibility

Preserve:

- Meaningful menu labeling.
- Current selection value.
- Selected-item semantics.
- VoiceOver discoverability.
- Appropriate Dynamic Type adaptation.

At larger text sizes, allow the selected-layer label to wrap or adapt.

Do not reduce it to an unreadable single-line abbreviation.

---

# 7. Active Warning Overlay Control

The established layer menu also contains the active-alert geometry visibility control.

Its user-facing action is:

"Show Active Alerts"

## Responsibilities

The control determines whether supported active alert geometry is displayed on the map.

It does not:

- Disable alert ingestion.
- Cancel official warnings.
- Change notification preferences.
- Change the user's local alert state.
- Modify accepted weather information.

It is a presentation control.

## Interaction

Preserve the established toggle behavior and its current persistence semantics.

Do not move it to a separate floating button without an explicit design decision.

Keep the layer menu focused on the existing Map viewing options.

## Visibility

When active alert geometry is hidden, the map should accurately reflect the user's selection.

Do not continue displaying warning geometry while implying it is disabled.

Likewise, do not remove the underlying accepted alert information.

## Legend Relationship

The warning legend should describe warning geometry actually displayed.

Do not show legend items for hidden warning polygons.

Do not fabricate an empty warning legend merely to occupy consistent space.

---

# 8. Meteorological Overlay Presentation

Meteorological overlays are the Map's primary information layer.

They should be:

- Recognizable.
- Readable.
- Semantically accurate.
- Consistent with accepted source data.
- Stable during map interaction.
- Legible in light and dark appearance.

## Polygon Presentation

Preserve established:

- Geographic boundaries.
- Source-provided geometry.
- Probability or category relationships.
- Polygon ordering and rendering semantics.
- Relevant fill and stroke relationships.
- Conditional-intensity associations.

Do not alter underlying weather geometry to make the rendered map look cleaner.

## Overlapping Risk Areas

Multiple polygons may represent different risk levels or hazards.

Their appearance must preserve the established interpretation.

Avoid styling that makes overlapping polygons impossible to distinguish.

Do not flatten meaningful distinctions into a single decorative color wash.

## Geographic Readability

Weather overlays should remain visible without completely obscuring the map.

The geographic context must remain useful for determining local relevance.

Do not increase fill opacity merely to make screenshots appear more colorful.

Evaluate opacity and stroke treatments against representative geography.

---

# 9. Semantic Color on Map

Map colors communicate established weather meaning.

They are not arbitrary palette choices.

## Categorical Risk

Categorical storm-risk polygons use the established SPC-aligned risk ladder.

The associated color communicates the categorical outlook meaning.

Preserve category order and semantics.

Do not introduce custom categories or visual severity interpretations.

## Severe-Hazard Probability

Tornado, wind, and hail layers use their established probability colors and probability thresholds.

The colors communicate likelihood within the corresponding hazard layer.

Do not interpret a stronger color as proof that storms will occur.

Do not treat conditional intensity as an increase in probability.

## Fire Weather

Fire-weather polygons use the established fire-risk categories and source semantics.

Preserve their visual distinction from convective storm-risk categories.

## Mesoscale Discussions

Mesoscale discussions retain their distinct visual identity.

Do not reuse High categorical-risk purple indiscriminately for mesoscale products.

## Active Warnings

Active warning polygons use their established warning-type styling.

Do not replace authoritative warning distinctions with generic hazard coloring.

## Shared Semantic Sources

Use existing semantic mappings and polygon styling code.

Avoid defining new local colors that approximate existing risk colors.

A visual adjustment must not silently change the meaning of a risk threshold.

---

# 10. Conditional-Intensity Hatching

Conditional intensity is a modifier of an established severe-hazard forecast.

It is not a standalone Map layer.

The North Star defines its eligibility, provenance, and meteorological meaning.

## 10.1 Fundamental Distinction

**Color communicates likelihood.**

**Hatching communicates potential intensity if the hazard occurs.**

These meanings must remain separate.

Higher conditional intensity does not mean a higher probability of storms.

## 10.2 Relevant Layers

Conditional-intensity presentation belongs to supported severe-hazard layers:

- Tornado.
- Wind.
- Hail.

Display hatching only when appropriate, accepted intensity data exists for the selected layer.

Do not invent hatching for:

- Categorical risk.
- Fire Risk.
- Mesoscale discussions.
- Unsupported severe-intensity levels.

## 10.3 Visual Character

Hatching should feel:

- Meteorological.
- Deliberate.
- Subordinate to probability color.
- Visibly distinguishable.
- Consistent with the legend.
- Stable during interaction.

Hatching should read as texture, not heavy ink.

## 10.4 Stable Screen-Space Texture

The established hatching approach uses a stable visual texture.

Do not make hatch spacing or line width visually expand and contract dramatically as the user zooms.

The pattern should maintain a consistent perceived scale.

Preserve the existing renderer strategy unless a demonstrated correctness or accessibility defect requires change.

## 10.5 Intensity Differentiation

Supported intensity levels may have different hatch characteristics.

These differences must remain consistent with their established semantic mapping.

Do not invent additional meteorological levels.

In particular, do not add an unsupported third hail-intensity level.

## 10.6 Light and Dark Appearance

Tune hatching for both appearances.

In light mode:

- Preserve visible texture.
- Avoid excessive dark line density.
- Keep the probability color readable.

In dark mode:

- Avoid muddy low-contrast hatching.
- Maintain sufficient luminance distinction.
- Preserve the established pattern geometry.
- Avoid overpowering underlying colors.

Prefer focused contrast or luminance adjustments over redesigning the renderer.

## 10.7 Accessibility

Hatching must not be the sole representation of intensity.

Provide corresponding text meaning through the legend and accessible explanation.

Do not require users to interpret line density or pattern differences without supporting information.

---

# 11. Map Legends

The legend explains what the currently displayed Map information means.

Its purpose is rapid interpretation, not exhaustive meteorological education.

## Primary Goal

A user should understand the selected layer's basic visual meaning within approximately two seconds.

## Legend Content

The legend should communicate:

- Current layer identity.
- Applicable categories or probabilities.
- Corresponding colors and symbols.
- Conditional-intensity meaning when available.
- Relevant warning-overlay categories.

Do not display information unrelated to the selected layer merely to make the legend appear complete.

## Visual Structure

Use compact rows with clear swatches and labels.

Preserve:

- Readable headings.
- Consistent swatch sizing.
- Appropriate row spacing.
- Clear semantic associations.
- Restrained container styling.

The legend should feel like a compact interpretation aid.

It should not become a second weather dashboard floating over the map.

---

# 12. Probability and Risk Legends

Each selected layer uses its corresponding established legend content.

## Categorical

Show the relevant categorical storm-risk color ladder.

Preserve the established category order and risk terminology.

## Tornado, Wind, and Hail

Show applicable severe-probability legend entries for the selected layer.

Use the existing probability and significant-risk semantics.

Do not substitute generic categorical-risk descriptions.

## Fire Weather

Show the established fire-risk categories and corresponding colors.

Do not interpret these as convective storm probabilities.

## Mesoscale

Use the established mesoscale representation and label.

Do not invent probability thresholds for mesoscale discussions.

## Empty and Unavailable States

The legend must communicate its actual accepted presentation state.

Distinguish:

- Loading.
- Resolving with accepted content.
- Current.
- Confirmed empty.
- Stale.
- Unavailable.

Do not show an empty legend as though it means no risk when the source is unavailable.

---

# 13. Hatching Legend

Conditional-intensity explanation belongs inside the existing severe-hazard legend.

Do not create an additional floating hatching panel.

## 13.1 Placement

For supported severe-hazard layers, the legend may contain:

1. Selected-layer title.
2. Probability entries.
3. Subtle divider.
4. Hatching swatch and explanation.

This structure keeps probability and intensity visibly distinct.

## 13.2 Conditional Visibility

Show the hatching explanation only when:

- The selected layer supports it.
- Relevant accepted intensity information is present.
- Applicable legend content exists.

Do not reserve an empty hatching section when intensity data is unavailable.

## 13.3 User-Facing Language

Preferred concepts:

"Hatching"

"Stronger storms possible"

Use hazard-specific potential-impact language in the expanded explanation.

Do not expose:

- CIG.
- CIG1.
- CIG2.
- CIG3.

Those are internal terminology.

## 13.4 Swatch Consistency

The legend swatch should match the map's established hatch language.

Preserve:

- Pattern direction.
- Relative spacing.
- Distinct intensity treatments.
- Recognizable texture character.

The legend sample may be slightly softer than the map texture, provided it remains recognizable.

Avoid using a different pattern merely because it looks better inside the legend.

## 13.5 Explanation

The expanded explanation should make the following distinction clear:

Hatching identifies areas where stronger hazard intensity may be possible if the hazard occurs.

It does not establish a greater probability of storms.

Use the same supported intensity descriptions as Today's Severe Risk.

Do not introduce competing interpretations between Today and Map.

---

# 14. Active Warning Legend

Active warning geometry uses its own supporting legend.

## Responsibilities

The warning legend identifies the types of active warning areas currently displayed.

It should:

- Be concise.
- Use established warning colors.
- Preserve meaningful event distinctions.
- Remain subordinate to the map.
- Avoid duplicating the full Local Alerts experience.

## Conditional Visibility

Show the warning legend only when relevant warning overlays are actually displayed.

Do not create a permanent empty warning legend container.

## Multiple Warning Types

When multiple warning types exist, preserve readable labels and swatches.

Do not let the warning legend obscure an excessive portion of the geographic map.

Use the existing adaptive legend behavior when space is constrained.

---

# 15. Adaptive Legend Presentation

The established Map implementation supports multiple legend presentations depending on available space.

Preserve this adaptive behavior.

## 15.1 Inline Legends

When sufficient space exists, the selected-layer legend and warning legend may appear inline.

Keep them compact and visually balanced.

## 15.2 Stacked Legends

When horizontal space is constrained, legends may stack vertically.

This is preferable to forcing unreadable side-by-side panels.

## 15.3 Compact Legend Trigger

When available space or accessibility requirements make full inline legends impractical, use the established compact legend trigger.

The trigger should clearly indicate that additional legend information is available.

## 15.4 Legend Sheet

The compact trigger opens a native sheet containing the complete relevant legend.

The sheet should preserve:

- Selected-layer meaning.
- Warning information when present.
- Conditional-intensity explanation.
- Readable text and swatches.
- Native dismissal.
- Dynamic Type support.

Do not remove essential legend information merely to keep the compact trigger small.

## 15.5 Design Boundary

Adaptive legend behavior may change the arrangement of supporting controls.

It must not alter:

- Meteorological meaning.
- Selected-layer state.
- Underlying map content.
- Probability thresholds.
- Warning visibility.

---

# 16. Map Awareness Summary

The Map may display a compact summary of the current primary awareness state.

Its purpose is to provide local weather context while the user explores spatial risk.

It is not a second Today screen.

## 16.1 Conditional Visibility

Show the awareness summary only when there is meaningful information to communicate.

Do not display a permanent empty summary container.

Quiet or unresolved states may omit the floating summary according to established presentation rules.

## 16.2 Content

The summary may include:

- Primary awareness symbol.
- Main risk or alert title.
- Applicable event timing.
- Concise explanatory text.

Keep the information brief.

Do not duplicate all three supporting risk cards.

## 16.3 Visual Treatment

Use a compact, stable weather-content surface distinct from floating controls.

Preserve the established:

- Semantic symbol.
- Narrow leading accent.
- Readable title and explanation.
- Restrained edge treatment.
- Compact proportions.

Do not automatically copy Today's full semantic-gradient card treatment onto the Map summary.

The summary should be recognizable as SkyAware content while remaining appropriately subordinate to the map.

## 16.4 Light and Dark Appearance

Light mode uses the established near-white weather-content family.

Dark mode retains the approved dark content treatment.

The summary must remain readable over varied geographic backgrounds.

A restrained separation shadow may be used when necessary, following Foundations.

Do not introduce excessive material effects.

## 16.5 Responsive Behavior

The summary must not consume an excessive portion of the map viewport.

When content or display space is constrained, use the established compact disclosure presentation.

The compact presentation provides access to the fuller awareness summary in a native sheet.

Do not aggressively shrink essential weather text.

## 16.6 Interaction

The expanded awareness experience should remain discoverable when the compact disclosure is shown.

Do not turn an informational summary into an unrelated navigation destination.

Preserve the established awareness-sheet interaction.

## 16.7 Accessibility

Expose meaningful summary text to assistive technology.

Avoid duplicate announcements from decorative symbols or rails.

The summary should remain useful when the visual map itself cannot be explored in detail.

---

# 17. Native Materials and Floating Controls

The Map applies the shared content-versus-controls distinction defined in Foundations.

## Weather Content

Examples:

- Map legends.
- Warning legends.
- Awareness summaries.
- Expanded meteorological explanations.

These are information surfaces.

They should remain stable and readable over changing map imagery.

They are not Liquid Glass by default.

## Floating Controls

Examples:

- Layer selector.
- Compact legend trigger.
- Appropriate native Map utilities.

These are interaction surfaces.

They may use native Liquid Glass where supported.

## Glass Policy

Use native platform behavior.

Do not create custom imitations of Liquid Glass.

Avoid adding decorative shadows or backgrounds around controls that already receive appropriate system treatment.

## Material Contrast

The Map background is variable.

Controls and content must remain legible over:

- Light geography.
- Dark geography.
- Water.
- Urban areas.
- Overlapping polygons.
- Warning overlays.

Evaluate actual combinations rather than only neutral preview backgrounds.

---

# 18. Light and Dark Map Design

Light and dark appearances are independently designed.

## Light Mode

The established light weather-content surface uses:

`#FCFCFD`

Use the approved restrained edge treatment where necessary.

Weather-content surfaces should remain readable without relying on heavy shadows.

Native floating controls may use their supported system material treatment.

Do not apply the ordinary Today canvas color as an opaque replacement for the geographic map.

## Dark Mode

Preserve the established dark map and content styling.

Avoid:

- Muddy risk polygons.
- Nearly invisible hatching.
- Bright floating panels.
- Overly strong borders.
- Excessive glowing effects.
- Unrelated charcoal surface tones.

## Semantic Consistency

The same weather category must retain the same meaning in light and dark appearance.

Visual contrast may be tuned independently.

Semantic identity must not change.

## Appearance Changes

Switching appearance should not change:

- Selected layer.
- Map camera.
- Warning-overlay preference.
- Accepted risk interpretation.

---

# 19. Map State and Refresh Behavior

Map presentation consumes accepted weather state.

It must not expose incomplete source ingestion as accepted geographic information.

## Cached-First Behavior

When valid accepted Map content exists:

- Keep it visible during refresh.
- Preserve the selected layer.
- Preserve the user's camera.
- Avoid unnecessary overlay removal.
- Replace the displayed information with a coherent accepted revision.

## Layer-Specific State

Different Map layers may have different availability or refresh states.

Do not interpret a failed source request as a confirmed empty geographic result.

Preserve the established per-layer state behavior.

## Warning Overlay State

Warning geometry is independently meaningful weather information.

Do not remove valid accepted warning overlays solely because an unrelated forecast layer could not refresh.

Likewise, do not fabricate warning geometry when current accepted information does not support it.

## No Visual Churn

Avoid:

- Repeated polygon disappearance and reappearance.
- Unnecessary legend resets.
- Camera jumps.
- Repeated loading indicators.
- Animated overlays on unchanged accepted data.
- Briefly empty Map states during successful refresh.

## State Communication

Use clear distinctions between:

- Loading.
- Resolving.
- Current.
- Confirmed empty.
- Stale.
- Unavailable.

The legend and accessible Map summary should reflect the actual presentation state.

Detailed accepted-state rules belong in [States and Accessibility](states-accessibility.md).

---

# 20. Map Accessibility

Map accessibility must preserve meaningful weather interpretation for users who cannot rely on visual polygon exploration.

## 20.1 Accessible Map Summary

The established accessible Map summary communicates:

- Selected-layer state.
- Relevant local geographic relationship where known.
- Active warning-overlay status.
- Applicable displayed warning types.

Keep these descriptions aligned with actual accepted information.

## 20.2 Location Relationship

When supported by available geometry and location information, communicate whether the user's location lies within a displayed risk area.

Do not claim a geographic relationship when it cannot be established.

Use an appropriately scoped unknown or unavailable state.

## 20.3 Differentiate Without Color

The Map uses established non-color differentiation for relevant polygon boundaries.

Preserve meaningful differences in stroke pattern and emphasis where supported.

Do not rely solely on fill color to distinguish risk categories.

## 20.4 Legend Accessibility

Legend rows must provide accessible category or probability descriptions.

Do not require VoiceOver users to infer meaning from colored swatches.

Conditional-intensity meaning must remain available as text.

## 20.5 Dynamic Type

The layer selector, compact legend trigger, and expanded sheets must adapt to larger text sizes.

Allow wrapping and alternative arrangements rather than unreadable compression.

## 20.6 Reduce Motion

Respect Reduce Motion for:

- Legend transitions.
- Awareness disclosure.
- Sheet presentation effects controlled by the app.
- Layer-change animation.

Do not animate map overlays merely to indicate refresh.

## 20.7 Contrast and Transparency

Preserve content readability under:

- Increase Contrast.
- Reduce Transparency.
- Light and dark appearance.
- Varied map backgrounds.

Essential information must remain understandable without depending on translucency.

---

# 21. Map Interaction Discipline

Map controls should remain predictable and narrowly focused.

## Native Behavior

Prefer established native SwiftUI and MapKit interaction.

Do not introduce custom gesture handling where native behavior already provides the intended interaction.

## Honest Affordances

Every visible control should communicate an actual action.

Examples:

- Layer selector opens layer choices.
- Active Alerts toggle controls displayed warning geometry.
- Compact legend trigger opens the full legend.
- Compact awareness disclosure opens the awareness summary.

Do not display decorative chevrons without actions.

## Control Density

Avoid adding separate floating controls for functionality that already exists in the layer menu or legend system.

Each new control increases competition with the geographic weather information.

Prefer refining existing controls over adding more.

---

# 22. Implementation Boundaries

The Map design uses an established SwiftUI and MapKit architecture.

Visual changes should remain within presentation ownership unless an explicit issue requires broader work.

## Investigation Starting Points

Useful entry points include:

- `Sources/Features/Map/MapScreenView.swift`
- `Sources/Features/Map/MapLegendView.swift`
- `Sources/Features/Map/Picker.swift`
- `Sources/Features/Map/MapCanvasView.swift`

These are orientation points, not an exhaustive file list or implementation boundary.

Follow actual dependencies before changing code.

## Preserve Existing Ownership

The current Map implementation separates:

- UI presentation.
- Selected-layer state.
- Render planning.
- Accepted scene state.
- Polygon mapping.
- Overlay rendering.

Do not collapse these responsibilities during a visual refinement.

## Renderer Changes

Changes involving hatching, polygon styles, or renderer behavior require particular care.

Inspect the current renderer and mapping contract before modifying presentation.

Do not adjust data geometry to solve a visual contrast issue.

## Shared Styling

Map surfaces may consume shared styles also used elsewhere in SkyAware.

Inspect consumers before changing global modifiers or color assets.

A Map-specific correction must not accidentally repaint Today, Settings, or unrelated detail screens.

## Scope Protection

Visual Map work does not authorize:

- New radar integration.
- New weather data sources.
- Additional Map layers.
- New recenter functionality.
- Changes to forecast geometry.
- Changes to warning targeting.
- New persistence ownership.
- Changes to accepted-state rules.
- Broad MapKit architecture rewrites.
- Unrelated visual redesign.

Use the smallest coherent change that satisfies the approved requirement.

---

# 23. Visual Validation

Map changes require visual review against actual rendered compositions.

A successful build is not proof of visual correctness.

## Representative Layers

Review affected behavior across:

- Categorical Severe Risk.
- Wind.
- Hail.
- Tornado.
- Mesoscale.
- Fire Risk.

A narrow change need not exercise every layer when the behavior is clearly isolated.

Shared Map changes require broader representative coverage.

## Representative Weather States

Include relevant examples of:

- Quiet weather.
- Elevated categorical risk.
- Severe-hazard probabilities.
- Conditional-intensity hatching.
- Active warning overlays.
- Multiple warning types.
- Confirmed empty data.
- Cached refreshing.
- Failed refresh with cache.
- Unavailable data.

## Geographic Conditions

Evaluate:

- Urban geography.
- Rural geography.
- Water and coastlines.
- Light and dark map regions.
- Overlapping polygons.
- Polygon boundaries near the user's location.
- Multiple zoom levels.

## Control and Legend States

Verify:

- Layer menu.
- Selected-layer title.
- Active Alerts toggle.
- Inline legend.
- Stacked legend.
- Compact legend trigger.
- Full legend sheet.
- Hatching explanation.
- Compact awareness disclosure.
- Awareness detail sheet.

## Appearance

Review meaningful states in light and dark appearance.

Check:

- Overlay visibility.
- Semantic color.
- Hatch contrast.
- Content legibility.
- Control separation.
- Native material behavior.

## Accessibility

Include relevant:

- Dynamic Type sizes.
- VoiceOver.
- Increase Contrast.
- Differentiate Without Color.
- Reduce Motion.
- Reduce Transparency.

## Camera and Interaction

Verify that:

- Refresh does not reset the user's camera.
- Layer changes preserve established camera behavior.
- Warning visibility changes do not alter unrelated layers.
- Map gestures remain usable.
- Floating controls do not obstruct excessive geography.

## Full Composition Review

Review the Map as a whole, not only isolated legend or control previews.

A readable legend can still be too large for the Map.

A beautiful overlay can still obscure important geography.

A correct control can still compete with the weather content.

Evaluate the complete experience.

Detailed review practices belong in [Visual Review](visual-review.md).

---

# 24. Map Anti-Patterns

Avoid:

- Radar added through visual redesign.
- New speculative Map layers.
- Automatic camera recentering during routine refresh.
- Geographic overlays hidden behind excessive floating UI.
- Multiple competing legends.
- A separate floating hatching panel.
- Probability and intensity represented as one concept.
- Raw CIG labels in primary UI.
- Hatching that scales dramatically with map zoom.
- Muddy dark-mode texture.
- Hatch patterns inconsistent with their legend swatches.
- Decorative color substitutions.
- Warning overlays shown while the visibility toggle is off.
- Empty legends presented as confirmed quiet weather when data is unavailable.
- Unnecessary map-control animations.
- Custom imitation Liquid Glass.
- Decorative shadows around native floating controls.
- Copied full-size Today cards floating over the Map.
- Permanent empty awareness panels.
- Fixed layouts that clip legends at accessibility text sizes.
- Changes to accepted weather geometry for visual convenience.
- Broad rendering rewrites for isolated styling defects.

---

# 25. Definition of Success

The Map design succeeds when:

1. The selected weather layer is immediately recognizable.

2. Geographic weather information remains visually dominant.

3. Risk colors preserve their established meaning.

4. Conditional-intensity hatching remains distinct from probability.

5. Legends explain the selected information clearly and quickly.

6. Active warning geometry remains recognizable and appropriately represented.

7. Floating controls remain native, compact, and predictable.

8. Awareness summaries provide context without obscuring the geographic Map.

9. Refresh activity preserves accepted information and established camera behavior.

10. Light and dark appearances
    remain coherent and readable.

11. Accessibility preserves
    meaningful geographic
    weather interpretation.

12. The Map feels like one
    integrated SkyAware experience,
    not a generic mapping tool
    covered in weather controls.

---

# Final Map Principle

**The Map exists to make severe-weather risk understandable in geographic context.**

Its value comes from the relationship between:

- The user's location.
- Established weather-risk geometry.
- Official warning areas.
- Accurate semantic colors.
- Conditional-intensity texture.
- Clear and compact interpretation.

The map should remain the dominant visual element.

Controls should help users explore it.

Legends should help users understand it.

And every displayed weather signal should retain its correct meaning.

**Preserve spatial clarity. Preserve weather semantics. Keep the Map focused on awareness.**
