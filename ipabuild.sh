#!/bin/bash

set -e

cd "$(dirname "$0")"

PROJECT_NAME=Erosion
APPLICATION_NAME=ErosionPlus
APP_VERSION=$(grep -m1 'MARKETING_VERSION =' "$PROJECT_NAME.xcodeproj/project.pbxproj" | sed -E 's/.*= *([^;]+);/\1/' | tr -d '[:space:]')
IPA_NAME="${APPLICATION_NAME}_v${APP_VERSION}_Bilingual.ipa"
if [[ $* == *--debug* ]]; then
    IPA_NAME="${APPLICATION_NAME}_v${APP_VERSION}_Bilingual.debug.ipa"
fi

echo "[*] $APPLICATION_NAME v$APP_VERSION Build Script"

echo "[*] Building device pairing and notification capture library..."
./Native/DeviceConsole/build-xcframework.sh

rm -rf build

WORKING_LOCATION="$(pwd)"

if [ ! -d "build" ]; then
    mkdir build
fi

cd build

echo "[*] Building..."
if [[ $* == *--debug* ]]; then
xcodebuild -project "$WORKING_LOCATION/$PROJECT_NAME.xcodeproj" \
    -scheme "$PROJECT_NAME" \
    -configuration Debug \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp" \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO"

DD_APP_PATH="$WORKING_LOCATION/build/DerivedDataApp/Build/Products/Debug-iphoneos/$APPLICATION_NAME.app"
TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"
cp -r "$DD_APP_PATH" "$TARGET_APP"
else
xcodebuild -project "$WORKING_LOCATION/$PROJECT_NAME.xcodeproj" \
    -scheme "$PROJECT_NAME" \
    -configuration Release \
    -derivedDataPath "$WORKING_LOCATION/build/DerivedDataApp" \
    -destination 'generic/platform=iOS' \
    build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO" ASSETCATALOG_COMPILER_OPTIMIZATION=space DEPLOYMENT_POSTPROCESSING=YES STRIP_SWIFT_SYMBOLS=YES SEPARATE_STRIP=YES STRIP_STYLE=all

DD_APP_PATH="$WORKING_LOCATION/build/DerivedDataApp/Build/Products/Release-iphoneos/$APPLICATION_NAME.app"
TARGET_APP="$WORKING_LOCATION/build/$APPLICATION_NAME.app"
cp -r "$DD_APP_PATH" "$TARGET_APP"
fi

echo "[*] Stripping signature..."
codesign --remove "$TARGET_APP"
if [ -e "$TARGET_APP/_CodeSignature" ]; then
    rm -rf "$TARGET_APP/_CodeSignature"
fi
if [ -e "$TARGET_APP/embedded.mobileprovision" ]; then
    rm -rf "$TARGET_APP/embedded.mobileprovision"
fi

echo "[*] Adding entitlements..."
if command -v ldid >/dev/null 2>&1; then
    ldid -S"$WORKING_LOCATION/Erosion/Erosion.entitlements" "$TARGET_APP"
else
    codesign --force --sign - --entitlements "$WORKING_LOCATION/Erosion/Erosion.entitlements" --generate-entitlement-der --timestamp=none "$TARGET_APP"
fi

echo "[*] Packaging..."
mkdir Payload
cp -r "$APPLICATION_NAME.app" "Payload/$APPLICATION_NAME.app"
zip -9vr "$APPLICATION_NAME.ipa" Payload

echo "[*] All done, cleaning up..."
rm -rf Payload

cd ..
mv "$WORKING_LOCATION/build/$APPLICATION_NAME.ipa" "./$IPA_NAME"
rm -rf "$WORKING_LOCATION/build/"
echo "[*] Output IPA: $(pwd)/$IPA_NAME"
