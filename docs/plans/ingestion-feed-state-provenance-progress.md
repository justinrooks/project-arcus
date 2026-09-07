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
- Status: Implemented; awaiting review
- Handoff: Versioned actor-owned JSON sidecar is metadata-only and wired through Dependencies; transport propagation and scheduling remain deferred.

### [#444](https://github.com/justinrooks/project-arcus/issues/444) — Propagate Arcus transport provenance
- Status: Implemented; awaiting review
- Handoff: Arcus outcomes preserve live, 304 revalidation, local-cache, and error-fallback provenance. Error fallback cannot reconcile terminal alert payloads; accepted cache remains usable offline without reporting network success.

### [#445](https://github.com/justinrooks/project-arcus/issues/445) — Propagate SPC text transport provenance
- Status: Pending

### [#443](https://github.com/justinrooks/project-arcus/issues/443) — Add transport provenance to SPC map outcomes
- Status: Pending
- Handoff: Preserve staged convective/fire atomic acceptance.

## Verification Ledger

- [#441](https://github.com/justinrooks/project-arcus/issues/441): focused `FeedStateStoreTests` lane passed (5 tests) and Debug simulator build passed.
- [#444](https://github.com/justinrooks/project-arcus/issues/444): focused Arcus repository/provider lane passed (29 tests), full unit lane passed (1,119 tests), and Debug simulator build passed.
