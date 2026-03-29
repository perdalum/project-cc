#!/bin/bash
# Builds ProjectCommandAndControl.app and copies it to ./dist/
# Must build outside the project tree to avoid iCloud Drive xattr conflicts with codesign.

set -e

SCHEME="ProjectCommandAndControl"
CONFIG="${1:-Release}"
TMP_DIR="/tmp/PCC-build-$$"
DIST_DIR="$(dirname "$0")/dist"

echo "Building $SCHEME ($CONFIG)..."

xcodebuild \
  -project "$(dirname "$0")/ProjectCommandAndControl.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  CONFIGURATION_BUILD_DIR="$TMP_DIR" \
  build

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/$SCHEME.app"
cp -R "$TMP_DIR/$SCHEME.app" "$DIST_DIR/"
rm -rf "$TMP_DIR"

echo "Done: $DIST_DIR/$SCHEME.app"
open "$DIST_DIR/$SCHEME.app"
