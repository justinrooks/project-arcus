# Xcode Cloud Test Topology

This repository owns the test plans and result validation scripts. Xcode Cloud owns workflow creation and the
selected Xcode/runtime images.

## Local test-lane selection

Use `tools/ci/run_test_lane.sh` for local simulator validation. It runs the selected shared scheme test plan, writes a fresh `.xcresult` bundle, and invokes `ci_scripts/verify_xcresult.sh`; do not bypass the runner for focused selections.

- `tools/ci/run_test_lane.sh unit` runs `SkyAware_Tests`, the default regression suite required for normal development and CI validation. During implementation, narrow the suite with standard Xcode selectors after the lane name; run the full unit lane for final regression validation. For example: `tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/SevereRiskRepoActiveSelectionTests`.
- `tools/ci/run_test_lane.sh performance` runs the optional `SkyAware_Performance` measurement suite. Choose it for performance investigations or when a change could affect measured behavior; validate regression behavior with the unit lane as well. These measurements depend on the simulator and host environment and do not use stable CI timing thresholds.
- `tools/ci/run_test_lane.sh ui-navigation` runs the separate `SkyAware_UI_Smoke` navigation smoke suite. This lane remains distinct from regression and performance validation.

Report the exact command, finalized result, logical test counts and parameter-expanded count when available, simulator/runtime, configuration, test plan, and `.xcresult` path. For performance runs, report the measured tests, environment, and available result attachments; do not conflate their environment-dependent measurements with deterministic regression evidence.

## Unit workflow

Configure one Xcode Cloud test action with:

- Scheme: `SkyAware`
- Test plan: `SkyAware_Tests`
- Build configuration: Debug
- Xcode: 26.6 (build 17F113)
- Destinations: Xcode Cloud's recommended-phone matrix using the runtime supplied by the selected Xcode:
  - iPhone 16 Pro Max
  - iPhone 16 Pro
  - iPhone 16
  - iPhone SE (3rd generation)
- Parallel test execution: enabled

Preserve this matrix. The verifier reports the aggregate counts and every destination returned by the finalized
result bundle, so one process crash is visible as a matrix-wide problem without relying on the active-test label.

## UI smoke workflow

If Cloud UI smoke coverage is enabled, create a separate test action using `SkyAware_UI_Smoke` and the same Xcode
and recommended-phone matrix. It must not use `SkyAware_All_Tests`, which intentionally contains both unit and UI targets for
interactive local work.

`SkyAware_UI_Smoke` itself selects the navigation smoke test; Cloud needs no additional selector. Keep the unit and
UI results as separate build artifacts.

## Required result checks

`ci_scripts/ci_post_xcodebuild.sh` verifies the completed Xcode Cloud `test-without-building` phase through
`CI_RESULT_BUNDLE_PATH`; it skips the preceding `build-for-testing` phase and non-test actions. The checker rejects
missing, staging, unreadable, unknown-result, and zero-test bundles, then reports exact aggregate counts, every
simulator/runtime/test-plan configuration, the build configuration, and the bundle path.

For a reproducibility check, rebuild the same commit twice through the unit workflow. Both bundles must have the
same nonzero counts, no failures, and no crash-log artifacts. Do not disable parallel execution, serialize the target,
or add retries to make this condition pass.
