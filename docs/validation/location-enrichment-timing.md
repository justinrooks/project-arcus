# Location enrichment timing — LOC-16 / #878

The production policy remains immediate durable H3 admission and best-effort dispatch. No 250 ms or 500 ms dispatch holdback is implemented. NWS identifiers are resolved independently of reverse geocoding, optional zone labels, Home, and weather-store initialization. County, forecast-zone, and fire-zone identifiers must all be nonempty for a complete targeting signature; missing identifiers produce a partial signature rather than invented codes. The existing resolver still requires county and fire metadata for weather context, while the process-owned presence path can retain partial metadata.

## Diagnostic boundaries

In macOS Console, select the signed development device and SkyAware, enable info messages, and filter `Enrichment trace=`. The trace ID is random and ephemeral. Only one current observation is retained in memory, and supersession discards its correlation state. No coordinates, H3/UGC codes, capture timestamps, installation identifiers, or diagnostic history are emitted or persisted by these events. NWS logs identify endpoint categories rather than coordinate-bearing paths.

All `elapsed_ms` values use a monotonic clock starting at provider acceptance, after validity/H3 derivation and before snapshot publication. They measure application processing, scheduling, persistence, and network time as applicable. They are not capture-age measurements. `source` becomes the foreground/background admission source at `admission_started`; earlier events may show `unknown`.

| Stage | Meaning |
| --- | --- |
| `accepted` | Canonical observation accepted; H3 already derived |
| `admission_started` | Process-owned admission starts, before durable retention |
| `points_started` | Shared NWS lookup begins for this exact observation |
| `points_http_completed` | HTTP response received; `network` reports `live`, `localCache`, `cacheRevalidated304`, or `cacheFallback` from the existing transport |
| `codes_ready` | Points response decoded; `shape` is `complete`, `partial`, or `h3_only` |
| `outbox_retained` | Existing outbox save succeeded for the indicated shape |
| `post_started` | Actual prepared payload enters the HTTP POST; shape reflects that payload, including late outbox upgrades |
| `signal_accepted` | Signal returned a validated `accepted` acknowledgment for that actual payload |
| `points_failed` / `points_cancelled` | Resolution ended without usable points metadata |
| `upload_failed` / `upload_cancelled` | Prepared location upload did not yield an accepted acknowledgment |

`live` is the transport's classification, not proof of origin recomputation or bypassing intermediary caches. Coalesced consumers and repeated resolution of the same completed observation do not create extra points events. Source failures remain retryable on subsequent eligible foreground activation. Relaunch can retry from the existing accepted snapshot and durable outbox mechanisms. No execution after suspension or force-quit is guaranteed.

Traces superseded by movement, process exit, or relaunch are censored. Acknowledgments after supersession may remain visible in existing `Presence stage=` logs but cannot be correlated with this single-current-observation trace. Count them as missing/censored, never as fast successes. An outbox retention event alone does not establish a transmitted payload or server acceptance.

## Quick device recipe

1. Validate Signal #414 compatibility in the intended development environment before interpreting partial-to-complete upload outcomes. Use a signed development build and the normal sharing/authorization settings; do not change production endpoints or consent to manufacture results.
2. Start Console capture before launch. Collect separate cold-launch and warm-foreground samples on Wi-Fi and cellular. Preserve normal admission cadence; use legitimate accepted fixes rather than repeatedly forcing identical timestamps. Record build, device/OS, network, sample count, and test context alongside the logs.
3. Where feasible, collect eligible Always-authorized significant-change background samples. Include missing execution opportunities, cancellations, failures, and incomplete signatures. Do not count arbitrary background launches as location callbacks.
4. For each trace, record points start/completion, complete `codes_ready`, complete `outbox_retained`, every actual `post_started` shape, and validated `signal_accepted` shapes. Report cold/warm and foreground/background separately; compute median/p90/p95 and counts within 250/500 ms only from correlated observations, alongside failures and censored counts.
5. For each candidate window W (250 ms and 500 ms), use complete **durable** readiness R, not HTTP response time alone. A trace is a candidate for avoiding a separate H3-only POST only when R <= W, an H3-only POST actually started, and a later complete POST for that same trace was accepted. Record codes-ready-to-retained overhead, actual POST count, and failure/tail cases. Report the potential reduction as a counterfactual upper bound: this build does not implement a scheduler that proves the reduction.
6. Compare those counts with total eligible traces and actual H3-only/partial/complete POSTs and accepted outcomes. A complete payload already sent first contributes zero duplicates avoided. A completed HTTP GET without a later accepted complete upload contributes zero verified avoided duplicates. Retain missing/censored samples in the denominator and disclose why they cannot be scored.

## Evidence and decision

| Evidence | Status |
| --- | --- |
| Device cold/warm distributions | Pending physical-device exercise |
| Eligible background distributions | Pending physical-device exercise and OS opportunities |
| Actual H3-only versus complete upload counts | Pending paired-device/Signal validation |
| 250 ms versus 500 ms avoided-duplicate comparison | Pending correlated application observations |
| Signal #414 end-to-end reconciliation | Pending; server issue open at implementation |

The owner authorized PR publication on November 10, 2026 with device distributions and Signal #414 validation explicitly pending. This authorization is not measured evidence or release authorization. The external 50-point Python sample is preliminary HTTP latency only and is not substituted for any row above.

Recommendation: retain immediate dispatch until device evidence quantifies the incremental avoided duplicates between 250 ms and 500 ms, processing overhead, and tails/failures. Any future holdback needs an explicit decision on dispatch ownership, completion-triggered release, deadline, cancellation, consent, and bounded H3 fallback, plus verified Signal #414 compatibility. Durable H3 admission must remain immediate regardless of that decision.
