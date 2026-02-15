#!/bin/bash

# Handed Clean Script
# Removes all build artifacts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Handed Clean ==="
echo ""

# Clean Xcode build
echo "Cleaning Xcode build..."
xcodebuild -project "$PROJECT_DIR/dnsmasqGUI.xcodeproj" \
    -scheme dnsmasqGUI \
    clean 2>/dev/null || true

# Remove build directory
if [ -d "$PROJECT_DIR/build" ]; then
    echo "Removing build directory..."
    rm -rf "$PROJECT_DIR/build"
fi

# Remove dist contents (but keep the directory)
if [ -d "$PROJECT_DIR/dist" ]; then
    echo "Cleaning dist directory..."
    rm -rf "$PROJECT_DIR/dist/"*
fi

# Remove DerivedData for this project
DERIVED_DATA_PATH=~/Library/Developer/Xcode/DerivedData
if [ -d "$DERIVED_DATA_PATH" ]; then
    echo "Cleaning DerivedData..."
    find "$DERIVED_DATA_PATH" -maxdepth 1 -name "dnsmasqGUI-*" -type d -exec rm -rf {} \; 2>/dev/null || true
fi

echo ""
echo "=== Clean Complete ==="
