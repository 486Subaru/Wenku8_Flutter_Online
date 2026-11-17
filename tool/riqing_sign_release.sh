#!/usr/bin/env bash
set -euo pipefail
umask 077
expected_fingerprint=1c12d9ee4b85c68f511c641d2593afd545d8419c2583c32c981679ba6a6803bc
keystore="$(mktemp --suffix=.p12)"
trap 'rm -f "$keystore"' EXIT
test -n "$RIQING_RELEASE_PASSWORD"
printf '%s' "$RIQING_RELEASE_KEYSTORE" | base64 -d > "$keystore"
tools="$(find "$ANDROID_HOME/build-tools" -name apksigner -type f | sort -V | tail -1)"
test -x "$tools"
aapt="$(dirname "$tools")/aapt"
version="$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)$/\1/p' pubspec.yaml)"
test -n "$version"
version_name="${version%+*}"
version_code="${version##*+}"
mkdir -p build/signed-release
target="build/signed-release/riqing.apk"
"$tools" sign --ks "$keystore" --ks-type PKCS12 --ks-key-alias riqing-release \
  --ks-pass env:RIQING_RELEASE_PASSWORD --key-pass env:RIQING_RELEASE_PASSWORD \
  --out "$target" build/app/outputs/flutter-apk/app-release.apk
"$tools" verify --verbose --print-certs "$target" \
  | grep -F "certificate SHA-256 digest: $expected_fingerprint"
"$aapt" dump badging "$target" > "$RUNNER_TEMP/riqing-badging.txt"
grep -E '^package:|^application-label:|^native-code:' "$RUNNER_TEMP/riqing-badging.txt"
grep -F "package: name='org.mewx.wenku8_flutter.online.riqing' versionCode='$version_code' versionName='$version_name'" "$RUNNER_TEMP/riqing-badging.txt"
grep -Fx "application-label:'日轻'" "$RUNNER_TEMP/riqing-badging.txt"
unzip -Z1 "$target" > "$RUNNER_TEMP/riqing-apk-files.txt"
for abi in armeabi-v7a arm64-v8a x86_64; do
  grep -Fx "lib/$abi/libflutter.so" "$RUNNER_TEMP/riqing-apk-files.txt"
  grep -Fx "lib/$abi/libapp.so" "$RUNNER_TEMP/riqing-apk-files.txt"
done
rm -f "$target.idsig"
sha256sum "$target"
