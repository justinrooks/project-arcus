---
title: Keep weather awareness shortcuts on accepted snapshots
author: Justinrooks
date: 2026-10-20
branch: issue-750
---

## Decided
- A Siri or Shortcuts weather-awareness action should read the accepted snapshot through the existing result/store boundary and format freshness explicitly. Do not trigger refresh or location access from the intent.
- Only a current accepted empty alert assessment supports a quiet-alert claim; stale retained warnings must be described as stale, and current warning/watch context leads the response.

## Tried and ruled out
- None.

## Watch out
- Unit tests can verify formatter and freshness behavior, but they cannot prove App Shortcut discovery or spoken Siri invocation. Record that system smoke separately.
