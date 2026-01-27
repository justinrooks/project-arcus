# Repository Guidelines

## Project Structure & Module Organization
- Root project lives in `SkyAware`; primary app targets are under `SkyAware.xcodeproj`.
- App source lives in `SkyAware/Sources` with feature areas (App, Features, Providers, Repos, Utilities, Views) grouped by responsibility; keep new code inside the closest matching module.
- Shared assets and previews sit in `SkyAware/Resources`; config plist lives in `SkyAware/Config`.
- Tests live in `SkyAware/Tests/UnitTests` and `SkyAware/Tests/UITests`; mirror production namespaces when adding coverage.

## Build, Test, and Development Commands
- Build (debug): `xcodebuild -project SkyAware/SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 15" build`
- Run unit + UI tests: `xcodebuild -project SkyAware/SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 15" test`
- SwiftPM fetch/resolve (if Xcode prompts): `xcodebuild -resolvePackageDependencies -project SkyAware/SkyAware.xcodeproj`
- Open in Xcode: `xed SkyAware`

## Coding Style & Naming Conventions
- Swift 6.0+, SwiftUI-first; prefer `struct` for views/models, `final class` for services.
- Indent with 4 spaces; wrap lines at ~120 cols; keep imports ordered (Foundation before project modules).
- Avoid force unwraps; use `guard` for early exits and explicit error handling.
- Minimize nesting when possible, especially within functions
- Naming: types in PascalCase, functions/properties in lowerCamelCase; test cases suffixed with `Tests`/`UITests`.

## Testing Guidelines
- Use Swift Testing (import Testing); place new specs alongside the feature they cover (mirror folder names under `UnitTests`/`UITests`).
- Prefer small, deterministic tests; stub network/providers and avoid hitting live WeatherKit or SPC feeds.
- When adding UI, include a smoke UI test for navigation/happy path; keep identifiers stable for accessibility and UITest hooks.
- Please use iPhone 17 or iPhone 17 Pro and iOS 26.2 when running unit tests
- Always analyze the .xcresult and report coverage after running tests

## Commit & Pull Request Guidelines
- Commits follow the current history: single-line, short, imperative summaries prefixed with `- ` (e.g., "- Fix bug preventing watches from loading").
- PRs should describe intent, list user-visible changes, and note testing performed (`xcodebuild … test`, manual device checks, screenshots for UI changes).
- Link related issues/roadmap items; call out risk areas (offline StormSafe mode, alert syncing) and rollback steps when applicable.

## Security & Configuration Tips
- Keep private keys and WeatherKit credentials out of the repo; rely on local developer provisioning profiles and per-user keychains.
- Verify Info.plist and any secrets templates before sharing builds; do not log sensitive location or alert data in production code.
