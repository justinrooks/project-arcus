# Ingestion and State

This document describes SkyAware's Home ingestion, acceptance, persistence, freshness, and presentation ownership. Start with the [client architecture overview](README.md) for system composition.

**Reconciliation scope:** the execution, coordination, canonical acceptance and persistence contracts below have been reviewed against current source and historical decisions. Detailed freshness, presentation arbitration, reactive consumers and feature-specific contracts are still being reconciled. Consult their existing source and historical evidence until those sections are reviewed; this document does not supersede that material wholesale.

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

These are application policies, not execution guarantees from iOS. Expiration, cancellation, or insufficient remaining budget must stop discretionary background work. Preserve hot-alert priority, foreground-only AQI, and bounded admission of optional Storm Setup enrichment; their detailed acquisition and acceptance rules belong with the respective feature contracts. WSSI background assessment reads accepted local data rather than starting background acquisition.

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

Optional enrichment has its own persistence boundary. AQI preserves eligible same-location state on skip, failure or unavailable persistence, and publishes replacement only from the accepted returned record. Older AQI observations cannot replace newer persisted observations. Do not introduce a live-only AQI fallback after a failed save. Storm Setup, WSSI and derived consumer publication have their own feature-specific acceptance rules.

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

## Historical rationale and evidence

The following records preserve decisions and historical validation, including later supersessions:

- [Architecture recovery](../audits/codebase-architecture-recovery.md): original ownership, identity, task boundaries, cancellation and projection transaction findings.
- [Simplification runbook](../plans/codebase-simplification-runbook.md) and [progress](../plans/codebase-simplification-progress.md): #332–336 waiter characterization, cancellation, bounded drain and explicit atomic core transaction decisions.
- [SPC map stability playbook](../plans/spc-map-ingestion-stability-playbook.md) and [progress](../plans/spc-map-ingestion-stability-progress.md): staged validation, independent domain acceptance, transactional replacement and rejection preservation. Later source changes supersede broad original empty/future-window rules.
- [Cache acceptance runbook](../plans/ingestion-cache-acceptance-runbook.md) and [progress](../plans/ingestion-cache-acceptance-progress.md): typed outcomes, coherent hot acceptance, projection acknowledgement and persistence-gated publication. [Epic #425](https://github.com/justinrooks/project-arcus/issues/425) and all nine children are closed completed; historical pending labels do not describe current status.
- [Today performance runbook](../plans/today-refresh-performance-runbook.md): hot priority, core-before-enrichment, and preserved ownership boundaries.
- [Background reliability runbook](../plans/background-refresh-reliability-runbook.md): background owner lifetime, cancellation, scheduler budgets and location-reuse rationale.
- [Execution policy runbook](../plans/ingestion-execution-policy-runbook.md) and [progress](../plans/ingestion-execution-policy-progress.md): explicit execution class, scoped HTTP policy, prime reuse, parallel NWS labels and deferred foreground durable reuse. [Epic #421](https://github.com/justinrooks/project-arcus/issues/421) and its five children are closed completed; the historical planned/pending labels are not current implementation status.

Representative current test definitions are in [HomeIngestionCoordinatorTests](../../Tests/UnitTests/HomeIngestionCoordinatorTests.swift), [HomeRefreshPipelineTests](../../Tests/UnitTests/HomeRefreshPipelineTests.swift), [RemoteHotAlertHandlerTests](../../Tests/UnitTests/RemoteHotAlertHandlerTests.swift), [background reuse tests](../../Tests/UnitTests/BackgroundLocationContextReusePolicyTests.swift), and [foreground reuse tests](../../Tests/UnitTests/ForegroundDurableContextReusePolicyTests.swift). Persistence regression definitions include [HomeProjectionStoreTests](../../Tests/UnitTests/HomeProjectionStoreTests.swift), [SpcProviderSyncMapProductsTests](../../Tests/UnitTests/SpcProviderSyncMapProductsTests.swift), and [WSSI accepted-store tests](../../Tests/UnitTests/WSSIAcceptedStoreTests.swift). [WSSI local retention evidence](../validation/wssi-local-retention.md) records measured workload limits. Historical ledgers record executed checks and their limitations; these links do not claim new test execution. [#346](https://github.com/justinrooks/project-arcus/issues/346) retired the universal physical-device profiling campaign without converting incomplete traces into performance evidence. Use targeted validation for concrete questions.

