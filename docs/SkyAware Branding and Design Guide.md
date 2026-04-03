---
up: "[[Arcus Control Center]]"
related:
  - "[[SkyAware North Star Spec]]"
created: 2026-04-02
tags:
  - skyaware
  - design
---
# **Purpose**
This document is the canonical design and brand guide for SkyAware based on the design work, UX decisions, language choices, and interaction patterns developed in our collaboration.

For prompt-friendly, execution-focused guidance, use the companion spec [[SkyAware North Star Spec]].

It is intended to serve three purposes:
1. General reference for ongoing product and UI work
2. Input to Codex / implementation prompts / agent skills
3. Context anchor for future branding and design conversations to prevent drift
This guide is written to optimize for consistency, clarity, restraint, and direct product usefulness.
---
# **Guide Map**
## **Quick Start**
If you only need the non-negotiables, keep these in view:
1. SkyAware is a **severe-weather awareness app**, not a generic weather app.
2. Calm, clear, useful, and trustworthy beat flashy every time.
3. Typography and layout should carry the hierarchy; iconography should support it.
4. Risk colors are semantic and should not be casually reused.
5. Secondary context belongs in rails and subtle supporting layers, not in the hero area.
6. The Summary screen is the product’s center of gravity.
7. Cached-first, resolve-forward is the correct loading model.
8. Full-screen resolving state is only for true empty/no-cache startup.
9. Conditional intensity should be represented as texture, not jargon.
10. Every state transition should feel like the app is becoming more accurate, not reloading.

## **How to Read This Guide**
- Read Sections 1-8 when you are setting brand, hierarchy, color, typography, or icon rules.
- Read Sections 9-20 when you are designing the summary experience, alert surfaces, and map behavior.
- Read Sections 21-29 when you are implementing loading states, copy, motion, and interaction details.
- Read Sections 30-32 when you are reviewing work, checking for drift, or turning the guide into implementation prompts.

## **Decision Status**
- **Locked** means treat the guidance as canonical unless the product direction intentionally changes.
- **Preferred** means the direction is strong and should guide implementation, but some details can still evolve.
- **Still tuning** means the conceptual answer is set, but visual or interaction polish is still being refined.

## **Quick Navigation**
- **Part I. Foundations**
  - [[#1. Brand Core|1. Brand Core]]
  - [[#2. Product Positioning|2. Product Positioning]]
  - [[#3. Inspirations and Design Reference Points|3. Inspirations and Design Reference Points]]
  - [[#4. High-Level Visual Language|4. High-Level Visual Language]]
  - [[#5. Corner Radius and Shape System|5. Corner Radius and Shape System]]
  - [[#6. Typography System|6. Typography System]]
  - [[#7. Color System|7. Color System]]
  - [[#8. Iconography|8. Iconography]]
- **Part II. Core Product Experience**
  - [[#9. Summary Screen Philosophy|9. Summary Screen Philosophy]]
  - [[#10. Current Conditions Header|10. Current Conditions Header]]
  - [[#11. Risk Snapshot Hero Tiles|11. Risk Snapshot Hero Tiles]]
  - [[#12. Fire Risk Rail|12. Fire Risk Rail]]
  - [[#13. Atmospheric Conditions Rail|13. Atmospheric Conditions Rail]]
  - [[#14. Local Alerts Section|14. Local Alerts Section]]
  - [[#15. Watch Detail View|15. Watch Detail View]]
  - [[#16. Outlooks, Mesos, and Watches Layout Strategy|16. Outlooks, Mesos, and Watches Layout Strategy]]
  - [[#17. Map Design Philosophy|17. Map Design Philosophy]]
  - [[#18. Map Legend|18. Map Legend]]
  - [[#19. Conditional Intensity (CIG) Design System|19. Conditional Intensity (CIG) Design System]]
  - [[#20. Hatching Visual Direction|20. Hatching Visual Direction]]
- **Part III. States, Copy, and Interaction**
  - [[#21. Loading / Resolving Experience|21. Loading / Resolving Experience]]
  - [[#22. Cached-First, Resolve-Forward Summary Behavior|22. Cached-First, Resolve-Forward Summary Behavior]]
  - [[#23. Notification Copy Philosophy|23. Notification Copy Philosophy]]
  - [[#24. Copy Style Rules Across the Product|24. Copy Style Rules Across the Product]]
  - [[#25. Motion and Transition Rules|25. Motion and Transition Rules]]
  - [[#26. Control Styling and Microinteractions|26. Control Styling and Microinteractions]]
  - [[#27. Design Patterns to Reuse|27. Design Patterns to Reuse]]
  - [[#28. Anti-Patterns to Avoid|28. Anti-Patterns to Avoid]]
  - [[#29. Canonical Messaging Themes|29. Canonical Messaging Themes]]
- **Part IV. Reference and Review**
  - [[#30. Summary of the Most Important Brand/Design Decisions|30. Summary of the Most Important Brand/Design Decisions]]
  - [[#31. Review Notes / Consistency Check|31. Review Notes / Consistency Check]]
  - [[#32. Recommended Use of This Document|32. Recommended Use of This Document]]
---
# **Part I. Foundations**
These sections define the brand, visual language, and semantic rules the rest of the product should inherit.
---
# **1. Brand Core**
> [!success] **Status:** Locked. Treat this section as the baseline identity and voice for the product.

## **Product identity**
SkyAware is **not** a generic weather app.

It is a **severe-weather awareness product** focused on helping the user answer:

> How weather-aware do I need to be right now?

The product should feel like:
- a calm weather intelligence tool
- a trustworthy local severe-weather assistant
- a product that resolves complex atmospheric data into simple, actionable awareness
It should **not** feel like:
- a playful consumer weather toy
- a meteorology dashboard for experts only
- a flashing emergency app
- a generic “weather data viewer”
## **Brand traits**
SkyAware should consistently feel:
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
- playful in serious contexts
- overloaded with technical jargon
- visually noisy
## **Voice and tone**
The product voice should be:
- concise
- human
- direct
- informative
- grounded
- neutral but reassuring
Preferred qualities:
- reassuring without coddling
- informative without sounding robotic
- weather-literate without exposing meteorology jargon unnecessarily
- structured without sounding formal
Avoid:
- cute writing
- exaggerated urgency unless truly warranted
- marketing-speak in-product
- developer/system language in user-facing surfaces
- “Loading…”, “Fetching…”, “Resolving context…”, etc.
---
# **2. Product Positioning**
## **Core user promise**
SkyAware translates multiple severe-weather data sources into a fast, glanceable understanding of current risk and evolving conditions.

The app’s role is not simply to show weather. It is to:
- synthesize severe risk
- localize that risk
- highlight the most important threats
- communicate what matters most right now
## **Experience goal**
The user should be able to open the app and understand, within seconds:
- where they are
- what the current conditions are
- how concerning today’s setup is
- whether there are active local alerts
- whether there are heightened atmospheric ingredients worth noticing
The app should feel like it is **resolving reality**, not just loading data.
---
# **3. Inspirations and Design Reference Points**
SkyAware’s strongest design inspirations are:
- Dark Sky
- Apple Weather
- Tide Guide
- Lumy
- selectively, CARROT Weather’s clarity (not its personality)
## **What to borrow from the inspiration apps**
### **Dark Sky**
- calm confidence
- at-a-glance utility
- immediate information hierarchy
- minimal friction
### **Apple Weather**
- polish
- continuity
- material softness
- typography-led structure
- elegant transitions
### **Tide Guide**
- tasteful minimalism
- beautiful density
- subtle premium feel
- precise information layout
### **Lumy**
- atmospheric presentation
- elegant motion restraint
- high visual refinement without clutter
### **CARROT Weather (selectively)**
- clarity of information hierarchy
- strong summary framing
Do not borrow:
- jokes
- novelty
- visual chaos
- loud personality
---
# **4. High-Level Visual Language**
## **Overall style**
SkyAware should feel:
- calm and cozy
- minimalist with optional depth
- typography-led
- Apple-native
- atmospheric but not flashy
The app should be visually clean enough for general users while still carrying enough detail and polish for weather-aware users and enthusiasts.
## **Primary visual principles**
1. Information first
2. Color with purpose
3. Texture before ornament
4. Smooth continuity over hard state changes
5. Calm surfaces over loud cards
6. Subtle emphasis over dramatic alerts
## **Surfaces**
Surfaces should feel soft, slightly elevated, and integrated.

Use:
- continuous corner radii
- subtle glass/material influences where appropriate
- restrained shadows
- soft overlays
Avoid:
- heavy borders
- harsh dividers
- thick outlines
- modal-looking containers unless a true modal is intended
---
# **5. Corner Radius and Shape System**
## **Shape philosophy**
Corner radius must follow Apple’s modern rounded system and respect device concentricity.

SkyAware standardized around:
- continuous corner style
- a shared radius system (SkyAwareRadius)
- an app-wide fallback of approximately **30 pt** for iOS 18 compatibility
This decision should remain consistent across:
- hero cards
- rails
- buttons
- picker surfaces
- chips
- map controls
- legend panels
## **Rules**
- Use continuous corners everywhere practical
- Avoid mixing unrelated corner styles
- Do not introduce sharper radii for one-off components
- Components that live together should share radius language
---
# **6. Typography System**
## **Typography philosophy**
Typography is a primary carrier of hierarchy in SkyAware.

The app should rely more on:
- type weight
- spacing
- contrast
- layout
and less on:
- icons
- borders
- badges with too much decoration
## **General usage**
### **Headings**
- semibold
- clean and short
- not oversized
### **Labels / section headers**
- subtle
- secondary emphasis
- often uppercase or small utility style when appropriate
- should feel Apple-native, not custom-for-the-sake-of-custom
### **Values**
- slightly stronger than labels
- monospaced digits where numerics matter
- prominent without shouting
### **Supporting text**
- secondary color
- concise
- never dense if shown in summary contexts
## **Style direction**
Text should feel:
- stable
- readable
- calm
- not flashy
Avoid:
- excessive boldness
- oversized headings on small components
- stacked emphasis everywhere
---
# **7. Color System**
## **Color philosophy**
Color is semantic in SkyAware.

It should communicate:
- risk
- hazard type
- current status
- atmospheric support
Color should **not** be decorative noise.
## **Key semantic rule**
Risk colors must remain reserved for actual risk meaning.

Do not reuse risk colors casually in unrelated UI contexts.

Example:
- green = all clear / safe / baseline low risk
- do not also use that green as a generic positive UI accent everywhere
## **Storm risk colors**
Storm risk colors were aligned to SPC-inspired semantics and standardized with consistent gradient logic:
- All Clear / Thunderstorm: green family
- Marginal: darker green
- Slight: yellow
- Enhanced: orange
- Moderate: red
- High: purple
Gradients are built consistently from base color to a darkened companion color.
## **Severe threat colors**
Severe threat badges use custom colors:
- Tornado: tornadoRed
- Hail: hailBlue
- Wind: windTeal
- All Clear: green
These are applied consistently in both light and dark mode with gradient logic.
## **Fire risk**
Fire risk uses its own semantic ladder and should not visually conflict with storm/severe risk.
## **Mesoscale color**
Mesoscale discussion color should be a distinct purple family, separate from High storm risk purple.

A better indigo/purple distinction was preferred over reusing the same purple semantics.
## **Atmospheric conditions rail color**
Atmospheric data is **instrumentation**, not risk.

It should use a **cool blue-gray / slate / teal-blue atmospheric tint**, not fire or risk colors.

This rail must read as:
- telemetry
- context
- support signal
not:
- alert status
- danger state
## **Freshness colors**
Freshness is system state, not safety state.

Preferred logic:
- healthy / normal freshness should generally be neutral
- stale or degraded freshness may use amber/red subtly
- avoid using green for freshness because green competes semantically with “all clear”
---
# **8. Iconography**
## **General philosophy**
Use iconography sparingly and semantically.

Icons should:
- reinforce meaning
- not repeat what text already says unless helpful
- not dominate typography
## **Current direction**
### **Local alerts**
- overall section icon originally used exclamationmark.triangle
- watches and mesos were given distinct identities
- mesos settled toward waveform-based symbols, especially waveform.path.ecg.magnifyingglass in some contexts
### **Map layer selector**
- slider.horizontal.3 was rejected because it feels like settings
- better choices were layered icons such as `square.2.layers.3d.top.filled` and `square.3.layers.3d.middle.filled`
- final selector also included a chevron to communicate that the control opens a picker
### **Severe / fire risk icon conflict**
- flame.fill conflicted between High storm risk and fire risk
- High storm risk moved to bolt.trianglebadge.exclamationmark.fill
- Fire risk retains flame semantics
## **Rules**
- Prefer semantic icons over decorative icons
- If an icon already strongly communicates a category elsewhere, avoid reusing it for a different meaning nearby
- Treat icons as tertiary hierarchy after text and layout unless the icon is the category anchor
---
# **Part II. Core Product Experience**
These sections define the summary surface, supporting rails, alert presentation, and map behavior that make SkyAware feel coherent.
---
# **9. Summary Screen Philosophy**
## **Role of the summary screen**
The Summary screen is the **hero screen**.

It is the landing page and the main “what do I need to know?” surface.

The intended content stack is:
1. Current Conditions / Location
2. Storm Risk + Severe Risk hero tiles
3. Fire Risk rail
4. Atmospheric Conditions rail
5. Local Alerts (watches / mesos)
6. Convective Outlook summary
This is the primary interaction page and the highest-leverage surface in the app.
## **Design intent**
The Summary screen must answer:
- where am I?
- what’s it like right now?
- how concerning is today?
- what is active locally?
- what should I be paying attention to?
It should feel:
- immediate
- calm
- intelligent
- layered
---
# **10. Current Conditions Header**
## **What it became**
The original top section showed location plus a freshness timestamp. That evolved.

The final direction:
- header renamed from “Current Location” to **“Current Conditions”**
- left side = location
- right side = current temperature + condition icon
This was a major improvement because it changed the section from metadata into useful context.
## **Why this works**
It answers:
- Where am I?
- What’s it like right now?
without mixing in system timestamps or product issuance times.
## **Rules**
- Keep this section compact, utility-like, and Apple-native
- Location is primary
- Temperature is primary on the trailing side
- Condition icon is secondary
- Tight spacing between temperature and icon
- The overall section should feel like a header, not a heavy content card
## **Copy / labels**
Preferred section title:
- **Current Conditions**
Avoid:
- Current Conditions for
- Current Location (once weather is included)
---
# **11. Risk Snapshot Hero Tiles**
## **Philosophy**
Storm Risk and Severe Risk tiles are the app’s primary severe-weather summary signal.

They should remain:
- horizontally aligned
- glanceable
- semantically colored
- elegant but never flashy
## **Tile language**
These tiles represent the most important severe-weather categories and should not become overloaded with auxiliary metadata.
## **Conditional intensity integration**
Rather than adding text labels for CIG or new icons, the chosen direction is:
- add **subtle texture / hatch** to the badge / tile when conditional intensity applies to the user’s current location
This keeps the visual language consistent with the map.
---
# **12. Fire Risk Rail**
## **Role**
The Fire Risk rail is a distinct contextual hazard rail beneath the hero badges.

It is subordinate to storm/severe hero tiles but still important.
## **Design intent**
- concise
- rail-like
- integrated with the summary hierarchy
- clearly distinct from severe weather badges
---
# **13. Atmospheric Conditions Rail**
## **Role**
This rail exists to surface supportive atmospheric ingredients relevant to severe weather.

It is not a weather dashboard. It is a contextual support layer.

The first key metric was **dew point**, followed by:
- humidity
- wind
- pressure
## **Position**
This rail sits below Fire Risk.
## **Why it exists**
Dew point and similar metrics are important severe-weather ingredients, but they are not headline risk. They belong in a secondary contextual layer.
## **Design principles**
- quiet utility
- compact values
- secondary, not dominant
- no semantic alert colors except a subtle emphasis where meaningful
## **Visual design**
- background uses blue-gray atmospheric tint
- typography-led
- compact metrics laid out in a clean rail/grid
- iconography is subdued
- dew point value receives a subtle warm/orange emphasis because it is the most meteorologically meaningful ingredient for this context
## **Dew point handling**
A dew point detail popup was designed to:
- explain what dew point means in plain language
- explain that higher dew points increase the potential for stronger storms
- include a dynamic hint tied to current value
The popup copy should remain:
- plain-language
- calm
- useful
- non-technical unless necessary
## **Dew point visual behavior**
- only the dew point **value** is tappable for the info popup, not the whole tile
- the popup content must fully wrap and scroll rather than truncating
---
# **14. Local Alerts Section**
## **Role**
This section surfaces alerts that matter to the current location.

Specifically:
- warnings (future consideration / priority above watches)
- watches
- mesoscale discussions
## **Hierarchy**
Local alert severity hierarchy should be:
1. Warning
2. Watch
3. Meso
Watches should appear above mesos because they represent a stronger direct concern.
## **Design direction**
- left-aligned headers preferred over centered
- concise, glanceable alert cards
- watches and mesos can share reusable structural components, but should retain distinct semantics
## **Watch summary guidance**
At summary level, show:
- event type (e.g. Tornado Watch)
- expiration / end time
- enough threat summary to convey meaning quickly
Do not dump full metadata into the summary card.
---
# **15. Watch Detail View**
## **Design philosophy**
Watch detail should be more structured than the initial implementation.

It should include:
- title / watch number
- valid / issued / expires
- hazard summary
- optional instruction text
- sender / office information
- status chips for severity / certainty / urgency
## **Status chips**
Status chips were preferred for compact metadata like:
- severity
- certainty
- urgency
But not for:
- sender
- instruction
- response
Those longer items should be displayed as textual rows/sections instead.
## **Instruction text**
Instruction text should appear in both:
- card view (if helpful and concise)
- full detail view
It should be readable, secondary, and not overloaded with decoration.
---
# **16. Outlooks, Mesos, and Watches Layout Strategy**
## **Standardization direction**
Among the views reviewed, the **meso sheet** was liked the most and became the structural influence for other products.

The desired pattern is:
- clean header
- key metadata
- summary first
- detail expandable / drill-in
The goal is consistency across:
- Convective Outlook
- Mesoscale Discussion
- Weather Watch
without forcing them into identical content.
---
# **17. Map Design Philosophy**
> [!tip] **Status:** Preferred. The interaction model is settled; detail polish should support this structure rather than reinvent it.

## **Role**
The map should feel like a serious product surface, not an engineering tool.

It must remain readable under multiple overlays and layers.
## **General principles**
- map is the hero, not the controls
- controls should float lightly
- overlays should feel intentional and layered
- the user should understand the map in under 2 seconds
## **Map layer selector**
A combined control showing:
- current selected layer
- layer icon
- chevron
was preferred over separate label + slider button.

It should read as:
- current layer state
- tappable control
- Apple-native menu trigger
### **Preferred selector structure**
- left: icon + selected layer title
- right: chevron
- use existing surface style
- subtle pressed feedback
### **Recommended wording**
- “Severe Risk” instead of “Categorical”
This is more human and aligns with app language.
---
# **18. Map Legend**
## **Role**
Legend must decode the map in under 2 seconds.

It should communicate:
- probability via color
- intensity via texture/hatching
## **Placement**
Current floating legend panel location is correct.

Rather than adding a separate hatching UI, the chosen direction was:
- keep hatching explanation **inside the existing legend card**
## **Structure**
For severe layers, legend card should include:
1. layer title (e.g. Tornado Risk)
2. probability rows
3. divider
4. hatch swatch + explanation
## **Hatching explanation copy**
Preferred:
- “Hatching”
- “Stronger storms possible”
No raw CIG labels in legend.
## **Hatch swatch**
The swatch must match the map’s hatch feel:
- same angle
- same spacing
- same overall visual language
Legend swatch should be slightly softer than the map itself.
## **Conditional visibility**
The hatching legend row should appear only when intensity data exists for the current severe layer.
---
# **19. Conditional Intensity (CIG) Design System**
## **Conceptual model**
CIG / conditional intensity is treated as:
- a **modifier**, not a standalone hazard
Map semantics:
- color = likelihood
- hatch / texture = stronger intensity potential if storms occur
## **User-facing language**
Do not expose:
- CIG1 / CIG2 / CIG3 in primary UI
Instead use:
- hatch texture on map
- hatch texture in badge when applicable
- plain-language popovers on tap
## **Badge integration**
Rather than adding text or icons, the preferred design is:
- subtle hatch/texture overlay inside the risk badge when the user is inside a conditional intensity area for the active hazard
This visually connects badge and map.
## **Multiple hazards**
Because severe outlooks often include wind, hail, and tornado simultaneously, a **horizontal swipe rotator** was preferred for severe threat cards, similar in spirit to iOS rotating widgets.

This prevents trying to compress all hazard-specific details into a single overloaded badge area.

Default order currently considered:
- wind → hail → tornado
---
# **20. Hatching Visual Direction**
> [!warning] **Status:** Still tuning. The renderer strategy is right; contrast, dark-mode treatment, and final texture polish remain active refinement areas.

## **Desired feel**
Hatching should be:
- texture, not ink
- subtle but visible
- meteorological, not decorative
- consistent at all zoom levels
## **Key decision**
Hatching should **not visually scale with zoom**.

It should behave like a stable screen-space texture rather than geometry that expands/contracts dramatically while zooming.
## **Dark mode concerns**
Dark mode map + dark hatch risks muddiness.

This remained an active tuning topic. The working philosophy was:
- keep geometry constant
- tune stroke color / luminance separately for dark mode
## **Current direction**
The strongest design conclusion from the hatching work was:
- renderer architecture is correct
- remaining work is primarily visual tuning (contrast / color / dark mode)
---
# **Part III. States, Copy, and Interaction**
These sections cover resolving behavior, language, motion, and the interaction details that keep the app calm and legible.
---
# **21. Loading / Resolving Experience**
> [!success] **Status:** Locked. The app should feel like it is resolving the local picture, not loading data.

## **Philosophy**
SkyAware should not feel like it is “loading data.”

It should feel like it is:
- getting the user’s weather ready
- resolving the current local picture
- becoming more accurate over time
## **First-load full-screen state**
The initial launch state with no meaningful cached data should be a dedicated full-screen resolving presentation.
### **Title chosen**
- **Getting your conditions ready**
This was preferred because it:
- feels like a beginning, not a completion
- does not sound technical
- combines the ideas of “getting” and “preparing” without sounding final
## **Initial resolving screen design direction**
The screen should be:
- calm
- integrated
- not card/modal based
- atmospheric
- minimal
Preferred structure:
- icon with soft ambient glow
- short title
- short status line
- faint suggestion of summary structure underneath
- subtle nav dimming during the state
## **Strong decisions**
- large card container removed
- spinner de-emphasized or replaced with atmospheric motion
- no technical implementation detail like “Apple Weather” attribution on this screen
- faint ghosted/blurred summary beneath was liked and aligned with the direction
## **Animation direction**
- soft glow
- ultra-subtle pulse
- no flashy loading indicators
- summary should feel like it is resolving into focus
## **Important state distinction**
This first screen should only appear when there is **no meaningful content yet**.

After cached content exists, the app should not go back to a blocking full-screen loading experience.
---
# **22. Cached-First, Resolve-Forward Summary Behavior**
> [!success] **Status:** Locked. This is the canonical loading model once meaningful cached content exists.

## **Core model**
If cached data exists:
- show summary immediately
- resolve forward in place as fresh data arrives
Do not hide the summary with a full-screen loading screen once meaningful cached data exists.
## **Sections that participate in resolving treatment**
The following summary sections should participate in blur/opacity resolving:
- Current Conditions & Location
- Storm Risk
- Severe Risk
- Fire Risk rail
- Atmospheric Conditions
- Local Watches
- Convective Outlook
## **Visual treatment**
Cached-but-refreshing:
- blur: 2–3 pt max
- opacity: ~0.82–0.90
- preserve layout
- no per-section spinners
Fresh:
- blur resolves to 0
- opacity to 1.0
- crossfade in place
## **Resolving status placement**
When cached content is visible, status should live in the **header area** as a subtle secondary line, not as a floating overlay.
## **Status message system**
Messages should be:
- state-driven
- tied to actual provider / data source activity
- optionally rotated only among active tasks
- calm and concise
### **Preferred messages refined during conversation**
For initial / staging states:
- Finding your location…
- Getting your area ready…
- Bringing in your conditions…
- Ready
- Location not available
For in-summary refresh states:
- Getting your location…
- Updating your conditions…
- Getting storm risk…
- Bringing in local alerts…
- Getting everything ready…
These replaced more technical originals like:
- Resolving local weather context…
- Loading local weather details…
- Analyzing storm risk…
- Refreshing local alerts…
- Finalizing data…
## **Cause → effect relationship**
A key UX decision:
- the resolving message should correspond to what just resolved
- when a section sharpens/updates, the matching status text should have been shown immediately before or during that change
This creates a subtle cause → effect sense of progress.
---
# **23. Notification Copy Philosophy**
## **Overall approach**
Notification copy should be:
- brief
- descriptive
- useful at a glance
- hazard-first
- location/coverage aware
- lifecycle aware
Push notifications are **interrupt copy**, so every word must earn its place.
## **Field semantics**
### **Title**
- what happened
- event-first
- usually just the alert event name
- may include Cancelled / Expired when appropriate
### **Subtitle**
- why the user got the alert
- conveys coverage / relationship to user
### **Body**
- what is happening / why it matters
- short, hazard-specific, tone-aware
## **Tone model**
Notification tone should be derived from NWS metadata:
- severity
- urgency
- certainty
Internal tone levels defined:
- CRITICAL
- HIGH
- ELEVATED
- INFORMATIONAL
These are not shown to the user. They shape body wording.
## **Subtitle philosophy**
Subtitle answers:
- why the user got the alert
Preferred subtitle examples:
- Includes your location
- Now includes your location
- Updated for your area
- No longer affecting your area
- Cancelled for your area
- For Weld County
- For your area
## **Hazard body dictionary philosophy**
Bodies should be:
- hazard-specific
- short
- tone-aware
- lifecycle-aware (new / updated / cancelled / expired)
Examples:
- Tornado possible. Seek shelter now.
- Damaging winds and large hail possible.
- Flash flooding expected. Avoid low areas.
- Critical fire weather conditions.
## **Title / subtitle / body responsibilities locked in**
- Title = event name + optional cancellation/expiration suffix
- Subtitle = why user got this alert
- Body = hazard summary shaped by tone and lifecycle
---
# **24. Copy Style Rules Across the Product**
## **General user-facing language rules**
Preferred language qualities:
- calm
- short
- helpful
- human
- clear
- non-technical
Avoid words/phrases like:
- loading
- fetching
- resolving context
- processing
- finalizing data
- internal provider names
## **Ellipsis**
Prefer the true ellipsis character:
- …
instead of three periods:
- ...
This was explicitly noted as a quality detail.
---
# **25. Motion and Transition Rules**
## **Overall motion philosophy**
Motion should feel:
- calm
- atmospheric
- low-frequency
- material-driven
- subtle enough to be felt, not noticed
## **Recommended motion types**
- soft glow pulse
- gentle gradient drift
- blur-to-sharp resolution
- opacity lift
- crossfade on messaging
Avoid:
- strong spring motion
- bouncing
- obvious spinner-led loading
- flashy shimmer outside of carefully chosen contexts
## **Timing guidance captured**
- blur resolve: ~0.45s easeOut
- opacity settle: ~0.35s easeOut
- status text crossfade: ~0.25–0.35s
- atmospheric glow / gradient drift: ~8–12s loop or ~3s pulse depending on element
---
# **26. Control Styling and Microinteractions**
## **Map selector**
Should have:
- semantic icon
- selected layer title
- chevron
- calm surface
- subtle pressed feedback
## **Key / legend interaction**
Map legend should not become a separate floating ecosystem. Keep it lightweight and integrated.
## **Buttons and tappable values**
When a single value is meant to be interactive (e.g. dew point), prefer making only that value the tap target rather than the whole tile.

This keeps the UI precise and prevents accidental affordance sprawl.
---
# **27. Design Patterns to Reuse**
These patterns are strong and should be reused thoughtfully:
- compact utility header with location + real-world context
- hero tiles with clear semantic color and minimal text
- rail components for secondary context (fire risk, atmospheric conditions)
- subtle texture overlays as semantic modifiers
- inline resolving status instead of overlay banners
- state-driven copy instead of generic loading language
- progressive disclosure via popover for advanced concepts
---
# **28. Anti-Patterns to Avoid**
Avoid introducing anything that makes SkyAware feel like:
- a dashboard full of widgets
- a novelty weather app
- a warning siren UI
- a settings-heavy technical tool
- a spinner-first experience
Specifically avoid:
- extra icons when texture or type can do the job
- hard cuts between loading and content
- generic “Loading…” copy
- raw jargon like CIG in primary surfaces
- dramatic color reuse across unrelated semantic layers
- cluttering the summary with every metric available
---
# **29. Canonical Messaging Themes**
Across the app, the preferred messaging themes are:
- getting your weather / conditions ready
- bringing in your conditions
- getting storm risk
- bringing in local alerts
- updating your conditions
The common thread is:
- present progressive movement
- user-centered phrasing
- no technical leakage
---
# **Part IV. Reference and Review**
Use this part for fast alignment, review passes, and turning the guidance above into implementation guardrails.
---
# **30. Summary of the Most Important Brand/Design Decisions**
If only a small set of principles is remembered, use these:
1. SkyAware is a **severe-weather awareness app**, not a generic weather app.
2. Calm, clear, useful, and trustworthy beat flashy every time.
3. Typography and layout should carry the hierarchy; iconography should support it.
4. Risk colors are semantic and should not be casually reused.
5. Secondary context belongs in rails and subtle supporting layers, not in the hero area.
6. The Summary screen is the product’s center of gravity.
7. Cached-first, resolve-forward is the correct loading model.
8. Full-screen resolving state is only for true empty/no-cache startup.
9. Conditional intensity should be represented as texture, not jargon.
10. Every state transition should feel like the app is becoming more accurate, not reloading.
---
# **31. Review Notes / Consistency Check**
## **Resolved tensions**
This guide resolves and standardizes several tensions that came up during exploration:
- **Preparing** vs **Getting**: final preference leans toward “Getting … ready” language when the state is transitional and not complete.
- **Timestamp in header** vs **weather context**: final preference is weather context in the top header; freshness belongs elsewhere or only when needed.
- **CIG labels** vs **texture**: final preference is texture in primary UI, plain-language explanation in secondary/detail UI.
- **Loading screen** vs **resolving experience**: final preference is cached-first progressive resolution, with full-screen resolving only when truly empty.
- **Legend placement**: final preference is to keep hatching explanation inside the existing legend card.

## **Still tuning**
No major unresolved contradictions remain in the guidance itself. Remaining open areas are mostly implementation and tuning concerns, especially around:
- dark mode hatch contrast
- exact hatching color treatment
- final map texture polish
- exact provider-to-status-message hook logic
---
# **32. Recommended Use of This Document**
## **Use this guide for**
- the reference doc for all future branding/design discussions
- the basis for Codex skills or design prompts
- the canonical alignment source when creating new UI
- the review standard for detecting drift

## **Review questions**
1. Does this make SkyAware feel calmer or noisier?
2. Does this make the app feel more trustworthy or more dramatic?
3. Does this help the user understand what matters right now?
4. Does this fit the existing voice and visual hierarchy?
If the answer is unclear, the design likely needs simplification.
