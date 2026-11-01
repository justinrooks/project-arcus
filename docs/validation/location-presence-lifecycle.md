# Location presence lifecycle validation — LOC-06 / #848

The process owns one `LocationPresenceRuntime`, constructed before the weather `ModelContainer` opens. The app delegate restores Always-authorized significant-change registration on every launch, including scene-based launches with nil launch options; the foreground scene then selects its normal foreground mode. The normal dependency graph reuses that runtime after storage becomes available. An Always-authorized background callback admits only fresh, canonically accepted observations to the durable presence outbox before the existing Home ingestion and local watch/risk evaluation. The outbox retains retry and consent authority; weather processing is discretionary. Neither startup nor delivery requests authorization in the background.

Durable admission and transport have separate boundaries. The background pusher seam returns after queue persistence; delivery/retries and local notification work then run concurrently under one execution grant. Expiration cancels the delivery task and its structured transport child; cancellation is forwarded to the weather handler's owned task. Sharing opt-out or failed outbox persistence does not turn a canonically accepted location into a rejected observation or disable existing local notification ownership. A failed persistence attempt is not proof of durable presence.

Deterministic coverage includes real UserDefaults outbox reopen, a newer observation admitted while transport and discretionary weather are blocked, cancellation/expiration retaining the newest intent, grant cleanup, local notification suppression after cancellation, stale/duplicate/older observation rejection, and Always authorization downgrade/denial. These cases exercise source behavior without establishing OS wake behavior.

## Configuration and platform limits

`Config/Info.plist` retains `UIBackgroundModes = location, fetch, processing, remote-notification`. `LocationManager` retains `allowsBackgroundLocationUpdates = true`, `pausesLocationUpdatesAutomatically = false`, and its existing accuracy/distance settings. No setting was removed without physical-device evidence. Significant-change delivery does not provide a fixed distance or cadence guarantee. Always authorization, service availability, Background App Refresh, system policy, and force quit affect eligibility. No continuous background stream or new scheduler is introduced.

Apple documents that significant-change service can relaunch an eligible terminated app and that the app must recreate its manager and restart monitoring. The current [UIApplicationDelegate launch documentation](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:didfinishlaunchingwithoptions:)) states that scene-based apps receive nil launch options, and the [legacy location launch key](https://developer.apple.com/documentation/uikit/uiapplication/launchoptionskey/location) is deprecated. Restoration therefore does not depend on that key. See [startMonitoringSignificantLocationChanges](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringsignificantlocationchanges()) and [Getting the User's Location](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/CoreLocation/CoreLocation.html). User force quit must not be treated as a supported relaunch mechanism. A background execution grant can expire; cancellation must not be interpreted as acknowledgment of a pending outbox request.

## Physical-device matrix

On 2026-11-01, the owner explicitly deferred physical-device testing and authorized publication of the reviewed implementation with this matrix pending. This deferral permits PR publication; it does not establish physical-device acceptance or authorize merge/release. Keep #848 open until its remaining acceptance evidence is recorded.

All rows below are **unperformed** in this implementation session. Simulator/unit evidence cannot establish OS wake delivery. Run on a signed physical iPhone, record device/OS/build, authorization, accuracy, Background App Refresh, receipt timestamp, captured-at timestamp, pending outbox state, and server acknowledgment. Do not log coordinates or notification contents. Preserve #760 as the downstream notification-validation owner.

| Scenario | Procedure | Expected evidence |
| --- | --- | --- |
| Background movement | Grant Always, background app, travel until iOS delivers an event | Accepted observation retains its timestamp; durable intent precedes weather/notification work |
| System termination | Let iOS terminate the background app; cause eligible movement without swiping it away | Location relaunch restores monitoring; presence admission works before Home appears |
| Weather startup failure | Exercise location relaunch while the weather store cannot open, including protected-data conditions | Runtime remains alive; if outbox/identity storage is accessible, presence persists independently; unavailable durable storage must not be reported as success |
| Rejected/cached callback | Deliver inaccurate, duplicate, stale, and older fixes through deterministic injection | No fresh presence or discretionary weather work from rejected evidence |
| Overlapping ingestion | Keep weather ingestion active while a newer movement event arrives | New presence is retained independently of the weather handler's active-task join |
| Connectivity recovery | Disable networking, receive movement, restore connectivity and trigger an existing retry/drain opportunity | Persisted newest observation survives and is eventually acknowledged; reconnection alone is not a guaranteed execution opportunity |
| Expiration/cancellation | Expire the OS grant during pending upload, then relaunch/drain | Grant ends; no discretionary weather follows canceled admission; persisted intent remains retryable |
| Authorization revocation | Revoke Always or all access while suspended; resume/deliver a queued callback | No background presence admission; monitoring stops as authorization permits |
| Force quit | Swipe away app, travel, then manually reopen | No promised wake while force-quit; normal launch restores supported behavior |
| Background App Refresh disabled | Disable globally/per-app, repeat termination/movement, then reenable | No guaranteed relaunch while disabled; record actual supported restoration |

A completed matrix requires device evidence, not a passing unit lane. Before-first-unlock storage accessibility, OS launch timing, energy behavior, and visible notification receipt remain device-only questions.
