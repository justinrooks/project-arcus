---
title: Gate Storm Setup terminal status on current eligibility
author: Justinrooks
date: 2026-10-27
branch: issue-792
touches:
  - Sources/Features/StormSetup/StormSetupPresentation.swift
  - Tests/UnitTests/HomeRefreshPipelineTests.swift
  - Tests/UnitTests/StormSetupPresentationTests.swift
---

## Decided
Storm Setup summary selection preserves fresh displayable/suppressed guidance and active analyzing first, then checks current fetch eligibility before interpreting retained terminal outcomes. Current ineligible inputs select Analysis not needed even when the pipeline retains a prior failure across skipped same-location refreshes.

## Tried and ruled out
Giving retained failure, timeout, H3 mismatch, or unusable success unconditional precedence leaves Storm Setup unavailable after current risk, alert, and meso eligibility clears. Clearing the stored outcome merely to fix rendering would also erase legitimate same-location backoff history.

## Watch out
Exercise the sequence eligible failure or timeout -> skipped while still eligible -> skipped after same-location eligibility clears. The first two states remain unavailable; the last becomes analysis not needed. Keep active requests and fresh-cache guidance ahead of the eligibility gate.
