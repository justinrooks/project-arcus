#!/bin/zsh
#  ci_post_xcodebuild.sh

#if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]]; then
  if [[ -d "$CI_APP_STORE_SIGNED_APP_PATH" ]]; then
    TESTFLIGHT_DIR_PATH="$CI_PROJECT_FILE_PATH/../TestFlight"
    mkdir $TESTFLIGHT_DIR_PATH
    git fetch --deepen 3 && git log -3 --pretty=format:"%s" >! $TESTFLIGHT_DIR_PATH/WhatToTest.en-US.txt
  fi
#fi