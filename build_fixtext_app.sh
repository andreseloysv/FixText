    #!/usr/bin/env bash
    set -euo pipefail

    APP_NAME="FixTextApp"
    APP_DIR="$APP_NAME.app"

    echo "Building release binary…"
    swift build -c release

    BIN_PATH=$(swift build -c release --show-bin-path)

    echo "Preparing .app bundle at $APP_DIR"
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR/Contents/MacOS"

    cp "$BIN_PATH/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

    cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\>
    <plist version="1.0">
    <dict>
        <key>CFBundleName</key><string>FixTextApp</string>
        <key>CFBundleDisplayName</key><string>FixText</string>
        <key>CFBundleIdentifier</key><string>com.example.FixTextApp</string>
        <key>CFBundleExecutable</key><string>FixTextApp</string>
        <key>CFBundlePackageType</key><string>APPL</string>
        <key>LSMinimumSystemVersion</key><string>13.0</string>
        <key>NSPrincipalClass</key><string>NSApplication</string>
    </dict>
    </plist>
    PLIST

    echo "Signing ad-hoc…"
    codesign --force --deep --sign - "$APP_DIR" >/dev/null || true

    echo "Done! Open $APP_DIR or drag it to Applications."
PLIST
