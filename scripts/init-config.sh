#!/bin/sh

# setup default upload branch name
if [[ -z "$APPLE_TESTFLIGHT_UPLOAD_BRANCH" ]]; then
  export APPLE_TESTFLIGHT_UPLOAD_BRANCH="testflight"
fi

if [[ -z "$HOCKEYAPP_UPLOAD_BRANCH" ]]; then
  export HOCKEYAPP_UPLOAD_BRANCH="hockeyapp"
fi
