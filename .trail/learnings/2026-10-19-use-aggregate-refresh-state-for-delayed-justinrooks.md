---
title: Use aggregate refresh state for delayed review prompts
author: Justinrooks
date: 2026-10-19
branch: issue-614
touches:
  - Sources/App/HomeView.swift
  - Tests/UnitTests/AppReviewRequestLedgerTests.swift
---

## Decided
Delayed app review requests must recheck HomeRefreshPipeline.isRefreshInFlight before firing so one completion cannot hide overlapping foreground work.

## Tried and ruled out
Using isManualRefreshInFlight for the delayed guard is insufficient because each manual completion clears that single flag while another refresh may remain active.

## Watch out
Cancel pending requests when a new manual refresh starts, then recheck aggregate refresh state after the delay. The successful-refresh event is separate from Map pending-operation priority; unit-test target membership and the repository unit lane remain intentional.
