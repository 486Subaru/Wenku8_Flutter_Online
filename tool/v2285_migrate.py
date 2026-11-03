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


# The v2284 compatibility patch runs immediately before this migration and
# already promotes pubspec from +2283 to +2284.
replace_once('pubspec.yaml', 'version: 0.5.5+2284', 'version: 0.5.5+2285')
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

# Do not modify files under .github/workflows here: the GITHUB_TOKEN used by
# Actions has contents:write but no workflows permission. The normal CI file
# and this temporary migration workflow are finalized afterwards through the
# authenticated GitHub connector.
for obsolete_path in [
    'tool/apply_v2284_patch.py',
    'tool/apply_v2284_postpatch.py',
    'tool/v2285_release_content.dart',
    'tool/v2285_migrate.py',
]:
    obsolete = Path(obsolete_path)
    if obsolete.exists():
        obsolete.unlink()

print('v2285 source-only migration prepared successfully')
