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
"$script_directory/verify_xcresult.sh" "$CI_RESULT_BUNDLE_PATH" Debug
