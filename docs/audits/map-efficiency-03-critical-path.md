# Map Efficiency 03 — post-scoping critical path (#710)

Date: 2026-10-19. Production revision: `00872b6a1b8cd5f97e61873f0b618012c4ad74e8` (integrated #709 / PR #740, including #702, #598, and #706). Comparison: [#708 baseline and #709 follow-up](map-efficiency-01-baseline.md). Test changes: `MapAcceptedUpdateMeasurementTests.testSelectedSceneCriticalPathAfterSourceScoping` on `issue-710`.

## Decision

**No-go for production scheduling changes.** Source scoping removed the demonstrated redundant work. Repeatable in-memory unit fixtures show no material remaining selected-to-coherent-publication bottleneck that justifies restructuring fetch/planner orchestration. Complete #710 with this measured no-change disposition. Keep the coherent publication barrier, planner isolation, latest-generation checks, and existing cache policy.

This is a bounded conclusion for these fixtures, not a claim that all source implementations or device workloads are fast. Reopen scheduling work if a representative accepted-store fixture demonstrates material remaining latency. Artificially delaying unrelated sources would demonstrate the known full-refresh dependency graph, but would not establish that those delays occur in the accepted-store pipeline or that repository actors execute independently.

## Method and environment

Debug unit target, iPhone 17 simulator, iOS 26.5, arm64; Xcode reports macOS 27.0.1 as the build environment. No live providers, UI tests, UI automation, device timing, or Instruments. Eight repetitions per scenario. Wall time uses `ContinuousClock`; the existing comparable benchmark also records process CPU time. Report sample standard deviation rather than imposing an absolute performance threshold. Concurrent test scheduling and runtime warmup affect these measurements.

Reuse #708/#709's small counted-provider fixture: one current categorical polygon, one polygon for each future categorical day, a Day 2 wind polygon, empty meso/fire, and zero or one warning. The new test creates a fresh model for every initial-load sample, selects Day 1, 2, or 3 before loading, and injects the existing counted planner delegating to the production builder. It times entry to full reload through its return after synchronous coherent publication; this is logical model readiness, not app launch or rendered MapKit readiness.

For the selection-change scenario, first load accepted plans, then change Day 2 categorical issuance/content and suspend its replacement read with `IndexedReloadGate`. Select Day 3 categorical, Day 2 wind, and Day 2 categorical while suspended. Assert the original categorical geometry/validity remains current and no candidate plan has built. Release the gate and time the remaining read/plan/publication path; assert the new Day 2 geometry and exactly one source read / one plan. Each repetition changes content in a fresh harness. Gate dwell and selection-switch duration are excluded from that timing. Existing scene/scoped tests separately exercise all-plan coherence, warnings, cancellation, supersession, merged scopes, failed/empty inputs, expiration, and cache eviction.

The original accepted-update benchmark is unchanged and rerun for comparison. Its accepted scenarios revise content once before eight accepted generations, so most repetitions test equal accepted content, not eight distinct geometry replacements. The new gated scenario supplies the repeated changed-content case. Neither harness records per-stage CPU attribution, network time, feed observation, or coordinator scheduling latency.

## Comparable #708 → #709 → #710 observations

The first two timing columns are the previously recorded runs, not recreated historical executions. The third comes from the focused #710 run. All values are milliseconds; source/plan counts are the stable comparison, while separate-run timing ratios include environmental variability.

| Scenario | #708 reads / plans | Post-#709 reads / plans | #708 wall median | #709 wall median | #710 wall median / mean / SD | #710 CPU median / mean / SD |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Full refresh | 8 / 11 | 8 / 11 | 0.921 | 1.098 | 0.383 / 0.971 / 1.625 | 0.767 / 1.692 / 2.578 |
| Day 2 categorical | 8 / 11 | 1 / 1 | 0.527 | 0.194 | 0.077 / 0.093 / 0.049 | 0.143 / 0.159 / 0.055 |
| Day 3 categorical | 8 / 11 | 1 / 1 | 0.557 | 0.253 | 0.075 / 0.082 / 0.021 | 0.152 / 0.157 / 0.025 |
| Warnings | 8 / 11 | 1 / 0 thematic | 0.459 | 0.273 | 0.116 / 0.131 / 0.043 | 0.172 / 0.191 / 0.047 |
| Home hot | 8 / 11 | 2 / 1 thematic | 0.497 | 0.276 | 0.135 / 0.136 / 0.005 | 0.256 / 0.260 / 0.012 |
| Unchanged Day 2 acceptance | 8 / 11 | 1 / 1 | 0.473 | 0.106 | 0.078 / 0.081 / 0.010 | 0.164 / 0.167 / 0.028 |

Warnings patch six current warning slices; Home hot rebuilds meso and patches the other five current warning slices. These patches are separate from thematic plan builds. Other current #710 medians: Day 1 convective 0.149 ms (2 reads / 4 plans), fire 0.073 ms (1 / 1), Day 2 hazards 0.116 ms (1 / 3). One hazard snapshot supplies all three Day 2 hazard plans. The comparison confirms an 87.5% source-read and 90.9% thematic-plan reduction for a categorical future-day update. There is no additional work reduction attributable to #710.

## Selected scene and controlled selection changes

| Scenario | Samples | Reads / plans per sample | Wall median / mean / SD (ms) |
| --- | ---: | ---: | ---: |
| Fresh model, Day 1 categorical | 8 | 8 / 11 | 0.527 / 0.507 / 0.084 |
| Fresh model, Day 2 categorical | 8 | 8 / 11 | 0.381 / 0.391 / 0.038 |
| Fresh model, Day 3 categorical | 8 | 8 / 11 | 0.367 / 0.370 / 0.010 |
| Changed Day 2 acceptance after rapid day/layer switches, gate release → publication | 8 | 1 / 1 | 0.123 / 0.128 / 0.013 |

Full refresh still stages the selected layer's Day 1 input and warnings, its selected plan, remaining current inputs/plans, and then future snapshots/plans. Selecting Day 2/3 does not remove that full-refresh barrier. It reads all eight sources and builds all eleven required plans for first foreground entry. This serial dependency is observable in source, but total preparation is small in the measured fixture, and the older repeated full-refresh benchmark has substantial warmup/scheduling variance. The measurements do not identify a material stage deserving overlap or prove a benefit from prioritizing the selected future-day read.

After #709, a Day 2 categorical acceptance instead requires only its snapshot and plan. Day 1 sources, warnings, Day 2 hazards, and Day 3 neither refetch nor gate that update. The gated fixture proves selection changes use existing accepted plans and do not expand that one-read/one-plan boundary. There is no select-then-unrelated-source dependency left to remove in this case. All changed slices still publish together. No production files or retained-scene policy change; the existing two-scene bound remains covered by scene tests.

## Reproduction and evidence

Run `rtk summary tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/MapAcceptedUpdateMeasurementTests -only-testing:SkyAwareTests/MapAcceptedUpdateScopeTests -only-testing:SkyAwareTests/MapFeatureModelSceneTests`. Export attachments with `xcrun xcresulttool export attachments --path <bundle> --output-path <directory>` and inspect `MapAcceptedUpdateMeasurement.txt` and `MapSelectedSceneCriticalPath.txt`.

The focused finalized result is `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.YF4C4i/unit.xcresult`: 45 logical tests / 58 parameter-expanded executions passed, 0 failed, 0 skipped, 0 expected failures. Both new and existing measurement tests ran. Exported attachments: `/tmp/issue-710-focused-attachments/3F90DDD4-4067-466D-A524-1E2A4954798D.txt` (accepted updates) and `/tmp/issue-710-focused-attachments/296E5D31-B570-49C8-AB23-B1413CB6031C.txt` (critical path). The repository's native verifier confirms the pass; RTK's text summary incorrectly counted logged simulated failure paths as test failures.

The final eleven-suite Map unit gate passed 251 logical tests / 267 parameter-expanded executions, 0 failed, 0 skipped, 0 expected failures. Finalized native result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.160HZe/unit.xcresult`. In addition to the focused selectors above, this run selected `MapFeatureModelTests`, `MapFeatureModelWarningsTests`, `MapDataFreshnessRepoTests`, `MapLegendAccessibilityTests`, `MapPolygonMapperTests`, `RiskPolygonOverlayTests`, `MapSceneWarmingMeasurementTests`, and `HomeRefreshPipelineTests`. It includes both measurement methods, source scopes/coalescing, full-refresh coherence, cancellation/latest-generation handling, warnings, failures/empty inputs, expired forecasts, and cache tests.

The final run reproduced initial Day 1 / Day 2 / Day 3 medians of 0.415 / 0.434 / 0.408 ms (means 0.424 / 0.434 / 0.415; sample SDs 0.077 / 0.023 / 0.018) and gated changed-Day-2 remainder median 0.127 ms (mean 0.125; SD 0.006), again eight repetitions each with unchanged asserted counts. Attachments are in `/tmp/issue-710-final-attachments/`, with the critical-path data in `EA8C5A99-F362-4B37-A5FA-EEBD7DD035B8.txt` and accepted-update data in `9AACE5D1-5038-4319-B8B7-8DB3C04F1E39.txt`. Both runs tested measurement-file SHA-256 `85ad70d38f152e0e3fbec0fe6a3ffbca867569ddfa16c5215f5bf7260c392d3b`; documentation was finalized afterward. Coverage delta is not measured. The full repository unit suite was not selected; no UI tests ran.
