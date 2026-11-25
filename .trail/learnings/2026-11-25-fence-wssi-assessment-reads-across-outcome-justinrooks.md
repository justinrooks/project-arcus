---
title: Fence WSSI assessment reads across outcome publication
author: Justinrooks
date: 2026-11-25
branch: issue-951
touches:
  - Sources/Providers/WSSI/WSSIForeground.swift
  - Tests/UnitTests/WSSISyncTests.swift
---

## Decided
Capture the local outcome generation with the status before reading accepted periods. Discard the assessment if generation, admission, or location fails revalidation at the existing publication boundary.

## Tried and ruled out
Moving status capture after the store read could pair an older store observation with a newer report. A suspended read reproduced stale failure publication on the prior head.

## Watch out
Every reportable completion advances the generation even when its status compares equal. Cancelled or superseded work produces no report. Admission already fences gate resets.
