# WSSI canonical acceptance contract

Issue: [#839](https://github.com/justinrooks/project-arcus/issues/839), epic [#833](https://github.com/justinrooks/project-arcus/issues/833). Defined from the follow-up investigation requested on November 11, 2026; the live probe crossed into November 12 UTC. The user accepted this contract as the implementation baseline. It deliberately revises the original all-layer source-publication requirement. The V8 storage and canonical acceptance coordinator described below are implemented. App integration, scheduling and presentation remain separate work.

## Decision

**Accept an atomic, complete, observed-stable regional snapshot of twenty independently identified WSSI layers. Preserve each layer's own source issuance and validity. Record an empty observation without inventing issuance, validity, or a forecast all-clear.**

“Atomic” describes SkyAware's durable replacement and readback. “Observed-stable” describes matching complete source reads. Neither claims NOAA publishes all twenty layers in a transaction. A local revision identifies a cache commit; it is never a NOAA generation identifier. The app may contain different source issuances across products and periods, explicitly represented as a vector of layer identities.

## Evidence and limits

- The [NOAA ArcGIS service](https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/wpc_wssi/MapServer?f=pjson) advertises two-hour updates, but exposes no common publication identifier. Captured service metadata has `supportsHistoricMoment=false`; layer 1 and layer 16 are neither versioned nor archived and have `supportsQueryWithHistoricMoment=false`. Esri's [query documentation](https://developers.arcgis.com/rest/services-reference/enterprise/query-map-service-layer/) restricts historical queries to appropriately enabled layers. These capabilities do not supply an atomic cross-layer snapshot.
- The follow-up probe made two sequential attribute-only reads of all twenty nationwide layers, bracketed by service/layer metadata retrieval: 43 HTTP responses, November 12, 2026, 01:33:05–01:33:19 UTC. Scan 1 had 13 nonempty responses, four empty responses, and three ArcGIS error bodies. Scan 2 had ten nonempty responses, three empty responses, and seven error bodies. All requests returned HTTP 200. These are incomplete research scans, not successful acquisitions. Their successful nonempty responses included both `2026-11-11 2116Z` and `2026-11-11 2316Z` across layers. Successful responses available in both scans matched; that does not establish stability for the failed layers or for geometry, which was not requested.
- The linked [WPC shapefile directory](https://www.wpc.ncep.noaa.gov/wwd/wssi/gis/shp/) and [WPC page](https://www.wpc.ncep.noaa.gov/wwd/wssi/wssi.php) were accessible through Python HTTPS despite HTTP 403 from the web retrieval tool. `WSSI_OVERALL_Day_1_latest.zip` contained source issuance `2026-11-12 0117Z`, newer than ArcGIS layer 1's observed `2316Z`. Its window was `00Z 11/12/26`–`00Z 11/13/26`. Therefore, mixing transports as if their “latest” names shared a generation is unsafe.
- `ICE_ACCUMULATION_Day_1_latest.zip` contained a zero-record DBF, empty SHP/SHX, coordinate-reference files, and indexes. Issuance/start/end existed only as DBF column definitions, with no values. No accompanying generation manifest was present. ZIP entry dates, directory modification times, DBF header dates, HTTP validators, and other layers' positive rows are not substitutes for those missing values. This rules out these sampled files as a solution; it does not prove no stronger NOAA product can ever exist.
- [NWS Instruction 10-514, section 5.2](https://www.weather.gov/media/directives/010_pdfs/pd01005014curr.pdf) describes approximate two-hour issuance and supersession by a new graphical product. It provides no ArcGIS transaction or empty-layer identity guarantee. Cached forecast windows describe applicability of that retained forecast; they do not establish that it is still the latest official product.

Exact responses, URLs, timestamps, headers, sample ZIPs and SHA-256 checksums are in [acceptance-evidence.tar.gz](acceptance-evidence.tar.gz). The forty query URLs are in `requests.json`; each query used `where=1=1`, `outFields=*`, `returnGeometry=false`, `orderByFields=objectid ASC`, and `resultRecordCount=2000`. This small probe supplements the [original capture](README.md), which establishes regional geometry and pagination behavior. It is not a longitudinal rollover study, a successful complete double scan, a device measurement, or evidence for atomic source publication.

## 1. Snapshot and layer states

The accepted snapshot contains the requested WGS84 envelope, source endpoint, all twenty expected layer IDs, acquisition interval, successful verification time, monotonically increasing local revision, and bounded provenance. Each layer has exactly one state:

| State | Required evidence | Consumer meaning |
| --- | --- | --- |
| `identifiedData` | Complete nonempty layer; all features agree on product, period, issuance and actual validity | Evaluate source polygons within coverage and `[validFrom, validTo)` |
| `observedEmpty` | Complete empty layer in both verification scans | No features observed during retrieval; issuance and forecast validity unknown |
| `identifiedEmpty` | A future, independently verified source mechanism binds this exact empty layer to issuance and validity | May support forecast no-impact within its authenticated coverage/window |

`identifiedEmpty` is reserved and unreachable from the current ArcGIS adapter. The adapter must not borrow another layer's dates or retain the previous layer's dates on an empty observation. A missing snapshot means not loaded. Failure is attempt metadata, never an empty accepted layer. Unknown identifiers or malformed values are errors, not another layer state.

`observedEmpty` is a successful observation with limited meaning. It replaces the previous layer in the current snapshot, including its old polygons, but must not be passed to `WSSIAssessmentLayer` using fabricated dates. A future consumer must expose unavailable forecast assessment with the explicit empty-observation reason and retrieval time. It must not report `noImpact`, “all clear,” or a risk decrease for notifications. Do not keep superseded positive polygons masquerading as the current layer after accepting an empty observation.

Product tradeoff: quiet regions may have a healthy, recently verified empty observation while forecast assessment remains unavailable. This is intentional. Reliable forecast no-impact for those regions requires stronger source identity evidence or a separately approved observation-only presentation; another component's issuance cannot fill the gap.

Within a validated nonempty layer, no polygon intersecting a point inside accepted coverage means no mapped WSSI impact for that layer/window. Outside coverage means `outsideCoverage`; future and expired windows remain distinct. Overall is assessed directly and independently; missing components do not synthesize or invalidate Overall. Never union the individual periods to reconstruct Days 1–3 or require different periods to share validity bounds.

## 2. Acquisition and observed stability

1. Read all twenty expected layers for one explicit regional envelope through the bounded WSSI client. Validate known source identities, schema, UTC dates, impact values, full polygon topology, resource ceilings, and cancellation. No geometry clipping or scope expansion is implied.
2. For every layer, bracket deterministic paging with initial/final ID inventories. Require exact unique-ID coverage and valid transfer-limit behavior. Any API error, missing layer, duplicate, truncation, inconsistent feature issuance/window, malformed geometry, deadline, or exhausted budget rejects the entire attempt.
3. Repeat the complete regional acquisition without using the first read's cached responses or conditional requests. Compare each layer's decoded full content, including geometry, product/period, issuance/window, and empty state. Compare by object ID within the attempt, independent of JSON field order; preserve coordinate/ring order. Record processing timestamps as provenance, not generation identity. Any difference rejects the attempt. Both complete scans must fit one shared deadline and aggregate byte/request budget; do not silently give each scan a new budget.
4. Stage only the matching second snapshot. Cross-layer issuance equality is not required. Two matching reads reduce observable rollover exposure but cannot rule out an intermediate publication or a stable, partly published upstream dataset. This residual risk is the explicit observed-consistency policy.

There is no automatic unbounded retry, partial layer acceptance, merge of successful layers from separate attempts, transport fallback to WPC ZIPs, or NOAA-atomicity claim. A later scheduled/manual attempt can retry. The existing single-pass acquisition DTO is retrieval evidence and does not itself satisfy this contract. Requiring two full reads increases cost; the existing limits still apply, and device/background feasibility must be measured before enabling those paths.

Initial coordinator limits are two scans, 120 seconds total, 100,000,000 decoded response-body bytes total, 25,000,000 bytes per response, 30 seconds per request, and at most 400 requests across both scans. Preserve page size 100 and at most 2,000 features per layer per scan. These are ceilings, not promises that every permitted feature inventory fits; reject on the first exhausted limit. A scan cannot reset the aggregate counters or deadline. New request-count and aggregate enforcement belong to the coordinator, in addition to existing transport enforcement.

## 3. Ordering and supersession

- One actor owns admission, validation authority, persistence, and reads. Admit attempts with actor-issued increasing tokens. Only the latest admitted token for a scope may commit; a later admission fences an earlier in-flight attempt even if the later attempt fails. A separate latest location-selection token prevents completion for an old location from selecting the active scope. Cancellation is checked during acquisition/staging and immediately before save.
- For each product/period, persist the highest accepted known `issuedAt` independently of scope and layer emptiness. Reject an identified candidate older than that watermark. Never derive source order from HTTP Date, retrieval completion, object IDs, GIS processing dates, or the local revision. Preserve these twenty watermarks through empty acceptance, scope eviction, and restart.
- For the same scope and known issuance/window, identical decoded content is a revalidation: update verification time without creating a content revision. Changed payload or validity under the same issuance is an unorderable correction and rejects the whole attempt. After a same-scope empty observation removes comparable geometry, an identified candidate equal to the durable issuance watermark is also rejected; wait for a strictly newer issuance. Supporting same-issuance source corrections requires a separately evidenced revision rule. A different scope naturally has a different feature selection; equal issuance alone does not imply identical regional content.
- `observedEmpty` has no source order. Latest-attempt admission orders its local observation only; it cannot prove the upstream response is newer than prior positive data. It does not advance or erase known-issuance watermarks. This is why it changes the observation record but cannot clear a forecast impact or establish no-impact for downstream change comparison.
- A snapshot has twenty layer entries with their own timestamps, never one synthetic `issuedAt`. A newer issuance may have different actual windows; no fixed day-rollover or two-hour tolerance rule is invented.

## 4. Atomic persistence and cache-forward reads

Keep the accepted snapshot readable throughout acquisition and staging. Encode and validate the entire candidate before mutation. In one actor-owned persistence transaction, replace all twenty entries for that scope, advance applicable issuance watermarks and content revision, and apply retention. No suspension is allowed inside this mutation/save section. On any failure, roll back all candidate changes and expose the previous committed snapshot. Return only immutable reconstructed values across actor boundaries.

Readback, including after restart, must reconstruct one complete snapshot with matching scope, revision, provenance, and layer states. Never expose a half-written vector, silently omit a corrupt layer, or interpret a decode failure as an empty layer. If cancellation arrives after a successful save, report the committed outcome; do not claim cancellation rolled it back. WSSI acceptance has no write dependency on SPC/NWS, HomeProjection, widgets, or notifications.

## 5. Coverage, retention, and freshness

Keep at most two accepted scopes: the active scope and one most recently selected previous scope, with at most twenty entries each. A newly accepted region does not delete the immediately previous region solely because location moved. Do not union envelopes, fabricate no-impact between them, or combine layers across scopes. Assessment selects one complete scope containing the point, preferring active then previous; otherwise it returns outside coverage. Acquisition completion cannot change selection authority.

The aggregate encoded accepted payload ceiling is 100,000,000 bytes, with at most forty layer entries and twenty issuance watermarks. Evict the inactive scope first to meet the byte ceiling; if the active candidate alone cannot fit, reject it and preserve the previous committed state. Bound provenance to 64 KiB per snapshot and exclude raw response bodies and unbounded attempt history from the store. These are explicit initial engineering limits, not measured device-memory guarantees. Record encoded bytes and eviction counts for later tuning; retain the client's stricter transient acquisition limits as well.

Delete a snapshot when none of its identified layers has a future `validTo` and its last successful verification is at least 24 hours old; an all-empty snapshot ages out by that same 24-hour rule. Apply pruning on startup and successful acceptance using an injectable clock. Clock changes never promote an expired forecast or extend validity. Scope/byte caps remain effective even if the wall clock moves backward.

Keep source `issuedAt`, forecast `[validFrom, validTo)`, `verifiedAt`, and `committedAt` separate. A successful unchanged double scan may advance `verifiedAt`; failures cannot. Retained content is always labeled with its source time and last verification, and never asserted to be the current official publication merely because `validTo` is in the future. This acceptance slice does not assign a UI freshness TTL or promise a two-hour refresh cadence. `observedEmpty` never acquires a forecast validity window through retention.

## 6. Required implementation evidence

| Scenario | Required observable result |
| --- | --- |
| Complete stable nonempty snapshot with differing cross-layer issuance | Atomic acceptance; exact per-layer identity/window readback |
| Empty regional/all-layer response | Explicit `observedEmpty`, nil source dates; unavailable forecast assessment, never no-impact |
| Error body with HTTP 200; missing/partial page; duplicate/mixed within-layer data | Whole attempt rejected; accepted snapshot/revision/verification unchanged |
| Identical IDs but changed geometry/attributes between scans | Whole attempt rejected |
| Failure after deletion/insertion or during save | Rollback; previous full snapshot survives same-context read and disk reopen |
| Cancellation before commit; cancellation after save | Previous snapshot for the former; committed snapshot and truthful outcome for the latter |
| Older attempt finishes last; latest admitted attempt fails | Earlier token remains fenced; accepted state unchanged |
| Older known issuance; empty followed by older positive; eviction/restart | Watermark prevents regression in every case |
| Same issuance/content; same issuance conflicting payload/window | Revalidation only for identical content; conflict rejected |
| Movement A → B → C and overlapping envelopes | A retained after B subject to byte cap, oldest inactive evicted after C; no cross-scope layer merge |
| Expired/future windows, all-empty aging, byte cap, clock reversal | Correct applicability, bounded retention and conservative eviction |
| Restart with data/empty/unknown states or interrupted attempt | Exact committed snapshot and watermarks restored; no intermediate state |
| WSSI acquisition/acceptance failure | SPC/NWS, HomeProjection and notification state unchanged |

Use deterministic transport fixtures and disk-backed containers. Run focused tests repeatedly, independent persistence/concurrency review, and the repository's full unit lane with finalized native XCResult evidence. Live research responses demonstrate source behavior; they do not replace those implementation tests.

## Consequences for #839 and its dependencies

The original “no hybrid publication” and “accepted empty forecast” criteria cannot both be established from this source. Replace them with complete observed-stable snapshots, explicit independent layer generations, and explicit unidentified empty observations. Preserve rejection of mixed metadata *within* a layer. Preserve atomic local commit and source regression protection where a source issuance exists; do not promise source chronology for unidentified empties.

WSSI-03 needs a bounded two-scan acceptance coordinator; it must not be treated as already proving observed stability. WSSI-04 needs a boundary that preserves `observedEmpty` as unavailable forecast assessment. WSSI-05's twenty-row, mandatory-date representation cannot encode unidentified empties, two retained scopes, durable ordering watermarks, and snapshot identity safely: plan a minimal versioned schema adjustment with disk migration/reopen evidence. Do not force these states into the existing model with sentinel dates or opaque provenance strings. Reconcile these changes with #833/#839 before implementation; foreground/background and notification work remain separate.

## First implementation slice: V8 snapshot storage

V8 adds one `WSSICacheRecord` containing an explicitly versioned Data payload. The payload holds at most two complete snapshots, content revisions, selection order, retrieval/commit times, and at most twenty known-issuance watermarks. Custom Codable values are encoded inside Data rather than stored as SwiftData attributes. The aggregate 100 MB ceiling includes the entire encoded record, so it is stricter than a geometry-only ceiling. V7 models remain in the schema and migrate in place; existing uncoordinated V7 layer rows are preserved but never promoted into canonical snapshots.

`WSSISnapshotStore` is the actor-owned persistence seam for already verified input. It validates complete vectors and explicit layer states, rejects known issuance regression and comparable same-issuance conflicts, performs revalidation without advancing the content revision, prunes retained scopes, and rolls back injected failures. Unknown-date empty observations return no assessment layer. It is not wired into app startup, acquisition, location selection, Home or notifications. The future coordinator must enforce admission tokens, source/empty authentication, two full matching reads, shared acquisition limits, and startup pruning before this seam is used by the app. Same-issuance conflict comparison in this slice uses the retained identified layer for the same scope; watermarks retain source order, not evicted geometry history.

PR #887 covered persistence only and left #839 open. The coordinator slice below supplies the remaining canonical acceptance path. No scheduling or presentation is added here.

## Canonical acceptance coordinator

The coordinator is co-isolated with `WSSISnapshotStore` through a separate extension and authority value. There is one actor for admission, selection, reads and save; the final latest-attempt check and synchronous V8 replacement have no intervening suspension. Per-scope monotonically increasing attempt tokens fence superseded completions, including when the latest attempt fails. Independent selection identities change only through `selectCoverage`, never from a completed acquisition. In-flight authority is intentionally process-local; restart restores only committed snapshots and their durable source watermarks.

`selectCoverage` expresses location intent independently of refresh. When that scope is retained, the existing V8 record reorders it and updates only selection time. This prevents late unselected work from treating a previously active scope as the current one during retention. Selecting a scope without accepted data does not invent coverage. `acceptedCoverage` exposes selected intent separately from the retained snapshot array; consumers must not infer current location from whichever response finished last. Entries accepted without ever being selected retain the existing distant-past selection marker and do not restore active selection at restart.

The first coordinator read, selection or refresh synchronously prunes startup data before use and restores the most recently selected retained scope. `refreshCoverage` admits work, acquires and validates off the actor, rechecks cancellation and admission on return, and calls the existing atomic replacement with selection authority determined from the captured selection identity. Failed, cancelled, changed or superseded attempts do not advance accepted verification time. An old location's result may be retained within existing limits but cannot select coverage. Callers receive their own completion or error; there is no coalesced waiter queue.

`WSSIClient.acquireVerified` uses one monotonic deadline and subtracts the first scan's exact decoded byte and request totals from the shared budget before starting the second scan. Hard contract ceilings also apply to configured limits. Both reads omit conditional reuse. Object IDs remain paired with decoded features for order-independent record comparison, while polygon/ring/coordinate order is preserved. Cross-layer issuance equality is never imposed. Matching empty layers become only `observedEmpty`; identified-empty remains unreachable from this adapter. Bounded provenance records scan count, request/byte totals and per-layer content hashes. Stable reads are observed evidence, not a transactional NOAA generation.

The public canonical seam is `selectCoverage` / `refreshCoverage` / `acceptedCoverage`; raw `read` and `replace` remain lower-level persistence seams. The coordinator is ready for later dependency-container and foreground integration, but this issue does not wire it into app startup, Home, notifications or background scheduling. The canonical seam's own lazy startup pruning is tested through disk reopen; app lifecycle wiring remains owned by the following integration issue. Keep #839 open until the remaining criteria and evidence have been reviewed.
