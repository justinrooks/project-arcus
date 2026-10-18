---
title: Keep canceled map reload ownership until unwind
author: Justinrooks
date: 2026-10-18
branch: issue-601
touches:
  - Sources/Features/Map/MapFeatureModel.swift
  - Tests/UnitTests/HomeRefreshPipelineTests.swift
  - Tests/UnitTests/MapFeatureModelSceneTests.swift
---

## Decided
A canceled map reload remains the coordinator's active operation until its async provider work unwinds. Any replacement full reload queues behind it so the map model's isLoading guard cannot discard the replacement.

## Tried and ruled out
Clearing the task reference immediately on cancel and starting a replacement allows overlapping model reloads; the replacement can return early while isLoading is true, leaving the visible map stale.

## Watch out
Keep full reloads higher priority than queued mesoscale refreshes. Test hide-to-show with a provider gate that returns despite cancellation, then assert the replacement fetch and scene publication.
