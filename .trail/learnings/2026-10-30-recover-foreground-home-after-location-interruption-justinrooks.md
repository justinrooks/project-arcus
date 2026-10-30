---
title: Recover foreground Home after location interruption
author: Justinrooks
date: 2026-10-30
branch: issue-828
touches:
  - Sources/App/HomeRefreshPipeline.swift
  - Sources/App/HomeView.swift
  - Sources/Infrastructure/Location/LocationSession.swift
  - Tests/UnitTests/HomeRefreshPipelineTests.swift
  - Tests/UnitTests/LocationManagerTests.swift
---

## Decided
Foreground location recovery must preserve accepted Home state, distinguish same-cell recovery from ordinary updates, and coalesce newer fixes across resolution and publication.
## Tried and ruled out
Treating the Home refresh key alone as the recovery signal suppresses a restored location with the same key; relying on a transient nil observation can miss coalesced transitions.
## Watch out
Preserve generation and authorization fences, retain pending fixes across foreground transitions, and avoid dropping successful uploads when a pending fix is already satisfied. The 2026-10-30 trail check reported lexical conflicts against unrelated testing, Storm Setup, and enrollment learnings; the authorized project-file commit is semantically identical after plist parsing and the new tests do not alter those contracts.
