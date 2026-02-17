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
- **War story (StormRisk colors)**: we had SPC `stroke`/`fill` values in storage, but the map still painted by parsing polygon titles like “SLGT” and “MDT.” It was like buying paint and then ignoring the color labels.
- **Bug squash**: categorical polygons now carry StormRisk style metadata into `MKPolygon` overlays, and the renderer consumes SPC colors first, then falls back to legacy style parsing only when needed.
- **Aha! (overlay identity)**: style-only updates can be invisible if your overlay diff key only hashes geometry. Including subtitle/style metadata in the map signature made color refreshes deterministic instead of “why didn’t it repaint?”
- **Follow-through (Fire layer)**: we applied the same style-metadata pipeline to Fire Risk polygons, so fire overlays now honor upstream SPC `stroke`/`fill` instead of defaulting to generic fire colors.
- **Final map style pass (Severe layer)**: hail, wind, and tornado overlays now carry SPC `stroke`/`fill` from persistence into map polygons, so severe shading follows upstream styling instead of only title/probability heuristics.
- **Legend parity fix**: the severe legend now consumes the same SPC `stroke`/`fill` metadata as the map polygons, and legend style resolution uses map alpha so chips match on-map overlays exactly instead of rendering a denser preview tint.
- **Testing hardening**: we added focused tests to guard severe style metadata propagation and map-vs-legend alpha/color parity, because UI color regressions are easy to miss in manual checks and expensive to debug later.
- **War story (Startup echo bug)**: on launch we saw logs like `Updated 1 wind risk feature` multiple times, which looked like a haunted refresh loop.
- **Bug squash (Single owner + coalescing)**: startup map sync was being kicked off in both `SkyAwareApp` and `HomeView`. We removed the app-level startup map sync and added an in-provider coalescing guard/cooldown so overlapping `syncMapProducts()` calls join the same work instead of replaying the full SPC map pipeline.
- **Aha!**: duplicate startup work often comes from lifecycle fan-out, not one bad loop. The clean fix is ownership clarity first, then a defensive coalescing layer at the provider boundary.
- **Bug squash (time-traveling tests)**: `WatchRepo.active(county:zone:fireZone:on:)` accepted a clock value but silently filtered with `.now`. Tests that pinned `on` to a fixture date were effectively arguing with wall-clock time. We now thread the passed `on` date into the fetch descriptor so active/expired/upcoming watch filtering is deterministic in tests and production call sites that provide a custom date.
- **War story (Liquid Glass migration)**: the first pass looked shiny but inconsistent because every card/view invented its own blur recipe. It felt like a weather dashboard assembled from five different apps.
- **Bug squash (API sharp edges)**: the iOS 26-only `glassEffect` APIs compiled fine once we gated every usage with `#available(iOS 26, *)`, but one seemingly harmless style helper (`LinearGradient.stops`) broke compilation in this project setup. We replaced that with explicit per-layer tint tokens.
- **Aha! (design system > one-off polish)**: moving glass/fallback behavior into shared view extensions (`skyAwareSurface`, `skyAwareChip`, `skyAwareGlassButtonStyle`) gave us consistent depth and reduced copy/paste modifier soup.
- **Pitfall**: test + coverage workflows can fail if you diff against a failed `.xcresult` bundle. Always diff against two successful results, or report the current coverage snapshot only.
- **Bug squash (row shadow halos)**: list rows in Alerts/Outlooks looked fuzzy because `cardRowBackground` inherited heavy card shadows plus negative row insets. We introduced row-specific shadow defaults (tiny radius/opacity) and sane positive insets so cards look crisp instead of “double-shadowed.”
- **Aha! (interaction hygiene)**: replacing row `onTapGesture` with `Button` + `.buttonStyle(.plain)` gave cleaner accessibility semantics and more predictable tap behavior without changing visuals.
- **Refactor pass**: we removed nested `NavigationStack`s in diagnostics screens and trimmed dead/unused helpers in view files. Result: cleaner view trees, fewer side effects, easier reasoning.
- **Bug squash (Map layer button hit-testing)**: the map layer picker button sometimes needed multiple taps. Root cause was overlay stacking: a full-frame legend container sat above the button and could steal taps in edge cases. Fix was to move the button to a higher z-index and mark the legend overlay as non-interactive with `.allowsHitTesting(false)`.
- **UI redesign pass (consistency first)**: we shifted from mixed system list/form chrome into a unified glass-card rhythm across Summary, Alerts, Outlooks, Map overlays, and Settings. The app now uses one atmospheric background language, one card/row surface language, and shared spacing/section patterns so screens feel like one product rather than independent modules.
- **Bug squash (row shadow halos, round two)**: the awkward “fuzzy card” edges in Alerts/Outlooks were mostly list-row composition artifacts. Moving those screens to custom `ScrollView` + card sections removed row-shadow stacking and made tap targets visually crisp.
- **Aha! (design system leverage)**: the highest-impact visual improvements came from changing shared primitives (`AppBackground`, `skyAwareSurface`, `cardRowBackground`) before touching feature views. Once primitives were right, per-screen cleanup became mostly structure and content hierarchy.
- **Pitfall**: strong backgrounds in child views can quietly nullify root-level branding/atmosphere. Using transparent feature backgrounds where safe lets app-level visuals do their job without fighting each tab.
- **Bug squash (scroll layering + taps)**: Alerts, Outlooks, and Settings showed a ghosted top region on first load and occasional missed taps. We moved pull-to-refresh ownership into each screen’s own `ScrollView`, switched key content stacks to `LazyVStack`, tightened nav title display mode where needed, and marked decorative glass border overlays as non-hit-testable so gestures land on intended controls.
- **Bug squash (small tap zones on rows)**: in custom card lists, taps initially favored text/icon pixels instead of the entire row. We expanded row hit regions with full-width frames plus explicit `.contentShape(Rectangle())` so Alerts, Outlooks, and Settings navigation rows all respond across the whole surface.
- **Consistency pass (detail screens)**: we aligned Convective Outlook details to the same composition language as Watch details: strong header card using shared SPC header/footer components, metadata chips, and monospaced detail sections. The result feels like one design system instead of separate feature implementations.
- **War story (performance paper cuts)**: diagnostics looked fine in isolation, but the app still felt busy because several tiny inefficiencies were stacking up: formatter churn, over-eager task triggers, render-time sorting/filtering, and geometry feedback updates.
- **Bug squash (refresh throttle policy)**: summary refreshes now gate on both elapsed time and distance moved, so the app avoids repeated full refresh cycles for tiny location jitter while still supporting explicit force refresh.
- **Bug squash (formatter hotspots)**: date and relative-date formatters now use thread-local caches instead of being recreated repeatedly in hot UI paths, reducing allocation churn during scrolling and diagnostics rendering.
- **Bug squash (log viewer load fan-out)**: we replaced multiple competing `.task(id:)` reload triggers with a single initial load plus focused `onChange` triggers, and we cancel in-flight work on disappear to avoid stale overlapping loads.
- **Bug squash (map render-path work)**: severe legend data is now derived during state recomputation rather than filtered/sorted inside the render path, so map-related body recomputation stays lighter.
- **Bug squash (sheet height jitter)**: dynamic sheet height updates now respect a tolerance threshold, preventing tiny geometry fluctuations from causing unnecessary invalidation loops.
- **Aha!**: performance wins in SwiftUI are often architectural hygiene, not one magic optimization. Moving work out of `body` and into explicit state transitions is usually the highest ROI change.
- **Pitfall**: coverage comparisons are noisy if executable-line counts changed between runs. Track both percentage and covered/executable line totals to avoid false confidence (or false panic).
- **Legend parity fix (Fire layer)**: the fire legend used to show a single generic "Fire" chip, which hid what SPC was actually saying. We now build legend rows from unique `riskLevel`s (sorted high-to-low) and render each chip with upstream `stroke`/`fill`, so the legend finally mirrors the map overlays instead of acting like a placeholder.

## 6) Engineer's Wisdom
- Keep background handlers short and predictable; timeouts are your friend.
- Make policy decisions explicit (cadence, time budgets) and centralize them for testability.
- Prefer dependency injection so you can test scheduling logic without touching real OS APIs.
- In map UIs, “follow user location” should be explicit state, not a side effect of every position update.
- When multiple upstream data sources feed one screen, degrade gracefully: fail one panel, not the whole page.
- If one SwiftUI file starts doing networking, UI composition, and geometry transformation, split it before it becomes a kitchen-sink file.
- When a style value comes from upstream data, pass it as explicit metadata instead of reverse-engineering it from display text.
- For visual refactors, treat style as infrastructure: centralize “new API + fallback” paths once, then apply them broadly with minimal per-view custom logic.
- Keep formatter allocation out of hot paths; cache or centralize formatting helpers before profiling gets noisy.
- Stable list identity is a performance feature. Random IDs make diffing expensive and can degrade scroll smoothness.
- Prefer one clear async trigger pipeline over several reactive hooks that can race or duplicate work.

## 7) If I Were Starting Over...
- I’d design background scheduling as a policy engine from day one, with clear rules for “tighten/relax cadence” and easy unit test hooks.
- I’d add a small diagnostics surface in-app early so it’s obvious when background work is being throttled or suppressed.
- I’d separate map data transforms into a dedicated mapper layer up front so polygon construction and caching are deterministic and testable outside SwiftUI.
- I’d add a lightweight performance checklist early (render-path work, identity stability, async trigger fan-out, geometry feedback loops) and enforce it in review.
