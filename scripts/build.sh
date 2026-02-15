#!/bin/bash

# Handed Build Script
# Builds the application for the specified configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="Handed"

# Default configuration
CONFIGURATION="${1:-Release}"

echo "=== Handed Build Script ==="
echo "Configuration: $CONFIGURATION"
echo "Project Directory: $PROJECT_DIR"
echo ""

# Create dist directory if it doesn't exist
mkdir -p "$DIST_DIR"

# Clean previous build
echo "Cleaning previous build..."
xcodebuild -project "$PROJECT_DIR/dnsmasqGUI.xcodeproj" \
    -scheme dnsmasqGUI \
    -configuration "$CONFIGURATION" \
    clean 2>/dev/null || true

# Build the project
echo "Building Handed ($CONFIGURATION)..."
xcodebuild -project "$PROJECT_DIR/dnsmasqGUI.xcodeproj" \
    -scheme dnsmasqGUI \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$PROJECT_DIR/build" \
    build

# Find the built app
APP_PATH="$PROJECT_DIR/build/Build/Products/$CONFIGURATION/${APP_NAME}.app"

if [ -d "$APP_PATH" ]; then
    echo ""
    echo "Build successful!"
    echo "App location: $APP_PATH"

    # Copy to dist folder
    echo "Copying to dist folder..."
    rm -rf "$DIST_DIR/${APP_NAME}.app"
    cp -R "$APP_PATH" "$DIST_DIR/"

    echo ""
    echo "=== Build Complete ==="
    echo "Application: $DIST_DIR/${APP_NAME}.app"
    echo ""
    echo "To run: open $DIST_DIR/${APP_NAME}.app"
else
    echo "Error: Build failed - app not found at $APP_PATH"
    exit 1
fi
