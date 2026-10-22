# Xcode Cloud Test Topology

This repository owns the test plans and result validation scripts. Xcode Cloud owns workflow creation and the
selected Xcode/runtime images.

## Local test-lane selection

Use `tools/ci/run_test_lane.sh` for local simulator validation. It runs the selected shared scheme test plan, writes a fresh `.xcresult` bundle, and invokes `ci_scripts/verify_xcresult.sh`; do not bypass the runner for focused selections.

- `tools/ci/run_test_lane.sh unit` runs `SkyAware_Tests`, the default regression suite required for normal development and CI validation. During implementation, narrow the suite with standard Xcode selectors after the lane name; run the full unit lane for final regression validation. For example: `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/SevereRiskRepoActiveSelectionTests`.
- Compile-time target partitioning keeps the six timing entry points out of `SkyAware_Tests`, and the runner's native XCResult verification asserts that all six remain absent; separate plan and command-line skip lists are unnecessary.
- `tools/ci/run_test_lane.sh performance` runs the optional `SkyAware_Performance` measurement suite. Choose it for performance investigations or when a change could affect measured behavior; validate regression behavior with the unit lane as well. These measurements depend on the simulator and host environment and do not use stable CI timing thresholds.
- Focused performance runs accept target-qualified `-only-testing` or `-skip-testing` selectors, and the runner verifies the exact remaining expected cases. For example: `tools/ci/run_test_lane.sh performance -only-testing:SkyAwarePerformanceTests/MapSceneWarmingMeasurementTests`.
- `tools/ci/run_test_lane.sh ui-navigation` runs the separate `SkyAware_UI_Smoke` navigation smoke suite. This lane remains distinct from regression and performance validation.

Report the exact command, finalized result, logical test counts and parameter-expanded count when available, simulator/runtime, configuration, test plan, and `.xcresult` path. For performance runs, report the measured tests, environment, and available result attachments; do not conflate their environment-dependent measurements with deterministic regression evidence.

## Unit workflow

The repository owns test plans and result validation; Xcode Cloud action selection is maintained externally. Build 238 is the latest configuration evidence retained in [the Unit CI 01 baseline](../../docs/audits/unit-ci-01-baseline.md); it confirms one selected destination for that run, not the current workflow UI settings.

Build 238 used:

- Scheme: `SkyAware`
- Test plan: `SkyAware_Tests`
- Build configuration: Debug
- Xcode: 27.1 (build 27A9275)
- Destination: one iPhone 16 Pro Max simulator on iOS 27.0 (build 24A434)
- Parallel test execution: enabled

The finalized Build 238 result records one destination. The current Cloud UI action settings, selected Xcode/runtime, and separate Analyze action are maintained externally and are not established by that historical result. Keep the required Cloud action on `SkyAware_Tests`; confirm any current UI setting from Xcode Cloud before treating it as current policy.

## UI smoke workflow

If Cloud UI smoke coverage is enabled, create a separate test action using `SkyAware_UI_Smoke`. It must not use `SkyAware_All_Tests`, which intentionally contains both unit and UI targets for interactive local work.

`SkyAware_UI_Smoke` itself selects the navigation smoke test; Cloud needs no additional selector. Keep the unit and
UI results as separate build artifacts.

## Required result checks

`ci_scripts/ci_post_xcodebuild.sh` verifies the completed Xcode Cloud `test-without-building` phase through `CI_RESULT_BUNDLE_PATH`; it skips the preceding `build-for-testing` phase and non-test actions. `CI_TEST_PLAN` routes the required `SkyAware_Tests` action through the regression contract and the documented optional `SkyAware_UI_Smoke` action through plan- and target-specific native result checks. Unsupported or missing plans fail. The regression verifier rejects missing, staging, unreadable, unknown-result, failing, zero-test, wrong-plan, wrong-target, and materially under-selected results. It requires five stable regression sentinels, at least 1,470 logical test cases, and no unapproved skips; it does not pin the exact total, so ordinary test additions do not require a contract update. The 1,470 floor allows nine fewer cases than the expected 1,479 after #766's six measurement extractions and five untimed replacements. The `PERFORMANCE_TESTS` target partition keeps timing-only cases out of the regression target. The only currently approved regression skip is the configuration-gated `SummaryAwarenessPanelTests/awarenessFamilyRenderEvidence()` case.

The full local unit lane and the Cloud `SkyAware_Tests` action enforce the same plan, target, count floor, sentinels, and skip allowance. The separate Cloud `SkyAware_UI_Smoke` action uses its own plan, target, and native-result checks. Focused local unit selections retain native result, plan, target, outcome, and skip checks but intentionally omit the full-suite count and sentinels. `build-for-testing` prepares the selected test plan; `test-without-building` runs it and produces the result bundle the hook validates. The separate Analyze action is retained and is configured in Xcode Cloud, not this repository.

No post-change Xcode Cloud action has run with this coverage contract. Compare its next action duration and phase timestamps against the historical baseline before reporting an effect; Cloud compute usage and monthly impact were not included in the Build 238 evidence, so no compute savings can be claimed from this change.

For a reproducibility check, rebuild the same commit twice through the unit workflow. Both bundles must have the
same nonzero counts, no failures, and no crash-log artifacts. Do not disable parallel execution, serialize the target,
or add retries to make this condition pass.
