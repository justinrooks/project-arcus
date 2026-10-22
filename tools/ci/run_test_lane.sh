#!/bin/zsh

set -u

if (( $# < 1 )); then
    print -u2 "Usage: $0 <unit|performance|ui-navigation> [xcodebuild test selection arguments]"
    exit 64
fi

lane="$1"
shift

case "$lane" in
    unit)
        test_plan="SkyAware_Tests"
        result_name="unit"
        default_selection=(
            '-skip-testing:SkyAwareTests/HomeProjectionStoreScalingMeasurementTests/seededRetainedProjections_reportBaselineAndPresentationScaling()'
            '-skip-testing:SkyAwareTests/MapAcceptedUpdateMeasurementTests/testAcceptedReloadScenariosRecordSourceReadsAndSelectedSceneChurn()'
            '-skip-testing:SkyAwareTests/MapAcceptedUpdateMeasurementTests/testSelectedSceneCriticalPathAfterSourceScoping()'
            '-skip-testing:SkyAwareTests/MapSceneWarmingMeasurementTests/testInactiveSceneWarmingTradeoff()'
            '-skip-testing:SkyAwareTests/MapSceneWarmingMeasurementTests/testRetainedScenePolygonConstruction()'
            '-skip-testing:SkyAwareTests/RiskPolygonOverlayTests/hatchDrawingMeasurement()'
        )
        ;;
    performance)
        test_plan="SkyAware_Performance"
        result_name="performance"
        default_selection=()
        ;;
    ui-navigation)
        test_plan="SkyAware_UI_Smoke"
        result_name="ui-navigation"
        default_selection=()
        ;;
    *)
        print -u2 "Unknown test lane: $lane"
        exit 64
        ;;
esac

expected_tests=()
if [[ "$lane" == performance ]]; then
    expected_tests=(
        'MapSceneWarmingMeasurementTests/testInactiveSceneWarmingTradeoff()'
        'MapSceneWarmingMeasurementTests/testRetainedScenePolygonConstruction()'
        'MapAcceptedUpdateMeasurementTests/testAcceptedReloadScenariosRecordSourceReadsAndSelectedSceneChurn()'
        'MapAcceptedUpdateMeasurementTests/testSelectedSceneCriticalPathAfterSourceScoping()'
        'RiskPolygonOverlayTests/hatchDrawingMeasurement()'
        'HomeProjectionStoreScalingMeasurementTests/seededRetainedProjections_reportBaselineAndPresentationScaling()'
    )
elif [[ "$lane" == unit ]]; then
    excluded_tests=(
        'MapSceneWarmingMeasurementTests/testInactiveSceneWarmingTradeoff()'
        'MapSceneWarmingMeasurementTests/testRetainedScenePolygonConstruction()'
        'MapAcceptedUpdateMeasurementTests/testAcceptedReloadScenariosRecordSourceReadsAndSelectedSceneChurn()'
        'MapAcceptedUpdateMeasurementTests/testSelectedSceneCriticalPathAfterSourceScoping()'
        'RiskPolygonOverlayTests/hatchDrawingMeasurement()'
        'HomeProjectionStoreScalingMeasurementTests/seededRetainedProjections_reportBaselineAndPresentationScaling()'
    )
fi

result_root="$(mktemp -d "${TMPDIR:-/tmp}/skyaware-results.XXXXXX")" || exit 1
result_bundle="$result_root/$result_name.xcresult"

print "Result bundle: $result_bundle"

command=(
    xcodebuild
    -quiet
    -project SkyAware.xcodeproj
    -scheme SkyAware
    -configuration Debug
    -testPlan "$test_plan"
    -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5"
    -resultBundlePath "$result_bundle"
)
command+=("${default_selection[@]}" "$@" test)

set +e
"${command[@]}"
xcodebuild_status=$?
if [[ "$lane" == unit ]]; then
    ci_scripts/verify_xcresult.sh "$result_bundle" Debug --exclude "${excluded_tests[@]}"
elif [[ "$lane" == performance ]]; then
    ci_scripts/verify_xcresult.sh "$result_bundle" Debug --target SkyAwarePerformanceTests "${expected_tests[@]}"
else
    ci_scripts/verify_xcresult.sh "$result_bundle" Debug
fi
verification_status=$?
set -e

if (( xcodebuild_status != 0 )); then
    exit "$xcodebuild_status"
fi

exit "$verification_status"
