#!/bin/bash

# Handed Release Build Script
# Builds a release version and creates distributable artifacts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
VERSION="2.1.0"
APP_NAME="dnsmasqGUI"  # Keep Xcode project name

echo "=== Handed Release Build ==="
echo "Version: $VERSION"
echo ""

# Build release version
"$SCRIPT_DIR/build.sh" Release

APP_PATH="$DIST_DIR/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Create ZIP archive
echo "Creating ZIP archive..."
ZIP_NAME="Handed-v${VERSION}-macOS.zip"
cd "$DIST_DIR"
rm -f "$ZIP_NAME"
ditto -c -k --keepParent "${APP_NAME}.app" "$ZIP_NAME"

echo ""
echo "=== Release Build Complete ==="
echo ""
echo "Artifacts:"
echo "  App:  $DIST_DIR/${APP_NAME}.app"
echo "  ZIP:  $DIST_DIR/$ZIP_NAME"
echo ""
echo "ZIP size: $(du -h "$DIST_DIR/$ZIP_NAME" | cut -f1)"
