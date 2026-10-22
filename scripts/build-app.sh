#!/bin/bash
# 릴리스 빌드를 Scribe.app 으로 묶고 서명한다.
# 환경변수:
#   VERSION (기본: 0.1.0)
#   BUILD_NUMBER (기본: 1)
#   SIGN_IDENTITY (기본: - [ad-hoc 서명])
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

swift build -c release

APP="build/Scribe.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Scribe" "$APP/Contents/MacOS/Scribe"

mkdir -p "$APP/Contents/Resources"
if [ ! -f build/AppIcon.icns ]; then
    swift scripts/generate-icon.swift build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# 집필 모드 원문(Project Gutenberg 퍼블릭 도메인 텍스트). zlib 로 압축해 넣고 앱이 읽을 때 푼다.
if [ ! -f build/Books/manifest.json ]; then
    swift scripts/pack-books.swift Books build/Books
fi
cp -R build/Books "$APP/Contents/Resources/Books"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Scribe</string>
    <key>CFBundleDisplayName</key><string>Scribe</string>
    <key>CFBundleIdentifier</key><string>local.scribe</string>
    <key>CFBundleExecutable</key><string>Scribe</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

xattr -cr "$APP"
if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --deep --sign - "$APP"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
echo "built: $APP (v${VERSION}, build ${BUILD_NUMBER})"
