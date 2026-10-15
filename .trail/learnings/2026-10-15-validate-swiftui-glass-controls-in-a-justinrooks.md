---
title: Validate SwiftUI glass controls in a live simulator
author: Justinrooks
date: 2026-10-15
branch: issue-692
touches:
  - Sources/Features/Map/Picker.swift
  - Sources/Features/Summary/AwarenessSupportRow.swift
  - Tests/UnitTests/SummaryAwarenessPanelTests.swift
  - docs/images/issue-692/map-picker-dark-increased-contrast-ios-26-5.jpg
  - docs/images/issue-692/map-picker-dark-ios-26-5.jpg
  - docs/images/issue-692/map-picker-light-ios-26-5.jpg
  - docs/images/issue-692/map-picker-wind-layer-dark-increased-contrast-ios-26-5.jpg
  - docs/images/issue-692/today-support-intensity-accessibility-dark.png
  - docs/images/issue-692/today-support-long-detail-dark.png
---

## Decided
Use unit ImageRenderer output for ordinary SwiftUI rows, but inspect native Menu glass with a live simulator screenshot because Menu labels may render as placeholders outside a window hierarchy.

## Tried and ruled out
ImageRenderer of MapLayerMenu produced a yellow placeholder instead of the control, so it was not valid visual evidence.

## Watch out
When Xcode hangs collecting diagnostics after parallel simulator tests, a focused nonparallel unit run can produce a finalized xcresult without changing test selection.
