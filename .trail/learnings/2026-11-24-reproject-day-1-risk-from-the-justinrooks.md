---
title: Reproject Day 1 risk from the accepted SPC revision
author: Justinrooks
date: 2026-11-24
branch: issue-927
touches:
  - Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift
  - Sources/App/HomeRefreshV2/HomeSnapshotStore.swift
  - Sources/App/SkyAwarePersistentStoreBootstrap.swift
  - Sources/Providers/SPC/SpcProvider+Syncing.swift
  - Sources/Repos/HomeProjectionStore.swift
  - Sources/Repos/SevereRiskRepo.swift
  - Sources/Repos/SpcMapBatchPersistenceRepo.swift
  - Sources/Repos/StormRiskRepo.swift
  - Tests/UnitTests/HomeRefreshPipelineTests.swift
  - Tests/UnitTests/SpcProviderSyncMapProductsTests.swift
---

## Decided
The Day 1 categorical and hazard transaction owns both the geometry and the marker proving its accepted window and row coverage. Home evaluates both risks for the destination from that marker and checks the same revision and location at save. Feed acceptance, widget source age, and the background comparison baseline keep their own authority.

## Tried and ruled out
Raw point-query all-clear also means no rows. Feed-state generation and location-specific notification tokens do not prove a coherent geometry revision or an empty window. Preserve legacy rows through the lightweight migration and establish reprojection authority from a subsequent qualified acceptance.

## Watch out
An accepted undated empty supports the accepting run only. A dated empty can be reprojected within its window. Rejected refresh must preserve existing same-location stale data when retained revision proof is absent or expired. Keep Fire independent and never use projected time as source acceptance time.
