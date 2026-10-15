---
title: SkyAware Brand and Voice
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - brand
  - voice
  - identity
---

# SkyAware Brand and Voice

## Purpose

This document defines how SkyAware expresses its identity and communicates with users.

It establishes the product's brand character, voice, terminology, communication principles, and marketing standards.

Its purpose is to ensure that SkyAware remains recognizable, consistent, trustworthy, and deliberately crafted as the product evolves.

This document governs:

- Brand personality and positioning.
- Written communication and terminology.
- Communication of weather risk and uncertainty.
- Notification copy.
- Loading, status, and availability language.
- Brand identity and official assets.
- Marketing and App Store communication.
- Editorial consistency across product surfaces.

It does not define component geometry, specific layouts, SwiftUI implementation, or detailed visual styling.

Related canonical documentation:

- `docs/product/north-star.md` — product identity, priorities, behavior, and meteorological meaning.
- `docs/design/README.md` — visual and interaction design documentation and implementation contracts.

Documentation responsibilities:

**North Star owns product truth.**

**Brand and Voice owns communication and identity.**

**Design owns visual and interaction implementation.**

When communication and meteorological interpretation intersect, the North Star's product and trust requirements take precedence.

When detailed styling or interaction questions arise, consult the appropriate Design document rather than inventing new brand-level implementation rules.

---

# 1. Brand Identity

## What SkyAware Represents

SkyAware is a severe-weather awareness assistant.

It helps people understand when the weather deserves their attention.

Its central promise is:

> How weather-aware do I need to be right now?

SkyAware translates complex meteorological information into a clear understanding of local conditions, risks, and relevant official weather information.

The brand should convey competence without arrogance, confidence without overstatement, and calm without indifference.

SkyAware is designed for people who want to understand their weather environment without being overwhelmed by information.

It should remain approachable to general users while providing meaningful depth for weather-aware enthusiasts.

## Brand Traits

SkyAware should consistently feel:

- Calm.
- Clear.
- Precise.
- Trustworthy.
- Local.
- Useful.
- Elegant.
- Restrained.
- Refined.
- Quietly intelligent.
- Deliberately crafted.

The brand should avoid feeling:

- Sensational.
- Alarmist.
- Playful in serious situations.
- Gimmicky.
- Overly technical.
- Robotic.
- Pretentious.
- Visually chaotic.
- Generic or interchangeable.

Every interaction should reinforce the impression that the product was built with care.

---

# 2. Brand Positioning

## Severe-Weather Awareness, Not Generic Weather

Most weather applications provide broad collections of weather information.

SkyAware focuses on helping users understand the local severe-weather picture.

Its differentiating characteristics are:

- Hyper-local relevance.
- Severe-weather focus.
- Clear risk interpretation.
- Meaningful official alert awareness.
- Supporting meteorological context.
- Progressive disclosure of deeper information.
- A calm, focused experience.

The goal is not to display everything.

The goal is to communicate what matters.

## Core Messaging

Preferred positioning concepts:

- Severe-weather awareness without the noise.
- Understand your local severe-weather risk.
- Know when weather deserves your attention.
- Clear awareness of changing local conditions.
- Meaningful weather information, without overload.

These are messaging directions, not mandatory taglines for every surface.

Select wording that accurately represents the current product and intended audience.

Avoid positioning SkyAware primarily as:

- A radar application.
- An emergency warning replacement.
- A storm prediction engine.
- An AI weather forecaster.
- A general-purpose weather dashboard.
- A professional meteorological analysis platform.

Do not invent capabilities to strengthen positioning.

## Demonstrate Quality Rather Than Claim It

Internally, SkyAware is held to a high-end product standard.

Externally, avoid relying on claims such as:

- Premium.
- Luxury.
- Professional-grade.
- Most accurate.
- Best-in-class.
- Revolutionary.

The quality of the experience should establish those impressions naturally.

Precision, restraint, clarity, and consistency communicate more than marketing adjectives.

---

# 3. Brand Voice

## Voice Characteristics

SkyAware speaks in a voice that is:

**Direct**

Communicate the important information first.

**Human**

Use natural language rather than internal system terminology.

**Grounded**

Avoid certainty that the underlying information does not support.

**Concise**

Every sentence should contribute useful meaning.

**Weather-literate**

Communicate meteorological concepts accurately without requiring users to understand technical jargon.

**Calm**

Do not manufacture urgency.

**Respectful**

Allow users to interpret information without being talked down to or unnecessarily reassured.

## Tone by Situation

The underlying brand voice remains consistent, but emphasis changes with the situation.

### Quiet Weather

Tone:

- Calm.
- Matter-of-fact.
- Reassuring through clarity.
- Appropriately scoped.

Example:

"No Severe Storm Risk"

Avoid:

"You're completely safe today!"

Quiet weather is a weather assessment, not a universal safety guarantee.

### Elevated Risk

Tone:

- Attentive.
- Clear.
- More direct.
- Specific about the hazard.

Example:

"Several severe storms are possible."

Avoid:

"Dangerous storms are coming!"

Do not convert probability into certainty.

### Active Warning

Tone:

- Immediate.
- Clear.
- Action-oriented when justified.
- Faithful to authoritative information.

Identify the warning, affected area, and meaningful threat information.

Use emergency instructions only when justified by the actual warning and applicable guidance.

Avoid dramatic wording that adds urgency beyond the source information.

### Unavailable or Degraded Information

Tone:

- Transparent.
- Calm.
- Useful.
- Nondefensive.

Communicate what is unavailable and, when appropriate, what information remains usable.

Avoid presenting uncertainty as normal conditions.

Do not apologize repeatedly for routine provider or connectivity limitations.

---

# 4. Communication Principles

## Information Before Explanation

Lead with the conclusion or condition.

Provide supporting context afterward.

For primary surfaces:

1. Identify what matters.
2. Explain its significance briefly.
3. Offer additional detail when useful.

Do not require users to read an explanatory paragraph before discovering the current risk.

## Precision Over Drama

Prefer:

"Damaging winds and large hail possible."

Avoid:

"Powerful storms could unleash devastating weather!"

Use stronger language only when supported by the actual hazard information.

## Scoped Statements

Every weather statement has an implied scope.

That scope may include:

- A particular hazard.
- A geographic area.
- A time period.
- An accepted forecast.
- An active official alert.
- Available supporting evidence.

Do not silently expand a narrow statement into a broad conclusion.

For example:

"No Active Threats"

does not mean:

"No dangerous weather can occur."

Likewise, an unavailable alert feed does not support a claim of no active alerts.

## Explain Uncertainty Without Overexplaining

Users should understand uncertainty when it materially affects their interpretation.

Avoid overwhelming the primary experience with technical disclaimers.

Prefer concise, contextual explanation, with deeper detail available on demand.

## Progressive Disclosure

SkyAware serves both ordinary users and people interested in meteorological detail.

Primary surfaces use plain language.

Detail surfaces may introduce technical terms when those terms improve understanding.

A technical parameter should earn its place in the interface.

Do not expose internal terminology merely because it exists in the underlying data.

---

# 5. Canonical Product Vocabulary

Use established product labels consistently.

| Concept | Canonical user-facing label |
| --- | --- |
| Current local weather | Current Conditions |
| Primary risk assessment | Today's Awareness |
| Convective category | Storm Risk |
| Principal severe hazard | Severe Risk |
| Fire-weather assessment | Fire Risk |
| Local official alerts and discussions | Local Alerts |
| Supporting environmental measurements | Atmospheric Conditions |
| Convective environmental analysis | Storm Setup |
| Location-permission guidance | Location Reliability |
| Convective outlook summary | Outlook Summary |
| Map severe-risk selector | Severe Risk |

Do not introduce alternative labels merely for stylistic variety.

Consistency is more valuable than novelty.

## Quiet-State Terminology

Preferred examples:

- Quiet Weather.
- No Severe Storm Risk.
- No Active Threats.
- No active alerts for your location.

These phrases are not interchangeable.

Each must be used only for the specific state it accurately describes.

Avoid broad safety claims, especially:

- All Clear.
- Completely Safe.
- No Danger.
- Nothing to Worry About.

Internal model names such as `allClear` do not establish approved user-facing wording.

## Meteorological Terminology

Technical language is appropriate when it provides meaningful context.

However, primary surfaces should prefer plain-language explanations.

Internal terms such as:

- CIG.
- CIG1 / CIG2 / CIG3.
- Raw diagnostic parameter names.
- Provider-specific processing terminology.

should not appear in primary awareness copy.

Conditional intensity should be described through its actual hazard meaning.

Preferred user-facing concepts include:

- Hatching.
- Stronger storms possible.
- Strong tornadoes possible.
- Destructive gusts possible.
- Very large hail possible.

The precise supported intensity descriptions and eligibility requirements are defined in the North Star.

## Forecast and Model Provenance

When communicating supplemental model guidance, preserve its identity as forecast guidance.

For example:

"HRRR guidance"

may be appropriate in Storm Setup detail.

Do not present model-derived analysis as:

- An observation.
- An official watch.
- An official warning.
- A guaranteed outcome.

---

# 6. Writing Style

## Sentence Structure

Prefer:

- Short sentences.
- Direct statements.
- Familiar vocabulary.
- Strong verbs.
- One primary idea per sentence.

Avoid:

- Excessive qualifiers.
- Repeated explanations.
- Promotional adjectives.
- Elaborate metaphors.
- Unnecessary technical detail.
- Formal or bureaucratic phrasing.

## Headings and Labels

Headings should be:

- Short.
- Meaningful.
- Consistent.
- Easy to scan.

Avoid changing established labels simply to make the UI sound different.

## Supporting Copy

Supporting text should explain meaning, not repeat the heading.

Example:

Heading: "Enhanced Risk"

Supporting text: "Several severe storms are possible."

Avoid repeating the category in the explanation without adding useful context.

## Ellipsis

Use the true ellipsis character:

`…`

rather than three periods:

`...`

Use ellipses where they communicate ongoing activity, not as decorative punctuation.

## Capitalization

Use consistent capitalization within the same component family.

Preserve established names and labels.

Do not introduce arbitrary all-caps emphasis to manufacture urgency.

## Punctuation

Prefer simple, complete wording.

Avoid excessive exclamation marks.

Severe-weather urgency should come from the actual information, not punctuation.

---

# 7. Loading, Resolving, and Status Language

SkyAware should feel like it is assembling or updating the local weather picture.

It should not expose internal processing as the primary user experience.

## Preferred Language

For the initial no-cache experience:

"Getting your conditions ready"

Other appropriate progress messages include:

- Finding your location…
- Getting your area ready…
- Bringing in your conditions…
- Getting your location…
- Updating your conditions…
- Getting storm risk…
- Bringing in local alerts…
- Getting everything ready…

Messages should correspond to actual activity.

Do not randomly rotate status text without a meaningful relationship to the work being performed.

## Language to Avoid

Avoid generic or technical messages such as:

- Loading data…
- Fetching…
- Processing…
- Resolving local weather context…
- Finalizing data…
- Synchronizing providers…

A provider name should appear only when its identity is meaningful to the user.

## Status Must Reflect Reality

Do not display an updating message when the application is known to be offline and no update is occurring.

Do not claim that information is ready before an accepted result exists.

Do not display a quiet-state message when the underlying evidence is unavailable.

Cached information may remain visible while refresh activity proceeds.

Status language should support that continuity rather than suggesting the entire screen is loading again.

---

# 8. Alerts and Watches

Official weather information demands particularly disciplined communication.

## Summary Copy

Alert summaries should communicate:

- Event type.
- Meaningful local relevance.
- End or expiration time where available.
- Concise threat information.

Avoid dumping administrative metadata into the summary.

## Detail Copy

Detailed alert surfaces may include:

- Issuing office.
- Issue and validity times.
- Severity.
- Certainty.
- Urgency.
- Instructions.
- Geographic information.
- Additional source details.

Preserve authoritative wording where its precision is important.

## Lifecycle Language

Differentiate:

- Newly issued.
- Updated.
- Expanded or newly affecting the location.
- No longer affecting the location.
- Cancelled.
- Expired.

These are distinct events.

Avoid describing a changed location as a changed forecast when the underlying weather product has not changed.

Likewise, do not describe an updated weather product as a location change.

---

# 9. Notification Copy

Notifications are interruptive communication.

Every word must justify the interruption.

Their job is to tell the user:

- What happened.
- Why it matters to them.
- What relevant threat information is available.

## Field Responsibilities

### Title

**What happened?**

Usually the event name.

Lifecycle information such as cancellation or expiration may be included when appropriate.

### Subtitle

**Why did I receive this?**

Communicate geographic relevance or the reason for the notification.

Examples, when supported:

- Includes your location.
- Now includes your location.
- Updated for your area.
- No longer affecting your area.
- Cancelled for your area.
- For Weld County.
- For your area.

Do not claim location inclusion without supporting targeting evidence.

### Body

**What is happening, and why does it matter?**

Keep the message:

- Hazard-specific.
- Concise.
- Accurate.
- Appropriate to the warning lifecycle.
- Consistent with severity, urgency, and certainty.

Illustrative hazard language:

- Damaging winds and large hail possible.
- Flash flooding expected.
- Critical fire weather conditions.

These are examples of tone, not automatic text for every related product.

Instructions such as "Seek shelter now" must be justified by the actual alert and applicable authoritative guidance.

## Internal Tone Model

Notification wording may be shaped by established internal classifications such as:

- Critical.
- High.
- Elevated.
- Informational.

These are implementation-level tone inputs, not necessarily labels shown to the user.

Their use must remain consistent with available NWS severity, urgency, certainty, and lifecycle metadata.

## Notification Trust

Do not imply:

- Guaranteed delivery.
- Guaranteed immediacy.
- Broader coverage than implemented.
- Official warning authority.
- Certainty of a forecast outcome.

SkyAware is an awareness assistant.

Official NWS warnings and local emergency authorities remain the appropriate sources for emergency instructions.

---

# 10. Permissions, Privacy, and Reliability Copy

Communication about location, notifications, and background behavior must be transparent.

## Permissions

Explain what enabling a permission actually improves.

Examples of appropriate themes:

- Better local relevance.
- Improved background location context.
- More useful location-aware notifications.

Avoid:

- Fear-based permission requests.
- Repeated pressure after dismissal.
- Implying that permission grants guarantee delivery.
- Suggesting the application becomes unsafe or unusable without maximum permissions.

Preserve user agency.

## Reliability

Be direct about limitations when relevant.

SkyAware may depend on:

- Source availability.
- Network connectivity.
- Device location.
- Background execution.
- Notification delivery.

These systems have limitations.

Communicate the impact on the user rather than exposing unnecessary implementation detail.

## Privacy Claims

Privacy statements must reflect actual current product behavior and published disclosures.

Do not invent guarantees about:

- Data collection.
- Retention.
- Sharing.
- Device tracking.
- Location handling.
- Server processing.

Verify specific claims against the current privacy policy and implementation before using them in public copy.

---

# 11. Visual Brand Character

The detailed visual system is owned by the Design documentation.

This section defines only the character that the visual system should express.

## Calm Does Not Mean Colorless

SkyAware combines a restrained native foundation with a distinctive semantic weather identity.

Neutral surfaces, typography, spacing, and clear hierarchy establish calm.

Purposeful weather color establishes:

- Recognition.
- Relative importance.
- Hazard identity.
- State distinction.
- Visual continuity.

A calm design should not become visually anonymous.

Avoid two extremes:

**Too much decoration**

Color, effects, and materials compete with the weather information.

**Too little character**

Important information becomes visually indistinct or its interaction is concealed.

SkyAware's identity lives between them.

## Semantic Color

Weather color has meaning.

Do not reuse meaningful risk and hazard colors as arbitrary decoration.

The established color families include:

- Emerald/jade for quiet weather states.
- SPC-aligned colors for storm risk.
- Distinct tornado, wind, and hail colors.
- A separate fire-risk semantic ladder.
- A distinct mesoscale discussion identity.
- Neutral treatment for ordinary freshness and application status.

Green must not become a general-purpose "everything is good" indicator.

The precise color mappings, palettes, and gradient behavior belong in `docs/design/foundations.md` and the relevant surface specifications.

## Premium Visual Quality

SkyAware should look:

- Deliberate.
- Cohesive.
- Refined.
- Readable.
- Distinctive.
- Native to Apple platforms.

Avoid using:

- Excessive Glass.
- Heavy shadows.
- Glowing borders.
- Decorative gradients.
- Visual clutter.
- Arbitrary color changes.
- Generic weather illustrations.

Visual treatment should express actual information or interaction meaning.

The design should never feel expensive merely because more effects were applied.

---

# 12. Inspirations and Reference Points

SkyAware's established design inspirations are:

## Dark Sky

Borrow:

- Calm confidence.
- Immediate usefulness.
- Information hierarchy.
- Minimal friction.

## Apple Weather

Borrow:

- Platform refinement.
- Typography-led structure.
- Interaction predictability.
- Material and transition discipline.

Do not imitate its complete interface or broaden SkyAware into a generic weather application.

## Tide Guide

Borrow:

- Tasteful minimalism.
- Beautiful information density.
- Precise layout.
- Quiet premium character.

## Lumy

Borrow:

- Atmospheric refinement.
- Restrained motion.
- Visual polish.
- Deliberate use of color and space.

## CARROT Weather

Borrow selectively:

- Clear information framing.
- Strong summary hierarchy.
- Effective presentation of complex data.

Do not borrow:

- Novelty personality.
- Jokes.
- Sensationalism.
- Excessive visual activity.

These products are inspiration, not implementation templates.

SkyAware must maintain its own identity.

---

# 13. Official Brand Assets

## Logo and App Icon

Use official, approved SkyAware assets for production and marketing compositions.

Do not recreate, reinterpret, or approximate the SkyAware logo using image generation.

The application repository contains:

- `Resources/AppIcon.icon`
- `Resources/Icon/SkyAwareIcon.png`

The Icon Composer package is part of the application's icon implementation.

The PNG is an existing export/reference asset.

Before preparing a final public asset, verify that the selected artwork matches the current approved shipping icon.

Do not assume a historical export remains authoritative after an icon revision.

## Brand Asset Integrity

Preserve:

- Recognizable symbol geometry.
- Approved proportions.
- Appropriate visual contrast.
- Consistent background treatment.
- Established brand identity.

Do not substitute:

- Generic storm clouds.
- Lightning-bolt app icons.
- Unrelated tornado symbols.
- Synthetic weather logos.
- AI-generated approximations.

Generated artwork may provide atmosphere around an official brand asset.

It must not silently replace that asset.

---

# 14. Marketing and App Store Communication

Marketing should communicate SkyAware's value without exaggerating its capabilities.

## Core Marketing Goal

A prospective user should quickly understand:

- What SkyAware is.
- Why it exists.
- What makes it different.
- What information it provides.
- Why its presentation can be trusted.

## Writing Principles

Prefer:

- Direct benefit statements.
- Short explanations.
- Factual specificity.
- Clear severe-weather positioning.
- Meaningful feature descriptions.
- Honest limitations.

Avoid:

- Fear-driven messaging.
- Buzzwords.
- Excessive superlatives.
- Generic AI claims.
- Unsupported accuracy claims.
- Guaranteed safety claims.
- Overstated notification reliability.

## Screenshots and Product Imagery

App Store screenshots should represent the actual product.

Prefer:

- Real SkyAware UI.
- Meaningful weather states.
- Clear information hierarchy.
- Quiet and active examples.
- Current feature behavior.
- Deliberate visual consistency.

Avoid:

- Invented features.
- Synthetic product controls.
- Unsupported map layers.
- Decorative radar imagery that implies radar functionality.
- Unrealistic weather assessments.
- Repeated screenshots with little additional user value.

Generated atmospheric artwork may be appropriate for supporting marketing compositions.

However, final product screenshots and official brand assets must remain accurate and authentic.

Do not interpret a generated mockup as authority to change the product.

## Supporting Marketing Artwork

Prefer atmospheric skies, layered weather textures, soft restrained gradients, typography-led composition, generous negative space, and one clear visual focal point.

Avoid clipart-led compositions, cartoon storm imagery, overly dramatic or sensational weather artwork, and generic AI-generated weather imagery that conflicts with SkyAware's identity.

This guidance applies to supporting marketing artwork. It does not authorize changes to application UI, semantic weather colors, official weather graphics, or established product icon assets.

## Release Communication

Release notes should explain meaningful user-visible improvements.

Prefer:

- Clearer awareness.
- Improved navigation.
- Better reliability.
- More understandable alerts.
- Better accessibility.
- Meaningful new capabilities.

Avoid exposing implementation concepts that have no direct user value.

Examples:

- Actor isolation.
- Persistence acknowledgements.
- Cache invalidation mechanics.
- Transport provenance.
- Internal revision bookkeeping.

Translate engineering improvements into truthful user benefits.

## Current Public Listing

The current shipped App Store listing is recorded separately at:

`docs/marketing/app-store-listing.md`

That file is the record of published listing content.

Do not treat proposed copy in this brand guide as automatically approved or already published.

Follow the established release process when modifying App Store metadata.

---

# 15. Communication Across Surfaces

The brand voice must remain recognizable even when presentation constraints differ.

## Today

Prioritize immediate awareness.

Use short titles, clear values, and concise supporting explanations.

Avoid marketing language.

## Map

Use direct layer names and clear explanations of weather meaning.

Prefer user-facing terminology over internal product codes.

## Widgets

Communicate complete, appropriately scoped awareness with minimal words.

Never broaden or truncate weather meaning merely to fit a layout.

## Notifications

Prioritize relevance, urgency, and accurate lifecycle information.

Keep every word useful.

## Detail Screens

Allow more explanation and technical specificity where it improves understanding.

Maintain the same grounded voice.

## Settings and Permissions

Explain behavior, consequences, and user choice plainly.

Avoid implementation jargon, pressure, and unnecessary warnings.

## Marketing

Lead with the user benefit.

Demonstrate quality through clarity and truthful product evidence.

Do not turn SkyAware's in-app voice into promotional copy.

---

# 16. Editorial Anti-Patterns

Avoid introducing copy or imagery that:

- Implies universal safety.
- Invents weather certainty.
- Exaggerates urgency.
- Obscures source limitations.
- Makes a forecast sound like an observation.
- Confuses probability with intensity.
- Confuses a location change with a forecast change.
- Presents supplemental model guidance as an official alert.
- Claims notification delivery is guaranteed.
- Uses internal implementation terminology.
- Replaces useful content with decorative language.
- Uses inconsistent names for the same feature.
- Adds personality where seriousness is required.
- Recreates official brand assets inaccurately.
- Introduces features through generated artwork.
- Makes quiet or unavailable states misleadingly reassuring.
- Uses visual drama to manufacture perceived product value.

The right voice should make the weather easier to understand.

It should not call attention to itself.

---

# 17. Brand Review Checklist

Before approving meaningful user-facing copy, artwork, or marketing material, ask:

1. Is the communication accurate?

2. Does it preserve the scope and uncertainty of the underlying information?

3. Is the most important message immediately understandable?

4. Does it sound like SkyAware rather than a generic weather application?

5. Is the tone appropriate to the actual weather situation?

6. Are canonical labels and terminology used consistently?

7. Could the wording imply broader safety or capability than supported?

8. Are official brand assets represented accurately?

9. Is the result clear, concise, and deliberately crafted?

10. Could anything be removed without
    losing useful meaning?

If a statement is technically accurate but likely to mislead, refine it.

If a visual is attractive but implies an unsupported capability, reject it.

If the communication requires more words than the surface can support, simplify the message without changing its meaning.

---

# Final Brand Principle

**SkyAware communicates complex weather information with calm confidence, precision, and restraint.**

It should feel knowledgeable without being intimidating.

Reassuring without making promises it cannot keep.

Distinctive without becoming decorative.

Premium without calling itself premium.

And always focused on helping people understand when the weather deserves their attention.
