# AGENTS.md — SkyAware App Guidance

## Purpose
- This file provides app-specific guidance for agents working in `SkyAware/` and its subdirectories.
- Apply the repo-level guidance in `../AGENTS.md` first, then use this file for rules that are specific to the iOS app layer.
- Prefer concrete implementation guidance over high-level project summary.

## Product and UX Intent
- SkyAware is a severe-weather awareness app, not a general forecast app.
- Prioritize severe-weather relevance, glanceability, and concise communication over broad weather surface area.
- Preserve privacy-first behavior in location-aware and alert-driven user flows.
- Keep user-facing behavior calm, clear, and utility-focused.

## App-Layer Architecture Rules
- Keep SwiftUI views thin; do not move parsing, orchestration, or domain decision-making into view bodies or view modifiers.
- Preserve clear separation between feature UI, providers, repositories, and utilities.
- Do not bypass the shared dependency container from feature code without a task-specific reason.
- Preserve provider and repository boundaries; do not duplicate data-fetching, parsing, persistence, or orchestration logic across layers.
- Do not expose raw provider, persistence, or framework details directly to user-facing views when a DTO, helper, or view-model boundary is more appropriate.

## Background and Location Behavior
- Background scheduling is opportunistic, not guaranteed.
- Reschedule background work on each run when that is part of the existing flow.
- Keep background handlers short, resumable, and side-effect aware.
- Do not assume a force-quit app will continue to receive background execution until relaunched.
- Treat location-driven flows as dependent on current authorization, accuracy, app lifecycle state, and system policy.

## Testing Guidance
- Prefer deterministic tests around provider, repository, and feature seams.
- Avoid live SPC, NWS, WeatherKit, or other network-backed dependencies in tests.
- When changing user-facing flows, favor focused tests on behavior rather than implementation details.
- Keep accessibility identifiers stable when UI tests depend on them.

## Local Notes and Gotchas
- Background refresh is coordinated centrally; do not reintroduce competing orchestration paths in features or views.
- Location-driven behavior can change based on authorization state, accuracy, and app lifecycle.
- Changes that affect notifications, background work, or location should call out assumptions and validation gaps clearly.

## Instruction Precedence
- This file supplements the repo-level `../AGENTS.md` with the more specific rules for code under `SkyAware/`.