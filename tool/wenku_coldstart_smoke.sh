#!/usr/bin/env bash
set -euo pipefail
package=org.mewx.wenku8_flutter.online.riqingpreview
official='^(www[.])?wenku8[.](net|cc)$|^(img|pic)[.]wenku8[.](com|cn|net)$'
page_official='^(www[.])?wenku8[.](net|cc)$'
traffic="$(mktemp)"
port=8766
python3 tool/wenku_startup_proxy.py "$port" > "$traffic" &
proxy_pid=$!
cleanup() {
  adb shell settings put global http_proxy :0
  kill "$proxy_pid" 2>/dev/null || true
}
trap cleanup EXIT
sleep 1
kill -0 "$proxy_pid"

adb install build/app/outputs/flutter-apk/app-x86_64-release.apk
adb shell settings put global http_proxy "10.0.2.2:$port"
adb shell am force-stop "$package"
activity="$(adb shell cmd package resolve-activity --brief "$package" | tr -d '\r' | tail -1)"
[[ "$activity" == "$package/"* ]]
adb shell am start -W -n "$activity"
sleep 10
adb shell dumpsys activity activities | grep -E 'topResumedActivity|mResumedActivity' | grep -F "$package/"
if grep -E "$official" "$traffic"; then
  echo 'Cold start sent requests to an official Wenku8 host.'
  exit 1
fi
echo 'Cold start: zero connections to official Wenku8 sites and image hosts.'
adb shell uiautomator dump /sdcard/wenku-startup.xml
adb pull /sdcard/wenku-startup.xml /tmp/wenku-startup.xml >/dev/null
read -r x y < <(python3 - <<'PY'
import re
import xml.etree.ElementTree as ET

for node in ET.parse('/tmp/wenku-startup.xml').iter('node'):
    if any('加载发现' in node.get(name, '') for name in ('text', 'content-desc')):
        x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.attrib['bounds']))
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
else:
    raise SystemExit('Cannot find the explicit discovery control')
PY
)
adb shell input tap "$x" "$y"
for attempt in $(seq 1 15); do
  if grep -m1 -E "$page_official" "$traffic"; then
    echo 'Explicit discovery tap reached the official website connection.'
    exit 0
  fi
  sleep 1
done
echo 'Explicit discovery tap did not produce an official connection.'
exit 1
