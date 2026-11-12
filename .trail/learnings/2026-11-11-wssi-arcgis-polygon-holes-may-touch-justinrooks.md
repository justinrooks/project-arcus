---
title: WSSI ArcGIS polygon holes may touch their exterior
author: Justinrooks
date: 2026-11-11
branch: issue-835
touches:
  - SkyAware.xcodeproj/project.pbxproj
  - Sources/Infrastructure/Parsing/GeoJSON/WSSIDecoder.swift
  - Tests/UnitTests/WSSIDecoderTests.swift
---

## Decided
WSSI ArcGIS captures use response-level WGS84 metadata and source identifiers such as SNOW_LOAD_Day_1 and WSSI_OVERALL_Days_1_3. A hole can begin at a vertex shared with its exterior; preserve that point-touch when associating rings.

## Tried and ruled out
A boundary-exclusive test of the first interior-ring point rejects real Overall Day 2 and Days 1–3 NOAA responses. Checking only a hole edge midpoint also misses excursions through vertices of a concave exterior.

## Watch out
The captured source has no positive rows for ice Day 1 or Day 3; empty results do not establish publication identity. Validate whole captured geometries as well as compact metadata fixtures, and distinguish simulator tests from device performance evidence.
