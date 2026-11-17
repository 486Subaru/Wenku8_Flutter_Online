#!/usr/bin/env bash
set -euo pipefail
evidence=build/upstream-evidence
aapt=$(find "$ANDROID_HOME/build-tools" -type f -name aapt | sort -V | tail -n1)
"$aapt" dump badging /tmp/upstream-wenku8.apk > "$evidence/manifest.txt"
pkg=$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" "$evidence/manifest.txt")
[[ "$pkg" =~ ^[A-Za-z0-9_.]+$ ]]
adb install /tmp/upstream-wenku8.apk
launcher=$(adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$pkg" | tr -d '\r' | tail -n1)
[[ "$launcher" == "$pkg/"* ]]
adb shell am start -W -n "$launcher" | tee "$evidence/launch.txt"
sleep 15
adb shell pidof "$pkg" | tee -a "$evidence/launch.txt"
cd "$evidence"
python3 - <<'PY' | tee observed-ui.txt
import re, subprocess, time, xml.etree.ElementTree as ET
def adb(*args, **kwargs):
    return subprocess.run(["adb", *args], check=True, timeout=30, **kwargs)
def snapshot(name):
    with open(name+'.png', 'wb') as shot:
        adb('exec-out', 'screencap', '-p', stdout=shot)
    try:
        adb('shell','uiautomator','dump','/sdcard/wenku-probe.xml', stdout=subprocess.DEVNULL)
        dump=adb('exec-out','cat','/sdcard/wenku-probe.xml', capture_output=True).stdout
        with open(name+'.xml', 'wb') as out:
            out.write(dump)
        nodes=list(ET.fromstring(dump).iter('node'))
    except (subprocess.SubprocessError, ET.ParseError):
        print(name+': UI tree unavailable')
        return []
    print(name+': '+repr(list(dict.fromkeys(label for n in nodes for key in ('text','content-desc') if (label:=n.get(key)) and len(label)<200))[:30]))
    return nodes
def tap(node):
    coordinates=[int(x) for x in re.findall(r'\d+', node.get('bounds',''))]
    if len(coordinates)!=4:
        return False
    x1,y1,x2,y2=coordinates
    adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
    return True
def label_is(node, labels):
    return any((node.get(key) or '').split('\n')[0].strip() in labels for key in ('text','content-desc'))
nodes=snapshot('upstream-start')
for index in range(4):
    words=[(n.get('text') or '')+' '+(n.get('content-desc') or '') for n in nodes]
    if not any('本版更新' in value or '请务必阅读' in value or '更新说明' in value for value in words):
        break
    onward=next((n for n in nodes if n.get('clickable')=='true' and label_is(n, ('下一页', '完成', '我知道了', '开始使用', '关闭', '我已阅读', '进入应用'))), None)
    if onward is None:
        onward=next((n for n in nodes if label_is(n, ('下一页', '完成', '我知道了', '开始使用', '关闭', '我已阅读', '进入应用'))), None)
    if onward is None or not tap(onward):
        print('Onboarding action unavailable in the visible UI tree.')
        break
    time.sleep(5)
    nodes=snapshot('upstream-onboarding-'+str(index+1))
time.sleep(6)
nodes=snapshot('upstream-home')
search=next((n for n in nodes if n.get('clickable')=='true' and label_is(n, ('搜索', '搜索书籍', '搜索作品', '搜索故事', 'Search', '查找'))), None)
if search is not None and tap(search):
    time.sleep(3)
    fields=snapshot('upstream-search-open')
    entry=next((n for n in fields if (n.get('class') or '').endswith('EditText')), None)
    if entry is not None and tap(entry):
        adb('shell','input','text','SAO')
        adb('shell','input','keyevent','66')
        time.sleep(18)
        snapshot('upstream-search-SAO')
    else:
        print('Search opened; no editable field was exposed.')
else:
    print('Search action was not exposed in the initial UI tree.')
PY
head -n 6 manifest.txt
