# 버전 정책 및 릴리스 가이드 (Release & Versioning Policy)

이 문서는 `Scribe` 프로젝트의 버전 관리 기준, 단일 버전 원본(Single Source of Truth), 배포 파이프라인을 정의한다. 사람과 모든 AI 코딩 에이전트(Antigravity, Gemini CLI, Claude Code, Cursor, Codex 등)는 버전을 올리거나 배포할 때 반드시 이 문서를 따른다.

---

## 1. 버전 번호 체계 (0.x.y 베타 단계 SemVer) 및 AI 자율 판정 규칙

현재 프로젝트는 **`0.x.y` 베타 단계**이므로, 정식 출시 전까지 메이저 버전(`1.0.0` 이상)은 올리지 않고 **`0.x.y` 범위 내에서 `patch`와 `minor`만 사용한다.**

### AI의 버전 결정 의무 (Diff 기반 자율 판정)
사용자가 배포(릴리스)를 요청할 때 버전 번호를 명시하지 않더라도, **AI 에이전트는 사용자에게 어떤 버전으로 올릴지 되묻지 않고 직전 릴리스(`v$(cat VERSION)`)와 현재 코드의 변경 내역을 직접 비교해 `patch` 또는 `minor`를 스스로 결정한다.**

1. **직전 버전 대비 변경 사항 조회**:
   ```bash
   ./scripts/release.sh --diff
   ```
   (내부적으로 `v$(cat VERSION)..HEAD` 커밋 로그와 작업 트리의 `git diff --stat`을 출력함)
2. **`minor` vs `patch` 판정 기준**:
   - **`minor` (`0.x.0`)로 올리는 경우**:
     - 사용자에게 보이는 **새로운 기능** 추가 (예: 상시 창 해·달 천문 궤적 표시, 신규 패널/뷰, 새 에이전트 로그 파서 지원)
     - **새로운 콘텐츠** 추가 (새 문학 작품, 작가, 장신구, 돌발 상황, 서점 이벤트, 업적 등)
     - 설정 항목 추가 또는 기존 시스템의 의미 있는 기능 확장
   - **`patch` (`0.1.x`)로 올리는 경우**:
     - 버그 수정 (예: '접기' 미동작 버그 수정, 스크립트 해시 갱신 오류 수정)
     - UI·애니메이션 보정 (예: `Collapsible` 서랍 애니메이션 개선), 레이아웃·색상 미세 조정
     - 문구·오타 수정, README/가이드 문서 개선, 내부 리팩터링, 테스트 보강
   - **복합 변경 시 우선순위**:
     - 직전 버전 이후 변경 내역에 `minor` 요건(신규 기능/콘텐츠)과 `patch` 요건(버그 수정/UI 보정)이 함께 포함되어 있으면 상위 단위인 **`minor`**를 선택한다.

| 구분 | 올리는 기준 (`./scripts/release.sh <구분>`) | 예시 |
| :--- | :--- | :--- |
| **`patch`** (`0.1.x`) | 버그 수정, 애니메이션·레이아웃 보정, 문구 수정, 내부 리팩터링, 소규모 밸런스 조정 | `0.1.0` → `0.1.1` |
| **`minor`** (`0.x.0`) | 신규 기능 추가(새 화면·천문 표시·새 에이전트 로그 지원·새 문학 작품 추가) 또는 베타 기간 중 주요 구조 변경 | `0.1.1` → `0.2.0` |
| **`major`** (`1.0.0`) | **현재 보류 (베타 단계 동안 사용 금지)**. [`scripts/release.sh`](scripts/release.sh)가 기본적으로 `1.0.0` 이상 범프를 차단함 | 보류 (`SCRIBE_ALLOW_MAJOR=1` 필요) |

### 버전 운영 핵심 원칙
1. **단일 버전 원본 (`VERSION`)**:
   - 현재 버전은 저장소 루트의 [`VERSION`](VERSION) 파일 한 곳에서만 정의한다.
   - [`scripts/build-app.sh`](scripts/build-app.sh)는 빌드 시 `VERSION` 파일을 읽어 `Scribe.app/Contents/Info.plist`(`CFBundleShortVersionString`, `CFBundleVersion`)에 주입한다.
   - [`Casks/scribe.rb`](Casks/scribe.rb)의 `version` 및 `sha256`은 배포 시 [`scripts/release.sh`](scripts/release.sh)가 자동으로 갱신한다. 수동으로 따로 수정하지 않는다.
2. **불변 릴리스 원칙 (기존 태그 덮어쓰기 금지)**:
   - 한 번 배포된 버전 태그(`vX.Y.Z`)와 GitHub Release 아티팩트는 **절대 삭제 후 재생성하거나 덮어쓰지 않는다.**
   - Homebrew Cask는 버전별 고정 URL과 `sha256` 해시를 검증하므로, 같은 버전 태그에 다른 `Scribe.zip`을 재업로드하면 기존 사용자의 `brew install` / `brew upgrade`가 해시 불일치로 깨진다.
   - 배포 직후 수정 사항이 생기면 반드시 `patch` 버전을 하나 올려 새 릴리스로 배포한다.
3. **일상 커밋과 릴리스의 분리**:
   - 일반 코드 수정·문서 업데이트 커밋마다 버전을 올리지 않는다.
   - 사용자가 명시적으로 배포(릴리스)를 요청했을 때만 `./scripts/release.sh`를 실행해 버전을 올린다.
4. **문서 내 가변 숫자 표기 금지**:
   - `README.md`, `README.en.md`, GitHub About 설명, 스크린샷 배너 등에 **작품 수, 작가 수, 장신구 수, 돌발 상황 수 등 향후 바뀔 수 있는 특정 수량을 하드코딩하지 않는다.** (`./scripts/release.sh --check-only`가 이를 검사한다.)

---

## 2. 최초 1회: 로컬 자체서명 인증서 생성

배포자 Mac의 로그인 키체인에 `Scribe Local` 코드서명 인증서를 1회 생성한다(개인키는 키체인에만 보관되며 저장소에 커밋되지 않는다):

```bash
./scripts/create-signing-cert.sh
```

- `Designated Requirement`가 버전 간 고정되어 사용자의 Keychain·알림 "항상 허용" 권한이 앱 업데이트 후에도 유지된다.
- 인증서를 분실·재생성하면 서명 신원이 바뀌므로 재생성하지 않는다(스크립트가 중복 생성을 차단함).

---

## 3. 한 줄 배포 (`scripts/release.sh`)

```bash
# 자동 증분 배포 (베타 단계: patch 또는 minor 만 사용)
./scripts/release.sh patch    # 예: 0.1.0 → 0.1.1
./scripts/release.sh minor    # 예: 0.1.0 → 0.2.0

# 또는 명시적 버전 지정 (0.x.y 범위)
./scripts/release.sh 0.1.1

# 배포 없이 버전 동기화 및 문서 일관성만 검사할 때
./scripts/release.sh --check-only
```

`scripts/release.sh`가 순서대로 수행하는 7단계(중간 실패 시 즉시 중단):

1. **사전 검증**: `main` 브랜치 여부, 새 버전 유효성, 기존 Git 태그(`vX.Y.Z`) 및 GitHub Release 중복 여부 확인.
2. **테스트 게이트 (`./scripts/test-gate.sh`)**: 릴리스 빌드 및 `Scribe --selftest` 전 항목 통과 검증.
3. **문서·버전 일관성 검토 (`doc_check`)**: 정적 버전 배지 여부, 특정 수량 하드코딩 여부, `VERSION`과 `Casks/scribe.rb` 동기화 확인.
4. **코드서명 신원 게이트**: 키체인에 유효한 `Scribe Local` 인증서가 있는지 확인(`ad-hoc` 서명 상태 배포 원천 차단).
5. **Universal 빌드 + ZIP + SHA-256 갱신**:
   - `VERSION` 파일 갱신 후 `arm64` + `x86_64` Universal 바이너리로 `build/Scribe.app`을 조립하고 `build/Scribe.zip`으로 압축.
   - `build/Scribe.zip`의 새 `sha256` 해시를 계산해 `Casks/scribe.rb`의 `version` 및 `sha256`을 함께 갱신.
6. **커밋 + 푸시**: `VERSION`과 `Casks/scribe.rb`를 `release: v<version>` 커밋으로 묶어 `origin/main`에 푸시.
7. **GitHub Release & Homebrew Tap 자동 갱신**:
   - `gh release create v<version> build/Scribe.zip` 실행.
   - 원격 `sangeui/homebrew-tap` 저장소의 `Casks/scribe.rb`(`version` + `sha256`)를 GitHub API로 자동 커밋.

---

## 4. Homebrew Tap 설치 안내

사용자는 아래 명령으로 격리(`com.apple.quarantine`) 경고 없이 설치 및 업데이트할 수 있다:

```bash
# 최초 설치
brew tap sangeui/scribe https://github.com/sangeui/Scribe
brew install --cask sangeui/scribe/scribe

# 새 버전 업데이트
brew update && brew upgrade --cask sangeui/scribe/scribe
```
