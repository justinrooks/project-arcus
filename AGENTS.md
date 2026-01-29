# AGENTS.md — SkyAware Repository + PR Review Guidelines

## Project Structure & Module Organization
- Root project lives in `SkyAware`; primary app targets are under `SkyAware.xcodeproj`.
- App source lives in `SkyAware/Sources` with feature areas (App, Features, Providers, Repos, Utilities, Views) grouped by responsibility; keep new code inside the closest matching module.
- Shared assets and previews sit in `SkyAware/Resources`; config plist lives in `SkyAware/Config`.
- Tests live in `SkyAware/Tests/UnitTests` and `SkyAware/Tests/UITests`; mirror production namespaces when adding coverage.

## Build, Test, and Development Commands
- Build (debug):
  `xcodebuild -project SkyAware/SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 15" build`
- Run unit + UI tests:
  `xcodebuild -project SkyAware/SkyAware.xcodeproj -scheme SkyAware -destination "platform=iOS Simulator,name=iPhone 15" test`
- SwiftPM fetch/resolve (if Xcode prompts):
  `xcodebuild -resolvePackageDependencies -project SkyAware/SkyAware.xcodeproj`
- Open in Xcode:
  `xed SkyAware`

## Coding Style & Naming Conventions
- Swift 6+, iOS 18+ only. SwiftUI-first.
- Prefer `struct` for views/models; `final class` for services.
- Indent with 4 spaces; wrap lines at ~120 cols; keep imports ordered (Foundation before project modules).
- Avoid force unwraps; use `guard` for early exits and explicit error handling.
- Minimize nesting, especially within functions.
- Naming: types in PascalCase, functions/properties in lowerCamelCase; test cases suffixed with `Tests`/`UITests`.

## Testing Guidelines
- Use Swift Testing (`import Testing`); place new specs alongside the feature they cover (mirror folder names under `UnitTests`/`UITests`).
- Prefer small, deterministic tests; stub network/providers and avoid hitting live WeatherKit, NWS, or SPC feeds.
- When adding UI, include a smoke UI test for navigation/happy path; keep identifiers stable for accessibility and UITest hooks.
- Coverage goal: 75%+ when reasonable for the change.
- Prefer iPhone 17 / iPhone 17 Pro on iOS 26.2 when running tests locally.
- When tests are run, analyze the `.xcresult` and report coverage deltas.

## Commit & Pull Request Guidelines
- Commits: single-line, short, imperative summaries prefixed with `- ` (e.g., `- Fix bug preventing watches from loading`).
- PRs should describe intent, list user-visible changes, and note testing performed (xcodebuild test, manual device checks, screenshots for UI changes).
- Link related issues/roadmap items; call out risk areas (offline StormSafe mode, alert syncing) and rollback steps when applicable.

## Security & Configuration Tips
- Keep private keys and WeatherKit credentials out of the repo; rely on local developer provisioning profiles and per-user keychains.
- Verify Info.plist and any secrets templates before sharing builds.
- Do not log sensitive location or alert data in production code.

---

# Code Review Guidelines (Swift / SwiftUI / SwiftData — iOS 18+, Swift 6)

## Scope
- Review the provided change(s) with a bias toward **correctness**, **clarity**, **performance**, **architecture**, and **testability**.
- Assume **Swift 6 strict concurrency** is enabled (Sendable, actor isolation, MainActor correctness).
- Prefer modern Apple idioms: Observation (`@Observable`), `NavigationStack`, `#Preview`, `async/await`, SwiftData (`@Model`, `ModelContext`, `ModelActor`).
- Avoid deprecated APIs and cross-platform assumptions.

## Non-negotiables (treat as Must-Fix / P0/P1)
Flag as **Critical** if any apply:
- Does not compile / obvious correctness bug / data loss.
- Concurrency violation (UI work off MainActor, cross-actor `ModelContext` misuse, non-Sendable sharing, race risk).
- Security/privacy regression (secrets in code, sensitive data logged, unsafe persistence).
- Unbounded work in SwiftUI rendering (heavy work in `body`, runaway tasks, repeated network/persistence on re-render).

## Review Checklist (keep it specific to the diff)
1. **Correctness & Concurrency**
   - MainActor boundaries correct; no actor hops hiding in helpers.
   - Async cancellation respected; no leaked Tasks.
2. **Readability & Organization**
   - Names precise; functions small and single-purpose.
   - Views stay declarative; business logic lives in VM/service/provider/repo.
   - DRY: avoid duplicating formatters, mappers, persistence helpers, view components.
3. **SwiftUI Performance**
   - Avoid heavy computation in `body`; prevent unnecessary invalidation.
   - Stable identity for lists; state ownership (`@State`, `@Observable`, environment) is correct.
4. **SwiftData Quality**
   - `@Model` design is sane (ids, relationships, delete rules).
   - Fetching is efficient/scoped; avoid accidental N+1 patterns in views.
5. **Error Handling & Resilience**
   - Errors not swallowed; surfaced/logged appropriately.
   - Retries/backoff/timeouts explicit where relevant.
6. **Testability**
   - DI seams exist for time/random/network/persistence.
   - Add/adjust unit tests and #Previews with deterministic sample data when applicable.
7. **Accessibility (lightweight)**
   - Labels/hints where needed; tap targets and Dynamic Type not obviously broken.

## Required Review Output Format
1. **Summary (2–4 sentences):** what’s solid, what’s risky.
2. **Findings by Severity:**
   - **Critical** – correctness/concurrency/data loss/security
   - **High** – performance/architecture/testability blockers
   - **Medium** – readability/organization improvements
   - **Low/Nit** – polish, naming, minor style
3. **Actionable Fixes (ordered):** smallest viable steps, minimal-diff bias.
4. **Targeted Patches:** small, compilable snippets/diffs demonstrating fixes.
5. **Test Hooks:** where/how to inject deps + 1–2 example unit/snapshot test ideas.
6. **Re-review Checklist:** short list to validate after changes.

## Clarifying Questions (only if blocking)
- Ask at most **3** concise questions **only** when the decision changes correctness/architecture (threading model, persistence lifetime, feature intent).
- Otherwise proceed with best-practice defaults and label uncertain items as **Potential Issue** with the assumption needed to confirm.

## Tone
- Direct, concrete, actionable. Avoid generic advice. Do not invent problems.