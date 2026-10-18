---
title: Prioritize queued full map reloads over meso cadence work
author: Justinrooks
date: 2026-10-18
branch: issue-601
touches:
  - Sources/App/HomeRefreshPipeline.swift
  - Sources/App/HomeView.swift
  - Sources/Features/Map/MapFeatureModel.swift
  - Sources/Features/Map/MapScreenView.swift
  - Tests/UnitTests/HomeRefreshPipelineTests.swift
---

## Decided
Reuse HomeRefreshPipeline's foreground timer generation for visible map refreshes. Nationwide meso cadence refreshes update only the meso render plan and must not replace an already queued full map reload; full refreshes remain higher priority.

## Tried and ruled out
Using one unprioritized pending-operation slot allowed a meso cadence event to overwrite a queued full refresh and leave accepted warning or SPC data stale.

## Watch out
Map freshness tests should identify discussions by stable overlay keys, not polygon titles. Trail check may misread polygon rendering or the existing overlay-key assertions as violating that rule; verify the exact source behavior before changing them.
