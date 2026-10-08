---
title: SkyAware Today Design
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - design
  - today
  - swiftui
---

# SkyAware Today Design

## Purpose

This document defines the canonical visual and interaction design for SkyAware's Today experience.

Today is the product's primary awareness destination.

Its purpose is to help users understand their local severe-weather situation quickly, accurately, and calmly.

This document owns:

- Today information hierarchy and composition.
- Current Conditions presentation.
- Today's Awareness visual system.
- Primary awareness hero presentation.
- Storm, Severe, and Fire supporting cards.
- Semantic gradients and navigation affordances.
- Local Alerts presentation.
- Atmospheric Conditions presentation.
- Storm Setup summary presentation.
- Location Reliability presentation.
- Outlook Summary presentation.
- Today-specific responsive behavior.
- Visual consistency and acceptance requirements.

This document does not redefine weather interpretation, alert precedence, risk calculation, persistence, or canonical state ownership.

Those responsibilities are governed by the North Star and established application architecture.

Related documentation:

- [Design System](README.md)
- [Foundations](foundations.md)
- [North Star](../product/north-star.md)
- [Brand and Voice](../brand/brand-and-voice.md)
- [States and Accessibility](states-accessibility.md)
- [Visual Review](visual-review.md)

---

# 1. Design Intent

Today should answer five questions:

1. Where am I?
2. What is the weather like right now?
3. How concerning is the severe-weather picture?
4. What official alerts are active locally?
5. What else deserves my attention?

The user should understand the most important information within seconds.

The experience should feel:

- Immediate.
- Calm.
- Focused.
- Trustworthy.
- Informative.
- Distinctly SkyAware.
- Carefully crafted.

## Primary Principle

**Today's Awareness is the visual center of the screen.**

Other sections should support it rather than compete for equal attention.

A user should not need to evaluate multiple equally prominent cards to discover the most important weather information.

## Calm Does Not Mean Visually Timid

Today's design uses a restrained neutral foundation with purposeful semantic weather color.

The neutral foundation provides clarity.

Semantic color provides recognition and meaning.

Typography establishes hierarchy.

Interaction affordances make navigation discoverable.

Avoid removing so much character that the primary awareness cards become indistinguishable from ordinary supporting content.

Equally, avoid decorative treatments that compete with actual weather information.

---

# 2. Canonical Today Composition

The established section order is:

1. Current Conditions.
2. Today's Awareness.
   - Primary awareness hero.
   - Storm Risk.
   - Severe Risk.
   - Fire Risk.
3. Local Alerts.
4. Atmospheric Conditions.
5. Storm Setup, when eligible.
6. Location Reliability, when eligible.
7. Outlook Summary.
8. Attribution.

The arrangement is conditional.

Optional sections disappear when not applicable.

Do not preserve empty containers solely to maintain a fixed visual stack.

Storm Setup retains its logical section position across its supported status and resolved states.

## Section Hierarchy

Today's content uses three broad levels.

### Primary Context

Current Conditions establishes the user's immediate location and weather context.

### Primary Awareness

Today's Awareness communicates the strongest relevant severe-weather signal and supporting risks.

### Supporting Information

Local Alerts, Atmospheric Conditions, Storm Setup, Location Reliability, and Outlook Summary provide additional context and appropriate navigation.

These sections must remain visually subordinate to the primary awareness experience.

---

# 3. Current Conditions

Current Conditions is a compact, open header.

It should feel like an integrated part of the screen rather than a large weather card.

## Responsibilities

Present:

- Current location.
- Current temperature.
- Current weather condition.
- Appropriate location or weather status.

## Visual Hierarchy

Location is primary.

Temperature is prominent on the trailing side.

The weather condition symbol supports the temperature rather than competing with it.

The temperature and associated symbol should maintain a close visual relationship.

## Presentation Rules

- Keep the header compact.
- Use typography rather than a heavy container.
- Preserve established alignment.
- Avoid unnecessary decorative backgrounds.
- Do not add a separate timestamp merely for decoration.
- Keep status communication visually subordinate.
- Preserve readable location context when available.

## Location and Weather Availability

A changing location or transient weather refresh must not create unnecessary visual churn.

When meaningful accepted weather information exists, preserve it while newer information resolves.

Do not make the header appear completely unavailable because an unrelated supporting section is refreshing.

The authoritative state rules are defined in [States and Accessibility](states-accessibility.md).

---

# 4. Today's Awareness

Today's Awareness is the primary severe-weather presentation system.

It contains four coordinated surfaces:

1. Dynamic primary awareness hero.
2. Storm Risk.
3. Severe Risk.
4. Fire Risk.

The hero presents the strongest relevant local awareness signal.

The supporting cards retain the other categories.

## 4.1 Awareness Selection

The established primary-awareness precedence is:

1. Active warning or watch.
2. Non-clear severe threat.
3. Non-clear storm risk.
4. Elevated fire risk.
5. Resolving state.
6. Quiet state.

This ordering is a product invariant.

The domain presentation model determines which state owns the hero.

The visual layer must not independently recalculate priority or select a more visually interesting hazard.

Refer to the North Star for authoritative selection and weather semantics.

---

# 5. Four-Card Awareness Family

The primary hero and three supporting cards share one deliberate visual language.

They should look related without carrying identical visual weight.

## Shared Elements

The established family uses:

- Continuous rounded card geometry.
- Stable content surfaces.
- Narrow vertical semantic-color rails.
- Restrained severity-aware gradients.
- Semantic category symbols.
- Clear primary values or event titles.
- Concise explanatory text.
- Colored navigation chevrons when actionable.
- Consistent interaction feedback.

These elements reinforce one another.

They are not independent decorative effects.

## Card Hierarchy

The primary hero has greater prominence than the supporting cards.

Storm Risk, Severe Risk, and Fire Risk share consistent supporting-card prominence.

Avoid introducing a second competing hero within the supporting group.

The hierarchy should remain recognizable in quiet, elevated, and warning states.

## Geometry

Preserve the established:

- Corner relationships.
- Internal padding.
- Inset vertical rail.
- Symbol placement.
- Typography hierarchy.
- Chevron alignment.
- Card-to-card spacing.

Do not redesign the card structure merely to adjust semantic coloring.

Use existing shared radius conventions and component styling where appropriate.

---

# 6. Supporting Risk Layout

## Full-Width Vertical Stack

On iPhone, the supporting cards are always arranged vertically:

1. Storm Risk.
2. Severe Risk.
3. Fire Risk.

Each card receives the full available width.

This is an approved design decision.

## Do Not Restore the Paired Layout

Do not place Storm Risk and Severe Risk side by side on wider iPhones.

The earlier adaptive arrangement produced different information hierarchies between standard Pro and Pro Max devices.

Although both arrangements could technically fit, the paired layout weakened:

- Text readability.
- Gradient continuity.
- Visual consistency.
- Supporting-card recognition.
- Available room for hazard explanations.

Additional device width is not sufficient reason to increase card density.

## Spacing

Maintain consistent spacing between the three supporting cards.

Preserve the established relationship between the primary hero and the supporting-card group.

Do not introduce nested containers around the three cards merely to group them visually.

## Accessibility Adaptation

Individual cards may grow vertically to accommodate content.

At accessibility text sizes, internal content arrangements may adapt.

The overall supporting-card hierarchy remains vertical.

Do not compress essential weather information to preserve card height.

---

# 7. Semantic Awareness Gradients

Semantic gradients are a defining part of the approved Today's Awareness design.

They provide recognizable weather identity within a restrained native content system.

They are not general-purpose decoration.

## 7.1 Composition

Each awareness card begins with a stable, opaque content surface.

A semantic gradient is layered within the existing card boundary.

The gradient should:

- Be strongest near the leading edge.
- Reinforce the established semantic rail.
- Fade horizontally toward the trailing surface.
- Blend naturally into the existing base color.
- Remain contained within the card geometry.
- Preserve legible text and symbols.

The result should appear integrated with the surface rather than painted on top of it.

## 7.2 Quiet Weather

Quiet states use a recognizable emerald/jade character.

The color should feel:

- Fresh.
- Calm.
- Clean.
- Distinctive.
- Appropriately restrained.

It should not feel:

- Muddy.
- Washed out.
- Nearly invisible.
- Overly mint-colored.
- Artificially saturated.
- Suggestive of elevated danger.

The final approved quiet treatment uses stronger color near the left rail and a graceful taper into the neutral card surface.

## 7.3 Quiet Gradient Transition

The transition should occur progressively across nearly the full card width.

Preserve recognizable semantic color near the leading rail.

Reduce intensity smoothly through the middle of the card.

The trailing portion should blend imperceptibly into the existing neutral surface.

Avoid:

- A visible gradient endpoint.
- Sudden color disappearance.
- Hard transitions near the middle or three-quarter position.
- An isolated saturated patch.
- Excessively broad pastel flooding.
- Muddy gray-green blending.

The gradient must feel continuous.

A visually attractive starting color does not compensate for a poor transition.

## 7.4 Hero Versus Supporting Cards

The primary hero may use a slightly stronger semantic treatment.

Supporting cards use a related, somewhat quieter treatment.

The cards should remain recognizable as one coordinated family.

Do not create substantially different gradient techniques for each risk category.

## 7.5 Elevated Weather

Elevated states use the established weather-risk and hazard colors.

Examples include:

- Orange categorical storm risk.
- Tornado-associated magenta/red.
- Wind-associated teal.
- Hail-associated blue.
- Elevated fire-weather colors.

Actual coloring must follow the accepted semantic mapping.

These examples are not permission to substitute colors based on appearance.

Elevated gradients may be more expressive than quiet-state gradients.

They must remain readable and restrained.

## 7.6 Active Warnings

An active warning hero receives appropriate primary emphasis.

Its semantic treatment should clearly distinguish it from quiet or ordinary supporting risk information.

The approved warning presentation uses meaningful color, a stronger semantic boundary when warranted, and clear typography.

Do not introduce:

- Flashing colors.
- Animated warning backgrounds.
- Emergency siren styling.
- Decorative glows.
- Excessive shadows.
- Dramatic layout transformations.

Urgency should come from actual warning information and appropriate semantic emphasis.

## 7.7 Light and Dark Appearance

Light and dark gradients are independently tuned.

Light mode uses the established near-white content base.

Dark mode retains the approved deep, atmospheric content treatment.

Do not force matching numerical gradient values across appearances.

Preserve already approved semantic treatments when refining another state.

## 7.8 Motion

Awareness gradients are static.

Do not introduce continuous gradient animation, pulsing, shimmer, or atmospheric drift.

State transitions may use restrained native motion when appropriate.

Animation must not imply a weather change when only presentation or freshness activity changed.

---

# 8. Semantic Rails

Each awareness card retains a narrow vertical semantic-color rail.

The rail is an important part of SkyAware's awareness identity.

It:

- Reinforces the represented weather category.
- Connects the category to its gradient.
- Supports quick visual recognition.
- Helps establish a cohesive card family.

## Rail Requirements

- Preserve the existing inset capsule treatment.
- Maintain consistent positioning.
- Keep the rail contained within its card.
- Use the actual semantic color.
- Preserve readable surrounding content.
- Maintain a consistent visual relationship with the card's symbol and gradient.

Do not substitute a full-height external border for the established rail.

Do not remove the rail merely because the gradient already communicates color.

The two elements work together.

---

# 9. Navigation and Interaction

Today's Awareness cards use clear, truthful navigation affordances.

## 9.1 Full-Card Interaction

When a card represents one action, the entire card is the interaction target.

Use native button behavior.

Preserve existing pressed feedback without adding elaborate animation.

Do not create a second independent button solely for the chevron.

## 9.2 Semantic Chevrons

Actionable cards display a trailing chevron that reinforces navigation.

The chevron uses a readable variation of the associated semantic color.

It should:

- Remain visible in light and dark mode.
- Maintain appropriate contrast.
- Align consistently with card content.
- Remain subordinate to the weather value.
- Be decorative for accessibility.

The card itself owns the action and accessibility semantics.

## 9.3 Hero Navigation

The primary hero supports three destination categories:

- Alerts.
- A relevant Map layer.
- No destination.

Show a chevron only when a real destination exists.

Quiet and resolving hero states may be noninteractive.

Do not make them appear tappable merely for consistency.

## 9.4 Supporting Card Navigation

Preserve established destinations:

**Storm Risk**

Opens the categorical storm-risk Map layer.

**Severe Risk**

Opens the relevant severe-hazard Map layer.

The selected hazard may be tornado, hail, or wind.

Preserve established quiet-state fallback behavior where applicable.

**Fire Risk**

Opens the fire-weather Map layer.

## 9.5 Navigation Boundaries

Do not change navigation behavior as a side effect of styling.

Do not introduce:

- New Map layers.
- New navigation destinations.
- Redundant chevron buttons.
- Gesture-based imitations of Buttons.
- Decorative controls without actions.

A visible affordance must represent actual supported behavior.

---

# 10. Primary Awareness Hero

The hero communicates the strongest currently relevant awareness signal.

Its presentation adapts to the accepted primary-awareness state.

## 10.1 Content Hierarchy

The hero may include:

- Relevant event timing.
- Semantic category symbol.
- Primary title or event name.
- Concise supporting explanation.
- Navigation chevron when actionable.
- Guidance when supplied by an applicable official alert.

Not every state contains every element.

Do not create empty placeholders for absent optional information.

## 10.2 Quiet Hero

The quiet hero should:

- Communicate the scoped quiet state clearly.
- Use the approved emerald/jade language.
- Remain visually prominent.
- Avoid implying universal safety.
- Avoid implying navigation when none exists.

Quiet weather should feel intentional, not like an empty or disabled interface.

## 10.3 Elevated Hero

An elevated hero should:

- Identify the selected risk or hazard.
- Communicate its primary meaning.
- Use the appropriate semantic color.
- Preserve concise supporting explanation.
- Offer the established destination.

It should not require users to inspect all three supporting cards before understanding the principal concern.

## 10.4 Warning or Watch Hero

An active warning or watch hero may include:

- Official event name.
- Valid-until or expiration information.
- Primary threat summary.
- Applicable guidance.

Timing should remain clear and readable.

Guidance, when available, is visually distinguished from the primary event information without becoming a separate competing hero.

A subtle separator and clear guidance label may establish the relationship.

Use only appropriate source-derived or established guidance language.

Do not generate generic emergency instructions based on the event name alone.

## 10.5 Accessibility Layout

The hero must support vertical growth.

At larger text sizes, its internal arrangement may stack.

Do not preserve a narrow horizontal composition at the expense of:

- Event title.
- Timing.
- Hazard explanation.
- Guidance.
- Navigation clarity.

The hero remains one coherent accessible element or action.

---

# 11. Supporting Risk Cards

Storm, Severe, and Fire share the same structural presentation.

## 11.1 Shared Content Pattern

Each supporting card contains:

- Semantic symbol.
- Category label.
- Primary risk value or state.
- Concise explanatory text.
- Optional category-specific modifier.
- Navigation affordance.

The category label establishes context.

The value communicates the assessment.

Supporting text explains its meaning.

Avoid repeating information merely to fill the available space.

## 11.2 Storm Risk

Storm Risk retains its categorical severe-weather meaning.

Use the established category label, value, symbol, and semantic color.

Keep the presentation concise.

Do not introduce additional probability or meteorological detail merely because the full-width card provides more space.

## 11.3 Severe Risk

Severe Risk communicates the selected local severe hazard.

The displayed hazard and its semantic coloring must agree.

The card may include conditional intensity when supported by accepted local evidence.

This modifier belongs only to the Severe Risk supporting card within Today's Awareness.

## 11.4 Fire Risk

Fire Risk retains its distinct semantic identity.

Its presentation should be visually consistent with the other supporting cards without implying that fire weather is a convective storm category.

Elevated fire conditions may also be represented by the primary hero when selected by established precedence.

Do not remove Fire Risk from the supporting stack when that occurs.

---

# 12. Conditional Intensity Presentation

Conditional intensity is a modifier of an established severe hazard.

It is not a separate risk category.

The North Star owns the precise meteorological interpretation, eligibility, and freshness requirements.

## 12.1 Today Ownership

The Severe Risk supporting card is the sole Today owner.

Do not move conditional intensity into:

- The primary hero.
- Storm Risk.
- Fire Risk.
- A separate full-width card.
- An unrelated badge area.

This remains true when an active warning owns the primary hero.

## 12.2 Visual Language

Conditional intensity combines:

- Hazard-specific plain-language meaning.
- A subordinate hatch sample.
- Concise supporting explanation.

The hatch is a semantic texture, not decorative artwork.

Users must understand the potential impact without having to interpret the texture alone.

## 12.3 Probability Versus Intensity

Preserve the distinction:

- Risk color represents established probability or categorical meaning.
- Hatching represents potential intensity if the hazard occurs.

Do not increase or alter the probability treatment merely because conditional intensity is elevated.

## 12.4 Layout

Conditional-intensity detail may occupy a distinct region within the Severe Risk card.

Keep the card readable and cohesive.

At accessibility text sizes, allow its internal layout to stack rather than aggressively compressing the explanatory text.

Do not clip the description or allow the hatch to overlap text.

## 12.5 Unavailable Intensity

When supported intensity is unavailable or ineligible, omit the modifier.

Do not display an artificial zero-intensity or quiet indicator.

Do not leave an empty decorative region where intensity would otherwise appear.

---

# 13. Supporting Section Patterns

Today uses two approved supporting-section patterns.

These patterns should be reused rather than introducing a new container treatment for every feature.

## Pattern A: External Heading and Content

Used by:

- Local Alerts.
- Atmospheric Conditions.

Structure:

1. Section heading on the canvas.
2. Supporting content surface beneath it.

The heading remains visually separate from the content container.

This supports clear scanning between sections.

## Pattern B: Self-Contained Summary Card

Used by:

- Storm Setup.
- Outlook Summary.

Structure:

1. Leading semantic symbol.
2. Embedded section heading.
3. Trailing navigation chevron when actionable.
4. Supporting summary or status content.

The card itself provides the section boundary.

Do not add an unnecessary external duplicate heading.

## Shared Rules

Both patterns use the ordinary supporting-content visual family.

Preserve consistent:

- Section rhythm.
- Heading typography.
- Corner relationships.
- Edge restraint.
- Padding relationships.
- Interaction semantics.

Do not force every section into an identical layout.

Consistency is a shared language, not universal component duplication.

---

# 14. Local Alerts

Local Alerts provides the most relevant official alert information and mesoscale discussion context.

It uses Pattern A:

**External heading + content.**

## 14.1 Heading

The heading uses the established Today section-label style.

It may include the existing semantic alert symbol.

Keep it consistent with the Atmospheric Conditions heading.

## 14.2 Alert Center Navigation

When applicable, the heading includes the existing Alert Center navigation action.

The action should remain visually secondary to the section heading.

Do not introduce competing navigation elements.

At accessibility text sizes, allow the heading and action to arrange vertically when needed.

## 14.3 Alert Hierarchy

Preserve the established ordering:

1. Warnings.
2. Watches.
3. Mesoscale discussions.

Do not reorder products based on visual appeal or card size.

## 14.4 Populated State

Display concise alert summaries using established alert components.

Important information includes:

- Event identity.
- Relevant timing.
- Primary threat context.
- Clear access to detail.

Keep supporting metadata subordinate.

Do not create oversized summary cards that compete with the awareness hero.

## 14.5 Multiple Alerts

When multiple alerts exist, preserve established grouping, ordering, and overflow behavior.

Avoid displaying every available alert in full on Today.

The dedicated Alerts experience remains the place for deeper review.

Related detail experiences follow the shared [weather-product detail presentation contract](foundations.md#weather-product-detail-presentation).

The content region must adapt to actual alert counts and lengths.

Do not allow content to overlap, clip, or compete with the following section.

## 14.6 Confirmed Empty State

When the accepted alert state confirms no active local alerts, use the established quiet no-active-alert presentation.

This should feel:

- Calm.
- Intentional.
- Useful.
- Appropriately scoped.

Do not use a broad universal safety statement.

## 14.7 Unavailable or Offline State

Distinguish:

- Confirmed no active alerts.
- Alerts still resolving.
- Alert information unavailable.
- Previously accepted alerts retained while offline.
- Failed refresh with valid cache.

Do not replace cached active alerts with a reassuring empty-state rail during transient refresh.

The accepted-state model determines which content remains visible.

---

# 15. Atmospheric Conditions

Atmospheric Conditions is supporting environmental instrumentation.

It is not another severe-weather risk assessment.

It uses Pattern A:

**External heading + content.**

## 15.1 Established Measurements

The current five measurements are:

1. Air Quality.
2. Visibility.
3. Pressure.
4. Humidity.
5. Wind.

These measurements are peers.

No measurement is promoted to a primary atmospheric hero.

## 15.2 Layout

The approved compact arrangement uses a 3+2 composition at ordinary text sizes.

Maintain a clean, balanced grid with consistent alignment.

The measurements should form one coherent supporting surface.

Do not create five separate floating cards.

At larger Dynamic Type sizes, adapt the layout as necessary to preserve readable content.

## 15.3 Measurement Presentation

Each measurement should have:

- A clear label.
- A readable primary value.
- Appropriate units.
- Supporting context when useful.
- A restrained semantic symbol where it improves recognition.

Avoid adding decorative icons without meaningful purpose.

## 15.4 Air Quality

Preserve established AQI meaning and health-category coloring.

Do not conflate AQI color with convective storm risk.

## 15.5 Visibility

Present current visibility and appropriate supporting meaning.

Keep the measurement concise.

## 15.6 Pressure

Present current pressure and WeatherKit's available pressure trend.

The trend is supporting information, not a separate alert.

Do not introduce new historical pressure infrastructure solely for the presentation.

## 15.7 Humidity

Present relative humidity as environmental context.

Avoid implying that humidity alone determines severe-weather risk.

## 15.8 Wind

Present wind direction and speed.

Include gust information when available and meaningful.

Preserve readable relationships between measurements and units.

## 15.9 Dew Point

Dew point no longer belongs in the main Atmospheric Conditions grid.

Its meteorological interpretation belongs in Storm Setup's Fuel & Instability detail.

Do not restore the older dew-point-led atmospheric rail or standalone dew-point hero.

## 15.10 Visual Treatment

Use the established ordinary supporting-content surface family.

Prefer:

- Neutral opaque background.
- Clear labels and values.
- Consistent measurement spacing.
- Subdued icons.
- Appropriate AQI emphasis.
- Minimal decorative chrome.

Do not add broad risk-colored gradients to the atmospheric section.

Instrumentation should not look like a warning surface.

---

# 16. Storm Setup Summary

Storm Setup is conditional supplemental meteorological guidance.

It uses Pattern B:

**Self-contained summary card.**

## 16.1 Role

The Today presentation should communicate the environmental assessment and its most important supporting or limiting context.

It should not reproduce the full meteorological analysis.

## 16.2 Embedded Header

Use the established embedded header structure:

- Leading symbol.
- Storm Setup title.
- Trailing chevron when navigable.

The entire actionable summary card is the navigation target.

Do not add redundant buttons inside the card.

## 16.3 Summary Content

Prioritize:

- Plain-language assessment.
- Relevant environmental meaning.
- Important limitations or uncertainty.
- Useful supporting context.

Avoid raw diagnostic terminology on the Today surface.

Examples of appropriate language:

- Model signals differ.
- Storm mode is uncertain.

Detailed composite parameters belong in the Storm Setup detail experience when useful.

## 16.4 Presentation States

Storm Setup may present:

- Resolved guidance.
- Analysis in progress.
- No notable setup.
- Analysis not needed.
- Unavailable guidance.

Keep these states distinguishable.

Do not present unavailable analysis as confirmed favorable conditions.

## 16.5 Conditional Placement

Storm Setup appears only when enabled and eligible.

Its supported status states occupy the established Storm Setup section position.

Do not insert temporary cards elsewhere during analysis.

## 16.6 Visual Restraint

Storm Setup is a supporting surface.

Do not give it the same semantic-gradient treatment as the awareness hero.

Avoid introducing a competing large hero presentation.

The detail experience may contain richer meteorological information without changing the Today hierarchy.

---

# 17. Location Reliability

Location Reliability is a conditional, dismissible supporting prompt.

Its purpose is to explain how appropriate location authorization can improve background awareness.

## Presentation

Keep it:

- Concise.
- Respectful.
- Clearly actionable.
- Visually subordinate.
- Consistent with ordinary supporting-content styling.

Do not make it resemble a severe-weather warning.

## Interaction

Preserve:

- The established explanation action.
- The dismissal action.
- Appropriate permission context.
- Existing eligibility behavior.

Do not create a broader permission campaign.

Do not imply guaranteed notification delivery.

## Placement

Location Reliability follows Storm Setup when that section is present.

Otherwise, it follows Atmospheric Conditions.

Do not move it into the primary awareness hierarchy.

---

# 18. Outlook Summary

Outlook Summary provides a concise supporting overview of the accepted convective outlook.

It uses Pattern B:

**Self-contained summary card.**

## 18.1 Embedded Header

Use the established:

- Leading weather symbol.
- Outlook Summary title.
- Trailing chevron when actionable.

Preserve the same general embedded-heading language used by Storm Setup.

## 18.2 Whole-Card Navigation

When an accepted outlook exists, the entire summary card is actionable.

It opens the relevant Convective Outlook detail.

The trailing chevron reinforces that existing navigation.

Do not add a redundant "All Outlooks" action inside the card.

The dedicated Outlooks experience remains available through its established navigation.

## 18.3 Summary Content

Show concise accepted outlook information.

Prioritize readability.

Avoid displaying the entire outlook discussion on Today.

Allow users to navigate for additional detail.

## 18.4 State Handling

Distinguish:

- Available current outlook.
- Cached outlook while refreshing.
- Failed update with accepted cache.
- Confirmed empty response.
- Unavailable outlook.
- Initial resolving state.

When valid accepted content exists, keep it visible while updates proceed.

Do not replace meaningful cached content with a placeholder during routine refresh.

## 18.5 Nonactionable States

When no accepted outlook is available, the card may present a status or unavailable message.

Do not show a navigation chevron unless a supported destination exists.

Do not invent an outlook to make the card navigable.

---

# 19. Attribution

Attribution is secondary supporting information.

It should remain:

- Readable.
- Visually quiet.
- Appropriately placed.
- Consistent with source requirements.

Do not give attribution primary content prominence.

Do not remove required source attribution merely for visual simplicity.

---

# 20. Light and Dark Appearance

Today's appearance follows the shared Foundations document.

## Light Mode

Use the established:

- `#F5F6F7` canvas.
- `#FCFCFD` ordinary content family.
- Restrained neutral edges.
- No ordinary-card drop shadows.
- Adaptive typography.
- Approved semantic awareness gradients.

Ordinary supporting sections should remain neutral and coherent.

Avoid alternating blue, lavender, or gray surface families.

## Dark Mode

Preserve the approved deep navy/charcoal foundation.

Semantic gradients may appear richer than their light equivalents.

Ordinary supporting surfaces should remain calm and integrated.

Avoid muddy colors, excessive shadows, and unnecessary glowing edges.

## Shared Appearance Rules

Do not change approved dark-mode styling merely to simplify a light-mode implementation.

Do not reduce semantic color globally to achieve visual restraint.

Do not make explanatory text look disabled.

Do not rely on translucent materials for legibility.

---

# 21. State-Aware Presentation

Today consumes accepted weather and application state.

It must not independently manufacture weather conclusions.

## Cached-First Presentation

When valid accepted cached information exists:

- Display it immediately.
- Preserve the layout.
- Keep meaningful content visible.
- Resolve forward in place.
- Avoid unnecessary animation.
- Replace content only when a coherent accepted update exists.

## Initial Resolving

A dedicated full-screen resolving presentation is appropriate only when meaningful cached content is unavailable.

Do not display a full-screen loading experience during routine refresh.

## Confirmed Empty

A confirmed empty state communicates that the relevant accepted source contains no applicable information.

It must remain distinguishable from unavailable data.

## Unavailable

Unavailable information should remain clearly identified.

Do not use quiet-state semantics as a fallback for missing or untrusted information.

## Offline

Preserve valid accepted cached information where appropriate.

Communicate offline or stale limitations without overpowering the primary weather content.

## Refresh Activity

Refresh is activity, not a new weather assessment.

Do not animate entire sections merely because data was checked.

Avoid unnecessary placeholder re-entry, card disappearance, or badge flicker.

The detailed behavioral contract belongs in [States and Accessibility](states-accessibility.md).

---

# 22. Accessibility and Responsive Behavior

Today must preserve its information hierarchy under accessibility adaptation.

## Dynamic Type

Allow essential information to grow vertically.

Prioritize:

- Risk values.
- Event titles.
- Timing.
- Threat explanations.
- Alert guidance.
- Navigation comprehension.

Do not reduce text to unreadable sizes to preserve fixed geometry.

## VoiceOver

Ensure that:

- Primary awareness meaning is clear.
- Actionable cards expose appropriate button semantics.
- Navigation destinations have useful accessible hints.
- Decorative icons, rails, and chevrons do not create redundant announcements.
- Conditional intensity includes accessible explanatory meaning.
- Unavailable states remain distinct from quiet states.

## Increase Contrast

Preserve readable text and meaningful card boundaries.

Strengthen established adaptive treatments as necessary.

Do not introduce an unrelated high-contrast visual system.

## Reduce Motion

Disable unnecessary presentation animation.

Preserve clear state transitions and complete weather meaning.

## Device Width

Review Today on both ordinary and larger iPhone sizes.

Do not allow available width alone to reintroduce the paired supporting-risk layout.

Internal content may adapt when necessary for readability.

## General Rule

Accessibility adaptation may change internal arrangement without changing product meaning or the established hierarchy.

---

# 23. Implementation Boundaries

The Today design system is implemented through existing SwiftUI presentation components.

Before changing it:

1. Inspect the current code.
2. Identify the real component owner.
3. Confirm established behavior.
4. Read the relevant design contract.
5. Preserve existing semantic mappings.
6. Apply a focused change.
7. Validate the resulting composition.
8. Stop when the intended visual behavior is correct.

## High-Value Investigation Starting Points

Existing presentation ownership includes components such as:

- `SummaryView`
- `PrimaryAwarenessPanel`
- `PrimaryAwarenessHeroView`
- `AwarenessSupportRow`
- `OutlookSummaryCard`
- `ActiveAlertSummaryView`
- `TodaySurfaceStyle`

These are orientation points, not an exhaustive implementation boundary.

Follow actual dependencies before modifying shared code.

## Avoid Scope Expansion

Do not treat Today styling as authorization to:

- Change weather interpretation.
- Change warning precedence.
- Modify accepted-state ownership.
- Add persistence fields.
- Add network requests.
- Change Map data semantics.
- Introduce new forecast capabilities.
- Redesign unrelated views.
- Add a broad styling framework.

## Shared Modifier Discipline

Some presentation modifiers and color assets are used throughout the application.

Before changing them, inspect their consumers.

A Today-specific improvement must not accidentally repaint Settings, onboarding, diagnostics, or unrelated detail screens.

Prefer the smallest coherent presentation change.

---

# 24. Today Visual Validation

Visual acceptance requires representative rendered evidence.

A successful build alone does not prove visual correctness.

## Required Weather States

Review:

- Quiet weather.
- Elevated storm risk.
- Elevated severe hazard.
- Elevated fire risk.
- Active Severe Thunderstorm Warning.
- Active Tornado Warning.
- Active watch.
- Cached refreshing.
- Offline with accepted content.
- Unavailable data.
- Initial resolving state.

Not every narrow implementation requires the full matrix.

Validation should be proportional to the affected surface.

## Required Appearance Coverage

Review meaningful affected states in:

- Light appearance.
- Dark appearance.

For semantic-gradient changes, both appearances are mandatory.

## Device Coverage

Review at least:

- A standard Pro-sized iPhone.
- A larger Pro Max-sized iPhone.

Check for unexpected responsive layout changes.

## Content Coverage

Include:

- Short and long event names.
- Multiple active alerts.
- Long supporting explanations.
- Conditional-intensity detail.
- Missing optional information.
- Unavailable supporting sections.
- Large Dynamic Type.

## Review the Whole Screen

Do not evaluate only individual card crops.

A component can look correct in isolation and still produce a poor full-screen composition.

Check:

- Overall information hierarchy.
- Section spacing.
- Surface consistency.
- Light/dark balance.
- Semantic color accuracy.
- Gradient quality.
- Text contrast.
- Navigation affordances.
- Card width and alignment.
- Content wrapping.
- Overlap and clipping.
- Visual competition between sections.

## Approved Visual Baseline

Use the [approved implementation baseline in Visual Review](visual-review.md#approved-application-screenshots) as the authoritative visual reference.

The accepted quiet-state emerald/jade treatment and approved elevated/warning presentations form the baseline for future refinements.

Generated mockups are secondary design references.

Do not treat incidental generated imagery or controls as product requirements.

Detailed validation procedures belong in [Visual Review](visual-review.md).

---

# 25. Design Anti-Patterns

Avoid:

- Multiple competing hero cards.
- Side-by-side Storm and Severe cards on iPhone.
- Full-surface decorative color flooding.
- Muddy or abruptly terminating gradients.
- Washed-out quiet-state presentation.
- Animated semantic gradients.
- Decorative radar or map backgrounds.
- Misleading navigation chevrons.
- Redundant buttons inside summary cards.
- Inconsistent section-heading treatments.
- Returning to the old dew-point rail.
- Giving Atmospheric Conditions warning-level emphasis.
- Treating unavailable information as quiet weather.
- Replacing cached content during routine refresh.
- Overlapping or clipped weather explanations.
- Arbitrary fixed-height cards.
- Unnecessary nested containers.
- Excessive Liquid Glass.
- Light-mode shadows without justification.
- Global styling changes for a local component issue.
- Introducing new data or domain logic merely to support presentation.

---

# 26. Definition of Success

The Today design succeeds when:

1. The current location and conditions are immediately recognizable.

2. Today's Awareness is clearly the visual center of the experience.

3. The primary hero communicates the most important local signal.

4. Storm, Severe, and Fire remain visible and easy to compare.

5. Semantic gradients provide meaningful identity without overwhelming content.

6. Navigation is discoverable and accurately represented.

7. Local Alerts remain readable and appropriately prioritized.

8. Atmospheric Conditions provides useful context without competing with severe-weather awareness.

9. Storm Setup and Outlook Summary share an intentional supporting presentation language.

10. Quiet, elevated, warning,
    cached, offline, and unavailable
    states remain coherent.

11. Light and dark appearances
    both feel deliberately designed.

12. Accessibility adaptations
    preserve essential weather meaning.

13. The complete screen feels
    like one cohesive product.

---

# Final Today Principle

**Today's Awareness is the heart of the SkyAware experience.**

The interface should guide the user from immediate conditions to the most important severe-weather information, then into supporting context when desired.

Its identity comes from the combination of:

- Calm neutral foundations.
- Purposeful semantic weather color.
- Clear and consistent hierarchy.
- Honest navigation.
- Accurate meteorological meaning.
- Careful attention to every state.

The goal is not to display the greatest amount of information.

The goal is to make the most important information immediately understandable.

**Make Today's weather picture clear, calm, actionable, and unmistakably SkyAware.**
