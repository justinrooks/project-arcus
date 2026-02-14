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

## 6) Engineer's Wisdom
- Keep background handlers short and predictable; timeouts are your friend.
- Make policy decisions explicit (cadence, time budgets) and centralize them for testability.
- Prefer dependency injection so you can test scheduling logic without touching real OS APIs.

## 7) If I Were Starting Over...
- I’d design background scheduling as a policy engine from day one, with clear rules for “tighten/relax cadence” and easy unit test hooks.
- I’d add a small diagnostics surface in-app early so it’s obvious when background work is being throttled or suppressed.
