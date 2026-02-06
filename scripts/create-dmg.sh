#!/bin/bash

# Create DMG installer for CPU Cap
# Signs and notarizes the DMG for Gatekeeper-free distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg"
APP_NAME="CPU Cap"
VERSION="${1:-1.0.0}"
DMG_NAME="CPUCap-$VERSION"
SIGN_IDENTITY="Developer ID Application: Mathieu Gagnon (RJL9XWBZ9L)"
NOTARY_PROFILE="cpucap-notary"

echo "Creating DMG for CPU Cap v$VERSION..."

# Check if app exists
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    echo "Run build-release.sh first."
    exit 1
fi

# Verify the app is properly signed before packaging
echo "Verifying app signature..."
codesign --verify --deep --strict "$APP_BUNDLE"
echo "App signature OK."

# Clean previous DMG builds
rm -rf "$DMG_DIR"
rm -f "$BUILD_DIR/$DMG_NAME.dmg"
mkdir -p "$DMG_DIR"

# Copy app to DMG staging area
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "$BUILD_DIR/$DMG_NAME.dmg"

# Clean up staging
rm -rf "$DMG_DIR"

# Sign the DMG itself
echo "Signing DMG..."
codesign --sign "$SIGN_IDENTITY" --timestamp "$BUILD_DIR/$DMG_NAME.dmg"

# Notarize
echo ""
echo "Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "$BUILD_DIR/$DMG_NAME.dmg" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# Staple the notarization ticket to the DMG
echo "Stapling notarization ticket..."
xcrun stapler staple "$BUILD_DIR/$DMG_NAME.dmg"

# Verify everything
echo ""
echo "Verifying final DMG..."
spctl --assess --type open --context context:primary-signature --verbose "$BUILD_DIR/$DMG_NAME.dmg" 2>&1 || true
xcrun stapler validate "$BUILD_DIR/$DMG_NAME.dmg"

echo ""
echo "DMG created, signed, and notarized: $BUILD_DIR/$DMG_NAME.dmg"
echo ""
ls -lh "$BUILD_DIR/$DMG_NAME.dmg"
