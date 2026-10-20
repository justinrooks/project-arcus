---
title: Own manual refresh completion by attempt ID
author: Justinrooks
date: 2026-10-20
branch: issue-614
touches:
  - Sources/App/HomeRefreshPipeline.swift
  - Tests/UnitTests/HomeRefreshPipelineTests.swift
---

## Decided
Give each manual refresh a unique attempt ID and let only the current owner update shared manual completion state. Pass the ID through both awaited and task-based submit completion paths.

## Tried and ruled out
A shared projection key cannot distinguish overlapping manual attempts at the same location; an older Alerts completion can clear it before a newer Today completion reports success.

## Watch out
Use a sequenced coordinator with separate gates to prove completion ordering in unit tests. Keep projection validation so an attempt that finishes after a location change still cannot report success.
