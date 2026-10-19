# Map Efficiency 01 baseline — #708

Date: 2026-10-19. Baseline source revision: `6972eb9a1e6aac5dbef4a86e88dfebbbb66b390d` (`main`, including integrated #702/#598 and #706). Original baseline validation revision: `6972eb9a1e6aac5dbef4a86e88dfebbbb66b390d`. Accepted-update measurement test revision: PR head `64ec07a1701cbe971fb731816cfa20aaa5d708ee`. Environment: Debug, iPhone 17 simulator, iOS 26.5 (runtime 26.5, simulator identifier `iPhone18,3`).

## Method

The original baseline run on `6972eb9a1e6aac5dbef4a86e88dfebbbb66b390d` passed the full unit lane with 1,412 logical tests passed and 1 skipped (1,539 parameter-expanded passed, 1 skipped). During the review correction, the focused unit lane covering accepted-update measurement, scene warming, Map scene, Map warnings, and risk overlay tests passed 58/58. The finalized bundle is `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.eZNeAE/unit.xcresult`.

A fresh full unit lane was also attempted after the correction and failed: 1,264 logical tests passed, 149 failed, and 1 was skipped (1,373 parameter-expanded passed, 163 failed, and 1 skipped). The result contains repeated test-process crashes in Swift Testing's `_applyScopingTraits`; the captured crash for `SPCCurrentDiscussionTests.issuance_rollover_and_bounds()` shows a Core Data notification callback from `ConvectiveOutlookRepo.replaceAcceptedCollection` on an `NSManagedObjectContext` queue. This is outside the changed files; the focused Map suite passed. The failed bundle is `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.haWthM/unit.xcresult`. No UI test lane or UI tests ran.

The original warming test performs one warmup and records 10 manual subscenario samples, with a separate 10-iteration XCTest clock/CPU measurement. Its attachment is `MapSceneWarmingMeasurement.txt` in `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.pBpqiJ/unit.xcresult`.

The counted accepted-update measurement test ran on PR head `64ec07a1701cbe971fb731816cfa20aaa5d708ee` as `MapAcceptedUpdateMeasurementTests.testAcceptedReloadScenariosRecordSourceReadsAndSelectedSceneChurn()` through the focused unit lane with its exact selector. Its finalized `.xcresult` reports 1 executed, 1 passed, 0 failed, 0 skipped. The corrected attachment is `2E59F7DE-90E5-40A7-AE8E-53D817BEB239.txt` in `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.knbOws/unit.xcresult`.

The synthetic fixtures cover small (one risk polygon per layer, one warning, four vertices), representative (1–8 risk polygons per layer, four warnings, 12 vertices), and high-volume (40–120 risk polygons per layer, 25 warnings, 48 vertices) inputs, with warning geometry on and off. Exterior rings, some interior rings, production-shaped keys/styles, deterministic scene materialization, retained scene/overlay counts, and selected versus inactive scene materialization are exercised. A second unit test uses in-memory counted providers for eight repeated full model reloads per scenario and records wall/CPU time, provider reads, selected day, overlay count/revision, and completed reloads. It simulates accepted generations by calling `invalidateAcceptedInputs()` before the reload; it does not exercise the feed observer or reload coordinator. No production instrumentation was added.

## Accepted-update work in the current implementation

`MapFeatureModel.performReload` provides a deterministic operation inventory for a full accepted reload, regardless of which currently recognized feed triggered it. The selected layer fetches one current source plus active warnings; the remaining payload fetches the other three current sources. Each measured reload therefore reads once from each current source (categorical, severe hazards, nationwide meso, and fire), once from active warnings, and once each for Day 2 categorical, Day 2 hazards, and Day 3 categorical forecasts. The counted-provider test observed this same eight-read inventory in every sample. Source/plan preparation remains coordinated through the model; static inspection finds six current layer plans and five supported future plans built before one coherent replacement. The model clears its scene cache and replaces the selected scene after each successful reload; the test observes the completed selected scene's day, overlay count/revision, and completed reloads, while cache clearing and exact planner invocations remain call-graph counts rather than injected counters.

| Scenario | Selected scene after reload | Completed reloads | Wall median / mean / SD | CPU median / mean / SD |
| --- | --- | ---: | ---: | ---: |
| Full reload | Day 1, 1 overlay | 8/8 | 0.921 / 9.401 / 23.791 ms | 1.725 / 4.000 / 6.122 ms |
| Day 2 accepted update | Day 2, 1 overlay | 8/8 | 0.527 / 0.673 / 0.318 ms | 0.976 / 1.044 / 0.332 ms |
| Day 3 accepted update | Day 3, 1 overlay | 8/8 | 0.557 / 0.562 / 0.077 ms | 0.753 / 0.832 / 0.134 ms |
| Warning accepted update | Day 1, 2 overlays | 8/8 | 0.459 / 0.499 / 0.087 ms | 0.799 / 0.892 / 0.223 ms |
| Hot accepted update | Day 1, 2 overlays | 8/8 | 0.497 / 0.588 / 0.224 ms | 0.946 / 0.999 / 0.214 ms |
| Unchanged accepted data | Day 1, 2 overlays | 8/8 | 0.473 / 0.473 / 0.053 ms | 0.794 / 0.852 / 0.170 ms |

Every row observed the same provider read counts per run: current categorical 1, severe 1, nationwide meso 1, fire 1, warnings 1, Day 2 categorical 1, Day 2 hazards 1, and Day 3 categorical 1. This includes eight reads for the initial full reload, both future-day accepted updates, warning and hot updates, and unchanged accepted data.

The provider source counts are observed for each of eight repetitions. The `full-reload` row starts from an empty model; accepted-update rows increment the model's accepted-input revision before reloading and assert that the scenario's feed ID is classified as reloadable. The test bypasses `FeedStateStore` and `MapReloadCoordinator`, so it measures model work after scheduling rather than those boundaries. The unchanged-data scenario confirms equal fixture input still triggers the same work. The completed active scene reports its selected forecast day, overlay count, and overlay revision each time; the warning, hot, and unchanged rows resolve to the same overlay revision because their inputs are identical. The completed reload count records successful model reloads; private cache hits and invalidations are not exposed, so the one cache clear per successful full replacement remains a static call-graph count. Existing scene unit tests independently verify the two-scene capacity.

These observed provider counts confirm redundant reads in the current implementation, including unchanged accepted data. The in-memory actors return small synthetic fixtures; timings include provider hops, planning, and selected-scene materialization, but exclude network/transport, feed observation, coordinator scheduling, SwiftUI rendering, and MapKit drawing. Full-reload mean and variance are dominated by one or more outliers, so its timing is inconclusive. The other scenario medians are tightly clustered around 0.46–0.56 ms, but these synthetic Debug simulator timings do not establish user-visible latency. `FeedStateStore` generation changes mean acceptance, not necessarily geometry/content change. The all-plan coherent replacement boundary is intentional and remains part of the measured inventory; this report does not recommend dropping it. Existing unit coverage confirms the two-scene forecast cache remains bounded and exercises atomic replacement, supersession, failure, and cancellation.

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
- **Inconclusive rendering cost:** the harness does not invoke `RiskPolygonRenderer.draw`, clip to a draw region, or measure hatch stroke generation. #712 owns the initial representative hatch workload and profiling, so #708 does not duplicate a renderer-specific proxy. This report cannot claim hatching is a bottleneck or negligible.
- **Not assessed / deferred:** accessibility-summary repeat cost was not benchmarked. No optimization or instrumentation recommendation follows from #708.

## Limitations

Provider read counts and selected-scene outputs for the six cases above are emitted by counted test providers. Current/future plan-build counts and cache clearing remain static call-graph measurements; no test-only planner counters were introduced. Timings cover in-memory model reload and synthetic plan materialization, not network transport, feed observer/coordinator scheduling, hatch drawing, manual viewport interaction, Instruments, or physical devices. Rapid selection/reload coalescing was not separately timed. Debug simulator samples, especially the cold full-reload row, have substantial variance, so compare operation counts rather than treating these absolute times as device performance claims.

## Source-scoped follow-up — #709

Comparison base: `c83d137` (integrated #708). The follow-up retains the same small counted-source fixtures, eight repetitions, Debug configuration, and iPhone 17 / iOS 26.5 unit lane. `MapAcceptedUpdateMeasurementTests` now passes actual accepted feed identities and monotonically increasing generations through the model's scoped reload entry point. Separate `MapAcceptedUpdateScopeTests` exercise the production observer/coordinator contracts and gated coalescing; no UI automation or live providers participate. A test-only planner actor delegates to the production builder and counts actual thematic plan calls. Warning-slice patches are reported separately because they preserve existing thematic plans and freshness.

| Accepted update | #708 source reads / plan builds | Scoped source reads / thematic plan builds | Shared warning-slice work |
| --- | ---: | ---: | --- |
| Explicit full refresh / initial load | 8 / 11 | 8 / 11 | Included in six current plans |
| Day 1 convective | 8 / 11 | 2 / 4 | Retain accepted warnings |
| Day 2 categorical | 8 / 11 | 1 / 1 | None |
| Day 3 categorical | 8 / 11 | 1 / 1 | None |
| Day 2 hazards | 8 / 11 | 1 / 3 | None; one shared hazard snapshot |
| Fire | 8 / 11 | 1 / 1 | Retain accepted warnings |
| `arcus.alert` or `arcus.alerts` | 8 / 11 | 1 / 0 | Patch six current plans |
| `home.hot.*` | 8 / 11 | 2 / 1 | Meso build plus five current warning patches |
| Foreground meso cadence | 1 / 1 | 1 / 1 | Retain accepted warnings |
| Unrelated or duplicate generation | Unrelated feeds already ignored; duplicate model reloads read 8 / build 11 | 0 / 0 | None |

A newer accepted generation with identical content still rereads and plans its contracted slice: generation alone cannot prove content equality. Final comparison includes geometry, styles, titles, legend items, presentation state, forecast day, and issuance/validity. Equal results retain cached scenes and overlays without publishing resolving state. Changed cached scenes reuse overlays whose semantic keys, signatures, and titles remain equal. Updating a current plan preserves future scenes with the same layer. The cache still retains at most two existing scenes; this change adds no overlay cache and creates no uncached inactive scenes.

Affected plans are staged until the whole requested scope finishes, then committed synchronously. Scheduling records generations and unions scopes before the coordinator can replace a pending operation. Superseded and cancelled candidates return their scope to the pending set, including when a provider returns despite cancellation. Full reentry remains explicit and establishes all selectable accepted inputs; the independent meso cadence remains lower priority than a queued accepted reload. Deterministic tests cover merged Day 1 / Day 2 / Day 3 / hot / warning updates, direct mid-load requests, selection and warning-toggle changes, accepted empty data, failed reads, cancellation, unchanged results, and validity-only changes.

### Final follow-up evidence

The final eleven-suite unit gate passed with 250 logical tests / 266 parameter-expanded executions, 0 failed, 0 skipped, and 0 expected failures. It includes scoped acceptance and measurement, Map feature/scene/warning/freshness/legend/mapper/rendering suites, scene warming, and `HomeRefreshPipelineTests`. Native result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.GqlGso/unit.xcresult`. The final measurement attachment is `A2794C86-9993-48A4-B10B-6E70CCC22F90.txt` in that bundle (exported to `/tmp/issue-709-final-attachments/`). Runtime/test file fingerprints are recorded in `/tmp/issue-709-final-source-fingerprints.txt`; documentation was completed after validation. The focused correction lane also passed 62 logical tests / 75 expanded executions, with no failures or skips, in `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.TVFrda/unit.xcresult`. No UI tests ran.

The following comparable scenarios each completed all eight repetitions. Values are milliseconds; final mean and sample standard deviation accompany each median. Full-refresh counts remain unchanged and its timing varies, illustrating the limits of comparing separate Debug simulator runs.

| Scenario | #708 wall median | Final wall median / mean / SD | Final CPU median / mean / SD |
| --- | ---: | ---: | ---: |
| Full refresh | 0.921 | 1.098 / 1.823 / 1.835 | 1.123 / 1.722 / 1.522 |
| Day 2 categorical acceptance | 0.527 | 0.194 / 0.216 / 0.059 | 0.256 / 0.260 / 0.062 |
| Day 3 categorical acceptance | 0.557 | 0.253 / 0.264 / 0.118 | 0.258 / 0.257 / 0.068 |
| Warning acceptance | 0.459 | 0.273 / 0.498 / 0.585 | 0.296 / 0.323 / 0.095 |
| Hot acceptance | 0.497 | 0.276 / 0.384 / 0.341 | 0.463 / 0.457 / 0.087 |
| Unchanged accepted content | 0.473 | 0.106 / 0.113 / 0.028 | 0.157 / 0.179 / 0.056 |

Source and planner counts are the repeatable optimization evidence. Timing samples ran alongside other unit suites, include actor scheduling, and show substantial variance in several rows; they establish no user-visible latency promise. The fire and hazard measurement rows retain categorical selection and measure isolated work, while separate parameterized unit tests select fire and all current/Day 2 hazards with changed nonempty geometry, risk legends, and future validity. Deterministic materializer tests cover equal overlay reuse, duplicate prior keys, changed signatures/geometry, and corrected titles. Independent review identified and verified a correction preserving out-of-scope warnings after a failed thematic read from accepted-empty/unavailable state.
