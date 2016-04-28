#!/bin/sh

SDK_FLAG=
if [[ "$PROJECT_TYPE" == "ios" ]]; then
  SDK_FLAG=-sdk $BUILD_SDK
fi

SDK_FLAG_FOR_ARCHIVE=
if [[ "$PROJECT_TYPE" == "ios" ]]; then
  SDK_FLAG_FOR_ARCHIVE=-sdk $RELEASE_BUILD_SDK
fi

if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then
    echo "This is a pull request. Just build in DEBUG configuration."
    xctool -workspace $WORKSPACE_NAME.xcworkspace \
    -scheme $SCHEME_NAME $SDK_FLAG \
    -configuration Debug ONLY_ACTIVE_ARCH=NO
    if [[ $? -ne 0 ]]; then
        echo "Error: Build fail."
        exit 1
    fi

else
    echo "Building..."
    xctool -workspace $WORKSPACE_NAME.xcworkspace \
    -scheme $SCHEME_NAME $SDK_FLAG ONLY_ACTIVE_ARCH=NO
    if [[ $? -ne 0 ]]; then
        echo "Error: Build fail."
        exit 1
    fi

    if [[ "$NO_TEST" != "true" ]]; then
      echo "Running test..."
      xcodebuild test -workspace $WORKSPACE_NAME.xcworkspace \
      -scheme $SCHEME_NAME $SDK_FLAG ONLY_ACTIVE_ARCH=NO | egrep '^(/.+:[0-9+:[0-9]+:.(error|warning):|fatal|===)' -
      if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
          echo "Error: Test fail."
          exit 1
      fi
    fi

    echo "Making archive..."
    xctool -workspace $WORKSPACE_NAME.xcworkspace -scheme $SCHEME_NAME \
    $SDK_FLAG_FOR_ARCHIVE -configuration Release ONLY_ACTIVE_ARCH=NO \
    archive -archivePath $PWD/build/$APP_NAME.xcarchive
    if [[ $? -ne 0 ]]; then
        echo "Error: Archive fail."
        exit 1
    fi
fi
