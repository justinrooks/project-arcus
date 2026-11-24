---
title: Reject older dated Day 1 SPC revisions before geometry changes
author: Justinrooks
date: 2026-11-24
branch: issue-927
touches:
  - Sources/Providers/SPC/SpcProvider+Syncing.swift
  - Sources/Repos/SpcMapBatchPersistenceRepo.swift
  - Tests/UnitTests/SpcProviderSyncMapProductsTests.swift
---

## Decided
Compare issuance and validity start against the current dated Day 1 revision inside the transaction lock. Either date moving backward rejects the convective candidate before any geometry changes. The same check covers dated all-clear.

## Tried and ruled out
Serialized writes only ordered arrivals. An older effective payload could arrive last and move Home back a forecast even while Map still selected the newer categorical slice.

## Watch out
An undated empty keeps its established acceptance semantics. The stale-candidate result updates attempt diagnostics while retaining the source UUID, acceptance timestamp, and feed generation.
