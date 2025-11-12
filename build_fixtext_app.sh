#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FixText"
APP_DIR="$APP_NAME.app"

echo "Building release binary…"
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)

echo "Preparing .app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"

cp "$BIN_PATH/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat <<'PLIST' > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>FixText</string>
    <key>CFBundleDisplayName</key><string>FixText</string>
    <key>CFBundleIdentifier</key><string>com.example.FixText</string>
    <key>CFBundleExecutable</key><string>FixText</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

if [ -f "FixTextIcon.icns" ]; then
    mkdir -p "$APP_DIR/Contents/Resources"
    cp FixTextIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_DIR/Contents/Info.plist" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_DIR/Contents/Info.plist"
fi

echo "Signing ad-hoc with entitlements…"
codesign --force --deep --sign - --entitlements FixText.entitlements "$APP_DIR" >/dev/null || true

echo "Done! Open $APP_DIR or drag it to Applications."
