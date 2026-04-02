# AGENTS.md — SkyAware Repository Guidance

## Purpose
- This file defines durable repository guidance for Codex and other agents working in this repo.
- Keep changes aligned with the existing architecture, coding patterns, and product goals.
- Prefer concrete repo-specific guidance over generic advice.

## Project Structure
- Root Xcode project lives at `SkyAware/SkyAware.xcodeproj`.
- App source lives in `SkyAware/Sources`.
- Shared assets and previews live in `SkyAware/Resources`.
- Config plist files live in `SkyAware/Config`.
- Tests live in:
  - `SkyAware/Tests/UnitTests`
  - `SkyAware/Tests/UITests`
- UI reference screenshots live in `docs/images`.
  - Use them to preserve visual consistency when building or revising UI.
  - Treat them as reference material, not as a source of exact truth unless the task explicitly says to match them.

## Build, Test, and Development Commands
- Build (Debug):
  `xcodebuild -project SkyAware/SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" build`
- Run unit + UI tests:
  `xcodebuild -project SkyAware/SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 17" test`
- Resolve Swift package dependencies:
  `xcodebuild -resolvePackageDependencies -project SkyAware/SkyAware.xcodeproj`
- Open in Xcode:
  `xed SkyAware`

## Platform and Architecture Constraints
- Swift 6+, iOS 18+ only.
- SwiftUI-first.
- Keep changes aligned with the existing app, server, and shared architecture boundaries in this repository.
- Avoid deprecated APIs and cross-platform assumptions unless the task explicitly requires them.
- Do not introduce cross-actor `ModelContext` misuse.

## Coding Conventions
- Indent with 4 spaces.
- Wrap lines around 120 columns when practical.
- Keep imports ordered and tidy.
- Naming:
  - Types use PascalCase.
  - Functions and properties use lowerCamelCase.
  - Test types end with `Tests` or `UITests`.

## Testing Expectations
- Use Swift Testing (`import Testing`).
- Do not hit live WeatherKit, NWS, or SPC feeds in tests.
- Stub or fake providers and network boundaries.
- When adding UI, include a smoke UI test for the main navigation or happy path when practical.
- Keep accessibility identifiers stable when they are used for UI testing.
- Prefer iPhone 17 or iPhone 17 Pro on iOS 26.4 for local simulator runs when available.
- If test execution produces an `.xcresult`, inspect it and report failures and coverage impact when available.
- Mirror production namespaces when adding tests.

## Definition of Done
- The change should compile unless the task explicitly requests draft-only output.
- Validate the smallest relevant scope before finishing.
- Prefer minimal diffs that solve the problem cleanly.
- Do not claim tests passed unless you ran them.
- Do not claim coverage changed unless you measured it.

## Commit and PR Guidance
- Commits use a single-line imperative summary prefixed with `- `.
  - Example: `- Fix bug preventing watches from loading`
- PRs should summarize intent, list user-visible changes, and note validation performed.
- For UI changes, include screenshots when the workflow calls for them.
- Call out risk areas and rollback considerations when they matter.

## Security and Configuration
- Keep private keys, WeatherKit credentials, and secrets out of the repo.
- Use local developer provisioning and per-user secure storage.
- Verify `Info.plist` changes and secrets templates before sharing builds.
- Do not log sensitive location or alert data in production code.
- Preserve the privacy-first handling of location, alert, and weather data across all repository changes.

## Related Guidance
- For code review tasks, follow `docs/code_review.md`.