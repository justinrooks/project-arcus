---
title: SkyAware Design Foundations
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - design
  - foundations
  - swiftui
---

# SkyAware Design Foundations

## Purpose

This document defines SkyAware's shared visual and interaction foundations across iOS, watchOS, and WidgetKit where applicable.

It establishes the rules for:

- Visual hierarchy.
- Color and semantic meaning.
- Light and dark appearances.
- Content surfaces and materials.
- Typography and contrast.
- Shape, spacing, and density.
- Iconography.
- Navigation and interaction affordances.
- Motion and feedback.
- Native SwiftUI presentation.
- Visual consistency across product surfaces.

These foundations apply unless a more specific canonical surface document establishes an intentional exception.

Related documentation:

- [Design System](README.md)
- [North Star](../product/north-star.md)
- [Brand and Voice](../brand/brand-and-voice.md)
- [Today](today.md)
- [Map](map.md)
- [Widgets](widgets.md)
- [States and Accessibility](states-accessibility.md)
- [Visual Review](visual-review.md)

This document defines the shared language.

Individual surface specifications define how that language is applied.

---

# 1. Foundational Philosophy

SkyAware combines a restrained, Apple-native foundation with a distinctive semantic weather identity.

The interface should feel:

- Calm.
- Precise.
- Readable.
- Trustworthy.
- Premium.
- Deliberately crafted.
- Recognizably SkyAware.

## Calm Does Not Mean Colorless

Neutral surfaces establish calm.

Typography and spacing establish hierarchy.

Semantic weather colors communicate risk, hazards, relative importance, and meaningful state.

Native interactions provide familiarity and predictability.

Avoid excessive decoration, but do not remove so much color or emphasis that the interface loses its identity.

An interface can be visually quiet without being visually anonymous.

## Information Before Decoration

Every visual element should contribute to at least one of the following:

- Communicating weather meaning.
- Establishing information hierarchy.
- Improving readability.
- Identifying an interaction.
- Supporting navigation.
- Distinguishing a meaningful state.
- Reinforcing product identity without competing with information.

If an effect contributes none of these, remove it.

## Premium Means Precision

Premium quality comes from:

- Consistent geometry.
- Careful alignment.
- Deliberate spacing.
- Readable typography.
- Smooth color relationships.
- Predictable interaction.
- Stable content.
- Accessibility.
- Coherent light and dark appearances.
- Thoughtful handling of unusual states.

Additional shadows, borders, materials, gradients, or animations do not automatically improve quality.

Prefer fewer elements, executed exceptionally well.

---

# 2. Visual Hierarchy

SkyAware uses three conceptual visual layers.

## Level 0: App Canvas

The canvas is the quiet foundation beneath the content.

It should:

- Provide visual continuity.
- Recede behind meaningful weather information.
- Avoid unnecessary decorative texture.
- Adapt independently to light and dark appearance.

The canvas should not compete with the information.

## Level 1: Weather Content

Examples:

- Today's Awareness.
- Active warning heroes.
- Storm Risk.
- Severe Risk.
- Fire Risk.
- Local Alerts.
- Atmospheric Conditions.
- Storm Setup.
- Outlook Summary.
- Detail content.

Weather content should be:

- Stable.
- Highly legible.
- Primarily opaque.
- Semantically expressive where appropriate.
- Visually integrated with the canvas.
- Organized around typography and spacing.

Weather content is not Liquid Glass by default.

## Level 2: Controls and Navigation

Examples:

- Tab bars.
- Toolbars.
- Navigation controls.
- Floating Map controls.
- Menus.
- Layer selectors.
- Appropriate floating actions.

These surfaces control or navigate content.

They may use native platform materials and Liquid Glass where supported and appropriate.

They should visually remain distinct from the weather information they operate on.

## Hierarchy Rule

The most important weather information should be recognizable before secondary detail.

Avoid several equally dominant content surfaces competing for attention.

A warning may command substantially more attention than ordinary atmospheric instrumentation.

This difference should be communicated through meaningful hierarchy rather than decorative escalation.

---

# 3. Light and Dark Appearance

Light and dark appearances are equally important.

Neither is a simple transformation of the other.

Both must preserve:

- Weather semantics.
- Information hierarchy.
- Text readability.
- Recognizable component relationships.
- Appropriate interaction affordances.
- Premium visual quality.

Do not assume that identical opacity values, gradients, or material treatments will produce equivalent visual results in both appearances.

Evaluate each independently.

---

# 4. Light-Mode Foundation

Light mode uses a clean, neutral, slightly cool visual foundation.

It should feel:

- Bright without being stark.
- Calm without being washed out.
- Clean without appearing clinical.
- Refined without floating-card clutter.
- Colorful where actual weather meaning warrants it.

## 4.1 Approved Neutral Palette

The established light-mode values are:

| Role | Value | Purpose |
| --- | --- | --- |
| App canvas | `#F5F6F7` | Quiet off-white background |
| Ordinary weather content | `#FCFCFD` | Stable near-white content surface |
| Neutral awareness base | `#FCFCFD` | Base surface beneath approved semantic treatment |

These are opaque sRGB color values.

Do not copy their numerical components into Display P3 assets without proper conversion.

Use existing application assets and styling seams where appropriate.

Do not create a separate palette-management framework merely to represent these values.

## 4.2 Canvas and Content Relationship

The canvas should remain slightly darker than ordinary weather content.

This small tonal difference creates separation without requiring strong borders or shadows.

Avoid:

- Stark pure-white canvas.
- Blue or lavender background washes.
- Alternating neutral hues between sections.
- Nested translucent cards.
- Unnecessary elevation.
- Card surfaces that become visually gray or disabled.

Ordinary content should share one coherent near-white surface family.

## 4.3 Ordinary Content Surfaces

Ordinary supporting content uses the established near-white neutral surface.

Examples include:

- Local Alerts.
- Atmospheric Conditions.
- Storm Setup.
- Outlook Summary.
- Ordinary neutral status content.

These surfaces should not acquire individual background hues merely to distinguish sections.

Use typography, spacing, and appropriate semantic accents to establish hierarchy.

Nested information normally inherits its parent's surface rather than receiving another card.

## 4.4 Today's Awareness Exception

Today's Awareness has an intentionally approved semantic-gradient treatment.

The hero and Storm Risk, Severe Risk, and Fire Risk cards use the neutral content surface as their base, with restrained semantic color layered into the existing card presentation.

This is a deliberate exception to the ordinary neutral-content rule.

It must not be interpreted as permission to apply broad gradients throughout the application.

The exact approved gradient behavior belongs in [Today](today.md).

## 4.5 Light-Mode Borders

Ordinary content cards use restrained edges only where separation is necessary.

The established standard is:

- Adaptive primary foreground.
- 6% opacity.
- 0.5 pt stroke.
- Continuous outline.

Avoid:

- Thick outlines.
- Bright white highlight rims.
- Multiple nested borders.
- Borders combined with shadows for the same purpose.
- Colored outlines without semantic justification.

Spacing and tonal separation should remain the primary organizing tools.

### Increase Contrast

Where additional separation is required:

- Adaptive primary foreground.
- 14% opacity.
- 1 pt stroke.

Verify the complete composition.

Stronger borders do not compensate for insufficient text contrast.

## 4.6 Light-Mode Shadows

Ordinary light-mode weather cards have **no drop shadow**.

Use the canvas/content tonal distinction first.

A stable content summary floating over a variable Map may use a restrained shadow when necessary for separation.

The established optional treatment is:

- Black at 6% opacity.
- 4 pt blur radius.
- 1 pt vertical offset.

Do not apply this automatically.

Start with the opaque surface and restrained edge.

Add elevation only when representative Map backgrounds demonstrate the need.

Native floating controls own their platform-provided elevation.

Do not add custom shadows or highlight rims around native Glass controls.

---

# 5. Dark-Mode Foundation

Dark mode uses a deep, atmospheric visual foundation.

It should feel:

- Rich.
- Calm.
- Legible.
- Integrated.
- Distinctly SkyAware.

The established direction uses deep navy and charcoal relationships rather than an assortment of unrelated floating gray cards.

## Surface Relationships

The dark canvas should recede behind meaningful weather content.

Content surfaces should remain visually distinct without excessive elevation.

Avoid:

- Muddy gray surfaces.
- Excessively bright borders.
- Repeated glowing outlines.
- Unrelated charcoal tones.
- Strong shadows that contribute little separation.
- Decorative color flooding.

## Semantic Color

Dark-mode semantic colors may have greater depth and richness than their light counterparts.

They must remain recognizable and readable.

Do not globally desaturate the weather palette to make the surrounding UI appear calmer.

Quiet emerald and elevated hazard colors should retain their established identity.

## Existing Dark-Mode Values

Preserve the current approved dark-mode palette and component treatments.

This document does not introduce a new numerical dark-mode palette.

Before changing a dark surface, inspect the current implementation and the [approved implementation baseline in Visual Review](visual-review.md#approved-application-screenshots) where applicable. Visual Review owns the approved reference set.

Do not modify approved dark-mode values merely to simplify light-mode implementation.

---

# 6. Semantic Color System

Color communicates weather meaning.

It is not a general-purpose decorative resource.

## 6.1 Semantic Ownership

Established semantic families include:

- Categorical storm risk.
- Tornado.
- Wind.
- Hail.
- Fire weather.
- Mesoscale discussions.
- Air quality.
- Conditional intensity.
- Quiet weather.

Preserve the existing meaning of each family.

Do not reuse weather-risk colors casually for:

- Settings categories.
- Generic navigation.
- Ordinary metadata.
- Loading activity.
- Offline status.
- Success indicators.
- Arbitrary visual emphasis.

## 6.2 Storm Risk

The established SPC-aligned categorical ladder is:

| Category | Semantic color family |
| --- | --- |
| Quiet / general thunderstorm baseline | Green |
| Marginal | Darker green |
| Slight | Yellow |
| Enhanced | Orange |
| Moderate | Red |
| High | Purple |

These families identify established storm-risk categories.

Do not change their meaning merely to create a more aesthetically balanced screen.

Use the current accepted semantic assets and mappings rather than redefining individual RGB values locally.

Quiet green represents a scoped weather assessment, not universal safety.

## 6.3 Severe Threats

The established severe-hazard identities include:

| Hazard | Established semantic identity |
| --- | --- |
| Tornado | `tornadoRed` |
| Hail | `hailBlue` |
| Wind | `windTeal` |
| Quiet severe state | Green family |

Use these identities consistently across relevant Today and Map presentations.

The displayed hazard and its semantic color must agree.

Never transfer semantic coloring or conditional-intensity meaning from one hazard to another.

## 6.4 Fire Risk

Fire Risk maintains its own semantic ladder.

Its colors must communicate actual fire-weather meaning.

Do not borrow storm-risk colors solely because they appear visually similar.

Fire Risk and Storm Risk may both use warm colors in elevated states, but their labels, icons, and underlying semantics must remain distinct.

The current domain mapping and semantic assets are authoritative.

## 6.5 Mesoscale Discussions

Mesoscale discussions use a distinct indigo-purple identity.

This must remain distinguishable from the purple associated with High categorical storm risk.

The purpose is recognition without semantic ambiguity.

## 6.6 Air Quality

AQI uses its established health-category color system.

Do not substitute severe-weather risk colors for air-quality meaning.

AQI remains environmental instrumentation, not a new severe-weather warning category.

## 6.7 Freshness and Availability

Freshness is application/data state, not weather safety.

Healthy freshness should generally use neutral presentation.

Stale or degraded states may use subtle warning-oriented emphasis when justified.

Do not use green as a generic "data is fresh" indicator.

Never present unavailable information using confirmed quiet-state styling.

The behavioral distinctions belong in [States and Accessibility](states-accessibility.md).

---

# 7. Semantic Gradients

Gradients are an established part of SkyAware's visual identity when they communicate weather meaning.

They are not a default decoration for every card.

## 7.1 General Principles

A successful semantic gradient should:

- Reinforce the associated weather category.
- Maintain readable foreground content.
- Integrate with the existing content surface.
- Support hierarchy without overwhelming it.
- Feel intentional in both appearances.
- Preserve a clear relationship to the associated semantic accent.

## 7.2 Color Relationships

Quiet gradients should feel recognizable without implying elevated urgency.

Elevated gradients may be more expressive in proportion to actual weather significance.

An active warning may receive stronger visual emphasis when it owns the primary awareness position.

The perceived strength of a gradient should correspond to its semantic role.

## 7.3 Transition Quality

Gradients should blend naturally into their underlying surfaces.

Avoid:

- Abrupt termination.
- Visible color bands.
- Muddy desaturation.
- Overly broad pastel washes.
- Excessive saturation across an entire card.
- Artificial glowing edges.
- Unrelated decorative color.

The final gradient should feel like part of the surface rather than a separate painted rectangle.

## 7.4 Appearance-Specific Tuning

Light and dark gradients require independent visual evaluation.

Do not assume identical stops, opacities, or blending behavior produce the same visual weight.

Preserve previously approved appearance-specific treatments when changing the other appearance.

## 7.5 Motion

Semantic awareness gradients are static presentation.

Do not animate them continuously to manufacture atmosphere or urgency.

Use motion only when it communicates a meaningful transition or interaction.

The specific Today's Awareness treatment is defined in [Today](today.md).

---

# 8. Typography

Typography carries most of SkyAware's information hierarchy.

Prefer native SwiftUI semantic fonts and Dynamic Type behavior.

The type system should remain:

- Stable.
- Readable.
- Calm.
- Consistent.
- Apple-native.

## 8.1 Typography Hierarchy

Typical content hierarchy:

1. Primary weather value or event.
2. Section heading.
3. Category or measurement label.
4. Supporting explanation.
5. Metadata and attribution.

The order may vary by component, but the relative importance must remain immediately recognizable.

## 8.2 Established Text Roles

| Role | Preferred treatment |
| --- | --- |
| Location | Primary foreground, strong established hierarchy |
| Temperature | Primary foreground, prominent value |
| Primary risk or warning title | Primary foreground, appropriate stronger weight |
| Section heading | Secondary foreground, headline, semibold |
| Category label | Secondary foreground, caption or subheadline |
| Supporting explanation | Secondary foreground, body or subheadline |
| Metadata | Secondary foreground, caption |
| Decorative indicator | Tertiary where appropriate |

Use the component's established Dynamic Type sizes and hierarchy.

Do not treat this table as permission to globally replace existing font sizes.

## 8.3 Text Contrast

Use adaptive system foreground styles.

For ordinary light-mode content:

- Primary values use `.primary`.
- Section headings use `.secondary` with appropriate semibold hierarchy.
- Supporting prose uses `.secondary` at full foreground opacity.
- Metadata uses appropriate secondary emphasis.

Do not reduce `.secondary` again with arbitrary opacity modifiers.

For example, avoid combining:

`.foregroundStyle(.secondary)`

with an additional:

`.opacity(0.6)`

This can make important text appear disabled or insufficiently legible.

## 8.4 Section Headings

Section headings should:

- Remain clearly visible.
- Use consistent alignment.
- Establish a predictable scanning rhythm.
- Remain subordinate to primary values.
- Avoid excessive size or weight.

Internal and external section headings should share a coherent typographic language.

Their structural differences are defined by the relevant surface specification.

## 8.5 Values and Measurements

Numerical measurements should be easy to recognize and compare.

Use monospaced digits where they materially improve numeric stability.

Do not use monospaced typography for ordinary explanatory weather prose.

Units should remain visually associated with their values.

Avoid excessive emphasis on secondary numbers merely because they are available.

## 8.6 Long Weather Text

Essential weather meaning must not be sacrificed to preserve fixed card height.

Prefer:

- Natural text wrapping.
- Vertical expansion.
- Appropriate adaptive arrangements.
- Progressive disclosure where suitable.

Avoid:

- Arbitrary truncation.
- Unreadably small fonts.
- Compressed multi-line descriptions.
- Overlapping text.
- Decorative elements occupying space needed by important content.

Accessibility-specific expectations belong in [States and Accessibility](states-accessibility.md).

---

# 9. Shape and Corner Geometry

SkyAware uses a consistent family of continuous rounded shapes.

Shape should feel native to modern Apple-platform design.

## 9.1 Shared Radius Language

Prefer existing shared radius conventions, including the established `SkyAwareRadius` system where applicable.

The original design standardized around continuous corners and an approximately 30 pt app-wide fallback for iOS 18 compatibility.

Treat this as historical baseline guidance, not an instruction to apply 30 pt to every component.

Inspect the current shared implementation before introducing or changing a radius.

## 9.2 Shape Consistency

Components that live together should use related corner treatments.

Examples:

- Hero and supporting awareness cards.
- Supporting summary cards.
- Embedded header surfaces.
- Map controls.
- Legend surfaces.
- Buttons and menus.

Do not introduce a one-off corner style without a clear structural reason.

Respect platform concentricity where appropriate.

## 9.3 Avoid Excessive Nesting

Prefer:

Canvas → meaningful content surface.

Avoid:

Canvas → decorative container → content card → nested card → badge.

Every additional shape should have a real grouping or semantic purpose.

A section containing multiple cards does not automatically need another large surrounding card.

---

# 10. Spacing and Density

SkyAware should feel spacious without becoming sparse.

## 10.1 Spacing Principles

Use spacing to communicate relationships.

Elements that belong together should feel grouped.

Separate conceptual sections clearly without introducing excessive distance.

Preserve consistent:

- Horizontal alignment.
- Section rhythm.
- Internal padding.
- Label-to-value relationships.
- Icon-to-text spacing.
- Related-card spacing.

## 10.2 Density

Information density should reflect importance and available space.

Do not compress primary weather information merely to fit more metrics.

Do not expand supporting sections until they compete with primary awareness.

Prefer omission or progressive disclosure over overcrowding.

## 10.3 Shared Spacing

Reuse existing spacing conventions where practical.

A small shared scale may be appropriate when it reduces demonstrated inconsistency.

Do not introduce a large token system for hypothetical future components.

## 10.4 Responsive Layout

A wider device does not automatically justify a denser arrangement.

Preserve approved information hierarchy across iPhone sizes.

Do not rearrange established components solely because additional width is available.

Adapt layouts when necessary for readability, accessibility, and available display constraints.

Surface-specific layout requirements belong in their respective documents.

---

# 11. Iconography

SF Symbols are the preferred iconographic foundation.

Use existing established symbols when they accurately communicate meaning.

## 11.1 Icon Responsibilities

Icons should:

- Reinforce a weather concept.
- Identify a category.
- Aid scanning.
- Clarify navigation or interaction.
- Communicate a meaningful state.

Icons are supporting elements, not substitutes for clear text.

## 11.2 Semantic Consistency

Do not use a strongly associated category icon for an unrelated nearby meaning.

The established design previously resolved several icon conflicts.

Examples include:

- Fire Risk retains flame semantics.
- High categorical storm risk uses a distinct severe-weather symbol rather than borrowing Fire Risk's flame.
- Mesoscale discussions retain their distinct identity.
- Map layer selection uses a layered symbol rather than a generic settings/sliders symbol.

Preserve current approved symbol mappings rather than introducing arbitrary variants.

## 11.3 Visual Consistency

Within a component family, maintain consistent:

- Symbol scale.
- Weight.
- Alignment.
- Semantic color.
- Relationship to accompanying text.

Do not reproduce malformed or synthetic symbols from generated images.

Prefer real SF Symbols or approved product assets.

---

# 12. Navigation and Interaction Affordances

Interactive elements should behave as their appearance suggests.

## 12.1 Native Interaction

Prefer appropriate native SwiftUI controls:

- `Button`
- `NavigationLink`
- `Menu`
- `Picker`
- `NavigationStack`
- Native sheets and popovers.
- Native toolbar actions.

Do not simulate buttons using unnecessary gestures or custom interaction plumbing.

Keep weather-domain presentation custom where it communicates meaningful information.

## 12.2 Entire-Surface Interaction

When a card represents one action, the card should ordinarily be the interaction target.

Avoid placing multiple competing navigation controls inside one simple summary card.

A decorative chevron should reinforce the existing action, not create a second independent action.

## 12.3 Honest Affordances

A navigable component should communicate that it is actionable.

A noninteractive component should not imply that navigation exists.

Show trailing chevrons or similar affordances only when they represent actual supported behavior.

Do not alter navigation destinations to justify a visual affordance.

## 12.4 Targeted Interaction

Not every content container needs to be tappable.

When only a specific value has additional meaning, it may be appropriate to make only that value interactive.

The interaction boundary must match the user's expectation.

## 12.5 Feedback

Provide immediate, proportionate interaction feedback.

Prefer native pressed states, control behavior, and supported sensory feedback.

Avoid elaborate animation for ordinary taps.

Interaction should feel responsive without drawing attention to itself.

---

# 13. Liquid Glass and Native Materials

SkyAware distinguishes weather content from controls that operate on that content.

The governing rule is:

**Liquid Glass identifies appropriate controls floating above weather content. It is not the weather content itself.**

## 13.1 Appropriate Uses

Native Liquid Glass may be used where supported for:

- Tab and navigation chrome.
- Toolbars.
- Floating Map controls.
- Appropriate menus.
- Intentionally floating actions.
- Transient interactive controls.

Use the platform's native behavior.

Allow Apple to manage appropriate material adaptation and appearance.

## 13.2 Inappropriate Uses

Do not apply Liquid Glass by default to:

- Active warning heroes.
- Storm Risk.
- Severe Risk.
- Fire Risk.
- Atmospheric Conditions.
- Local Alerts.
- Ordinary summary cards.
- Static metadata.
- Long-form reading surfaces.
- Widget content.

Weather content should remain stable and legible.

It must not depend on translucency for sufficient contrast.

## 13.3 Avoid Custom Glass Infrastructure

Do not create a SkyAware-specific imitation of Liquid Glass.

Avoid unnecessary wrappers around `glassEffect` or `GlassEffectContainer`.

Custom material usage should be justified by real interaction hierarchy.

Do not introduce a large Glass abstraction or theme framework.

Prefer native APIs over recreating platform behavior.

---

# 14. Motion and Transitions

Motion should communicate state and preserve continuity.

It should feel:

- Calm.
- Subtle.
- Responsive.
- Native.
- Purposeful.

## 14.1 Appropriate Motion

Examples include:

- Subtle opacity transitions.
- Content resolving into place.
- Appropriate crossfades.
- Immediate interaction feedback.
- Small changes that reinforce cause and effect.

Prefer native SwiftUI transitions where they express the intended behavior cleanly.

## 14.2 Motion to Avoid

Avoid:

- Bouncing content.
- Unnecessary spring effects.
- Decorative continuous animation.
- Flashing weather surfaces.
- Shimmer used merely for activity.
- Repeated refresh animations.
- Layout movement unrelated to meaningful content changes.
- Animated semantic gradients.
- Motion that makes risk appear more urgent than the data supports.

## 14.3 State Continuity

A routine refresh should not feel like a new screen appearing.

Preserve visible accepted information until a coherent replacement exists.

Do not animate unchanged data as though the weather changed.

Motion must never hide:

- Uncertainty.
- Latency.
- Incomplete state.
- Incorrect information.

## 14.4 Reduced Motion

Respect Reduce Motion.

The reduced-motion experience must remain complete and intentional.

Do not rely on animation to communicate essential meaning.

Detailed state-transition requirements belong in [States and Accessibility](states-accessibility.md).

---

# 15. Cross-Surface Consistency

The same underlying visual language should remain recognizable across:

- Today.
- Map.
- Weather detail screens.
- Home Screen widgets.
- Lock Screen widgets.
- Supported watchOS experiences.
- Settings and supporting navigation.

However, consistency does not require identical layouts or materials.

## Shared Identity

Preserve:

- Semantic color meaning.
- Typographic hierarchy.
- Recognizable category symbols.
- Established shape relationships.
- Clear interaction affordances.
- Appropriate visual restraint.

## Platform-Specific Behavior

Allow the platform to own:

- Native navigation chrome.
- Toolbar behavior.
- Widget outer shape and margins.
- System rendering modes.
- Appropriate material behavior.
- Accessibility adaptations.

Do not simulate iOS content cards inside WidgetKit merely to make the surfaces look identical.

## Deliberate Exceptions

Some product surfaces require specialized treatments.

Examples:

- Today's Awareness gradients.
- Official warning emphasis.
- Map legends and spatial overlays.
- Conditional-intensity hatching.
- Widget family-specific layouts.

These are intentional expressions of domain meaning or platform constraints.

They should not become global styling defaults.

## Weather-Product Detail Presentation

Alert Detail, Watch Detail, Outlooks, and Mesoscale Discussion detail experiences share a general hierarchy:

1. Clear header.
2. Important metadata.
3. Summary-first explanation.
4. Expanded or drill-in detail where supported by the existing experience.

Severity, certainty, and urgency use compact, readable status chips where applicable. Sender, instructions, and response information use textual rows or sections rather than being converted indiscriminately into chips.

These experiences share visual conventions without requiring identical content. Apply the typography, surface, and interaction guidance in this document; preserve official source wording where its precision matters and the authoritative meteorological meaning defined by the North Star.

This presentation hierarchy does not prescribe new navigation, data models, or detail-screen architecture.

---

# 16. Implementation Boundaries

These foundations should be implemented through existing presentation ownership where practical.

Before changing shared styles:

1. Inspect current component consumers.
2. Identify the real presentation owner.
3. Determine whether a modifier or asset is shared with unrelated screens.
4. Preserve existing semantic behavior.
5. Scope the change to the intended surface.
6. Validate affected light and dark appearances.

## Shared Styling Risks

Existing shared presentation seams may serve multiple areas of the application.

For example, shared background or surface modifiers may be consumed by:

- Today.
- Settings.
- Onboarding.
- Diagnostics.
- Detail screens.
- Map.
- Loading states.

A seemingly local palette change can repaint unrelated surfaces.

Do not modify globally shared assets without understanding their complete consumer set.

## Avoid Parallel Styling Systems

Do not create:

- A second palette manager.
- Duplicate semantic color mappings.
- A speculative design-token framework.
- A new abstraction for every card.
- Separate custom material systems.
- Unnecessary presentation-state owners.

Prefer existing assets and focused local implementation when sufficient.

A new abstraction should materially improve consistency, testability, or maintenance.

## Domain Boundaries

Visual work does not authorize changes to:

- Weather interpretation.
- Alert precedence.
- Persistence.
- Accepted-state ownership.
- Refresh orchestration.
- Map data semantics.
- Notification delivery.
- Source-specific ingestion.

If a presentation change requires new domain behavior, resolve that dependency explicitly.

---

# 17. Foundation Review Checklist

Before approving a meaningful shared visual change, verify:

## Hierarchy

- Is the most important weather information immediately recognizable?
- Are supporting elements subordinate?
- Does typography carry hierarchy without excessive decoration?

## Color

- Are semantic colors accurate?
- Do quiet states remain recognizable?
- Do elevated states communicate appropriate importance?
- Are gradients smooth and intentional?
- Has any existing semantic meaning been weakened or reassigned?

## Surfaces

- Do ordinary cards belong to one coherent surface family?
- Are light-mode shadows absent unless specifically justified?
- Are borders restrained?
- Is Glass limited to appropriate navigation and controls?
- Are nested containers necessary?

## Typography

- Are values and headings legible?
- Does supporting text have sufficient adaptive contrast?
- Is essential copy complete?
- Are font sizes and weights consistent?

## Interaction

- Are actionable elements discoverable?
- Do affordances match actual behavior?
- Are native control semantics preserved?
- Is redundant navigation avoided?

## Adaptation

- Does the composition work in light and dark appearance?
- Does it adapt to different device widths?
- Does Dynamic Type preserve meaning?
- Are Increase Contrast, Reduce Motion, and Reduce Transparency respected?

## Implementation

- Were shared consumers inspected?
- Was existing domain behavior preserved?
- Did the change avoid unnecessary styling infrastructure?
- Was the complete affected composition visually reviewed?

A passing build is not sufficient evidence of visual quality.

Use the review practices defined in [Visual Review](visual-review.md).

---

# Final Foundation Principle

SkyAware's visual identity is built from the relationship between:

**Calm native foundations.**

**Precise information hierarchy.**

**Purposeful semantic weather color.**

**Honest and predictable interaction.**

**Careful attention to every visible state.**

The goal is not to make every screen look identical.

The goal is to make every screen feel like it belongs to the same thoughtfully designed product.

**Preserve the established visual language. Use complexity only when it contributes meaning. Make every detail earn its place.**
