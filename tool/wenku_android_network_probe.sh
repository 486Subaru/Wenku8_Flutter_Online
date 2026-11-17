#!/usr/bin/env bash
set -euo pipefail
evidence=build/emulator-evidence
pkg=org.mewx.wenku8_flutter.online.fix
mkdir -p "$evidence"
{
  adb shell getprop ro.build.version.sdk
  adb shell getprop ro.product.cpu.abi
  adb shell dumpsys webviewupdate | grep -m1 'Current WebView package' || true
} | tee "$evidence/android-environment.txt"
launch() {
  local launcher
  launcher=$(adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$pkg" | tr -d '\r' | tail -n1)
  [[ "$launcher" == "$pkg/"* ]]
  adb shell am start -W -n "$launcher"
}
adb install /tmp/wenku-product.apk
adb logcat -c
launch | tee "$evidence/product-launch.txt"
sleep 7
adb shell pidof "$pkg" | tee -a "$evidence/product-launch.txt"
adb shell dumpsys activity activities | grep -E 'mResumedActivity|topResumedActivity' | tee -a "$evidence/product-launch.txt"
adb exec-out screencap -p > "$evidence/product-start.png"
adb install -r /tmp/wenku-probe.apk
adb shell pm clear "$pkg"
adb logcat -c
launch | tee "$evidence/probe-launch.txt"
for _ in $(seq 1 60); do
  adb logcat -d -s flutter:I AndroidRuntime:E | grep 'WENKU_PROBE' > "$evidence/online-probe.log" || true
  if grep -q '"name":"login_attempt"' "$evidence/online-probe.log"; then break; fi
  sleep 3
done
cat "$evidence/online-probe.log"
grep -q '"name":"summary","nativeFailures":0' "$evidence/online-probe.log"
sleep 5
adb shell dumpsys activity activities | grep -E 'mResumedActivity|topResumedActivity' | tee "$evidence/login-screen.txt"
adb exec-out screencap -p > "$evidence/login-screen.png"
grep -q 'Wenku8LoginActivity' "$evidence/login-screen.txt"
adb shell input keyevent 4
