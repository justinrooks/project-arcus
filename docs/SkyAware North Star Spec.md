---
up: "[[SkyAware Branding and Design Guide]]"
related:
  - "[[SkyAware Branding and Design Guide]]"
created: 2026-04-02
tags:
  - skyaware
  - design
  - spec
  - llm
---
# SkyAware North Star Spec
This is the LLM-facing companion to [[SkyAware Branding and Design Guide]].

Use this note when generating:
- UI concepts, mockups, and screen content
- brand assets, app-store visuals, and marketing compositions
- user-facing product copy
- implementation prompts, project instructions, and agent guidance

The full guide is the deep reference. This note is the execution spec.

If this note conflicts with exploratory or historical language in the full guide, follow this note.
---
## Purpose
SkyAware is a severe-weather awareness product, not a generic weather app.

Its core job is to help the user answer one question:

> How weather-aware do I need to be right now?

SkyAware should feel like:
- a calm weather intelligence tool
- a trustworthy local severe-weather assistant
- a product that resolves complex atmospheric data into simple, actionable awareness

SkyAware should not feel like:
- a playful consumer weather toy
- a meteorology dashboard for experts only
- a flashing emergency app
- a generic weather data viewer
---
## Operating Rules
1. Choose calm, clear, useful, and trustworthy over dramatic or decorative.
2. Preserve semantic meaning. Do not casually reuse colors, icons, or labels that already mean something specific.
3. Prefer omission over clutter. If a detail is not helping the user understand what matters now, leave it out.
4. Use canonical labels and user-facing vocabulary from this note.
5. Do not expose internal jargon like provider names or `CIG` on primary user surfaces.
6. When guidance overlaps, the more specific section wins over the more general one.
7. `Locked` decisions in the full guide should be treated as fixed unless the product direction intentionally changes.
8. `Still tuning` areas are polish problems, not invitations to invent new semantics.
---
## Brand Traits
SkyAware should feel:
- calm
- clear
- precise
- elegant
- restrained
- useful
- local
- trustworthy
- quietly intelligent

SkyAware should avoid feeling:
- dramatic
- loud
- sensational
- gimmicky
- cute in serious contexts
- visually noisy
- jargon-heavy
---
## Voice and Tone
Use a voice that is:
- concise
- human
- direct
- informative
- grounded
- neutral but reassuring

Preferred qualities:
- reassuring without coddling
- weather-literate without unnecessary meteorology jargon
- structured without sounding formal
- useful at a glance

Avoid:
- cute copy
- novelty personality
- exaggerated urgency unless the situation truly warrants it
- developer or system language in user-facing copy
- generic technical status copy like `Loading`, `Fetching`, `Processing`, or `Finalizing data`
---
## Canonical Vocabulary
Use these labels consistently when generating UI or copy:

- Product category: `severe-weather awareness app` or `severe-weather awareness product`
- Top header section: `Current Conditions`
- Hero risk labels: `Storm Risk` and `Severe Risk`
- Secondary hazard rail: `Fire Risk`
- Secondary instrumentation rail: `Atmospheric Conditions`
- Alert section: `Local Alerts`
- Severe map/menu wording: `Severe Risk`, not `Categorical`
- User-facing intensity language: `Hatching` and `Stronger storms possible`

Internal vs user-facing terminology:
- Internal term: `conditional intensity` or `CIG`
- User-facing term: `hatching`, `stronger storms possible`, or plain-language explanation on tap
- Never expose `CIG1`, `CIG2`, or `CIG3` in primary UI

Status and resolving language should use present-progressive, user-centered phrasing:
- `Getting your conditions ready`
- `Bringing in your conditions`
- `Getting storm risk`
- `Bringing in local alerts`
- `Updating your conditions`
---
## Visual System
### Hierarchy
SkyAware is typography-led.

Hierarchy should come primarily from:
- type weight
- spacing
- contrast
- layout

Hierarchy should not rely on:
- icon overload
- heavy borders
- decorative badges
- loud color everywhere

### Surfaces and Shape
Use:
- soft, integrated surfaces
- continuous corners
- restrained shadows
- subtle material or glass influence when appropriate

Avoid:
- heavy borders
- harsh dividers
- thick outlines
- containers that feel modal unless they are true modals

### Typography
Typography should feel:
- stable
- readable
- calm
- Apple-native

General type rules:
- headings should be semibold, short, and not oversized
- labels should be subtle and secondary
- numeric values can use stronger emphasis and monospaced digits where useful
- supporting text should stay concise and light

### Color Semantics
Color is semantic, not decorative.

Rules:
- reserve risk colors for actual risk meaning
- do not reuse risk colors as general accent colors
- keep freshness neutral by default
- use amber or red subtly for degraded freshness when needed
- avoid green for freshness because green already competes with `all clear`

Storm risk color ladder:
- All Clear / Thunderstorm: green family
- Marginal: darker green
- Slight: yellow
- Enhanced: orange
- Moderate: red
- High: purple

Severe threat colors:
- Tornado: `tornadoRed`
- Hail: `hailBlue`
- Wind: `windTeal`
- All Clear: green

Additional semantic rules:
- fire risk uses its own ladder and should not visually collide with storm or severe risk
- mesoscale discussion color should be its own indigo-purple family, distinct from High risk purple
- atmospheric instrumentation should use a cool blue-gray / slate / teal-blue tint

### Iconography
Icons are secondary support, not the main event.

Rules:
- use icons sparingly and semantically
- prefer icons that reinforce meaning rather than repeat obvious text
- avoid reusing a strong category icon for a different nearby meaning
- keep text and layout above icons in the hierarchy unless the icon is the category anchor

### Motion
Motion should feel:
- calm
- atmospheric
- low-frequency
- subtle enough to be felt, not noticed

Use:
- soft glow
- gentle gradient drift
- blur-to-sharp resolving
- opacity lift
- crossfades

Avoid:
- strong spring motion
- bouncing
- spinner-first behavior
- flashy shimmer
---
## Product Surface Spec
### Summary Screen
The Summary screen is the hero screen and center of gravity for the product.

It should answer, within seconds:
- where am I
- what is it like right now
- how concerning is today
- what is active locally
- what should I pay attention to

Canonical content order:
1. Current Conditions
2. Storm Risk and Severe Risk hero tiles
3. Fire Risk rail
4. Atmospheric Conditions rail
5. Local Alerts
6. Convective Outlook summary

### Current Conditions Header
Rules:
- keep it compact, utility-like, and Apple-native
- location is primary
- temperature is primary on the trailing side
- condition icon is secondary
- keep spacing tight between the temperature and icon
- it should feel like a header, not a heavy card

Use:
- `Current Conditions`

Avoid:
- `Current Location`
- `Current Conditions for`

### Risk Snapshot Hero Tiles
Rules:
- keep Storm Risk and Severe Risk horizontally aligned
- keep them glanceable and semantically colored
- do not overload them with auxiliary metadata
- conditional intensity should appear as subtle hatch or texture, not as extra jargon or extra iconography

### Fire Risk Rail
Rules:
- keep it concise and rail-like
- place it beneath the hero tiles
- keep it visually distinct from severe-weather hero badges

### Atmospheric Conditions Rail
This is instrumentation, not alerting.

Rules:
- keep it secondary, compact, and typography-led
- use a cool atmospheric tint rather than risk colors
- make dew point the lead signal when appropriate
- allow subtle warm emphasis on dew point value only
- if a dew point explanation is shown, keep it plain-language and useful
- when only the dew point value is interactive, make only that value tappable

### Local Alerts
Rules:
- use `Local Alerts` as the section label
- warnings outrank watches, and watches outrank mesos
- keep the summary card concise
- show event type, expiration or end time, and only enough threat summary to orient the user
- do not dump full metadata into the summary card

### Watch Detail
Include:
- title and watch number
- valid, issued, and expires times
- hazard summary
- optional instruction text
- sender or office information
- status chips for severity, certainty, and urgency

Use text rows instead of chips for:
- sender
- instruction
- response

### Outlooks, Mesos, and Watches
Use one family of structure across these views:
- clean header
- key metadata
- summary first
- detail expandable or drill-in

Consistency matters more than making every product look identical.

### Map, Layer Selector, and Legend
Map rules:
- the map is the hero, not the controls
- controls should float lightly
- overlays should feel intentional and readable
- the user should understand the active map in under 2 seconds

Layer selector rules:
- show the current layer, a semantic icon, and a chevron
- make it read like a current-state control and menu trigger
- use `Severe Risk`, not `Categorical`

Legend rules:
- decode the map in under 2 seconds
- color means likelihood
- hatching means stronger intensity potential if storms occur
- keep hatching explanation inside the legend card
- show the hatching row only when intensity data exists for the active severe layer

### Conditional Intensity
Treat conditional intensity as a modifier, not a standalone hazard.

Rules:
- use color for likelihood
- use hatch or texture for stronger intensity potential
- connect map and badges through the same hatch language
- explain it with plain language on demand
- for multiple severe hazards, avoid trying to compress everything into one overloaded badge area

### Loading and Resolving
SkyAware should feel like it is resolving the local picture, not loading data.

Rules:
- show a dedicated full-screen resolving state only when there is no meaningful cached content
- once cached content exists, show it immediately and resolve forward in place
- keep resolving status in the header area, not as a floating overlay
- use blur and opacity subtly during refresh
- remove technical implementation language from user-facing status copy

Preferred first-load title:
- `Getting your conditions ready`

Preferred refresh message family:
- `Getting your location...`
- `Updating your conditions...`
- `Getting storm risk...`
- `Bringing in local alerts...`

### Notifications
Push notifications are interrupt copy. Every word must earn its place.

Field responsibilities:
- Title: what happened
- Subtitle: why the user got this alert
- Body: what is happening or why it matters

Tone inputs:
- severity
- urgency
- certainty

Subtitle examples:
- `Includes your location`
- `Updated for your area`
- `Cancelled for your area`
- `For your area`

Body examples:
- `Tornado possible. Seek shelter now.`
- `Damaging winds and large hail possible.`
- `Flash flooding expected. Avoid low areas.`
- `Critical fire weather conditions.`
---
## Asset Generation Rules
Use these rules when generating screenshots, marketing visuals, icons, illustrations, or visual directions.

### Brand and Marketing Assets
Aim for:
- calm atmosphere
- restrained confidence
- local awareness
- polished, Apple-native refinement
- subtle premium quality

Prefer:
- atmospheric skies
- layered weather textures
- soft gradients
- typography-led compositions
- generous negative space
- one clear focal point

Avoid:
- clipart weather icons as the main visual idea
- emergency siren aesthetics
- cartoon storm imagery
- novelty personalities
- generic startup gradients with no semantic meaning
- visual chaos

### UI Mockups and Screenshots
Aim for:
- immediate information hierarchy
- realistic semantic color usage
- soft integrated surfaces
- components that feel coherent with each other

Avoid:
- dashboard sprawl
- too many cards competing at once
- decorative widgets
- risk colors used as generic accent decoration
- excessive iconography

### Map and Data Visuals
Aim for:
- clarity in under 2 seconds
- stable, legible overlays
- hatching that reads as texture, not ink

Avoid:
- noisy or overly dense legend systems
- textures that overpower the base map
- dark-mode hatching that becomes muddy
---
## Content Generation Rules
When generating copy, prompts, or content derived from this brand:

- keep the user-facing language calm, short, helpful, and human
- prefer plain-language weather literacy over technical theater
- use present-progressive status language when the app is actively resolving
- keep explanations concise on primary surfaces and use progressive disclosure for advanced concepts
- avoid marketing-speak inside the product
- avoid turning serious weather information into personality-driven entertainment

If writing prompt instructions for another model or agent:
- say what the artifact is
- say which sections of this spec matter most
- tell the model to preserve semantic colors and canonical labels
- tell the model not to invent extra jargon, decorative UI, or new hazard semantics
---
## Open Tuning Areas
These are still tuning topics, not invitations to change the product model:
- dark-mode hatch contrast
- exact hatch color treatment
- final map texture polish
- exact provider-to-status-message wiring

If work touches these areas, preserve the current semantics and solve for polish rather than reinvention.
---
## Review Checklist
Before approving generated assets, content, or UI, ask:
1. Does this make SkyAware feel calmer or noisier?
2. Does this make the product feel more trustworthy or more dramatic?
3. Does this help the user understand what matters right now?
4. Are the labels, colors, and icons being used semantically rather than decoratively?
5. Does this feel like a severe-weather awareness product rather than a generic weather app?

If the answer is unclear, simplify.
