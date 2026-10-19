---
title: Cross-surface outlook navigation replaces retained stack
author: Justinrooks
date: 2026-10-19
branch: issue-705
touches:
  - Sources/App/HomeView.swift
  - Sources/Features/ConvectiveOutlookView/ConvectiveOutlookDetailView.swift
  - Sources/Features/ConvectiveOutlookView/ConvectiveOutlookView.swift
  - Sources/Features/Map/MapScreenView.swift
  - Tests/UnitTests/ConvectiveOutlookRepoTests.swift
---

## Decided
Home owns the Outlooks NavigationStack path so Map-to-Outlooks requests replace any prior detail route with exactly one accepted same-day DTO, or an empty path when no accepted discussion exists. Clear the path when Outlooks becomes hidden; on ordinary tab entry, reset the selected day to Day 1.

## Tried and ruled out
Using navigationDestination(item:) for cross-surface requests while row links push separate destinations can stack a new detail over a stale retained detail. The back button then reveals the wrong detail instead of the Outlooks list.

## Watch out
Navigation state persists across tab switches. Treat cross-surface navigation as a path replacement, and test accepted-data and unavailable-data routing without relying on UI tests when the requested evidence is unit-only.
