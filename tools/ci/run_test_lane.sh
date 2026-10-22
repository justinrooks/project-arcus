#!/bin/zsh

set -u

if (( $# < 1 )); then
    print -u2 "Usage: $0 <unit|performance|ui-navigation> [xcodebuild test selection arguments]"
    exit 64
fi

lane="$1"
shift

measurement_tests=(
    'MapSceneWarmingMeasurementTests/testInactiveSceneWarmingTradeoff()'
    'MapSceneWarmingMeasurementTests/testRetainedScenePolygonConstruction()'
    'MapAcceptedUpdateMeasurementTests/testAcceptedReloadScenariosRecordSourceReadsAndSelectedSceneChurn()'
    'MapAcceptedUpdateMeasurementTests/testSelectedSceneCriticalPathAfterSourceScoping()'
    'RiskPolygonOverlayTests/hatchDrawingMeasurement()'
    'HomeProjectionStoreScalingMeasurementTests/seededRetainedProjections_reportBaselineAndPresentationScaling()'
)

case "$lane" in
    unit)
        test_plan="SkyAware_Tests"
        result_name="unit"
        ;;
    performance)
        test_plan="SkyAware_Performance"
        result_name="performance"
        ;;
    ui-navigation)
        test_plan="SkyAware_UI_Smoke"
        result_name="ui-navigation"
        ;;
    *)
        print -u2 "Unknown test lane: $lane"
        exit 64
        ;;
esac

expected_tests=()
excluded_tests=()
if [[ "$lane" == performance ]]; then
    expected_tests=("${measurement_tests[@]}")
elif [[ "$lane" == unit ]]; then
    excluded_tests=("${measurement_tests[@]}")
fi

selector_matches_test() {
    local test_identifier="$1"
    local selector="$2"
    local selector_path

    if [[ "$selector" == "SkyAwarePerformanceTests" ]]; then
        return 0
    elif [[ "$selector" == SkyAwarePerformanceTests/* ]]; then
        selector_path="${selector#SkyAwarePerformanceTests/}"
    else
        return 1
    fi

    [[ -n "$selector_path" ]] || return 1

    local normalized_test="${test_identifier%\(\)}"
    local normalized_selector="${selector_path%\(\)}"
    [[ "$normalized_test" == "$normalized_selector" || "$normalized_test" == "$normalized_selector/"* ]]
}

select_expected_performance_tests() {
    local -a only_selectors skip_selectors selected_tests
    local -a test_arguments
    local index argument selector test_identifier matched include_test

    only_selectors=()
    skip_selectors=()
    selected_tests=()
    test_arguments=("$@")

    for (( index = 1; index <= ${#test_arguments[@]}; index++ )); do
        argument="${test_arguments[$index]}"
        case "$argument" in
            -only-testing:*)
                only_selectors+=("${argument#-only-testing:}")
                ;;
            -skip-testing:*)
                skip_selectors+=("${argument#-skip-testing:}")
                ;;
            -only-testing)
                if (( index == ${#test_arguments[@]} )); then
                    print -u2 "Missing selector after -only-testing"
                    return 64
                fi
                (( index += 1 ))
                only_selectors+=("${test_arguments[$index]}")
                ;;
            -skip-testing)
                if (( index == ${#test_arguments[@]} )); then
                    print -u2 "Missing selector after -skip-testing"
                    return 64
                fi
                (( index += 1 ))
                skip_selectors+=("${test_arguments[$index]}")
                ;;
        esac
    done

    for selector in "${only_selectors[@]}" "${skip_selectors[@]}"; do
        matched=0
        for test_identifier in "${measurement_tests[@]}"; do
            if selector_matches_test "$test_identifier" "$selector"; then
                matched=1
                break
            fi
        done
        if (( matched == 0 )); then
            print -u2 "Performance selector does not match a planned measurement: $selector"
            print -u2 "Use a selector qualified with SkyAwarePerformanceTests."
            return 64
        fi
    done

    for test_identifier in "${measurement_tests[@]}"; do
        include_test=1
        if (( ${#only_selectors[@]} > 0 )); then
            include_test=0
            for selector in "${only_selectors[@]}"; do
                if selector_matches_test "$test_identifier" "$selector"; then
                    include_test=1
                    break
                fi
            done
        fi
        if (( include_test == 1 )); then
            for selector in "${skip_selectors[@]}"; do
                if selector_matches_test "$test_identifier" "$selector"; then
                    include_test=0
                    break
                fi
            done
        fi
        if (( include_test == 1 )); then
            selected_tests+=("$test_identifier")
        fi
    done

    if (( ${#selected_tests[@]} == 0 )); then
        print -u2 "Performance selectors exclude all planned measurements"
        return 64
    fi

    expected_tests=("${selected_tests[@]}")
}

if [[ "$lane" == performance ]]; then
    select_expected_performance_tests "$@"
    selector_status=$?
    (( selector_status == 0 )) || exit "$selector_status"
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
command+=("$@" test)

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
