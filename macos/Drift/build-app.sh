#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Drift"
BUILD_DIR=".build/release"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

echo "Building $APP_NAME..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"

# Copy resources (compiled asset catalog etc.)
if [ -d "$BUILD_DIR/Drift_Drift.bundle" ]; then
    cp -R "$BUILD_DIR/Drift_Drift.bundle/" "$CONTENTS/Resources/"
fi

# Compile asset catalog
echo "Compiling assets..."
xcrun actool "$SCRIPT_DIR/Assets.xcassets" \
    --compile "$CONTENTS/Resources" \
    --output-format human-readable-text \
    --platform macosx \
    --minimum-deployment-target 14.0 2>/dev/null || echo "Warning: actool failed, assets may not load"

# Create icns from high-res PNGs
ICONSET="$CONTENTS/Resources/AppIcon.iconset"
mkdir -p "$ICONSET"
SRC="Assets.xcassets/AppIcon.appiconset"
if [ -f "$SRC/app-icon-1024.png" ]; then
    sips -z 16 16     "$SRC/app-icon-1024.png" --out "$ICONSET/icon_16x16.png" 2>/dev/null
    sips -z 32 32     "$SRC/app-icon-1024.png" --out "$ICONSET/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32     "$SRC/app-icon-1024.png" --out "$ICONSET/icon_32x32.png" 2>/dev/null
    sips -z 64 64     "$SRC/app-icon-1024.png" --out "$ICONSET/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128   "$SRC/app-icon-1024.png" --out "$ICONSET/icon_128x128.png" 2>/dev/null
    sips -z 256 256   "$SRC/app-icon-1024.png" --out "$ICONSET/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256   "$SRC/app-icon-1024.png" --out "$ICONSET/icon_256x256.png" 2>/dev/null
    sips -z 512 512   "$SRC/app-icon-1024.png" --out "$ICONSET/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512   "$SRC/app-icon-1024.png" --out "$ICONSET/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 "$SRC/app-icon-1024.png" --out "$ICONSET/icon_512x512@2x.png" 2>/dev/null
    iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns" 2>/dev/null || true
fi
rm -rf "$ICONSET"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Drift</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.drift.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Drift</string>
    <key>CFBundleDisplayName</key>
    <string>Drift</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppleScriptEnabled</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Drift needs permission to close blocked website tabs during focus sessions.</string>
</dict>
</plist>
PLIST

# Ad-hoc code sign for macOS Gatekeeper
echo "Signing app..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || echo "Warning: Code signing failed"

# Install to /Applications
echo "Installing to /Applications..."
rm -rf /Applications/$APP_NAME.app
cp -R "$APP_BUNDLE" /Applications/$APP_NAME.app

# Register with Launch Services
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/$APP_NAME.app 2>/dev/null || true

echo ""
echo "Done! App installed at /Applications/$APP_NAME.app"
echo "Run: open /Applications/$APP_NAME.app"
