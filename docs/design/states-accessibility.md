---
title: SkyAware States and Accessibility
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - design
  - states
  - accessibility
  - swiftui
  - reliability
---

# SkyAware States and Accessibility

## Purpose

This document defines SkyAware's shared presentation requirements for application state, data availability, accessibility, and adaptive behavior.

It establishes how the interface should behave when:

- Information is loading or resolving.
- Valid cached information exists.
- A refresh is in progress.
- New accepted information becomes available.
- A refresh fails.
- The device is offline.
- Information is stale or degraded.
- A source confirms an empty result.
- Required information is unavailable.
- The device location changes.
- Accessibility settings alter the presentation.

It also establishes accessibility requirements for:

- Dynamic Type.
- VoiceOver.
- Color and contrast.
- Differentiate Without Color.
- Reduce Motion.
- Reduce Transparency.
- Interaction targets.
- Adaptive layouts.
- WidgetKit.
- Map interpretation.
- Meaningful weather-state announcements.

These requirements apply across SkyAware's supported surfaces unless a more specific canonical design document establishes an intentional exception.

Related documentation:

- [Design System](README.md)
- [Foundations](foundations.md)
- [North Star](../product/north-star.md)
- [Brand and Voice](../brand/brand-and-voice.md)
- [Today](today.md)
- [Map](map.md)
- [Widgets](widgets.md)
- [Visual Review](visual-review.md)

The North Star owns product and meteorological meaning.

This document owns the presentation and accessibility requirements that preserve that meaning.

It does not redefine data ingestion, persistence, accepted-revision policy, or state ownership.

---

# 1. Core Philosophy

SkyAware's interface must remain calm, trustworthy, and understandable while underlying information changes.

The user should experience a coherent local weather picture.

They should not experience the complexity of:

- Multiple asynchronous weather sources.
- Background refresh scheduling.
- Network requests.
- Cache reconciliation.
- Persistence updates.
- Source-specific ingestion.
- Accepted-revision bookkeeping.

Those are implementation concerns.

The interface should expose their consequences only when those consequences matter to the user's understanding.

## Primary Principle

**Present trustworthy accepted information first. Resolve forward into trustworthy replacement information.**

A refresh should not make the application appear to forget information it already knows.

A failure should not make previously accepted information disappear when that information remains valid and applicable.

An unavailable source must not produce a misleading quiet-weather conclusion.

## Accessibility Principle

**Every essential weather statement must remain understandable without relying on visual styling alone.**

Color, shape, texture, symbols, animation, and position may reinforce meaning.

They must not become its only representation.

## Premium Experience Principle

Loading, failure, offline, empty, and accessibility states are part of the finished product.

They are not temporary screens that can receive less design attention than the ideal experience.

A premium application remains deliberate and coherent when conditions are imperfect.

---

# 2. Canonical State Ownership

SkyAware separates accepted weather information from transient application activity.

This distinction must remain intact.

## Accepted Domain State

Accepted state represents weather information that has passed the application's established acceptance rules.

It may include:

- Current conditions.
- Convective outlooks.
- Severe probabilities.
- Fire-weather risk.
- Official alerts.
- Mesoscale discussions.
- Map geometry.
- Supplemental Storm Setup analysis.

Accepted state determines what weather information the interface is authorized to communicate.

## Transient Activity State

Activity represents operations such as:

- Loading.
- Refreshing.
- Reconnecting.
- Resolving location context.
- Awaiting source information.
- Applying an accepted update.

Activity does not independently determine the weather assessment.

## Presentation State

Presentation combines accepted content with relevant availability and activity information.

It determines whether the user sees:

- Current content.
- Cached content.
- A subtle updating indication.
- A resolving presentation.
- A degraded or offline indication.
- A confirmed empty state.
- An unavailable state.

Presentation must not invent a new meteorological conclusion from transient activity.

## Ownership Boundary

Views should consume established state and presentation models.

Do not recreate:

- Weather risk selection.
- Alert precedence.
- Source acceptance rules.
- Persistence validity.
- Revision comparison.
- Geographic eligibility.

inside SwiftUI presentation components.

If a design change requires additional state, identify its real owner before implementing it.

---

# 3. The Accepted-State Presentation Invariant

The fundamental presentation transition is:

**Last-known-good accepted state → coherent accepted replacement.**

The user should not see partially assembled or intermediate ingestion results.

## Required Behavior

When applicable accepted information exists:

1. Display it immediately.
2. Preserve it during routine refresh.
3. Retain its established presentation hierarchy.
4. Wait for a coherent accepted replacement.
5. Update the relevant presentation when replacement information is accepted.
6. Avoid unnecessary visual churn when the resulting displayed information has not meaningfully changed.

## Do Not Expose Intermediate State

Avoid transitions such as:

- Populated → Loading → Populated.
- Alert → No Alerts → Updated Alert.
- Known Risk → Quiet → Updated Risk.
- Map Polygons → Empty Map → Updated Polygons.

when the intermediate state exists only because a refresh or ingestion operation is incomplete.

These transitions can communicate false changes in the user's weather situation.

## Coherent Replacement

A new presentation should correspond to a coherent accepted state for the relevant content.

Do not combine unrelated partial revisions into an apparently unified current assessment.

The UI does not own the acceptance policy.

It must respect the accepted-state boundaries provided by the responsible domain and persistence layers.

---

# 4. State Vocabulary

SkyAware distinguishes several meaningful presentation concepts.

These should not be collapsed into a generic loading or error state.

| State | Meaning | Presentation expectation |
| --- | --- | --- |
| Current | Applicable accepted information meeting the content family's established current/freshness requirements | Present normally |
| Cached | Previously accepted information retained under the content family's established validity, provenance, and geographic applicability requirements | Present when still applicable |
| Cached refreshing | Accepted information remains visible while an update runs | Preserve content; use appropriate activity feedback |
| Quiet refreshing | Routine refresh occurs without requiring user attention | Preserve content; avoid unnecessary visual change |
| Stale refreshing | Saved information remains visible while updating is impaired or attempted | Preserve applicable content; communicate limitations where appropriate |
| Refresh failed with cache | An update failed but usable accepted information remains | Keep content; provide restrained failure context |
| Degraded | Information is available with a known limitation | Preserve applicable information and explain the limitation |
| No-cache resolving | No meaningful applicable accepted information is available while resolution proceeds | Show an appropriate resolving experience |
| Confirmed empty | An applicable source has established that no relevant items exist | Present a scoped empty state |
| Unavailable | Required information cannot be established | Present unavailability, not quiet weather |

These are conceptual presentation meanings.

Individual features may use different concrete state types or case names.

Do not introduce a new global state enumeration merely to make every feature use identical terminology.

## Important Distinction

A confirmed empty state is a valid result.

An unavailable state is a lack of sufficient information to establish a result.

They are fundamentally different.

---

# 5. Current and Cached Information

Valid accepted information should be useful immediately when the user opens SkyAware.

## Current State

Present current accepted information normally.

Avoid unnecessary freshness labels or decorative confirmation indicators.

The weather assessment itself remains primary.

## Cached State

Applicable cached information may be displayed while newer information is being obtained.

Preserve:

- Weather meaning.
- Risk category.
- Alert identity.
- Geographic context.
- Relevant timing.
- Existing interaction.
- Information hierarchy.

Do not make cached information look disabled.

## Cached Data Is Not Automatically Current

Cached information has its own validity, freshness, provenance, and geographic requirements.

Do not automatically treat every persisted value as eligible for current presentation.

The established domain and persistence layers determine whether saved information remains usable.

If required validity cannot be established, use an appropriate unavailable or degraded state.

## Source-Specific Freshness

Different content families may have different validity requirements.

For example:

- A current weather observation.
- An SPC outlook.
- An official warning.
- A Map polygon.
- Supplemental HRRR-derived guidance.

These should not all be governed by one invented presentation expiration rule.

Preserve the actual source-specific contracts.

---

# 6. Routine Refresh

Routine refresh is application activity.

It is not inherently a user-visible event.

## Quiet Refreshing

When accepted content exists and a routine refresh is underway:

- Keep the existing content visible.
- Preserve component dimensions where practical.
- Avoid replacing content with placeholders.
- Avoid full-screen loading treatment.
- Avoid unnecessary skeleton animation.
- Avoid unnecessary status badges.
- Avoid re-entering content transitions.

A routine update check should normally be visually quiet.

## Unchanged Information

If a refresh produces no meaningful user-visible change, the presentation should remain settled.

Avoid:

- Replaying entrance animations.
- Repositioning unchanged cards.
- Replacing identical text.
- Flashing risk colors.
- Recreating the whole screen.
- Repeated success messages.

A successful network request is not a weather change.

## Background Refresh

Background work may update accepted canonical information.

When SkyAware enters the foreground, it should consume applicable accepted state immediately.

Do not force an additional visible refresh cycle merely because the accepted information was produced while the application was backgrounded.

Background execution is not deterministic.

The interface must not imply otherwise.

---

# 7. User-Initiated Refresh

An explicit user refresh may justify more visible progress feedback.

However, existing content remains useful.

## Presentation

When valid accepted information exists:

- Keep it visible.
- Use the established refresh affordance.
- Communicate progress without obscuring content.
- Avoid a full-screen resolving transition.
- Preserve interaction when safe and appropriate.

During a cached Today refresh, visible progress belongs in the established subordinate header/status area. Keep accepted content visible and progress visually secondary. Do not add custom floating progress overlays over weather content, obscure the accepted awareness picture, or introduce unnecessary refresh animation.

The existing native pull-to-refresh progress indicator remains appropriate. [Brand and Voice](../brand/brand-and-voice.md) owns the exact status wording.

## Successful Refresh

When new accepted content differs meaningfully, update the affected presentation coherently.

When the displayed information is unchanged, return to the settled state without a dramatic confirmation animation.

## Failed Refresh

If refresh fails but applicable accepted information remains:

- Preserve that information.
- Communicate that the update failed.
- Explain that saved information is shown.
- Avoid replacing the screen with an error.
- Do not convert the result into quiet weather.

An established example is:

"Couldn't update. Showing saved conditions."

Detailed wording belongs in [Brand and Voice](../brand/brand-and-voice.md).

## Failure Without Cache

If no usable accepted information exists, present the appropriate unavailable state.

Do not reuse a cached-content failure message when no cached content is available.

---

# 8. Initial Resolving

A dedicated resolving experience is appropriate when SkyAware is assembling the initial local weather picture and meaningful applicable accepted information is not yet available.

## Presentation Goal

The experience should communicate:

- The application is preparing local information.
- The process is active.
- Weather meaning has not yet been established.
- The user is not looking at a confirmed quiet-weather assessment.

## Preferred Language

The established concept is:

"Getting your conditions ready"

Additional progress language may reflect the actual active operation.

Avoid generic technical messages such as:

- Fetching data.
- Processing providers.
- Synchronizing feeds.
- Finalizing network results.

## Visual Treatment

Use a restrained, native resolving treatment.

It should feel:

- Calm.
- Intentional.
- Responsive.
- Consistent with SkyAware.

Avoid unnecessary animated weather effects, large spinners, or dramatic loading choreography.

## Transition Into Content

When an accepted local picture becomes available:

- Replace the resolving experience coherently.
- Preserve the established Today hierarchy.
- Avoid multiple successive partial entrances.
- Respect Reduce Motion.
- Do not delay usable content for decorative animation.

## Scope

A global no-cache resolving experience should not be triggered by one optional section refreshing independently.

Supporting sections may use their own appropriate state presentation.

---

# 9. Section-Level Resolving

Not every section resolves at the same time.

SkyAware may have valid information for one section while another remains unresolved.

## Independent Section Meaning

A section may be:

- Current.
- Cached.
- Resolving without applicable content.
- Confirmed empty.
- Unavailable.
- Degraded.

Other sections should not lose their accepted content because of this distinction.

## Appropriate Placeholders

A local placeholder may be appropriate when that section has no usable accepted information and is actively resolving.

Use the existing component geometry where practical.

Avoid temporary layouts that cause substantial reflow when content appears.

## Placeholder Boundaries

Do not place a placeholder over valid accepted information merely because a refresh is running.

Do not use an animated placeholder when the application is known to be offline and no useful operation is underway.

Do not let placeholders resemble confirmed quiet-weather content.

## Section Position

Preserve the logical position of conditional supporting sections.

A Storm Setup analysis state, for example, should remain in its established section slot.

Do not temporarily relocate content because its data is resolving.

---

# 10. Confirmed Empty States

A confirmed empty state is a meaningful accepted result.

It communicates that no applicable information was returned or established within the relevant source's scope.

## Examples

- No active local alerts.
- No applicable items in an accepted list.
- No polygons for an accepted Map layer.
- No currently relevant optional product.

The exact conclusion depends on the corresponding source contract.

## Presentation

Confirmed empty states should feel:

- Calm.
- Complete.
- Deliberate.
- Appropriately scoped.
- Clearly different from unavailable states.

Use concise explanatory copy.

## Avoid Broad Safety Claims

Do not infer:

"No active alerts" → "No severe-weather risk."

Do not infer:

"No displayed polygons" → "No dangerous weather."

Do not infer:

"No optional analysis" → "Conditions are safe."

The presented conclusion must remain limited to the accepted evidence.

## Do Not Manufacture Emptiness

A failed request, cancelled operation, missing location, or incomplete ingestion does not establish a confirmed empty result.

A section must not enter its quiet or empty presentation merely because a temporary collection is empty.

---

# 11. Unavailable States

Unavailable means the application cannot establish the information needed for the intended presentation.

It is not a weather assessment.

## Appropriate Causes

Examples include:

- Missing required location context.
- No usable accepted source information.
- A failed initial load.
- Missing or invalid source identity.
- Unavailable required geometry.
- Expired data without a valid replacement.
- An unsupported or unresolved data relationship.

These examples do not establish a single global unavailable policy.

Each content family follows its existing eligibility requirements.

## Presentation

Unavailable states should:

- Identify what information is unavailable.
- Avoid implying a known risk level.
- Preserve useful unaffected information.
- Remain visually integrated with the application.
- Avoid exaggerated warning treatment.

## Semantic Treatment

Use neutral availability styling.

Do not use confirmed quiet-weather green as a generic unavailable fallback.

Do not use hazard colors merely because something failed to load.

A source failure is not a meteorological hazard.

## Interaction

Show retry or recovery actions only when supported by existing behavior and meaningful to the user.

Do not create decorative retry controls.

Avoid repeatedly interrupting the user for recoverable background failures.

---

# 12. Offline and Degraded Operation

SkyAware must remain useful when network connectivity is impaired.

Offline operation should not automatically replace the application with an error screen.

## Valid Saved Information

When applicable accepted data exists:

- Preserve it.
- Keep the established hierarchy.
- Retain relevant navigation where supported.
- Communicate the offline limitation.
- Avoid unnecessary placeholder transitions.

## Offline Status

Use restrained status treatment.

The established Today experience includes an Offline indicator and supporting explanation.

Its purpose is to explain the data limitation, not to compete with weather information.

## Status Explanation

An offline explanation may communicate that SkyAware is showing saved local data and will attempt updates when connectivity returns.

Do not promise a precise refresh time.

## Degraded Sources

One unavailable source should not automatically invalidate unrelated accepted information.

For example, a failed atmospheric update does not necessarily invalidate an accepted local alert state.

Preserve source-specific availability.

## Important Boundary

Offline does not automatically mean saved data remains valid indefinitely.

Respect accepted-state eligibility, source expiration, and location identity.

---

# 13. Geographic and Source Identity

SkyAware is hyper-local.

The displayed weather assessment must remain associated with the correct location and source identity.

## Location Changes

A location change can change the applicable weather assessment even when the underlying forecast product has not changed.

Preserve that distinction.

Do not present old-location information as current information for a new location.

## Cached Weather Continuity

Weather information may remain visible during refresh only while its established location identity requirements are met.

If the application cannot establish that cached information applies to the current location, it must not silently reuse that information.

## Outlook Identity

Risk information derived from an SPC outlook must remain associated with the correct accepted outlook.

Do not combine incompatible revisions merely to keep a presentation populated.

## Conditional Intensity

Local conditional intensity requires matching hazard, location, outlook identity, validity, and eligible geometry.

When those requirements fail, omit the modifier.

Do not replace it with an invented zero-intensity conclusion.

## Alert Geographic Relevance

An alert must not be presented as locally applicable without the established geographic relationship.

A changed location may alter alert relevance without any corresponding alert revision.

## Presentation Responsibility

The presentation layer should consume validated identity relationships.

It should not independently invent distance thresholds, geometry tests, or source-identity policies.

---

# 14. Alert State Continuity

Official alert information is especially sensitive to misleading transitions.

## Accepted Alerts

Keep applicable accepted alerts visible during refresh when their validity and source contracts permit it.

Do not remove them because an intermediate fetch returned no temporary rows.

## Confirmed No Active Alerts

Use the established no-active-alert presentation only when supported by accepted alert state.

## Failed Refresh

If a refresh fails with usable accepted alerts available:

- Retain those alerts.
- Communicate the update limitation.
- Avoid a temporary no-alert message.

## Alert Lifecycle

Preserve distinctions between:

- Newly issued.
- Updated.
- Newly affecting the location.
- No longer affecting the location.
- Cancelled.
- Expired.

Do not create visual transitions that imply the wrong lifecycle event.

## Attention and Motion

A genuinely new or materially changed warning may justify appropriate emphasis.

A routine check of the same accepted warning should not repeatedly animate it.

The weather event determines the urgency, not the refresh mechanism.

---

# 15. Map State Continuity

The Map consumes accepted geographic weather information and presentation state.

## Accepted Geometry

Preserve applicable displayed polygons while newer information resolves.

Do not temporarily clear the Map because a refresh is in progress.

## Selected Layer

Preserve the selected layer during refresh.

Do not fall back to another layer merely because the current one is temporarily resolving.

## Camera

Preserve established camera state.

Refresh must not unexpectedly recenter or reset zoom.

## Layer-Specific Availability

Different layers may have different current, resolving, stale, empty, or unavailable states.

The legend must reflect the actual state of the selected layer.

## Legend and Overlay Agreement

The legend should describe the information actually displayed.

Do not present a current legend for unavailable geometry.

Do not present an empty legend as confirmed quiet when the underlying source failed.

## Accessibility

The accessible Map summary must preserve the same state distinction.

If a location relationship is unknown, do not announce it as confirmed outside or inside a risk polygon.

Detailed Map rules belong in [Map](map.md).

---

# 16. Widget State Continuity

WidgetKit operates under different execution and rendering constraints from the foreground application.

## Snapshot Presentation

Widgets consume established snapshot information.

They should not independently recalculate severe-weather risk or alert precedence.

## Valid Accepted Content

Present applicable accepted content when available.

Do not replace meaningful saved information with generic loading or quiet-state content merely because a timeline update is pending.

## Unavailable Content

When required snapshot information is unavailable, communicate that limitation clearly.

Do not invent a risk value.

## Stale Content

Use the established stale presentation when applicable.

Preserve the distinction between saved information and current data.

## No Guaranteed Timing

WidgetKit updates are not deterministic.

Do not imply guaranteed real-time widget updates.

## Freshness Copy

Do not introduce decorative "as of" timestamps in widgets or their accessibility summaries.

Official alert issue and expiration times serve a different purpose and may remain meaningful.

Detailed family-specific rules belong in [Widgets](widgets.md).

---

# 17. Motion and State Transitions

Motion should support comprehension and preserve visual continuity.

It should not manufacture urgency.

## Appropriate Motion

Examples include:

- A restrained initial content entrance.
- A subtle transition between meaningfully different accepted states.
- Native interaction feedback.
- Appropriate sheet disclosure.
- Minor opacity transitions when they clarify change.

## Routine Refresh

Routine refresh should generally avoid noticeable content animation.

Do not animate:

- Unchanged values.
- Reapplied cached state.
- Repeated alert snapshots.
- Identical risk categories.
- Unchanged Map polygons.
- Entire sections reappearing after background refresh.

## Meaningful Changes

A genuine accepted change may justify restrained presentation feedback.

The transition should not obscure the new information or its meaning.

## Spatial Continuity

Prefer keeping important elements in stable positions.

Avoid unnecessary:

- Card disappearance.
- Large layout shifts.
- Full-screen replacement.
- Sudden changes in scroll position.
- Repeated content re-entry.

## Motion Priority

Correct state presentation comes first.

Motion is a refinement, not a mechanism for disguising inconsistent state.

---

# 18. Accessibility Philosophy

Accessibility is part of component correctness and design quality.

SkyAware should remain useful to people who:

- Use larger text.
- Navigate with VoiceOver.
- Need stronger contrast.
- Cannot reliably distinguish colors.
- Prefer reduced motion.
- Prefer reduced transparency.
- Use smaller devices.
- Use WidgetKit in constrained presentations.

Accessibility should preserve meteorological meaning, not merely provide an alternate way to navigate.

## Fundamental Rule

**Essential weather meaning must be available through understandable text and accessible interaction, independent of visual decoration.**

The interface may adapt substantially to accessibility settings.

Its underlying meaning must remain stable.

---

# 19. Dynamic Type

SkyAware should use native text behavior wherever practical.

Dynamic Type is not an exceptional layout state.

It is part of the supported application experience.

## 19.1 Content Priority

At larger text sizes, preserve:

1. Primary awareness meaning.
2. Official event identity.
3. Important timing.
4. Threat and hazard explanation.
5. Actionable guidance.
6. Navigation comprehension.
7. Supporting information.

Decorative elements have lower priority.

## 19.2 Layout Adaptation

When horizontal space becomes insufficient, prefer:

- Vertical stacking.
- Natural text wrapping.
- Increased component height.
- Adaptive spacing.
- Appropriate alternate layout.
- Progressive disclosure where supported.

Avoid aggressive text scaling that makes essential information difficult to read.

## 19.3 No Arbitrary Fixed Heights

Essential weather information must not be clipped to preserve a preferred card height.

Cards should grow vertically when necessary.

Fixed-size elements may remain appropriate for decorative symbols or bounded controls.

## 19.4 Long Text

Account for:

- Long location names.
- Long warning titles.
- Multiple-word risk categories.
- Expiration descriptions.
- Hazard explanations.
- Conditional-intensity text.
- Longer localized-style strings.

Do not assume short English preview strings represent the full supported content range.

## 19.5 Adaptive Arrangements

Established examples include:

- Stacked Current Conditions.
- Stacked primary hero content.
- Vertically adapted section headers.
- Compact or expanded Map legends.
- Widget family-specific alternatives.

Use existing adaptive layout conventions where possible.

Do not create a separate adaptive layout framework for every component.

## 19.6 Widget Constraints

WidgetKit has fixed external bounds.

Widget layouts may require different content priorities from application screens.

A widget-specific Dynamic Type limit or alternate presentation may be appropriate when necessary.

However, a size cap does not automatically guarantee:

- Readability.
- No overlap.
- Complete meaning.
- Accessible content.

Validate the actual result.

---

# 20. VoiceOver

VoiceOver must communicate weather meaning clearly and efficiently.

## 20.1 Meaningful Elements

Important information should expose:

- A useful label.
- A meaningful value when applicable.
- An interaction hint when useful.
- Correct control traits.
- Appropriate grouping.

Avoid exposing the internal structure of decorative layout.

## 20.2 Primary Awareness

The primary awareness hero should communicate its weather meaning as a coherent accessible element.

When actionable, it must expose the appropriate button semantics.

When noninteractive, it must not announce a navigation action.

## 20.3 Supporting Risk Cards

Risk cards should communicate:

- Category.
- Accepted risk value.
- Relevant supporting meaning.
- Navigation destination when actionable.

Do not require users to navigate separately through every decorative symbol and label to understand one simple risk assessment.

## 20.4 Decorative Elements

Hide purely decorative:

- Semantic rails.
- Background gradients.
- Divider lines.
- Repeated symbols.
- Navigation chevrons.
- Decorative hatch samples.

Their meaning must be represented through accessible text or the containing control.

## 20.5 Avoid Redundancy

Do not announce the same risk category repeatedly through nested accessibility elements.

Prefer one coherent accessible statement over multiple fragmented repetitions.

However, do not combine unrelated actions into one inaccessible group.

## 20.6 Navigation Hints

An actionable element should communicate its destination when that destination is not obvious.

Examples include:

- Opens the alert center.
- Opens the fire risk map.
- Opens the full map legend.
- Opens the awareness summary.

Hints must match actual behavior.

## 20.7 Unavailable and Stale States

Accessible labels must preserve state distinctions.

Do not announce stale information as confidently current.

Do not announce an unavailable risk as quiet weather.

## 20.8 Alert Urgency

Official warning information must remain understandable without relying on red color or visual prominence.

Accessible content should preserve the event name, applicable timing, and important guidance.

Do not invent urgency or emergency instructions.

---

# 21. Accessibility Grouping

Grouping should reflect the conceptual structure of the interface.

## Group Related Information

A simple awareness card with one action may be one accessible control.

A compact measurement may be one accessible element.

A widget may provide a coherent summary of several related values.

## Preserve Separate Actions

Do not merge unrelated interactive controls into one inaccessible container.

For example:

- A dismiss action.
- A navigation action.
- A Map layer selection.
- An alert detail action.

must remain appropriately discoverable when independently actionable.

## Avoid Duplicate Controls

A trailing chevron normally reinforces the parent card's navigation.

It is not a separate action.

Do not expose it as an additional accessibility control.

## Reading Order

Accessible reading order should follow the meaningful information hierarchy.

Do not allow decorative layout ordering to obscure:

- The primary risk.
- Supporting hazards.
- Official alerts.
- Important guidance.
- Related navigation.

---

# 22. Color and Non-Color Meaning

SkyAware uses semantic color extensively.

Color is a supporting carrier of meaning, not the only one.

## Weather Risk

A risk category must remain identifiable through its text label or accessible value.

Do not rely exclusively on green, orange, red, or purple.

## Severe Hazards

Tornado, hail, and wind must remain distinguishable through actual hazard identity.

Do not depend solely on magenta, blue, or teal.

## Conditional Intensity

Hatching communicates potential intensity.

The same conditional meaning must also be available through plain-language text.

Users should not need to compare hatch density to understand the potential impact.

## Map

Preserve established non-color polygon differentiation where supported.

Legends and accessible summaries must communicate category and probability meaning.

## Status

Stale, offline, unavailable, and current states must not depend solely on badge color.

Use appropriately scoped text and accessible semantics.

## General Principle

**Remove color mentally from the interface. The important weather meaning should remain.**

---

# 23. Increase Contrast

Increase Contrast must improve readability without creating an unrelated visual language.

## Text

Preserve clear distinction between primary and supporting information.

Do not rely on excessive foreground opacity reduction.

In particular, avoid adding arbitrary opacity to already secondary text unless the resulting contrast is verified.

## Surfaces

Use established adaptive border treatments where necessary.

For ordinary light-mode content, Foundations defines the approved higher-contrast edge.

Do not use stronger borders as a substitute for readable text.

## Semantic Gradients

Today's Awareness gradients must preserve readable foreground information under increased contrast.

Do not let gradient intensity interfere with text clarity.

## Map

Risk polygons and hatching must remain distinguishable.

Native controls and legends must remain readable over variable geographic backgrounds.

## Widgets

Review actual supported rendering modes.

A treatment that works in full color may change under system color transforms.

---

# 24. Reduce Motion

Reduce Motion must preserve complete functionality and weather meaning.

## Required Behavior

Reduce or remove:

- Decorative motion.
- Unnecessary content entrances.
- Large movement transitions.
- Nonessential spring effects.
- Repeated status animations.
- Animated refresh placeholders.
- Movement unrelated to meaningful accepted change.

## Acceptable Alternatives

Use:

- Immediate state replacement.
- Restrained opacity transitions.
- Native reduced-motion behavior.
- Stable layout without animation.

## Do Not Lose Information

The user must not depend on motion to recognize:

- A changed warning.
- A new risk state.
- A navigation destination.
- A resolving state.
- A failed refresh.

The information must remain understandable when animation is disabled.

## Routine Refresh

Routine background refresh should remain visually quiet even without Reduce Motion.

Reduce Motion should not be needed to prevent refresh churn.

---

# 25. Reduce Transparency

Weather content should remain readable when transparency is reduced.

## Stable Content

Ordinary weather cards should not depend on translucent materials.

This is consistent with SkyAware's established opaque-content design.

## Native Controls

Where controls use native system materials, allow supported platform adaptation.

Do not simulate Glass with custom translucent weather-content containers.

## Map

Map controls and legends must remain distinguishable from geographic content.

Use established content surface treatment rather than relying on blur alone.

## Widgets

Respect WidgetKit's system rendering behavior.

Do not introduce an additional fake translucent container when system presentation changes.

---

# 26. Interaction Accessibility

Accessible interaction must remain honest and predictable.

## Native Controls

Prefer native SwiftUI interaction components.

Examples include:

- Button.
- NavigationLink.
- Menu.
- Picker.
- Toggle.
- Native sheets and popovers.

Do not replace native controls with gesture-driven imitations without a demonstrated need.

## Interaction Targets

Maintain appropriately sized touch targets.

For ordinary tappable application controls, use the established minimum 44-point target where applicable.

A small visible symbol may sit inside a larger interaction region.

Do not enlarge decorative elements merely to satisfy touch-target requirements.

## Full-Card Actions

When a card represents one action, the card should ordinarily be the interaction target.

Avoid small isolated tap regions within an otherwise actionable card.

## Noninteractive States

A noninteractive component must not imply navigation.

Do not display a decorative chevron on a nonactionable hero.

## Dismissible Prompts

When a prompt provides both navigation and dismissal, keep those actions distinct.

The user must be able to understand and operate each one independently.

## Disabled Controls

Do not use a disabled-looking presentation merely because data is quiet.

Disabled appearance should correspond to actual interaction restrictions.

---

# 27. Semantic Status Announcements

A status announcement should communicate something meaningful.

## Meaningful Changes

Examples may include:

- A new applicable warning.
- A materially changed risk.
- A user-requested update failure.
- A change in information availability.

Use existing supported accessibility behavior rather than inventing a separate announcement system for every component.

## Avoid Announcement Noise

Do not repeatedly announce:

- Identical cached state.
- Routine refresh starts.
- Routine refresh completion.
- Unchanged forecast content.
- Repeated provider requests.
- Cosmetic state transitions.

A notification or status update should not be treated as a new weather event merely because its data was reread.

## Announcement Accuracy

Do not announce:

- A threat has ended without supporting evidence.
- A new forecast exists when only location changed.
- Current data is unavailable when applicable cache remains.
- All weather is safe when a specific hazard is quiet.

## User Control

Avoid unsolicited announcements for ordinary background activity.

Preserve predictable focus and navigation.

---

# 28. Focus and Navigation Continuity

Presentation updates should not unnecessarily disrupt the user's current interaction.

## Stable Identity

Preserve component identity where practical across routine state updates.

Avoid rebuilding the entire navigation surface merely because source data was refreshed.

## Focus

Do not steal accessibility focus for ordinary background state changes.

Avoid forcing the user to restart navigation through previously visible content after a refresh.

## Scroll Position

Routine refresh should not unexpectedly reset the current scroll position.

Do not force a return to the top of Today for unchanged information.

## Navigation Destinations

Preserve established navigation behavior.

A visual refinement should not change destinations or dismiss active detail presentation without a relevant state reason.

## Map Interaction

Preserve user-selected Map camera and layer when data updates.

The user should remain in control of exploration.

---

# 29. Responsive Layout Integrity

SkyAware must remain coherent across supported device sizes.

## Device Width

Do not optimize for one iPhone width at the expense of another.

A composition that works on a standard Pro-sized device must also be reviewed on larger devices.

## Additional Width

More horizontal space does not automatically justify more columns.

Preserve settled information hierarchy.

For example, Today's Storm, Severe, and Fire cards remain vertically stacked on iPhone.

## Content Growth

Allow components to expand when essential text requires more space.

Do not depend on ideal one-line weather labels.

## Fixed Bounds

WidgetKit and some native presentations have constrained bounds.

Use deliberate content priority and adaptive arrangements.

Do not solve overflow with overlapping elements or arbitrary offsets.

## Layout Correctness

No essential:

- Title.
- Risk value.
- Warning timing.
- Guidance.
- Overflow indicator.
- Status text.
- Accessibility control.

may become unreadable because of clipping, collision, or decorative layout constraints.

---

# 30. High-Value State Combinations

Individual presentation states should not be evaluated only in isolation.

Important real-world combinations include:

## Quiet With Current Data

A complete, calm accepted quiet state.

## Elevated Risk During Refresh

The elevated assessment remains visible while new information resolves.

## Active Warning With Failed Refresh

Previously accepted warning information remains available while its update limitation is clear, subject to applicable validity.

## Offline With Cache

The last applicable accepted picture remains visible with restrained offline context.

## Offline Without Cache

The application does not pretend to have an accepted local assessment.

## Location Changed With Old Cache

The application does not reuse unrelated old-location weather information as current local conditions.

## Forecast Updated at Same Location

The accepted replacement may update the assessment without implying that the device moved.

## Confirmed No Alerts With Elevated Risk

The alert section may be empty while risk remains elevated.

These are compatible states.

## Conditional Intensity Missing

The supported hazard assessment remains valid, but unsupported or ineligible intensity is omitted.

## Widget With Multiple Alerts

Active alerts, overflow, and supporting risks remain distinct and legible within fixed bounds.

---

# 31. Implementation Boundaries

These requirements should be applied through existing state and presentation ownership.

## Investigation Starting Points

High-value examples include:

- `Sources/Features/Summary/TodayContentState.swift`
- `Sources/Features/Summary/LocalAlertsDisplayState.swift`
- `Sources/Features/Summary/TodayVisibleWeatherState.swift`
- `Sources/Features/Summary/SummaryResolving.swift`
- `Sources/Features/Summary/SummaryStatus.swift`
- `Sources/Features/Summary/ActiveAlertSummaryView.swift`
- `Sources/Features/Map/MapLegendState.swift`
- `Sources/Features/Map/MapAccessibilitySupport.swift`
- `WidgetsExtension/WidgetStateComponents.swift`

These are orientation points, not an exhaustive implementation boundary.

Follow dependencies before making changes.

## Existing State Models

The application already distinguishes multiple presentation states.

Do not replace them with a simplified global loading/loaded/error model.

Do not add parallel state owners merely to make views easier to style.

## Swift Concurrency

Respect established Swift 6 concurrency ownership.

UI-facing state belongs to the appropriate main-actor context.

Mutable background state belongs to its established isolated owner.

Cross-isolation values must respect Sendable requirements.

Do not introduce hidden cross-actor mutation to manage presentation.

## Pure Presentation

Prefer focused presentation logic that transforms accepted state into understandable UI.

Avoid performing:

- Networking.
- Persistence writes.
- Alert selection.
- Polygon interpretation.
- Cache acceptance.
- Source reconciliation.

inside visual modifiers or reusable UI components.

## Preserve Existing Behavior

Do not use accessibility or visual cleanup as implicit authorization to change domain logic.

If an accessibility issue requires a different information representation, preserve the same accepted meteorological meaning.

---

# 32. Testing and Verification

State and accessibility correctness should be validated deliberately.

## Deterministic State Tests

Prefer focused tests for meaningful transitions.

High-value examples:

- Cached → Refreshing → Current.
- Cached → Refresh Failure.
- No Cache → Resolving → Current.
- No Cache → Unavailable.
- Current → Confirmed Empty, when supported by accepted data.
- Offline With Valid Cache.
- Offline Without Cache.
- Same Location, New Forecast.
- New Location, Same Forecast.
- Missing Conditional Intensity.
- Accepted Alert Retained During Refresh.

Tests should verify actual state invariants rather than implementation timing.

## Visual State Fixtures

Representative previews should include:

- Quiet.
- Elevated risk.
- Active warning.
- Active watch.
- Confirmed empty.
- Cached refreshing.
- Failed refresh with cache.
- Offline with cache.
- No-cache resolving.
- Unavailable.

Not every component requires every state.

Choose the states relevant to its responsibility.

## Accessibility Coverage

Review affected components under:

- Dynamic Type.
- VoiceOver.
- Increase Contrast.
- Differentiate Without Color.
- Reduce Motion.
- Reduce Transparency.

Use actual rendered compositions where useful.

## Device Coverage

Review meaningful layout changes on at least:

- Standard Pro-sized iPhone.
- Larger Pro Max-sized iPhone.

Include smaller constrained surfaces when relevant.

## Widget Coverage

Use supported widget families and representative content-density states.

Include multiple active alerts and overflow conditions for large widgets.

## Map Coverage

Include representative Map layers and selected legend states.

Verify non-color interpretation of risk and conditional intensity.

## Testing Scope

Favor deterministic regression tests for real defects.

Do not build extensive test infrastructure for hypothetical cases without clear value.

A passing unit test does not establish visual correctness.

---

# 33. Accessibility Review Checklist

Before accepting a meaningful presentation change, verify:

## Meaning

- Is the weather statement accurate?
- Is uncertainty preserved?
- Is unavailable distinct from quiet?
- Does the accessible description preserve the visual meaning?

## Typography

- Does essential text remain readable?
- Does Dynamic Type permit appropriate expansion?
- Are important labels complete?
- Is supporting text distinguishable without looking disabled?

## Color

- Is semantic coloring correct?
- Does meaning survive without color?
- Is contrast sufficient?
- Are conditional-intensity explanations available as text?

## Interaction

- Are controls discoverable?
- Are interaction targets appropriate?
- Do affordances represent real actions?
- Are decorative elements hidden from accessibility?
- Are navigation hints accurate?

## Motion

- Is routine refresh calm?
- Is Reduce Motion respected?
- Is meaningful change still understandable without animation?

## State

- Is accepted cache preserved?
- Are failure and offline limitations communicated?
- Are intermediate ingestion states hidden?
- Is geographic identity respected?
- Are unchanged values stable?

## Layout

- Are there overlaps?
- Is important content clipped?
- Do different iPhone widths preserve the approved hierarchy?
- Do constrained widgets preserve essential meaning?

---

# 34. State and Accessibility Anti-Patterns

Avoid:

- Replacing valid cached content with a loading placeholder.
- Showing confirmed quiet weather when data is unavailable.
- Treating every empty collection as a confirmed empty result.
- Exposing intermediate ingestion state.
- Replaying animations on unchanged data.
- Clearing Map polygons during refresh.
- Resetting the Map camera when accepted data changes.
- Reusing old-location data for a new location.
- Discarding accepted alerts because refresh failed.
- Presenting expired or mismatched conditional intensity.
- Using green as a generic application-success indicator.
- Making essential text tertiary or artificially faded.
- Clipping warning explanations.
- Shrinking important text merely to preserve card height.
- Using inaccessible custom gestures instead of native controls.
- Announcing decorative chevrons as separate actions.
- Making risk meaning depend entirely on color.
- Making intensity meaning depend entirely on hatching.
- Unnecessary VoiceOver announcement repetition.
- Stealing accessibility focus during routine refresh.
- Custom animations that disregard Reduce Motion.
- Assuming Dynamic Type caps solve widget layout defects.
- Adding new state infrastructure for a presentation-only change.
- Broad UI redesign in response to a localized accessibility issue.

---

# 35. Definition of Success

SkyAware's state and accessibility design succeeds when:

1. Valid accepted information is available immediately.

2. Routine refresh does not unnecessarily disrupt the presentation.

3. New information appears as a coherent accepted update.

4. Failed updates preserve applicable last-known-good data.

5. Confirmed empty and unavailable remain clearly distinguishable.

6. Offline operation preserves useful information and communicates limitations.

7. Geographic and source identity remain correct.

8. Active weather alerts are not visually lost during transient refresh.

9. Essential meaning survives larger text sizes and different device widths.

10. VoiceOver communicates
    complete weather meaning
    with accurate interaction.

11. Color and texture reinforce
    information rather than
    becoming its only expression.

12. Motion remains calm,
    purposeful, and optional
    where appropriate.

13. Widgets and Map preserve
    the same trust principles
    as the Today experience.

14. The application feels
    coherent and deliberately
    designed even when
    information is incomplete.

---

# Final Principle

**SkyAware should remain trustworthy when information is changing, incomplete, delayed, or unavailable.**

The interface must make the most useful accepted weather information visible without concealing its limitations.

Accessibility must preserve that same understanding for every user.

The application should move from one coherent weather picture to the next.

It should not expose the uncertainty of its internal processing as false changes in weather.

**Preserve what is known. Be clear about what is not. Make every state understandable.**
