#!/bin/sh
if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then
  echo "This is a pull request. No deployment will be done."
  exit 0
fi


OUTPUT_DIR="$PWD/build"
ARCHIVE_DIR="$OUTPUT_DIR/$APP_NAME.xcarchive"
APP_FILE_PATH="$ARCHIVE_DIR/Products/Applications/$APP_NAME.app"

if [[ "$PROJECT_TYPE" == "ios" ]]; then
  DELIVERABLE_PATH="$OUTPUT_DIR/$APP_NAME.ipa"
  #####################
  # Make the ipa file #
  #####################
  PROVISIONING_PROFILE="$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_NAME.mobileprovision"
  APP_EXTENSION_PROFILE="$HOME/Library/MobileDevice/Provisioning Profiles/$APP_EXTENSION_PROFILE_NAME.mobileprovision"

  if [[ -n "$APP_EXTENSION_PROFILE_NAME" ]]; then
    xcrun -log -sdk iphoneos \
    PackageApplication "$APP_FILE_PATH" \
    -o "$DELIVERABLE_PATH" \
    -sign "$DEVELOPER_NAME" \
    -embed "$PROVISIONING_PROFILE" "$APP_EXTENSION_PROFILE"
  else
    xcrun -log -sdk iphoneos \
    PackageApplication "$APP_FILE_PATH" \
    -o "$DELIVERABLE_PATH" \
    -sign "$DEVELOPER_NAME" \
    -embed "$PROVISIONING_PROFILE"
  fi
elif [[ "$PROJECT_TYPE" == "osx" ]]; then
  DELIVERABLE_PATH="$OUTPUT_DIR/$APP_NAME.app.zip"
  CODESIGN_IDENTITY=`openssl x509 -in ./certs/dist.cer -inform der -text | grep Subject: | cut -d',' -f2 | sed "s/ CN=//"`
  cp -R "$APP_FILE_PATH" "$OUTPUT_DIR/"
  codesign --deep -f -s "$CODESIGN_IDENTITY" "$OUTPUT_DIR/$APP_NAME.app"
  pushd .
  cd $OUTPUT_DIR
  zip --symlink -r -9 "$DELIVERABLE_PATH" "$APP_NAME.app"
  popd
fi

#########################
# Achieve the dSYM file #
#########################
pushd .
cd "$ARCHIVE_DIR/dSYMs"
zip -r -9 "$OUTPUT_DIR/$APP_NAME.app.dSYM.zip" "$APP_NAME.app.dSYM"
popd

RELEASE_DATE=`date '+%Y-%m-%d %H:%M:%S'`
RELEASE_NOTES="Build: $TRAVIS_BUILD_NUMBER\nUploaded: $RELEASE_DATE"

##############################
# Upload to Apple TestFlight #
##############################
if [[ "$TRAVIS_BRANCH" == "$APPLE_TESTFLIGHT_UPLOAD_BRANCH" ]]; then
  if [[ -z "$DELIVER_USER" ]]; then
    echo "Error: Missing TestFlight DELIVER_USER."
    exit 1
  fi

  if [[ -z "$DELIVER_PASSWORD" ]]; then
    echo "Error: Missing TestFlight DELIVER_PASSWORD"
    exit 1
  fi

  if [[ -z "$DELIVER_APP_ID" ]]; then
    echo "Error: Missing TestFlight App ID"
    exit 1
  fi

  echo "Installing gem..."
  gem install deliver

  echo "At $APPLE_TESTFLIGHT_UPLOAD_BRANCH branch, upload to testflight."
  deliver testflight "$DELIVERABLE_PATH" -a "$DELIVER_APP_ID"

  if [[ $? -ne 0 ]]; then
    echo "Error: Fail uploading to TestFlight"
    exit 1
  fi

  if [[ -n "$CRITTERCISM_APP_ID" && -n "$CRITTERCISM_KEY" ]]; then
    curl "https://app.crittercism.com/api_beta/dsym/$CRITTERCISM_APP_ID" \
    -F dsym="@$OUTPUT_DIR/$APP_NAME.app.dSYM.zip" \
    -F key="$CRITTERCISM_KEY"

    if [[ $? -ne 0 ]]; then
      echo "Error: Fail uploading to Crittercism"
      exit 1
    fi
  fi
fi

#######################
# Upload to HockeyApp #
#######################
if [[ "$TRAVIS_BRANCH" == "$HOCKEYAPP_UPLOAD_BRANCH" ]]; then
  if [[ -z "$HOCKEY_APP_ID" ]]; then
    echo "Error: Missing HockeyApp ID"
    exit 1
  fi

  if [[ -z "$HOCKEY_APP_TOKEN" ]]; then
    echo "Error: Missing HockeyApp Token"
    exit 1
  fi

  echo "At $HOCKEYAPP_UPLOAD_BRANCH branch, upload to hockeyapp."
  curl https://rink.hockeyapp.net/api/2/apps/$HOCKEY_APP_ID/app_versions \
    -F status="2" \
    -F notify="0" \
    -F notes="$RELEASE_NOTES" \
    -F notes_type="0" \
    -F ipa="@$DELIVERABLE_PATH" \
    -F dsym="@$OUTPUT_DIR/$APP_NAME.app.dSYM.zip" \
    -H "X-HockeyAppToken: $HOCKEY_APP_TOKEN"

  if [[ $? -ne 0 ]]; then
    echo "Error: Fail uploading to HockeyApp"
    exit 1
  fi

  if [[ -n "$CRITTERCISM_APP_ID" && -n "$CRITTERCISM_KEY" ]]; then
    curl "https://app.crittercism.com/api_beta/dsym/$CRITTERCISM_APP_ID" \
    -F dsym="@$OUTPUT_DIR/$APP_NAME.app.dSYM.zip" \
    -F key="$CRITTERCISM_KEY"

    if [[ $? -ne 0 ]]; then
      echo "Error: Fail uploading to Crittercism"
      exit 1
    fi
  fi
fi
