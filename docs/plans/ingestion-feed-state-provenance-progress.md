# Ingestion Feed-State and Provenance Progress

## Overview

Tracks the metadata-only durable feed sidecar and end-to-end transport provenance.

**Epic status:** Planned
**Primary GitHub epic:** [#426](https://github.com/justinrooks/project-arcus/issues/426)

## Global Decisions

- Avoid a SwiftData schema change in this campaign.
- Sidecar is actor-owned, versioned, primitive, bounded, and contains no feed payload.
- Canonical repositories remain authoritative.
- Generations advance only after accepted canonical persistence.
- All implementation uses `GPT-5.6 Terra / medium`.

## Current State

HTTP responses expose source, but Arcus/SPC provider contracts often discard it. Refresh state is in memory and conflates transport success with canonical acceptance. Existing durable location-context storage provides the preferred sidecar pattern.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#441](https://github.com/justinrooks/project-arcus/issues/441) — Add a versioned feed-state sidecar | Pending | Cache acceptance epic |
| 2 | [#444](https://github.com/justinrooks/project-arcus/issues/444) — Propagate Arcus transport provenance | Pending | 01 plus typed Arcus outcomes |
| 3 | [#445](https://github.com/justinrooks/project-arcus/issues/445) — Propagate SPC text transport provenance | Pending | 01 plus typed text outcomes |
| 4 | [#443](https://github.com/justinrooks/project-arcus/issues/443) — Add transport provenance to SPC map outcomes | Pending | 01 |

## Existing Code Map

- HTTP source: `Sources/Infrastructure/Networking/HTTPDataDownloader.swift`
- Durable sidecar precedent: `Sources/Infrastructure/Location/LocationSnapshotCache.swift`
- Arcus path: `Sources/Clients/ArcusClient.swift`, `Sources/Repos/AlertRepo.swift`, `Sources/Providers/ArcusAlertProvider.swift`
- SPC path: `Sources/Clients/SpcClient.swift`, SPC text repos, and `Sources/Providers/SPC/SpcProvider+Syncing.swift`

## Status Ledger

### [#441](https://github.com/justinrooks/project-arcus/issues/441) — Add a versioned feed-state sidecar
- Status: Pending
- Handoff: Cover corruption, newer versions, pruning, future dates, and concurrent updates.

### [#444](https://github.com/justinrooks/project-arcus/issues/444) — Propagate Arcus transport provenance
- Status: Pending

### [#445](https://github.com/justinrooks/project-arcus/issues/445) — Propagate SPC text transport provenance
- Status: Pending

### [#443](https://github.com/justinrooks/project-arcus/issues/443) — Add transport provenance to SPC map outcomes
- Status: Pending
- Handoff: Preserve staged convective/fire atomic acceptance.

## Verification Ledger

No implementation validation yet.

