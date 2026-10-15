---
title: SkyAware Widget Design
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - design
  - widgets
  - widgetkit
  - swiftui
---

# SkyAware Widget Design

## Purpose

This document defines the canonical visual and interaction design for SkyAware's WidgetKit experiences.

Widgets extend severe-weather awareness beyond the application, providing glanceable information on the Home Screen, Lock Screen, and other supported system presentation surfaces.

This document owns:

- Widget visual identity.
- Information hierarchy by widget family.
- Small, medium, and large widget composition.
- Lock Screen accessory presentation.
- Active-alert presentation and prioritization.
- Supporting risk summaries.
- Semantic color and iconography.
- Widget backgrounds and system rendering modes.
- Layout adaptation within fixed bounds.
- Accessibility and complete weather meaning.
- Widget-specific state presentation.
- Visual validation and regression prevention.

This document does not redefine meteorological interpretation, alert selection, snapshot generation, timeline scheduling, or canonical state ownership.

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

This document owns their application to WidgetKit.

---

# 1. Design Intent

SkyAware widgets provide immediate severe-weather awareness without requiring users to open the app.

They should answer questions such as:

- What is my current storm risk?
- Is a meaningful severe threat present?
- Are official alerts active locally?
- What weather information deserves my attention?
- Is the displayed information available and trustworthy?

The amount of information depends on widget size.

The underlying weather meaning does not.

## Primary Principle

**Glanceability is more valuable than information density.**

A widget succeeds when the most important information can be understood quickly and accurately.

It does not succeed merely because it displays the greatest number of measurements.

## Design Character

Widgets should feel:

- Calm.
- Precise.
- Focused.
- Recognizably SkyAware.
- Native to WidgetKit.
- Carefully composed.
- Trustworthy in every state.

They should not resemble:

- Miniature dashboard applications.
- Decorative weather posters.
- Collections of tiny unrelated cards.
- Emergency siren displays.
- Generic system-status indicators.

## Platform Identity

Widgets belong to SkyAware's visual family.

They do not need to reproduce the exact geometry, materials, or layouts of the Today screen.

Preserve shared:

- Weather semantics.
- Category names.
- Recognizable symbols.
- Risk color meaning.
- Information hierarchy.
- Typography character.
- Visual restraint.

Allow WidgetKit to determine the appropriate outer presentation and rendering behavior.

---

# 2. Supported Widget Families

The established widget offering includes:

## Home Screen

**Storm Risk**

Small widget presenting categorical convective storm-risk awareness.

**Severe Risk**

Small widget presenting the most relevant supported severe-hazard awareness.

**Combined Awareness**

Medium and large widget presentations combining local alerts and supporting weather-risk information.

## Lock Screen

**Storm Risk**

Supported accessory presentations:

- Circular.
- Rectangular.
- Inline.

**Severe Risk**

Supported accessory presentations:

- Circular.
- Rectangular.
- Inline.

## Family Responsibilities

Each widget family has a specific information responsibility.

Do not create identical layouts at different sizes and merely scale them.

A larger widget should provide additional meaningful context.

A smaller widget should preserve the essential meaning of its specific awareness concept.

---

# 3. Information Hierarchy by Size

Widget hierarchy changes according to available space.

## Small

One primary risk concept.

The risk category and current accepted state must be immediately clear.

Supporting explanation is optional when space is insufficient.

## Medium

A compact local-awareness summary.

Prioritize:

1. SkyAware identity and location context.
2. The most relevant selected local alert, or appropriately scoped no-alert state.
3. Limited Storm, Severe, and Fire context.

The primary awareness information must remain stronger than the supporting risk summaries.

## Large

A more complete local-alert awareness presentation.

Prioritize:

1. SkyAware identity and location.
2. Active-alert count and awareness heading.
3. Relevant active alert rows.
4. Overflow indication when necessary.
5. Compact Storm, Severe, and Fire summary.

Active alerts take precedence over supporting risk information.

## Lock Screen

One compact weather-awareness statement appropriate to the accessory family.

Preserve recognizable meaning without requiring the same visual structure as Home Screen widgets.

## General Rule

**Increasing widget size should add context, not visual complexity for its own sake.**

---

# 4. Widget Surface System

WidgetKit owns the widget's external presentation.

This includes system-controlled:

- Outer shape.
- Placement.
- Rendering context.
- Background treatment.
- Supported family dimensions.
- Certain margin behaviors.
- Tinted and accessory rendering modes.

## 4.1 One Outer Content Surface

Home Screen widgets use a single established content background.

Ordinary supporting information should remain visually integrated into that surface.

Avoid adding a large application-style card inside the WidgetKit container.

The widget itself is already a bounded presentation surface.

## 4.2 Light Appearance

The established full-color light widget background is:

`#FCFCFD`

This is the same near-white content family used for ordinary SkyAware weather surfaces.

Do not use the application's `#F5F6F7` canvas as a second background inside the widget.

The widget's neutral surface should feel:

- Clean.
- Bright.
- Calm.
- Stable.
- Carefully integrated.

Avoid:

- Lavender or icy backgrounds.
- Alternating gray content slabs.
- Bright white highlight rims.
- Strong inner shadows.
- Unnecessary nested cards.

## 4.3 Dark Appearance

Preserve the current approved dark WidgetKit surface treatment.

The established dark appearance is deep navy and atmospheric.

It should feel consistent with SkyAware's dark-mode identity.

Avoid:

- Muddy gray backgrounds.
- Excessive black gradients.
- Multiple unrelated dark surfaces.
- Glowing boundaries.
- Large decorative shadow effects.

Do not derive dark widget styling by simply inverting light-mode values.

## 4.4 Background Ownership

Use the established WidgetKit container-background boundary.

Prefer the existing:

`containerBackground(for: .widget)`

and shared widget surface styling.

Do not recreate the outer widget shape with another rounded rectangle.

Do not introduce a separate widget-background framework.

## 4.5 Content Margins

Respect the established WidgetKit content-margin strategy for each family.

If the widget disables default content margins, its own internal padding must provide appropriate readability and breathing room.

Do not apply additional default padding blindly.

Conversely, do not assume all widget families have identical content-margin behavior.

Review the actual rendered widget.

---

# 5. Native WidgetKit Materials

WidgetKit is not an extension of the application's Liquid Glass content system.

## Native Presentation

Let the system provide:

- External shape.
- Appropriate material integration.
- Rendering transformations.
- Lock Screen treatment.
- Tinted widget presentation.
- Supported accessibility behavior.

## Avoid Simulated Glass

Do not create:

- App-style floating cards.
- Custom Liquid Glass imitations.
- Translucent inner containers for decorative effect.
- Strong glowing outlines.
- Artificial elevation around the entire widget.

Stable weather information should remain readable.

## Weather Content Versus Controls

Home Screen widgets are glanceable information surfaces.

They do not need to reproduce the full application's floating navigation controls.

Do not introduce decorative buttons or chevrons merely to imitate Today.

Interaction should follow actual WidgetKit capabilities and established widget destinations.

---

# 6. Semantic Color

Widget colors must retain SkyAware's established weather meanings.

## 6.1 Shared Semantic Identity

Preserve recognizable colors for:

- Categorical storm risk.
- Tornado.
- Hail.
- Wind.
- Fire weather.
- Active alerts.
- Quiet weather.

Use the established widget semantic mapping.

Do not independently invent colors for the same risk levels.

## 6.2 Quiet Weather

Quiet states use restrained semantic green.

They should feel:

- Calm.
- Intentional.
- Recognizable.
- Appropriately reassuring.

Avoid making quiet weather look unavailable, disabled, or visually unfinished.

However, green represents a scoped weather assessment.

It does not guarantee safety.

## 6.3 Elevated Risk

Elevated states may use stronger semantic accents.

Increase emphasis in proportion to actual weather meaning.

Do not make every elevated condition look like an official warning.

## 6.4 Active Alerts

Official alert information may receive stronger emphasis.

The established alert styling uses hazard-specific:

- Color.
- Symbol.
- Leading rail.
- Restrained background tint.

Warnings can receive stronger visual emphasis than watches and supporting risk summaries.

Do not add decorative urgency.

## 6.5 Unavailable Information

Unavailable information should normally use neutral presentation and clear explanatory text.

Do not substitute quiet green for missing risk information.

## 6.6 Color Is Not Enough

All essential risk information must remain available through:

- Text.
- Accessible labels.
- Symbols where appropriate.
- Clear state wording.

A user should not need to identify a specific color to understand the widget's meaning.

---

# 7. Typography and Information Density

Typography is the primary carrier of widget hierarchy.

## Primary Values

Primary weather values should be immediately readable.

Use strong but restrained font weight.

Do not increase decorative icon size at the expense of the primary value.

## Category Labels

Use concise established category names.

Examples:

- Storm Risk.
- Severe Risk.
- Fire Risk.

Do not invent shorter ambiguous names merely to save a few points of horizontal space.

## Supporting Information

Supporting text should be visually subordinate.

Use adaptive secondary foreground styling with sufficient contrast.

Do not reduce secondary text opacity repeatedly.

## Numeric Information

Use appropriate numeric formatting.

Monospaced digits may be useful for values that benefit from alignment.

Avoid unnecessary numerical detail when a plain-language risk category is more useful.

## Content Priority

When space is constrained, preserve content in this order:

1. Essential weather or alert meaning.
2. Necessary geographic context.
3. Important lifecycle information.
4. Supporting risk context.
5. Optional explanatory text.
6. Decorative elements.

This is a general priority.

The specific widget family may establish a more precise hierarchy.

## Text Compression

Do not make indiscriminate font-size reductions.

Prefer:

- Shorter truthful copy.
- Adaptive layout.
- Reduced decorative spacing.
- Fewer optional details.
- Natural word wrapping.
- Deliberate family-specific composition.

Essential meaning must remain intact.

---

# 8. Small Storm Risk Widget

The small Storm Risk widget communicates one categorical convective-risk assessment.

## Primary Content

The established composition includes:

- Storm Risk identity.
- Semantic risk symbol.
- Primary accepted risk label.
- Optional concise explanation.
- Narrow semantic accent.

The category and assessment must be immediately understandable.

## Visual Hierarchy

Prioritize:

1. Storm Risk identity.
2. Primary risk assessment.
3. Relevant symbol.
4. Optional supporting explanation.

Do not allow the symbol to dominate the assessment.

## Semantic Treatment

Use the established categorical risk coloring.

Quiet states retain restrained green.

Elevated states use appropriate category colors.

Do not introduce warning-like presentation for ordinary categorical risk.

## Text Wrapping

Preserve complete weather terms.

Prefer wrapping between meaningful words rather than clipping part of a risk description.

Do not abbreviate a category into something ambiguous.

## Adaptive Content

Supporting explanation may be omitted when necessary to preserve the primary state.

Do not omit the actual risk category or label.

The small widget should remain readable within its fixed WidgetKit bounds.

---

# 9. Small Severe Risk Widget

The small Severe Risk widget communicates the most relevant supported local severe threat.

## Primary Content

The established composition includes:

- Severe Risk identity.
- Hazard symbol.
- Primary threat label.
- Optional supporting explanation.
- Narrow semantic accent.

## Hazard Identity

Preserve the established severe-hazard distinctions:

- Tornado.
- Hail.
- Wind.
- Quiet severe state.

The displayed symbol and semantic color must agree with the selected hazard.

## Quiet State

A quiet severe-risk presentation describes the accepted severe-risk state.

It does not claim that all weather is safe.

## Content Scope

The small widget is not a complete severe-weather analysis surface.

Do not add multiple hazard rows or detailed conditional-intensity explanations.

Users can open SkyAware for additional context.

## Text Integrity

Preserve the complete primary threat meaning.

Optional supporting text may be reduced or omitted when necessary.

Do not replace a meaningful hazard name with a generic colored icon.

---

# 10. Medium Combined Widget

The medium widget provides a compact overview of local weather awareness.

Its purpose is to combine the most relevant alert information with limited supporting risk context.

## 10.1 Composition

The established layout contains:

1. SkyAware identity and location.
2. Primary local-awareness information.
3. Subtle separator.
4. Compact Storm, Severe, and Fire summaries.

These regions should remain visually distinct.

## 10.2 Identity and Location

The top context line includes:

- SkyAware.
- Location summary.

Use concise typography.

Do not make the brand name more prominent than the important weather information.

The location should remain readable and appropriately scoped.

## 10.3 Primary Awareness

When relevant local alerts exist, the selected alert receives primary emphasis.

It may include:

- Alert type or event name.
- Semantic symbol.
- Supporting lifecycle information.
- Additional-alert count when applicable.

Do not attempt to render the full alert list inside the medium widget.

## 10.4 No Active Alerts

When the accepted alert state confirms no active local alerts, communicate that fact plainly.

The absence of local alerts must not imply the absence of all severe-weather risk.

Storm, Severe, and Fire remain available as supporting context.

## 10.5 Risk Summary

The lower summary includes:

- Storm Risk.
- Severe Risk.
- Fire Risk.

Use compact semantic accents and concise values.

Maintain a clear difference between the primary alert and supporting assessment.

## 10.6 Separator

Use a subtle divider or spacing relationship between primary awareness and supporting risk context.

Do not turn the separator into a decorative feature.

## 10.7 Accessibility Layout

When ordinary three-column presentation cannot remain readable, adapt the content to the available space.

Preserve essential meaning.

Do not require an inaccessible miniature version of the regular layout.

## 10.8 Overflow

Additional-alert information must remain accurate.

If the widget displays one selected alert and indicates additional alerts, the count must match the accepted snapshot.

Do not allow overflow text to collide with the primary alert or risk footer.

---

# 11. Large Local Awareness Widget

The large widget provides the most complete glanceable local-alert presentation available within WidgetKit.

It is not a miniature Local Alerts detail screen.

## Primary Purpose

Communicate:

- Whether local alerts exist.
- How many are active.
- Which alerts deserve attention.
- Whether additional alerts exist.
- Supporting Storm, Severe, and Fire risk context.

## Established Composition

The large widget contains five logical regions:

1. Identity and location.
2. Awareness heading.
3. Active alert content.
4. Overflow indicator, when applicable.
5. Supporting risk footer.

The regions must remain visually distinct.

## Information Priority

Active alert information has priority over supporting risk summaries.

Within the alert section, preserve the established alert ordering and primary-alert emphasis.

The risk footer supports the alert information.

It must not compete with or obscure it.

---

# 12. Large Widget Identity and Heading

## Identity

The top row includes:

- SkyAware.
- Location context.

Keep this compact.

The location must remain useful without consuming excessive vertical space.

## Awareness Heading

The established heading communicates the active alert count.

Examples:

- LOCAL AWARENESS
- 1 ACTIVE ALERT
- 3 ACTIVE ALERTS

The displayed count must reflect accepted widget snapshot information.

Do not derive a conflicting count from only the visible subset of alert rows.

## Visual Hierarchy

The heading establishes the purpose of the widget.

The active alert rows carry the actionable detail.

Avoid making the heading so oversized that the alerts lose necessary space.

## Quiet Presentation

When no applicable active alerts are confirmed, use the established local-awareness heading and concise quiet-state content.

Do not leave a large visually empty alert region without meaningful context.

---

# 13. Large Widget Active Alert Rows

Active alert rows are the primary content of the large widget when alerts exist.

## Row Structure

Each row may include:

- Narrow semantic rail.
- Relevant hazard symbol.
- Alert event name.
- Lifecycle or expiration information.
- Restrained semantic background tint.

The first visible alert receives stronger hierarchy.

Subsequent alerts remain clearly identifiable.

## Alert Ordering

Preserve accepted alert selection and ordering.

Do not reorder alerts based on which event name fits most easily.

Presentation must consume the established alert snapshot rather than reimplementing selection logic.

## Primary Alert

The first visible alert may receive:

- Stronger title emphasis.
- Slightly greater height.
- More readable supporting timing.
- Stronger semantic treatment.

It must not become a disproportionate decorative hero.

## Supporting Alerts

Additional visible alerts use a more compact treatment.

Preserve:

- Event identity.
- Meaningful lifecycle context.
- Readable text.
- Semantic distinction.

Do not shrink supporting alerts until their event names become unrecognizable.

## Event Timing

Expiration and lifecycle information are meaningful alert content.

They are not the same as widget-refresh timestamps.

Relevant event times may be displayed when supported by the alert.

Do not introduce decorative widget freshness timestamps to fill the layout.

---

# 14. Large Widget Alert Overflow

A large widget cannot display every possible active alert.

The established behavior shows a bounded visible subset and indicates additional active alerts when necessary.

## Overflow Meaning

The overflow indicator communicates the number of additional alerts not visible in the widget.

Example:

"+2 more active alerts"

The count must be derived from accepted snapshot information and the actual visible subset.

Do not silently drop additional alerts without communicating that more information exists.

## Visual Treatment

The overflow indicator should be:

- Readable.
- Concise.
- Visually subordinate to the actual alert rows.
- Clearly associated with the alert section.

It should not resemble another alert row.

## Layout Ownership

The overflow indicator belongs to the alert content region.

It must receive sufficient space for its complete text.

It must not be positioned under the risk footer or overlapped by decorative elements.

## Alert Count Variation

Validate the widget with:

- Zero alerts.
- One alert.
- Two alerts.
- Three alerts.
- More alerts than can be visibly displayed.

Do not assume the layout that works for one alert will work for five.

---

# 15. Large Widget Supporting Risk Footer

The supporting risk footer provides compact context beneath the alert section.

It contains:

- Storm Risk.
- Severe Risk.
- Fire Risk.

## 15.1 Hierarchy

The footer is supporting information.

It must remain visually subordinate to active alerts.

It should be recognizable without appearing to be a second main content section.

## 15.2 Regular Layout

The approved regular-size footer uses three compact risk summaries.

Each includes:

- Narrow semantic rail.
- Category label.
- Primary risk value.

Maintain consistent alignment and spacing across columns.

## 15.3 Compactness

The footer should occupy only the space necessary to communicate its values.

Prefer:

- Restrained vertical padding.
- Compact label-to-value spacing.
- Clear but narrow semantic rails.
- Consistent column relationships.
- One subtle separator.

Avoid:

- Excessively tall colored rails.
- Large decorative backgrounds.
- Independent rounded cards around every risk column.
- Excessive footer padding.
- Oversized labels.
- Redundant icons.

## 15.4 Separator

A restrained divider separates the risk footer from the alert information above it.

The divider should clarify hierarchy without becoming a prominent visual feature.

## 15.5 Adaptive Arrangement

At larger supported text sizes, the footer may adapt to a more compact or stacked presentation where necessary.

Preserve all three risk categories when the accepted design requires them.

Do not overlap or obscure essential alert information to maintain three columns.

## 15.6 Semantic Accuracy

Each risk column uses the correct accepted risk value and semantic color.

An unavailable risk must not receive a confirmed quiet-state label.

A placeholder must remain visually distinguishable from an accepted low-risk state.

---

# 16. Large Widget Layout Integrity

The large widget has a strict content-fit requirement.

**No alert text, overflow indicator, risk label, semantic rail, or decorative element may overlap another content region.**

This is a non-negotiable visual correctness rule.

## 16.1 Distinct Layout Regions

The following must occupy separate layout regions:

- Alert rows.
- Alert overflow indicator.
- Risk footer.

The footer must begin after the alert content, including any overflow text.

## 16.2 Do Not Mask Collisions

Do not solve layout defects using:

- Arbitrary negative offsets.
- Fixed positional corrections.
- Clipping that conceals text.
- Shrinking all typography.
- Hidden overflow indicators.
- Overlapping background elements.
- Unbounded spacers that assume ideal content height.

These techniques can make one screenshot look correct while leaving other states broken.

## 16.3 Content Budget

WidgetKit provides fixed external bounds.

The layout must allocate those bounds according to information priority.

When content is dense:

1. Preserve critical alert meaning.
2. Preserve a truthful overflow count.
3. Reduce unnecessary decoration.
4. Compress supporting spacing.
5. Use established adaptive layouts.
6. Reduce optional information according to a deliberate policy.

Do not sacrifice alert readability merely to preserve footer dimensions.

## 16.4 Footer Containment

The risk footer's semantic rails must remain entirely within its own region.

They must not extend into:

- Overflow text.
- Alert rows.
- The divider's preceding content area.

The footer should remain fully contained within WidgetKit's visible bounds.

## 16.5 Long Content

Alert titles may contain multiple words or unexpectedly long names.

Location names may also require additional room.

Layout must accommodate realistic content variation.

Do not design solely around short preview strings.

## 16.6 Accessibility

Larger text settings can increase the height of alert and overflow content.

Review the actual rendered widget at supported larger text sizes.

Do not assume that a Dynamic Type cap alone guarantees nonoverlapping content.

## 16.7 Acceptance Requirement

The large widget is not visually complete until its alert and footer regions remain readable, separated, and contained across representative content-density states.

---

# 17. Quiet Widget States

Quiet widgets should feel deliberate and reassuring through clarity.

They should not feel empty or disabled.

## Scoped Language

Use wording tied to the accepted evidence.

Examples:

- No local alerts.
- No active local alerts.
- No active severe threats.
- No Severe Storm Risk.

These phrases are not interchangeable.

Use only wording justified by the corresponding accepted data.

## Avoid Broad Safety Claims

Do not use:

- All Clear.
- Completely Safe.
- Nothing to Worry About.
- Your area is safe.
- Your area is clear.

These statements imply more certainty than SkyAware can establish.

## Visual Treatment

Quiet states may use restrained semantic green.

Avoid:

- Decorative full-surface green flooding.
- Glowing checkmarks.
- Large empty illustrations.
- Disabled-looking gray text.

The result should feel complete and trustworthy.

## Alert Versus Risk State

No active local alerts does not imply that the storm or severe-risk forecast is quiet.

The widget must preserve these distinctions.

---

# 18. Active Warning States

An active warning can represent the most important information in a widget.

## Visual Priority

Use appropriate:

- Hazard-specific symbol.
- Semantic color.
- Stronger title hierarchy.
- Concise lifecycle information.
- Clear alert count.

## Restraint

Urgency must remain proportional to the actual alert meaning.

Avoid:

- Flashing surfaces.
- Pulsing warnings.
- Strong background glow.
- Oversized emergency symbols.
- Decorative red flooding.
- Additional alarm-like chrome.

## Readability

A warning title should remain clearly recognizable.

The supporting lifecycle information should not compete with the event name.

Do not sacrifice meaningful warning text for decorative weather imagery.

## Multiple Warnings

Preserve established alert ordering and primary-alert selection.

The widget should make the most relevant warning recognizable while accurately indicating additional alerts.

---

# 19. Stale, Offline, and Unavailable States

Widgets consume accepted weather information and its availability context.

They must preserve the same trust principles as the full application.

## 19.1 Available Accepted Data

When valid accepted information exists, display it according to established rules.

Do not replace it with a generic placeholder merely because an update is scheduled.

## 19.2 Stale Information

When previously accepted information remains usable but cannot currently be refreshed, preserve its applicable meaning.

Use restrained stale or degraded presentation where appropriate.

Do not replace retained risk with a quiet state.

## 19.3 Unavailable Information

When the required accepted information does not exist or cannot be trusted, communicate unavailability.

The established unavailable presentation uses clear neutral messaging.

Do not invent a risk level.

## 19.4 Confirmed Empty

A confirmed empty alert state is different from an unavailable alert feed.

Show no-active-alert language only when supported.

## 19.5 Location Context

If location is unavailable, do not imply that a hyper-local risk assessment is current and applicable.

Communicate the limitation appropriately.

## 19.6 Freshness Timestamps

Do not display decorative "as of" or last-update timestamps in widgets.

Do not include those timestamps in accessible summary labels.

Freshness remains internal to widget state and presentation decisions.

Relevant official alert issue or expiration times may still be displayed.

These serve a different information purpose.

## 19.7 Timeline Behavior

WidgetKit updates are not guaranteed to occur at a precise instant.

Do not communicate guaranteed real-time refresh or delivery.

The visual contract must remain truthful when the system delays updates.

---

# 20. Lock Screen Widgets

Lock Screen widgets are highly constrained accessory experiences.

They should feel native to WidgetKit rather than attempting to reproduce Home Screen widget styling.

## 20.1 Circular

The circular presentation uses a compact symbol or similarly concise awareness indication.

The meaning must remain available through accessibility text.

Do not force explanatory paragraphs into the circular bounds.

## 20.2 Rectangular

The rectangular presentation may combine:

- Primary risk phrase.
- Supporting category label.
- Relevant symbol.

Preserve readable weather meaning.

Avoid decorative background containers.

## 20.3 Inline

The inline presentation uses a short, complete weather-awareness phrase.

Examples of useful phrase structures:

- Thunderstorm risk.
- Tornado possible.
- Hail possible.
- Damaging wind possible.
- No active severe threats.

The actual wording must follow accepted state.

## 20.4 System Rendering

Respect system-controlled Lock Screen styling.

Do not force full-color Home Screen palettes into accessory widgets.

Use appropriate WidgetKit accent behavior.

## 20.5 Quiet State

Quiet accessory widgets should communicate appropriately scoped weather meaning.

Do not use a green checkmark alone as proof of universal safety.

## 20.6 Unavailable State

Use a recognizable, concise unavailable state.

Do not display a stale risk value as current without appropriate state handling.

---

# 21. Widget Rendering Modes

WidgetKit may render widgets differently depending on platform and user configuration.

The design must remain understandable across supported rendering modes.

## Full Color

Use the established light or dark base and semantic treatments.

Preserve readable foreground contrast.

## Accented and Tinted

The system may modify or constrain colors.

Do not assume all semantic hues will remain unchanged.

Weather meaning must remain understandable through text and symbols.

Avoid forcing the ordinary full-color background into system-controlled tinted presentation.

## Vibrant Rendering

Preserve content hierarchy when foreground and background colors are transformed by the system.

Do not depend on subtle transparent fills to distinguish critical information.

## Background Removal

When WidgetKit removes the container background, content must remain readable and meaningful.

Do not add a replacement opaque outer card merely to restore app styling.

## Rendering Principle

**A widget's meaning must survive the system's visual transformations.**

---

# 22. Accessibility

Widget accessibility is part of visual and meteorological correctness.

## 22.1 VoiceOver

Provide complete accessible summaries.

Relevant information may include:

- SkyAware identity.
- Location.
- Alert identity.
- Additional-alert count.
- Storm Risk.
- Severe Risk.
- Fire Risk.
- Availability limitations.

Avoid redundant announcements from decorative icons and semantic rails.

## 22.2 Alert Context

Alert summaries should include useful lifecycle information when available.

Overflow counts must remain accessible.

Do not rely on the visible layout alone to communicate that additional alerts exist.

## 22.3 Complete Meaning

A compact visible phrase must not broaden, weaken, or contradict its accepted weather meaning.

Accessible text may provide additional context.

It must not introduce unsupported certainty.

## 22.4 Dynamic Type

WidgetKit imposes fixed spatial constraints.

Adapt typography and layout deliberately.

Do not assume every widget family can reproduce the same text sizes as the app.

Where necessary, prioritize essential content while preserving accessible alternatives.

## 22.5 Contrast

Review meaningful text in light and dark full-color presentation.

Also inspect supported accented and vibrant rendering modes.

## 22.6 Differentiate Without Color

Weather meaning must not depend exclusively on semantic tint.

Preserve text labels and recognizable symbols.

## 22.7 Reduce Motion

Widgets should not rely on continuous animation to communicate state.

Avoid decorative motion and refresh effects entirely.

---

# 23. Widget Interaction and Navigation

Widgets should provide predictable navigation into the application.

## Established Destinations

Preserve the existing widget destination and deep-link behavior.

Do not change widget routing merely to simplify presentation.

## Interaction Boundaries

Do not display decorative buttons or chevrons that imply unsupported independent actions.

A widget is not a miniature navigation interface.

## Alert Context

When a widget presents active alerts, its destination should remain consistent with the established snapshot routing contract.

Do not invent per-row tap destinations without an explicit product requirement.

## Native Behavior

Use WidgetKit-supported navigation and interaction.

Avoid custom gesture implementations that simulate application navigation controls.

---

# 24. Cross-Surface Consistency

Widgets and Today share SkyAware's weather identity.

They do not need to share identical layouts.

## Preserve Across Surfaces

- Risk category names.
- Weather interpretation.
- Semantic color meaning.
- Recognizable symbols.
- Scoped quiet-state language.
- Appropriate warning emphasis.
- Accepted-state truthfulness.

## Adapt by Platform

- Widget outer backgrounds.
- Container margins.
- Supported family layouts.
- Text density.
- Rendering modes.
- Accessory presentation.
- Interaction behavior.

## Avoid Literal Copies

Do not reproduce:

- Today's four-card stack inside a medium widget.
- Today's full hero geometry inside a small widget.
- Liquid Glass navigation inside Home Screen widgets.
- App-style cards around every Lock Screen value.

Consistency means recognizable design relationships.

It does not mean identical components.

---

# 25. Implementation Boundaries

Widget presentation is implemented through the existing WidgetKit extension and supporting snapshot contracts.

## Investigation Starting Points

Relevant presentation ownership includes:

- `WidgetsExtension/SkyAwareWidgetsBundle.swift`
- `WidgetsExtension/WidgetRenderingComponents.swift`
- `WidgetsExtension/WidgetCombinedComponents.swift`
- `WidgetsExtension/WidgetLargeAwarenessComponents.swift`
- `WidgetsExtension/WidgetAlertComponents.swift`
- `WidgetsExtension/WidgetRenderingStyle.swift`

Relevant preview and state presentation files also exist within `WidgetsExtension`.

These are investigation entry points, not an exhaustive file list.

Follow actual dependencies before changing code.

## Existing Ownership

Preserve the separation between:

- Widget snapshot generation.
- Accepted weather state.
- Timeline provisioning.
- Risk and alert selection.
- Widget rendering.
- Widget navigation.

Visual work should not reimplement domain logic.

## Styling Changes

Before changing a shared widget style, identify all family consumers.

A change that improves the large widget must not accidentally degrade the small or medium families.

## Avoid New Infrastructure

Do not create:

- Another widget theme system.
- Duplicate semantic mappings.
- A new snapshot state owner.
- Custom WidgetKit layout infrastructure without need.
- An additional rendering abstraction for one defect.

Prefer focused fixes within existing presentation components.

## Scope Protection

Visual widget work does not authorize:

- New weather products.
- Changes to alert targeting.
- New persistence fields.
- New timeline scheduling policies.
- Changes to deep links.
- Additional widget families.
- Unrelated application redesign.
- New notification behavior.

Resolve broader dependencies as separate product or engineering decisions.

---

# 26. Visual Validation

Widget validation requires actual rendered compositions.

A successful build is not proof of layout correctness.

## 26.1 Small Widgets

Review:

- Quiet storm risk.
- Elevated categorical risk.
- Highest categorical risk.
- Wind, hail, and tornado states.
- Long risk labels.
- Unavailable information.
- Supporting text omitted because of limited space.

Verify:

- Complete primary meaning.
- Recognizable semantic color.
- Readable typography.
- No clipped text.
- No decorative crowding.

## 26.2 Medium Widgets

Review:

- No active alerts.
- One active alert.
- Multiple active alerts.
- Long alert title.
- Additional-alert count.
- Elevated supporting risks.
- Unavailable risk context.
- Stale accepted information.

Verify:

- Clear primary hierarchy.
- Correct location context.
- Compact supporting values.
- Accurate overflow meaning.
- No text collisions.

## 26.3 Large Widgets

Review:

- Zero active alerts.
- One active alert.
- Two active alerts.
- Three active alerts.
- Five or more active alerts.
- Multiple alert types.
- Long warning titles.
- Overflow indicator.
- Long location name.
- Elevated Storm Risk.
- Tornado, hail, and wind risk.
- Elevated Fire Risk.
- Unavailable supporting risk.
- Stale accepted information.

Verify:

- Correct active-alert count.
- Correct primary-alert selection.
- Readable alert rows.
- Complete overflow indicator.
- Footer below all alert content.
- Semantic rails contained within their own sections.
- All three footer categories appropriately represented.
- No overlapping content.
- No clipping.
- No content outside WidgetKit bounds.

The large-widget overlap scenario is a required regression case for future layout changes.

## 26.4 Lock Screen Widgets

Review:

- Circular.
- Rectangular.
- Inline.
- Quiet.
- Elevated risk.
- Unavailable.
- System-controlled rendering modes.

Verify that compact phrases remain meaningful.

## 26.5 Appearance Coverage

Review affected Home Screen widgets in:

- Light appearance.
- Dark appearance.

Include relevant tinted, accented, vibrant, or background-removed modes where supported.

Do not assume full-color previews establish system rendering quality.

## 26.6 Accessibility Coverage

Include:

- VoiceOver.
- Larger text settings.
- Long localized-style strings.
- Differentiate Without Color.
- Relevant contrast settings.

Focus especially on content-density boundaries.

## 26.7 Real Device Validation

Widget previews are useful but not always sufficient.

For meaningful layout changes, inspect widgets installed on a supported device or simulator.

Actual rendered bounds, text behavior, and system background treatment matter more than isolated component previews.

## 26.8 Proportional Validation

A narrow change need not retest every widget family when ownership is isolated.

Shared styling or layout changes require broader representative coverage.

Do not build an oversized snapshot-testing framework without demonstrated value.

Use existing deterministic preview fixtures first.

---

# 27. Widget Anti-Patterns

Avoid:

- Treating widgets as miniature copies of the Today screen.
- Excessive nested cards.
- Artificial Liquid Glass.
- Decorative full-surface risk gradients.
- Unnecessary shadows.
- Glowing warning borders.
- Overly large weather icons.
- Ambiguous abbreviated risk labels.
- Incomplete safety wording.
- Broad "All Clear" claims.
- Treating unavailable data as quiet weather.
- Decorative freshness timestamps.
- Overcrowded medium layouts.
- Showing every possible metric because space exists.
- Alert rows competing with the risk footer.
- Overlapping overflow indicators.
- Rails extending outside their content regions.
- Layout fixes based on arbitrary offsets.
- Clipping essential text.
- Excessive font shrinking.
- Redundant navigation controls.
- Inconsistent semantic colors.
- Unsupported assumptions about tinted rendering.
- Global styling changes for an isolated family defect.
- Widget visual updates that change domain behavior.

---

# 28. Definition of Success

SkyAware widgets succeed when:

1. The most important available weather information is immediately understandable.

2. Each family has a clear information responsibility.

3. Small widgets communicate one complete awareness concept.

4. Medium widgets combine relevant local alerts with concise risk context.

5. Large widgets prioritize active alerts and present supporting risks without competing for space.

6. Alert counts and overflow indicators remain accurate.

7. All content stays within WidgetKit's supplied bounds.

8. Quiet states feel calm without overstating safety.

9. Elevated conditions receive appropriate semantic emphasis.

10. Unavailable and stale information remain truthful.

11. Light, dark, and supported system rendering modes preserve essential meaning.

12. Lock Screen widgets remain compact and native.

13. Accessibility provides meaningful weather context.

14. The entire widget family feels recognizably SkyAware.

---

# Final Widget Principle

**A SkyAware widget exists to make severe-weather awareness available at a glance.**

Its value comes from:

- Accurate weather meaning.
- Appropriate local relevance.
- Clear information priority.
- Purposeful semantic color.
- Complete and concise wording.
- Careful use of limited space.
- Faithful WidgetKit behavior.

The widget should never require the user to untangle its layout before understanding the weather.

When space is limited, preserve meaning before decoration.

When alerts are active, give them the attention they deserve.

When weather is quiet, communicate that calmly and precisely.

When information is unavailable, say so.

**Make every glance useful. Make every weather statement trustworthy. Make every pixel earn its place.**
