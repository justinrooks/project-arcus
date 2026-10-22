#!/bin/zsh

set -u

if [[ "${CI_XCODEBUILD_ACTION:-}" != "test-without-building" ]]; then
    exit 0
fi

if [[ -z "${CI_RESULT_BUNDLE_PATH:-}" ]]; then
    print -u2 "XCResult verification failed: test action did not produce a result bundle"
    exit 1
fi

script_directory="${0:A:h}"
case "${CI_TEST_PLAN:-}" in
    SkyAware_Tests)
        "$script_directory/verify_xcresult.sh" "$CI_RESULT_BUNDLE_PATH" Debug --regression
        ;;
    SkyAware_UI_Smoke)
        "$script_directory/verify_xcresult.sh" "$CI_RESULT_BUNDLE_PATH" Debug \
            --test-plan SkyAware_UI_Smoke --target SkyAwareUITests
        ;;
    *)
        print -u2 "XCResult verification failed: unsupported or missing Xcode Cloud test plan '${CI_TEST_PLAN:-}'"
        exit 1
        ;;
esac
