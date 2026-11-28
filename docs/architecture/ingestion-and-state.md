# Ingestion and State

This document describes SkyAware's Home ingestion, acceptance, persistence, freshness, and presentation ownership. Start with the [client architecture overview](README.md) for system composition.

See [Feature Data Contracts](feature-data-contracts.md) for specialized acquisition, validity, domain and derived-consumer requirements. Location lifecycle, notification delivery and installation security remain separate architectural concerns. The linked historical records preserve evidence and earlier decisions; reconcile any remaining contradictions against current source before reuse.

## Ingestion ownership

Home ingestion converges foreground activation, manual refresh, scheduled background refresh, location changes, and supported remote-alert work on common coordination and execution boundaries. This preserves one coherent location-scoped weather truth, avoids competing Home refresh implementations, and makes hot-alert priority and resource ownership explicit.

| Owner | Responsibility |
| --- | --- |
| [HomeIngestionRequest / HomeIngestionPlan](../../Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift) | Express request intent and translate it into executable requirements and compatibility rules. |
| [HomeIngestionCoordinator](../../Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift) | Own plan admission, joining, serialization, pending work, waiter lifetimes and shared execution. |
| [HomeIngestionExecutor](../../Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift) | Resolve applicable location context, execute provider lanes under the selected policy, orchestrate persistence and staged publication. |
| [HomeRefreshPipeline](../../Sources/App/HomeRefreshPipeline.swift) | Own foreground submissions, lifecycle intent, and visible publication on the main actor. |

The coordinator is an execution authority, not a weather-data authority. Domain repositories and their acceptance boundaries determine which data is canonical; the projection and presentation owners consume that state.

Unified Home ingestion is not a requirement to route every network operation through a full Home plan. Feature-local manual outlook and Storm Setup refreshes, targeted meso notification resolution, independent presence delivery, and WSSI acquisition have distinct scopes. Such paths must respect their own execution, acceptance, and publication boundaries rather than introduce competing domain truth.

## Request coordination

A plan keeps the following requirements distinct:

- **Provenance:** why the request occurred, including lifecycle, manual, movement, and remote-alert intent. It remains useful for diagnostics and trigger-specific behavior but does not alone determine execution class.
- **Execution class:** foreground or background HTTP and latency policy.
- **Lanes and forced lanes:** hot alerts, slow products, and weather. Lane coverage is a requirement for work consideration; forced coverage bypasses ordinary freshness admission, not authorization, validity, cancellation, or resource constraints.
- **Location request:** current prepared context, preparation from the latest accepted observation, preparation with freshness/prompt requirements, or explicit resolved context.
- **Remote-alert context:** targeted alert identity and applicable revision.
- **Execution context:** independently scoped background budget/deadline ownership when applicable.

See `HomeIngestionPlan.init(request:)` and `HomeIngestionLocationRequest` in [HomeRefreshTrigger.swift](../../Sources/App/HomeRefreshV2/HomeRefreshTrigger.swift) for the exact trigger matrix and location compatibility rules. Hot-alert consideration is included in every Home plan; a plan need not execute every admitted lane on the network.

### Joining and pending work

The coordinator actor runs one Home plan at a time and retains at most one merged pending follow-up. An active run may satisfy a new request only when its lane, force, location, remote-awareness, and execution-context compatibility checks allow joining. Otherwise work is queued or merged into the pending plan.

Merging unions lane and force requirements and provenance. It reconciles location requirements, with the newest location-bearing request replacing the pending location requirement. If that replacement makes an earlier pending waiter unsatisfiable, terminate that waiter rather than leaving it suspended indefinitely. A newer supplied remote context replaces the pending remote context; do not mistake this for independent execution of every targeted request.

Remote-targeted requests cannot join a run lacking remote context or a run that has passed its hot-alert absorption boundary. They may join an eligible remote-aware forced-hot run before that boundary. Receipt-specific acceptance still has its own validation and completion contract.

The coordinator tracks an earliest eligible run number per waiter. Run completion resolves only eligible satisfied waiters; staged publication carries the executor's run identity. Visible submission identity, location identity, provider source identity, and run identity remain separate. See [coordinator tests](../../Tests/UnitTests/HomeIngestionCoordinatorTests.swift) for serialization, supersession, targeted joining, and publication identity characterization.

### Execution class and deadlines

Foreground participation in merged pending work selects foreground execution and clears retained background deadline context. Do not retroactively promote an already active budget-constrained run: incompatible foreground ownership or different submitted deadlines can require a follow-up.

The executor scopes HTTP execution mode across location resolution and provider work. Budget context is task-local and explicitly installed for each coordinator run. Background execution class does not itself imply a scheduled-refresh budget.

| Pending owner combination | Execution-context merge policy |
| --- | --- |
| Foreground plus background | Foreground class; no retained background budget. |
| Ordinary bounded background plus unbudgeted background | Retain the bounded context. |
| Two ordinary bounded background contexts | Retain the earlier work deadline. |
| Receipt-involving merge with differing deadlines, one owner unbudgeted | Preserve unbudgeted shared lifetime. |
| Receipt-involving merge with differing deadlines, both owners bounded | Retain the later bounded work deadline; receipt watchdogs remain independent. |

These are the current coordinator merge rules, not a promise that all combinations can join an existing active run. See `submit`, `mergedExecutionContext`, and `startRun` in [HomeIngestionCoordinator.swift](../../Sources/App/HomeRefreshV2/HomeIngestionCoordinator.swift) and [BackgroundRefreshBudget.swift](../../Sources/Features/Background/BackgroundRefreshBudget.swift).

## Cancellation and resource ownership

Caller lifetime, shared execution lifetime, and OS-granted execution lifetime are separate.

- Cancellation removes the actor-owned waiter and resumes its continuation with cancellation exactly once. A removed waiter is no longer eligible for subsequent progress/publication selection; callbacks already in flight cannot be recalled.
- A canceled ordinary waiter does not automatically cancel coordinator-owned work. Fire-and-forget ownership and retained compatible waiters preserve useful shared execution.
- Canceling the final eligible active background owner cancels unshared execution. Preserve the work if another active owner remains.
- Ordinary queued work can remain after its waiter cancels. Receipt-specific cancellation can retire a queued follow-up when it has no retained pending waiter or fire-and-forget owner.
- Completion and cancellation are resolved by actor-owned waiter removal. A completion already observed is not undone by later cancellation.

Use structured provider-lane concurrency and explicit task ownership. Do not introduce unowned detached ingestion or enrichment work, unchecked sendability, or cross-actor ModelContext access to work around these boundaries.

### Background and remote execution

[BackgroundRefreshBudget](../../Sources/Features/Background/BackgroundRefreshBudget.swift) uses a monotonic clock for application-owned work and finalization windows, distinct from persisted wall-clock timestamps. Scheduled refresh defaults to 30 seconds total with five seconds reserved for finalization. [BackgroundOrchestrator](../../Sources/Features/Background/BackgroundOrchestrator.swift) includes a quota-one, five-second durable upload pre-drain within cancellation scope and elapsed run time; remaining durable requests survive for later delivery. The cooperative drain deadline does not guarantee termination of a non-cooperative network operation.

[RemoteNotificationReceipt](../../Sources/App/RemoteHotAlertHandler.swift) owns a separate 25-second total application budget with two seconds reserved for completion, its own watchdog, and exactly-once completion. Accepted product evidence can survive subsequent failure or timeout of discretionary work; receiving a payload is not by itself canonical acceptance. Receipt-specific results and navigation require separate notification-contract review.

These are application policies, not execution guarantees from iOS. Expiration, cancellation, or insufficient remaining budget must stop discretionary background work. Preserve hot-alert priority, foreground-only AQI, and bounded admission of optional Storm Setup enrichment; their detailed acquisition and acceptance rules are in [Feature Data Contracts](feature-data-contracts.md). WSSI background assessment reads accepted local data rather than starting background acquisition.

The scheduling fallback, cadence, authorization, durable presence delivery, and notification policies will be covered with lifecycle and notification ownership. Do not conflate them with coordinator plan priority.

## Foreground orchestration

[HomeRefreshPipeline](../../Sources/App/HomeRefreshPipeline.swift) retains a hot-alert-first prime followed by a non-blocking full follow-up for scene activation and context-change flows. Prime resolves or receives the applicable context and requests forced hot alerts; the follow-up uses the context returned by prime when available. This avoids repeating GPS/NWS preparation unnecessarily. Manual and timer refreshes do not use this two-stage path.

The pipeline retains deferred context-change intent while foreground work is in flight and re-evaluates it against the active scene and current context before submitting the deferred refresh. Preserve movement correctness when reducing latency; the original two-stage design should not be removed merely because it appears complex. Evaluate changes against concrete runtime evidence.

### Location reuse is scope-specific

Only the dedicated scheduled-refresh intent can admit the scheduled durable-context reuse path; explicit contexts and incompatible merged work must not inherit it merely because background provenance is present.

[BackgroundLocationContextReusePolicy](../../Sources/Infrastructure/Location/BackgroundLocationContextReusePolicy.swift) allows complete, valid, accurate, movement-free context within a 90-minute product privacy tolerance under eligible authorization. When-In-Use authorization permits eligible reuse but not a fresh background fix; Always authorization may attempt fresh resolution when reuse is ineligible. The tolerance is not a guarantee of scheduler timing.

[ForegroundDurableContextReusePolicy](../../Sources/Infrastructure/Location/ForegroundDurableContextReusePolicy.swift) is a characterized future fast-path policy, not an established runtime integration. Existing durable v1 records cannot establish capture authorization or trusted current grid identity. The policy requires a complete context at most 15 seconds old, matching authorization, trusted matching H3 and NWS grid cell, and no movement/invalidation evidence. Eligible reuse has no upload side effect and requires independent refresh-behind. Fresh observations retain their original capture time. Do not treat this policy's existence or its tests as proof that foreground durable reuse is active.

Detailed context validation, privacy, storage, and NWS enrichment semantics remain for the location/lifecycle review.

## Canonical acceptance

Acquisition attempts, transport responses, domain acceptance, projection commits, and consumer publication are different events. A successful HTTP response does not establish domain truth; a successful domain transaction does not prove a location projection has been committed. Presentation must respect the authority of the data it consumes.

Distinguish authoritative empty from unavailable, invalid, skipped, expired, cancelled and failed. An eligible accepted empty result can remove a previous threat; missing or unaccepted evidence must not manufacture a quiet assessment. Retain eligible accepted data across failed attempts without extending its validity or promising indefinite display as current. Use explicit domain outcomes when absence has different behavioral meanings; do not introduce a generic provider result framework merely for uniformity.

Transport fallback does not establish a new accepted projection or freshness by itself. Individual repositories may have bounded merge/reconciliation behavior for cached inputs; do not infer identical mutation semantics across every provider. Source provenance and admission timing are separate from domain validity.

## Domain persistence

### SPC map products

[SPC map ingestion](../../Sources/Providers/SPC/SpcProvider+Syncing.swift) stages candidate products and validates geometry and source metadata before accepted replacement. Never invent issuance, validity or expiry timestamps from the acquisition time when source metadata is malformed.

Convective and fire are independent acceptance domains. Categorical geometry anchors the coherent Day 1 convective batch (categorical, hail, wind, tornado); fire RH has its own source window and transaction. One domain may accept while the other retains eligible prior rows.

- Missing, malformed, inconsistent, expired or otherwise invalid candidate data rejects the affected domain. Transport fallback cannot authorize map replacement.
- Valid empty severe layers and recognized no-area geometry are legitimate when supported by coherent accepted evidence. Empty categorical with material non-categorical geometry is not a coherent all-clear. A coherent all-empty batch can clear active risk; do not store synthetic all-clear polygons.
- Verified future-valid convective products are deferred until applicable; future issuance and expired convective windows are rejected. Deferral is not acceptance of current risk.
- Stage before mutation; replace accepted windows without deleting unrelated future windows. Clear only the affected scope when a coherent batch proves absence.
- Commit accepted geometry through [SpcMapBatchPersistenceRepo](../../Sources/Repos/SpcMapBatchPersistenceRepo.swift). Convective geometry and acceptance evidence save together with rollback on failure or cancellation before commit. Fire uses its own window/active-row backup and restoration path. Do not describe these as a single transaction across all products.

The original [SPC stability playbook](../plans/spc-map-ingestion-stability-playbook.md) documents why transient ingestion must not clear real threats. Its broad rejection of empty/future-only categorical candidates predates the current no-area, accepted-all-clear and deferred-validity rules.

### Accepted Day 1 revision and local assessment

`SPCAcceptedDay1Convective` records the accepted revision identity, source window when available, acceptance time and expected geometry-row counts. Geometry and the revision are committed together. A forecast with an older issued or valid date than the accepted dated revision cannot replace it; a future issuance cannot establish acceptance.

A local Day 1 assessment requires a unique effective accepted revision, a valid point and, for material forecasts, matching source-window rows, expected counts and nonempty polygon geometry. Missing, inconsistent or ineffective evidence is unavailable, not a new all-clear. A coherent undated empty batch may authorize an immediate all-clear only for its newly accepted source; it does not create a reusable validity window.

`HomeProjectionStore.commitCore` revalidates the assessed revision, effective window, point and applicable active projection boundary before committing Day 1 risk. The repository and projection store coordinate revision validation and save with a shared synchronous lock. They remain separate transactions; this is not a cross-ModelContext transaction or a general instruction to add locks.

An effective retained revision may support a new local assessment when acquisition fails or is skipped. Reprojection retains the original source acceptance time and does not imply a new forecast acceptance or notification transition. If revision proof becomes unavailable, preserve eligible prior projection state rather than replacing it with a fabricated quiet value.

See [Day 1 acceptance implementation](../../Sources/Repos/SpcMapBatchPersistenceRepo.swift) and [projection revalidation](../../Sources/Repos/HomeProjectionStore.swift). Future-day categorical and hazard forecast contracts have separate source and acceptance rules.

### Coherent hot collection

[ArcusAlertProvider](../../Sources/Providers/ArcusAlertProvider.swift) distinguishes location-scoped and targeted sync outcomes. [AlertRepo](../../Sources/Repos/AlertRepo.swift) reconciles alert lifecycle and revision identity; a successful empty upstream response is not a blanket instruction to delete all persisted alerts.

[HomeSnapshotStore](../../Sources/App/HomeRefreshV2/HomeSnapshotStore.swift) assembles applicable canonical alerts and the H3-scoped Arcus meso collection through [ArcusMesoProvider](../../Sources/Providers/ArcusMesoProvider.swift). The complete hot projection is eligible to advance only when location-scoped alert acceptance and meso collection acceptance both hold. The meso collection accepts live or revalidated responses; local-cache, fallback and failed reads do not establish a new accepted collection. A targeted alert/meso can be accepted independently without proving coherent location-scoped refresh.

The projection represents the accepted assembled collection, including legitimate empty collections, not simply the count returned by the last endpoint. Failed or incomplete coherent acceptance preserves the prior hot slice. This supersedes the historical description of Home hot acceptance as a pair of Arcus alert and direct SPC meso sync operations. Alert revision, lifecycle and notification-specific acceptance are governed by their own contracts.

### Outlook discussions

[ConvectiveOutlookRepo](../../Sources/Repos/ConvectiveOutlookRepo.swift) treats SPC RSS as a publication feed, not a complete Day 1–3 collection. Current discussion pages bootstrap omitted days; eligible incoming issuances are combined with previously accepted content. Malformed recognized RSS products or missing channels reject that candidate input, not necessarily a separate valid current-page acquisition.

Validate source issuance and validity without manufacturing current timestamps. Forecast day is a source role, not a local calendar date. Retain the latest eligible validity period for each role, deduplicate issuances and titles, and bound history using the source policy. Re-read accepted state after suspension and evaluate eligibility at commit time to prevent an older request from removing a newer period. Replace the accepted collection and its acceptance marker in one save; roll back failed saves. Local-cache and fallback responses do not establish a new accepted collection. Manual refresh must honor the provider's typed outcome.

## Projection transactions

[HomeProjectionPersisting](../../Sources/Repos/HomeProjectionStore.swift) requires explicit `commitCore` semantics. Do not provide a decomposed default implementation that lets a conformer claim atomicity while performing independent saves. Production stages authorized weather, slow-product and hot-alert updates and applicable comparison state in one actor-owned core save; test conformers must preserve the same transaction contract.

Skipped slices retain accepted state; explicitly authorized empty slices can clear it. The weather double optional distinguishes no update from an explicit empty update. Convective and fire update authority remains separate. Persistence acknowledgement returns the exact committed record, derived risk change, widget publication input and applicable accepted Day 1 assessment. The store rolls back failed saves.

[HomeIngestionExecutor](../../Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift) uses that acknowledgement for projection-backed publication. A failed projection save does not invalidate independently accepted canonical domain data: retain a prior durable projection when available, otherwise suppress core replacement. Canonical data remains available for applicable independent evaluation and a later successful run can repair publication. Do not manufacture committed risk changes or publish an uncommitted candidate as accepted widget state. A skipped/no-update attempt may still consume an eligible retained projection; a missing projection-store seam does not establish accepted core status.

Optional enrichment has its own persistence boundary. AQI preserves eligible same-location state on skip, failure or unavailable persistence, and publishes replacement only from the accepted returned record. Older AQI observations cannot replace newer persisted observations. Do not introduce a live-only AQI fallback after a failed save. See [Feature Data Contracts](feature-data-contracts.md) for Storm Setup, WSSI and derived consumer acceptance.

Risk comparison state is persisted with the applicable risk commit; foreground observation and background comparison are distinct modes. Rejected domains or failed projection saves must not manufacture a forecast-transition baseline. Detailed comparison identity, eligibility and delivery belong with the notification contract.

## Projection identity, readiness and retention

[HomeProjection](../../Sources/Models/Home/HomeProjection.swift) partitions durable state by H3 and normalized county, forecast and fire-zone identifiers. The refresh key, projection key, risk comparison key (resolution-8 H3), source identity and consumer presentation identity serve different purposes; do not collapse them simply because they share geographic inputs.

Display readiness requires useful core content: weather, risk values or accepted hot-alert load evidence. Legitimately empty hot collections can establish readiness. A location-only row or optional enrichment alone is not a display-ready core; not every core slice must be present.

[Projection retention](../../Sources/Repos/HomeProjectionStore.swift) preserves the active row, newest display-ready startup fallback and a bounded set of recent useful projections, ranked by update/view recency. The current recent-useful policy is 10 rows within 30 days; that is not a strict total-store cap. Other candidates are staged across sweeps before deletion. The active projection is rechecked and protected through the final save using [HomeProjectionRetentionCoordinator](../../Sources/Repos/HomeProjectionRetentionCoordinator.swift); a context change during cleanup must not delete the newly active row. A staged candidate is not a deletion entitlement.

## Persistent-store lifecycle

[SkyAwarePersistentStoreBootstrap](../../Sources/App/SkyAwarePersistentStoreBootstrap.swift) owns the versioned schema, explicit migration plan and evidence-based recovery. Consult those definitions for exact schema versions and stages; their existence does not prove that each version shipped independently.

- Try opening the existing persistent store. A locked device does not necessarily make an already accessible store unavailable.
- Distinguish protection/access, ambiguous opening errors and positive incompatibility/corruption evidence. An opaque SwiftData error is not sufficient reason to erase or quarantine a healthy store.
- Only attempt quarantine recovery with actual store files, protected data available and appropriate recovery evidence. Preserve store components and recoverable partial quarantine/rollback state if recovery fails.
- Bound quarantine retention and exclude diagnostic stores from backup. Do not turn recovery into routine cache deletion.
- Defer unavailable production startup for retry rather than silently substituting a transient store. Deterministic in-memory UI-test composition is explicit and not production persistence evidence.

Follow the local [SwiftData guardrails](../../Sources/AGENTS.md#swiftdata-persistence-guardrails) and their shared engineering reference for disk-backed save/fetch/reopen, shipped-schema compatibility, migration, repeated focused verification and full unit-lane requirements. JSON coding tests and in-memory-only SwiftData tests do not establish on-disk compatibility.

## Durable feed state

[FeedStateStore](../../Sources/Infrastructure/Ingestion/FeedStateStore.swift) owns a versioned, actor-isolated JSON metadata sidecar, separate from SwiftData. It contains no weather payloads. Canonical repositories own accepted data; projection storage owns durable location-scoped representations. The sidecar records feed-specific evidence for admission and consumer invalidation, not an alternative source of domain truth.

Keep the clocks distinct:

| Evidence | Meaning |
| --- | --- |
| Last attempt | Work was attempted, not necessarily completed successfully. |
| Last network success | A live or revalidated response was obtained. |
| Last canonical acceptance | The feed's applicable acceptance boundary acknowledged data. |
| Last validity observation | Feed-owned recorded validity evidence, not necessarily source expiration. |
| Source issuance and validity window | Domain-owned applicability of the accepted weather product. |
| Projection load time | When a particular location-scoped slice was committed. |
| Monotonic work deadline | Remaining execution budget, not a wall-clock weather timestamp. |

Sidecar updates merge network-success, acceptance and validity timestamps monotonically; latest-attempt provenance, failure and deferral follow attempt ordering. A completion at the same attempt time takes precedence over a provisional cancellation marker; deterministic tie-breaking handles other equal-time updates. Accepted generation advances on an owner-reported acceptance; generation notifications are emitted after successful sidecar persistence. These are invalidation hints, not domain values or universally network-verified revisions.

The store atomically replaces the sidecar and bounds records by most recent attempt (default 32). Missing metadata is not accepted evidence. Corrupt metadata reads fail; a subsequent update can reconstruct the sidecar. Unsupported versions fail rather than being silently overwritten. Non-finite or future-dated attempt, success, acceptance and validity evidence is invalid; the separate deferred-until field deliberately describes a future applicability boundary. Missing or unusable metadata makes the applicable refresh eligible, subject to normal authorization, force, cancellation and resource policy. Do not destroy canonical data to repair admission metadata.

### Acceptance is feed-specific

| Feed identity | Acceptance boundary |
| --- | --- |
| `arcus.alerts` | Repository acknowledgement, including permitted cached merges; error fallback records transport failure and does not establish network success. |
| `home.hot.<projectionKey>` | Complete coherent location-scoped collection and acknowledged projection commit. |
| `home.weather.<projectionKey>` | Successful WeatherKit result and acknowledged projection commit. |
| `spc.map.convective`, `spc.map.fire` | Independent network-backed accepted domain saves. |
| `spc.outlook` | Network-backed accepted discussion collection save. |
| Future-day SPC feeds | Independent accepted forecast persistence and network-backed metadata acceptance. |

[ArcusAlertProvider](../../Sources/Providers/ArcusAlertProvider.swift) records repository-level acceptance independently from coherent Home hot freshness. Its generation may advance after a cached merge without new network success. Targeted remote work does not advance coherent Home freshness. Do not use one feed's generation as evidence of another feed's freshness.

## Refresh admission

[HomeIngestionExecutor](../../Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift) hydrates applicable [HomeFreshnessState](../../Sources/App/HomeRefreshV2/HomeFreshnessState.swift) from durable feed evidence when the production sidecar is available. The in-memory value is an execution/read-model input, not the primary durable scheduling authority.

- Hot and WeatherKit admission are scoped by projection identity. Missing location context cannot establish a location-scoped acceptance.
- Current map admission requires usable records for both convective and fire domains, using the older accepted timestamp. Outlook admission is independent; successful map work cannot hide a failed outlook and vice versa.
- Slow products and weather use an accepted-date predicate requiring positive generation, no latest failure or deferral, live/revalidated provenance and coherent acceptance time. Coherent hot admission uses its own positive-generation/no-failure predicate because it has a different acceptance boundary.
- Forced lanes bypass the corresponding executor freshness interval, not all provider cooldowns, authorization, validity, cancellation or resource checks. Follow the individual policy and provider definitions for exact admission behavior.

### Interruption and restart

Applicable hot, map, outlook and WeatherKit attempts record provisional cancellation/failure metadata before acquisition. This marker means successful acceptance has not yet been established, not that cancellation has already occurred. Only the appropriate acknowledgement finalizes accepted freshness. WeatherKit can successfully return authoritative nil; it still requires an acknowledged projection save. Failed, rejected, interrupted or fallback-only attempts remain eligible for retry under their applicable admission policies, including after restart.

Sidecar and canonical repository saves are separate transactions. A canonical save may succeed while its metadata write fails; do not claim a distributed transaction. The conservative policy is to prefer redundant acquisition over unsupported freshness. Sidecar failure must not erase accepted weather data.

## Temporal validity and cooldowns

Network-verified future-valid convective candidates can be deferred rather than rejected as malformed or accepted as current risk. The SPC sidecar records `lastDeferredUntil` without advancing canonical acceptance. The executor's accepted-date predicate treats a deferred record as not fresh; this is not a dedicated wake-up timer at the validity boundary. Canonical source-window checks continue to govern usable retained assessments.

[SpcProvider](../../Sources/Providers/SPC/SpcProvider.swift) and [its sync implementation](../../Sources/Providers/SPC/SpcProvider+Syncing.swift) retain a short process-local current-map cooldown after fully accepted work. Partial acceptance does not establish that cooldown. Future-day categorical and hazard acquisition have their own accepted identities and process-local cooldowns; failed future-day acquisition can retry on subsequent provider invocations independently of the current-map cooldown. These are not independent OS jobs.

Keep OS background scheduling, durable feed admission and provider-local cooldowns separate. The scheduler controls opportunities to execute; admission determines which requested work is due; provider policy suppresses redundant acquisition or admits specific retries. Exact cadence, jitter and OS lifecycle behavior belong to [Location and Lifecycle](location-and-lifecycle.md).

## Transport provenance and fallback

[HTTPDataDownloader](../../Sources/Infrastructure/Networking/HTTPDataDownloader.swift) distinguishes live acquisition, network-revalidated cached representation (304), local HTTP cache and error fallback. These describe how bytes were obtained, not domain acceptance. A 304 can support acceptance if the applicable representation and domain requirements are satisfied. Local cache and error fallback do not themselves prove new network success or authoritative absence.

HTTP response cache, canonical application cache and Home projection are separate. Rejecting transport fallback must not erase eligible accepted application data. Accepting transport fallback does not necessarily authorize replacing it; preserve each domain's acceptance and lifecycle rules.

### Feed-specific error-fallback policy

Maximum-age fallback requires a parseable origin HTTP `Date` header, nonnegative age and age within the configured limit. Missing, malformed, future-dated or excessively old dates reject fallback. This is transport-representation age, not product validity or application retention duration.

| Client | Error-fallback tolerance |
| --- | --- |
| [Arcus alerts](../../Sources/Clients/ArcusClient.swift) and [mesos](../../Sources/Clients/ArcusMesoClient.swift) | 2 minutes |
| [NWS](../../Sources/Clients/NwsClient.swift) | 2 minutes |
| [SPC](../../Sources/Clients/SpcClient.swift) | 10 minutes |
| [Storm Setup](../../Sources/Clients/StormSetupClient.swift) | 5 minutes |
| [AQI](../../Sources/Clients/AirQualityClient.swift) | 60 minutes |
| [Forge WSSI](../../Sources/Clients/ForgeWSSIClient.swift) | Explicit revalidation; no error fallback |

These are intentional per-client policies, not a universal safety-critical age. The generic HTTP layer retains an unrestricted legacy option; callers must choose appropriate policy. Do not infer all HTTP requests have the same fallback protections.

### Execution and specialized transport

The shared transport applies task-local foreground/background policy. Budgeted background requests cap timeout by remaining work, admit retry delay only if it fits, enforce an in-flight deadline, and propagate cancellation. Retry-After is bounded and jittered according to the applicable policy. Deadline fallback is available only while work remains and the GET fallback policy permits it; otherwise cancel. Failed writes do not become successful cached reads. Refer to the transport implementation for exact retry and timeout defaults.

Storm Setup specializes foreground HTTP with a 30-second timeout and no retry delays; it does not use the generic foreground policy unchanged. Forge WSSI uses explicit conditional revalidation: exact requested URL, network-backed response, and matching validator evidence for cached-body recovery after 304. It preserves legitimate bodyless 304s, rejects ordinary error fallback and requires a complete body for a missing immutable geometry revision. Manifest and geometry acceptance remain with WSSI's domain owners.

## Accepted visible revisions

[HomeVisibleRevision](../../Sources/App/HomeVisibleRevision.swift) derives a location-scoped accepted presentation from persisted records. Its weather, storm risk, severe risk and fire risk core comes from one accepted projection, not a mixture of transient provider results. Independently accepted alerts/mesos, optional enrichment and location display metadata may advance without replacing that core. A new core requires accepted weather or applicable slow-product evidence; older same-key observations cannot replace it merely because another slice was updated.

A hot-alert-only prime can update applicable alerts but cannot certify the weather/risk core. Preserve the historical hail-to-wind regression: a prime must not insert a false intermediate quiet assessment before the accepted replacement forecast. A complete slow-product certification normally requires both domain acceptance controls; current Day 1 revision revalidation and retained-assessment paths have their own explicit evidence rules. Refer to the executor and projection commit rather than inferring certification from a completed lane.

Before a core exists, a resolved projection scope can present an alert-only revision with accepted hot-load evidence and nonempty active alerts. If supplied, the accepted current-point H3 must match. Expired alerts are filtered using the earlier of their end and expiry; alert-only presentation cannot establish weather/risk acceptance and explicitly masks unaccepted core values. Unresolved startup fallback does not use this alert-only exception. Optional enrichment, empty alert-only results and location metadata cannot manufacture a core. Authoritative-empty visible core requires the weather, slow-product and hot acceptance markers as well as empty applicable core and alert values.

Location display metadata can advance independently for an applicable newer observation; late enrichment may supply a place name for the same capture without promoting a new assessment. Do not revive an older capture's name as though it belongs to a newer unnamed observation. See [HomePresentationSnapshot](../../Sources/App/HomeView+PresentationState.swift) for capture and key checks.

## Presentation selection and ownership

Production [HomeProjectionObservation](../../Sources/App/HomeView.swift) derives the visible revision from the current keyed projection, or the newest display-ready startup candidate before location resolution. Retain accepted same-key content across observation gaps; a changed key invalidates the prior visible revision. Do not fill missing weather for a resolved location with a different location's cached risk. Startup fallback is last-known context, not proof of a currently resolved location.

[HomePresentationSnapshot](../../Sources/App/HomeView+PresentationState.swift) composes the accepted revision and applicable readiness/display metadata. Production weather/risk and enrichment are persistence-derived; transient pipeline payloads are available only for explicit static UI-test composition. The pipeline still contributes resolved-location and committed-alert keys and refresh activity. The pure `HomeVisiblePresentation` transition contract in HomeVisibleRevision.swift characterizes accepted promotion, context and refresh outcomes in tests/previews; do not assume it is the sole production runtime state machine.

### Staged publication

[HomeIngestionExecutor](../../Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift) publishes core before optional enrichment. Persisted acknowledgement, retained-state publication and suppressed core are distinct. A successful provider or progress event alone cannot promote the visible core.

[HomeRefreshPipeline](../../Sources/App/HomeRefreshPipeline.swift) associates a visible submission UUID with the accepted executor run and refresh key. Only the latest visible submission handles staged callbacks. Enrichment must belong to the applicable accepted core; Storm Setup activity has additional run/context and manual-attempt guards. A later compatible waiter can adopt an already applied core for Storm Setup when run identity and current context match, without publishing a redundant core. Final snapshot handling must not reapply an already-published core or resurrect a suppressed one. Equivalent committed alert snapshots are not republished. Execution identity, submission identity, projection identity, refresh identity and accepted source revision are not interchangeable.

### Activity is not content

[TodayContentState](../../Sources/Features/Summary/TodayContentState.swift), [LocalAlertsDisplayState](../../Sources/Features/Summary/LocalAlertsDisplayState.swift) and the feature presentation models derive readiness and activity separately from accepted payloads. Preserve useful applicable cache during refresh or failure. Distinguish no-cache resolution, accepted empty, unavailable, offline/degraded, failed refresh with cache, location unavailable and persistence unavailable. Initial core resolution is scoped to the applicable attempt; optional work does not extend it into a new full-screen loading cycle. A provider progress label can describe activity but cannot replace accepted content.

Automatic refresh is normally quiet with cache; manual refresh owns explicit feedback and accessibility events. Cancellation is not automatically a failed refresh. Manual completion and failure effects must respect attempt and location ownership. Same-location weather retention and the accepted visible weather decision must remain coherent across Today sections. Alert-specific failure is distinct from an unrelated refresh failure; Outlook retains eligible cached rows or accepted-empty evidence rather than treating a failed empty result as quiet.

[North Star](../product/north-star.md) owns product meaning; [States and Accessibility](../design/states-accessibility.md), [Today design](../design/today.md) and [Map design](../design/map.md) own visual state, restrained motion, copy and accessibility treatment. Do not duplicate these requirements or use UI transitions to repair acceptance defects.

## Reactive consumers

Accepted feed generations are invalidation hints. Reread the relevant provider/repository; the event is not domain data, a new network success, or proof that a consumer replacement is already ready.

### Map

[MapScreenView](../../Sources/Features/Map/MapScreenView.swift) subscribes while visible and scene-active, schedules an initial reload, and cancels observation/reload work on exit. [MapAcceptedUpdateScope](../../Sources/Features/Map/MapAcceptedUpdateScope.swift) maps accepted feed identities to affected render inputs:

- Current convective and fire feeds affect their respective thematic plans.
- Future-day categorical and hazard feeds affect only their supported forecast selections.
- Arcus alert acceptance affects warning overlays; coherent Home hot acceptance affects meso and warning inputs.
- Unrelated feeds do not invalidate Map.

[MapFeatureModel](../../Sources/Features/Map/MapFeatureModel.swift) rejects duplicate/older observed generations, unions pending scopes and fences staged replacement by input revision, cancellation and pending reload. Read only affected inputs for scoped invalidation; full reloads remain explicit. Publish affected plans together, preserving unaffected materialized scenes and the current accepted scene during resolution. Failed/cancelled reads preserve applicable prior content; accepted empty may clear it. Equivalent plan content need not rematerialize unchanged scenes. Preserve selection and camera independently of acquisition/replacement.

SPC geometry and warning reads use canonical local queries. The current Arcus meso query is an exception to a universally cache-only Map path: it can acquire over HTTP and requires live/revalidated collection evidence for replacement. Visible foreground refresh generation may also trigger a dedicated meso reload. Do not claim all Map reloads or entry navigation are network-free. Exact forecast support, meso lifecycle and scene materialization rules are feature-owned.

### Cached detail

[ReconciledAlertDetailView](../../Sources/Features/Alert/ReconciledAlertDetailView.swift) seeds from the selected cached alert DTO, subscribes to relevant acceptance events and immediately reconciles against the canonical local repository to cover changes since selection. Replace only the same stable identity with a newer versioned revision (including a versioned replacement for an unversioned seed). Absent, mismatched, older/equal or unversioned candidates retain the detail. View-scoped cancellation prevents further replacement. Do not add navigation-time network acquisition or a duplicate reconciliation path.

An outlook detail represents the selected issuance, not an automatically rolling latest discussion. Keep its identity stable when the accepted collection changes. Alert revision reconciliation and selected outlook issuance are intentionally different contracts.

## Observation efficiency

The current Home query uses a sorted retained-projection population and selects the matching current record and newest display-ready fallback in memory. It is not a two-row database predicate. Explicit retention bounds the useful retained population while protecting active and fallback records (see projection retention above); the query itself does not enforce a strict total-row cap. The original query-narrowing target in #455 was replaced by this implementation; do not require a speculative rewrite without evidence.

Sample the projection-derived observation once per body evaluation, sharing the sampled value with rendering and acceptance callbacks. Record conversion can decode persisted Storm Setup enrichment; avoid repeated conversions rather than adding a competing conversion cache. Preserve payload-only updates even when revision timestamps do not change.

Avoid reading discarded transient pipeline payloads in production presentation construction: Observation registers dependencies on reads even if a later branch discards the values. Gate static-test-only reads at the call site, preserve meaningful accepted revision and activity dependencies, and avoid broader view boundaries or new caches without measurement.

The [projection sampling audit (#805)](../audits/2026-10-30-home-projection-sampling.md) and [Observation breadth audit (#810)](../audits/2026-10-30-home-observation-breadth.md) record the bounded replay and hosted-view evidence supporting these decisions. They do not establish production device latency or prove that a visible hitch was fixed. Keep measurements, fixtures, methods and limitations in those records.

## Historical rationale and evidence

The following records preserve decisions and historical validation, including later supersessions:

- [Architecture recovery](../audits/codebase-architecture-recovery.md): original ownership, identity, task boundaries, cancellation and projection transaction findings.
- [Simplification runbook](../plans/codebase-simplification-runbook.md) and [progress](../plans/codebase-simplification-progress.md): #332–336 waiter characterization, cancellation, bounded drain and explicit atomic core transaction decisions.
- [SPC map stability playbook](../plans/spc-map-ingestion-stability-playbook.md) and [progress](../plans/spc-map-ingestion-stability-progress.md): staged validation, independent domain acceptance, transactional replacement and rejection preservation. Later source changes supersede broad original empty/future-window rules.
- [Cache acceptance runbook](../plans/ingestion-cache-acceptance-runbook.md) and [progress](../plans/ingestion-cache-acceptance-progress.md): typed outcomes, coherent hot acceptance, projection acknowledgement and persistence-gated publication. [Epic #425](https://github.com/justinrooks/project-arcus/issues/425) and all nine children are closed completed; historical pending labels do not describe current status.
- [Feed-state/provenance runbook](../plans/ingestion-feed-state-provenance-runbook.md) and [progress](../plans/ingestion-feed-state-provenance-progress.md): metadata-only sidecar, acceptance generation and transport provenance. [Epic #426](https://github.com/justinrooks/project-arcus/issues/426) and all four children are closed completed.
- [Durable scheduling runbook](../plans/ingestion-durable-scheduling-runbook.md) and [progress](../plans/ingestion-durable-scheduling-progress.md): independent durable admission, interrupted-attempt recovery and per-feed fallback rationale. [Epic #423](https://github.com/justinrooks/project-arcus/issues/423) and all four children are closed completed. Historical pending states and schema references describe the original campaign, not current schema or implementation status.
- [Today state-flow runbook](../plans/today-state-flow-runbook.md) and [progress](../plans/today-state-flow-progress.md): cache roll-forward, shared visible weather, coherent partial arrival and restrained transitions. Later atomic-presentation work supersedes earlier implementation details.
- [Reactive consumers runbook](../plans/ingestion-reactive-consumers-runbook.md) and [progress](../plans/ingestion-reactive-consumers-progress.md): accepted-generation invalidation, actual retained-query implementation, explicit retention and alert revision reconciliation. [Epic #424](https://github.com/justinrooks/project-arcus/issues/424) and its five children are closed completed. #450's device traces and separate recordings do not establish every requested latency or network-count claim.
- [UI coherence runbook](../plans/ingestion-ui-coherence-runbook.md) and [progress](../plans/ingestion-ui-coherence-progress.md): atomic visible revision, independent activity and motion after state correctness. [Epic #422](https://github.com/justinrooks/project-arcus/issues/422) is closed completed; [#463](https://github.com/justinrooks/project-arcus/issues/463) was closed as a duplicate of #451, not a second implementation. [#460](https://github.com/justinrooks/project-arcus/issues/460) narrowed final validation, removing mandatory Instruments and automated physical-device orchestration. Preserve the recorded failed, incomplete and zero-test attempts alongside finalized passing evidence.
- [Today performance runbook](../plans/today-refresh-performance-runbook.md): hot priority, core-before-enrichment, and preserved ownership boundaries.
- [Background reliability runbook](../plans/background-refresh-reliability-runbook.md): background owner lifetime, cancellation, scheduler budgets and location-reuse rationale.
- [Execution policy runbook](../plans/ingestion-execution-policy-runbook.md) and [progress](../plans/ingestion-execution-policy-progress.md): explicit execution class, scoped HTTP policy, prime reuse, parallel NWS labels and deferred foreground durable reuse. [Epic #421](https://github.com/justinrooks/project-arcus/issues/421) and its five children are closed completed; the historical planned/pending labels are not current implementation status.

Representative current test definitions are in [HomeIngestionCoordinatorTests](../../Tests/UnitTests/HomeIngestionCoordinatorTests.swift), [HomeRefreshPipelineTests](../../Tests/UnitTests/HomeRefreshPipelineTests.swift), [RemoteHotAlertHandlerTests](../../Tests/UnitTests/RemoteHotAlertHandlerTests.swift), [background reuse tests](../../Tests/UnitTests/BackgroundLocationContextReusePolicyTests.swift), and [foreground reuse tests](../../Tests/UnitTests/ForegroundDurableContextReusePolicyTests.swift). Persistence regression definitions include [HomeProjectionStoreTests](../../Tests/UnitTests/HomeProjectionStoreTests.swift), [SpcProviderSyncMapProductsTests](../../Tests/UnitTests/SpcProviderSyncMapProductsTests.swift), and [WSSI accepted-store tests](../../Tests/UnitTests/WSSIAcceptedStoreTests.swift). [WSSI local retention evidence](../validation/wssi-local-retention.md) records measured workload limits. Durable metadata and transport regression definitions include [FeedStateStoreTests](../../Tests/UnitTests/FeedStateStoreTests.swift), [HTTPDataDownloaderTests](../../Tests/UnitTests/HTTPDataDownloaderTests.swift) and the Home pipeline and SPC suites above (reopen, interrupted attempts, independent admission, fallback, cancellation and deferred validity). Presentation regression definitions include [HomeViewStateTests](../../Tests/UnitTests/HomeViewStateTests.swift), [TodayContentStateTests](../../Tests/UnitTests/TodayContentStateTests.swift), [MapFeatureModelSceneTests](../../Tests/UnitTests/MapFeatureModelSceneTests.swift) and [AlertDetailReconciliationTests](../../Tests/UnitTests/AlertDetailReconciliationTests.swift). Historical ledgers record executed checks and their limitations; these links do not claim new test execution. [#346](https://github.com/justinrooks/project-arcus/issues/346) retired the universal physical-device profiling campaign without converting incomplete traces into performance evidence. Use targeted validation for concrete questions.

