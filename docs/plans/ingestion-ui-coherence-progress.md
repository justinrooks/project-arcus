# Ingestion UI Coherence Progress

## Overview

Tracks a consistent cache-forward loading, refresh, transition, accessibility, and evidence campaign across Home, Alerts, Outlook, Map, and details.

**Epic status:** Planned
**Primary GitHub epic:** [#422](https://github.com/justinrooks/project-arcus/issues/422)

## Global Decisions

- Preserve useful cached content during every attempt and failure.
- Activity is shown around content; it does not replace content.
- UI derives truth from accepted cache contracts.
- Motion is local, value-scoped, optional, and Reduce Motion aware.
- Completed Today issue #253 is precedent, not scope to redo.
- No Liquid Glass or global animation-framework campaign.
- All implementation uses `GPT-5.6 Terra / medium`.

## Current State

Home combines SwiftData and pipeline state, while feature tabs use differing loading, empty, stale, and failure semantics. Map can clear or lag during reload. Existing Today motion cleanup is narrower than the desired cross-feature contract.

## Issue Sequence

| Order | Issue | Status | Dependency |
|---:|---|---|---|
| 1 | [#453](https://github.com/justinrooks/project-arcus/issues/453) — Define cache-forward presentation vocabulary | Pending | Cache acceptance contract |
| 2 | [#458](https://github.com/justinrooks/project-arcus/issues/458) — Introduce focused Home presentation-state derivation | Pending | 01 and persistence gating |
| 3 | [#449](https://github.com/justinrooks/project-arcus/issues/449) — Stabilize Today cache-to-refresh transitions | Pending | 02 and keyed Home observation |
| 4 | [#457](https://github.com/justinrooks/project-arcus/issues/457) — Unify refresh affordances and status feedback | Pending | 01 |
| 5 | [#454](https://github.com/justinrooks/project-arcus/issues/454) — Normalize Alerts and Outlook loading states | Pending | 01 and typed feed outcomes |
| 6 | [#459](https://github.com/justinrooks/project-arcus/issues/459) — Refine map loading and accepted-generation transitions | Pending | Reactive map invalidation |
| 7 | [#462](https://github.com/justinrooks/project-arcus/issues/462) — Codify restrained cross-feature motion | Pending | 01; may begin early |
| 8 | [#463](https://github.com/justinrooks/project-arcus/issues/463) — Refine cached-detail navigation transitions | Pending | Reactive detail decision |
| 9 | [#461](https://github.com/justinrooks/project-arcus/issues/461) — Add a presentation-state preview matrix | Pending | 02–08 incrementally |
| 10 | [#460](https://github.com/justinrooks/project-arcus/issues/460) — Validate accessibility, hitches, and transition behavior | Pending | Implemented UI scope |

## Existing Code Map

- Home orchestration/presentation: `Sources/App/HomeView.swift`, `Sources/App/HomeRefreshPipeline.swift`
- Today composition: `Sources/App/TodayTabView.swift`, Summary feature views
- Alerts/Outlook: corresponding feature views and presentation-state types
- Map: `Sources/Features/Map/MapScreenView.swift`, `Sources/Features/Map/MapFeatureModel.swift`
- Product guidance: `docs/SkyAware North Star Spec.md`

## Status Ledger

### [#453](https://github.com/justinrooks/project-arcus/issues/453) — Define cache-forward presentation vocabulary
- Status: Pending

### [#458](https://github.com/justinrooks/project-arcus/issues/458) — Introduce focused Home presentation-state derivation
- Status: Pending

### [#449](https://github.com/justinrooks/project-arcus/issues/449) — Stabilize Today cache-to-refresh transitions
- Status: Pending
- Handoff: Do not duplicate completed issue #253 without regression evidence.

### [#457](https://github.com/justinrooks/project-arcus/issues/457) — Unify refresh affordances and status feedback
- Status: Pending

### [#454](https://github.com/justinrooks/project-arcus/issues/454) — Normalize Alerts and Outlook loading states
- Status: Pending

### [#459](https://github.com/justinrooks/project-arcus/issues/459) — Refine map loading and accepted-generation transitions
- Status: Pending

### [#462](https://github.com/justinrooks/project-arcus/issues/462) — Codify restrained cross-feature motion
- Status: Pending

### [#463](https://github.com/justinrooks/project-arcus/issues/463) — Refine cached-detail navigation transitions
- Status: Pending

### [#461](https://github.com/justinrooks/project-arcus/issues/461) — Add a presentation-state preview matrix
- Status: Pending

### [#460](https://github.com/justinrooks/project-arcus/issues/460) — Validate accessibility, hitches, and transition behavior
- Status: Pending validation gate

## Verification Ledger

No implementation validation yet.

