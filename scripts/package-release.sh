#!/bin/bash
# Scribe.app 을 빌드·검증(--selftest)하고 배포용 ZIP 및 DMG 아카이브를 dist/ 에 생성한다.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
APP="build/Scribe.app"
DIST="dist"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
    VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" ./scripts/build-app.sh
fi

echo "==> Running selftest..."
"$APP/Contents/MacOS/Scribe" --selftest > /dev/null
echo "==> Selftest passed."

rm -rf "$DIST"
mkdir -p "$DIST"

ZIP_PATH="$DIST/Scribe-${VERSION}-macos.zip"
DMG_PATH="$DIST/Scribe-${VERSION}.dmg"

echo "==> Creating ZIP archive: $ZIP_PATH"
xattr -cr "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP_PATH"

if command -v hdiutil >/dev/null 2>&1; then
    STAGE="$DIST/dmg-root"
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/Scribe.app"
    ln -s /Applications "$STAGE/Applications"
    xattr -cr "$STAGE"
    echo "==> Creating DMG image: $DMG_PATH"
    if hdiutil create -volname "Scribe" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null 2>&1; then
        echo "==> Created DMG: $DMG_PATH"
    else
        echo "warning: hdiutil could not create DMG in this environment; ZIP archive is ready."
    fi
    rm -rf "$STAGE"
fi

(
    cd "$DIST"
    shasum -a 256 Scribe-* > SHA256SUMS.txt
)

echo "==> Release artifacts in $DIST/:"
ls -lh "$DIST"
cat "$DIST/SHA256SUMS.txt"
