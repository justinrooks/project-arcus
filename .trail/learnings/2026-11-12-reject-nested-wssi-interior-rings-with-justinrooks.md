---
title: Reject nested WSSI interior rings with boundary contacts
author: Justinrooks
date: 2026-11-12
branch: issue-835
touches:
  - Sources/Infrastructure/Parsing/GeoJSON/WSSIDecoder.swift
  - Tests/UnitTests/WSSIDecoderTests.swift
---

## Decided
Validate pairs of interior rings in both directions. Examine edge intervals between boundary contacts as well as vertices, because a nested ring can have every vertex on the containing ring's boundary.

## Tried and ruled out
Testing only vertices strictly inside the other hole accepts a diamond inscribed in a rectangular hole. Treating all boundary contact as invalid rejects legitimate NOAA exterior touches.

## Watch out
Preserve disjoint interior rings touching at a point and NOAA hole-to-exterior touches. Exercise the full captured NOAA pages when changing topology validation; compact fixtures alone omit most multipart geometry.
