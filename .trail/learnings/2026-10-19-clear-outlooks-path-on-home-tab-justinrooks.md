---
title: Clear Outlooks path on Home tab exit
author: Justinrooks
date: 2026-10-19
branch: issue-735
touches:
  - Resources/PreviewContent/ConvectiveOutlookSamples.swift
  - SkyAware.xcodeproj/project.pbxproj
  - Sources/App/HomeView.swift
  - Tests/SkyAware_UI_Smoke.xctestplan
  - Tests/UITests/SkyAwareUITests.swift
---

## Decided
Home's selected-tab transition owns clearing the Outlooks NavigationStack path when leaving Outlooks, while preserving selectedDay. Ordinary entry resets to Day 1; explicit Map-to-Outlooks preparation preserves its requested day. The Outlooks visibility callback only cancels an abandoned pending request and never mutates the path.

## Tried and ruled out
Clearing the path from the child view's visibility callback competes with Home-owned navigation state during SwiftUI root reattachment. Native Back and root reattachment do not represent a tab transition and must preserve the selected day.

## Watch out
Navigation state remains mounted across tab selection. Cover Day 1-3 detail-to-Map-to-discussion round trips with rendered UI assertions and verify Back returns to the same-day list. Keep Map routing unchanged.
