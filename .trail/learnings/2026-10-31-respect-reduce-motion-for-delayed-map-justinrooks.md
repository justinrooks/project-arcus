---
title: Respect Reduce Motion for delayed map centering
author: Justinrooks
date: 2026-10-31
branch: issue-814
touches:
  - Sources/Features/Map/MapCanvasView.swift
  - Tests/UnitTests/RiskPolygonOverlayTests.swift
---

## Decided

Issue #814 reproduced delayed first-coordinate camera animation with actual system Reduce Motion enabled on iPhone 18 Pro / iOS 27.2. Read accessibilityReduceMotion at MapCanvasView and use it for the delayed setRegion request. Preserve nonanimated creation, viewport size, and one-time camera ownership. Runtime validation on iOS 27.2 alone was explicitly accepted for this issue.

## Tried and ruled out

Static Home fixtures do not establish nil-to-first-coordinate timing. A temporary DEBUG synthetic host exercised the actual representable, then was removed after verification. RunCodeSnippet executes without a visible app window and cannot replace this runtime host. Do not retain startup exceptions merely for this one investigation.

## Watch out

A recording is needed to assess camera motion; a final screenshot or Boolean-policy test is insufficient. Map tile/label loading can continue after camera geometry settles. MKMapView invokes setRegion during initialization: clear that initial request when using a recording subclass to test subsequent requests. Compare system Reduce Motion off/on and verify later updates retain a user-panned viewport. Deterministic regression tests supplement simulator evidence, not physical-device acceptance.
