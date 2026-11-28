# AGENTS.md — SkyAware App Guidance

Apply [repository guidance](../AGENTS.md) first. This file supplements it for work under `Sources/`.

Consult the [knowledge index](../docs/README.md) for product meaning, brand and design requirements, architectural context, and relevant validation evidence. Preserve the established severe-weather focus, glanceability, and privacy-first experience.

## App-Layer Boundaries

- Keep SwiftUI views thin; do not move parsing, orchestration, or domain decisions into view bodies or modifiers.
- Preserve feature UI, provider, repository, and utility responsibilities. Do not bypass the shared dependency container without a task-specific reason.
- Preserve provider and repository boundaries; do not duplicate fetching, parsing, persistence, or orchestration across layers.
- Keep raw provider, persistence, and framework details out of user-facing views when a DTO, helper, or view-model boundary is appropriate.
- Background refresh is coordinated centrally. Do not introduce competing orchestration in features or views.

## Background and Location

- Background scheduling is opportunistic, not guaranteed. Reschedule work on each run where required by the existing flow; keep handlers short, resumable, and side-effect aware.
- Do not assume a force-quit app will continue receiving background execution before relaunch.
- Location behavior depends on current authorization, accuracy, lifecycle state, and system policy.
- Changes affecting notifications, background work, or location must identify assumptions and validation gaps.

## Source Testing

Prefer deterministic behavioral tests at provider, repository, and feature seams. Follow the repository's test-lane, network isolation, accessibility identifier, and Xcode Cloud requirements.

Consult [shared SwiftData persistence guidance](https://github.com/justinrooks/Prompt_Fu/blob/main/codex/context/swiftdata-persistence.md) for framework practices. The following requirements remain explicit for SkyAware.

## SwiftData Persistence Guardrails
- Do not persist associated-value enums or arbitrary custom `Codable` domain types
  directly in an `@Model` without disk-backed SwiftData compatibility evidence.
- Prefer primitive persisted fields with a computed domain-model interface when the
  domain type has associated values, custom encoding, or evolving cases.
- JSONEncoder and JSONDecoder tests do not validate SwiftData compatibility.
- Any change to an `@Model`, a persisted `Codable` type, or its custom encoding must
  include real `ModelContainer` tests covering:
  - insert and save;
  - fetch and value reconstruction;
  - store close and reopen;
  - every enum case and relevant nil/default state;
  - compatibility with the previous production schema when the type already shipped.
- In-memory-only SwiftData tests are insufficient for schema, encoding, migration, or
  reopen compatibility.
- Schema changes require an explicit migration strategy or a documented, narrowly scoped
  cache-invalidation decision. Never delete a shared store as a routine workaround.
- Before accepting a persistence change, run its focused test suite repeatedly and the
  full unit lane at least once, then inspect the resulting `.xcresult` and crash artifacts.
