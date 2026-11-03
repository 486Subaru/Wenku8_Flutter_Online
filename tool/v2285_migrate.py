from pathlib import Path
import shutil


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f'{path}: expected exactly one match, found {count}: {old!r}'
        )
    target.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once('pubspec.yaml', 'version: 0.5.5+2283', 'version: 0.5.5+2285')
replace_once(
    'android/app/build.gradle.kts',
    'versionName = "0.5.5-online-fix"',
    'versionName = "0.5.5"',
)
replace_once(
    'android/app/build.gradle.kts',
    'manifestPlaceholders["wenkuAppLabel"] = "日轻修正版"',
    'manifestPlaceholders["wenkuAppLabel"] = "日轻"',
)
replace_once(
    'lib/updates/app_updates.dart',
    'const currentAppBuild = 2276;',
    'const currentAppBuild = 2285;',
)

shutil.copyfile(
    'tool/v2285_release_content.dart',
    'lib/updates/current_release_content.dart',
)

ci_path = Path('.github/workflows/flutter-ci.yml')
ci = ci_path.read_text(encoding='utf-8')
patch_lines = [
    '      - name: Apply v2284 network compatibility patch',
    '        run: |',
    '          python3 tool/apply_v2284_patch.py',
    '          python3 tool/apply_v2284_postpatch.py',
    '          git diff --check',
    '',
]
patch_step = '\n'.join(patch_lines) + '\n'
if ci.count(patch_step) != 1:
    raise SystemExit('flutter-ci.yml: v2284 patch step not found exactly once')
ci = ci.replace(patch_step, '', 1)
ci = ci.replace(
    'Wenku8-0.5.5-online-fix-arm64-v2284',
    'riqing-0.5.5-arm64-v2285',
)
ci_path.write_text(ci, encoding='utf-8')

for obsolete_path in [
    'tool/apply_v2284_patch.py',
    'tool/apply_v2284_postpatch.py',
    'tool/v2285_release_content.dart',
    'tool/v2285_migrate.py',
    '.github/workflows/v2285-migrate-build.yml',
]:
    obsolete = Path(obsolete_path)
    if obsolete.exists():
        obsolete.unlink()

print('v2285 source migration prepared successfully')
