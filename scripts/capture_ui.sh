#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
PREVIEW_ROOT="${RUNNER_TEMP:-/tmp}/erosion-ui-preview"
mkdir -p "$PREVIEW_ROOT/screenshots"

xcodebuild -project Erosion.xcodeproj -scheme Erosion -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$PREVIEW_ROOT/DerivedData" \
    build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

PREVIEW_APP="$PREVIEW_ROOT/DerivedData/Build/Products/Debug-iphonesimulator/ErosionPlus.app"
DEVICE_ID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
devices=json.load(sys.stdin)["devices"]
choices=[device for runtime,items in devices.items() if "iOS" in runtime for device in items if "iPhone" in device["name"]]
preferred=next((device for device in choices if "18 Pro" in device["name"] and "Max" not in device["name"]),choices[0])
print(preferred["udid"])
')
DEVICE_STATE=$(xcrun simctl list devices -j | python3 -c 'import json,sys; device_id=sys.argv[1]; print(next(d["state"] for rows in json.load(sys.stdin)["devices"].values() for d in rows if d["udid"]==device_id))' "$DEVICE_ID")
if [ "$DEVICE_STATE" != Booted ]; then xcrun simctl boot "$DEVICE_ID"; fi
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" "$PREVIEW_APP"
xcrun simctl status_bar "$DEVICE_ID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100

capture() {
    local tab="$1" appearance="$2" language="$3" filename="$4"
    xcrun simctl terminate "$DEVICE_ID" io.github.su-cyber-art.ErosionPlus >/dev/null 2>&1 || true
    xcrun simctl ui "$DEVICE_ID" appearance "$appearance"
    xcrun simctl launch "$DEVICE_ID" io.github.su-cyber-art.ErosionPlus --preview-tab "$tab" -appLanguageMode "$language" -AppleLanguages "($language)" -AppleLocale "$language"
    sleep 4
    xcrun simctl io "$DEVICE_ID" screenshot "$PREVIEW_ROOT/screenshots/$filename.png"
}

capture 0 light zh-Hans home-light
capture 1 light zh-Hans tools-light
capture 2 light zh-Hans files-light
capture 3 light zh-Hans settings-light
capture 0 dark zh-Hans home-dark
capture 0 light en home-english

echo "UI screenshots: $PREVIEW_ROOT/screenshots"
