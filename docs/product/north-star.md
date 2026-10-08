---
title: SkyAware North Star
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - product
  - north-star
---

# SkyAware North Star

## Purpose

This document defines SkyAware's product identity, purpose, priorities, core user experience, and non-negotiable behavioral principles.

It is the authoritative reference for **what SkyAware is, what it must communicate, and what the product must never compromise**.

It is not a visual styling specification or an implementation guide.

Related documentation:

- `docs/brand/brand-and-voice.md` — identity, voice, terminology, communication, and marketing.
- `docs/design/README.md` — design documentation entry point, visual foundations, interaction patterns, and surface contracts.

These documents have distinct responsibilities.

**Product truth belongs here. Communication belongs to Brand. Visual and interaction implementation belongs to Design.**

Detailed presentation decisions should not be duplicated across them.

---

# 1. Product Identity

## What SkyAware Is

SkyAware is a hyper-local severe-weather awareness assistant for iOS and watchOS.

Its purpose is to turn complex meteorological information into clear, timely, actionable awareness.

The fundamental question SkyAware answers is:

> **How weather-aware do I need to be right now?**

SkyAware should help someone understand:

- Their current local weather context.
- Whether meaningful severe-weather threats are present.
- The nature and relative significance of those threats.
- Whether official watches, warnings, or other relevant products affect their location.
- What supporting atmospheric conditions may contribute to risk.
- Where to find more detail when it becomes relevant.

The user should not need to understand meteorological models, probabilities, outlook geometry, or forecast products to answer that fundamental question.

SkyAware performs that interpretation and presentation work for them.

## What SkyAware Is Not

SkyAware is not:

- A generic weather application.
- A replacement for official NWS warnings and emergency guidance.
- A forecasting authority.
- A guarantee of personal safety.
- A deterministic warning-delivery system.
- A meteorological research dashboard.
- A radar-first weather explorer.
- A collection of every weather metric available.
- A novelty or entertainment application.

Features that do not meaningfully improve severe-weather awareness should be treated as supplemental, not central.

---

# 2. Product Promise

SkyAware should make severe-weather awareness:

**Clear**

Important information should be understandable within seconds.

**Local**

Information should be relevant to the user's actual location, not merely a broad regional forecast.

**Trustworthy**

Weather meaning, uncertainty, provenance, and freshness must be represented accurately.

**Timely**

The experience should surface relevant changes promptly while acknowledging that background execution and notification delivery are not guaranteed.

**Calm**

The interface should communicate urgency when warranted without manufacturing anxiety or sensationalizing weather.

**Useful**

Every primary surface should help the user understand, decide, or navigate toward information that matters.

---

# 3. Product Priorities

When priorities compete, use this order:

1. Correct meteorological meaning and data integrity.
2. User safety, trust, and honest communication of uncertainty.
3. Accessibility and predictable interaction.
4. Clarity of awareness and information hierarchy.
5. Reliability, resilience, and state continuity.
6. Visual quality, coherence, and product identity.
7. Additional information, visual effects, or functionality.

Visual and interaction quality are release-critical product requirements, not optional decoration.

However, presentation must never distort meteorological meaning or conceal unavailable, stale, or uncertain information.

A beautiful but misleading weather interface is a failure.

A technically correct but confusing interface is also incomplete.

---

# 4. High-End Experience Standard

SkyAware must feel and behave like a carefully crafted, high-end Apple-platform application.

Premium quality means:

- Precise information hierarchy.
- Consistent and understandable interaction.
- Carefully considered presentation.
- Responsive behavior.
- Smooth continuity between accepted states.
- Excellent accessibility.
- First-class light and dark appearances.
- Well-designed quiet, elevated, empty, stale, offline, resolving, and unavailable states.
- No unnecessary complexity exposed to the user.
- No obvious unfinished or inconsistent experiences.

Premium does not require elaborate ornamentation.

**The user should experience craftsmanship without having to think about the craftsmanship.**

Apple-native behavior is preferred where it improves usability, accessibility, reliability, and platform consistency.

SkyAware should retain its own identity where custom presentation communicates meaningful weather information.

Native does not mean generic.

---

# 5. Trust and Weather Semantics

## 5.1 Weather Meaning Is Authoritative

SkyAware consumes information from established weather sources, including:

- Apple WeatherKit.
- Storm Prediction Center (SPC).
- National Weather Service (NWS).

Supplemental numerical-model guidance may be used where supported by the product.

Different sources serve different purposes.

Forecast conditions, categorical outlooks, severe probabilities, official alerts, and model-derived environmental guidance must not be presented as interchangeable evidence.

Preserve source provenance and the distinction between:

- Observation and forecast.
- Probability and potential intensity.
- Official alert and supplemental analysis.
- Current accepted information and transient refresh activity.
- Known absence of a threat and unavailable information.

The application may simplify presentation, but it must not simplify away these distinctions.

## 5.2 Quiet Does Not Mean Universally Safe

A quiet severe-weather assessment describes the available evidence within SkyAware's defined scope.

It does not guarantee that dangerous weather cannot occur.

Avoid broad user-facing claims such as:

- "All Clear"
- "Completely Safe"
- "No Danger"

Preferred scoped concepts include:

- "Quiet Weather"
- "No Severe Storm Risk"
- "No Active Threats"

Use these only when supported by the corresponding accepted data.

Do not present missing, unresolved, expired, or unavailable information as confirmed quiet weather.

An internal enumeration named `allClear` does not authorize a broad user-facing safety claim.

Green is a semantic quiet/low-risk state, not a generic guarantee of safety or a general-purpose success color.

## 5.3 Uncertainty Must Remain Visible

SkyAware should communicate what is known without exaggerating what can be inferred.

In particular:

- A forecast probability is not a guaranteed outcome.
- Potential intensity is not the probability of occurrence.
- A model-derived environment is not an official warning.
- An expired forecast is not a current forecast.
- A missing hazard signal is not evidence that the hazard has been ruled out.
- Background notification delivery is not guaranteed.

When evidence is insufficient, omission or an appropriately scoped unavailable state is preferable to invented certainty.

---

# 6. Primary User Experience

## 6.1 Today Is the Product's Center of Gravity

The Today screen is SkyAware's primary user experience.

It should answer five questions:

1. Where am I?
2. What is it like right now?
3. How concerning is the current severe-weather picture?
4. What official alerts or relevant discussions are active?
5. What deserves my attention next?

Users should be able to understand the most important information without scrolling through secondary detail.

Advanced meteorological information remains available through progressive disclosure.

## 6.2 Today Content Responsibilities

Today brings together current local conditions, the primary awareness assessment with supporting Storm, Severe, and Fire risks, local alerts, environmental context, and source attribution. It interprets the local severe-weather picture; broader outlook discussion and history belong in the dedicated Outlooks experience.

Storm Setup appears when enabled and eligible. Location Reliability appears when eligible.

The exact section order and conditional placement are owned by [Today's canonical composition](../design/today.md#2-canonical-today-composition).

The content plan is conditional.

Optional sections do not leave empty spaces when inapplicable.

When Storm Setup is eligible, its analyzing, unavailable, analysis-not-needed, and resolved states occupy the same logical section position.

Do not create a permanently visible section merely to maintain a symmetrical screen.

---

# 7. Current Conditions

Current Conditions provides immediate local weather context.

Its core responsibilities are:

- Identify the current location.
- Display the current temperature.
- Communicate the current weather condition.
- Provide appropriate information about transient location or weather availability.

It supports situational awareness but is not itself a severe-weather risk assessment.

The location and weather presentation must remain accurate when location authorization, accuracy, or availability changes.

Transient refresh activity should not displace otherwise valid accepted weather information.

---

# 8. Today's Awareness

## 8.1 Core Responsibility

Today's Awareness is the primary severe-weather assessment surface.

It presents one dynamic primary awareness hero selected from the strongest relevant local signal.

Storm Risk, Severe Risk, and Fire Risk remain available as supporting information beneath the hero.

The supporting categories must not disappear simply because one category becomes the primary awareness signal.

## 8.2 Primary Awareness Precedence

The established selection priority is:

1. Active warning or watch.
2. Non-clear severe threat.
3. Non-clear storm risk.
4. Elevated fire risk.
5. Resolving state.
6. Quiet state.

Preserve the existing domain rules that determine the most relevant active warning or watch.

Do not change primary selection merely to improve visual balance or emphasize a preferred hazard.

The hero should communicate the strongest actionable awareness signal available from accepted state.

## 8.3 Four-Card Awareness Family

Today's Awareness consists of:

- One primary hero.
- Storm Risk.
- Severe Risk.
- Fire Risk.

On iPhone, the three supporting risk cards use a consistent full-width vertical arrangement.

Do not return to the superseded side-by-side Storm/Severe arrangement on wider phones.

The hero maintains the strongest hierarchy.

Supporting risk cards remain concise, individually recognizable, and easy to scan.

The four cards share a coordinated semantic presentation language.

Quiet states should remain calm but visually distinctive. Elevated states should have appropriately stronger semantic presence. Active warnings should receive the greatest emphasis.

The detailed gradient, surface, color, geometry, and navigation-affordance rules belong in `docs/design/today.md`.

## 8.4 Navigation Must Reflect Meaning

Today's Awareness cards are meaningful navigation surfaces.

Preserve established destinations:

- Storm Risk opens the appropriate categorical risk Map layer.
- Severe Risk opens the relevant severe-hazard Map layer.
- Fire Risk opens the fire-weather Map layer.
- The primary hero opens its established Alerts or Map destination when one exists.

The primary hero may also be noninteractive.

A noninteractive hero must not advertise navigation.

Visual affordances must accurately represent actual actions.

The full actionable card should remain the interaction target rather than introducing competing controls within it.

Navigation changes require an explicit product decision; they must never emerge accidentally from visual refinement.

---

# 9. Storm, Severe, and Fire Risk

## 9.1 Storm Risk

Storm Risk communicates the established categorical severe-convective outlook for the user's location.

The category, supporting explanation, and semantic color must remain consistent with accepted SPC-derived information.

Do not reinterpret categorical severity to create a more dramatic user experience.

## 9.2 Severe Risk

Severe Risk communicates the most relevant supported local severe-weather hazard.

The established hazard categories include:

- Tornado.
- Wind.
- Hail.

Probability and conditional-intensity meaning must remain distinct.

Where applicable, the Severe Risk supporting card also owns the local conditional-intensity explanation.

That modifier must not be moved into unrelated risk cards or become a separate competing awareness category.

## 9.3 Fire Risk

Fire Risk is a distinct severe-weather awareness category.

It retains its own semantic interpretation and color ladder.

Elevated fire conditions may become the primary awareness signal when established precedence selects them.

Fire weather should not be visually or semantically conflated with convective storm risk.

---

# 10. Conditional Severe-Weather Intensity

Conditional intensity describes the potential severity of a hazard **if that hazard occurs**.

It does not increase the probability that the hazard will occur.

This distinction is fundamental.

## 10.1 Supported Hazard Meanings

The established increasing intensity descriptions are:

| Hazard | Level 1 | Level 2 | Level 3 |
| --- | --- | --- | --- |
| Tornado | Strong tornadoes possible | More intense tornadoes possible | Highest tornado intensity potential |
| Wind | Destructive gusts possible | More intense wind damage possible | Highest wind intensity potential |
| Hail | Very large hail possible | Giant hail possible | Not supported |

Hail does not have a third supported intensity level.

Each label must be accompanied by hazard-conditional explanatory meaning.

Use the following explanatory meanings for the corresponding supported levels:

| Hazard | Level 1 meaning | Level 2 meaning | Level 3 meaning |
| --- | --- | --- | --- |
| Tornado | If tornadoes form, there is greater potential for strong tornadoes. | If tornadoes form, there is higher potential for stronger and more damaging tornadoes. | If tornadoes form, this represents the highest tornado intensity potential. |
| Wind | If damaging winds occur, especially strong gusts are possible. | If damaging winds occur, stronger wind gusts are possible. | If damaging winds occur, this represents the highest wind intensity potential. |
| Hail | If severe hail occurs, larger hailstones are possible. | If severe hail occurs, this represents the highest hail intensity potential. | Not supported |

These descriptions are neither guaranteed outcomes nor absolute upper limits.

Conditional intensity does not independently establish storm mode, spatial coverage, or a broader weather event.

The mapping follows SPC conditional-intensity guidance:

https://www.weather.gov/media/rah/ConditionalIntensityPresentation.pdf

## 10.2 Source and Eligibility Contract

Local conditional intensity must correspond to the actual displayed severe hazard and accepted local outlook.

The established eligibility rules require:

- A displayed non-clear severe hazard.
- Matching device-location context.
- Matching accepted outlook identity.
- Active local stored polygons.
- A matching base probability polygon.
- The highest containing supported intensity level.

Do not transfer intensity from a different hazard.

A storm, fire, or quiet hero does not independently inherit the severe-intensity modifier.

The Severe Risk supporting card remains its sole Today presentation owner, including beneath an alert hero.

## 10.3 Freshness and Failure Semantics

Conditional intensity must be omitted when:

- The required identity cannot be established.
- The accepted outlook has been replaced.
- The supporting data has expired.
- The relevant geometry cannot be read.
- No matching supported hazard is present.
- No-cache resolving or unavailable state prevents a trustworthy determination.

Cached-refreshing and offline presentations may retain the modifier only while the same provenance, identity, and validity requirements continue to hold.

Missing intensity is not a quiet-state determination.

The existing product derives local intensity from accepted stored geometry.

Do not introduce a separate persisted intensity field or additional network dependency without an explicit architectural and product decision.

## 10.4 Shared Today and Map Interpretation

Today and Map must communicate compatible interpretations of the same conditional-intensity evidence.

The established distinction is:

- Color communicates probability or established risk.
- Hatching communicates conditional potential intensity.

Neither may replace the other.

Users should be able to understand the meaning through plain-language descriptions without being required to decode the hatching visually.

---

# 11. Local Alerts

Local Alerts presents official alerts and relevant discussions affecting the user's location.

The established category order is:

1. Warnings.
2. Watches.
3. Mesoscale discussions.

Preserve the existing domain interpretation and ordering within these categories.

At summary level, communicate:

- Event type.
- Applicable end or expiration time.
- Concise threat meaning.
- Whether additional detail is available.

Do not overload the summary with administrative metadata.

## 11.1 Active Warning Hero

An active warning may become the primary awareness hero.

When it does, the hero should communicate:

- The warning type.
- Valid-until information.
- Primary threat summary.
- Actionable guidance when supplied by applicable authoritative alert information.

Never invent emergency instructions from the warning type alone.

Guidance must remain consistent with the actual alert and its threat meaning.

An active warning can deserve more attention than forecast probabilities without changing the meaning of those probabilities.

## 11.2 Alert Detail

Alert detail surfaces should preserve meaningful source information, including:

- Event identity.
- Relevant issued, valid, and expiration times.
- Hazard summary.
- Instructions when available.
- Source or issuing office.
- Severity, certainty, and urgency where supported.

Weather meaning takes priority over decorative status presentation.

---

# 12. Atmospheric Conditions

Atmospheric Conditions provides supporting environmental instrumentation.

It is not an independent severe-weather risk assessment and must not compete with Today's Awareness.

The established five measurements are:

1. Air Quality.
2. Visibility.
3. Pressure.
4. Humidity.
5. Wind.

The measurements are peers.

They provide useful local context without introducing another primary hero metric.

## Measurement Responsibilities

**Air Quality**

Preserve the available AQI value and its established health-category meaning.

AQI semantic coloring must not be confused with severe-weather risk coloring.

**Visibility**

Present current visibility with concise, appropriate context.

**Pressure**

Present current pressure and the available WeatherKit pressure trend.

Do not introduce historical pressure-storage or trend-reconstruction infrastructure merely for this display.

**Humidity**

Present relative humidity as contextual instrumentation.

Do not imply that humidity alone determines severe risk.

**Wind**

Present direction and speed, including gust context when available and relevant.

## Dew Point Ownership

Dew point is not a primary Atmospheric Conditions metric.

It belongs within Storm Setup's **Fuel & Instability** ingredient context, where its meteorological significance can be evaluated alongside other convective ingredients.

Do not restore a standalone dew-point hero or the older dew-point-led atmospheric presentation.

The established visual layout and accessibility behavior belong in `docs/design/today.md`.

---

# 13. Storm Setup

Storm Setup is optional, supplemental meteorological guidance for users who enable it and have eligible local information.

Its purpose is to explain the environmental ingredients that may support severe thunderstorms.

It is not an official warning, watch, or independent prediction of a tornado occurring at the user's location.

## Product Responsibilities

Storm Setup should:

- Present an understandable assessment.
- Explain meaningful supporting or limiting ingredients.
- Identify uncertainty.
- Distinguish model guidance from observed conditions.
- Preserve appropriate model provenance.
- Support deeper meteorological exploration on demand.

The summary should prioritize plain-language meaning.

Detailed composite parameters and diagnostic terminology belong in the Storm Setup detail experience when useful.

For example:

- Prefer "Model signals differ" to an internal diagnostic disagreement label.
- Prefer "Storm mode is uncertain" to a raw missing-input diagnostic.

Forecast provenance such as HRRR guidance must be identified as model guidance, not an observation or official warning.

## Supported Presentation States

Storm Setup may communicate:

- Resolved environmental guidance.
- Analysis in progress.
- No notable setup.
- Analysis not needed.
- Unavailable guidance.

These states are meaningfully different.

Do not convert missing or unavailable analysis into a confident environmental conclusion.

---

# 14. Location Reliability

Location Reliability is a conditional, dismissible awareness prompt.

Its purpose is to explain how appropriate background location access may improve severe-weather awareness.

It is not a generic permission campaign.

The prompt should appear only when the established eligibility rules justify it, considering:

- Current location authorization.
- Location accuracy.
- Relevant local risk.
- Prompt history and dismissal state.

Preserve user choice.

Do not imply that granting Always location access guarantees background updates or notification delivery.

The prompt occupies its established conditional position within the Today section plan.

---

# 15. Outlooks, Watches, and Mesoscale Discussions

These product families expose deeper weather information without competing with primary awareness.

Each experience should preserve:

- Correct product identity.
- Source provenance.
- Relevant validity times.
- An understandable summary.
- Appropriate detailed information.
- Consistent navigation behavior.

The dedicated Outlooks experience is the destination for broader forecast discussion and history. Today communicates locally relevant SPC information through Storm Risk, Severe Risk, and Today’s Awareness. No Outlook Summary is required on Today.

Different meteorological products may share structural presentation conventions while retaining their distinct meaning.

---

# 16. Map

The Map is SkyAware's spatial severe-weather awareness surface.

It helps users understand where relevant risks and official alerts exist relative to their location.

The Map is not a general-purpose weather explorer.

Its primary responsibilities are:

- Display established severe-weather risk layers.
- Display relevant warning and hazard information.
- Preserve established probability and color semantics.
- Explain hatching and conditional intensity where available.
- Provide clear layer selection and map interpretation.
- Retain established camera and location behavior.

## Product Boundaries

Do not introduce new capabilities merely because they appear in conceptual renderings.

In particular, the redesign direction does not authorize:

- Radar.
- Additional speculative weather layers.
- New recenter/current-location behavior.
- Unnecessary forecasting products.
- Changes to existing map camera behavior.
- New interpretation of established polygon data.

Any genuine new Map capability requires its own product decision and implementation scope.

The underlying weather information must remain more important than the controls used to explore it.

---

# 17. WidgetKit and Glanceable Awareness

SkyAware widgets extend severe-weather awareness beyond the application.

They should communicate useful information quickly, within the constraints of their platform and size.

Widgets are not miniature reproductions of the full Today experience.

## Product Priorities by Family

**Small**

Communicate one primary awareness concept with complete, appropriately scoped meaning.

**Medium**

Communicate immediate awareness with useful location identity and a limited set of supporting information.

**Large**

Prioritize active alerts and meaningful supporting risk context.

The amount of information presented must remain appropriate for available space.

## Alert Priority

When active alerts exist, they take precedence over secondary risk summaries.

Alert content, overflow descriptions, and supporting risk information must remain meaningfully distinct.

Do not lose important alert meaning merely to preserve decorative layout symmetry.

## Widget Trust Rules

- Preserve accepted state and valid cached information.
- Keep user-facing risk wording appropriately scoped.
- Do not broaden quiet-state meaning into universal safety.
- Do not show unnecessary "as of" timestamps, including in accessibility descriptions.
- Preserve correct location context.
- Never invent risk data when it is unavailable.
- Respect WidgetKit rendering and accessibility behavior.

Widget family layouts, semantic accents, and detailed composition requirements belong in `docs/design/widgets.md`.

---

# 18. Loading, Refreshing, and Accepted State

SkyAware follows a **cached-first, resolve-forward** presentation model.

This is a product invariant.

## 18.1 Last-Known-Good Presentation

When meaningful accepted cached data exists:

- Present it immediately.
- Keep it visible while checking for updates.
- Preserve the current information hierarchy.
- Replace it with a coherent accepted revision.
- Do not expose intermediate ingestion or partially assembled state.
- Do not blank the screen during routine refresh.
- Do not animate unchanged data as though it changed.

A background refresh may update canonical state, but background execution is not deterministic.

When the application opens, valid accepted state should be available without unnecessary presentation churn.

## 18.2 First Load

A dedicated full-screen resolving experience is appropriate only when meaningful cached content does not exist.

It should communicate that SkyAware is assembling the local weather picture.

The preferred concept is:

"Getting your conditions ready"

Do not use a generic spinner-first loading experience when meaningful information can already be displayed.

## 18.3 State Distinctions

Maintain distinct meanings for:

- Current accepted data.
- Cached accepted data.
- Cached data with refresh in progress.
- Resolving without cached data.
- Confirmed absence of a threat or alert.
- Unavailable data.
- Offline operation.
- Stale or degraded data.

These states must not be collapsed merely because they would otherwise require different presentation.

A refresh is activity, not a new weather assessment.

## 18.4 Status Communication

Transient status belongs in an appropriate existing status or header location.

Use concise, user-centered progress language.

Avoid internal terminology such as:

- Fetching.
- Processing.
- Finalizing data.
- Synchronizing providers.

Detailed status vocabulary belongs in `docs/brand/brand-and-voice.md`.

Presentation transitions must preserve spatial and semantic continuity.

---

# 19. Notifications

SkyAware notifications are interruptions intended to communicate meaningful weather changes.

They require particular care because users may act on their content immediately.

## Notification Responsibilities

**Title**

Communicate what happened.

**Subtitle**

Explain why the user received the notification.

**Body**

Explain the threat, change, or relevant consequence.

Notification language must reflect:

- Severity.
- Urgency.
- Certainty.
- Geographic relevance.
- Actual source information.

Do not manufacture urgency through copy.

Do not imply that a warning includes the user's location unless that relationship has been established.

Do not imply that a forecast changed when the apparent difference was caused by the device moving to another location.

Do not treat a notification as proof that background execution or delivery will always occur.

Preserve the distinction between official alert content and SkyAware's supplemental awareness.

Detailed vocabulary, examples, and notification copy conventions belong in the Brand document.

---

# 20. Accessibility and Platform Behavior

Accessibility is part of product correctness.

Core severe-weather meaning must remain available regardless of:

- Dynamic Type size.
- VoiceOver usage.
- Increase Contrast.
- Reduce Motion.
- Reduce Transparency.
- Device dimensions.
- Supported appearance modes.

Essential information must not depend exclusively on color, animation, iconography, or texture.

Long weather descriptions must remain understandable rather than being arbitrarily clipped or compressed.

Interactive surfaces must communicate their actual behavior through native interaction and appropriate accessibility semantics.

The product should remain recognizably SkyAware across accessibility adaptations.

Specific layout and interaction requirements belong in the Design documentation.

---

# 21. Privacy and User Agency

SkyAware should request and use information only when it supports a meaningful product capability.

Location is central to hyper-local awareness, but its handling must remain transparent and respectful of user choice.

Principles:

- Explain the benefit of permissions clearly.
- Do not exaggerate the consequences of declining.
- Do not repeatedly pressure users.
- Preserve useful functionality when reduced permissions still permit it.
- Avoid unnecessary collection or retention.
- Keep privacy expectations consistent with actual application and service behavior.

A more permissive authorization state should improve capability where supported, not become a prerequisite for ordinary product trust.

---

# 22. Product Boundaries and Scope Discipline

SkyAware should grow by solving meaningful awareness problems, not by accumulating weather features.

Before introducing a capability, ask:

1. Does this improve severe-weather awareness?
2. Does it make the user's next decision clearer?
3. Can existing sources and product structures support it?
4. Does it create new uncertainty or interpretation risk?
5. Can it remain supplemental without weakening the primary experience?
6. Is the added complexity justified by real user value?

Favor existing Apple and weather-platform capabilities over custom infrastructure when they solve the problem reliably.

Do not introduce new data pipelines, persistent fields, state owners, or services merely to support decorative or speculative UI behavior.

Preserve the separation between:

- Accepted weather state.
- Transient refresh/activity state.
- Domain interpretation.
- Persistence.
- Presentation.
- Source-specific ingestion.

Architecture should reinforce trust and clarity, not become a visible product feature.

---

# 23. Product Decision Boundaries

The following decisions are established product direction:

- SkyAware is a severe-weather awareness assistant.
- Today is the primary awareness experience.
- One dynamic hero owns the leading awareness signal.
- Storm, Severe, and Fire remain visible beneath it.
- Supporting risk cards are full-width and vertically stacked on iPhone.
- Warning/watch precedence and risk selection semantics are preserved.
- Quiet-state language must not overclaim safety.
- Conditional intensity is distinct from probability.
- Storm Setup is supplemental model-guided context.
- Dew point belongs with Storm Setup ingredients.
- Atmospheric Conditions uses five peer measurements.
- Map remains awareness-focused.
- Widgets prioritize glanceability and correct weather meaning.
- Valid cached state remains visible during refresh.
- Light and dark appearance are equally important.
- Native interaction and accessibility are product requirements.
- Visual quality must support weather meaning rather than compete with it.

Changing one of these decisions requires an intentional product discussion.

A visual implementation issue, cleanup task, or generated design concept does not implicitly authorize changing them.

---

# 24. Definition of Product Success

SkyAware succeeds when users can quickly understand:

- Their current local weather situation.
- Whether meaningful severe-weather threats exist.
- Which hazard deserves attention.
- Whether official alerts affect their location.
- What additional information is available.
- What the available evidence does and does not establish.

The application should feel:

- Calm without being visually timid.
- Informative without being dense.
- Premium without excessive decoration.
- Apple-native without losing identity.
- Trustworthy without overclaiming certainty.
- Useful in ordinary weather and during genuinely consequential events.

Correctness, clarity, resilience, and craftsmanship must reinforce one another.

The ideal experience does not draw attention to how much meteorological complexity SkyAware manages.

It simply makes the local weather picture easier to understand.

---

# 25. Product Review Questions

Before accepting a meaningful product or UX change, ask:

1. Does this improve the user's understanding of severe-weather awareness?

2. Does it preserve correct source meaning, uncertainty, and accepted-state behavior?

3. Is the most important information immediately recognizable?

4. Does the experience remain honest during quiet, elevated, unavailable, cached, and offline states?

5. Are navigation and interaction behavior predictable?

6. Does it respect existing product boundaries rather than introducing speculative functionality?

7. Does it preserve accessibility and user agency?

8. Does it make SkyAware feel more coherent and deliberately crafted?

9. Would a simpler solution provide the same user value with less complexity?

10. Does this remain consistent with the canonical
    Brand and Design documentation?

If a change improves appearance while weakening trust, clarity, or weather meaning, it is not an improvement.

---

# Final Principle

**SkyAware exists to make severe-weather awareness understandable, timely, and trustworthy.**

Everything else serves that purpose.

The product's visual identity, native behavior, meteorological intelligence, and technical architecture should work together to make complex weather information feel clear and actionable.

Build the experience with precision, restraint, and care.

Preserve what works.

Change what materially improves the user's understanding.

Do not introduce complexity simply because it is possible.
