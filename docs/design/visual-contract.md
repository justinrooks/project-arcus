# SkyAware Apple-Native UI Redesign  
## Visual Implementation Contract

**Status:** Implementation contract  
**Applies to:** SkyAware iOS app and WidgetKit surfaces included in the redesign epic  
**Reference location:** `docs/design/redesign-2026/`

## 1. Purpose

This document defines the implementation rules for the SkyAware UI redesign.

The redesign should make SkyAware feel simpler, calmer, more premium, and more deeply native to Apple platforms while preserving its identity as a severe-weather awareness product.

The goal is not to imitate an Apple app visually. The goal is to build SkyAware the way Apple might build this product:

- native SwiftUI structure and behavior;
- strong typography and spacing before decorative chrome;
- clear information hierarchy;
- restrained use of materials;
- semantic weather color;
- predictable navigation and controls;
- excellent light and dark appearances;
- accessibility as part of the layout rather than an accommodation afterward.

The redesign is primarily a **presentation and UI simplification effort**. Existing domain logic, refresh behavior, accepted-state semantics, caching behavior, alert interpretation, persistence, and data ownership should remain unchanged unless an implementation story explicitly requires otherwise.

---

# 2. Product Character

SkyAware is a severe-weather awareness assistant, not a generic weather dashboard.

Every redesigned surface should feel:

- calm;
- precise;
- trustworthy;
- premium;
- focused;
- native;
- information-first.

The interface should answer:

> **How weather-aware do I need to be right now?**

Weather information should carry the visual hierarchy. Containers, decoration, animation, and material effects should support that hierarchy rather than compete with it.

Avoid:

- dashboard-widget density;
- excessive borders;
- stacked card-on-card chrome;
- decorative gradients without semantic meaning;
- excessive icons;
- siren-like emergency styling;
- generic use of hazard colors;
- glass applied simply because the API exists.

---

# 3. Implementation Priority

When implementation choices conflict, use this priority:

1. **Correct weather meaning and existing domain behavior**
2. **Accessibility and native platform behavior**
3. **This Visual Implementation Contract**
4. **SkyAware Branding and North Star specifications**
5. **Target reference screenshots**
6. **Incidental details visible in generated mockups**

Reference screenshots communicate direction, hierarchy, proportion, density, and character. They are not pixel-perfect specifications.

Do not reproduce an image artifact when doing so would conflict with native SwiftUI behavior, accessibility, SkyAware semantics, or this contract.

---

# 4. Native SwiftUI First

Use native SwiftUI structure and behavior wherever it can express the intended interaction cleanly.

Prefer native components such as:

- `Button`
- `NavigationLink`
- `NavigationStack`
- `TabView`
- `Menu`
- `Picker`
- `List`
- `Form`
- `Section`
- `LabeledContent`
- native sheets and popovers
- native toolbar and navigation APIs
- `sensoryFeedback`
- system materials
- SF Symbols

Do not preserve custom UI infrastructure merely because it already exists.

When native SwiftUI can replace custom presentation code while preserving SkyAware behavior, prefer deletion and simplification over rebuilding the same abstraction in a different form.

Examples:

- gesture pretending to be a button → `Button`
- custom navigation row → `NavigationLink`
- custom single-selection sheet → `Menu` or `Picker` when appropriate
- manual feedback generator → `sensoryFeedback`
- hand-built platform chrome → native navigation or toolbar behavior

However:

> **Native does not mean generic.**

Weather-specific presentation remains intentionally custom where the custom presentation communicates real domain meaning.

Storm Risk, Severe Risk, alert awareness, atmospheric context, SPC intensity, hatching, map overlays, and similar concepts should not be flattened into generic system rows simply to reduce custom code.

---

# 5. Surface Hierarchy

SkyAware uses three broad visual layers.

## Level 0 - App Canvas

The base screen or map.

Characteristics:

- quiet;
- atmospheric;
- visually recessive;
- minimal decorative chrome;
- light and dark adaptive.

The canvas should provide context without competing with weather information.

---

## Level 1 - Weather Content

Examples:

- active warning hero;
- Storm Risk;
- Severe Risk;
- Fire Risk;
- Atmospheric Conditions;
- local alert content;
- Outlook summaries;
- Storm Setup;
- widget content.

Characteristics:

- stable;
- highly legible;
- mostly opaque or restrained material;
- semantic weather color used intentionally;
- continuous corners;
- subtle separation from the canvas;
- typography carries hierarchy more than borders or shadows.

Weather content should not depend on translucency for legibility.

These surfaces are **not Liquid Glass by default**.

---

## Level 2 - Controls and Navigation

Examples:

- tab bar;
- navigation chrome;
- map layer controls;
- current-location control;
- floating map controls;
- menus;
- toolbar actions;
- transient interactive controls.

These are the primary candidates for native Liquid Glass on supported systems.

They should visually float above weather content because they control the content rather than represent it.

---

# 6. Liquid Glass Policy

SkyAware follows one simple rule:

> **Liquid Glass identifies controls floating above weather content. It is not the weather content itself.**

Use native Liquid Glass where supported for:

- navigation;
- tab and toolbar chrome;
- floating map controls;
- appropriate menus and interactive controls;
- intentionally floating actions.

Do not use Liquid Glass by default for:

- warning heroes;
- Storm Risk;
- Severe Risk;
- Fire Risk;
- Atmospheric Conditions;
- static metadata;
- long-form reading surfaces;
- ordinary content cards;
- widgets solely for visual decoration.

Do not create a SkyAware-specific imitation of Liquid Glass.

Prefer Apple's native implementation and allow the platform to evolve it.

Custom uses of `glassEffect` or `GlassEffectContainer` must be intentional and justified by interaction hierarchy.

Glass should be **opt-in**, not the default treatment for reusable content surfaces.

Do not create a large glass abstraction or theme framework.

---

# 7. Information Hierarchy

The screen should communicate importance before detail.

For Today, use this conceptual hierarchy:

1. **Current Conditions**
2. **Most important awareness information right now**
3. **Supporting severe-weather context**
4. **Atmospheric context**
5. **Secondary awareness information**

When a meaningful active warning affects the user, the warning may own the primary awareness position.

When no active warning requires that position, forecast risk information becomes primary.

Supporting information must visually remain supporting information.

The redesign should never produce several equally dominant "hero" surfaces competing for attention.

---

# 8. Active Warning Presentation

An active warning hero should be the strongest weather-content surface when the warning is the user's most actionable awareness information.

It should communicate:

- event type;
- valid-until time;
- primary threat summary;
- concise actionable guidance when appropriate.

Action language must come from established SkyAware/NWS semantics and available alert information.

Do not infer generic emergency wording from event type alone.

Avoid phrases such as `Take cover` unless the actual alert guidance and threat warrant that instruction.

Changes in urgency should primarily affect:

- semantic color;
- icon;
- text;
- threat information.

They should not cause the entire interface to switch into a dramatically different visual language.

A Tornado Warning should be clearly more urgent without turning SkyAware into a flashing emergency interface.

---

# 9. Semantic Color

Color communicates weather meaning.

Risk and hazard colors must remain reserved for their established semantics.

Use semantic color for:

- categorical storm risk;
- tornado;
- hail;
- wind;
- fire;
- meaningful hazard state;
- conditional-intensity texture where applicable.

Do not reuse hazard colors for:

- settings categories;
- generic metadata;
- offline status;
- ordinary navigation;
- arbitrary emphasis;
- decorative accents.

Supporting cards should generally use semantic color as an **accent**, not as a full-surface flood of saturated color.

Active awareness may use stronger semantic color when justified by hierarchy.

Neutral state, metadata, stale/offline information, and availability states should use a neutral palette.

---

# 10. Typography

Typography should perform most of the hierarchy work.

Prefer native semantic fonts and Dynamic Type.

Typical hierarchy:

- category or section label;
- primary value or event name;
- supporting explanation;
- metadata.

The primary value should be immediately scannable.

Examples:

**Storm Risk**  
**Moderate**  
Widespread severe storms expected.

**Tornado Risk**  
**15%**  
Within 25 miles of you.

Measurements may use monospaced digits where useful.

Narrative weather text should use proportional system typography rather than monospaced presentation.

Do not compensate for weak hierarchy with more borders, shadows, gradients, or icons.

---

# 11. Icons

Use SF Symbols whenever an appropriate native symbol exists.

Icons should:

- communicate meaning;
- reinforce navigation;
- identify important weather concepts;
- aid scanning.

Avoid icons that exist only to fill empty space.

Do not reproduce malformed or synthetic icons from generated reference images.

If a screenshot conflicts with an appropriate SF Symbol, use the native symbol.

Icon style should remain consistent within the same hierarchy level.

---

# 12. Shape, Spacing, and Density

The redesign should feel spacious without becoming sparse.

Use:

- consistent continuous corners;
- deliberate horizontal alignment;
- clear section rhythm;
- restrained internal padding;
- predictable spacing between related elements.

Avoid excessive nesting of rounded rectangles.

A section containing several cards should not automatically require another large rounded card around those cards.

Prefer:

> canvas → meaningful surface

over:

> canvas → container → card → chip → inner card

Reuse existing radius conventions where they remain appropriate.

If shared spacing constants materially reduce inconsistency, keep the scale small. Do not build a large design-token framework.

Exact pixel measurements from reference screenshots are not binding.

---

# 13. Light and Dark Appearance

Light and dark modes are equal first-class appearances.

Neither is a derivative of the other.

Both should preserve:

- hierarchy;
- semantic color;
- contrast;
- surface relationships;
- readability;
- perceived quality.

Do not simply invert colors.

Light mode should feel clean and restrained rather than stark white.

Dark mode should feel deep and atmospheric rather than composed of many floating gray boxes.

Weather content must remain legible with:

- Reduce Transparency;
- Increase Contrast where applicable;
- system appearance changes.

Do not rely solely on translucent material to separate surfaces.

## 13.1 First-Class Light-Mode Grammar

Do not change approved dark-mode values merely to make shared implementation easier.

Light mode is designed independently, with a quiet neutral foundation and precise weather accents.
It must feel calm and deliberate as a complete composition. Readable individual cards are insufficient
if the screen still feels icy, washed out, or composed of competing slabs.

The following values are the implementation target for Wave 4. Use explicit **sRGB**, opaque fills for
these neutral roles; do not copy numerical components into a Display P3 asset without conversion.
These are a small palette for existing assets and local styling, not a new theme framework.

| Role | Light-mode target | Application |
| --- | --- | --- |
| App canvas | `#F5F6F7` | Neutral off-white with a slight cool character; no blue atmospheric wash behind ordinary Today content. |
| Ordinary weather content | `#FCFCFD` | One near-white family for risk rows, Local Alerts, Atmospheric Conditions, Storm Setup, Outlook Summary, and neutral status surfaces. |
| Neutral primary awareness | `#FCFCFD` | Same content family; establish prominence through type, space, scale, and the existing semantic accent. |
| Content edge | Adaptive primary at 6% opacity, 0.5 pt | One restrained continuous outline where needed; no white highlight rim in light mode. |

### Canvas and content relationships

- Keep the canvas slightly darker than ordinary content. Avoid both stark white canvas and visibly
  blue or lavender neutrals. Do not alternate surface hues by section or weather category.
- Use one opaque content fill. Do not composite the legacy translucent card fill over gradients and
  expect the result to match the neutral family. Nested information normally stays on its parent's fill.
- Current Conditions remains an open header on the canvas. Supporting cards retain their approved
  external-heading or internal-heading structure, corner radii, padding, and alignment.
- A neutral awareness hero uses the same fill as its supporting cards. A semantic warning hero may
  retain its established colored treatment when it conveys warning meaning and supports legible text.
  Do not add an unrelated neutral hue solely to distinguish the hero.
- Quiet, resolving, unavailable, and cached content use the same neutral family. Preserve their existing
  words, symbols, and state distinctions; a new gray slab is not a state indicator.

### Borders and elevation

- Ordinary light-mode weather cards have **no drop shadow**. Use the canvas/content tonal difference
  first; add the single edge treatment above when a boundary needs reinforcement. Do not combine
  nested outlines, white rims, gradients, and shadows to make the same boundary.
- Internal separators, when needed for grouping, use the same quiet neutral edge treatment. Spacing
  remains the default separator; do not draw a divider between every value or row.
- Under Increase Contrast, raise the edge to adaptive primary at 14% opacity and 1 pt where needed.
  Keep text adaptive and verify the actual composition; borders do not substitute for text contrast.
- A stable awareness summary over a variable map may use a restrained shadow for separation:
  black at 6% opacity, radius 4 pt, y offset 1 pt. Start with the opaque fill and edge; use the shadow
  only if representative map backgrounds need it. Keep the base map's native appearance.
- Native floating controls own their platform elevation. Do not add card shadows or custom highlight
  rims around the tab bar, toolbar, or native glass controls.

### Typography and contrast roles

Use adaptive system foreground styles at full opacity. Establish role differences with the existing
Dynamic Type fonts and weights as well as foreground emphasis; never dim an entire content group.
Use .secondary directly and don’t slap another .opacity(0.6) on it.

| Role | Foreground and emphasis |
| --- | --- |
| Location, temperature, primary risk/value, warning title | Primary; retain the approved larger or semibold value treatment. |
| Section heading | Secondary, headline semibold; clearly visible without matching the weight of a primary value. Applies to internal and external section headings. |
| Category or measurement label | Secondary, caption/subheadline at the component's existing size; distinct from its value. |
| Supporting weather meaning or explanatory prose | Secondary, body/subheadline; full opacity, with vertical growth for complete meaning. |
| Metadata and attribution | Secondary, caption; lower priority through size and spacing, with sufficient legibility. |
| Decorative chevron or nonessential separator | Tertiary may be used; essential status and weather text must not depend on tertiary contrast. |

Secondary roles may share the system secondary foreground, but must not collapse into one faint gray
because their size, weight, and placement are identical. Do not hard-code near-black headings or apply
another opacity reduction to secondary text. A control affordance that becomes hard to see needs stronger
adaptive emphasis. Meaningful text on a semantic hero requires a separately verified foreground for
that colored background; do not assume the ordinary neutral text recipe works there.

### Semantic weather color and native controls

- Preserve the established hazard, risk, AQI, and hatching meanings, labels, and symbols. Calm the neutral
  surroundings before changing any semantic treatment. Do not desaturate the weather palette globally.
- Ordinary cards express semantic color through their existing accent, icon, or meaningful value.
  Avoid broad decorative washes in quiet/supporting cards. A warning's stronger semantic surface remains
  justified by its warning meaning, rather than by a desire for more colorful hierarchy.
- Where a semantic hue is too light for text, retain it in the accent and use readable adaptive text
  alongside the existing label/symbol. Do not make yellow, green, or a hatch the sole carrier of meaning.
- Native Liquid Glass/material remains reserved for floating controls and navigation under section 6.
  Weather content stays stable and opaque, including awareness content positioned over the Map.
  Let native controls respond to appearance and accessibility settings; do not imitate their material
  in content cards or add a tinted backing to make ordinary content compete with them.

### WidgetKit translation

- In full-color light rendering, the widget's single outer content background uses the near-white
  content target `#FCFCFD`, rather than the app canvas. Supply it through the existing
  `containerBackground(for: .widget)` boundary and `WidgetSurfaceStyle.baseColor(isDark:)` seam.
- Translate hierarchy through the approved family layouts, system text roles, spacing, narrow semantic
  accents, and complete awareness wording. Ordinary supporting groups share the outer neutral family;
  prefer spacing or restrained separators over nested shaded boxes. A meaningful warning region may
  retain its semantic emphasis, with verified foreground contrast.
- Quiet states need no broad semantic background wash. Existing severity-based washes are implementation
  history, not a requirement to tint every widget. Keep semantic color in meaningful accents and symbols.
- Let WidgetKit supply outer shape, margins, and placement. Do not add an app-style outer card, floating
  shadow, Liquid Glass, or simulated material. Lock Screen presentations remain WidgetKit-native.
- In accented or vibrant rendering, and when the system removes the container background, rely on
  adaptive foregrounds, labels, symbols, and layout. Do not force the sRGB neutral fill back into those
  modes or assume that full-color semantic hues survive system rendering.
- Dark widget styling retains its approved independent base and semantic treatments. App and widget
  hierarchy should agree; their platform backgrounds and material behavior need not be identical.

### Foundation audit and application boundaries (#661)

The existing implementation seams are sufficient; this foundation establishes rules without changing
shared runtime styling. The consumer audit found:

- `skyAwareBackground` also supplies onboarding, loading, settings, diagnostics, and detail screens.
  A global asset edit would repaint those screens as well as Today.
- `cardBackground` and `skyAwareSurface` in `ext+View.swift` serve Today, alert/outlook/detail content,
  diagnostics, and Map presentation. Their translucent `cardBackground` asset, white edges, and
  caller-selected shadows do not yet implement this light grammar.
- The opaque `skyAwareContentSurface` asset/modifier exists, but currently has a cooler light fill and
  also serves nested alert rows. Audit its consumers before changing its value or adding edge behavior.
- `PrimaryAwarenessPanel` also supplies a local blue neutral gradient; changing shared card assets alone
  will not reconcile all Today content. WidgetKit has its own base, washes, and nested badge treatments
  in `WidgetRenderingStyle.swift` and `WidgetRenderingComponents.swift`.

#662 applies this grammar across Today, #663 translates it to Map, and #664 applies it to widgets.
Those stories should reuse the existing seams with audited, appearance-specific changes and preserve
approved dark values and treatments. Scope changes to the owned surface when a shared edit would
repaint unrelated consumers. Do not create a parallel palette manager or migrate every legacy modifier
as part of the foundation story.

### Composition review gate

Use `redesign-2026/target/full-today.png` and `redesign-2026/target/widgets.png` for the intended neutral
surface relationships and typography-led character. Their generated content, tab treatment, shadows,
and atmospheric metrics do not override current product behavior or this grammar.

For each application story, inspect the full Today composition, Map controls plus awareness content,
or small/medium/large widget families as applicable. Compare light and approved dark appearances using
deterministic quiet, meaningful risk, warning, cached/offline, resolving, and unavailable states.
Include larger Dynamic Type, Increase Contrast, Reduce Transparency, and widget rendering variants.
Check that headings scan clearly, prose remains readable, cards form one neutral family, semantic
accents carry meaning, and native controls sit above content. Passing a build or checking palette
swatches alone does not establish visual quality. Record representative rendered evidence before
accepting the surface implementation; integrated validation belongs to #631.

---

# 14. Atmospheric Conditions

Atmospheric Conditions provide supporting context.

They are not a second weather dashboard.

The atmospheric surface should:

- remain visually subordinate to severe-weather awareness;
- emphasize the most useful ingredient;
- use measurement → meaning communication where useful;
- present secondary measurements quietly;
- feel more like instrumentation than a warning card.

Examples include:

- dew point;
- humidity;
- wind;
- pressure.

Avoid giving every atmospheric value equal prominence.

---

# 15. Supporting Risk Presentation

Storm Risk, Severe Risk, and Fire Risk should remain highly glanceable.

Supporting cards should typically contain:

- quiet category label;
- strong primary value;
- short explanatory text;
- narrow semantic accent;
- clear native interaction affordance when interactive.

These surfaces should remain visually subordinate to an active-warning hero.

When there is no active warning, one or more of these risk presentations may carry greater hierarchy as defined by the relevant story and existing awareness-selection behavior.

Conditional-intensity information should remain a modifier of the severe risk rather than becoming a competing category.

---

# 16. Map Experience

The map is weather content first.

The Map is an awareness surface, not a general-purpose weather explorer.

Map overlays should remain visually dominant over app controls.

Floating controls may use native Liquid Glass where supported.

Prefer native interaction patterns for:

- layer selection;
- location;
- warning visibility;
- map utilities.

Map controls should occupy as little visual area as practical while remaining obvious and accessible.

Risk polygons, warning polygons, hatching, and other meteorological overlays retain their established semantic meaning.

Do not redesign underlying map data semantics as part of visual work.

Any awareness summary floating over the map should:

- show useful current information;
- be compact;
- not obscure an excessive portion of the map;
- disappear entirely when there is nothing meaningful to show rather than leaving an empty container.

---

# 17. Widgets

Widgets should belong to the same visual family as the app without reproducing the full Today screen.

They should prioritize glanceability.

Do not show an “as of” update time in any widget, including its accessibility label. Keep freshness
timestamps internal to widget state and presentation decisions.

Hierarchy changes by widget size.

### Small

One primary awareness concept.

### Medium

Primary awareness plus limited supporting context.

### Large

Primary awareness plus the most useful risk and condition context.

Do not squeeze every available metric into a widget because space exists.

Quiet-weather states must feel intentionally calm.

Warning states may use stronger semantic emphasis.

Widget styling should remain compatible with WidgetKit behavior and platform constraints rather than attempting to simulate app-level Glass or navigation surfaces.

---

# 18. Motion and Interaction

Motion supports comprehension.

It should never make routine refresh activity feel dramatic.

Use native SwiftUI transitions and existing SkyAware motion conventions where appropriate.

Respect Reduce Motion.

Avoid:

- decorative continuous animation;
- unnecessary spring effects;
- animated refresh churn;
- motion that causes cached content to disappear and re-enter;
- transitions that imply a meaningful state change when only data freshness changed.

Pressed states and feedback should feel subtle and native.

---

# 19. Accessibility

Accessibility is part of the component design.

Every redesigned component must preserve or improve:

- Dynamic Type;
- VoiceOver;
- button semantics;
- minimum interaction targets;
- Reduce Motion;
- sufficient contrast;
- non-color communication of important meaning.

At accessibility text sizes, allow layouts to adapt rather than aggressively shrinking text.

Prefer vertical expansion or alternate layout over truncating essential weather information.

Semantic weather meaning must not depend solely on color.

---

# 20. Existing State and Behavior

This redesign must preserve existing accepted-state behavior unless a story explicitly changes it.

In particular:

- keep valid cached content visible;
- preserve resolve-forward behavior;
- distinguish cached, current, resolving, unavailable, and confirmed-empty states;
- do not turn temporary refresh activity into empty UI;
- preserve existing navigation destinations;
- preserve alert ordering and domain interpretation;
- preserve map data semantics;
- preserve canonical state ownership.

Presentation code must not recreate refresh, persistence, or domain business rules already owned elsewhere.

If a seemingly visual change requires new domain state, stop and verify that the story actually owns that change.

---

# 21. Code Simplification

The redesign is intentionally an opportunity to simplify presentation code.

Agents may:

- remove obsolete visual modifiers;
- replace custom interaction plumbing with native SwiftUI;
- consolidate duplicated presentation code when the simplification is obvious and local;
- remove redundant nested surfaces;
- delete abstractions made unnecessary by the new design.

Agents should not:

- introduce speculative design systems;
- build large token frameworks;
- rewrite unrelated architecture;
- move state ownership merely to make a view easier to style;
- perform broad cleanup outside the affected presentation boundary.

Prefer the smallest abstraction that removes real duplication.

Prefer deletion to replacement when possible.

---

# 22. Visual References

Reference assets live under:

`docs/design/redesign-2026/`

Expected organization:

```text
master/
current/
crops/
visual-contract.md
```

Each implementation issue should identify the exact relevant references.

Issues should normally provide:

- this contract;
- one to three target references;
- a current-state screenshot when it materially clarifies the transformation;
- a broader master reference only when needed for context.

Agents should not need to inspect the entire visual gallery for a narrow component story.

---

# 23. Interpreting Generated Mockups

Target images were created to communicate design intent.

Use them to understand:

- visual hierarchy;
- density;
- relative spacing;
- proportion;
- semantic color placement;
- surface relationships;
- overall character.

Do not treat them as authoritative for:

- exact text wrapping;
- exact dimensions;
- system status bars;
- SF Symbol selection;
- synthetic icons;
- incidental shadows;
- exact gradients;
- generated wording;
- unsupported platform behavior.

When an image contains an obviously generated artifact, fix it rather than reproducing it.

---

# 24. Previews and Verification

Affected components should have deterministic SwiftUI previews where practical.

Important states should be easy for an implementing or reviewing agent to inspect without requiring live weather.

High-value preview states include:

- quiet/no-warning;
- meaningful severe risk;
- active Severe Thunderstorm Warning;
- active Tornado Warning;
- cached/offline;
- resolving with accepted cached content;
- unavailable/no cached content;
- light;
- dark.

Do not create large snapshot-testing infrastructure as part of this redesign unless a story explicitly calls for it.

Visual implementation should be reviewed on-device or in representative previews during the redesign integration process.

---

# 25. Agent Guidance

Before changing a component:

1. Inspect the current implementation.
2. Identify the actual presentation/state owner.
3. Follow existing dependencies rather than assuming ownership from filenames.
4. Confirm which behavior must remain unchanged.
5. Open the issue's referenced target images.
6. Apply this contract.
7. Prefer native SwiftUI behavior where it reduces custom machinery.
8. Keep changes inside the story's intended boundary.
9. Update or add useful previews.
10. Stop when the requested visual behavior is complete.

Do not broaden a focused visual story into an unrelated redesign.

Do not redesign components outside the story merely because they are nearby.

Do not preserve complexity solely because it already exists.

---

# 26. Definition of Success

The redesign succeeds when SkyAware:

- feels more native to iOS;
- looks simpler and more deliberate;
- feels premium without becoming decorative;
- communicates severe-weather importance more clearly;
- preserves SkyAware's semantic visual identity;
- uses less unnecessary custom presentation code;
- uses native SwiftUI behavior wherever appropriate;
- uses Liquid Glass intentionally rather than pervasively;
- remains calm during refresh, offline operation, and state changes;
- looks coherent in light and dark appearances;
- remains accessible at large Dynamic Type sizes;
- preserves existing trusted weather behavior.

A successful implementation should make the interface feel as though the product and platform belong together.

It should not feel like SkyAware was reskinned to follow a trend.
