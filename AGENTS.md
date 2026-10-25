# AI 에이전트 공통 가이드 (AGENTS.md)

이 문서는 **Antigravity, Gemini CLI, Claude Code, Cursor, GitHub Copilot, OpenAI Codex** 등 이 저장소에서 작업하는 모든 AI 에이전트가 동일하게 준수해야 하는 프로젝트 표준 규칙이다.

---

## 1. 프로젝트 개요 및 빌드·검증

- **언어 및 환경**: Swift 6.0, macOS 14.0+ (`AppKit` + `SwiftUI`), 외부 패키지 의존성 없음 (`Package.swift`).
- **필수 검증 게이트**: 코드를 수정한 뒤에는 커밋·배포 전에 반드시 아래 셀프 테스트 스크립트를 실행해 `PASS`를 확인해야 한다.
  ```bash
  ./scripts/test-gate.sh
  ```
- **수정 완료 후 즉시 앱 재실행 (필수)**:
  - 앱 코드(`Sources/Scribe/**`) 수정을 마치고 `./scripts/test-gate.sh` 통과를 확인한 직후에는, 사용자가 별도로 요청하지 않아도 즉시 `Scribe Local` 서명 적용 및 `/Applications/Scribe.app` 교체·재실행을 수행해 화면에서 바로 확인할 수 있게 한다.
  ```bash
  codesign --force -s "Scribe Local" build/Scribe.app 2>/dev/null || true
  pkill -x Scribe 2>/dev/null || true
  rm -rf /Applications/Scribe.app && cp -R build/Scribe.app /Applications/ && open /Applications/Scribe.app
  ```
- **로컬 개발 빌드**:
  ```bash
  # 현재 아키텍처만 빠르게 빌드하고 /Applications/Scribe.app 설치·재실행까지 한 번에 수행할 때
  SCRIBE_NATIVE_ARCH_ONLY=1 SCRIBE_INSTALL_APPLICATIONS=1 ./scripts/build-app.sh
  ```

---

## 2. 버전 관리 및 릴리스 정책 (필수 준수)

상세 절차는 [`RELEASE.md`](RELEASE.md)에 정의되어 있으며, 모든 AI 에이전트는 다음 규칙을 엄격히 따른다:

1. **단일 버전 원본 (`VERSION`)**:
   - 현재 버전은 루트의 [`VERSION`](VERSION) 파일이 유일한 기준(Single Source of Truth)이다.
   - `scripts/build-app.sh`나 `Casks/scribe.rb`의 버전 문자열을 수동으로 따로 편집하지 않는다.
2. **SemVer (`0.MINOR.PATCH` 베타 단계) 및 AI 자율 판정 규칙**:
   - **메이저 버전(`1.0.0` 이상) 보류**: 현재 베타 버전이므로 메이저 버전은 올리지 않으며, `0.x.y` 범위 내에서 `patch`와 `minor`만 사용한다 (`scripts/release.sh`에서도 `major` 및 `1.x.x` 이상을 기본 차단함).
   - **AI의 직전 버전 비교 및 자율 결정 의무**:
     - 사용자가 배포를 요청할 때 버전 번호를 지정하지 않으면, AI는 `./scripts/release.sh --diff`를 실행해 **직전 버전(`v$(cat VERSION)`) 이후의 모든 커밋과 미커밋 변경 사항을 직접 비교·분석하여 `patch` 또는 `minor`를 스스로 결정**한다.
     - 신규 기능(예: 해·달 천문 표시, 새 화면, 새 데이터 소스)이나 신규 콘텐츠(작품·작가·장신구·이벤트·업적)가 하나라도 포함되어 있으면 **`minor`(`0.x.0`)**, 버그 수정·애니메이션 개선·문구/문서 수정·리팩터링만 있으면 **`patch`(`0.1.x`)**로 결정한다.
3. **기존 버전 태그 재사용·덮어쓰기 절대 금지**:
   - 이미 배포된 `vX.Y.Z` 태그나 GitHub Release를 삭제 후 재생성하거나 `Scribe.zip`을 덮어쓰지 않는다 (Homebrew Cask의 `sha256` 무결성이 깨짐).
   - 배포 후 추가 수정이 필요하면 반드시 다음 버전(`patch` 등)으로 올려 배포한다.
4. **배포 실행 방법 (한국어 릴리스 노트 포함 필수)**:
   - 사용자가 배포(릴리스)를 요청한 경우에만 `main` 브랜치에서 변경분을 커밋한 뒤, 직전 버전 대비 주요 변경 사항을 사용자 친화적인 한국어 마크다운 노트(`SCRIBE_NOTES_FILE`)로 작성하여 아래 스크립트를 실행한다:
     ```bash
     ./scripts/release.sh --diff  # 1) 직전 버전과 비교해 patch / minor 판정
     SCRIBE_NOTES_FILE=/tmp/scribe-notes.md ./scripts/release.sh minor  # 2) 한국어 릴리스 노트와 함께 배포 실행
     ```
   - 이 스크립트가 `--selftest` 검증, 코드서명(`Scribe Local`) 확인, `VERSION` 범프, Universal(`arm64` + `x86_64`) 빌드, `Casks/scribe.rb`의 `version` + `sha256` 갱신, 한국어 노트가 포함된 GitHub Release 생성, `sangeui/homebrew-tap` 원격 Cask 업데이트를 한 번에 처리한다.

---

## 3. 문서 및 UI 작성 원칙

1. **가변 수량 하드코딩 금지**:
   - `README.md`, `README.en.md`, GitHub 저장소 설명(About), 홍보 이미지 등에 **작품 수, 문호 수, 장신구 수, 업적 수 등 향후 변경될 수 있는 특정 숫자를 적지 않는다.**
   - 코드 내에서는 항상 `Library.books.count`, `Library.authors.count`, `Decor.all.count` 등 동적 속성을 사용한다.
2. **자연스러운 접기/펼치기 애니메이션**:
   - 화면 내 아코디언/서랍 요소를 펼치거나 접을 때는 단순 `.opacity` 페이드인·아웃 대신 [`Collapsible`](Sources/Scribe/Views/WritingView.swift) 컨테이너를 사용해 높이가 연속적으로 보간되도록 구현한다.
3. **소스 디렉토리 구조 (`Sources/Scribe/`)**:
   - 단일 파일이 과도하게 비대해져 에이전트 탐색 성능을 떨어뜨리지 않도록 다음 7개 하위 폴더 구조를 유지한다:
     - `App/`: 앱 진입점(`App.swift`), 자동 업데이터(`Updater.swift`), 알림(`Notifier.swift`), 조사·숫자 포맷(`Format.swift`)
     - `Telemetry/`: 에이전트 로그 파서(`ClaudeLogScanner.swift`), 한도 조회(`ClaudeLimits.swift`), 단가(`Pricing.swift`), 집계 모델·스토어(`UsageModels.swift`, `UsageStore.swift`)
     - `Simulation/`: 원문 서재(`Library.swift`), 집필 상태·진행도(`WritingState.swift`), 집필 엔진(`WritingStore.swift`), 돌발 상황·대사·기분·능력치·마감·사건·서점·비평·독자·업적·날씨
     - `World/`: 픽셀 마을 도트(`VillageSprites.swift`), 마을 상태·경로(`VillageModel.swift`), 마을 뷰(`VillageView.swift`), 마을 대화(`VillageTalk.swift`), 문학 살롱(`Salon.swift`), 작업실 가구(`Studio.swift`)
     - `Art/`: 픽셀 렌더러(`Pixels.swift`), 문호 초상화(`Portraits.swift`, `PortraitArt.swift`, `LivePortrait.swift`), 장신구(`Decor.swift`)
     - `Views/`: 팝오버(`PopoverView.swift`), 바탕화면 상시 창(`FloatingWindow.swift`), 옆 패널(`SidePanel.swift`), 집필 카드(`WritingView.swift`), 서재(`ShelfView.swift`), 가방(`BagView.swift`), 서점(`BookstoreView.swift`), 토큰 대시보드(`UsageDashboard.swift`), 설정(`SettingsView.swift`), 힌트(`Hint.swift`)
     - `Testing/`: 셀프 테스트(`Selftest.swift`), 스냅샷·투어 이미지 렌더러(`SnapshotRenderer.swift`)
4. **문서 일관성 확인**:
   - 문서나 버전을 건드린 뒤에는 `./scripts/release.sh --check-only`를 실행해 경고가 없는지 확인한다.
