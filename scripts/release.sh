#!/usr/bin/env bash
#
# release.sh — 버전 배포 자동화 + 문서/코드서명/유니버설 바이너리 검증 + GitHub Release & Homebrew Cask(version + sha256) 갱신.
#
# 사용:
#   ./scripts/release.sh --diff         # 직전 버전(v$(cat VERSION)) 대비 변경 내역 요약 (AI가 patch/minor 결정 시 사용)
#   ./scripts/release.sh patch          # 0.1.0 → 0.1.1 자동 계산
#   ./scripts/release.sh minor          # 0.1.0 → 0.2.0 자동 계산
#   ./scripts/release.sh 0.1.1          # 명시적 버전 지정
#   SCRIBE_NOTES_FILE=/tmp/notes.md ./scripts/release.sh patch
#   ./scripts/release.sh --check-only   # 버전 동기화 및 문서 일관성 검토만(배포 안 함)
#
# 단계: 1)test-gate 2)문서·버전 검토 3)코드서명 신원 게이트 4)VERSION 범프 5)universal build+zip+sha256
#       6)커밋·push 7)GitHub Release 8)Homebrew cask 갱신. 각 단계 실패 시 즉시 중단(set -e).
#
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="${SCRIBE_GITHUB_REPO:-sangeui/Scribe}"
TAP_REPO="${SCRIBE_TAP_REPO:-sangeui/homebrew-tap}"
CASK_PATH="Casks/scribe.rb"
VERSION_FILE="VERSION"

[[ -f "$VERSION_FILE" ]] || { echo "✗ $VERSION_FILE 파일이 없습니다."; exit 1; }
PREV="$(tr -d '[:space:]' < "$VERSION_FILE")"

doc_check() {
  local warn=0
  echo "▶ 문서 및 버전 일관성 검토"
  if grep -rnE "img.shields.io/badge/release-v[0-9]" README*.md 2>/dev/null; then
    echo "  ⚠ README 에 정적 버전 배지가 있습니다(동적 github/v/release 배지 권장)."; warn=1
  fi
  if grep -rnE "[0-9]+편의|[0-9]+ works|[0-9]+ classic|[0-9]+명의 문호|[0-9]+ literary|[0-9]+종의" README*.md 2>/dev/null; then
    echo "  ⚠ README 에 특정 수량(작품·작가·장신구 수 등) 표기가 남아 있습니다."; warn=1
  fi
  if [[ -f "$CASK_PATH" ]]; then
    local cask_ver
    cask_ver=$(grep -oE 'version "[0-9.]+"' "$CASK_PATH" | head -n1 | grep -oE '[0-9.]+')
    if [[ "$cask_ver" != "$PREV" ]]; then
      echo "  ⚠ VERSION($PREV) 과 $CASK_PATH($cask_ver) 의 버전이 다릅니다."; warn=1
    fi
  fi
  cat <<'CHECK'
  ─ 수동 체크리스트 (내용 변경 시 갱신) ─────────────────────────────
   [ ] README.md / README.en.md : 기능 목록·요구사항·특정 수량 미표기 원칙 준수
   [ ] homebrew-tap cask (Casks/scribe.rb): caveats·postflight 최신 상태인지
  ─────────────────────────────────────────────────────────────────
CHECK
  return $warn
}

if [[ "${1:-}" == "--check-only" ]]; then
  doc_check || exit 1
  echo "  ✓ 문서 및 버전 일관성 통과 (현재 버전: v$PREV)"
  exit 0
fi

if [[ "${1:-}" == "--diff" ]]; then
  echo "=== 직전 버전(v$PREV) 대비 변경 내역 ==="
  BASE_REF="v$PREV"
  if ! git rev-parse "$BASE_REF" >/dev/null 2>&1; then
    BASE_REF=$(git log -n 1 --grep="^release: v$PREV" --format="%H" || true)
  fi
  if [[ -n "$BASE_REF" ]]; then
    echo "▶ 기준 리비전: $BASE_REF (v$PREV)"
    echo "▶ 커밋 목록 ($BASE_REF..HEAD):"
    git log --oneline "$BASE_REF..HEAD" || true
    echo "▶ 변경 파일 통계 ($BASE_REF 대비 현재 작업 트리):"
    git diff --stat "$BASE_REF" || true
  else
    echo "▶ v$PREV 기준 태그/커밋을 찾지 못해 최근 10개 커밋과 작업 트리 상태를 표시합니다:"
    git log -n 10 --oneline
    git status -s
  fi
  exit 0
fi

TARGET="${1:?사용: release.sh <patch|minor|0.X.Y>  (현재: $PREV, 베타 단계)}"
IFS='.' read -r MAJ MIN PAT <<< "$PREV"
case "$TARGET" in
  patch) VERSION="$MAJ.$MIN.$((PAT + 1))" ;;
  minor) VERSION="$MAJ.$((MIN + 1)).0" ;;
  major)
    if [[ "${SCRIBE_ALLOW_MAJOR:-0}" != "1" ]]; then
      echo "✗ 현재 0.x.y 베타 단계이므로 major 버전 업그레이드는 보류되어 있습니다 (patch 또는 minor 사용)."
      echo "  정식 1.0.0 전환이 필요한 경우에만 SCRIBE_ALLOW_MAJOR=1 ./scripts/release.sh major 로 실행하세요."
      exit 1
    fi
    VERSION="$((MAJ + 1)).0.0"
    ;;
  *)     VERSION="$TARGET" ;;
esac

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "✗ 버전 형식 오류: $VERSION (0.X.Y 또는 patch/minor)"; exit 1; }
NEW_MAJ="${VERSION%%.*}"
if [[ "$NEW_MAJ" -ge 1 && "${SCRIBE_ALLOW_MAJOR:-0}" != "1" ]]; then
  echo "✗ 현재 0.x.y 베타 단계이므로 1.0.0 이상 버전($VERSION) 배포는 차단되어 있습니다."
  echo "  0.x.y 범위(patch 또는 minor)로 배포하세요."
  exit 1
fi
[[ "$VERSION" != "$PREV" ]] || { echo "✗ 새 버전($VERSION)이 현재 버전($PREV)과 같습니다. 기존 버전 재사용은 금지됩니다."; exit 1; }

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "✗ 로컬 Git 태그 v$VERSION 가 이미 존재합니다. 기존 태그를 덮어쓰지 마세요."
  exit 1
fi
if gh release view "v$VERSION" --repo "$REPO" >/dev/null 2>&1; then
  echo "✗ GitHub Release v$VERSION 가 이미 존재합니다. 새 버전 번호로 배포하세요."
  exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
[[ "$BRANCH" == "main" ]] || { echo "✗ main 브랜치에서 실행하세요 (현재: $BRANCH) — 커밋/push 대상 일치 보장"; exit 1; }
echo "=== Scribe 릴리스 v$PREV → v$VERSION ==="

echo "▶ 1/7 릴리스 전 테스트 게이트 (--selftest)"
./scripts/test-gate.sh >/dev/null || { echo "✗ test-gate 실패 — 중단"; exit 1; }
echo "  ✓ 통과"

doc_rc=0; doc_check || doc_rc=$?
if [[ $doc_rc -ne 0 ]]; then
  read -r -p "  문서 경고가 있습니다. 그래도 계속? [y/N] " a
  [[ "$a" == "y" || "$a" == "Y" ]] || { echo "중단 — 문서 먼저 갱신하세요."; exit 1; }
fi

echo "▶ 2/7 코드서명 신원 게이트 (배포 전 — ad-hoc 릴리스 차단으로 사용자 Keychain/알림 '항상 허용' 유지)"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-Scribe Local}"
EXPECTED_LEAF="${SCRIBE_EXPECTED_LEAF:-}"
LEAF=$(security find-identity -v -p codesigning 2>/dev/null | awk -v id="\"$SIGN_IDENTITY\"" '$0 ~ id {print $2; exit}')
if [[ -z "$LEAF" ]]; then
  echo "✗ 유효 codesigning identity '$SIGN_IDENTITY' 없음(미설치·만료 포함)."
  echo "  이대로면 build-app.sh 가 ad-hoc 서명 → 이 릴리스로 올린 사용자 전원이 권한을 재승인해야 합니다."
  echo "  복구: ./scripts/create-signing-cert.sh 실행 후 다시 시도하세요."
  exit 1
fi
if [[ -n "$EXPECTED_LEAF" && "$LEAF" != "$EXPECTED_LEAF" ]]; then
  echo "⚠ 서명 인증서 leaf 불일치: 현재 $LEAF ≠ 고정 $EXPECTED_LEAF"
  read -r -p "  의도한 변경이면 계속? [y/N] " a
  [[ "$a" == "y" || "$a" == "Y" ]] || { echo "중단 — 서명 신원을 확인하세요."; exit 1; }
fi
echo "  ✓ '$SIGN_IDENTITY' leaf=$LEAF — 안정적 서명으로 배포"
export SCRIBE_REQUIRE_STABLE_SIGN=1

echo "▶ 3/7 VERSION 범프 $PREV → $VERSION (아직 미커밋)"
printf '%s\n' "$VERSION" > "$VERSION_FILE"

echo "▶ 4/7 Universal 빌드 + zip + SHA-256 갱신 (push 전 검증 — 실패해도 범프 미커밋이라 origin/main 무손상)"
SCRIBE_NATIVE_ARCH_ONLY=0 ./scripts/build-app.sh >/dev/null
rm -f build/Scribe.zip
ditto -c -k --keepParent build/Scribe.app build/Scribe.zip
BUILT=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Scribe.app/Contents/Info.plist)
[[ "$BUILT" == "$VERSION" ]] || { echo "✗ 빌드 버전 불일치: $BUILT (수동 복구: git checkout VERSION Casks/scribe.rb)"; exit 1; }
BUILT_ARCHS="$(lipo -archs build/Scribe.app/Contents/MacOS/Scribe)"
[[ " $BUILT_ARCHS " == *" arm64 "* && " $BUILT_ARCHS " == *" x86_64 "* ]] \
  || { echo "✗ universal 바이너리 아님: $BUILT_ARCHS (arm64 + x86_64 필요)"; exit 1; }
ZIP_SHA256="$(shasum -a 256 build/Scribe.zip | awk '{print $1}')"
if [[ -f "$CASK_PATH" ]]; then
  perl -pi -e "s/version \"[0-9.]+\"/version \"$VERSION\"/" "$CASK_PATH"
  perl -pi -e "s/sha256 \"[0-9a-fA-F]+\"/sha256 \"$ZIP_SHA256\"/" "$CASK_PATH"
fi
echo "  ✓ build/Scribe.zip 생성 완료 (universal: arm64 + x86_64, sha256: $ZIP_SHA256)"

echo "▶ 5/7 커밋 + push (빌드 성공 후)"
git add "$VERSION_FILE"
if [[ -f "$CASK_PATH" ]]; then git add "$CASK_PATH"; fi
if ! git diff --cached --quiet; then
  git commit -q -m "release: v$VERSION"
fi
git push -q origin main

echo "▶ 6/7 GitHub Release v$VERSION"
if [[ -n "${SCRIBE_NOTES_FILE:-}" && -f "${SCRIBE_NOTES_FILE}" ]]; then
  gh release create "v$VERSION" build/Scribe.zip --repo "$REPO" \
    --title "Scribe v$VERSION" --target main --notes-file "$SCRIBE_NOTES_FILE"
else
  gh release create "v$VERSION" build/Scribe.zip --repo "$REPO" \
    --title "Scribe v$VERSION" --target main --generate-notes
fi

echo "▶ 7/7 Homebrew cask $VERSION ($TAP_REPO)"
if gh api "repos/$TAP_REPO/contents/$CASK_PATH" >/dev/null 2>&1; then
  TMP_CASK=$(mktemp)
  gh api "repos/$TAP_REPO/contents/$CASK_PATH" --jq '.content' | base64 -d \
    | perl -pe "s/version \"[0-9.]+\"/version \"$VERSION\"/; s/sha256 \"[0-9a-fA-F]+\"/sha256 \"$ZIP_SHA256\"/" > "$TMP_CASK"
  SHA=$(gh api "repos/$TAP_REPO/contents/$CASK_PATH" --jq '.sha')
  gh api -X PUT "repos/$TAP_REPO/contents/$CASK_PATH" \
    -f message="cask: scribe $VERSION" \
    -f content="$(base64 -i "$TMP_CASK")" -f sha="$SHA" --jq '.commit.html_url'
  rm -f "$TMP_CASK"
else
  echo "  (참고: $TAP_REPO 에 $CASK_PATH 가 아직 없어 원격 cask 자동 갱신은 건너뜁니다.)"
fi

echo "✓ v$VERSION 배포 완료."
