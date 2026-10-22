#!/bin/zsh

set -u

if (( $# < 2 )); then
    print -u2 "Usage: $0 <result-bundle-path> <build-configuration> [--regression|--regression-focused] [--test-plan <name>] [--target <name>] [--exclude <test-identifier ...> | expected-test-identifier ...]"
    exit 64
fi

result_bundle="$1"
build_configuration="$2"
shift 2
expected_test_identifiers=()
excluded_test_identifiers=()
expected_target=""
expected_plan=""
regression_contract=0
while (( $# > 0 )); do
    case "$1" in
        --regression)
            regression_contract=1
            shift
            ;;
        --regression-focused)
            regression_contract=2
            shift
            ;;
        --test-plan)
            (( $# >= 2 )) || exit 64
            expected_plan="$2"
            shift 2
            ;;
        --target)
            (( $# >= 2 )) || exit 64
            expected_target="$2"
            shift 2
            ;;
        --exclude)
            shift
            excluded_test_identifiers=("$@")
            break
            ;;
        *)
            expected_test_identifiers+=("$1")
            shift
            ;;
    esac
done

if (( regression_contract )); then
    expected_target="SkyAwareTests"
    expected_plan="SkyAware_Tests"
    allowed_skipped_test_identifiers=(
        'SummaryAwarenessPanelTests/awarenessFamilyRenderEvidence()'
    )
    if (( regression_contract == 1 )); then
        minimum_logical_tests=1470
        required_test_identifiers=(
            'WeatherAwarenessResultTests/acceptedCommitPublication()'
            'GetWeatherAwarenessIntentTests/currentMixedAndMesoOnlyCounts()'
            'StormSetupPresentationTests/summaryStateContract_selectsEveryTerminalState()'
            'MapLegendAccessibilityTests/hatchingLegend_remainsSemantic()'
            'WidgetRouteURLTests/buildsSummaryURL()'
        )
    else
        minimum_logical_tests=0
        required_test_identifiers=()
    fi
else
    minimum_logical_tests=0
    required_test_identifiers=()
    allowed_skipped_test_identifiers=()
fi

fail() {
    print -u2 "XCResult verification failed: $1"
    exit 1
}

[[ -d "$result_bundle" ]] || fail "bundle is missing at $result_bundle"
[[ -f "$result_bundle/Info.plist" ]] || fail "bundle is unfinalized or corrupt at $result_bundle"
[[ ! -d "$result_bundle/Staging" ]] || fail "bundle is still staging at $result_bundle"

summary_path="$(mktemp "${TMPDIR:-/tmp}/skyaware-xcresult-summary.XXXXXX")" || fail "could not create a summary file"
trap 'rm -f "$summary_path"' EXIT

xcrun xcresulttool get test-results summary --path "$result_bundle" --compact > "$summary_path" || \
    fail "xcresulttool could not read $result_bundle"

extract() {
    plutil -extract "$1" raw -o - "$summary_path"
}

result="$(extract result)" || fail "summary has no result"
total="$(extract totalTestCount)" || fail "summary has no total test count"
passed="$(extract passedTests)" || fail "summary has no passed-test count"
failed="$(extract failedTests)" || fail "summary has no failed-test count"
skipped="$(extract skippedTests)" || fail "summary has no skipped-test count"
expected_failures="$(extract expectedFailures)" || fail "summary has no expected-failure count"
destinations="$(plutil -extract devicesAndConfigurations json -o - "$summary_path")" || \
    fail "summary has no destination configuration"

for count in "$total" "$passed" "$failed" "$skipped" "$expected_failures"; do
    [[ "$count" == <-> ]] || fail "summary contains a non-numeric test count"
done

print "XCResult: bundle=$result_bundle result=$result total=$total passed=$passed failed=$failed skipped=$skipped expectedFailures=$expected_failures"
print "Environment: configuration=$build_configuration"
print "Destinations:"
print -r -- "$destinations" | plutil -p - || fail "could not format destination configuration"

(( total > 0 )) || fail "summary contains zero tests"
[[ "$result" != "unknown" ]] || fail "summary result is unknown"
[[ "$result" == "Passed" ]] || fail "summary result is $result"

if (( ${#expected_test_identifiers[@]} > 0 || ${#excluded_test_identifiers[@]} > 0 || ${#expected_target} > 0 || ${#expected_plan} > 0 )); then
    if (( ${#expected_test_identifiers[@]} > 0 )); then
        (( total == ${#expected_test_identifiers[@]} )) || \
            fail "expected ${#expected_test_identifiers[@]} tests, found $total"
        (( skipped == 0 )) || fail "expected zero skipped tests, found $skipped"
    fi

    tests_path="$(mktemp "${TMPDIR:-/tmp}/skyaware-xcresult-tests.XXXXXX")" || \
        fail "could not create a test list file"
    trap 'rm -f "$summary_path" "$tests_path"' EXIT
    xcrun xcresulttool get test-results tests --path "$result_bundle" --compact > "$tests_path" || \
        fail "xcresulttool could not read test details from $result_bundle"

    python3 - "$tests_path" "$expected_target" "$expected_plan" "$regression_contract" "$minimum_logical_tests" \
        "${#required_test_identifiers[@]}" "${required_test_identifiers[@]}" \
        "${#expected_test_identifiers[@]}" "${expected_test_identifiers[@]}" \
        "${#excluded_test_identifiers[@]}" "${excluded_test_identifiers[@]}" \
        "${#allowed_skipped_test_identifiers[@]}" "${allowed_skipped_test_identifiers[@]}" <<'PY'
import json
import sys

path = sys.argv[1]
expected_target = sys.argv[2]
expected_plan = sys.argv[3]
regression_contract = int(sys.argv[4])
minimum_logical_tests = int(sys.argv[5])
cursor = 6
required_count = int(sys.argv[cursor])
cursor += 1
required = sys.argv[cursor:cursor + required_count]
cursor += required_count
expected_count = int(sys.argv[cursor])
cursor += 1
expected = sys.argv[cursor:cursor + expected_count]
cursor += expected_count
excluded_count = int(sys.argv[cursor])
cursor += 1
excluded = sys.argv[cursor:cursor + excluded_count]
cursor += excluded_count
allowed_skip_count = int(sys.argv[cursor])
cursor += 1
allowed_skips = sys.argv[cursor:cursor + allowed_skip_count]
with open(path, encoding="utf-8") as result_file:
    data = json.load(result_file)

actual = []
targets = []
plans = []
def visit(node):
    if str(node.get("nodeType", "")).startswith("Test Plan"):
        name = node.get("name", "")
        plans.append(name.removeprefix("Test Plan '").removesuffix("'"))
    if "test bundle" in str(node.get("nodeType", "")).lower():
        targets.append(node.get("name", ""))
    if node.get("nodeType") == "Test Case":
        actual.append((node.get("nodeIdentifier", ""), node.get("result", "")))
    for child in node.get("children", []):
        visit(child)

for node in data.get("testNodes", []):
    visit(node)

actual_ids = [identifier for identifier, _ in actual]
missing = sorted(set(expected) - set(actual_ids))
unexpected = sorted(set(actual_ids) - set(expected))
not_passed = sorted(identifier for identifier, result in actual if result != "Passed")
present_excluded = sorted(set(excluded) & set(actual_ids))
target_mismatch = expected_target and targets != [expected_target]
required_missing = sorted(set(required) - set(actual_ids))
skipped_ids = sorted(identifier for identifier, result in actual if result == "Skipped")
unexpected_skips = sorted(set(skipped_ids) - set(allowed_skips))
plan_mismatch = expected_plan and plans != [expected_plan]
logical_count_too_low = regression_contract == 1 and len(actual_ids) < minimum_logical_tests
regression_failures = regression_contract > 0 and any(
    result not in ("Passed", "Skipped") for _, result in actual
)
if (missing or (expected and (unexpected or len(actual_ids) != len(expected))) or
        present_excluded or (expected and not_passed) or target_mismatch or required_missing or
        unexpected_skips or plan_mismatch or logical_count_too_low or regression_failures):
    if expected:
        print(f"Expected tests: {sorted(expected)}", file=sys.stderr)
    print(f"Actual tests: {sorted(actual_ids)}", file=sys.stderr)
    if missing:
        print(f"Missing tests: {missing}", file=sys.stderr)
    if unexpected:
        print(f"Unexpected tests: {unexpected}", file=sys.stderr)
    if not_passed:
        print(f"Tests not passed: {not_passed}", file=sys.stderr)
    if present_excluded:
        print(f"Excluded tests unexpectedly ran: {present_excluded}", file=sys.stderr)
    if target_mismatch:
        print(f"Expected target: {expected_target}; actual targets: {targets}", file=sys.stderr)
    if required_missing:
        print(f"Required regression sentinels missing: {required_missing}", file=sys.stderr)
    if unexpected_skips:
        print(f"Unexpected skipped tests: {unexpected_skips}", file=sys.stderr)
    if plan_mismatch:
        print(f"Expected test plan: {expected_plan}; actual plans: {plans}", file=sys.stderr)
    if logical_count_too_low:
        print(f"Expected at least {minimum_logical_tests} logical tests; found {len(actual_ids)}", file=sys.stderr)
    if regression_failures:
        failed_regression_cases = sorted(
            identifier for identifier, result in actual if result not in ("Passed", "Skipped")
        )
        print(f"Regression cases not passed: {failed_regression_cases}", file=sys.stderr)
    sys.exit(1)
PY
    [[ $? == 0 ]] || fail "test identities did not match the expected set"
    if (( ${#expected_test_identifiers[@]} > 0 )); then
        print "XCResult test membership: exact expected set (${#expected_test_identifiers[@]} tests), all passed"
    elif (( regression_contract == 1 )); then
        print "XCResult regression contract: plan=SkyAware_Tests target=SkyAwareTests logicalTests>=${minimum_logical_tests}, sentinels=${#required_test_identifiers[@]}, allowedSkips=${#allowed_skipped_test_identifiers[@]}"
    elif (( regression_contract == 2 )); then
        print "XCResult focused regression: plan=SkyAware_Tests target=SkyAwareTests, allowedSkips=${#allowed_skipped_test_identifiers[@]}"
    elif [[ -n "$expected_plan" ]]; then
        print "XCResult test plan: $expected_plan"
    else
        print "XCResult test membership: ${#excluded_test_identifiers[@]} excluded tests absent, all executed tests passed"
    fi
fi
