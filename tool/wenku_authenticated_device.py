import os
import re
import subprocess
import time
from xml.etree import ElementTree as ET

PACKAGE = 'org.mewx.wenku8_flutter.online.riqingcdn'
FIELD = 'android.widget.EditText'
REMOTE = '/sdcard/.wenku-device-check.xml'
LOGIN = os.environ['WENKU8_TEST_LOGIN']
PASSWORD = os.environ['WENKU8_TEST_PASSWORD']

def adb(*args):
    p = subprocess.run(['adb', *args], capture_output=True, timeout=35)
    if p.returncode:
        raise RuntimeError('Android command failed at ' + args[0])
    return p.stdout

def screen():
    adb('shell', 'uiautomator', 'dump', REMOTE)
    try:
        raw = adb('exec-out', 'cat', REMOTE)
    finally:
        adb('shell', 'rm', '-f', REMOTE)
    return list(ET.fromstring(raw).iter('node'))

def label(node):
    return (node.get('text', '') + '\n' + node.get('content-desc', '')).strip()

def bounds(node):
    return tuple(map(int, re.findall(r'\d+', node.get('bounds', ''))))

def tap(node):
    x1, y1, x2, y2 = bounds(node)
    adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))

def select(nodes, *words, exact=False):
    for node in nodes:
        text = label(node).splitlines()
        if len(bounds(node)) != 4:
            continue
        if any(word == line if exact else word in line for word in words for line in text):
            return node
    return None

def await_layout(match, seconds):
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        try:
            nodes = screen()
        except (RuntimeError, ET.ParseError, subprocess.TimeoutExpired):
            time.sleep(2)
            continue
        result = match(nodes)
        if result is not None:
            return result
        time.sleep(2)
    return None

def require(value, stage):
    if value is None:
        raise RuntimeError(stage)
    return value

def login_form_or_block(nodes):
    if select(nodes, '1015', '访问频率过高', 'You are being rate limited') is not None:
        return 'rate-limit', None
    if select(nodes, 'Verify you are human', 'Performing security verification', '验证您是真人', 'Checking your browser', 'Just a moment') is not None:
        return 'verification', None
    if select(nodes, '文库官网返回 HTTP 403', 'ERR_CONNECTION', 'ERR_NAME_NOT_RESOLVED', '文库页面加载失败') is not None:
        return 'http-block-or-network-error', None
    if select(nodes, '已检测到官网登录状态') is not None:
        return 'signed-in', nodes
    fields = [n for n in nodes if n.get('class') == FIELD and len(bounds(n)) == 4]
    passwords = [n for n in fields if n.get('password') == 'true']
    if passwords and select(nodes, '用户名', '使用者名稱', '用户登录', '會員登錄', '账号', '電子郵件', '用户名或邮箱', '用户名/邮箱') is not None:
        pwd = passwords[0]
        users = [n for n in fields if n.get('password') != 'true' and bounds(n)[1] <= bounds(pwd)[1]]
        if users:
            return 'form', (users[-1], pwd)
    link = select(nodes, '登录', '登入', '用户登录', '会员登录', '登錄', '會員登錄', exact=True)
    if link is not None:
        return 'link', link
    return None

def start():
    adb('install', 'build/app/outputs/flutter-apk/app-x86_64-release.apk')
    component = adb('shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE).decode().splitlines()[-1].strip()
    if not component.startswith(PACKAGE+'/'):
        raise RuntimeError('App launcher activity unavailable')
    adb('shell', 'am', 'start', '-W', '-n', component)
    print('STAGE: APK installed and opened', flush=True)
    for _ in range(18):
        try:
            nodes = screen()
        except (RuntimeError, ET.ParseError, subprocess.TimeoutExpired):
            time.sleep(2)
            continue
        onboarding = select(nodes, '本版更新')
        next_page = select(nodes, '下一页', '完成', exact=True) if onboarding is not None else None
        if next_page is not None:
            tap(next_page)
            time.sleep(1)
            continue
        mine = select(nodes, '我的', exact=True)
        if mine is not None:
            tap(mine)
            break
        time.sleep(2)
    else:
        raise RuntimeError('App profile tab was not observed')
    entry = require(await_layout(lambda ns: select(ns, '登录文库账号', '登录轻小说文库账号'), 35), 'App Wenku8 login entry was not observed')
    tap(entry)
    require(await_layout(lambda ns: select(ns, '日轻 · 文库账号登录'), 35), 'Official login WebView was not observed')
    print('STAGE: opened app official login screen', flush=True)
    time.sleep(20)

def login():
    state, detail = require(await_layout(login_form_or_block, 65), 'Official login form never became visible')
    if state == 'link':
        tap(detail)
        state, detail = require(await_layout(lambda ns: (v if (v:=login_form_or_block(ns)) and v[0]!='link' else None), 55), 'Official login form never became visible after selecting sign in')
    if state == 'form':
        if not LOGIN or not PASSWORD:
            raise RuntimeError('Environment login secrets unavailable')
        # The account is entered only in the app's official-host WebView.
        user, _ = detail
        tap(user)
        adb('shell', 'input', 'text', LOGIN)
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        refreshed = require(await_layout(lambda ns: next((n for n in ns if n.get('class')==FIELD and n.get('password')=='true'),None),15), 'Official password field lost focus layout')
        tap(refreshed)
        adb('shell', 'input', 'text', PASSWORD)
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        def submit_or_code(nodes):
            if select(nodes, '验证码', '驗證碼', '校验码', '校驗碼') is not None:
                return 'captcha', None
            for node in nodes:
                if select([node], '登录', '登入', '登錄', '立即登录', exact=True) is not None and node.get('class') == 'android.widget.Button':
                    return 'button', node
            return None
        action, button = require(await_layout(submit_or_code, 20), 'Official login submit button was not found')
        if action == 'captcha':
            raise RuntimeError('Official login form requires a human verification code')
        tap(button)
        print('STAGE: submitted official login form once', flush=True)
        state, detail = require(await_layout(lambda ns: (v if (v:=login_form_or_block(ns)) and v[0] not in ('form','link') else None), 65), 'Official session not confirmed after one login attempt')
    if state != 'signed-in':
        raise RuntimeError('Official login blocked before session confirmation: '+state)
    tap(require(select(detail, '完成登录', exact=True), 'App login confirmation button was not observed'))
    print('STAGE: app detected the official authenticated session', flush=True)

def open_book():
    # The app searches using its existing Discover interface.
    discover = require(await_layout(lambda ns: select(ns, '发现', exact=True), 35), 'Discover tab was not observed')
    tap(discover)
    search = require(await_layout(lambda ns: select(ns, '搜索', '搜索书名或作者', exact=True) or next((n for n in ns if n.get('class')==FIELD),None), 35), 'Discover search control was not observed')
    tap(search)
    field = require(await_layout(lambda ns: next((n for n in ns if n.get('class')==FIELD),None), 20), 'Discover search field was not observed')
    tap(field)
    adb('shell', 'input', 'text', 'GOSICK')
    adb('shell', 'input', 'keyevent', 'KEYCODE_ENTER')
    result = require(await_layout(lambda ns: next((n for n in ns if n.get('class')!=FIELD and select([n],'GOSICK') is not None and n.get('clickable')=='true'),None), 55), 'Official search result for GOSICK was not observed')
    tap(result)
    chapter = await_layout(lambda ns: select(ns,'插图',exact=True),30)
    if chapter is None:
        read = require(await_layout(lambda ns: select(ns,'开始阅读','继续阅读',exact=True), 15), 'Book reading action was not observed')
        tap(read)
        chapter = await_layout(lambda ns: select(ns,'插图',exact=True),25)
    tap(require(chapter, 'GOSICK illustration chapter was not observed'))
    print('STAGE: selected the official illustration chapter', flush=True)
    def image_or_error(nodes):
        if select(nodes,'章节正文为空','官网插图地址缺失或暂不支持','获取目录失败') is not None:
            return 'chapter-error'
        if select(nodes,'加载图片失败','图片加载失败','插图加载失败','重新读取插图') is not None:
            return 'image-error'
        # The original image's UI must be explicitly observable to count a pass.
        if any('章节插图，点击查看大图' in label(n) for n in nodes):
            return 'image-observed'
        return None
    result = require(await_layout(image_or_error,45), 'Illustration rendering was not independently confirmed')
    if result != 'image-observed':
        raise RuntimeError('The app reported '+result)
    print('STAGE: illustration was observed', flush=True)
    try:
        adb('shell','svc','wifi','disable')
        adb('shell','svc','data','disable')
        adb('shell','am','force-stop',PACKAGE)
        adb('shell','monkey','-p',PACKAGE,'-c','android.intent.category.LAUNCHER','1')
        local = require(await_layout(image_or_error,45), 'Offline illustration rendering was not independently confirmed')
        if local != 'image-observed':
            raise RuntimeError('Offline illustration could not be verified')
        print('STAGE: illustration observed after offline app restart', flush=True)
    finally:
        adb('shell','svc','wifi','enable')
        adb('shell','svc','data','enable')

try:
    start()
    login()
    open_book()
except (RuntimeError, ET.ParseError, subprocess.TimeoutExpired) as exc:
    # Report only fixed stage labels. Never upload UI dumps, screenshots, cookies, or logcat.
    print('CHECK STOPPED:', str(exc) if isinstance(exc,RuntimeError) else 'Android layout or command timed out', flush=True)
    raise SystemExit(1)
finally:
    try:
        adb('shell','rm','-f',REMOTE)
        adb('shell','pm','clear',PACKAGE)
    except (RuntimeError,subprocess.TimeoutExpired):
        pass
