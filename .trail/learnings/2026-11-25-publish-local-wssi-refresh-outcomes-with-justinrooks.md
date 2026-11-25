---
title: Publish local WSSI refresh outcomes with accepted assessments
author: Justinrooks
date: 2026-11-25
branch: issue-951
touches:
  - Sources/Providers/WSSI/WSSIForeground.swift
  - Tests/UnitTests/WSSISyncTests.swift
---

## Decided
WSSIForeground exposes the latest completed local manifest failure or slot reconciliation on WSSIAcceptedAssessment. Periods still come from the accepted store, so a local failure can accompany readable geometry and successful Forge poll metadata. A successful retry replaces the local report, and changing admission resets it.

## Tried and ruled out
The baseline reader returned no local status even after a manifest 503 or a completed slot reconciliation. Keeping the bounded classifications already returned by WSSISync avoids deriving local failures from Forge poll health or modifying persisted state.

## Watch out
Capture admission before starting the task and check it with task cancellation and the background deadline at publication. Disabled, cancelled, and superseded outcomes leave the current report alone. Keep the active task handle until the completion path releases it so a foreground offer does not overlap a draining background refresh.
