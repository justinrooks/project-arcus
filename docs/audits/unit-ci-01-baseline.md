# Unit CI 01: Build 238 baseline

Investigation date: 2026-10-22. Issue: [#764](https://github.com/justinrooks/project-arcus/issues/764), parent [#763](https://github.com/justinrooks/project-arcus/issues/763). Local source revision: `6a319c880bd223248bc7ec1dd0f79b4e5a4b9dc0` on `issue-764`; production, tests, and scheme are unchanged. The user changed the plan's diagnostic collection to Never at 12:35:35 MDT, after both focused comparisons and before the first full-plan comparison; that run must not be treated as an unchanged-default baseline.

## Evidence and configuration

The user supplied `SkyAware Build 238 XCResult for SkyAware_Tests test-without-building on iPhone 16 Pro Max (default runtime).xcresult.zip`, SHA-256 `63d424c5bc4e51ea9983c05172498658bfa53ec3e695571cf43bffc943ede986`. The Cloud source commit is not established by this export; local and Cloud source identity must not be assumed from the build number or matching test name.

Native bundles, extracted summaries, action logs, and exported diagnostics are retained outside Git at `/Users/justin/Code/skyaware-validation/issue-764`. The original Cloud archive is retained there too. These local artifacts are evidence references, not files supplied by this repository.

| Setting | Build 238 Cloud evidence | Local comparison |
| --- | --- | --- |
| Xcode | 27.1, build 27A9275 (`xcode_version.log` and test session header) | 27.1, build 27A9275 |
| SDK | iPhoneSimulator 27.1, build 24A94232 | Same installed SDK |
| Host | macOS 27.0.1 (26A434), Apple M2 Ultra virtual host | macOS 27.2 (26B118), Apple M3 |
| Destination | One iPhone 16 Pro Max, arm64, iOS 27.0 (24A434) | Focused: canonical iPhone 17 / 26.5 (23F77), then iPhone 16 Pro Max / 27.0 (24A434) |
| Scheme / plan / configuration | `SkyAware` / `SkyAware_Tests` / `Configuration 1`; product paths contain `Debug-iphonesimulator` | Same, explicit `-configuration Debug` |
| Parallel execution | Enabled; `-maximum-parallel-testing-workers 8`; in-process parallelization YES | Plan parallelization enabled; eight-worker limit for full comparison |
| Ordering / repetition | Alphabetical; repetition None, maximumIterations 1 | Checked-in defaults; no retries or serialization added |
| Appearance / text scaling | No explicit override in the checked-in plan or this test; actual Cloud effective values not captured | No override added; actual effective values not instrumented |
| Diagnostics | Export contains simulator logs and runner logs; session says `forceToNotWaitForAsynchronousDiagnostics is NO` | Focused runs used original plan; first full run followed user's Never edit; subsequent A/B uses explicit CLI overrides |

Cloud's scheduler bootstrapped three clones of the single destination, dispatched all three groups to Clone 1, and canceled the two unused bootstrapping workers. Those clones are parallel workers, not additional destination selections. The single exported destination is confirmed; the current live Cloud workflow UI, separate Analyze action, and future selected runtime remain outside this artifact's evidence.

`tools/ci/README.md` still prescribes Xcode 26.6 and four phones. It does not describe this observed run. Reconciliation of that policy belongs to #768; this report records the actual historical configuration without replacing it with the older recommendation. Keep the required regression action on one explicitly selected supported destination, Debug, with parallel execution enabled; pin the recorded runtime when comparing timings rather than relying on “default runtime.”

## Counts and result

Build 238's finalized summary reports **Failed**: 1,480 logical cases, 1,478 passed, 1 failed, 1 skipped, and 0 expected failures. Destination counts and legacy action metrics report **1,699 expanded executions**: 1,697 passed, 1 failed, 1 skipped. The summary records 52 parameterized tests with 271 runs; `1480 - 52 + 271 = 1699`. Do not combine logical totals with expanded passed counts.

The intentional skip is `SummaryAwarenessPanelTests/awarenessFamilyRenderEvidence()`: “Whole Today rendering uses static Home to skip live WeatherKit attribution.” Its existing `UI_TESTS_STATIC_HOME == 1` condition was not changed. The runner console separately reports 1,476 Swift Testing tests in 135 suites, 20.768 seconds; that framework-level number excludes the XCTest portion and is not the entire plan count.

## Failed invariant and reproduction

`Tests/UnitTests/SummaryAwarenessPanelTests.swift:255` renders seven supporting rows using `ImageRenderer`, widths `[175, 175, 175, 175, 360, 360, 360]`, with base renderer scale 1. It checks that long quiet labels can expand, all other compact rows are exactly 90 points high, and adding chevron space does not shrink content or change wide-row height. The layout has a 78-point minimum content height plus 12 points of vertical padding; text retains its intrinsic height. Ninety points is a minimum in production, while this test additionally assumes particular fixtures fit within it.

Cloud violated the final aggregate height assertion at line 310 with `[121, 95, 102, 95, 93, 90, 95]`. No chevron or quiet-label expansion failure is reported. This establishes an exact-height assertion failure, not clipping, lost content, or an accessibility regression. Whether the extra height reflects legitimate text metrics, ambient rendering state, source differences, or interference is unresolved. Neither device/runtime mismatch nor a race is proven. Do not cap production height or weaken the assertion on this evidence.

The exact selector passed locally on both the canonical destination and the Cloud model/runtime using the same installed Xcode build. Each finalized bundle contains exactly one passed test, zero failures/skips/expected failures. Canonical bundle elapsed time: 56.846 seconds. Matching model/runtime bundle elapsed time: 106.611 seconds; test execution reported 1.292 seconds. These are fresh `test` invocations, including build/startup work, not Cloud compute measurements.

```sh
rtk summary tools/ci/run_test_lane.sh unit '-only-testing:SkyAwareTests/SummaryAwarenessPanelTests/supportingRiskRailsShareCompactGeometry()'

# Use an available iPhone 16 Pro Max on iOS 27.0; each result path must be new.
xcodebuild -quiet -project SkyAware.xcodeproj -scheme SkyAware -configuration Debug -testPlan SkyAware_Tests -destination 'platform=iOS Simulator,name=Issue 764 iPhone 16 Pro Max iOS 27.0,OS=27.0' -maximum-parallel-testing-workers 8 -resultBundlePath /private/tmp/764-focused.xcresult '-only-testing:SkyAwareTests/SummaryAwarenessPanelTests/supportingRiskRailsShareCompactGeometry()' test
ci_scripts/verify_xcresult.sh /private/tmp/764-focused.xcresult Debug
```

The comparison simulator was created with `xcrun simctl create 'Issue 764 iPhone 16 Pro Max iOS 27.0' com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-0`; its local ID is `4779E42A-0195-41B7-9D63-FDC9A081AC58`. The actual local matching invocations selected this ID. Full-plan comparison uses the same command without `-only-testing` and a fresh result path. No UI test plan is selected.

The initial local full-plan run finalized Failed after 343.983 seconds: 1,480 logical cases (1,470 passed, 9 failed, 1 skipped, 0 expected failures), and 1,696 expanded executions (1,685 passed, 10 failed, 1 skipped). Its parameterization summary has 268 runs for 52 tests, three fewer expanded executions than Cloud. It failed in the geometry test at a later `#require(renderer.uiImage?.pngData())`, not the Cloud height assertion. Other reported failures include queue-drain/cadence assertions and five crash-attributed cases with `specialized static Runner._applyScopingTraits(for:testCase:_:)`. Crash attribution identifies affected cases, not their root cause. This is diagnostic evidence of local full-suite instability, not passing regression validation or a reproduction of the original height failure. Do not infer that Never improves elapsed time by comparing these unlike failures with Build 238.

## Action timing and diagnostics hypothesis

Cloud timestamps below are UTC, converted from native action/session timestamps. Durations describe elapsed wall time and overlap where indicated; do not sum nested launch and test sections.

| Boundary | UTC / elapsed | Evidence |
| --- | --- | --- |
| `test-without-building` result begins | 16:50:48.594 | Summary `startTime` |
| First runner test execution begins | 16:51:29.300 | Runner session log |
| Swift Testing portion | 20.768 s | Runner console summary |
| Scheduler finishes tests and requests shutdown | 16:51:57 | `scheduling.log`; runner shutdown request 16:51:57.103 |
| Runner says it can finish, asynchronous diagnostics wait allowed | 16:51:57.412 | Runner session log |
| Final runner log entry | 16:51:57.481 | Runner session log |
| Result ends | 17:01:58.321 | Summary `finishTime` |
| Entire exported result interval | 669.727 s (11m 9.727s) | Summary end minus start |
| Scheduler completion to result end | Approximately 601 s | Boundary difference, not attributed exclusively to diagnostics |

The action log's top section reports 670.247 seconds, slightly wider than the summary interval. Coverage profile merging takes 0.088 seconds and coverage generation appears at result finalization; it does not account for a ten-minute merge. The supplied bundle's build result is `notRequested`: preceding Cloud `build-for-testing` duration is unavailable. It contains no billed compute amount, whole-workflow duration, or definitive shutdown/diagnostic start/end interval. The asynchronous diagnostics message and exported archives support investigation of diagnostic collection; they do not prove its duration or a 600-second timeout.

## Controlled comparison and external limits

An explicit local comparison uses the same built products, source, host, model/runtime, full unit selection, Debug configuration, and eight-worker limit. It changes only the CLI diagnostic option: A uses `-collect-test-diagnostics on-failure`, B uses `-collect-test-diagnostics never`; both use `test-without-building` and unique result paths. The user authorized considering the Never edit after this comparison. No fixed saving or configuration recommendation follows from elapsed time alone when failures differ.

A finalized Failed after 908.645 seconds: 1,480 logical cases (1,473 passed, 6 failed, 1 skipped, 0 expected failures), and 1,699 expanded executions (1,691 passed, 7 failed, 1 skipped). The geometry case passed. The Swift Testing console reports 577.466 seconds. The scheduler finished at 18:53:59 UTC, about 250.3 seconds before result finalization at 18:58:09.297 UTC. A live process sample at `diagnostics-A-process-sample.txt` records `simctl diagnose -l -b --timeout=600`, running for 3m54s, targeting the three worker clones. This directly observes diagnostic collection during the local finalization interval; the timeout argument is an upper limit, not proof of a 600-second timeout. The console reports multiple issues per failing test; use native logical/expanded counts rather than issue count as the failure total.

B finalized Failed after 458.899 seconds: 1,480 logical cases (1,469 passed, 10 failed, 1 skipped, 0 expected failures), and 1,698 expanded executions (1,686 passed, 11 failed, 1 skipped). Its summary has 270 parameterized runs; the geometry case passed. Six logical cases carry runner-crash attribution. The runner log received the crash report at 19:03:24.365 UTC, restarted the worker, and the scheduler finished at 19:06:06 UTC; the result ended at 19:06:14.080 UTC, about eight seconds later. A live sample found no `simctl diagnose` process. B's exported diagnostics still contain scheduling, console, and runner session logs, including failure/crash attribution, but not A's simulator diagnostic archive. These retained ordinary failure records do not replace system diagnostics for a future crash investigation.

| Run | Logical passed / failed / skipped | Expanded passed / failed / skipped | Result interval | Scheduler completion to result end |
| --- | --- | --- | --- | --- |
| Cloud Build 238 | 1478 / 1 / 1 | 1697 / 1 / 1 | 669.727 s | ~601 s |
| Initial local full plan, Never edit | 1470 / 9 / 1 | 1685 / 10 / 1 | 343.983 s | Includes crash recovery; no Cloud-equivalent failure |
| Local A, explicit on-failure | 1473 / 6 / 1 | 1691 / 7 / 1 | 908.645 s | ~250 s; diagnostic process directly observed |
| Local B, explicit never | 1469 / 10 / 1 | 1686 / 11 / 1 | 458.899 s | ~8 s after worker restart and completion |

The controlled input change produced an observation of the diagnostic path, but the failure sets, completed parameterized executions, and crash recovery differed. The 449.746-second A–B total difference is not an isolated diagnostic saving, a repeatability claim, or a Cloud compute saving. The original height failure did not recur in A or B. A safe harness/config mismatch has not been established. This PR also commits `diagnosticCollectionPolicy: Never` in `Tests/SkyAware_Tests.xctestplan` as the routine unit-test default. This is a deliberate operational tradeoff to avoid potentially costly automatic simulator system diagnostics on ordinary failures while retaining normal XCResult failures, assertions, and runner logs. The local observation supports trying this default, but the differing failures and crash recovery do **not** prove a fixed Cloud time saving, a causal explanation for Build 238's entire delay, or resolution of its rendering failure. Cloud acceptance of this plan setting and actual billed compute impact require a subsequent measured run. No regression pass is claimed from these full-plan runs. No additional broad reruns or production/test changes are justified by this issue.

The original height assertion has not reproduced. This session has neither a connected Xcode Cloud/App Store Connect control API nor the Cloud test-products archive/action logs needed to repeat Build 238. The supplied XCResult permits the historical baseline above; local observations cannot establish Cloud compute savings. These are the external/tooling limits for a Cloud comparison, not a reason to stop #765's read-only inventory.

For the Cloud workflow owner, treat the committed test-plan setting `diagnosticCollectionPolicy: Never` as the proposed routine default and verify its effective behavior from subsequent Cloud logs/results. Record source revision, Xcode/runtime, selected device, scheme, plan, Debug, worker limit, selection, last-test time, action finalization, and reported compute. A historical pre-change run versus a post-merge run is useful directional evidence, **not** a controlled A/B comparison unless failure conditions and other inputs match. For a true controlled comparison, keep the source and built test products identical and vary only diagnostics collection through an explicit supported override when available. The installed local CLI exposes `-collect-test-diagnostics on-failure|never` for equivalent `test-without-building` invocations; do not assume an equivalent Cloud invocation override exists without verifying it.

Retain ordinary XCResult assertions, source locations, console/runner logs, crash evidence when available, and per-phase action logs in both runs. Disabling verbose collection loses system diagnostic archives such as sysdiagnose. Retain `Never` as the routine plan default; explicitly enable `on-failure` for a focused local diagnostic investigation when needed, then return to the normal plan behavior. Compare the same failure in both runs, last-test timestamp, runner shutdown, diagnostic intervals, finalization, build-for-testing duration, and Cloud-reported compute if exposed. If failure or selection differs, the comparison does not isolate diagnostics. Do not add retries, skip the failing test, or disable parallel execution to manufacture a comparable run.

The renderer/test owner remains `SummaryAwarenessPanelTests` / Today supporting-row layout under #764 until a controlled reproducer establishes an independent defect. No separate production defect is confirmed by this baseline. Route a proven renderer defect to a separate issue rather than changing layout here. The Cloud workflow owner retains the diagnostic experiment and unavailable source/compute metadata; #768 owns final workflow-documentation reconciliation.
