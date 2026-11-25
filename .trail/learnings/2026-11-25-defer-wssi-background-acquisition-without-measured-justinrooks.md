---
title: Defer WSSI background acquisition without measured residual budget
author: Justinrooks
date: 2026-11-25
branch: issue-917
touches:
  - Sources/App/BackgroundRefreshLifecycle.swift
  - Sources/App/SkyAwareApp.swift
  - Sources/Providers/WSSI/WSSIForeground.swift
  - Sources/Repos/WSSIAcceptedStore.swift
  - Tests/UnitTests/WSSISyncTests.swift
  - docs/validation/wssi-integrated-device-run.md
  - wssi-device-validation-2.txt
  - wssi-device-validation.txt
---

## Decided
WSSI optional work uses the existing app-refresh grant after core outcome persistence and successor scheduling. Measure its budget from callback entry, keep the production admission gate off until residual device time is observed, and preserve foreground acquisition and accepted-store reads independently.

## Tried and ruled out
The integrated iPhone run acquired and committed all 15 slots in 16.29 seconds, then reused all 15 after relaunch with a manifest 304 in 620 ms. Neither capture included an iOS background grant, so foreground timing does not establish a practical background window. The first container exports did not yield the capture; a temporary native Settings share link provided direct access to the scoped text artifact.

## Watch out
A foreground offer can cancel background WSSI without clearing the active work handle. Let the sync actor drain its previous workload before beginning another transport request. Gate acceptance against cancellation and the absolute deadline, and keep device capture code and raw exports out of the production change.
