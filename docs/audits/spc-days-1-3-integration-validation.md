# SPC Days 1–3 integration validation — #706

Date: 2026-10-19. Base: `c591839` (`main`, including #733's repair for #732). Scope: the accepted Days 1–3 Map/Outlooks implementation from epic #698. Prerequisite issues #699–#705 and #732 were closed when validation began.

## Outcome and boundary

This change adds deterministic integration coverage at existing seams. No production correction or performance tuning was justified by the focused run. Unit evidence does not complete the epic's manual iPhone or rendered-performance criteria. Justin owns physical-device review and measurements and will supply results later. Keep #706 open until those criteria are verified.

## Evidence map

| Requirement | Deterministic evidence | Limit |
| --- | --- | --- |
| Partial publication, failure, accepted-empty and restart | `SPCFutureCategoricalForecastTests.persistedForecasts_integrateWithMapScenes` exercises actual GeoJSON acceptance, disk reopen, `SpcProvider`, and `MapFeatureModel`; rejected Day 3 remains unavailable, then accepted dated no-area becomes confirmed empty without replacing Day 2 | Synthetic geometry; not a live publication observation |
| Current-day authority | The new integration test seeds populated Day 1 risk and verifies point-query authority before and after future-day browsing; `SPCFutureHazardForecastTests.hazardMappingAndCurrentRiskIsolation` covers future hazard acceptance/rejection/empty | Unit checks do not prove physical notification delivery |
| Real-source Day 2/3 text repair | `SPCCurrentDiscussionTests.acquisition_partialUpdate_failure_restart` uses captured SPC page bodies with shifted clocks through acquisition, accepted storage, reopen and Home; `ConvectiveOutlookRepoTests.multiDayCollection_reopensAfterFailure` uses actual RSS title patterns and now verifies offline latest-discussion routing for every day | No intentional live SPC requests |
| Fast selection and accepted invalidation races | `MapFeatureModelSceneTests.forecastReload_isAtomicAndLatestAcceptedWins`, `forecastReload_coordinatorInvalidationDiscardsSupersededCandidate`, and `forecastReload_cancellationPreservesAcceptedScene` | Deterministic gates; not measured foreground/background device scheduling |
| Validity rollover and stale cache | `SPCFutureCategoricalForecastTests.rollover`, `SPCCurrentDiscussionTests.issuance_rollover_and_bounds`, and the new persisted-scene test | Explicit source clocks; no local-midnight assumption |
| Day 3 compatibility and viewport | `MapFeatureModelSceneTests.layerTransitions_preserveOrResetForecastDay`, `forecastSelection_isCachedAndScoped`, and the new persisted-scene test | Initial center and capability policy are unit-tested; actual camera retention needs device review |
| Explicit Map ↔ Outlooks routing | `MapFeatureModelTests.discussionRoutesMatchSupportedProductsAndKeepTheRequestedDay`, `ConvectiveOutlookDayPresentationTests.latestDiscussionUsesRequestedDay`, and source-title ingestion → reopen → Home → offline routing extension | Rendered navigation is unobserved |
| Cache work and accessibility metadata | `MapFeatureModelSceneTests.forecastCache_isBoundedAcrossDays`, `forecastSelection_isCachedAndScoped`, and `forecastDayMenu_usesCapabilityAndAccessibilityPolicies` | No provider reread on selection and bounded scenes are structural proof, not a latency or VoiceOver usability measurement |

Outlooks remains a text list/detail surface; this diff adds no maps, thumbnails or UI changes. Existing Today, widget, warning and notification suites belong to final unit regression validation, rather than serving as proof of device behavior.

## Validation artifacts

Focused command: `rtk summary tools/ci/run_test_lane.sh unit -only-testing:SkyAwareTests/SPCFutureCategoricalForecastTests -only-testing:SkyAwareTests/ConvectiveOutlookRepoTests -only-testing:SkyAwareTests/MapFeatureModelSceneTests`.

Finalized result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.EfqsTk/unit.xcresult`. Native `xcresulttool` summary: Passed; 53 logical tests, 62 parameter-expanded executions, 0 failed, 0 skipped, 0 expected failures. Environment: Debug, `SkyAware_Tests`, Configuration 1, iPhone 17 Simulator, iOS 26.5. RTK's inferred failure summary disagreed with native results; the finalized native bundle is authoritative.

Independent read-only review found no actionable defects in the scoped tests/report. The configured specialist role was unavailable, so a separate agent performed the review with the same read-only defect-review assignment.

Final command: `rtk summary tools/ci/run_test_lane.sh unit`. Finalized result: `/var/folders/sl/llpj7km14cb97fd1nmkt8gt40000gn/T/skyaware-results.gKg5dQ/unit.xcresult`. Native summary: Passed; 1,405 logical tests total, 1,404 passed, 0 failed, 1 skipped, 0 expected failures; parameter-expanded counts are 1,528 passed and 1 skipped. Same Debug simulator/test-plan configuration as the focused run. The skip is the existing `SummaryAwarenessPanelTests.awarenessFamilyRenderEvidence` guard requiring `UI_TESTS_STATIC_HOME=1`; that environment was not enabled. Both changed tests and `SPCCurrentDiscussionTests.acquisition_partialUpdate_failure_restart` appear as passed in the native test tree. UI tests are excluded at the user's request. Coverage deltas were not measured.

The full bundle contains the existing `MapSceneWarmingMeasurement.txt` attachment from `MapSceneWarmingMeasurementTests.testInactiveSceneWarmingTradeoff`. For its representative fixture with warnings off, 10 measured iterations reported median wall times of 0.2228 ms for selected categorical materialization, 0.3214 ms for first cold layer switch, and 0.0013 ms for first warm switch. These are Debug simulator harness observations with synthetic geometry, not rendered multi-day switching measurements or a before/after regression comparison. No performance correction follows from these numbers.

## Remaining user-owned acceptance evidence

- On iPhone, switch categorical Days 1–3 and individual hazards Days 1–2; verify camera retention and that controls/legend leave the map usable. Verify unavailable versus accepted-empty states remain clear.
- Review Outlooks styling and discussion readability at large Dynamic Type sizes; use VoiceOver for day selection, validity metadata and cross-tab actions. Confirm no embedded maps or historical thumbnails.
- Measure scene creation and day/layer switching against a comparable baseline with the same build configuration, device and data workload. The existing `MapSceneWarmingMeasurementTests` harness measures materialization only and excludes fetch, planning, rendering and task scheduling; it cannot establish the multi-day rendered-performance criterion. Generalized tuning stays with the separate Map review epic.
- Confirm physical-device Today/widget/warning/notification behavior remains current-day scoped while browsing future forecasts. Record device, OS, build and observations when reporting results.

No evidence-backed production blocker was demonstrated by these unit runs. The outstanding items above are validation gaps, not verified passes or inferred defects.
