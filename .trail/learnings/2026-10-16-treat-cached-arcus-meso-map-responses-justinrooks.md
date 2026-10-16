---
title: Treat cached Arcus meso map responses as stale
author: Justinrooks
date: 2026-10-16
branch: issue-598
touches:
  - Sources/Features/Map/MapFeatureModel.swift
  - Tests/UnitTests/MapFeatureModelSceneTests.swift
  - Tests/UnitTests/MapFeatureModelTestSupport.swift
---

## Decided
Map consumers that present Arcus meso data as accepted scene state should replace it only from live or cache-revalidated responses. Treat cache fallback and local cache as failures so empty cached data cannot clear the accepted polygons or claim confirmed emptiness.

## Tried and ruled out
Using the polygon title to identify a discussion in map scene tests; the renderer title is the map layer title. Use the overlay key, which includes the discussion number.

## Watch out
When validating Swift test lanes through rtk summary, inspect the finalized xcresult summary for exact counts and outcome; the condensed text heuristic may mislabel parameterized results.
