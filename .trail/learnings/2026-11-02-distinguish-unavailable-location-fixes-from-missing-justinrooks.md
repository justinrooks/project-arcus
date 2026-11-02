---
title: Distinguish unavailable location fixes from missing permission
author: Justinrooks
date: 2026-11-02
branch: fix/location-unavailable-recovery
touches:
  - Sources/App/TodayTabView.swift
  - Sources/Features/Summary/SummaryStatus.swift
  - Sources/Features/Summary/SummaryView.swift
  - Tests/UnitTests/SummaryViewLoadingStateTests.swift
---

## Decided
Today must derive location failure copy and recovery actions from the current LocationSession reliability state. Authorized access with no usable fix offers Try Again through the existing manual refresh pipeline; denied access and reduced accuracy direct to Settings; undetermined authorization requests access. Core Location locationUnknown alone does not establish denied permission.

## Tried and ruled out
Do not fabricate coordinates or weaken fresh-evidence and consent gates to hide simulator location failures. Supplying a simulator location can restore delivery, but that is an environment intervention rather than an app guarantee.

## Watch out
The location recovery UI does not alter Storm Setup eligibility, same-key recovery scheduling, notification queue fixtures, or test-lane selection. Trail check flagged those existing learnings by shared words in the UI diff; the change preserves their contracts. Xcode MCP accessibility snapshots were stale during this verification while screenshots reflected the actual rendered screen, so a tap result alone was not accepted as end-to-end recovery evidence.
