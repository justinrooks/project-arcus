# AGENTS.md — SkyAware (Project Memory)

## Project Overview & Purpose
SkyAware is an iOS app that keeps users aware of severe weather (SPC outlooks, mesoscale discussions, watches, warnings) and sends notifications tuned to their current location and risk context.

## Key Architecture Decisions
- SwiftUI-first UI; async/await for data flow and background work.
- Background refresh is orchestrated by a BackgroundOrchestrator that syncs providers, evaluates risk, and triggers notifications.
- Dependencies are centralized in a DI container (Dependencies) to keep features testable and decoupled.
- SwiftData repositories wrap persistence and parsing per domain.

## Conventions & Patterns
- Source is organized by responsibility under `SkyAware/Sources` (App, Features, Providers, Repos, Utilities, Views).
- Use `struct` for views/models; `final class` for services.
- Prefer `guard` and explicit error handling; avoid force unwraps.
- Tests live in `SkyAware/Tests/UnitTests` and `SkyAware/Tests/UITests` and mirror production namespaces.

## Build / Run
- Build: `xcodebuild -project SkyAware/SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 15" build`
- Test:  `xcodebuild -project SkyAware/SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 15" test`
- Open:  `xed SkyAware`

## Quirks / Gotchas
- Background scheduling is opportunistic; reschedule every run and keep handlers short.
- Location-driven behavior depends on authorization state; force-quit suppresses background execution until relaunch.

## Notes
- This is a supplemental AGENTS.md. There is a repo level one located one level higher in the tree at ../AGENTS.MD.l
