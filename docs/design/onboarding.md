---
title: SkyAware Onboarding
status: Canonical
project: Project Arcus
tags:
  - skyaware
  - onboarding
  - design
  - swiftui
---

# SkyAware Onboarding

## Purpose

This document defines the shared visual and navigation contract for the first-run onboarding flow. It complements [Foundations](foundations.md), [States and Accessibility](states-accessibility.md), and [Brand and Voice](../brand/brand-and-voice.md); those documents remain authoritative for shared styling, accessibility, product meaning, and approved language.

The approved visual direction is `redesign-2026/target/onboarding-flow.png`. Use it for composition, hierarchy, density, and control character. It is illustrative and does not approve its sample copy, claims, exact measurements, or system dialogs.

## Shared presentation

- Use the app's semantic background in both appearances. Light mode stays clean, neutral, and slightly cool; dark mode uses the established deep navy and charcoal relationships. Keep typography adaptive and readable in both. Do not introduce a separate onboarding palette, weather-risk decoration, or broad theme framework.
- Keep a consistent scrollable content area and a bottom-anchored action area. Content grows vertically for small screens and accessibility text sizes; actions remain reachable.
- Use one heading scale, symbol size, spacing rhythm, and primary/secondary action treatment across steps. The welcome screen is the distinct branded entry point and uses an approved SkyAware brand asset.
- Keep progress compact and understandable. The required journey has four stages: Welcome, Important Information, Location Access, and Notifications. Show Background Awareness as an optional conditional step after When In Use access; identify it as optional and do not count it as required progress.
- Progress is informational, not interactive. It must never imply that the disclaimer can be skipped or that a permission is required to continue.

## Step order and responsibilities

1. **Welcome** introduces SkyAware and its severe-weather awareness purpose.
2. **Important Information** presents the complete approved disclaimer and requires explicit acknowledgment. Do not add skip, swipe, or dismissal affordances that bypass acceptance.
3. **Location Access** explains location use and privacy before the native authorization request. Skipping remains available.
4. **Background Awareness** appears only when the user has When In Use authorization and offers a clear, optional Always upgrade. Skipping continues to notifications.
5. **Notifications** explains notification value and limitations. Allowing or skipping completes onboarding.

Navigation is action-driven. Users cannot advance by swiping between pages. Honor Reduce Motion and provide concise VoiceOver progress text. Permission meaning, native prompt timing, existing checkpoint flags, notification/APNs setup, and location privacy behavior remain owned by the existing flow.

## Copy and asset constraints

- Preserve the approved legal disclaimer and its required acknowledgment. Visual work does not authorize paraphrasing or shortening legal copy.
- Explain the user benefit and limitations of each permission plainly. Preserve opt-out and never imply that access guarantees timely alerts or safety.
- Use the actual approved SkyAware brand asset in the welcome treatment. Do not recreate it or substitute generated artwork, generic weather marks, or mockup symbols.
- Reused Disclaimer and Location views must remain suitable inside post-onboarding sheets as well as the first-run flow.

## Accessibility and appearance

Follow [States and Accessibility](states-accessibility.md): support Dynamic Type, VoiceOver, semantic contrast, and Reduce Motion. Keep important content in the scroll region and actions reachable without fixed-height assumptions. Review light and dark independently; neither is an inversion of the other.
