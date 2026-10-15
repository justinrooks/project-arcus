---
title: SkyAware Design System
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - design
  - swiftui
  - ux
---

# SkyAware Design System

## Purpose

This directory defines SkyAware's visual and interaction design system.

It is the canonical reference for how SkyAware looks, feels, and behaves across its supported Apple-platform experiences.

The design system exists to:

- Preserve a consistent, recognizable product identity.
- Make complex weather information clear and actionable.
- Maintain high visual and interaction quality.
- Reduce unnecessary design decisions and one-off treatments.
- Support efficient, focused implementation.
- Prevent visual and interaction regressions as SkyAware evolves.

These documents describe established design decisions and behavioral expectations.

They are not a mandate to redesign unrelated functionality or introduce additional visual infrastructure.

---

# 1. Design Philosophy

SkyAware is a severe-weather awareness assistant, not a generic weather application.

Its design should help users answer:

> How weather-aware do I need to be right now?

The interface should feel:

- Calm.
- Precise.
- Trustworthy.
- Premium.
- Focused.
- Distinctly SkyAware.
- Native to Apple platforms.

## Calm Does Not Mean Colorless

SkyAware combines a restrained, Apple-native foundation with a distinctive semantic weather identity.

Neutral surfaces establish calm.

Typography and spacing establish hierarchy.

Purposeful weather color establishes recognition, meaning, and relative importance.

Native interactions establish familiarity and trust.

A calm interface must not become visually anonymous.

Avoid both extremes:

- Excessive decoration that competes with information.
- Excessive neutrality that conceals importance or interaction.

## Premium Means Deliberate

Premium quality is demonstrated through:

- Consistent visual relationships.
- Precise alignment and spacing.
- Carefully controlled information density.
- Clear interaction affordances.
- Smooth, predictable state transitions.
- Excellent light and dark appearances.
- Accessibility designed into components.
- Thoughtful handling of unusual and degraded states.

Premium is not achieved by adding more gradients, shadows, Glass, icons, or animation.

**The simplest solution that communicates the correct meaning beautifully is usually the best one.**

---

# 2. Documentation Ownership

SkyAware separates product truth, brand communication, and visual implementation.

Each decision should have one authoritative home.

| Responsibility | Canonical document |
| --- | --- |
| Product purpose, priorities, and weather semantics | [North Star](../product/north-star.md) |
| Brand identity, voice, vocabulary, and marketing | [Brand and Voice](../brand/brand-and-voice.md) |
| Visual foundations and interaction design | This design system |
| Existing implementation and state ownership | Current source code and tests |

## Ownership Rules

The North Star determines **what SkyAware means and does**.

Brand and Voice determines **how SkyAware communicates**.

Design determines **how SkyAware presents information and interaction**.

Source code establishes the existing implementation, but existing code is not automatically the intended design.

Do not duplicate detailed design rules in product or brand documentation.

Do not redefine meteorological meaning inside presentation specifications.

Do not change accepted domain behavior merely to make a visual implementation easier.

When a decision spans responsibilities, reference the appropriate authoritative document.

---

# 3. Design Documentation Map

The design system is organized by responsibility and product surface.

| Document | Responsibility |
| --- | --- |
| [Foundations](foundations.md) | Visual hierarchy, typography, color, surfaces, shape, spacing, materials, light/dark appearance, native controls |
| [Today](today.md) | Current Conditions, Today's Awareness, semantic gradients, risk cards, Local Alerts, Atmospheric Conditions, Storm Setup, Outlook Summary |
| [Map](map.md) | Map presentation, controls, overlays, layer selection, legends, conditional-intensity visualization |
| [Widgets](widgets.md) | Home Screen and Lock Screen widget presentation, family hierarchy, semantic states, constrained layouts |
| [Onboarding](onboarding.md) | First-run screen hierarchy, conditional progress, permission trust, and required acknowledgment |
| [States and Accessibility](states-accessibility.md) | Loading, cached refresh, offline, unavailable, empty, Dynamic Type, VoiceOver, contrast, motion, interaction accessibility |
| [Visual Review](visual-review.md) | Design acceptance, screenshot review, representative weather states, device coverage, visual regression prevention |

## How to Use These Documents

Read only the guidance relevant to the current task.

Examples:

**Refining Today's Awareness**

Consult Foundations and Today.

Consult States and Accessibility when state transitions or adaptive behavior are affected.

**Correcting a large-widget layout**

Consult Widgets.

Consult States and Accessibility for relevant text, content, or accessibility behavior.

**Changing Map controls**

Consult Foundations and Map.

**Reviewing a screenshot**

Consult the relevant surface specification and Visual Review.

**Writing notification copy**

Consult Brand and Voice and the applicable product semantics in the North Star.

**Changing persistence or ingestion**

The design system is normally unnecessary unless the change materially affects presentation.

Avoid loading the entire documentation system for a narrow task.

---

# 4. Design Authority and Precedence

When guidance appears to conflict:

1. Preserve correct weather meaning, accepted-state semantics, and product safety requirements.
2. Preserve accessibility and supported native platform behavior.
3. Follow the North Star for product behavior.
4. Follow Brand and Voice for communication.
5. Follow the relevant Design specification for visual and interaction presentation.
6. Use approved reference screenshots to interpret established visual intent.
7. Treat generated mockup details as illustrative, not authoritative.

These are complementary responsibilities, not competing styling preferences.

A more specific Design specification takes precedence over a general Design principle when both apply.

For example:

Ordinary weather content uses restrained neutral surfaces.

Today's Awareness has an explicitly approved semantic-gradient treatment.

That treatment is a deliberate exception, not permission to add gradients everywhere.

If a genuine conflict remains, identify it before making a consequential design decision.

Do not silently choose whichever interpretation is easiest to implement.

---

# 5. Foundational Design Invariants

The following principles apply across SkyAware.

## Weather Information Comes First

Meteorological meaning determines hierarchy.

Never distort weather information to fit a preferred layout, color treatment, or animation.

## Native, Not Generic

Prefer native SwiftUI behavior where it improves accessibility, reliability, or interaction quality.

Preserve custom SkyAware presentation where it communicates meaningful weather information.

## Semantic Color Has Meaning

Risk and hazard colors are not decorative accents.

Preserve their established meaning.

Do not reuse them casually in unrelated controls or application status indicators.

## Content and Controls Are Different Layers

Weather content should remain stable and readable.

Native Glass belongs primarily to appropriate navigation and floating controls.

Do not use Glass simply because the platform supports it.

## Light and Dark Are First-Class

Light mode is not an inverted version of dark mode.

Both appearances require deliberate visual decisions and independent evaluation.

## Interaction Affordances Must Be Honest

A control must look interactive when it is actionable.

A noninteractive surface must not advertise navigation.

Prefer native interaction semantics over decorative imitations of controls.

## Accessibility Is Part of the Design

Weather meaning must survive changes in text size, contrast, motion, transparency, and assistive technology.

Essential content must not depend solely on color.

## State Continuity Builds Trust

Preserve valid accepted information during refresh.

Avoid visual churn, unnecessary reflow, and presentation of intermediate or inconsistent weather state.

## Simplicity Is an Architectural Advantage

Prefer established components and native behavior.

Avoid speculative abstractions and one-off visual systems.

New styling infrastructure must solve a real consistency or maintenance problem.

---

# 6. Implementation Discipline

Before changing an existing interface:

1. Identify the actual presentation owner.
2. Inspect the current implementation.
3. Establish the behavior that must remain unchanged.
4. Read the relevant design documentation.
5. Identify the smallest coherent implementation change.
6. Preserve existing navigation and weather semantics.
7. Validate the resulting composition.
8. Stop when the intended behavior is correct.

Do not treat visual work as authorization to:

- Change domain logic.
- Reinterpret forecast data.
- Introduce new weather features.
- Modify navigation destinations.
- Restructure persistence.
- Replace accepted-state ownership.
- Redesign unrelated surfaces.
- Introduce broad styling infrastructure.

When a visual change reveals a genuine architectural or product question, resolve that question explicitly rather than hiding it inside presentation code.

---

# 7. Reference Images and Mockups

Screenshots and mockups communicate visual intent.

They may establish:

- Hierarchy.
- Density.
- Proportion.
- Relative spacing.
- Semantic color placement.
- Component relationships.
- Overall visual character.

They do not automatically establish:

- Exact implementation dimensions.
- Pixel-perfect layout requirements.
- New features.
- New weather sources.
- New navigation behavior.
- New hazard semantics.
- Exact system-control behavior.

Generated images may contain inaccurate symbols, text, weather information, or unsupported controls.

Do not reproduce those artifacts.

Actual approved application screenshots are stronger evidence of the accepted visual direction than exploratory generated compositions.

Historical redesign references may remain under:

`docs/design/redesign-2026/`

They support investigation but do not supersede the current canonical specifications.

---

# 8. Visual Validation

A successful build does not establish visual correctness.

Review complete compositions, not only isolated components.

Visual validation should consider:

- Quiet weather.
- Elevated severe-weather risk.
- Active watches and warnings.
- Cached and refreshing information.
- Unavailable and offline states.
- Light and dark appearances.
- Standard and larger iPhone widths.
- Relevant WidgetKit families.
- Long or variable content.
- Dynamic Type and accessibility settings.

Check for:

- Incorrect hierarchy.
- Inconsistent spacing.
- Weak contrast.
- Misleading affordances.
- Clipped or overlapping content.
- Unexpected responsive layouts.
- Muddy or abrupt color transitions.
- Unnecessary animation or visual churn.
- Inconsistency with established components.

Use deterministic previews where useful.

Prefer focused visual verification and actual rendered evidence over elaborate testing infrastructure without demonstrated value.

Detailed acceptance procedures belong in [Visual Review](visual-review.md).

---

# 9. Design Change Discipline

Established design decisions should remain stable.

Do not reopen settled visual questions without a meaningful reason.

Valid reasons include:

- A demonstrated usability problem.
- An accessibility failure.
- Incorrect weather meaning.
- A genuine platform compatibility issue.
- A reproducible layout defect.
- A clear inconsistency in established patterns.
- A deliberate new product requirement.

Personal preference alone is insufficient justification for repeatedly changing approved components.

When a new design decision is approved:

1. Update the document that owns the decision.
2. Remove or correct contradictory guidance.
3. Reference shared foundations rather than duplicating them.
4. Preserve unrelated established behavior.
5. Update visual references when they materially help.
6. Keep implementation instructions aligned with the current canonical guidance.

Avoid creating permanent documentation for every temporary experiment or rejected alternative.

Git history and issue discussions preserve exploration.

Canonical documentation preserves accepted direction.

---

# 10. Definition of Design Success

A successful SkyAware interface:

- Communicates severe-weather meaning quickly.
- Establishes an obvious information hierarchy.
- Uses semantic color accurately.
- Feels calm without losing character.
- Behaves naturally on Apple platforms.
- Remains legible in light and dark appearances.
- Preserves accessibility and state continuity.
- Makes interaction discoverable and predictable.
- Avoids unnecessary decoration.
- Feels coherent with the rest of the product.

The design should communicate that someone has carefully considered every meaningful detail.

**SkyAware should feel like one thoughtfully designed product, not a collection of independently styled features.**

---

# Final Principle

The design system exists to protect clarity, consistency, and trust.

Its purpose is not to prevent improvement.

Its purpose is to ensure that improvements strengthen the whole product rather than solving one visual problem at the expense of another.

**Preserve the established language. Adapt it thoughtfully. Change only what makes SkyAware better.**
