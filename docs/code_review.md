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