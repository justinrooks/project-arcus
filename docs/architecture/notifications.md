# Notifications

SkyAware owns local weather-awareness notification evaluation, remote-product convergence and explicit-open presentation. Timely server alert delivery is backend-owned. Read [Ingestion and State](ingestion-and-state.md) for accepted evidence, [Location and Lifecycle](location-and-lifecycle.md) for execution opportunities, and [installation enrollment](../security/installation-enrollment.md) for subscription, consent and protocol safeguards. [North Star](../product/north-star.md) and [Brand and Voice](../brand/brand-and-voice.md) own product meaning and communication; composers own current implementation copy.

## Delivery ownership

| Surface | Checked-in owner |
| --- | --- |
| Remote NWS alerts | Signal/APNs; client consumes accepted product identity. |
| Remote mesos | Signal/APNs following acknowledged delivery ownership. |
| Local meso fallback | SkyAware while enabled and server ownership is not acknowledged. |
| Morning summary and risk profile changes | SkyAware background orchestration. |
| Local watch compatibility | SkyAware background location-change evaluation. |
| Remote receipt, widgets and explicit-open navigation | SkyAware. |

Signal and ArcusCore are deprecated, not necessarily decommissioned. Forge is the strategic successor; see the [Arcus ecosystem](https://github.com/justinrooks/Prompt_Fu/blob/main/docs/arcus/README.md). Do not infer live routing, accepted targeting, duplicate-free handoff or APNs receipt from checked-in client compatibility. Server targeting, revision policy, queues and operational delivery belong to their backend owners.

## Local notification architecture

The local engines separate rule (meaningful occurrence), gate (claim/dedupe), composer (message) and sender (OS scheduling). Repositories acknowledge accepted evidence; the ingestion executor returns it; orchestration owns notification side effects. Ordinary foreground refresh does not send local risk-change notifications. Scheduled work and eligible background movement are opportunistic, not alarm clocks.

[NotificationClaimState](../../Sources/Interfaces/Notification/NotificationGating.swift) serializes claims and stamp persistence. Reserve an occurrence before awaiting the sender; release unsuccessful claims and persist successful scheduling. Morning and meso retain the latest stamp; watch retains its observed delivered identities. Risk changes have a separate durable occurrence gate. These are local best-effort safeguards, not transactional exactly-once presentation guarantees across process death.

[NotificationManager](../../Sources/Notifications/NotificationManager.swift) checks OS authorization at send; authorized, provisional and ephemeral can schedule, denied cannot. Its undetermined branch can request authorization. Do not claim every existing background send path is nonprompting. Success means iOS accepted a local notification request, not confirmed user-visible delivery.

[SettingsView](../../Sources/Features/Settings/SettingsView.swift) derives effective preference state from stored user intent and OS authorization without overwriting stored preferences on denial. [Notification settings provider](../../Sources/App/Dependencies.swift) defaults morning, meso and risk changes to enabled, winter opt-in and server meso ownership to false. Server ownership is acknowledgment evidence, not user intent. APNs registration and installation consent remain separate.

## Morning summary

[AmRangeLocalRule](../../Sources/Notifications/Morning/AmRangeLocalRule.swift) uses the local calendar day and default 07:00–11:00 exclusive-end window. The rule supports quiet hours, but production orchestration currently supplies nil. A known SPC issuance older than 24 hours is rejected; absent issuance metadata is allowed by the rule. Normal production SPC summary requires the complete location-scoped storm/severe/fire combination. This is not a guarantee of a specific issuance or delivery time. [MorningGate](../../Sources/Notifications/Morning/MorningGate.swift) uses one latest local-day stamp for successful scheduling, with unsuccessful claims retryable.

[BackgroundOrchestrator](../../Sources/Features/Background/BackgroundOrchestrator.swift) offers a local accepted winter assessment read alongside ingestion when morning and winter preferences/window permit. Never await that optional read on the normal SPC delivery path. A ready applicable assessment may enrich the summary; if SPC is unavailable, a winter-only attempt can use the remaining bounded work window, including an accepted point without NWS context. Independent meso/risk delivery gets its opportunity before a later winter-only read. Winter acquisition is not a prerequisite and is disabled in production background composition. See [winter source selection](feature-data-contracts.md#wssi-and-winter-impacts) for domain eligibility.

[MorningEngine](../../Sources/Notifications/Morning/MorningEngine.swift) claims the daily occurrence, then reauthorizes and reevaluates at delivery time. Preserve cancellation, deadline, current morning preference, local-day/window, winter preference, exact accepted-point and source-expiry checks. Remove ineligible winter content without unnecessarily suppressing eligible SPC; a winter-only result with no remaining applicable impact must release its claim. Both summary forms share the daily gate. [MorningComposer](../../Sources/Notifications/Morning/MorningComposer.swift) uses source-period timing for winter and generic title when place is unavailable; do not label winter-only guidance with unrelated SPC issuance.

## Accepted risk transitions

[HomeProjectionStore](../../Sources/Repos/HomeProjectionStore.swift) owns atomic comparison and persistence. The acknowledged delta travels through the shared ingestion snapshot; never derive delivery from transient provider values. Convective and fire baselines are independent. For each eligible domain compare the accepted source identity and H3 comparison location (not the full projection key):

- Same location, changed source: forecast transition.
- Changed location, same source: location transition.
- Both changed, missing source/baseline or incomplete comparable dimension: establish baseline rather than attribute a change.
- Foreground observe-only acceptance advances observed evidence without consuming the background delivery baseline; retained Day 1 reprojection has its own observe-only boundary. Only applicable accepted updates in evaluation mode advance comparison and produce eligible dimensions.

Preserve meaningful storm, severe hazard/whole-percent probability and fire transitions, including upgrades, downgrades, mixed changes and later reversions. Batch eligible changed dimensions from one accepted occurrence, not unrelated runs. [RiskChangeRule](../../Sources/Notifications/RiskChange/RiskChangeRule.swift) identifies an occurrence by projection and occurrence ID; a previously seen risk value is not a permanent dedupe key.

[RiskChangeGate](../../Sources/Notifications/RiskChange/RiskChangeGate.swift) owns pending occurrences, in-flight claims and delivered tombstones. Register before delivery, even if disabled; supersede older non-in-flight pending work for the same projection, discard non-in-flight work outside the active comparison location when supplied, and purge pending entries older than 24 hours. Failed scheduling retains eligible pending work unless superseded/expired. Successful scheduling replaces pending with a tombstone; bound delivered tombstones to 128. A later eligible attempt may claim older pending work without a new delta.

Morning may include the current eligible risk change when its independent preference is enabled. Only successful morning scheduling coalesces that occurrence (and retires older applicable pending work for the projection); failed scheduling leaves standalone risk delivery eligible. A successful morning without a current change does not suppress an older pending occurrence. Preserve coalescing before cancellation checks following successful scheduling. Background movement evaluates risk after the watch path; ordinary scheduled work evaluates after morning and local meso fallback. Do not claim all preference or cancellation races are recallable after OS scheduling begins.

Historical [risk-change runbook](../plans/risk-profile-change-notifications-runbook.md) / [progress](../plans/risk-profile-change-notifications-progress.md) ([#100](https://github.com/justinrooks/project-arcus/issues/100), #308–312 closed completed) preserve original rationale and evidence. The current domain/source/H3 comparison and durable occurrence model supersede original per-projection fingerprint guidance.

## Meso and watch compatibility

[MesoEngine](../../Sources/Notifications/Meso/MesoEngine.swift) evaluates local fallback only if enabled and server delivery ownership is not acknowledged. The scheduled orchestrator rereads current settings before evaluation; the engine rechecks permission/ownership through its delivery callback after gate admission. Release the claim if ownership changes. [MesoRule](../../Sources/Notifications/Meso/MesoRule.swift) selects the most recently issued eligible meso and keys by local day and product number. This remains compatibility behavior until explicit removal, not the long-term delivery strategy.

[BackgroundLocationChangeHandler](../../Sources/Features/Background/BackgroundLocationChangeHandler.swift) invokes [WatchEngine](../../Sources/Notifications/Watch/WatchEngine.swift) then risk evaluation on an eligible location snapshot after shared ingestion. [WatchRule](../../Sources/Notifications/Watch/WatchRule.swift) chooses the newest non-update alert with end after now from the supplied collection, with stable-ID tie breaking. The watch gate dedupes alert identity; do not assume a separate watch-specific preference or a fully transferred delivery owner. [#760](https://github.com/justinrooks/project-arcus/issues/760) remains open for location-change meso/watch/warning verification without local duplicates. Do not retire fallback based on source compatibility alone.

## Remote receipt and navigation

[AppDelegate](../../Sources/App/SkyAwareAppDelegate.swift) and [RemoteHotAlertHandler](../../Sources/App/RemoteHotAlertHandler.swift) distinguish background receipt from explicit open. Validate typed ArcusCore product identity (NWS alert or meso); preserve supported legacy NWS payload decoding but do not reinterpret invalid typed identity as legacy. Receipt with unsupported payload completes noData; unavailable startup returns failed. Explicit open can be retained until Home is ready; the latest eligible intent wins.

Receipt uses a 25-second application budget with two seconds reserved for completion. [Shared ingestion](ingestion-and-state.md) retains independent waiter ownership; receipt watchdog completes once and cancels its work. Accepted matching canonical alert revision establishes newData or noData relative to prior accepted product; missing/mismatched evidence fails. Meso receipt resolves accepted product identity before hot convergence. A previously established accepted result survives subsequent convergence/widget failure or watchdog expiry. Targeted product acceptance does not certify a coherent location hot collection or new risk assessment. Remote widget publication uses accepted projection evidence and its own publication scope; see [Widgets](feature-data-contracts.md#widgets).

Explicit open resolves the requested product, fences superseded navigation by open identity, and publishes focus (including unresolved identity when detail is unavailable). It is not receipt-budgeted work or permission to select an unrelated product. Preserve cache-seeded local detail reconciliation and accepted widget ordering. APNs receipt, canonical acceptance, UI focus and user-visible notification delivery are different boundaries.

### Evidence and historical material

Representative tests: [Morning](../../Tests/UnitTests/MorningNotificationTests.swift), [Risk Change](../../Tests/UnitTests/RiskChangeNotificationTests.swift), [Meso](../../Tests/UnitTests/MesoNotificationTests.swift), [Alert](../../Tests/UnitTests/AlertNotificationTests.swift), [Background orchestration](../../Tests/UnitTests/BackgroundOrchestratorCadenceTests.swift), [Remote receipt/open](../../Tests/UnitTests/RemoteHotAlertHandlerTests.swift) and [Registration](../../Tests/UnitTests/RemoteNotificationRegistrarTests.swift). These identify regression contracts, not new execution evidence. [Preference authorization plan](../superpowers/plans/2026-06-10-notification-preference-authorization.md) is historical implementation material. [April 2026 notification strategy](timely-notifications-strategy.md) describes a prior Signal backend investigation, not current client or server authority. Preserve its rationale pending backend reconciliation rather than transferring unchecked claims. Physical-device scheduling, live APNs delivery, server handoff and duplicate-free notification behavior remain separate validation concerns.
