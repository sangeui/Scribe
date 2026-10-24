#!/bin/bash
# Scribe.app 번들 조립 (Universal arm64 + x86_64, strip, 자체서명 인증서 또는 ad-hoc 서명)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
APP_NAME="Scribe"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

# Apple Silicon + Intel 지원을 위해 배포 바이너리는 universal(arm64 + x86_64)로 만든다.
# 로컬 개발에서 빌드 시간을 줄이려면 SCRIBE_NATIVE_ARCH_ONLY=1.
ARCHS=(arm64 x86_64)
if [[ "${SCRIBE_NATIVE_ARCH_ONLY:-0}" == "1" ]]; then
    if [[ "${SCRIBE_REQUIRE_STABLE_SIGN:-0}" == "1" ]]; then
        echo "   ✗ 릴리스 빌드는 SCRIBE_NATIVE_ARCH_ONLY 를 쓸 수 없습니다 (universal 필수)." >&2
        exit 1
    fi
    ARCHS=("$(uname -m)")
fi

mkdir -p "$BUILD_DIR"
SLICES=()
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/clang-module-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/tmp/swift-module-cache}"
EXTRA_FLAGS=(--disable-sandbox -Xswiftc -module-cache-path -Xswiftc "$SWIFTPM_MODULECACHE_OVERRIDE" -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE_PATH")
for arch in "${ARCHS[@]}"; do
    echo "==> swift build -c release --arch $arch"
    swift build -c release --arch "$arch" "${EXTRA_FLAGS[@]}"
    BIN_PATH="$(swift build -c release --arch "$arch" "${EXTRA_FLAGS[@]}" --show-bin-path)/$APP_NAME"
    SLICE_PATH="$BUILD_DIR/$APP_NAME-$arch"
    cp "$BIN_PATH" "$SLICE_PATH"
    SLICES+=("$SLICE_PATH")
done

echo "==> $APP 조립"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/$APP_NAME"
rm -f "${SLICES[@]}"
BUILT_ARCHS="$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"
for arch in "${ARCHS[@]}"; do
    [[ " $BUILT_ARCHS " == *" $arch "* ]] || { echo "   ✗ 아키텍처 누락: $arch (현재: $BUILT_ARCHS)" >&2; exit 1; }
done
echo "   archs: $BUILT_ARCHS"

# 심볼 strip — codesign 전에 수행(서명 무효화 방지).
strip -rSTx "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null || strip -rSx "$APP/Contents/MacOS/$APP_NAME"

if [ ! -f "$BUILD_DIR/AppIcon.icns" ]; then
    swift scripts/generate-icon.swift "$BUILD_DIR/AppIcon.icns"
fi
cp "$BUILD_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# 집필 모드 원문(Project Gutenberg 퍼블릭 도메인 텍스트). zlib 로 압축해 넣고 앱이 읽을 때 푼다.
if [ ! -f "$BUILD_DIR/Books/manifest.json" ]; then
    swift scripts/pack-books.swift Books "$BUILD_DIR/Books"
fi
cp -R "$BUILD_DIR/Books" "$APP/Contents/Resources/Books"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>local.scribe</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

mkdir -p "$APP/Contents/Library/LaunchAgents"
cat > "$APP/Contents/Library/LaunchAgents/local.scribe.login.plist" <<AGENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>local.scribe.login</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/$APP_NAME.app/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key><false/>
    </dict>
    <key>ThrottleInterval</key><integer>10</integer>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
    <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
AGENT

xattr -cr "$APP"

echo "==> codesign"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-Scribe Local}"
if security find-identity -v -p codesigning 2>/dev/null | grep -F "\"$SIGN_IDENTITY\"" >/dev/null; then
    # 안정적 자체 서명 신원 → 재빌드해도 Keychain/알림 "항상 허용" 유지
    codesign --force -s "$SIGN_IDENTITY" "$APP"
else
    if [[ "${SCRIBE_REQUIRE_STABLE_SIGN:-0}" == "1" ]]; then
        echo "   ✗ SCRIBE_REQUIRE_STABLE_SIGN=1 인데 '$SIGN_IDENTITY' 유효 identity 없음 → ad-hoc 금지, 중단." >&2
        echo "     ./scripts/create-signing-cert.sh 실행 후 다시 시도하세요." >&2
        exit 1
    fi
    echo "   ('$SIGN_IDENTITY' 유효 codesigning identity 없음 → ad-hoc 서명 — 로컬 개발용)"
    echo "   안정적 서명을 쓰려면 ./scripts/create-signing-cert.sh 실행 후 다시 빌드하세요."
    codesign --force -s - "$APP"
fi

if [[ "${SCRIBE_INSTALL_APPLICATIONS:-0}" == "1" ]]; then
    echo "==> 기존 인스턴스 종료 + /Applications 설치 및 재실행"
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    open "/Applications/$APP_NAME.app"
    echo "완료: /Applications/$APP_NAME.app 재실행됨 (v$VERSION)"
else
    echo "완료: $APP (v$VERSION)"
fi
