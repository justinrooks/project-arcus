# Installation enrollment and consent

SkyAware uses accountless installation authority for authenticated device writes. Public weather acquisition and cached presentation do not require successful enrollment. This document owns the client security contract; [Location and Lifecycle](../architecture/location-and-lifecycle.md) owns accepted observation and outbox behavior, and [Notifications](../architecture/notifications.md) owns local evaluation and delivery handoff. Server authorization, atomic acceptance, targeting and deployment remain backend-owned.

## Current protocol and backend authority

The [resolved packages](../../SkyAware.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved) pin ArcusCore 0.7.0. The checked-in client consumes Signal installation endpoints even though Signal and ArcusCore are deprecated. Forge is the strategic successor, not an inferred deployed replacement.

| Operation | Production POST route | Accepted response |
| --- | --- | --- |
| Enrollment | `/v2/devices/enroll` | HTTP 200, status accepted |
| Preferences | `/v3/devices/preferences` | HTTP 200, matching non-stale consent acknowledgment |
| Location presence | `/v4/devices/location-snapshots` | HTTP 200, status accepted, valid receivedAt |
| Foreground activity | `/v3/devices/foreground-activity` | HTTP 204 |

[ArcusSignalConfiguration](../../Sources/App/ArcusSignalConfiguration.swift) defines the shared routes; [LocationPresenceRuntime](../../Sources/Infrastructure/Location/LocationPresenceRuntime.swift) explicitly selects geography-invalidating V4 in [HTTPLocationSnapshotUploader](../../Sources/Infrastructure/Location/HTTPLocationSnapshotUploader.swift). V4 uses ArcusCore's DeviceLocationSnapshotV3Payload with capture-bound geographic acceptance semantics. The explicitly selectable V3 uploader remains for compatibility/testing; failed V4 requests do not select it automatically. Legacy queue DTOs are preparation inputs, not current wire consent. No failure authorizes legacy mutating routes. Public weather endpoints retain their own protocol versions.

## Installation identity and credential lifetime

[InstallationIdentityStore](../../Sources/Notifications/RemoteNotificationRegistrar.swift) owns the installation UUID. Authenticated operations require durable readback; a volatile launch UUID must not initialize enrollment or consent authority. APNs token registration is separate from installation identity. Enrollment can occur on first foreground activity without a token or notification permission.

[InstallationEnrollmentCoordinator](../../Sources/Infrastructure/Activity/InstallationEnrollmentCoordinator.swift) is shared by the three protected writers. Persist a cryptographically random 32-byte base64url credential and its creation marker before any enrollment request. The Keychain record uses after-first-unlock, this-device-only accessibility; accepted origin is stored separately from credential existence. Require exact HTTP 200/shared accepted acknowledgment and persisted origin before admitting protected writes. Retry lost response or failed acknowledgment persistence with the same UUID and credential. An already acknowledged enrollment needs no separate enrollment-validation network request on ordinary reactivation.

A missing credential with an existing marker, corrupt/unavailable storage, mismatched identity, invalid secret or incompatible acknowledged origin fails closed. Do not create replacement credentials or reassign queued work following authentication failure. Concurrent waiters share enrollment until its owner unwinds; individual cancellation suppresses that caller's subsequent write without abandoning the shared claim. Bounded persisted-intent recovery requires existing acknowledged enrollment and cannot initiate or wait for a new claim.

Enrollment requires HTTPS with no URL userinfo, and binds accepted credentials to normalized scheme/host/port. Enrollment JSON contains the secret; subsequent protected writes use bearer authorization. Do not put credentials in durable queues, diagnostic output or public-weather requests. Retain redirect confinement for installation writes: initial HTTPS and stripping Authorization alone are insufficient to protect a credential-bearing POST body. See [original security rationale](../../.trail/learnings/2026-10-28-confine-installation-enrollment-secrets-and-preserve-justinrooks.md) and [redirect verification](../../.trail/learnings/2026-10-28-enrollment-test-membership-and-redirect-guard-justinrooks.md).

**Known protection gap (source review at fbb337e):** [InstallationRequestRedirectPolicy](../../Sources/Infrastructure/Networking/HTTPDataDownloader.swift) currently refuses POST redirects for V2/V3 device routes and their /api aliases, but not V4. Production V4 uses the common POST transport, and the existing [redirect regression](../../Tests/UnitTests/InstallationEnrollmentTests.swift) does not cover V4. Preserve the intended no-redirect invariant; separately correct and verify V4 coverage before the next affected client release. This is a source-confirmed omission, not evidence of actual redirection or disclosure. Documentation does not remediate the defect.

## Revisioned consent and evidence fencing

[InstallationConsentStore](../../Sources/Infrastructure/Activity/InstallationConsentStore.swift) owns durable consent revision, not user intent itself. AppStorage and current Core Location authorization provide the four consent fields: server subscription, meso preference, location sharing and OS location authorization. Persist the complete snapshot, matching installation UUID and positive Int64 revision together in the existing defaults suite. Only changed consent advances revision; token/environment/metadata changes alone do not. Require persistence/flush and a separate Keychain creation marker before transport, including unchanged-revision retry. Lost defaults after prior promotion must not silently restart at revision 1.

Keep three authorities distinct:

| Authority | Purpose |
| --- | --- |
| Consent revision | Monotonic server-visible consent snapshot. |
| Location evidence fence | Monotonic local cutoff for observations invalidated by sharing, authorization or precision transitions. |
| Pending preference intent | Recover current unacknowledged preference sync independently of location. |

Precision participates in the local evidence fence, not the four-field V3 wire revision. Explicit sharing/permission captures and observed state transitions advance the cutoff. Unchanged restart does not manufacture a revocation; first marker without prior invalidation starts from no known cutoff. Reject corrupted fence state and pre-cutoff observations. Registration of location transfers and invalidation share a lock; cancel applicable active work and retain a preference recovery intent. An unobserved permission round trip while terminated cannot be inferred from identical final state.

Settings capture subscription changes synchronously after the AppStorage write. [LocationSession](../../Sources/Infrastructure/Location/LocationSession.swift) serializes durable intent bookkeeping in capture order; network callbacks reconcile current consent rather than impose callback ordering. This permits deliberate rapid disable/enable without requiring an async read of the intermediate disabled value. Legacy Boolean-only restrictions remain conservative where explicit ordering is absent. Never elevate historical queued consent to a new revision. See [consent replay rationale](../../.trail/learnings/2026-10-28-consent-replay-must-preserve-prepared-identity-justinrooks.md).

## Protected transfer admission and acknowledgment

[HTTPDevicePreferenceSyncUploader](../../Sources/Infrastructure/Location/HTTPDevicePreferenceSyncUploader.swift), [location uploader](../../Sources/Infrastructure/Location/HTTPLocationSnapshotUploader.swift) and [foreground activity uploader](../../Sources/Infrastructure/Activity/ForegroundActivityReporter.swift) share enrollment and consent authorities. Each admitted location/activity operation first synchronizes current authenticated V3 consent, including after restart. Concurrent equal-revision preferences are permitted; backend atomic monotonic acceptance and irreversible promotion prevent older in-flight requests restoring superseded consent.

Reconcile current consent after enrollment and preparation waits. For location, consent admission checks cancellation/deadline independently of geographic eligibility so a higher-revision opt-out can synchronize before the final geography gate suppresses the location. Recheck matching durable identity, pending record identity, full precision, sharing, granted location authorization, capture cutoff and cancellation/deadline before handing off the prepared location. Force, retry, legacy source fallback and persisted replay cannot bypass these gates. Initial consent and opt-out require neither token nor geography.

Compare preference acknowledgment with freshly reconciled local revision. Reject server-ahead, stale or mismatched acknowledgment; if local revision advanced while waiting, synchronize the newer snapshot. Only the latest request generation may apply meso ownership and clear the matching pending preference intent, including competing same-revision token changes. A late tokenless response cannot overwrite newer acknowledged binding. This does not prove server-side token commit order. A preference acknowledgment is not location acceptance.

Location presence contains observation evidence, not subscription or token authority. Preserve original capture time including subsecond identity and applicable H3/UGC evidence; V4 allows partial capture-bound geography and subsequent same-capture enrichment. Do not retain prior-capture UGC as current verified geography. HTTP 200 alone is insufficient: validate the acknowledgment, and record accepted delivery only for status accepted. Ignored/stale retire that completed attempt without recording successful geographic replacement. Pending queue identity must survive newer retained work during an older send. Semantic dedupe uses actual prepared identity, not historical request fields or completion-time settings. Failed/suppressed transfers do not establish acknowledged freshness. See [presence delivery](../architecture/location-and-lifecycle.md#delivery-cadence-and-acknowledgment) and [post-enrollment checks](../../.trail/learnings/2026-10-28-pending-consent-checks-must-follow-enrollment-justinrooks.md).

## Failure handling and explicit recovery

| Condition | Required handling |
| --- | --- |
| Lost enrollment acknowledgment | Retry same persisted claim. |
| Temporary transport, persistence or enrollment failure | Defer eligible work; do not acknowledge it. |
| Invalidated or prohibited location evidence | Suppress geographic handoff, without suppressing necessary preference recovery. |
| Ignored/stale location response | Retire completed attempt without accepted-presence acknowledgment. |
| Credential rejection, mismatched identity or origin | Fail closed without automatic credential replacement or downgrade. |
| Corrupt/missing promoted consent, overflow, server-ahead revision | Reject; explicit recovery rather than counter invention. |
| V3 preferences HTTP 409 | Terminal consent inconsistency. |

On preferences HTTP 409, preserve the existing UUID, revision and snapshot and persist conflictRequiresRecovery. The in-process latch blocks subsequent automatic handoffs even if persisting the flag fails; successful persistence also blocks after reopen. Later preference changes do not repair conflict automatically. Retain eligible queued work. Diagnostics identify status and recovery requirement without credentials or consent/geography values. No automatic credential rotation, fresh-identity migration, revision reset or recovery procedure is authorized. Notification continuity requires a separately approved recovery contract.

Client checks cannot recall HTTP requests already handed to transport, nor accepted APNs deliveries. Server ordering and routing must be verified separately. Public weather and accepted cache remain independent of these failures.

## Deployment prerequisites and validation boundaries

Historical implementation decisions: [SkyAware #796](https://github.com/justinrooks/project-arcus/issues/796) introduced enrollment; [#794](https://github.com/justinrooks/project-arcus/issues/794) corrected prepared-intent replay; [#798](https://github.com/justinrooks/project-arcus/issues/798) introduced revisioned V3 consent. The earlier V2-only and V3-only location descriptions and conservative Boolean callback-only reversal policy are superseded. Preserve original issue/PR and Trail evidence.

| Backend dependency | Status at review |
| --- | --- |
| [Signal #386](https://github.com/justinrooks/arcus-signal/issues/386) / [PR #388](https://github.com/justinrooks/arcus-signal/pull/388), authenticated V2 enrollment | Implementation closed completed. |
| [Signal #379](https://github.com/justinrooks/arcus-signal/issues/379), monotonic V3 consent and promotion | Implementation closed completed. |
| [Signal #391](https://github.com/justinrooks/arcus-signal/issues/391), usable accepted presence before meso ownership | Implementation closed completed. |
| [Signal #414](https://github.com/justinrooks/arcus-signal/issues/414), V4 geographic reconciliation | Implementation closed completed. |
| [Signal #387](https://github.com/justinrooks/arcus-signal/issues/387), legacy V1 retirement | Open; requires explicit cutover approval. |
| [SkyAware #760](https://github.com/justinrooks/project-arcus/issues/760), location-change notification delivery without duplicates | Open. |

These are issue states, not deployment evidence. Before distributing a client requiring a new protocol, verify compatible server deployment first, existing-client compatibility and downgrade fencing, and controlled signed-device consent/presence/ownership behavior before wider distribution. Do not infer current release readiness from historical checked launch drills. Preserve meso fallback until acknowledged usable server ownership; validate absence of a delivery gap. Device acceptance includes ordinary update preserving credentials, after-first-unlock locked-device recovery, denied notification permission, restart following lost enrollment acknowledgment, current opt-out/re-enable and partial-to-complete capture reconciliation. V4 redirect confinement needs its own targeted regression and release verification.

[Forge installation parity](https://github.com/justinrooks/arcus-forge/blob/main/docs/installation-parity.md) establishes isolated PostgreSQL compatibility of these four routes, including approved geographic differences; Forge deliberately returns serverOwnsMesoNotificationDelivery false. Production routing, credential/data transfer, notification ownership and rollback require separate migration approval. See the [Arcus ecosystem](https://github.com/justinrooks/Prompt_Fu/blob/main/docs/arcus/README.md).

Representative regression definitions: [InstallationEnrollmentTests](../../Tests/UnitTests/InstallationEnrollmentTests.swift), [InstallationConsentTests](../../Tests/UnitTests/InstallationConsentTests.swift), [ForegroundActivityReporterTests](../../Tests/UnitTests/ForegroundActivityReporterTests.swift) and [RemoteNotificationRegistrarTests](../../Tests/UnitTests/RemoteNotificationRegistrarTests.swift). Preserve isolated synthetic HTTP, memory stores, simulator Keychain services and reopened defaults queues. Verify native Xcode test membership and actual executed results through [CI procedures](../../tools/ci/README.md). Deterministic seams do not establish physical Keychain accessibility, deployed server behavior, production APNs delivery or end-to-end ordering. This documentation review executed no runtime tests or deployment checks.
