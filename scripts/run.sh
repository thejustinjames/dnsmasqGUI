#!/bin/bash

# Handed Run Script
# Builds (if needed) and runs the application

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/Handed.app"

# Check if app exists, build if not
if [ ! -d "$APP_PATH" ]; then
    echo "App not found. Building..."
    "$SCRIPT_DIR/build.sh" Debug
fi

echo "Launching Handed..."
open "$APP_PATH"
