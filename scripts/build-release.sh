#!/bin/bash

# Build CPU Cap for release
# Creates a universal binary (arm64 + x86_64) app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="CPU Cap"
BUNDLE_ID="com.cpucap.app"
VERSION="${1:-1.0.0}"

echo "Building CPU Cap v$VERSION..."

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd "$PROJECT_DIR/CPUCap"

# Build for both architectures
echo "Building for arm64..."
swift build -c release --arch arm64

echo "Building for x86_64..."
swift build -c release --arch x86_64

# Create universal binary
echo "Creating universal binary..."
mkdir -p "$BUILD_DIR/universal"
lipo -create \
    .build/arm64-apple-macosx/release/CPUCap \
    .build/x86_64-apple-macosx/release/CPUCap \
    -output "$BUILD_DIR/universal/CPUCap"

# Create app bundle structure
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/universal/CPUCap" "$APP_BUNDLE/Contents/MacOS/CPU Cap"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CPU Cap</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024. MIT License.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Copy icon if it exists
ICON_SOURCE="$PROJECT_DIR/CPUCap/CPUCap/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
if [ -f "$ICON_SOURCE" ]; then
    # Convert PNG to icns
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    
    # Copy all icon sizes
    ICON_BASE="$PROJECT_DIR/CPUCap/CPUCap/Resources/Assets.xcassets/AppIcon.appiconset"
    cp "$ICON_BASE/icon_16x16.png" "$ICONSET_DIR/icon_16x16.png"
    cp "$ICON_BASE/icon_32x32.png" "$ICONSET_DIR/icon_16x16@2x.png"
    cp "$ICON_BASE/icon_32x32.png" "$ICONSET_DIR/icon_32x32.png"
    cp "$ICON_BASE/icon_64x64.png" "$ICONSET_DIR/icon_32x32@2x.png"
    cp "$ICON_BASE/icon_128x128.png" "$ICONSET_DIR/icon_128x128.png"
    cp "$ICON_BASE/icon_256x256.png" "$ICONSET_DIR/icon_128x128@2x.png"
    cp "$ICON_BASE/icon_256x256.png" "$ICONSET_DIR/icon_256x256.png"
    cp "$ICON_BASE/icon_512x512.png" "$ICONSET_DIR/icon_256x256@2x.png"
    cp "$ICON_BASE/icon_512x512.png" "$ICONSET_DIR/icon_512x512.png"
    cp "$ICON_BASE/icon_1024x1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
    
    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
    echo "Icon created."
fi

# Ad-hoc code sign
echo "Code signing..."
codesign --sign - --force --deep "$APP_BUNDLE"

# Verify
echo "Verifying..."
codesign --verify --deep --strict "$APP_BUNDLE"

echo ""
echo "Build complete!"
echo "App bundle: $APP_BUNDLE"
echo ""

# Show info
ls -la "$APP_BUNDLE/Contents/MacOS/"
file "$APP_BUNDLE/Contents/MacOS/CPU Cap"
