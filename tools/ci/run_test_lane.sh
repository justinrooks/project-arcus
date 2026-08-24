#!/bin/zsh

set -u

if (( $# < 1 )); then
    print -u2 "Usage: $0 <unit|ui-navigation> [xcodebuild test selection arguments]"
    exit 64
fi

lane="$1"
shift

case "$lane" in
    unit)
        test_plan="SkyAware_Tests"
        result_name="unit"
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
ci_scripts/verify_xcresult.sh "$result_bundle" Debug
verification_status=$?
set -e

if (( xcodebuild_status != 0 )); then
    exit "$xcodebuild_status"
fi

exit "$verification_status"
