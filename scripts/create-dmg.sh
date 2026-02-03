#!/bin/bash

# Create DMG installer for CPU Cap

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

# Copy background if exists
BACKGROUND_DIR="$DMG_DIR/.background"
mkdir -p "$BACKGROUND_DIR"
if [ -f "$PROJECT_DIR/dmg-resources/background.png" ]; then
    cp "$PROJECT_DIR/dmg-resources/background.png" "$BACKGROUND_DIR/"
    cp "$PROJECT_DIR/dmg-resources/background@2x.png" "$BACKGROUND_DIR/" 2>/dev/null || true
fi

# Create temporary DMG
TEMP_DMG="$BUILD_DIR/temp.dmg"
hdiutil create -srcfolder "$DMG_DIR" -volname "$APP_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW "$TEMP_DMG"

# Mount it
MOUNT_DIR="/Volumes/$APP_NAME"
hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR"

# Configure DMG window using AppleScript
echo "Configuring DMG window..."
osascript << EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        
        -- Try to set background
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        
        -- Position icons
        set position of item "$APP_NAME.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Unmount
sync
hdiutil detach "$MOUNT_DIR"

# Convert to compressed DMG
echo "Compressing DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 \
    -o "$BUILD_DIR/$DMG_NAME.dmg"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$DMG_DIR"

echo ""
echo "DMG created: $BUILD_DIR/$DMG_NAME.dmg"
echo ""
ls -lh "$BUILD_DIR/$DMG_NAME.dmg"
