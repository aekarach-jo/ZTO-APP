#!/bin/sh

# Xcode Cloud runs this immediately after cloning the repository, before it
# resolves dependencies or builds. Its images ship without Flutter, so the
# archive fails on the two files Flutter generates rather than commits:
# Generated.xcconfig (from `flutter pub get`) and the Pods-Runner xcfilelists
# (from `pod install`).
#
# Flutter is pinned to the version the app is developed against so a stable
# channel release cannot silently change the toolchain under a store build.

set -e

FLUTTER_VERSION="3.41.9"
FLUTTER_HOME="$HOME/flutter"

echo "--- Installing Flutter $FLUTTER_VERSION"
git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch "$FLUTTER_VERSION" \
  "$FLUTTER_HOME"

export PATH="$FLUTTER_HOME/bin:$PATH"

flutter --version
flutter config --no-analytics
flutter precache --ios

echo "--- Resolving Dart packages (writes ios/Flutter/Generated.xcconfig)"
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "--- Installing pods (writes the Pods-Runner xcfilelists)"
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "--- Ready to archive"
