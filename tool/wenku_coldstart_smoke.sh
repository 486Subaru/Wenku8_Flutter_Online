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
mkdir -p build/wenku-startup-diagnostics
diagnostics=build/wenku-startup-diagnostics
coordinate=''
for attempt in $(seq 1 14); do
  if adb shell uiautomator dump /sdcard/wenku-startup.xml; then
    adb exec-out cat /sdcard/wenku-startup.xml > "$diagnostics/hierarchy.xml"
    coordinate="$(python3 - "$diagnostics/hierarchy.xml" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

nodes = list(ET.parse(sys.argv[1]).iter('node'))
release_notes = any('本版更新' in node.get('content-desc', '') for node in nodes)
for node in nodes:
    identifier = node.get('resource-id', '')
    labels = node.get('text', '') + node.get('content-desc', '')
    if release_notes and labels.splitlines() and set(labels.splitlines()) <= {'下一页', '完成'}:
        action = 'release-notes'
    elif 'wenku8_load_discovery' in identifier or any(
        label in labels for label in ('加载发现', '載入發現', '加載發現')
    ):
        action = 'discover'
    else:
        continue
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.attrib['bounds']))
    if x2 > x1 and y2 > y1:
        print(action, (x1 + x2) // 2, (y1 + y2) // 2)
        break
PY
)" || coordinate=''
    if [[ "$coordinate" == release-notes\ * ]]; then
      read -r action x y <<< "$coordinate"
      adb shell input tap "$x" "$y"
      coordinate=''
    elif [[ "$coordinate" == discover\ * ]]; then
      break
    fi
  fi
  sleep 2
done
if [[ -z "$coordinate" ]]; then
  adb exec-out screencap -p > "$diagnostics/screen.png"
  adb logcat -d -s flutter:E AndroidRuntime:E > "$diagnostics/application.log"
  echo 'Cannot find the explicit discovery control. The emulator screen and UI hierarchy are attached.'
  exit 1
fi
sleep 5
if grep -E "$official" "$traffic"; then
  echo 'The discovery page would have contacted the official hosts without input.'
  exit 1
fi
read -r action x y <<< "$coordinate"
adb shell input tap "$x" "$y"
for attempt in $(seq 1 15); do
  if grep -m1 -E "connected (${page_official#^})" "$traffic"; then
    echo 'Explicit discovery tap connected to the real official website.'
    sleep 25
    adb shell uiautomator dump /sdcard/wenku-startup.xml
    adb exec-out cat /sdcard/wenku-startup.xml > "$diagnostics/result.xml"
    python3 - "$diagnostics/result.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

labels = [
    node.get('text', '') + node.get('content-desc', '')
    for node in ET.parse(sys.argv[1]).iter('node')
]
for label in labels:
    if any(text in label for text in ('1015', '需要完成官网验证', '需要连接文库账号', '书籍加载失败')):
        print(label[:360].replace('\n', ' '))
if any('1015' in label for label in labels):
    raise SystemExit('The official website rate-limited the explicit initial request.')
PY
    exit 0
  fi
  sleep 1
done
echo 'Explicit discovery tap did not produce an official connection.'
exit 1
