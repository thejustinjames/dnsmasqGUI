#!/bin/bash

# Handed DMG Creation Script
# Creates a distributable DMG file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
VERSION="2.1.0"
APP_NAME="dnsmasqGUI"  # Xcode project name
DMG_NAME="Handed-v${VERSION}-macOS"
DMG_PATH="$DIST_DIR/${DMG_NAME}.dmg"
VOLUME_NAME="Handed"

echo "=== Handed DMG Creation ==="
echo "Version: $VERSION"
echo ""

# Ensure app exists
APP_PATH="$DIST_DIR/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "App not found. Building first..."
    "$SCRIPT_DIR/build.sh" Release
fi

# Remove existing DMG
rm -f "$DMG_PATH"

# Create temporary DMG directory
TEMP_DMG_DIR=$(mktemp -d)
echo "Creating DMG structure..."

# Copy app to temp directory
cp -R "$APP_PATH" "$TEMP_DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$TEMP_DMG_DIR/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Cleanup
rm -rf "$TEMP_DMG_DIR"

echo ""
echo "=== DMG Creation Complete ==="
echo ""
echo "DMG: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "To install:"
echo "  1. Open the DMG"
echo "  2. Drag Handed to Applications"
