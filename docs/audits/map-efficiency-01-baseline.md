# Map Efficiency 01 baseline — #708

Date: 2026-10-19. Baseline revision: `6972eb9a1e6aac5dbef4a86e88dfebbbb66b390d` (`main`, including integrated #702/#598 and #706). Validation revision: same commit. Environment: Debug, iPhone 17 simulator, iOS 26.5 (runtime 26.5, simulator identifier `iPhone18,3`).

## Method

Ran the full unit lane through `tools/ci/run_test_lane.sh unit`; the finalized `.xcresult` reports 1,413 logical tests, 1,412 passed, 0 failed, and 1 skipped (1,540 parameter-expanded executions: 1,539 passed, 0 failed, 1 skipped). The specific measurement test also ran first through `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/MapSceneWarmingMeasurementTests/testInactiveSceneWarmingTradeoff`; its finalized `.xcresult` reports 1 executed, 1 passed, 0 failed, 0 skipped. It performs one warmup and records 10 manual subscenario samples, with a separate 10-iteration XCTest clock/CPU measurement. Its attachment is `MapSceneWarmingMeasurement.txt` in `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.pBpqiJ/unit.xcresult`.

The full unit result bundle is `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.retgE8/unit.xcresult`. No UI test lane or UI tests ran.

The synthetic fixtures cover small (one risk polygon per layer, one warning, four vertices), representative (1–8 risk polygons per layer, four warnings, 12 vertices), and high-volume (40–120 risk polygons per layer, 25 warnings, 48 vertices) inputs, with warning geometry on and off. Exterior rings, some interior rings, production-shaped keys/styles, deterministic scene materialization, retained scene/overlay counts, and selected versus inactive scene materialization are exercised. No production instrumentation was added.

## Accepted-update work in the current implementation

`MapFeatureModel.performReload` provides a deterministic operation inventory for a full accepted reload, regardless of which currently recognized feed triggered it. In the current broad-invalidation path, the selected layer fetches one of its data sources plus active warnings; the remaining payload fetches each of the other three map sources. Therefore each reload reads once from each current source (categorical, severe hazards, nationwide meso, and fire) and once from active warnings. Future forecast planning reads Day 2 categorical, Day 2 hazards, and Day 3 categorical once each. The reload builds six current layer plans and five supported future plans, replaces the plan set coherently, clears the scene cache, and materializes the selected scene once. These are direct counts from the current call graph, not timed end-to-end accepted-update measurements.

| Accepted update scenario | Current source reads | Forecast reads | Current plans | Future plans | Selected scene materializations |
| --- | --- | --- | ---: | ---: | ---: |
| Initial Map open / full reload | Categorical 1, hazards 1, meso 1, fire 1, warnings 1 | Day 2 categorical 1, Day 2 hazards 1, Day 3 categorical 1 | 6 | 5 | 1 |
| Day 1 convective | Same full set | Same full set | 6 | 5 | 1 |
| Day 2 categorical | Same full set | Same full set | 6 | 5 | 1 |
| Day 2 hazards | Same full set | Same full set | 6 | 5 | 1 |
| Day 3 categorical | Same full set | Same full set | 6 | 5 | 1 |
| Fire-only | Same full set | Same full set | 6 | 5 | 1 |
| `home.hot.*` | Same full set | Same full set | 6 | 5 | 1 |
| `arcus.alert` / `arcus.alerts` | Same full set | Same full set | 6 | 5 | 1 |
| Foreground meso-only refresh | Nationwide meso 1 | None | 1 | 0 | 0 or 1, depending on selected layer and cache state |
| Unchanged accepted data | Same full set when a relevant accepted generation schedules reload | Same full set | 6 | 5 | 1 |
| Rapid day/layer selection without a feed update | None | None | None; existing plans are selected | None | Cache hit or one materialization on cache miss |

These operation counts confirm redundant work in the current implementation, but they do not prove user-visible latency. `FeedStateStore` generation changes mean acceptance, not necessarily geometry/content change. The all-plan coherent replacement boundary is intentional and remains part of the measured inventory; this report does not recommend dropping it. Existing unit coverage confirms the two-scene forecast cache remains bounded and exercises atomic replacement, supersession, failure, and cancellation.

## Materialization observations

For the representative fixture with warnings off, 10 explicit samples produced:

| Scenario | Cached scenes | Cached overlays | Wall median | Wall mean | Wall standard deviation | CPU median | CPU mean | CPU standard deviation |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Selected categorical scene | 1 | 5 | 0.2385 ms | 0.2363 ms | 0.0082 ms | 0.2410 ms | 0.3355 ms | 0.1717 ms |
| Selected plus first cold switch | 2 | 13 | 0.5713 ms | 0.5704 ms | 0.0135 ms | 0.5800 ms | 0.7078 ms | 0.1980 ms |
| Inactive layers total | 5 | 29 | 1.2648 ms | 1.2541 ms | 0.0300 ms | 2.0210 ms | 1.8214 ms | 0.6349 ms |
| Selected plus eager all-layer materialization | 6 | 34 | 1.4948 ms | 1.4849 ms | 0.0332 ms | 2.2460 ms | 2.1610 ms | 0.7728 ms |

Wall-time coefficient of variation was 2.2–3.5% for these rows; CPU variation was higher at 28–51%. These are Debug simulator synthetic materialization measurements, not device promises. The eager row is a comparative workload only; it is not a proposed behavior. The production cache remains capped at two scenes. Previous fixed #394/#399 work bounded inactive scene warming; the remaining measured materialization work here is the scene selected after accepted replacement and cold switching.

## Cost classification and recommendations

- **Verified redundant work:** every relevant accepted update currently rereads all four current sources and active warnings, rebuilds six current plans and five future plans, and discards reusable scenes even when a single source changed or the accepted payload is unchanged. The call graph establishes this work; the benchmark does not time the reload. Proceed with #709 source-selective invalidation while retaining warning and nationwide meso semantics and coherent publication of affected slices.
- **Demonstrated materialization cost:** selected scene construction is small in this synthetic fixture; constructing all inactive scenes adds measurable work and is already avoided by the bounded two-scene policy. Do not reopen #394/#399 or add eager warming.
- **Inconclusive critical-path latency:** the harness does not measure async fetch, planning, scheduling, accepted replacement, or visible scene refresh as a combined operation. Defer #710 until #709 has a comparable post-change profile. No evidence currently justifies changing the coherent publication boundary.
- **Inconclusive rendering cost:** the harness does not invoke `RiskPolygonRenderer.draw`, clip to a draw region, or measure hatch stroke generation. Proceed with the independent targeted profile in #712; this report cannot claim hatching is a bottleneck or negligible.
- **Negligible/rejected:** no meaningful accessibility-summary repeat cost was demonstrated or benchmarked; do not add instrumentation or optimization for it under #708.

## Limitations

Per-source/per-layer operation counts above are derived from the inspected production call graph, not emitted by per-source spies. Timings cover synthetic plan materialization only; they do not cover complete accepted-update scenarios, hatch drawing, manual viewport interaction, Instruments, or physical devices. Rapid selection/reload coalescing was not separately timed. Debug simulator CPU samples show substantial variance. These gaps constrain latency conclusions but do not erase the directly visible broad invalidation and plan-build counts.
