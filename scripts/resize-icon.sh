#!/bin/bash

# Resize a 1024x1024 icon to all required macOS app icon sizes
# Usage: ./resize-icon.sh /path/to/icon_1024x1024.png

set -e

SOURCE="$1"
if [ -z "$SOURCE" ] || [ ! -f "$SOURCE" ]; then
    echo "Usage: ./resize-icon.sh /path/to/icon_1024x1024.png"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ICON_DIR="$PROJECT_DIR/CPUCap/CPUCap/Resources/Assets.xcassets/AppIcon.appiconset"

echo "Resizing icon from: $SOURCE"
echo "Output directory: $ICON_DIR"

# Generate all sizes using sips (built into macOS)
sips -z 16 16 "$SOURCE" --out "$ICON_DIR/icon_16x16.png"
sips -z 32 32 "$SOURCE" --out "$ICON_DIR/icon_32x32.png"
sips -z 64 64 "$SOURCE" --out "$ICON_DIR/icon_64x64.png"
sips -z 128 128 "$SOURCE" --out "$ICON_DIR/icon_128x128.png"
sips -z 256 256 "$SOURCE" --out "$ICON_DIR/icon_256x256.png"
sips -z 512 512 "$SOURCE" --out "$ICON_DIR/icon_512x512.png"
sips -z 1024 1024 "$SOURCE" --out "$ICON_DIR/icon_1024x1024.png"

echo ""
echo "Icon sizes generated:"
ls -la "$ICON_DIR"/*.png

echo ""
echo "Done! Now rebuild the app:"
echo "  cd $PROJECT_DIR && ./scripts/build-release.sh 1.0.1"
