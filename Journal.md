# Journal.md

## 1. The Big Picture
SkyAware is our weather awareness copilot for "what matters right now" at the user’s location. Instead of throwing a wall of meteorology at people, we distill it into fast, local signals: severe risk, active alerts, atmosphere context, and outlook summaries. Think of it like a flight instrument panel for neighborhood weather: compact, high-signal, and designed for quick decisions.

## 2. Architecture Deep Dive
The architecture works like a relay team:
- Data providers/repos grab and normalize upstream data (SPC, NWS, WeatherKit).
- Domain models/DTOs translate that into app-friendly language.
- Feature views render focused cards and rails.

A useful analogy: the kitchen line in a busy restaurant.
- Repos are prep stations (clean ingredients, consistent cuts).
- DTOs are plated components (ready to serve, no raw prep left).
- SwiftUI views are the pass window (presentation + timing).

This keeps heavy work away from rendering, so the UI can stay responsive while data updates in the background.

## 3. The Codebase Map
- `Sources/App`: app shells, navigation, tab wiring, screen orchestration.
- `Sources/Features`: user-facing screens/components by domain (Summary, Alerts, Map, Outlooks, Settings).
- `Sources/Models`: DTOs and domain models passed across boundaries.
- `Sources/Repos`: ingestion/query layers for weather products.
- `Sources/Utilities`: shared UI and helper extensions.
- `Tests`: unit and UI coverage.

If you’re debugging summary smoothness, start at:
1. `Sources/Features/Summary/SummaryView.swift`
2. `Sources/Features/Summary/ActiveAlertSummaryView.swift`
3. `Sources/Utilities/Extensions/ext+View.swift`
4. `Sources/Models/Meso/MdDTO.swift`

## 4. Tech Stack & Why
- SwiftUI: declarative UI composition and great iteration speed for feature cards.
- Swift Concurrency: keeps async fetch/update flows readable and cancellation-friendly.
- SwiftData + repository boundaries: isolates persistence concerns from UI behavior.
- iOS 26+ Liquid Glass (with fallbacks): native visual language and modern interaction affordances.

Why this combo works: we can iterate UI quickly, keep async state sane, and avoid coupling rendering to data-fetch complexity.

## 5. The Journey
### 2026-04-26 — Summary performance pass (choppiness/jank)
What we saw:
- Summary interactions felt less smooth than before, especially during loading/resolution state changes.

What we fixed:
- Stabilized `MdDTO` identity by deriving `id` from stable domain data (`number`) instead of generating `UUID()` at init time.
- Made placeholder animation opt-in instead of always-on, so loading redaction doesn’t animate broad subtrees by default.
- Added a non-glass outer card option and used it for `SummaryView` and `ActiveAlertSummaryView` cards that already contain multiple inner glass surfaces.
- Removed extra loading-state animation on the atmosphere rail transition in summary.

Why it matters:
- Stable identity lowers row teardown/rebuild churn during refresh.
- Fewer implicit animations reduce surprise layout motion and repeated recomposition.
- Flattening redundant glass layers lowers compositing cost while preserving Liquid Glass where it adds value.

Potential pitfall to remember:
- Glass effects are awesome, but stacking outer glass shells with inner glass-heavy content is a silent performance tax.

## 6. Engineer’s Wisdom
- Identity is performance: stable IDs are not optional in dynamic SwiftUI lists.
- Animate intentionally, not globally: implicit animation on helper modifiers can accidentally animate half the screen.
- Preserve visual systems, but budget for them: Liquid Glass should be grouped and deliberate, not duplicated at every nesting level.
- Keep UI state transitions predictable: stable roots + localized changes usually outperform branch-heavy tree swaps.

## 7. If I Were Starting Over...
- I’d define a “render budget” rule for summary cards from day one (one primary surface layer per section).
- I’d ship placeholder behavior with explicit animation flags from the start.
- I’d lock DTO identity strategy early and document it beside model definitions to prevent accidental churn regressions.
