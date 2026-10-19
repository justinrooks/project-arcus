---
title: Clarify current-only alerts in future Map outlooks
author: Justinrooks
date: 2026-10-19
branch: issue-703
touches:
  - "Sources/Features/Map/MapAccessibilitySupport.swift#MapForecastPresentationPolicy"
  - "Sources/Features/Map/MapScreenView.swift#MapScreenContent"
  - "Sources/Features/Map/Picker.swift#MapLayerMenu"
  - "Tests/UnitTests/MapFeatureModelTests.swift#forecastPresentationPolicy_currentAndFutureDays"
---

## Decided
Day 2–3 map outlooks keep the existing native MapLayerMenu and warning preference, but label the toggle Show Current-Day Alerts and state in accessibility summaries that active warnings are current-day only. The control remains available so the saved preference survives returning to current scenes.

## Tried and ruled out
Hiding the warning toggle would discard useful access to the persisted preference while on a future outlook; relabeling it keeps the control and makes its scope clear.

## Watch out
trail check may treat MapLayerMenu references or MapLayerScene.placeholder unit fixtures as restoration of removed map UI or ImageRenderer placeholders. This change does not render the menu with ImageRenderer and adds no UI tests; keep validation unit-only.
