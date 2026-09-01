# Ingestion UI Coherence Runbook

**Status:** Planned
**Applies to:** Home, Alerts, Outlook, Map, and cached-detail loading, transitions, refresh feedback, accessibility, and performance
**Project:** `SkyAware.xcodeproj`
**Parent epic:** [#422](https://github.com/justinrooks/project-arcus/issues/422)

## Related Docs

- `docs/SkyAware North Star Spec.md`
- `docs/plans/today-state-flow-runbook.md`
- `docs/plans/today-refresh-performance-runbook.md`
- `docs/plans/ingestion-reactive-consumers-runbook.md`

## Purpose

Create a calm, consistent cache-forward presentation: preserve useful content in place, show activity around it, and transition only accepted local replacements.

## Required Read Order

1. Active child issue.
2. This runbook.
3. `docs/plans/ingestion-ui-coherence-progress.md`.
4. North Star specification and only the named completed predecessor issue handoffs.

## Minimal Implementation Prompt

> Implement only the active UI slice using `GPT-5.6 Terra` with medium reasoning. Preserve accepted cache and stable identity, scope animations narrowly, honor Reduce Motion and accessibility, update previews/tests and the progress ledger, then stop.

## Target Contract

- Cache presence and refresh activity are independent dimensions.
- Cached content never disappears merely because refresh begins or fails.
- Authoritative empty, no cache, stale cache, location unavailable, and persistence unavailable remain distinct.
- Animations are local, value-scoped, interruptible, and optional; no root animation.
- Map and detail navigation remain usable during refresh.

## Guardrails

- Follow the North Star visual language; no broad redesign or Liquid Glass campaign.
- Treat completed issue #253 as historical Today motion cleanup; do not reopen it without regression evidence.
- Use `@Observable`/`@State` correctly, stable identity, native navigation, Dynamic Type, VoiceOver, Increase Contrast, and Reduce Motion.
- No live services in previews or UI fixtures.
- UI state derives from ingestion/cache contracts; views do not invent freshness semantics.

## Forbidden Scope

- Provider, repository, scheduler, persistence schema, notification, cadence, or server changes.
- Navigation-time networking, global animation framework, or speculative custom transitions.

## Execution Sequence

| Order | Work item | Preferred model |
|---:|---|---|
| 1 | [#453](https://github.com/justinrooks/project-arcus/issues/453) — Define cache-forward presentation vocabulary | `GPT-5.6 Terra / medium` |
| 2 | [#458](https://github.com/justinrooks/project-arcus/issues/458) — Introduce focused Home presentation-state derivation | `GPT-5.6 Terra / medium` |
| 3 | [#449](https://github.com/justinrooks/project-arcus/issues/449) — Stabilize Today cache-to-refresh transitions | `GPT-5.6 Terra / medium` |
| 4 | [#457](https://github.com/justinrooks/project-arcus/issues/457) — Unify refresh affordances and status feedback | `GPT-5.6 Terra / medium` |
| 5 | [#454](https://github.com/justinrooks/project-arcus/issues/454) — Normalize Alerts and Outlook loading states | `GPT-5.6 Terra / medium` |
| 6 | [#459](https://github.com/justinrooks/project-arcus/issues/459) — Refine map loading and accepted-generation transitions | `GPT-5.6 Terra / medium` |
| 7 | [#462](https://github.com/justinrooks/project-arcus/issues/462) — Codify restrained cross-feature motion | `GPT-5.6 Terra / medium` |
| 8 | [#463](https://github.com/justinrooks/project-arcus/issues/463) — Refine cached-detail navigation transitions | `GPT-5.6 Terra / medium` |
| 9 | [#461](https://github.com/justinrooks/project-arcus/issues/461) — Add a presentation-state preview matrix | `GPT-5.6 Terra / medium` |
| 10 | [#460](https://github.com/justinrooks/project-arcus/issues/460) — Validate accessibility, hitches, and transition behavior | `GPT-5.6 Terra / medium` |

## Verification Defaults

- Pure presentation-state tests and self-contained `#Preview` states.
- Focused UI/navigation lane with finalized non-zero `.xcresult` evidence.
- Representative light/dark, accessibility Dynamic Type, VoiceOver, Increase Contrast, and Reduce Motion checks.
- Final child captures physical-device Release SwiftUI and Animation Hitches evidence.
- Debug build and `git diff --check` after implementation.

## Terra / Medium Quality Bar

One screen/state transition behavior per issue, normally one to five production files. Prefer stable layout, narrow observation, opacity/transforms, and standard navigation. Stop before solving unstable ingestion semantics in UI code.

