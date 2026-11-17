#!/usr/bin/env bash
set -euo pipefail
package=org.mewx.wenku8_flutter.online.riqing
adb install build/signed-release/riqing.apk
activity="$(adb shell cmd package resolve-activity --brief "$package" | tr -d '\r' | tail -1)"
[[ "$activity" == "$package/"* ]]
adb shell am start -W -n "$activity"
sleep 6
adb shell dumpsys activity activities | grep -E 'topResumedActivity|mResumedActivity' | grep -F "$package/"
