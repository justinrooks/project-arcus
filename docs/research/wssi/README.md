# WSSI-01 source contract and acquisition benchmark

Issue: [#834](https://github.com/justinrooks/project-arcus/issues/834), parent [#833](https://github.com/justinrooks/project-arcus/issues/833). Research only: no production ingestion, app behavior, SwiftData, or Xcode configuration changes.

## Reproduction and evidence

Run `python3 tools/research/benchmark_wssi.py /tmp/wssi-new-capture` from the repository root using Python 3 (standard library only). The destination must not exist. Requests are sequential, have a 90-second timeout, and are not retried. The script fails closed on API errors in benchmark queries, missing/duplicate IDs, changing ID inventories, or unexpected transfer-limit flags. A failed run leaves its partial capture and manifest for diagnosis; it is not a completed comparison. The script is a research probe, not a canonical publication validator.

The committed capture contains exact JSON response bodies, service and all feature-layer metadata, URL parameters, UTC request start times, HTTP status/headers, body sizes, wall latency, and Python JSON decode time/peak traced allocation. `summary.json` contains every returned feature's attributes, grouped by layer and strategy. Raw fixtures are packaged in `capture.tar.gz`; extract with `tar -xzf docs/research/wssi/capture.tar.gz -C /tmp`. Capture contents and aggregate measurements are described below. HTTP failures raise; the explicit invalid-field query records ArcGIS's JSON error even when HTTP succeeds. The error fixture must never be interpreted as an empty feature set.

The regional envelope is longitude -112 to -102, latitude 36 to 43; the point is (-105, 40). Nationwide means no spatial filter within this service's coverage, not a guarantee of Alaska/Hawaii coverage. These scopes are fixed research coordinates, not user location. All strategies query the same layer set in one sequential run; issuance equivalence must be checked from attributes, and is impossible to establish for an empty scoped result. These are not concurrent atomic snapshots or repeated controlled performance trials.

## Sources and contract

Primary sources: [NOAA service metadata](https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/wpc_wssi/MapServer?f=pjson), [layer 1 metadata](https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/wpc_wssi/MapServer/1?f=pjson), and [Esri MapServer query reference](https://developers.arcgis.com/rest/services-reference/enterprise/query-map-service-layer/). The linked WPC graphical page returned HTTP 403 during investigation; it is not additional verified evidence. The service explicitly says it is not time enabled; historical generations cannot be selected through a `time` query based on this evidence.

The twenty feature layers are IDs 1–4 Overall Impact, 6–9 Snow Amount, 11–14 Snow Load, 16–19 Ice Accumulation, and 24–27 Blowing Snow. Each group orders Day 1, Day 2, Day 3, Days 1–3. Group IDs 0/5/10/15/23 are not queryable product layers. Overall Impact is the source product; do not reconstruct it from these four components.

Features use Esri polygons (`rings`, potentially multipart with holes), not a GeoJSON Polygon coordinate array. Source coordinates are Web Mercator (102100/latest 3857); the requests explicitly use `inSR=4326` for spatial filters and `outSR=4326` for returned geometry. Preserve longitude/latitude order and validate returned spatial reference, finite coordinates, ring closure/topology, and geometry type in the future decoder. Do not assume a single exterior ring or discard holes. The query envelope selects intersecting features; it does not request clipping. All six nonempty bbox pages in this capture contain vertices outside the requested envelope, confirming that selection did not clip the returned polygons. Point queries can use `returnGeometry=false`; their attributes cannot support offline rematching after movement or map rendering.

The schema includes OID `objectid`; string `product`, `component`, `impact`, `valid_time`, `issue_time`, `start_time`, `end_time`, `idp_source`; epoch-millisecond dates `idp_filedate` and `idp_ingestdate`; shape and area/perimeter fields. `end_time` misleadingly has alias “Start Time”: use the field name and value. Renderer values advertise `WINTER WEATHER AREA`, `MINOR`, `MODERATE`, `MAJOR`, `EXTREME`; the fixture's observed subset is recorded below. Unknown values must fail validation rather than silently become no impact. File/ingest dates describe GIS processing, not forecast validity or a promised common issuance token.

## Validity, publication, and empty results

Use actual start/end timestamps, never a calendar-day interpretation of Day 1/2/3. The first live Day 1 response is issued `2026-11-11 2116Z`, valid `21Z 11/11/26` through `18Z 11/12/26`: 21 hours. The initial Day 2/3 responses are issued `2026-11-11 1916Z`, with consecutive 24-hour windows ending at 18Z. Combined Days 1–3 initially spans `19Z 11/11/26` through `18Z 11/14/26`: 71 hours. Thus the service description's nominal 24/72-hour terminology is insufficient for decoding actual windows. The combined product covers the full source window; it is not a fourth day, nor proof that the current three individual layers can be unioned to reproduce its geometry.

The service advertises two-hour updates, which is neither a device scheduling guarantee nor evidence that all layers supersede atomically at a fixed clock. This capture directly observes different issuance markers across layers during polling. No common all-20 issuance marker is available in metadata. Object IDs identify records, not generations. The capture demonstrates publication overlap/mixed observed issuances; it cannot determine whether this reflects staggered publication, intentionally different component schedules, or an interrupted update. A longitudinal run across later cycles is needed to establish actual supersession behavior; no stable rollover rule is claimed.

A legitimate empty query returns schema/feature-set structure without feature attributes. In particular it cannot supply `issue_time`, validity, file date, or ingest date from a nonexistent row. Layer/service metadata supplies neither an authoritative empty-generation marker nor an atomic snapshot token. HTTP Date, request completion time, an unchanged ID list, and an empty feature count cannot substitute for that evidence. The explicit offshore point fixture tests this absence independently of whether any entire nationwide layer happens to be empty.

## Conservative acceptance contract for WSSI-06

Follow-up: [WSSI canonical acceptance contract](acceptance-contract.md) defines the user-accepted observed-consistency policy from additional live ArcGIS and WPC ZIP investigation. It explicitly changes the original strict all-layer requirement and distinguishes unidentified empty observations from forecast no-impact. The original gate and evidence below remain historical context; the contract records the initial V8 storage implementation and the remaining coordinator work. GitHub acceptance criteria remain to be reconciled before that coordinator slice.

**Decision gate for [#839](https://github.com/justinrooks/project-arcus/issues/839): this service has not established strict all-layer publication coherence or authoritative empty-generation identity. Do not implement canonical acceptance using invented identity.** This research completes the fallback requested by #834; enabling canonical acceptance requires resolving this gate with source-backed evidence or an explicitly approved change to the epic's consistency contract.

1. Stage the entire required layer set; validate expected layer identity, field schema, impact values, geometry, coverage, UTC timestamps, and actual period bounds. Reject unknown/missing generation fields, malformed/error bodies, incomplete pages, and conflicting attributes. Keep prior accepted state during failure.
2. Enumerate IDs per layer/scope, retrieve all pages in deterministic OID order, and compare exact unique IDs to the initial inventory and a final inventory. Reject truncation, duplicates, missing IDs, API errors, and changed inventories. A terminal page alone is insufficient. These checks establish observed record completeness, not an atomic generation: content may change under stable IDs.
3. Require consistent issuance evidence for every feature within a layer and source-supported cross-layer coherence before canonical acceptance. Compare period alignment independently from issuance; never force different valid periods to share start/end. Reject mixed issuances under the current strict epic contract. A second identical scan can detect some races but cannot prove atomic publication and must not be described as such.
4. Empty layers or empty scoped queries have unknown generation unless an independently verified source mechanism establishes it. Reject the attempted complete canonical replacement; retain last-known-good within its validity and label unavailable/stale when appropriate. Never infer “no impact” from unverified absence, including when all twenty point queries are empty. Positive rows elsewhere do not authenticate an empty layer.
5. Even matching nonempty timestamps across all layers provide only observed consistency, not a documented transactional snapshot. Until the source guarantee or approved policy exists, retain the data as research/staged evidence rather than claiming strict canonical acceptance. Expiration is still enforced; retention never extends forecast validity.

## Pagination and request budget

Metadata advertises a 2,000-record maximum and supports pagination, ordering, ID-only queries, and WGS84 output. Esri documents that ID-only responses are not subject to the feature response limit. The benchmark brackets each strategy/layer with ID inventories and fetches pages with `orderByFields=objectid ASC`, `resultOffset`, and `resultRecordCount=2000`. The forced one-record page pair exercises actual transfer-limit signaling and offset behavior even when live counts are below 2,000. A true >2,000-feature storm was not available in this capture; that scale is unproven, not passed. Production should enforce request, byte, page, and elapsed-time budgets and reject when exceeded; metadata support does not justify unbounded downloads.

With one page per layer, one strategy costs 60 requests including before/after ID inventories; all three cost 180, plus 21 metadata requests and four explicit probes = 205. At twelve nominal two-hour opportunities/day that would be 720 requests/device/day for one strategy before retries, which argues against blindly repeating full scans. No published NOAA rate quota was established; successful requests do not establish permission or capacity for fleet-scale polling. Back off on HTTP/API failures; no exact refresh schedule is promised.

## Recommendation and practical limits

Select **regional bounding-box acquisition with geometry** as the initial acquisition strategy for #836, conditional on resolving canonical acceptance separately. Persist explicit requested coverage and retain full returned polygons; local matching is valid only inside accepted coverage. Geometry permits map reuse and offline rematching inside that region; movement beyond it requires another acquisition. The product preference confirmed in PR #882 and recorded in #836 is a roughly state-scale footprint around the user’s location with full, unmodified returned polygons. This means a geographic footprint, not administrative state-border clipping or a fixed-state filter. Exact bounds and iOS byte/page/resource budgets remain implementation evidence questions; map presentation stays in the separate UI epic. This capture reduced total geometry bytes by about 43%, but peak traced decode allocation only fell from 21.5 MB to 20.0 MB: a large intersecting multipart feature still dominates. Narrowing the box alone cannot guarantee a small response. This research envelope is a benchmark input, not a proposed fixed product region.

Nationwide geometry is useful as a reference and avoids coverage shifts, but its largest payloads and decode allocations are unnecessary for the initial local assessment. Point queries reduce payload further but lose offline/map reuse and cannot establish an empty result's generation. Bounding boxes share the empty-generation limitation; they do not solve coherence. No permanent three-strategy client is proposed.

Measurements below are macOS Python diagnostics, including TLS/network/server variability and instrumented JSON allocation overhead. They are not Swift decoder, iOS memory, energy, physical-device, background execution, or Instruments evidence. A regional strategy is a candidate for best-effort background work, not demonstrated device feasibility. No widespread-storm or historical-generation evidence is claimed; repeat under larger events and measure the selected implementation on device before assigning background budgets. The app unit suite was not run because no app source, test, project, or runtime configuration changed; validation instead checks captured contracts, IDs, fixtures, and reproducibility.

## Captured measurements

Capture interval: 2026-11-11T22:26:16.509124+00:00 through 2026-11-11T22:27:34.725161+00:00; macOS-27.2.1-arm64-arm-64bit, Python 3.9.6. Exactly 205 successful HTTP responses, 51,267,834 response-body bytes. Body bytes are the bytes read by urllib (no compression requested); headers/TLS overhead and radio cost are excluded.

| Strategy | Features (sum across 20 layers) | Body bytes (pages) | Page latency sum / median (s) | Decode sum (ms) | Max page traced decode allocation (bytes) |
| --- | ---: | ---: | ---: | ---: | ---: |
| nationwide | 56 | 32,411,566 | 14.064 / 0.736 | 1194.564 | 21,549,392 |
| bbox | 10 | 18,626,250 | 10.102 / 0.335 | 683.477 | 20,020,611 |
| point | 0 | 29,424 | 6.546 / 0.322 | 3.476 | 7,946 |

The table excludes ID and metadata overhead; the complete request manifest includes them. Peak allocation is per JSON decode, not application RSS or simultaneous retention of twenty decoded layers. One trial per layer/scope cannot establish a stable latency ranking. Feature totals count layer records, not unique areas or storms.

| Layer | Nationwide / bbox / point counts | Observed issuance(s), nationwide |
| --- | --- | --- |
| 1: Overall_Impact_Day_1 | 2 / 0 / 0 | 2026-11-11 2116Z |
| 2: Overall_Impact_Day_2 | 5 / 0 / 0 | 2026-11-11 1916Z |
| 3: Overall_Impact_Day_3 | 5 / 2 / 0 | 2026-11-11 1916Z |
| 4: Overall_Impact_Days_1-3 | 5 / 2 / 0 | 2026-11-11 1916Z |
| 6: Snow_Amount_Day_1 | 1 / 0 / 0 | 2026-11-11 2116Z |
| 7: Snow_Amount_Day_2 | 3 / 0 / 0 | 2026-11-11 2116Z |
| 8: Snow_Amount_Day_3 | 3 / 1 / 0 | 2026-11-11 1915Z |
| 9: Snow_Amount_Days_1-3 | 3 / 1 / 0 | 2026-11-11 1915Z |
| 11: Snow_Load_Day_1 | 2 / 0 / 0 | 2026-11-11 1915Z |
| 12: Snow_Load_Day_2 | 3 / 0 / 0 | 2026-11-11 1915Z |
| 13: Snow_Load_Day_3 | 3 / 0 / 0 | 2026-11-11 2116Z |
| 14: Snow_Load_Days_1-3 | 3 / 0 / 0 | 2026-11-11 2116Z |
| 16: Ice_Accumulation_Day_1 | 0 / 0 / 0 | unknown (empty) |
| 17: Ice_Accumulation_Day_2 | 1 / 0 / 0 | 2026-11-11 1915Z |
| 18: Ice_Accumulation_Day_3 | 0 / 0 / 0 | unknown (empty) |
| 19: Ice_Accumulation_Days_1-3 | 1 / 0 / 0 | 2026-11-11 1915Z |
| 24: Blowing_Snow_Day_1 | 1 / 0 / 0 | 2026-11-11 2116Z |
| 25: Blowing_Snow_Day_2 | 5 / 0 / 0 | 2026-11-11 2116Z |
| 26: Blowing_Snow_Day_3 | 5 / 2 / 0 | 2026-11-11 2116Z |
| 27: Blowing_Snow_Days_1-3 | 5 / 2 / 0 | 2026-11-11 2116Z |

Observed impact values: EXTREME, MAJOR, MINOR, MODERATE, WINTER WEATHER AREA. Empty nationwide layers: 16, 18.

Probe `forced-page-1`: 1 features, exceededTransferLimit=True.
Probe `forced-page-2`: 1 features, exceededTransferLimit=False.
Probe `empty`: 0 features, exceededTransferLimit=False.
Probe `error`: {'code': 400, 'message': 'Failed to execute query.', 'details': []}.

An additional positive-point probe at an actual layer-1 polygon vertex returned one feature with no geometry, confirming `returnGeometry=false` on a positive match. It is included in the manifest as request 206, after the 205-request benchmark interval above; its bytes/latency are excluded from the benchmark totals. The original capture used layer 1; its fixtures are preserved unchanged. New captures select a nationwide layer with at least one feature for the positive-point probe and a layer with at least two features for the forced-pagination pair.

Offline validation: `python3 tools/research/verify_wssi_capture.py docs/research/wssi/capture.tar.gz` verifies response-body byte sizes, error separation, all 60 before/after ID inventories and page contents, the empty response, distinct forced pagination records, and positive-point geometry omission. This verifies observed completeness, not generation coherence.

Independent review reproduced benchmark totals and verified that all nonempty bbox results matched the corresponding nationwide issuance/validity fields in this run. Empty scopes remain incomparable. Review found no actionable defects. Final checks: offline verifier passed all 206 responses and 60 inventories; both research scripts passed Python syntax compilation; `git diff --check` passed. No Swift/app regression or device-performance claim is made.

## Quiet-publication reproducibility correction

New captures write `probes.json` with the selected layer and `captured` status for each available probe. If no nationwide layer has the required record count, the probe records `not_observable` and a reason, and no corresponding response is fabricated. The verifier validates captured responses before reporting `verified`; unavailable probes print `not observable in this capture`, which is an evidence limitation rather than a successful probe. It rejects an unavailable claim when the inventory contains a suitable layer. If publication changes between inventory and probing, missing/invalid responses still fail verification rather than being excused as seasonal absence.

The original archive predates `probes.json`; its verifier compatibility path checks its actual layer-1 probe responses and retains both as verified. A future fully quiet capture can pass inventory/error/empty integrity checks while explicitly reporting both availability-dependent probes as unobserved. Request totals vary with probe availability (203 base requests, two pagination requests when available, and one positive-point request when available).

Regression validation: `python3 tools/research/test_wssi_probes.py` uses stub HTTP responses to run the capture script and archive verifier together with layer 1 empty: all layers quiet, one feature elsewhere, and two features elsewhere. It also verifies rejection of a missing positive response and an unjustified pagination skip. No live NOAA calls or fixture replacements are needed for these regressions.

## WSSI-08 background acquisition remains deferred

PR #890 retains the bounded background integration but does not enable source acquisition in app wiring. The foreground `internalWSSIIngestionEnabled` preference does not enable background acquisition; the separate constructor control defaults to false. A background opportunity reports `deferredFeasibility` before shared ingestion ownership, network requests, or attempt-backoff updates, preserving accepted coverage and foreground opportunities. Deterministic tests explicitly enable the acquisition path to exercise its cancellation and ownership boundaries; this is behavioral evidence only.

The captured regional single scan spent 10.102 seconds on feature pages alone, excluding ID inventories and metadata. Canonical acceptance requires two complete unconditional scans, with at least 120 requests for the current twenty-layer protocol. Simply doubling the measured pages gives about 20.2 seconds before inventory overhead; that is an illustrative cost estimate from one macOS/Python capture, not a measured full Swift acquisition or an iOS/background timing guarantee. It provides no support for a five-second successful acquisition policy. The existing scheduled refresh has a 25-second work deadline within a 30-second policy budget and a five-second finalization reserve; uploads, ingestion, and notification evaluation consume that work window before optional WSSI admission. Their residual budget has not been shown to accommodate canonical acquisition.

Keep background acquisition deferred under #841 until representative complete double-scan timing with the Swift client, including inventories, decode/validation, and acceptance, establishes a defensible fit within measured residual background budgets. Include device/background evidence when available, varying source size and network conditions. No such feasibility evidence is claimed here. Do not raise the timeout, borrow higher-priority or finalization time, or weaken unconditional observed-stability acceptance to enable this path.
