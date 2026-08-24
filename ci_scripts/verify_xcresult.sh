#!/bin/zsh

set -u

if (( $# != 2 )); then
    print -u2 "Usage: $0 <result-bundle-path> <build-configuration>"
    exit 64
fi

result_bundle="$1"
build_configuration="$2"

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
