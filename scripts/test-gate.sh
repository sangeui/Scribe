#!/usr/bin/env bash
# 빌드 + --selftest 전체 검증 게이트 (CI 및 release.sh 에서 호출)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Building Scribe (release, native arch)..."
SCRIBE_NATIVE_ARCH_ONLY=1 SCRIBE_INSTALL_APPLICATIONS=0 ./scripts/build-app.sh

echo "==> Running Scribe --selftest..."
./build/Scribe.app/Contents/MacOS/Scribe --selftest
echo "==> All selftests passed."
