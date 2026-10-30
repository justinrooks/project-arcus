---
title: Preserve failed location acquisition when pending fix is a no-op
author: Justinrooks
date: 2026-10-30
branch: issue-828
touches:
  - Sources/Infrastructure/Location/LocationSession.swift
  - Tests/UnitTests/LocationManagerTests.swift
---

## Decided
A failed location resolution remains failed when a queued same-cell fix cannot start a replacement. Keep an inactive pending fix for foreground replay while publishing the actual failure.
## Tried and ruled out
Treating every pending snapshot as a successful handoff can leave the session ready after a failed fresh acquisition even though no replacement started.
## Watch out
Keep successful same-cell publication and upload paths unchanged, and verify generation fencing. Trail check reported lexical matches to unrelated learnings and to the existing same-key recovery implementation; that implementation uses an interruption revision rather than relying on the refresh key alone.
