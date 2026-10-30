# Home projection sampling — #805

The observation view repeatedly converted retained SwiftData projections while building one body. Each conversion calls `HomeProjection.record`, which decodes a populated Storm Setup response. Sampling the query-derived snapshot once per body evaluation removes redundant conversion without retaining a second cache. Current-location selection, latest-startup fallback, and accepted-revision derivation retain their existing rules. Acceptance callbacks derive against the current accepted revision using that body's sampled observation.

## Reproduction and measurements

Run `tools/ci/run_test_lane.sh performance '-only-testing:SkyAwarePerformanceTests/HomeProjectionStoreScalingMeasurementTests/retainedStormSetupProjections_reportBodySnapshotSampling()'`. The parentheses are required for this method selector in the local toolchain; omitting them selected zero tests and failed native result verification.

The deterministic fixture saves ten projections to an in-memory SwiftData store, fetches them, then populates each managed row with the same 2,329-byte detailed Storm Setup response: HRRR source/freshness, canonical and diagnostic ingredients, embedded Anvil analysis, and viability. This represents the recent retained population; it makes no unbounded-history claim. The measurement replays the pre-change body access pattern and the single-sample alternative through the same production snapshot factory. SwiftData accessors and the decoder are warmed before nine measured repetitions. The replay includes revision derivation and equality checks, excludes query fetch/render scheduling and acceptance callback work, and does not count actual SwiftUI body invocations.

Snapshot accesses are counted in the replay. Conversion and decode counts are derived from the inspected production path: each snapshot maps all ten records plus the matching current record when keyed, and each populated record invokes one JSON decode. They are not profiler counters. The unchanged selection path still converts the matching row separately from the full collection.

| Scenario | Snapshot reads before → after | Record conversions / decodes before → after | Median before → after | p95 before → after |
| --- | --- | --- | --- | --- |
| Resolved location | 3 → 1 | 33 → 11 | 22.541 → 7.351 ms | 26.818 → 7.857 ms |
| Startup fallback | 4 → 1 | 40 → 10 | 27.912 → 6.776 ms | 37.491 → 7.047 ms |

Environment: Debug, SkyAware_Performance, iPhone 17 simulator, iOS 26.5 (23F77), arm64, Xcode default toolchain on macOS 27.2. Native finalized result: 1 executed, 1 passed, 0 failed/skipped/expected failures. Bundle: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.uaoglA/performance.xcresult`; attachment: `HomeProjectionBodySampling.txt` (exported filename has a UUID). Baseline code was main `036b28b` plus the behavior-preserving snapshot-factory extraction and measurement harness; the production single-sample change followed measurement. Both alternatives run in the same benchmark, and the measured factory remains unchanged by the correction.

The measured reduction is material within this Debug simulator replay and justifies the small local deduplication. These durations are environment-dependent diagnostics, not release-build/device latency or evidence that a visible hitch was fixed. No device trace, rendered UI latency, or Instruments measurement was performed. No additional cache is justified or introduced.

## Correctness boundary

The deterministic regression verifies current/latest selection, missing-key/startup behavior, full response reconstruction, and visibility of a payload-only change with an unchanged revision timestamp. Existing hosted SwiftUI observation and accepted-revision tests cover initial promotion, observation gaps, location transitions, replacement/deletion fallback, independent hot-alert/enrichment updates, and cache preservation after refresh failure. Focused validation passed with 31 logical tests and 34 parameter-expanded executions, with no failures or skips. The required full `tools/ci/run_test_lane.sh unit` passed with 1,592 logical tests (1,591 passed, one allowed skip, no failures), or 1,878 parameter-expanded executions (1,877 passed, one skip). Both used Debug, SkyAware_Tests, iPhone 17 on iOS 26.5. Focused bundle: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.gTuc94/unit.xcresult`; full bundle: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.kZQQhC/unit.xcresult`. Coverage change was not measured. Apple `swiftui-specialist` (dataflow and soft-deprecation references) and `xctrace` skill guidance were loaded; no Instruments command was needed for this bounded replay.
