#!/bin/bash
set -e

OUTPUT_DIR="build/xcframeworks"
DERIVED_DATA="build/DerivedData"
ARCHIVES="build/archives"
mkdir -p "$OUTPUT_DIR"

LIBRARIES=(
  PingLogger PingStorage PingNetwork PingCommons PingBrowser
  PingOrchestrate PingDavinciPlugin PingJourneyPlugin
  PingOidc PingDavinci PingJourney PingDeviceId
  PingDeviceProfile PingDeviceClient PingTamperDetector PingExternalIdP
  PingExternalIdPApple PingFido PingOath PingPush
  PingBinding
  PingExternalIdPGoogle PingExternalIdPFacebook PingProtect PingReCaptchaEnterprise
)

for LIB in "${LIBRARIES[@]}"; do
  echo "=== Building $LIB ==="

  # Archive for iOS device
  xcodebuild archive \
    -scheme "$LIB" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVES/${LIB}-iOS" \
    -derivedDataPath "$DERIVED_DATA" \
    SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    -quiet

  # Archive for iOS Simulator
  xcodebuild archive \
    -scheme "$LIB" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$ARCHIVES/${LIB}-iOS-Simulator" \
    -derivedDataPath "$DERIVED_DATA" \
    SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    -quiet

  # Create XCFramework
  xcodebuild -create-xcframework \
    -archive "$ARCHIVES/${LIB}-iOS.xcarchive" -framework "${LIB}.framework" \
    -archive "$ARCHIVES/${LIB}-iOS-Simulator.xcarchive" -framework "${LIB}.framework" \
    -output "$OUTPUT_DIR/${LIB}.xcframework"

  echo "=== $LIB.xcframework created ==="
done
