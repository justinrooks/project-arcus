# Feature Data Contracts

This document owns SkyAware-specific acquisition, acceptance and consumer invariants for specialized features. Read [Ingestion and State](ingestion-and-state.md) for the shared execution, persistence, freshness and reactive presentation model, and the [architecture overview](README.md) for composition and integration ownership. [North Star](../product/north-star.md) owns product meaning; the [Design System](../design/README.md) owns visual behavior. Backend wire contracts and scientific methodology remain with their owning repositories.

- [Storm Setup](#storm-setup)
- [Air quality](#air-quality)
- [WSSI and Winter Impacts](#wssi-and-winter-impacts)
- [SPC forecasts and Map](#spc-forecasts-and-map)
- [Widgets](#widgets)
- [App Intents and accepted awareness](#app-intents-and-accepted-awareness)

## Storm Setup

[StormSetupHTTPClient](../../Sources/Clients/StormSetupClient.swift) consumes the Signal current aggregate as ArcusCore's `StormSetupCurrentResponse` in one eligible request with the signed decimal H3 cell. The checked-in integration still depends on Signal and ArcusCore despite their ecosystem deprecation; this is not evidence of migration completion. [HomeStormSetupIngestion](../../Sources/App/HomeRefreshV2/HomeStormSetupIngestion.swift) owns acquisition and acceptance, [HomeProjectionStore](../../Sources/Repos/HomeProjectionStore.swift) owns persisted aggregate bytes, and app-local DTOs, assessment and presentation models own user-facing interpretation, not a competing wire contract.

### Admission and ownership

[StormSetupPreferences and policies](../../Sources/Models/StormSetup/StormSetupPreferences.swift) distinguish automatic fetch from display. The main opt-in defaults off; Detailed Ingredients remains stored while disabled and becomes effective only with the main opt-in. Detailed Ingredients forces automatic eligibility/display when applicable, not a second profile-analysis request.

Automatic fetch requires enablement and no unexpired matching cached guidance, plus marginal-or-higher categorical risk, non-clear severe risk, qualifying convective alert, active meso or effective Detailed Ingredients. [Alert eligibility](../../Sources/Models/StormSetup/StormSetupAlertEligibility.swift) recognizes issued, unexpired tornado and severe thunderstorm watches and warnings. Full guidance requires enabled, unexpired analysis and a known assessment value, with supportive/strong signal, qualifying alert, active meso or effective Detailed Ingredients. Do not conflate a fetch trigger with a display trigger.

User-initiated acquisition requires enablement and applicable location/persistence/query seams but bypasses automatic eligibility, fresh-cache suppression and automatic failure backoff. It uses the dedicated [pipeline manual path](../../Sources/App/HomeRefreshPipeline.swift), not a full Home refresh. Pipeline activity guards suppress duplicate visible actions; the ingestion actor coalesces same-projection compatible waiters and can queue manual intent behind automatic work. Independent cancellation releases a waiter; cancel the owned query when no waiters remain. Fence visible completion by attempt and context.

Core publication precedes optional enrichment. Storm Setup and AQI execute as structured children with independent outcomes; Storm Setup has separate start/finish publication, while the final combined enrichment result may await both. Background enrichment is discretionary and admits only within the remaining shared budget (current minimum admission estimate: five seconds). This is not a guaranteed completion time.

### Deadline, ordering and persistence

- Foreground transport and the owned query race use a 30-second deadline. A structured task group would wait for a non-cooperative cancelled query; the specific owned race releases the caller on its winning completion and prevents the losing response from accepting. Do not generalize this exception into detached enrichment work.
- Automatic failed-attempt backoff is five minutes for background/session-tick provenance. Manual intent bypasses it; cancellation does not establish a normal failed-attempt marker. These attempt records are process-local, not a durable feed-admission guarantee.
- Require matching response H3. Compare model run time, source valid time and fetched time in order, with missing evidence losing to present evidence. Older/equal responses retain the accepted value; a stale response can report operation success while recording failed-attempt backoff.
- Persist a newer aggregate through the projection store before presenting it as accepted. Persistence failure retains eligible fresh cached guidance, not live-only replacement. Recheck cache expiry after waiting; never use expired guidance to conceal failure or avoid a visual transition.
- `profileAnalysis == nil` is a valid aggregate outcome. Never splice an older profile into a newer response. Keep numeric SHIP from the profile; do not synthesize categorical support from it or derive Primary Drivers from unrelated viability fields. Preserve shared tagged-enum decoding and app-owned confidence terminology (ArcusCore moderate maps to user-facing medium).

[StormSetupPresentation](../../Sources/Features/StormSetup/StormSetupPresentation.swift) preserves the enabled section identity: distinguish analyzing (actual work), not analyzed (no usable result without a completed failing outcome), fresh displayable guidance, fresh suppressed guidance, analysis not needed and unavailable. Fresh displayable cache wins over analyzing; unavailable location or disabled preference hides the ordinary section. Fixture-specific forced presentation is not a production acquisition authority. Follow [Today design](../design/today.md) for rendering.

Rationale and historical validation: [aggregate migration](../plans/storm-setup-contract-migration-runbook.md) / [progress](../plans/storm-setup-contract-migration-progress.md) ([#283](https://github.com/justinrooks/project-arcus/issues/283)); [summary stability](../plans/storm-setup-summary-stability-runbook.md) / [progress](../plans/storm-setup-summary-stability-progress.md) ([#411](https://github.com/justinrooks/project-arcus/issues/411)); [original Storm Setup runbook](../plans/storm-setup-runbook.md). Earlier quiet-day hiding, separate profile requests and single-development-device cache deletion advice are superseded, not current architecture or migration policy. Tests: [ingestion](../../Tests/UnitTests/StormSetupIngestionTests.swift), [policy](../../Tests/UnitTests/StormSetupPolicyTests.swift), [mapping](../../Tests/UnitTests/StormSetupMappingTests.swift), [presentation](../../Tests/UnitTests/StormSetupPresentationTests.swift).

## Air quality

[AQI acquisition](../../Sources/App/HomeRefreshV2/HomeIngestionExecutor.swift) through [AirQualityClient](../../Sources/Clients/AirQualityClient.swift) is optional, location-scoped, foreground weather-lane work. `alwaysShowAirQuality` is a presentation preference, not an acquisition gate. AQI does not run in background, in a hot-only session tick, or as a prerequisite for accepted core publication.

[HomeProjectionStore](../../Sources/Repos/HomeProjectionStore.swift) persists primitive optional fields and reconstructs the shared response. Older observedAt cannot replace a newer observation. Preserve non-AQI slices and their acceptance times. Skip, nil, failure, cancellation, unavailable persistence and failed save preserve eligible same-location content. Only publish replacement from the response returned by durable storage, which may be the newer previously accepted value. Location changes cannot borrow previous-location AQI.

AQI and Storm Setup outcomes remain independent; failure of either does not invalidate the other or the core. The [cache-forward campaign](../plans/air-quality-cache-forward-runbook.md) / [progress](../plans/air-quality-cache-forward-progress.md) ([#404](https://github.com/justinrooks/project-arcus/issues/404)) established these ownership and ordering requirements, but its live-only fallback after failed persistence and live-over-persisted presentation recommendations were superseded by [#425](https://github.com/justinrooks/project-arcus/issues/425) and atomic visible revisions. Preserve the current acceptance gate. Tests: [HTTP client](../../Tests/UnitTests/AirQualityHTTPClientTests.swift), [enrichment and failed-save regressions](../../Tests/UnitTests/StormSetupIngestionTests.swift), [projection store](../../Tests/UnitTests/HomeProjectionStoreTests.swift).

## WSSI and Winter Impacts

WSSI uses a separate optional Forge HTTPS origin, not the Signal origin or a Home projection field. [WinterImpactsRuntime / WSSIForeground](../../Sources/Providers/WSSI/WSSIForeground.swift), [WSSISync](../../Sources/Providers/WSSI/WSSISync.swift) and [WSSIAcceptedStore](../../Sources/Repos/WSSIAcceptedStore.swift) own admission, acquisition and independent accepted national geometry in the shared persistent container. Location-specific assessment is a subsequent local query, not a reason to download geometry for each location.

### Preference and execution

The unset preference is distinct from an explicit enable/disable choice; discovery is offered only after onboarding while undecided and not dismissed. Rapid preference changes use admission revision and serialized command fencing. Disable invalidates assessments and cancels acquisition. Eligible foreground offers coalesce; the sync actor serializes workloads and joins compatible execution budgets. A foreground offer can cancel a draining background workload but cannot start overlapping transport before it unwinds.

The [background lifecycle](../../Sources/App/BackgroundRefreshLifecycle.swift) supports optional WSSI work only after successful/skipped core outcome persistence and successor scheduling, using the original callback-entry budget. [SkyAwareApp](../../Sources/App/SkyAwareApp.swift) explicitly disables that production admission gate pending measured residual device time. Current background morning evaluation reads accepted local assessment without WSSI acquisition; do not infer activation from the existence of the tested background method. Cancellation and absolute deadlines fence acceptance. See [#917](https://github.com/justinrooks/project-arcus/issues/917) and the [background decision](../../.trail/learnings/2026-11-25-defer-wssi-background-acquisition-without-measured-justinrooks.md).

### Manifest, revisions and storage

[ForgeWSSIClient](../../Sources/Clients/ForgeWSSIClient.swift) uses exact origin/canonical immutable geometry paths and explicit network-backed revalidation, without a second HTTP payload cache or ordinary error fallback. [WSSISourceDecoder](../../Sources/Infrastructure/Parsing/GeoJSON/WSSISource.swift) validates a complete 15-identity manifest and geometry matching the advertised product/day/revision, source window, source metadata and coverage. Geometry requires valid nonempty features and appropriate polygon topology.

| Reconciliation evidence | Accepted-state behavior |
| --- | --- |
| Valid manifest body | Persist a new manifest generation. |
| Valid manifest 304 | Retain the accepted manifest; mismatched validator can trigger an unconditional recovery request. |
| Already accepted advertised revision | No geometry request. |
| New advertised revision | Sequentially fetch full body, validate against manifest and commit slot. |
| Unavailable advertisement or failed slot | Preserve prior accepted slot; record the local outcome separately. |
| Changed manifest generation | Reject superseded acceptance. |
| Same revision, conflicting metadata or bytes | Reject. |
| Earlier issuance | Reject. |
| Equal issuance, newer GIS file date | Accept only when the correction ordering rule is satisfied. |

Manifest acceptance is independent of geometry acceptance. A manifest can be durable even if some requests fail or never start. A slot transaction replaces its previous row in the same save; cancellation before commit and failed saves preserve accepted state. There is one manifest and at most 15 geometry rows (Overall Impact, Snow Amount, Snow Load, Ice Accumulation and Blowing Snow, each Days 1–3). Readers receive value snapshots. Expired bytes can remain for last-known-good recovery; validity limits use. No persisted staging, revision history, separate pruning service or WSSI-specific purge is justified by existing evidence.

### Assessment, coverage and refresh truth

[WSSIPointAssessment](../../Sources/Models/WSSI/WSSIPointAssessment.swift) evaluates each product/day independently using source validity (inclusive start, exclusive end). Future-valid periods retain their assessed impact without becoming current. Select the strongest matching severity; include exterior edges and exclude interior holes and their edges. Invalid point, unavailable geometry, disabled, match, unknown-coverage no-match and confirmed no-impact are distinct. A no-match supports confirmed no-impact only with independently verified coverage for the exact dataset/revision/point. The current production reader does not supply that proof; ordinary no-match remains unknown coverage. Do not infer quiet from absence of a polygon.

Accepted geometry/coverage, advertised Forge poll health/source status and local refresh outcomes are separate. A local manifest or slot failure can coexist with readable accepted geometry and healthy upstream status. Preserve the latest completed local outcome until a retry or admission reset; cancelled, disabled or superseded work does not publish a new report. Read accepted values through a fresh context, capturing status and its generation before suspension and rechecking generation, admission, preference and exact accepted location observation afterward. Do not pair old geometry with a newer local report. Geometry detail reads require the requested revision and unexpired source window; a new slot must not silently substitute for the selected revision.

See the [local outcome decision](../../.trail/learnings/2026-11-25-publish-local-wssi-refresh-outcomes-with-justinrooks.md) and [assessment read fence](../../.trail/learnings/2026-11-25-fence-wssi-assessment-reads-across-outcome-justinrooks.md).

### Common winter presentation

[WinterImpactsPresentation](../../Sources/Models/WSSI/WinterImpactsPresentation.swift) is the common interpretation of applicable accepted assessments for Today, detail and morning summary. Disabled, off-location, unavailable and expired remain distinguishable; recompute validity at presentation time. Hero eligibility is Overall Impact moderate on Day 1 or major/extreme on Days 1–2. Morning selection permits Overall Impact minor or greater across Days 1–3. The rail prefers matching Overall Impact for the chosen period, otherwise an affected component by earliest source start. Hero/morning choose strongest qualifying severity then earliest source window; independent retained slots can cross issuance boundaries, so do not use day number as a proxy for source chronology. The caller owns hero precedence and delivery admission; notification eligibility and timing belong to the notification contract.

### Evidence

[Local retention](../validation/wssi-local-retention.md) records disk reopen, five issuances across all slots, bounded logical bytes, SQLite/WAL allocation, cancellation and failed-save recovery. [Integrated device run](../validation/wssi-integrated-device-run.md) records one cold and one warm foreground workload after relaunch, with 15 accepted slots and no geometry requests on warm 304. This supports full-resolution geometry, sequential acquisition and bounded accepted slots; it establishes neither a background grant nor performance on smaller devices/larger issuances. Do not generalize logical geometry bytes into wire size or SQLite footprint. Tests: [source decoder](../../Tests/UnitTests/WSSISourceDecoderTests.swift), [accepted store](../../Tests/UnitTests/WSSIAcceptedStoreTests.swift), [sync and preference/assessment fencing](../../Tests/UnitTests/WSSISyncTests.swift).

## SPC forecasts and Map

[MapFeatureModel](../../Sources/Features/Map/MapFeatureModel.swift) retains source/day/layer selection identity independently from the ingestion run. Categorical forecasts support Days 1–3; tornado, wind and hail support Days 1–2; fire and meso are current-only. Active warnings are current-day overlays, not a future forecast. Preserve the warning preference while browsing future days and communicate its current-day scope (see [Map design](../design/map.md)). Future forecast persistence, browsing, validity rollover and Outlooks routing must not mutate current Day 1 assessment authority used by Today, widgets or notifications. Source issuance/validity determines applicability, not local midnight.

Preserve distinct unavailable, accepted-empty, stale and applicable accepted forecast states. Select supported day/layer pairs from accepted plans without rereading merely on selection; preserve camera and explicit Map/Outlooks navigation identity. The selected Outlook discussion is an issuance, not a live pointer to the latest text. [Days 1–3 integration evidence](../audits/spc-days-1-3-integration-validation.md) ([#698](https://github.com/justinrooks/project-arcus/issues/698), [#706](https://github.com/justinrooks/project-arcus/issues/706)) records the deterministic acceptance/reopen and isolation tests with manual device and rendered-performance limits. Closed issues do not prove the originally requested physical evidence was obtained.

### Rendering and measured decisions

[MapRenderPlan](../../Sources/Features/Map/MapRenderPlan.swift) separates value-based planning from main-actor materialization; accepted plans survive eviction of the two-scene day/layer LRU cache. Retain equivalent plans/scenes and materialize only visible/needed geometry after reuse checks; share polygon construction within a materialization. [MapPolygonMapper](../../Sources/Features/Map/MapPolygonMapper.swift) preserves valid exterior and interior geometry, including valid warning interiors, stable product/revision identity and deterministic coordinate fingerprints. Do not recover the historical warning-interior fixture limitation as a current rule.

| Historical investigation | Durable rationale |
| --- | --- |
| [Baseline and source scoping](../audits/map-efficiency-01-baseline.md) | Relevant accepted scopes avoid unrelated reads/builds; generation alone is not content identity. |
| [Critical path](../audits/map-efficiency-03-critical-path.md) | No further scheduling rewrite justified by measured fixtures; retain coherent publication and input-revision fences. |
| [Lazy materialization](../audits/map-efficiency-04-materialization.md) | Avoid discarded polygon allocations and hidden-warning construction; preserve overlay identity and new legend metadata. Cold-switch improvement was inconclusive. |
| [Bounded hatch drawing](../audits/map-efficiency-05-hatch-drawing.md) | Bound stripe candidates to renderer-space draw region with conservative clipping padding; preserve lattice, original endpoints, dash phase, even-odd holes and styling. |

[RiskPolygonRenderer](../../Sources/Features/Map/RiskPolygonRenderer.swift) owns actual hatch geometry. Avoid reintroducing whole-overlay hatch work per draw region; exact measurement fixtures and results remain in the audits. These bounded synthetic simulator measurements do not prove rendered or physical-device latency. Revisit scheduling, cache capacity or geometry complexity only with a concrete measured problem. Tests: [Map scene behavior](../../Tests/UnitTests/MapFeatureModelSceneTests.swift), [polygon mapping](../../Tests/UnitTests/MapPolygonMapperTests.swift), [renderer](../../Tests/UnitTests/RiskPolygonOverlayTests.swift). General invalidation and meso acquisition exceptions are in [Ingestion and State](ingestion-and-state.md#reactive-consumers).

## Widgets

Widgets consume an app-produced derived snapshot, not an independent acquisition pipeline. [WidgetSnapshotPublication / refresh coordinator](../../Sources/App/HomeRefreshV2/WidgetSnapshotRefreshCoordinator.swift) takes an accepted projection value and process-local publication order, builds with [WidgetSnapshotBuilder](../../Sources/App/HomeRefreshV2/WidgetSnapshotBuilder.swift), writes the shared App Group file through [WidgetSnapshotStore](../../Shared/WidgetSnapshotStore.swift), then reloads affected timelines only after successful publication.

Risk/location updates require applicable accepted risk evidence; hot updates require coherent hot acceptance. Normal Home widget refresh excludes remote APNs plans; the remote handler has a separate convergence/publication owner. Risk/location scope reloads all snapshot-backed kinds; active-alert scope reloads combined only. Missing publication or rejected/failed save must not generate a new accepted snapshot. Independently competing Home and remote writers use one per-destination process-local order fence across store instances and atomic whole-file replacement. Older orders (or an unordered replacement after ordered publication) cannot overwrite a newer successfully written snapshot. The fence advances on successful write, not failed attempt; WidgetKit reads without owning the writer.

Risk and alert freshness are separate (eight hours and 30 minutes respectively in [WidgetSnapshot](../../Shared/WidgetSnapshot.swift)). Carry domain acceptance timestamps, including the applicable accepted Day 1 assessment, through publication; file regeneration does not intrinsically renew them. The current builder has generated-time fallbacks for absent risk timestamps: do not treat these as explicit source acceptance evidence or bypass production publication gates. Filter expired events and rank warnings ahead of watches and mesos, then hazard, issuance and stable identity. A missing/corrupt file is unavailable, not authoritative quiet.

[WidgetCombinedTimeline](../../Shared/WidgetCombinedTimeline.swift) derives future expiry entries from the same accepted snapshot, coalescing nearby expirations without removing still-valid events early and bounding timeline entries. Timeline scheduling is not network acquisition or a guarantee of immediate system delivery. [Widgets design](../design/widgets.md) owns presentation and accessibility; [widget builder](../../Tests/UnitTests/WidgetSnapshotBuilderTests.swift), [publication coordinator](../../Tests/UnitTests/WidgetSnapshotRefreshCoordinatorTests.swift), [snapshot store](../../Tests/UnitTests/WidgetSnapshotStoreTests.swift) and [snapshot behavior](../../Tests/UnitTests/WidgetSnapshotTests.swift) test the data boundary.

## App Intents and accepted awareness

[GetWeatherAwarenessIntent](../../Sources/App/GetWeatherAwarenessIntent.swift) reads and formats the latest accepted assessment without opening the app UI, constructing the normal dependency graph, opening SwiftData, requesting location authorization or refreshing weather. It does not check the invocation's current location. The app-owned [WeatherAwarenessSnapshotStore](../../Sources/Repos/WeatherAwarenessSnapshotStore.swift) is distinct from the widget App Group file: Application Support, versioned file name, atomic bounded JSON (256 KiB), read-only invocation and typed missing/corrupt/read-failure outcomes.

[HomeProjectionStore](../../Sources/Repos/HomeProjectionStore.swift) selects the applicable canonical projection and reserves a monotonic revision before yielding to the independent file actor. Accepted slow-product or hot-load evidence can establish an awareness assessment; location, weather or enrichment saves alone cannot. Retain the prior explicitly last-assessed scope until the new scope accepts applicable awareness data. On startup, restore only a saved projection identity if still eligible and no newer commit already owns selection; rebuild values from canonical data. The awareness publisher fences older revisions even when a newer write fails (unlike the widget successful-write fence). A failed derived-file write does not roll back canonical acceptance.

[WeatherAwarenessSnapshot](../../Sources/Models/Home/WeatherAwarenessSnapshot.swift) and [WeatherAwarenessResult](../../Sources/Models/Home/WeatherAwarenessResult.swift) distinguish risk (eight-hour freshness window) and alert (30-minute window) acceptance. Never substitute invocation/file-write time for acceptance. Missing or future-dated evidence is unavailable; an optional expected key can reject mismatched saved scope but does not resolve location. Apply event issued/start/end validity at read time. State explicitly that the answer is for the last assessed location and current location was not checked.

Only current accepted alert assessment with no remaining time-valid events supports a scoped quiet statement; risk-only, missing or stale assessment cannot certify current alert absence. Prioritize time-valid official warnings/watches when the assessment is current. Stale time-valid events are historical evidence, not verified current alert status. Report missing individual risk values as unavailable, not synthesized quiet. Tests: [intent formatting](../../Tests/UnitTests/GetWeatherAwarenessIntentTests.swift), [assessment outcomes](../../Tests/UnitTests/WeatherAwarenessResultTests.swift), [publication and restore](../../Tests/UnitTests/HomeProjectionStoreTests.swift).

## Evidence boundaries

The linked regression definitions identify representative verification targets, not newly executed tests. Historical runbooks, progress records, issue/PR decisions and validation reports retain original scope, failed/incomplete attempts and measurements. Do not apply their superseded instructions as current authority. Location capture, process/OS lifecycle, delivery precedence, installation consent and server deployment remain separate contracts; consult the applicable source and current security guidance until those reviews are complete.
