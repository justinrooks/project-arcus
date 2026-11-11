---
title: Complete presence cadence follows effective acknowledgment
author: Justinrooks
date: 2026-11-11
branch: issue-880
touches:
  - Sources/Infrastructure/Location/LocationSnapshotPusher.swift
  - Tests/UnitTests/LocationManagerTests.swift
  - docs/validation/location-enrichment-timing.md
---

## Decided
SkyAware #880 keeps unchanged-complete cadence in LocationSnapshotPusher. Compare against the latest effective complete acknowledgment per installation for 300 seconds; do not advance its clock on suppression. Unknown state after process restart conservatively allows first current delivery and recovers the durable outbox.

## Tried and ruled out
Timestamp-identical 15-second semantic dedupe permits equivalent newer complete captures. Historical per-signature acknowledgment lookup would incorrectly suppress A-to-B-to-A boundary returns. Persisting a separate acknowledgment authority is unnecessary for conservative restart behavior.

## Watch out
A prepared partial or different-geography transfer may reach V4 even if its acknowledgment is lost, so invalidate the complete baseline before transport. Preserve immediate H3-only delivery and same-capture completion. Real H3-only regression fixtures must derive H3 from their coordinates. Swift Testing parameterized function selectors require their signature; the containing suite provides verified coverage. Source-level Signal freshness thresholds are hours; deployment remains separate evidence.
