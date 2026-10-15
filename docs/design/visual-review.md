---
title: SkyAware Visual Review and Acceptance
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - design
  - visual-review
  - quality
  - accessibility
---

# SkyAware Visual Review and Acceptance

## Purpose

This document defines how SkyAware's visual and interaction design is evaluated, validated, and accepted.

Its purpose is to:

- Preserve the established SkyAware design language.
- Prevent visual and interaction regressions.
- Validate realistic weather and application states.
- Protect accessibility and meteorological meaning.
- Identify genuine defects before release.
- Avoid unnecessary redesign and endless refinement.
- Provide clear evidence that visual work is complete.

This document defines a lightweight review discipline.

It is not a separate implementation lifecycle, a mandatory screenshot-testing framework, or a replacement for engineering review.

Related documentation:

- [Design System](README.md)
- [Foundations](foundations.md)
- [North Star](../product/north-star.md)
- [Brand and Voice](../brand/brand-and-voice.md)
- [Today](today.md)
- [Map](map.md)
- [Widgets](widgets.md)
- [States and Accessibility](states-accessibility.md)

The relevant canonical design specification establishes the intended result.

This document establishes how that result is evaluated.

---

# 1. Review Philosophy

SkyAware must feel like one carefully designed product.

Visual quality is established through:

- Clear information hierarchy.
- Accurate weather semantics.
- Consistent visual relationships.
- Readable typography.
- Purposeful semantic color.
- Appropriate native interaction.
- Stable state transitions.
- Accessible presentation.
- Correct layout across supported devices.
- Deliberate restraint.

## Primary Principle

**Review the complete user experience, not merely the appearance of individual components.**

A component may look excellent in isolation while creating a poor full-screen composition.

A layout may work in one simulator while failing on another device.

A widget may look correct with one alert while overlapping content with five.

A successful build does not establish visual correctness.

## Review for Meaning

A visually attractive design is not acceptable if it changes or obscures the underlying weather meaning.

Correctness includes:

- Risk category.
- Alert identity.
- Geographic relevance.
- Probability versus intensity.
- Freshness and availability.
- Navigation destinations.
- Accessible interpretation.

Meteorological meaning takes priority over visual preference.

## Review for Consistency

A new component should feel consistent with its surrounding interface.

It should not introduce a different visual language merely because another treatment looks attractive.

Prefer established patterns before creating something new.

---

# 2. Review Scope

Visual verification should be proportional to the actual change.

Not every modification requires the complete acceptance matrix.

## Level 1: Localized Presentation Change

Examples:

- Correcting text spacing.
- Adjusting one icon.
- Fixing a local alignment issue.
- Improving a specific label.
- Correcting one card's contrast.

Expected review:

- Inspect the affected component.
- Inspect its surrounding composition.
- Review relevant light/dark appearances.
- Check applicable accessibility behavior.
- Verify existing interactions remain intact.

Do not perform a full application audit for a narrowly scoped correction.

## Level 2: Shared Component or Surface Change

Examples:

- Updating an awareness-card family.
- Changing shared typography.
- Refining a supporting-section pattern.
- Changing Map legends.
- Modifying medium or large widget layouts.

Expected review:

- Inspect the affected component family.
- Review representative content states.
- Review both appearances.
- Check relevant device sizes.
- Validate adaptive layouts.
- Check affected accessibility behavior.
- Inspect actual shared-style consumers.

## Level 3: Broad Design or Navigation Change

Examples:

- A substantial screen redesign.
- A new navigation structure.
- A shared visual-foundation change.
- A redesign spanning multiple surfaces.
- A major accessibility refactor.

Expected review:

- Complete affected-screen compositions.
- Representative weather and availability states.
- Both appearances.
- Multiple device sizes.
- Relevant WidgetKit rendering modes.
- Accessibility.
- Interaction behavior.
- State transitions.
- Cross-surface consistency.
- Appropriate regression tests.

## Scope Rule

Increase review breadth when the implementation boundary is shared or the consequences are difficult to isolate.

Do not increase breadth simply because a visual change is interesting.

## Debug Preview: Today No-Cache Resolving

To inspect the dedicated resolving presentation on a simulator or connected iPhone without changing saved weather data,
use a Debug Run and add this launch environment variable in Xcode:

1. Open **Product → Scheme → Edit Scheme**.
2. Select **Run → Arguments → Environment Variables**.
3. Add `SKYAWARE_DEBUG_SHOW_NO_CACHE_RESOLVING` with value `1`.
4. Run the app and open Today. Remove the variable or set it to `0` to return to normal presentation.

The override affects only Today presentation in Debug builds. It does not change the app's accepted data or other tabs. The regular no-cache path and `UI_TESTS_NO_CACHE_RESOLVING` UI-test fixture remain separate.

---

# 3. Establish the Review Baseline

Before evaluating a change, understand what it is intended to accomplish.

## Required Context

Identify:

1. The requested behavior or visual improvement.
2. The current implementation.
3. The relevant canonical design specification.
4. Existing product and weather semantics.
5. The surfaces affected by the change.
6. Established behavior that must not change.

## Current Implementation

Inspect the actual presentation owner.

Do not assume ownership from filenames.

Follow relevant dependencies, including shared modifiers, styles, navigation, and presentation state.

## Approved Design

Use the applicable canonical documentation to establish intended presentation.

Do not infer new requirements from exploratory mockups.

## Preserve Unrelated Behavior

A presentation change should not implicitly modify:

- Weather interpretation.
- Alert precedence.
- Accepted-state ownership.
- Persistence.
- Notification behavior.
- Map geometry.
- Navigation destinations.
- Location eligibility.
- Background refresh.

If broader changes are necessary, identify them explicitly.

---

# 4. Visual Reference Authority

Visual references have different levels of authority.

Use them accordingly.

## Canonical Specifications

The current design documents define accepted design requirements.

Their explicit rules take precedence over incidental screenshot details.

## Approved Application Screenshots

Approved screenshots from the implemented application demonstrate the accepted visual direction.

The approved Today implementation baseline is:

| State | Light appearance | Dark appearance |
| --- | --- | --- |
| Quiet awareness | [docs/images/issue-673/quiet-light-after.png](../images/issue-673/quiet-light-after.png) | [docs/images/issue-673/quiet-dark-after.png](../images/issue-673/quiet-dark-after.png) |
| Elevated risk | [docs/images/issue-673/elevated-light-after.png](../images/issue-673/elevated-light-after.png) | [docs/images/issue-673/elevated-dark-after.png](../images/issue-673/elevated-dark-after.png) |
| Warning state | [docs/images/issue-673/warning-light-after.png](../images/issue-673/warning-light-after.png) | [docs/images/issue-673/warning-dark-after.png](../images/issue-673/warning-dark-after.png) |

These implemented screenshots establish the approved awareness gradients and composition in both appearances. Before images and exploratory generated mockups are not part of this approved baseline. Incidental screenshot details do not introduce additional product or design requirements.

They are valuable for evaluating:

- Overall composition.
- Color balance.
- Hierarchy.
- Spacing relationships.
- Surface character.
- Visual consistency.

## Current-State Screenshots

Current screenshots establish what the application actually renders.

They are evidence of behavior, not automatically evidence of intended design.

A current screenshot may contain the defect being corrected.

## Generated Mockups

Generated mockups communicate design concepts.

They may be useful for:

- General hierarchy.
- Relative density.
- Composition.
- Visual character.
- Semantic color placement.

They are not authoritative for:

- Exact dimensions.
- SwiftUI behavior.
- System navigation.
- SF Symbols.
- Weather values.
- Branding assets.
- New functionality.
- Map layers.
- Exact gradient parameters.

Never implement an unsupported feature because it appears in a generated image.

## Historical References

Historical redesign materials may remain under:

`docs/design/redesign-2026/`

They provide context for previous decisions.

They do not override current canonical design specifications.

---

# 5. Visual Review Procedure

Use the following process for meaningful UI work.

## Step 1: Understand the Change

Determine:

- What is changing?
- Why is it changing?
- Which user problem does it solve?
- What must remain unchanged?
- Which design specification applies?

Avoid beginning with styling experiments.

## Step 2: Inspect the Current State

Review relevant code and available rendered evidence.

Identify the real presentation and state owners.

Inspect shared consumers before changing shared styles.

## Step 3: Establish Expected Behavior

Describe the intended visual or interaction outcome.

Prefer measurable requirements.

Examples:

- Supporting risk cards remain full-width.
- A noninteractive hero has no chevron.
- Alert overflow does not overlap the footer.
- Cached alerts remain visible during refresh.
- Long warning text remains readable.

## Step 4: Implement the Smallest Coherent Change

Preserve established components and behavior where possible.

Do not introduce a new styling framework for a localized problem.

Prefer existing native SwiftUI behavior and shared conventions.

## Step 5: Validate Rendered Results

Use deterministic previews and representative rendered screens where practical.

Inspect the complete affected composition.

Review applicable:

- Weather states.
- Availability states.
- Light and dark appearance.
- Device widths.
- Dynamic Type.
- Native interaction.

## Step 6: Evaluate Regressions

Check that the change did not:

- Break nearby layout.
- Weaken text contrast.
- Alter semantic color.
- Change navigation.
- Introduce clipping.
- Cause refresh churn.
- Affect unrelated shared consumers.

## Step 7: Determine Acceptance

Identify:

- Confirmed defects.
- Unsupported assumptions.
- Unverified requirements.
- Optional polish.

Correct genuine defects.

Do not reopen settled design decisions without cause.

## Step 8: Stop

Stop when:

- The intended design is satisfied.
- Relevant behavior is correct.
- Appropriate validation is complete.
- No material unresolved defects remain.

Avoid speculative refinement.

---

# 6. Composition Review

Review complete screen relationships, not only individual component crops.

## Visual Hierarchy

Ask:

- What draws attention first?
- Is that the correct information?
- Are supporting elements subordinate?
- Does the interface communicate an obvious scanning order?

## Surface Relationships

Check:

- Canvas and content separation.
- Consistent surface families.
- Appropriate corner relationships.
- Restraint in borders and shadows.
- Necessary versus redundant containers.

## Typography

Check:

- Primary value prominence.
- Section-heading consistency.
- Supporting-copy contrast.
- Appropriate text wrapping.
- Clear measurement units.
- Readable metadata.

## Semantic Color

Check:

- Correct risk or hazard identity.
- Recognizable quiet-state color.
- Appropriate elevated-state emphasis.
- Consistent icon and accent meaning.
- Legible foreground content.

## Density

Check:

- Unnecessary empty space.
- Overcrowded content.
- Excessive decorative padding.
- Competing visual groups.
- Long text handling.

## Interaction

Check:

- Tappable components look actionable.
- Noninteractive components do not.
- Chevrons correspond to destinations.
- Native controls behave predictably.
- There are no redundant actions.

---

# 7. Light and Dark Appearance

Both appearances are first-class.

Do not validate one and assume the other is correct.

## Light Mode

Review against the established neutral foundation:

- `#F5F6F7` application canvas.
- `#FCFCFD` ordinary content surfaces.
- Restrained borders.
- No ordinary-card drop shadows.
- Readable secondary text.
- Purposeful semantic weather color.

Avoid:

- Icy blue-gray surfaces.
- Lavender neutral backgrounds.
- Washed-out supporting text.
- Excessive floating-card separation.
- Decorative shadows.
- Weak or muddy semantic accents.

## Dark Mode

Review the established deep navy/charcoal foundation.

Check:

- Surface separation.
- Text readability.
- Gradient richness.
- Semantic color integrity.
- Restrained edges.
- Native control behavior.

Avoid:

- Muddy gray surfaces.
- Excessive glow.
- Washed-out hazard colors.
- Competing dark surface tones.
- Excessive elevation.

## Appearance-Specific Changes

When refining one appearance, verify the other remains consistent.

Do not force identical gradient values or opacities across light and dark.

Matching code does not guarantee matching visual quality.

---

# 8. Semantic Gradient Review

Today's Awareness has an approved semantic-gradient system.

It requires focused evaluation.

## Quiet States

The approved quiet treatment uses a recognizable emerald/jade color near the leading rail.

The gradient fades smoothly into the established neutral surface.

Check that it is:

- Calm.
- Recognizable.
- Clean.
- Continuous.
- Readable.
- Distinctly SkyAware.

Avoid:

- Muddy green.
- Washed-out mint.
- Nearly invisible color.
- Abrupt termination.
- Broad pastel flooding.

## Elevated States

Review representative:

- Storm Risk.
- Tornado.
- Wind.
- Hail.
- Fire Risk.
- Active warning.

Check that each uses its established semantic identity.

Elevated colors should feel stronger than quiet states without overwhelming the content.

## Gradient Transition

Inspect the entire card width.

Check:

- Leading color presence.
- Smooth middle transition.
- Natural trailing blend.
- No visible gradient edge.
- No abrupt desaturation.
- No clipping outside the card.

## Hero and Supporting Cards

Verify that:

- The hero remains dominant.
- The three supporting cards form one visual family.
- Semantic rails align consistently.
- Chevrons are readable when actionable.
- Text remains legible over color.

## Scope

This gradient treatment belongs to the approved awareness surfaces.

Do not spread it into ordinary supporting content without a separate design decision.

---

# 9. Today Review

Today is SkyAware's primary user experience.

Review it as a complete composition.

## Current Conditions

Check:

- Clear location context.
- Prominent temperature.
- Supporting condition symbol.
- Compact open-header treatment.
- Stable presentation during refresh.

## Today's Awareness

Check:

- Correct primary hero.
- Clear risk hierarchy.
- Appropriate semantic gradient.
- Consistent rails and chevrons.
- Full-width supporting risk cards.
- Correct Storm, Severe, Fire order.

## Supporting Risk Layout

On iPhone:

- Storm Risk is full-width.
- Severe Risk is full-width.
- Fire Risk is full-width.
- All three stack vertically.

Do not reintroduce the superseded paired layout on wider devices.

## Local Alerts

Check:

- Consistent external heading.
- Correct alert priority.
- Readable event information.
- Appropriate no-alert presentation.
- Clear access to alert detail.
- No false empty state during refresh.

## Atmospheric Conditions

Check the established five metrics:

- Air Quality.
- Visibility.
- Pressure.
- Humidity.
- Wind.

At ordinary text sizes, verify the approved compact 3+2 arrangement.

Ensure the section remains visually subordinate.

Do not restore the old dew-point-led presentation.

## Storm Setup and Outlook Summary

Check:

- Consistent embedded headers.
- Appropriate supporting typography.
- Single honest navigation affordance.
- No redundant actions.
- Correct conditional visibility.

## Overall Composition

Verify that Today's Awareness remains the visual center.

Supporting content should not accumulate enough color or elevation to compete.

---

# 10. Map Review

The Map is a spatial weather-awareness surface.

Review the relationship between geography, overlays, and controls.

## Geographic Content

Check:

- Map remains visually dominant.
- Risk polygons are recognizable.
- Geography remains readable.
- Warning areas remain distinct.
- Overlays match selected data.

## Controls

Check:

- Native layer selector.
- Correct selected-layer label.
- Active Alerts visibility toggle.
- Compact floating presentation.
- Appropriate native materials.

## Legends

Review:

- Inline legend.
- Stacked legends.
- Compact legend trigger.
- Expanded legend sheet.
- Active warning legend.

Check that legends remain readable without unnecessarily obscuring the map.

## Conditional Intensity

Verify:

- Probability uses color.
- Intensity uses hatching.
- Hatch texture remains recognizable.
- Hatching explanations are available.
- Legend samples match the Map.
- Unsupported levels are absent.

## Camera Continuity

Verify that:

- Routine refresh does not recenter.
- Layer changes preserve established camera behavior.
- Warning visibility does not change unrelated camera state.

## Accessibility

Review:

- Accessible selected-layer meaning.
- Geographic-risk relationship.
- Non-color differentiation.
- Legend explanations.
- Dynamic Type adaptation.

---

# 11. Widget Review

Widgets must be validated within their actual WidgetKit bounds.

Component previews alone are insufficient.

## Small Widgets

Review:

- Storm Risk.
- Severe Risk.
- Quiet states.
- Elevated states.
- Long risk labels.
- Unavailable information.

Check that one primary awareness concept remains clear.

## Medium Widgets

Review:

- No active alerts.
- One active alert.
- Multiple active alerts.
- Overflow count.
- Supporting risk summaries.
- Long location names.
- Stale and unavailable states.

Check that primary awareness remains stronger than supporting risk information.

## Large Widgets

Review at least:

- Zero active alerts.
- One active alert.
- Two active alerts.
- Three active alerts.
- Five or more active alerts.

Include realistic:

- Long warning titles.
- Different alert types.
- Alert expiration wording.
- Elevated supporting risks.
- Long location names.
- Larger text sizes.

## Large Widget Layout Integrity

Verify that:

- Alert rows remain readable.
- Overflow count is accurate.
- Overflow text is fully visible.
- The footer begins after all alert content.
- Footer semantic rails remain within their own region.
- Storm, Severe, and Fire remain legible.
- No content overlaps.
- No content escapes WidgetKit bounds.

This is a required regression scenario for large-widget layout changes.

## Lock Screen

Review supported:

- Circular.
- Rectangular.
- Inline.

Check complete meaning in system-controlled accessory presentation.

## Rendering Modes

Where supported, inspect:

- Full color.
- Accented or tinted.
- Vibrant.
- Background removed.

Do not assume full-color rendering predicts every system transformation.

---

# 12. State Review

Visual changes must preserve the distinction between weather information and refresh activity.

## High-Value States

Review relevant combinations of:

| State | Expected presentation |
| --- | --- |
| Quiet | Calm, complete, appropriately scoped |
| Elevated risk | Clear semantic emphasis |
| Active warning | Stronger primary awareness |
| Cached refreshing | Accepted content remains visible |
| Refresh failed with cache | Accepted content remains; limitation is clear |
| Offline with cache | Applicable saved content remains visible |
| No-cache resolving | Intentional resolving experience |
| Confirmed empty | Scoped absence of applicable information |
| Unavailable | Missing information is acknowledged |
| Location changed | Old-location data is not misrepresented |
| Source revision changed | New accepted information replaces old coherently |

## State Continuity

Check for:

- Disappearing cards.
- Temporary empty alert states.
- Flickering badges.
- Repeated entrance animations.
- Unnecessary placeholder re-entry.
- Repeated changes to unchanged values.
- Map polygon disappearance.
- Unexpected camera movement.
- Scroll position resets.

## Failure With Cache

A failed refresh should not automatically clear accepted information.

The interface should remain useful and honest.

## Unknown Is Not Quiet

Unresolved or unavailable weather information must never appear as a confirmed quiet-weather assessment.

This is both a design and product correctness requirement.

---

# 13. Accessibility Review

Accessibility validation should match the affected change.

For meaningful component changes, consider the following.

## Dynamic Type

Check:

- Natural text wrapping.
- Vertical content growth.
- Alternate layouts when needed.
- Complete weather explanations.
- Readable navigation controls.
- No overlapping elements.

Do not preserve fixed geometry at the expense of essential content.

## VoiceOver

Check:

- Meaningful labels.
- Appropriate values.
- Correct button traits.
- Honest navigation hints.
- Logical reading order.
- No duplicate decorative announcements.
- Distinct unavailable and quiet states.

## Increase Contrast

Check:

- Readable primary text.
- Legible supporting prose.
- Visible control boundaries.
- Correct semantic color treatment.
- Sufficient contrast over gradients.

## Differentiate Without Color

Check that:

- Risk categories remain identifiable.
- Map legends remain understandable.
- Conditional intensity has a textual explanation.
- Status meaning remains clear.

## Reduce Motion

Check that:

- Decorative motion is absent.
- Routine refresh is calm.
- Meaningful changes remain understandable.
- No information depends on animation.

## Reduce Transparency

Check that:

- Weather content remains readable.
- Native controls adapt appropriately.
- Map legends remain distinguishable.
- No custom translucent content becomes difficult to interpret.

## Interaction Targets

Check appropriate touch-target sizes.

Verify that entire actionable cards remain tappable.

Decorative chevrons should not create separate accessibility actions.

---

# 14. Device and Environment Coverage

Device size can change layout behavior unexpectedly.

The redesign demonstrated that a wider iPhone may activate a different adaptive composition than a smaller simulator.

This must be considered during review.

## iPhone Coverage

For meaningful responsive changes, review at least:

- One standard Pro-sized iPhone.
- One larger Pro Max-sized iPhone.

Use a smaller constrained device when relevant.

Do not assume that additional width improves every layout.

Preserve established information hierarchy.

## Appearance

Review meaningful affected states in light and dark mode.

Do not rely on a single appearance for acceptance.

## Real Rendering

Prefer:

- Actual SwiftUI previews.
- Simulator screenshots.
- Physical-device screenshots when available and useful.

Do not assume an isolated component preview establishes the complete layout.

## Environment Variation

Review relevant changes with:

- Short and long content.
- Ordinary Dynamic Type.
- Accessibility text sizes.
- Increased contrast.
- Different availability states.
- Multiple alert counts.
- System-controlled rendering modes.

Choose a representative matrix, not every mathematical combination.

---

# 15. Deterministic Preview Fixtures

SkyAware already includes useful SwiftUI and WidgetKit preview infrastructure.

Reuse it.

## Goals

Fixtures should make important states reproducible without requiring live severe weather.

They should allow developers and reviewers to inspect specific visual behavior reliably.

## High-Value Fixtures

Examples include:

- Quiet weather.
- Elevated storm risk.
- Tornado primary awareness.
- Active Severe Thunderstorm Warning.
- Active Tornado Warning.
- Multiple local alerts.
- No active alerts.
- Cached refreshing.
- Offline with cache.
- Unavailable information.
- Conditional intensity.
- Widget overflow.
- Long text.
- Large Dynamic Type.

## Fixture Quality

Fixtures should:

- Represent valid domain states.
- Use meaningful weather terminology.
- Exercise realistic content variation.
- Avoid impossible combinations unless deliberately testing resilience.
- Remain deterministic where practical.

## Avoid Overbuilding

Do not create:

- A large visual-fixture framework.
- An elaborate screenshot-generation pipeline.
- Thousands of combinations.
- A separate state simulator for every component.

Add a fixture when it protects a real design or correctness concern.

A small, useful fixture library is preferable to a large speculative one.

---

# 16. Screenshot Review

Screenshots are valuable evidence of visual quality.

They must be evaluated in context.

## Good Screenshot Evidence

A useful screenshot identifies:

- Affected screen or widget family.
- Relevant weather state.
- Light or dark appearance.
- Device size or widget family.
- Important accessibility settings.
- The visual behavior being evaluated.

## Full Composition First

Begin with the complete screen or widget.

Determine whether the overall hierarchy and surface relationships are correct.

Then inspect relevant component details.

## Component Crops

Crops are useful for:

- Typography.
- Gradient transitions.
- Border treatment.
- Icon alignment.
- Small spacing defects.

They should supplement, not replace, full-screen review.

## Before and After

For a targeted correction, compare equivalent states when possible.

Avoid comparing:

- Different weather risks.
- Different alert counts.
- Different appearances.
- Different device widths.

unless those differences are the subject of the review.

## Limits of Screenshots

A static image cannot prove:

- Navigation behavior.
- Touch-target correctness.
- VoiceOver semantics.
- Refresh continuity.
- Reduced-motion behavior.
- Live Map interaction.

Validate these separately when they matter.

---

# 17. Visual Defect Classification

Not every visual observation requires another implementation pass.

Classify findings according to their consequence.

## Release-Blocking Defects

Examples:

- Incorrect weather meaning.
- Misleading quiet or warning state.
- Essential content clipped or hidden.
- Overlapping alert information.
- Broken navigation affordance.
- Unusable accessibility interaction.
- Incorrect semantic hazard coloring.
- Failed accepted-state continuity.
- Major contrast failure.
- Important controls inaccessible on supported devices.

These require correction before accepting the affected work.

## Material Design Regressions

Examples:

- Approved hierarchy is weakened.
- Light and dark appearance diverge from their accepted direction.
- Supporting cards use inconsistent geometry.
- Interaction becomes difficult to discover.
- Shared styling changes affect unrelated application surfaces.
- Unexpected responsive layout alters established composition.

Correct when attributable to the change under review.

## Minor Polish

Examples:

- Small nonfunctional spacing differences.
- Subjective gradient preferences.
- Slight differences in visual weight.
- Optional animation refinements.
- Minor alignment improvements without readability consequences.

These do not automatically justify another implementation cycle.

## Speculative Preferences

Examples:

- A different color might be nicer.
- A new layout might feel more modern.
- Another animation might feel premium.
- A different card style might be interesting.

These are not defects.

Do not reopen settled design decisions based on preference alone.

---

# 18. Review Findings

A useful visual finding should be specific and actionable.

## Preferred Finding Structure

Include:

1. The affected surface.
2. The observed behavior.
3. The expected behavior.
4. The violated design invariant.
5. The conditions needed to reproduce it.
6. Relevant screenshot or rendered evidence.
7. The smallest appropriate correction boundary.

## Example

Affected surface:

Large Home Screen widget.

Observed:

With five active alerts, the overflow indicator overlaps the supporting risk footer.

Expected:

Alert rows, overflow indication, and risk footer occupy distinct nonoverlapping regions.

Violated invariant:

Active-alert readability and widget layout containment.

Scope:

Correct large-widget layout without changing other families or weather semantics.

This is a meaningful, reproducible finding.

## Avoid Vague Findings

Avoid requests such as:

- Make it more premium.
- Improve the spacing.
- Make it look more Apple-like.
- Polish the whole screen.
- Modernize the cards.

These do not establish measurable acceptance criteria.

Translate genuine concerns into observable behavior.

---

# 19. Design Review and Engineering Review

Visual review and engineering review overlap, but they have distinct responsibilities.

## Visual Review

Evaluates:

- Hierarchy.
- Readability.
- Semantic presentation.
- Layout.
- Interaction discoverability.
- Appearance consistency.
- Accessibility presentation.
- Full-screen coherence.

## Engineering Review

Evaluates:

- State ownership.
- Swift concurrency safety.
- Persistence correctness.
- Domain behavior.
- Data integrity.
- Performance.
- Resource usage.
- Deterministic tests.
- Architectural maintainability.

## Shared Concerns

Both should protect:

- Accepted-state continuity.
- Weather interpretation.
- Navigation correctness.
- Accessibility.
- Predictable interaction.
- Avoidance of unnecessary complexity.

## Workflow Ownership

Visual review does not replace the established issue lifecycle, code review, or audit process.

When another workflow owns implementation and approval, apply this document within that workflow.

Do not create parallel approval ceremonies.

---

# 20. Review Evidence and Reporting

Visual review should produce enough evidence to support an acceptance decision.

It should not create unnecessary administrative work.

## For Localized Changes

A concise review statement may be sufficient.

Example:

"Verified the affected card in light and dark mode. No text clipping or navigation regression observed."

Only claim checks that were actually performed.

## For Shared Surface Changes

Provide:

- Relevant screenshots or previews.
- States examined.
- Device or family coverage.
- Accessibility checks performed.
- Known limitations.
- Confirmed findings, if any.

## For Broad Audits

Summarize:

- Scope.
- Canonical design references.
- Representative evidence.
- Material findings.
- Correctness or trust risks.
- Recommended focused corrections.
- Acceptance recommendation.

## Evidence Integrity

Do not claim:

- Device verification when only a preview was inspected.
- VoiceOver validation without actually testing VoiceOver.
- Runtime behavior from static screenshots alone.
- Full regression coverage from one happy-path fixture.
- A visual defect is fixed merely because code compiles.

When evidence is unavailable, state that limitation.

This is preferable to inventing confidence.

---

# 21. Avoiding Design Drift

SkyAware's established visual language should remain stable between meaningful product changes.

## Preserve Approved Decisions

Do not casually revisit:

- Today's four-card awareness system.
- Full-width supporting risk cards.
- Semantic rails and gradients.
- Approved light-mode neutral surfaces.
- Established dark-mode identity.
- Honest navigation chevrons.
- Supporting-section patterns.
- Atmospheric Conditions hierarchy.
- Native Map controls and legends.
- Widget family responsibilities.

## Valid Reasons to Reconsider

A settled decision may be reconsidered when there is:

- A demonstrated usability problem.
- An accessibility failure.
- A correctness issue.
- A platform compatibility problem.
- A reproducible layout defect.
- A genuine product requirement.
- Clear evidence that a simpler approach is better.

## New Design Decisions

When a new decision is approved:

1. Update its canonical owner.
2. Remove contradictory guidance.
3. Update useful reference evidence.
4. Avoid duplicating specifications.
5. Preserve unrelated decisions.

Do not add permanent documentation for every rejected experiment.

Git history and issue discussions preserve the exploration.

Canonical documents preserve the accepted direction.

---

# 22. Stop Conditions

Visual work should end when it satisfies the established design requirements.

## Ready to Accept

A change is ready when:

- Intended behavior is implemented.
- Correct weather meaning is preserved.
- Relevant visual states are coherent.
- Applicable light/dark behavior is correct.
- Layout works on relevant devices.
- Accessibility requirements are met.
- Navigation remains truthful.
- No material regressions remain.
- Appropriate verification is complete.

## Not Ready

A change is not ready when:

- Important information overlaps.
- Essential text is clipped.
- Navigation is misleading.
- Weather meaning is inaccurate.
- Unavailable is presented as quiet.
- Important accessibility behavior fails.
- State transitions create false changes.
- The change damages unrelated surfaces.

## Diminishing Returns

Stop further refinement when remaining concerns are:

- Speculative.
- Subjective.
- Unrelated to the agreed scope.
- Unsupported by rendered evidence.
- Minor enough that continued iteration risks destabilizing an already accepted design.

Do not keep changing a successful component merely because alternatives exist.

## Release Readiness

A visually accepted change must still satisfy applicable engineering, testing, and release requirements.

Visual acceptance is not a substitute for product or technical correctness.

---

# 23. Final Review Checklist

Before accepting meaningful visual work, confirm:

## Product Meaning

- [ ] Weather meaning is correct.
- [ ] Uncertainty is preserved.
- [ ] Quiet and unavailable are distinct.
- [ ] Official alerts retain correct priority.

## Visual Identity

- [ ] The result feels recognizably SkyAware.
- [ ] The established hierarchy is preserved.
- [ ] Semantic colors are appropriate.
- [ ] Surfaces and typography are consistent.
- [ ] Decoration remains restrained.

## Appearance

- [ ] Relevant light-mode states were reviewed.
- [ ] Relevant dark-mode states were reviewed.
- [ ] Important text remains readable.
- [ ] Semantic treatments retain their meaning.

## Layout

- [ ] Complete affected compositions were inspected.
- [ ] Relevant device sizes were checked.
- [ ] Long content behaves appropriately.
- [ ] No essential information overlaps or clips.
- [ ] Responsive behavior preserves approved hierarchy.

## Interaction

- [ ] Actionable elements are discoverable.
- [ ] Noninteractive elements do not imply actions.
- [ ] Navigation destinations remain correct.
- [ ] Native interaction semantics are preserved.

## Accessibility

- [ ] Relevant Dynamic Type behavior was reviewed.
- [ ] VoiceOver behavior was checked where affected.
- [ ] Contrast is appropriate.
- [ ] Important meaning does not depend solely on color.
- [ ] Motion and transparency preferences are respected.

## State Continuity

- [ ] Applicable accepted cache remains visible.
- [ ] Routine refresh avoids unnecessary churn.
- [ ] Failure and unavailable states remain truthful.
- [ ] No intermediate ingestion state is exposed.

## Implementation

- [ ] The real presentation owner was identified.
- [ ] Shared consumers were considered.
- [ ] No unrelated redesign was introduced.
- [ ] Verification matches the change's actual impact.
- [ ] Any remaining limitations are disclosed.

A checkbox should only be marked complete when the corresponding review was actually performed.

Not every item applies to every localized change.

---

# 24. Definition of Success

SkyAware's visual review process succeeds when:

1. Meaningful defects are identified before release.

2. Approved design decisions remain consistent over time.

3. Weather interpretation and state integrity are protected.

4. Visual quality is evaluated using actual rendered evidence.

5. Device differences and constrained layouts are considered.

6. Accessibility is part of ordinary acceptance.

7. Reviews remain proportional to actual change scope.

8. Findings are specific and actionable.

9. Unnecessary redesign and speculative polish are avoided.

10. Engineers and agents know
    when work is complete.

The result should be a more dependable product, not a more elaborate review process.

---

# Final Review Principle

**SkyAware's design quality comes from consistently getting the important details right.**

Visual review should protect:

- Clear weather meaning.
- Recognizable hierarchy.
- Purposeful semantic color.
- Native interaction.
- State continuity.
- Accessibility.
- Consistent product identity.

Review enough to establish confidence.

Correct real problems.

Preserve accepted decisions.

Stop when the experience is coherent, trustworthy, and ready to ship.

**Quality is the goal. Review is how we protect it.**
