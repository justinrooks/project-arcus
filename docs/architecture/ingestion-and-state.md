# Ingestion and State

This document describes SkyAware's Home ingestion, acceptance, persistence, freshness, and presentation ownership. Start with the [client architecture overview](README.md) for system composition.

**Reconciliation scope:** the execution and coordination contract below has been reviewed against current source and historical decisions. Detailed acceptance, persistence, freshness, projection, and feature-specific contracts are still being reconciled. Consult their existing source and historical evidence until those sections are reviewed; this document does not supersede that material wholesale.

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

## Historical rationale and evidence

The following records preserve decisions and historical validation, including later supersessions:

- [Architecture recovery](../audits/codebase-architecture-recovery.md): original ownership, identity, task boundaries and cancellation findings.
- [Simplification runbook](../plans/codebase-simplification-runbook.md) and [progress](../plans/codebase-simplification-progress.md): #332–335 waiter characterization, cancellation and bounded drain decisions.
- [Today performance runbook](../plans/today-refresh-performance-runbook.md): hot priority, core-before-enrichment, and preserved ownership boundaries.
- [Background reliability runbook](../plans/background-refresh-reliability-runbook.md): background owner lifetime, cancellation, scheduler budgets and location-reuse rationale.
- [Execution policy runbook](../plans/ingestion-execution-policy-runbook.md) and [progress](../plans/ingestion-execution-policy-progress.md): explicit execution class, scoped HTTP policy, prime reuse, parallel NWS labels and deferred foreground durable reuse. [Epic #421](https://github.com/justinrooks/project-arcus/issues/421) and its five children are closed completed; the historical planned/pending labels are not current implementation status.

Representative current test definitions are in [HomeIngestionCoordinatorTests](../../Tests/UnitTests/HomeIngestionCoordinatorTests.swift), [HomeRefreshPipelineTests](../../Tests/UnitTests/HomeRefreshPipelineTests.swift), [RemoteHotAlertHandlerTests](../../Tests/UnitTests/RemoteHotAlertHandlerTests.swift), [background reuse tests](../../Tests/UnitTests/BackgroundLocationContextReusePolicyTests.swift), and [foreground reuse tests](../../Tests/UnitTests/ForegroundDurableContextReusePolicyTests.swift). Historical ledgers record executed checks and their limitations; these links do not claim new test execution. [#346](https://github.com/justinrooks/project-arcus/issues/346) retired the universal physical-device profiling campaign without converting incomplete traces into performance evidence. Use targeted validation for concrete questions.

