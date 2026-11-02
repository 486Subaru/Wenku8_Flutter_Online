# 0.5.5 Online Restoration

This branch keeps the 0.5.5 reader UI and local-library implementation while adding a separate official-site transport.

## Online path

- Android package ID: `org.mewx.wenku8_flutter.online`
- Method channel: `org.mewx.wenku8/official_web`
- Site pages: discovery rankings, publication categories, search, book details, chapter lists and chapter bodies.
- Media: official Wenku8 image hosts and the site's chapter-illustration paths.
- Authentication: the user signs in inside the official Wenku8 WebView. Session cookies stay in Android's CookieManager and are not copied into Dart preferences or backups.
- Network requests: HTTPS only, official-host allowlist, bounded response sizes, redirect validation and a shared request interval.

## Not restored in this phase

Daily check-in, cloud bookshelf synchronization, reviews and other account mutations remain explicitly unavailable. They are separate from public discovery and reading and must not be presented as working.

## Local verification

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

The release build is intended to coexist with the original preview installation; it does not replace the original application ID.
