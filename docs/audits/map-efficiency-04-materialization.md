# Map Efficiency 04 — lazy polygon construction (#711)

Date: 2026-10-19. Baseline production revision: `0d73339` (integrated #709/#710). References: [#708 baseline](map-efficiency-01-baseline.md), [#710 critical path](map-efficiency-03-critical-path.md).

## Decision and scope

Proceed with a local materializer optimization. #709 already compares accepted plan content, including source/layer/day identity, complete polygon coordinates/interiors, overlay keys/signatures and legend presentation/forecast period. Equal accepted snapshots therefore retain cached scenes; feed generation alone is not content identity. No further model invalidation or scheduling change is justified here.

The remaining redundant work occurs when a retained scene needs new metadata or a partially changed overlay slice: the materializer eagerly constructs every polygon before checking overlay reuse. Cold scenes also construct warnings that are hidden. Move construction after visibility and existing overlay identity checks, and share newly constructed polygons among styles within that invocation. Retain the existing key/signature/title/subtitle reuse contract, overlay ordering and revision hashing. Always publish the new plan's legend and derive warning legend items from visible overlays. The injected polygon factory defaults to the existing constructor and enables local test counters; it adds no global state or telemetry.

The change retains main-actor ownership, existing two-scene LRU capacity, forecast-day selection identity and cold-eviction reconstruction. It does not introduce another geometry cache, warm inactive scenes, change warning ingestion, or alter canvas reconciliation. MapCanvasView already skips overlay synchronization when the materialized revision is unchanged.

## Method and baseline

Reuse #708's small, representative and high-volume categorical fixtures, respectively 1/5/80 thematic polygons and 1/4/25 warning polygons, with 4/12/48 exterior vertices and existing thematic interior-ring patterns. Ten repetitions for each combination of warnings shown/hidden and cold/retained scene. Time only the production materializer with the same injected counting factory before and after. Count factory calls directly; derive total MKPolygon objects from each constructed entry's valid interior rings plus exterior. Verify overlay reuse by comparing every retained result identity with the prior scene; cold overlay counts equal visible overlay counts. Plan construction and the initial retained scene are outside the measured interval. A retained identical render input also represents the geometry work in a metadata-only publication; unchanged accepted snapshots normally bypass this call entirely.

Wall time uses the existing DispatchTime helper; CPU uses process-wide CLOCK_PROCESS_CPUTIME_ID and can include other test work. Recorded medians select sorted sample index 5 of 10, matching the test report. Debug, arm64 iPhone 17 simulator, iOS 26.5. These are synthetic unit measurements, not rendered/device latency claims. Counts are the deterministic benefit; timing varies with concurrent test scheduling and warmup. The initial baseline selected only the new measurement method; the subsequent run includes other Map suites.

Baseline finalized result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.mBeHVO/unit.xcresult`, 1 test passed, zero failures/skips/expected failures. Baseline attachment: `/tmp/issue-711-before-attachments/72891782-A2A4-4A19-AE1E-3FD92C9A4C66.txt`. This revision contains only the constructor injection and measurement method, before lazy construction.

| Fixture / scenario | Before entries / polygon objects | Before wall / CPU median (ms) |
| --- | ---: | ---: |
| Small retained, warnings shown | 2 / 2 | 0.0112 / 0.012 |
| Representative retained, warnings shown | 9 / 11 | 0.0507 / 0.050 |
| High-volume retained, warnings shown | 105 / 125 | 0.9046 / 1.667 |
| Representative cold, warnings hidden | 9 / 11 | 0.2197 / 0.219 |
| High-volume cold, warnings hidden | 105 / 125 | 3.7415 / 7.728 |

Retained scenarios already allocate zero new overlay objects; the improvement targets discarded polygon allocations. Cold visible scenes necessarily construct all requested geometry and overlays. No additional accepted-store reads or plan builds are removed by this issue.

## Initial after measurement

The first optimized run's measurement passed; its overall focused lane failed one new fixture assertion because the warning mapper intentionally strips interior rings. The fixture was corrected to supply an interior-capable render entry directly. Production behavior was not changed in response. This failed lane is retained as diagnostic evidence, not a passing validation gate: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.Lr9nmz/unit.xcresult`, 16 logical tests passed, 1 failed. Measurement attachment: `/tmp/issue-711-focused-attachments/B1EA9BD4-92DC-49BE-B1D1-D743ABD2CEDD.txt`.

| Fixture / scenario | After entries / polygon objects | After wall / CPU median (ms) |
| --- | ---: | ---: |
| Small retained, warnings shown | 0 / 0 | 0.0096 / 0.009 |
| Representative retained, warnings shown | 0 / 0 | 0.0346 / 0.034 |
| High-volume retained, warnings shown | 0 / 0 | 0.3377 / 0.337 |
| Representative cold, warnings hidden | 5 / 7 | 0.2419 / 0.241 |
| High-volume cold, warnings hidden | 80 / 100 | 3.9795 / 3.979 |

The high-volume retained fixture eliminates all 125 polygon objects and reduces median wall time about 63%; the representative retained case eliminates all 11 and reduces median wall time about 32%. Hidden-warning cold scenes omit exactly 4 or 25 warning polygons. Cold timing does not improve in this run (about 6–10% slower for these rows); dictionary setup and other runtime work remain, and separate-run process CPU figures are noisy. Do not claim a cold-switch latency improvement. The justification is reduced allocations and measured retained-scene work with a small local change, not a general performance claim.

## Behavioral verification

New counted tests cover zero construction on equal retained inputs, title/signature/geometry replacement, metadata-only stale legend publication with unchanged revision, hidden warnings, warning restoration, changed warning message identity, interior-bearing warning render input, and a shared probability/intensity polygon. Existing scoped acceptance tests cover equal accepted snapshots, validity changes, thematic/warning slices, failures, confirmed empties, cancellation and coalescing. Scene tests cover cold layer/day selection, deterministic eviction, bounded retention and coherent replacement. The canvas guard remains unchanged: an equal overlay revision does not synchronize overlays; this is supported by the existing guard and revision assertions, not a rendered UI measurement.

Reproduce with `rtk summary tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/MapAcceptedUpdateScopeTests -only-testing:SkyAwareTests/MapSceneWarmingMeasurementTests/testRetainedScenePolygonConstruction`. Export `MapRetainedSceneMeasurement.txt` from the finalized bundle with `xcrun xcresulttool export attachments --path <bundle> --output-path <directory>`.

Corrected focused gate: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.c47V2q/unit.xcresult`, 16 logical tests / 29 parameter-expanded executions passed, zero failures/skips/expected failures. The selected suites were `MapAcceptedUpdateScopeTests` and `MapSceneWarmingMeasurementTests/testRetainedScenePolygonConstruction`. The rerun reproduced zero polygon construction for every retained fixture and high-volume visible-retained wall/CPU medians of 0.3330/0.544 ms; representative medians were 0.0350/0.035 ms. Attachment: `/tmp/issue-711-corrected-attachments/5619C2AE-1735-4C26-9ACD-A27ACACFC09B.txt`. RTK misclassifies logged simulated failures; native finalized results and `ci_scripts/verify_xcresult.sh` are authoritative.

Tested SHA-256 fingerprints (focused corrected and final gate unless explicitly noted otherwise): `Sources/Features/Map/MapRenderPlan.swift` = `42cf6915dd84f39a6da8011e519bb2cf5d90e23277fb57a5ac9033cf977d2ae3`; `Tests/UnitTests/MapAcceptedUpdateMeasurementTests.swift` = `90246cb322ad98079092e35bf73fd1b27a0ea251a11c9e707097f295f334cfb9`; `Tests/UnitTests/MapSceneWarmingMeasurementTests.swift` = `bc8642888103e6a54b3d76d51630d80dcd34bc921df5961a5f0cc29e6c2e0946`. Documentation is finalized after tests. Coverage delta is not measured. UI tests, physical-device runs and rendered performance checks are excluded.

## Final validation and review

Independent read-only defect review found no actionable introduced defects and verified the focused native result plus source/test fingerprints. The configured `skyaware_reviewer` role was unavailable, so a standard isolated agent performed that review with the same bounded assignment.

The final eleven-suite Map unit gate passed 253 logical tests / 269 parameter-expanded executions, zero failures, skips or expected failures. Finalized native bundle: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.LxZMaM/unit.xcresult`; verified with `ci_scripts/verify_xcresult.sh`. Selected suites: `MapAcceptedUpdateMeasurementTests`, `MapAcceptedUpdateScopeTests`, `MapFeatureModelSceneTests`, `MapFeatureModelTests`, `MapFeatureModelWarningsTests`, `MapDataFreshnessRepoTests`, `MapLegendAccessibilityTests`, `MapPolygonMapperTests`, `RiskPolygonOverlayTests`, `MapSceneWarmingMeasurementTests`, and `HomeRefreshPipelineTests`. The full repository unit suite was not selected; UI tests did not run.

The final run again eliminated all retained-fixture polygon allocations. High-volume visible-retained wall/CPU medians were 0.3027/0.302 ms, compared with baseline 0.9046/1.667 ms; representative medians were 0.0302/0.030 ms versus 0.0507/0.050 ms. Cold hidden-warning high-volume work was 80 entries / 100 polygon objects, with wall/CPU medians 3.7107/3.710 ms; baseline was 105 entries / 125 objects and 3.7415/7.728 ms. Across optimized runs high-volume retained wall medians ranged 0.3027–0.3377 ms; hidden-warning cold medians ranged 3.7107–4.1228 ms. This supports the retained-work reduction while leaving cold latency inconclusive. Final measurement attachment: `/tmp/issue-711-final-attachments/0CD98E6B-39BC-4FA7-8F6B-2A2F8E0927DC.txt`.
