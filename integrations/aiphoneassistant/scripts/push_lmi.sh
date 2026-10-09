#!/bin/bash
# lmi deploy: build-if-needed, then adb install -r (no root required once
# the system copy exists; see INTEGRATION.md for the root/remount fallback).
set -e
AOSP_ROOT="/home/inoki/Builds/LineageOS/lineage-22_2-poco-f2"
APK_PATH="$AOSP_ROOT/out/target/product/lmi/system_ext/priv-app/AIPhoneAssistant/AIPhoneAssistant.apk"

if ! adb devices | grep -qw "device$"; then
    echo "No ADB device found:"; adb devices; exit 1
fi

if [ ! -f "$APK_PATH" ]; then
    "$(dirname "$(readlink -f "$0")")/build_lmi.sh"
fi

echo "Installing $APK_PATH ..."
adb install -r "$APK_PATH"
echo "Deployed. Verify: adb logcat -s AIPhoneAssistant"
