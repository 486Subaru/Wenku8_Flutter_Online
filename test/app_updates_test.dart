import 'package:flutter_test/flutter_test.dart';
import 'package:wenku8_flutter/updates/app_updates.dart';

void main() {
  const repository = '486Subaru/Wenku8_Flutter_Online';
  const tag = 'v0.5.5+2287';

  Map<String, dynamic> releaseJson(String assetName) => {
    'tag_name': tag,
    'draft': false,
    'prerelease': false,
    'body': 'test',
    'assets': [
      {
        'id': 1,
        'name': assetName,
        'browser_download_url':
            'https://github.com/$repository/releases/download/$tag/$assetName',
        'size': 1024,
      },
    ],
  };

  test('Riqing update channel is pinned to the derivative repository', () {
    expect(updateRepository, repository);
    expect(currentAppBuild, 2286);
  });

  test('accepts Riqing ARM64 release assets', () {
    final release = AppRelease.fromGithub(
      releaseJson('riqing-0.5.5-arm64-v8a.apk'),
      repository,
    );
    expect(release, isNotNull);
    expect(release!.assets, hasLength(1));
    expect(release.assetFor(const ['arm64-v8a'])?.name,
        'riqing-0.5.5-arm64-v8a.apk');
  });

  test('rejects upstream Wenku8 package names', () {
    final release = AppRelease.fromGithub(
      releaseJson('wenku8-0.5.5-arm64-v8a.apk'),
      repository,
    );
    expect(release, isNotNull);
    expect(release!.assets, isEmpty);
  });
}
