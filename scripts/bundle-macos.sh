#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "QR Pocket can only be built on macOS." >&2
    exit 1
fi

cargo build --release
NATIVE="$(cargo run --quiet --release -- --native-path)"
APP="$ROOT/dist/QR Pocket.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$NATIVE" "$APP/Contents/MacOS/QR Pocket"
chmod +x "$APP/Contents/MacOS/QR Pocket"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>QR Pocket</string>
    <key>CFBundleDisplayName</key><string>QR Pocket</string>
    <key>CFBundleIdentifier</key><string>com.qrpocket.manager</string>
    <key>CFBundleExecutable</key><string>QR Pocket</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
plutil -lint "$APP/Contents/Info.plist"
echo "Built: $APP"
echo "Open it with: open \"$APP\""
