# Installation enrollment

SkyAware consumes ArcusCore **0.6.0** (`d648e2c91c687511daf9a1f7cecaf9c52b283713`) for Signal installation enrollment. This development change must not be installed on devices or released until the compatible Signal v2 server from Signal #386 / PR #388 is deployed. Server deployment is a separate operation.

## Credential lifetime

`InstallationEnrollmentCoordinator.shared` owns enrollment for the three installation writers: location snapshots, preferences, and foreground activity. Public weather APIs do not use installation credentials. First foreground activity can enroll without an APNs token or notification permission; failed enrollment does not block public weather or cached UI.

The existing installation UUID must be durable before enrollment. A 32-byte cryptographically random secret is encoded as base64url without padding and saved in a device-only, after-first-unlock Keychain record before the first enrollment request. The record stores enrollment acknowledgment separately from credential existence. A lost response or failed acknowledgment persistence retries the same UUID and secret. HTTP 200 with the shared `status: accepted` acknowledgment establishes enrollment; subsequent foreground activations make no enrollment or credential-validation request.

A separate Keychain marker prevents credential loss from being interpreted as an eligible legacy first claim. Locked, corrupt, mismatched, or unavailable identity/credential state fails closed. HTTP 409 and protected-write HTTP 401 never generate replacement credentials or fall back to v1. Credential rotation and fresh-identity recovery are intentionally unavailable: notification continuity requires a separately approved recovery contract. Enrollment is bound to the configured HTTPS origin. The URLSession task delegate rejects every redirect for v2 installation POSTs, including aliases, to prevent forwarding credential bodies or bearer headers to another route, origin, or protocol.

Concurrent callers share one enrollment operation. Cancellation prevents a waiting caller's protected write; the shared claim retains ownership until it finishes, allowing its acknowledgment to be persisted and preventing a competing enrollment. A future caller can retry failed enrollment with the persisted credential.

## Pending uploads and consent ownership

The durable upload queue and its format remain unchanged. Rehydrated work, retries, and legacy source-value fallback all reach the authenticated v2 uploaders. The queued installation UUID must match the current durable identity; mismatches remain unsent rather than being reassigned. Payloads contain no credentials, and failed enrollment does not acknowledge or remove queued work.

SkyAware #794 owns the existing pre-send consent/replay correction and remains a separate open issue. Signal #379 owns server ordering of in-flight consent changes. Authentication does not establish either consent invariant, and enrollment introduces a wait before the protected HTTP handoff that #794 must account for. This integration does not claim to prevent stale queued preferences or recall already-started requests. Legacy v1 retirement remains Signal #387. After an installation is claimed, downgrading to a v1-only app cannot restore device writes; rollback must preserve a compatible authenticated client/server pair or use a separately reviewed continuity plan.

## Validation boundaries

Deterministic tests use synthetic HTTP seams, memory credential stores, isolated simulator Keychain services, and reopened UserDefaults upload queues. They establish client protocol, coordination, retry, and header behavior; they do not establish physical-device Keychain accessibility, production deployment, APNs delivery, or end-to-end consent ordering. Device acceptance must include ordinary app updates, locked-device background sends after first unlock, denied notification permission, and restart following lost enrollment acknowledgment after the compatible server is deployed.
