#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/debug"
APP_DIR="$ROOT_DIR/dist/Extremum.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
swift build

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
cp "$BUILD_DIR/Extremum" "$MACOS_DIR/Extremum"
if [[ -f "$ROOT_DIR/Resources/ApplicationIcon.icns" ]]; then
  cp "$ROOT_DIR/Resources/ApplicationIcon.icns" "$RESOURCES_DIR/ApplicationIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Extremum</string>
    <key>CFBundleIdentifier</key>
    <string>local.codex.extremum</string>
    <key>CFBundleName</key>
    <string>Extremum</string>
    <key>CFBundleDisplayName</key>
    <string>Extremum</string>
    <key>CFBundleIconFile</key>
    <string>ApplicationIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
