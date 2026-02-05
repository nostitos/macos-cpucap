#!/bin/bash

# Create DMG installer for CPU Cap (simplified version)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg"
APP_NAME="CPU Cap"
VERSION="${1:-1.0.0}"
DMG_NAME="CPUCap-$VERSION"

echo "Creating DMG for CPU Cap v$VERSION..."

# Check if app exists
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    echo "Run build-release.sh first."
    exit 1
fi

# Clean previous DMG builds
rm -rf "$DMG_DIR"
rm -f "$BUILD_DIR/$DMG_NAME.dmg"
mkdir -p "$DMG_DIR"

# Copy app to DMG staging area
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG directly (without fancy background - simpler and more reliable)
echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "$BUILD_DIR/$DMG_NAME.dmg"

# Clean up
rm -rf "$DMG_DIR"

echo ""
echo "DMG created: $BUILD_DIR/$DMG_NAME.dmg"
echo ""
ls -lh "$BUILD_DIR/$DMG_NAME.dmg"
