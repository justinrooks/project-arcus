---
title: Cancel abandoned pending Outlook navigation requests
author: Justinrooks
date: 2026-10-19
branch: issue-705
touches:
  - Sources/App/HomeView.swift
  - Sources/Features/ConvectiveOutlookView/ConvectiveOutlookView.swift
  - Sources/Features/Map/MapScreenView.swift
  - Tests/UnitTests/ConvectiveOutlookRepoTests.swift
---

## Decided
A Map-to-Outlooks discussion request should select its requested forecast day as soon as it is pending, so the visible loading state stays on that day. If the user leaves Outlooks before it resolves, cancel and acknowledge only the same pending request UUID; mark it handled so later tab entry cannot replay it. Home acknowledgement callbacks must clear only the matching shared request UUID, preserving any newer request.

## Tried and ruled out
Clearing the shared cross-surface request unconditionally can erase a newer request that replaced the one being handled. Leaving an abandoned loading request live allows ordinary Outlooks reentry to replay it.

## Watch out
Trail lexical checks may flag existing navigationDestination wording, navigation request pending states, or test names as conflicts with unrelated learnings about stacked destinations, refresh scheduling, or device delivery. Inspect the actual implementation and explain these false positives when the code does not violate those learnings. Keep verification unit-only when requested; unit results do not establish rendered navigation or device behavior.
