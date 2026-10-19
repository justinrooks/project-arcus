# Map Efficiency 05 — bounded hatch drawing (#712)

Date: 2026-10-19. Production baseline: `78237f7254f5ca978908f36caa66f8be821f0f6f` (`main`, including #702 and #708–#711). [#708](map-efficiency-01-baseline.md) explicitly left hatch CPU cost unmeasured; this investigation supplies that missing workload and go/no-go evidence.

## Decision and implementation

Proceed. A nationwide rectangular polygon at zoom 0.004 generated 11,667 candidate hatch stripes for both 256- and 1,024-pixel draw regions. Eight repeated baseline draws per case took 8.2–14.8 seconds at the median. Selecting the stripes relevant to the draw region reduces that to 15–49 stripes and 13.3–47.6 milliseconds: roughly 180–1,118 times less wall time across these four synthetic cases. Stripe count falls by more than 99.5%. The small-polygon medians remain below 0.3 ms after optimization, with no pathological ordinary-case overhead observed.

Convert MapKit's supplied map rectangle with `rect(for:)` before comparing it with the path. Intersect with the existing expanded polygon bounds, add conservative stroke/antialias padding, and inverse-rotate the relevant rectangle into hatch coordinates. Round the selected stripe indices outward, including spare edge stripes. Retain the original polygon-centered lattice and original line endpoints, which preserve stripe alignment and dash phase. Keep the existing even-odd polygon clip, threshold, screen-relative relaxation, styles, fill/stroke ordering, and probability branch. No map UI, overlay identity, data-source, cache, or renderer architecture changes.

[Apple's renderer documentation](https://developer.apple.com/documentation/mapkit/mkoverlayrenderer/draw(_:zoomscale:in:)) requires conversion from map geometry to renderer drawing coordinates and recommends avoiding whole-overlay drawing for each region. [The conversion API](https://developer.apple.com/documentation/mapkit/mkoverlayrenderer/rect(for:)) returns the renderer-space rectangle. Tests construct actual MKPolygons, create their renderer paths, and use the inverse `mapRect(for:)` conversion to exercise this boundary without assuming equal coordinate origins.

## Reproduction and method

Debug, arm64 iPhone 17 simulator, iOS 26.5 (23F77), built on macOS 27.0.1. `RiskPolygonOverlayTests.hatchDrawingMeasurement()` invokes the real production renderer into clipped RGBA bitmap contexts. Two four-vertex rectangular polygons begin at map point (80,000,000, 80,000,000), with width 100,000 or 40,000,000 map points and height 0.6 times width. The larger rectangle approximates nationwide extent. Level 2 uses its production dashed recipe, angles -45 and 30 degrees, zooms 0.0001 and 0.004, and centered 256- or 1,024-pixel square draw regions. Thus mapRect origin is (80,000,000 + width/2 - pixels/(2*zoom), 80,000,000 + 0.3*width - pixels/(2*zoom)), with size (pixels/zoom, pixels/zoom). This fully specifies every mapRect in the tables.

One warmup, then eight samples per case (16 cases, 128 measured draws per run). Wall time uses DispatchTime; process CPU uses CLOCK_PROCESS_CPUTIME_ID. Both zooms reach the existing 32-pixel spacing cap and 3.5 relaxation cap. Baseline candidate counts are the original loop's mathematical count; optimized counts are returned by the same stripe-range function used in production. Context creation and path creation occur outside the timing interval; draw and context flush are timed. Samples report the upper middle sorted sample as median and sample standard deviation (n-1). CPU is process-wide and includes any other test/runtime work. These are synthetic renderer-work measurements, not interactive map latency or physical-device claims, and there is no absolute timing assertion.

The baseline suite includes nine existing tests plus the measurement. The optimized comparison selects only the measurement to reduce scheduling interference. Baseline high-cost variance is substantial, but even the slowest optimized median is below the fastest baseline median by about 180 times. A separate optimized suite run reproduced 15–49 stripes and 13.7–47.6 ms high-cost medians. Ordinary-polygon timing is near measurement noise; only the absence of pathological overhead is claimed. Original endpoints intentionally remain long so dash phase stays unchanged; the optimization bounds stripe count, not all dash-segment work as polygon size grows.

Reproduce the current measurement with `rtk summary tools/ci/run_test_lane.sh unit '-only-testing:SkyAwareTests/RiskPolygonOverlayTests/hatchDrawingMeasurement()'`. Export its `HatchDrawingMeasurement.txt` attachment with `xcrun xcresulttool export attachments --path <bundle> --output-path <directory>`. Swift Testing method selectors require the parentheses; the initial selector without them matched zero tests, was rejected by the verifier, and is not evidence.

## Measurements

All times are milliseconds, shown as median / mean / sample SD. Small = width 100,000 map points; nationwide = width 40,000,000. Regions are screen pixels per side. Baseline and optimized rows below have the same geometry and rendering recipe.

### Baseline

| Polygon | Zoom | Region | Angle | Candidate stripes | Wall median / mean / SD | CPU median / mean / SD |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Small | 0.0001 | 256 | -45.0 | 6 | 0.035 / 0.043 / 0.040 | 0.107 / 0.099 / 0.075 |
| Small | 0.0001 | 1024 | -45.0 | 6 | 0.015 / 0.017 / 0.004 | 0.024 / 0.024 / 0.014 |
| Small | 0.0001 | 256 | 30.0 | 6 | 0.016 / 0.016 / 0.001 | 0.016 / 0.016 / 0.001 |
| Small | 0.0001 | 1024 | 30.0 | 6 | 0.014 / 0.015 / 0.001 | 0.014 / 0.015 / 0.001 |
| Small | 0.004 | 256 | -45.0 | 35 | 0.217 / 0.220 / 0.013 | 0.497 / 0.527 / 0.235 |
| Small | 0.004 | 1024 | -45.0 | 35 | 0.301 / 0.307 / 0.016 | 0.774 / 0.700 / 0.351 |
| Small | 0.004 | 256 | 30.0 | 35 | 0.221 / 0.221 / 0.004 | 0.533 / 0.522 / 0.118 |
| Small | 0.004 | 1024 | 30.0 | 35 | 0.312 / 0.325 / 0.025 | 0.650 / 0.782 / 0.271 |
| Nationwide | 0.0001 | 256 | -45.0 | 297 | 7.283 / 7.827 / 1.275 | 22.358 / 20.338 / 7.520 |
| Nationwide | 0.0001 | 1024 | -45.0 | 297 | 10.673 / 10.553 / 0.513 | 21.264 / 20.986 / 1.610 |
| Nationwide | 0.0001 | 256 | 30.0 | 297 | 6.987 / 6.987 / 0.075 | 13.835 / 13.539 / 0.926 |
| Nationwide | 0.0001 | 1024 | 30.0 | 297 | 10.483 / 10.576 / 0.266 | 21.407 / 21.113 / 2.659 |
| Nationwide | 0.004 | 256 | -45.0 | 11667 | 14848.431 / 13276.883 / 2721.234 | 14972.460 / 13352.862 / 2739.832 |
| Nationwide | 0.004 | 1024 | -45.0 | 11667 | 8993.438 / 9127.308 / 638.619 | 8999.137 / 9145.048 / 675.243 |
| Nationwide | 0.004 | 256 | 30.0 | 11667 | 11874.875 / 11632.462 / 1999.937 | 11865.697 / 11551.938 / 1837.933 |
| Nationwide | 0.004 | 1024 | 30.0 | 11667 | 8232.554 / 8180.602 / 248.241 | 8236.011 / 8200.959 / 245.342 |

### Bounded

| Polygon | Zoom | Region | Angle | Candidate stripes | Wall median / mean / SD | CPU median / mean / SD |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Small | 0.0001 | 256 | -45.0 | 6 | 0.014 / 0.017 / 0.010 | 0.013 / 0.017 / 0.009 |
| Small | 0.0001 | 1024 | -45.0 | 6 | 0.012 / 0.013 / 0.003 | 0.011 / 0.012 / 0.002 |
| Small | 0.0001 | 256 | 30.0 | 6 | 0.012 / 0.012 / 0.001 | 0.011 / 0.011 / 0.000 |
| Small | 0.0001 | 1024 | 30.0 | 6 | 0.012 / 0.012 / 0.000 | 0.011 / 0.011 / 0.001 |
| Small | 0.004 | 256 | -45.0 | 16 | 0.157 / 0.160 / 0.009 | 0.157 / 0.159 / 0.009 |
| Small | 0.004 | 1024 | -45.0 | 21 | 0.268 / 0.269 / 0.015 | 0.267 / 0.268 / 0.015 |
| Small | 0.004 | 256 | 30.0 | 15 | 0.162 / 0.162 / 0.005 | 0.161 / 0.166 / 0.016 |
| Small | 0.004 | 1024 | 30.0 | 20 | 0.265 / 0.268 / 0.013 | 0.265 / 0.268 / 0.013 |
| Nationwide | 0.0001 | 256 | -45.0 | 15 | 0.445 / 0.448 / 0.010 | 0.444 / 0.447 / 0.009 |
| Nationwide | 0.0001 | 1024 | -45.0 | 49 | 4.918 / 5.127 / 0.646 | 5.188 / 5.538 / 1.124 |
| Nationwide | 0.0001 | 256 | 30.0 | 15 | 0.446 / 0.464 / 0.039 | 0.452 / 0.531 / 0.153 |
| Nationwide | 0.0001 | 1024 | 30.0 | 48 | 4.545 / 4.563 / 0.360 | 4.789 / 5.309 / 1.561 |
| Nationwide | 0.004 | 256 | -45.0 | 15 | 13.279 / 13.408 / 0.714 | 18.730 / 17.373 / 3.046 |
| Nationwide | 0.004 | 1024 | -45.0 | 49 | 47.605 / 47.762 / 0.843 | 55.268 / 56.502 / 9.513 |
| Nationwide | 0.004 | 256 | 30.0 | 15 | 13.552 / 13.504 / 0.104 | 16.391 / 16.915 / 2.970 |
| Nationwide | 0.004 | 1024 | 30.0 | 48 | 45.774 / 45.360 / 1.246 | 76.723 / 77.849 / 6.353 |

## Validation and review

The focused corrected unit gate passed 12 logical tests / 75 parameter-expanded executions, zero failed/skipped/expected failures. It covers three intensity recipes, four angles and five zoom scales (below, at and above the visibility threshold), adjacent tile edges, a polygon boundary, interior holes, an offset coordinate origin, disjoint draw regions, and retention of every relevant original stripe. Bitmap comparisons against a full-region draw permit at most one 8-bit channel value of antialias quantization per pixel; holes require exact transparency. A separate interior region asserts hatching appears exactly at the existing threshold. Existing overlay styling, hole winding and coordinator identity tests also pass.

Baseline finalized bundle: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.bAxXQW/unit.xcresult` (10 logical/expanded tests passed). Baseline attachment: `21208689-7F2A-4A83-8BE8-2AB6E6B5FB85.txt`, exported to `/tmp/issue-712-baseline-attachments/`. The production source is the baseline SHA above; the test contained the measurement method before the optimized counter and regression additions.

Corrected focused bundle: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.hdhscg/unit.xcresult`. Isolated optimized measurement bundle: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.6orgfl/unit.xcresult` (1 test passed), attachment `D8D31DC5-F5FF-476D-8446-D3C9039C81E6.txt`, exported to `/tmp/issue-712-isolated-attachments/`. Both native bundles were finalized and verified with `ci_scripts/verify_xcresult.sh`. RTK's heuristic summary mislabels zero-failure fields as failures; native results are authoritative.

Independent isolated read-only review found no actionable introduced defects. The configured `skyaware_reviewer` role was unavailable, so a standard isolated reviewer performed the same assignment. The reviewer checked the geometry, retained endpoints/dashes, styling and clipping; it did not rerun tests.

Final three-suite gate: `rtk summary tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/RiskPolygonOverlayTests -only-testing:SkyAwareTests/MapPolygonMapperTests -only-testing:SkyAwareTests/MapFeatureModelSceneTests`. Finalized bundle `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.LdRf5l/unit.xcresult` passed 60 logical tests / 123 parameter-expanded executions, zero failed/skipped/expected failures, verified with `ci_scripts/verify_xcresult.sh`. This gate includes the real renderer measurement again, mapping/style/interior-ring contracts, and existing scene selection/reuse behavior. The full repository unit suite was not selected.

Source/test SHA-256 fingerprints: `RiskPolygonRenderer.swift` = `4e6fb6f499df911831f6a70237cad9a1bc3ceea11142e5f29a3c5ab7aa5eba3e`; `RiskPolygonOverlayTests.swift` = `156f5cd87a19aebf720041ba7ec64d9b57046913c6fb8532c04c2be796648441`. Documentation was completed after these tests. No UI tests, screenshots, physical-device runs, Instruments, live weather requests, or measured coverage delta are part of this evidence.
