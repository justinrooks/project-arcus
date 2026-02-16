# Journal.md

## 1) The Big Picture
SkyAware is like having a weather-savvy friend who keeps an eye on the sky for you. It watches official feeds (SPC/NWS), understands what they mean for *your* location, and taps you on the shoulder when things get spicy.

## 2) Architecture Deep Dive
Think of the app as a restaurant kitchen. The **Providers** are your ingredient suppliers (SPC/NWS feeds), the **Repos** are prep cooks who clean and store those ingredients, and the **BackgroundOrchestrator** is the head chef who decides what gets served (notifications) and when. SwiftUI is the front-of-house, and SwiftData is the pantry where prepared items live.

## 3) The Codebase Map
- `SkyAware/Sources/App`: app entry, dependency wiring, lifecycle.
- `SkyAware/Sources/Features`: UI + domain flows (alerts, maps, diagnostics, onboarding).
- `SkyAware/Sources/Providers` + `Repos`: data fetching and persistence logic.
- `SkyAware/Sources/Infrastructure`: parsing, scheduling, networking, location.
- `SkyAware/Tests`: unit and UI tests mirroring production namespaces.

## 4) Tech Stack & Why
- **SwiftUI**: fast iteration, modern iOS patterns, clean state-driven UI.
- **Swift Concurrency**: clear async flow without callback spaghetti.
- **SwiftData**: lightweight persistence integrated with Swift types.
- **BackgroundTasks**: best available mechanism for periodic background refresh.

## 5) The Journey
- **War story**: background scheduling felt “stuck” when a pending task existed. The fix is to replace pending requests when a tighter cadence is needed so the system can try sooner.
- **Bug squash**: a pending refresh at a later time used to block scheduling a new earlier run. We now inspect the pending `earliestBeginDate`, replace only when the new request is materially earlier, and restore the old schedule if replacement submission fails.
- **Aha!**: even tiny scheduling policy changes can be nullified if the pending request isn’t updated.
- **Pitfall**: background work is opportunistic; force-quit means no background runs until relaunch.
- **War story (Map edition)**: the map kept “fidgeting” because every location update rebuilt overlays and re-centered the viewport. It looked like the app was fighting the user.
- **Bug squash**: map layer fetches were sequential and all-or-nothing. If one feed failed, the whole map looked empty. We moved to parallel fetches with per-source error handling so successful layers still render.
- **Aha!**: identity-based overlay diffs only work when the same overlay instances survive render cycles. Caching the active polygon set in `MapView` and syncing overlays by geometry signature stopped unnecessary churn.
- **Bug squash**: categorical risk shading could hide higher-risk pockets under lower-risk overlays. We now explicitly render in severity order (`TSTM -> MRGL -> SLGT -> ENH -> MDT -> HIGH`) so the dangerous areas stay visually on top.
- **Bug squash (NWS client)**: we found an error-domain mix-up where NWS request failures were throwing `SpcError.networkError` (wrong subsystem). We moved to typed `NwsError` failures (`networkError(status:)`, `missingData`) so logs and call-site handling stay honest.
- **Aha! (URL building)**: hand-built URL strings work until they don’t. Switching NWS endpoints to `URLComponents` eliminated brittle query concatenation and made point-parameter encoding deterministic.
- **Resilience upgrade**: we preserved HTTP response headers in the shared downloader so clients can finally react to upstream hints like `Retry-After` instead of treating every non-200 the same.
- **Privacy + observability tradeoff**: we tightened NWS logging by hashing coordinate logs while still emitting structured endpoint/status fields, so diagnostics stay useful without leaking precise location traces.
- **Aha! (cancellation semantics)**: swallowing `Task.sleep` cancellation during retries quietly fights structured concurrency. Letting cancellation bubble keeps networking cooperative with SwiftUI task lifecycles.
- **Consistency cleanup (SPC vs NWS)**: SPC and NWS now speak the same language at the client boundary (`async throws -> Data` with status-aware mapping). That removed misleading “nil means no data” branches and made error handling deterministic in repos/providers.
- **Side-effect containment**: downloader-level `Last-Modified` persistence moved behind an injected observer instead of hidden global writes. The network pipe is now transport-focused, and policy hooks are explicit at composition time.
- **Architecture checkpoint**: we split the map feature into a screen (`MapScreenView`), a render canvas (`MapCanvasView`), and a geometry mapper (`MapPolygonMapper`). The view now orchestrates state and async work, while geometry conversion has one home.
- **Pitfall**: when adding new Swift Testing files, verify target membership immediately. A misplaced file can compile into the app target and fail on `import Testing`.

## 6) Engineer's Wisdom
- Keep background handlers short and predictable; timeouts are your friend.
- Make policy decisions explicit (cadence, time budgets) and centralize them for testability.
- Prefer dependency injection so you can test scheduling logic without touching real OS APIs.
- In map UIs, “follow user location” should be explicit state, not a side effect of every position update.
- When multiple upstream data sources feed one screen, degrade gracefully: fail one panel, not the whole page.
- If one SwiftUI file starts doing networking, UI composition, and geometry transformation, split it before it becomes a kitchen-sink file.

## 7) If I Were Starting Over...
- I’d design background scheduling as a policy engine from day one, with clear rules for “tighten/relax cadence” and easy unit test hooks.
- I’d add a small diagnostics surface in-app early so it’s obvious when background work is being throttled or suppressed.
- I’d separate map data transforms into a dedicated mapper layer up front so polygon construction and caching are deterministic and testable outside SwiftUI.
