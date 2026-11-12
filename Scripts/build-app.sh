#!/bin/bash
# Builds build/JayceMouse.app from the SwiftPM executable.
# Set UNIVERSAL=1 for an arm64 + x86_64 binary.
# Set SIGN_IDENTITY to a stable code-signing identity so the Accessibility
# permission survives rebuilds (create a self-signed "Code Signing" certificate
# in Keychain Access and pass its name). Set SIGN_KEYCHAIN to sign from a specific keychain file.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${CONFIG:-release}"
APP="build/JayceMouse.app"
IDENTITY="${SIGN_IDENTITY:--}"
VERSION="${VERSION:-1.0.0}"

# SwiftPM's multi-arch mode needs Xcode, so build each slice separately and join them with lipo.
if [ "${UNIVERSAL:-0}" = "1" ]; then
    SLICES=()
    for arch in arm64 x86_64; do
        swift build -c "$CONFIG" --triple "$arch-apple-macosx"
        SLICES+=("$(swift build -c "$CONFIG" --triple "$arch-apple-macosx" --show-bin-path)/JayceMouse")
    done
    BIN="$(mktemp -d)/JayceMouse"
    lipo -create "${SLICES[@]}" -output "$BIN"
else
    swift build -c "$CONFIG"
    BIN="$(swift build -c "$CONFIG" --show-bin-path)/JayceMouse"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/JayceMouse"

ICONSET="$(mktemp -d)/AppIcon.iconset"
swift Scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>JayceMouse</string>
    <key>CFBundleDisplayName</key><string>JayceMouse</string>
    <key>CFBundleIdentifier</key><string>app.jaycemouse.JayceMouse</string>
    <key>CFBundleExecutable</key><string>JayceMouse</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key><string>JayceMouse reads the battery level of your Bluetooth mouse and keyboard to show it in the menu bar.</string>
</dict>
</plist>
EOF

KEYCHAIN_ARGS=()
if [ -n "${SIGN_KEYCHAIN:-}" ]; then KEYCHAIN_ARGS=(--keychain "$SIGN_KEYCHAIN"); fi
# Hardened runtime blocks DYLD_INSERT_LIBRARIES, so injected code can't borrow the Accessibility grant.
# Debug bundles skip it so lldb can still attach.
RUNTIME_ARGS=()
if [ "$CONFIG" = "release" ]; then RUNTIME_ARGS=(--options runtime); fi
codesign --force ${RUNTIME_ARGS[@]+"${RUNTIME_ARGS[@]}"} --sign "$IDENTITY" ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} --identifier app.jaycemouse.JayceMouse "$APP"
echo "Built $APP (signed with: ${IDENTITY/-/ad-hoc})"
