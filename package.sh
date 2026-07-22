#!/bin/bash
# Builds Wordplay.app — a real, double-clickable macOS application bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Wordplay"          # bundle / display name
EXEC_NAME="Anagrammer"        # SPM product (binary) name
BUNDLE_ID="org.abstreet.wordplay"
VERSION="6.5.0"
BUILD_DIR=".build/release"
APP="dist/${APP_NAME}.app"
CONTENTS="${APP}/Contents"

echo "==> Building release binary…"
swift build -c release

echo "==> Generating app icon…"
swift Resources/make_icon.swift "/tmp/AppIcon.icns" >/dev/null

echo "==> Assembling bundle at ${APP}…"
rm -rf "${APP}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"

cp "${BUILD_DIR}/${EXEC_NAME}" "${CONTENTS}/MacOS/${EXEC_NAME}"
cp "/tmp/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"

# Bundle the SPM resource bundle (contains cmudict.dict) so Bundle.module
# resolves at runtime inside the .app. It lives beside the release binary.
if [ -d "${BUILD_DIR}/${EXEC_NAME}_${EXEC_NAME}.bundle" ]; then
    cp -R "${BUILD_DIR}/${EXEC_NAME}_${EXEC_NAME}.bundle" "${CONTENTS}/Resources/"
fi
# Belt-and-suspenders: also place data files directly in Resources so the
# Bundle.main fallback resolves even if Bundle.module can't locate the bundle.
cp "Sources/${EXEC_NAME}/Resources/cmudict.dict" "${CONTENTS}/Resources/cmudict.dict"
cp "Sources/${EXEC_NAME}/Resources/enable.txt" "${CONTENTS}/Resources/enable.txt"

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>         <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleExecutable</key>      <string>${EXEC_NAME}</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>LSApplicationCategoryType</key> <string>public.app-category.productivity</string>
</dict>
</plist>
PLIST

echo "==> Code signing (ad-hoc)…"
codesign --force --deep --sign - "${APP}"

echo "==> Done: ${APP}"
echo "    Launch with:  open \"${APP}\""
