# 릴리스 프로세스

`PokeTokenBar` 와 동일한 방식으로 **고정 자체서명 인증서(`Scribe Local`) + Universal(`arm64` + `x86_64`) 바이너리 + GitHub Release(`Scribe.zip`) + Homebrew Cask(`postflight` 로 격리 속성 자동 제거)** 파이프라인을 사용한다.

## 1. 최초 1회: 로컬 자체서명 인증서 생성

배포자 Mac의 로그인 키체인에 `Scribe Local` 코드서명 인증서를 1회 생성한다(개인키는 키체인에만 보관되며 저장소에 커밋되지 않는다):

```bash
./scripts/create-signing-cert.sh
```

- `Designated Requirement` 가 버전 간 고정되어 사용자의 Keychain·알림 "항상 허용" 권한이 앱 업데이트 후에도 풀리지 않는다.
- 인증서를 분실·재생성하면 서명 신원이 바뀌므로 재생성하지 않는다(스크립트가 중복 생성을 차단함).

## 2. 한 줄 배포 (`scripts/release.sh`)

```bash
./scripts/release.sh 0.1.0
```

`scripts/release.sh <version>` 이 순서대로 수행하는 단계:

1. **test-gate** (`./scripts/test-gate.sh`) — 릴리스 빌드 및 `Scribe --selftest` 전 항목 통과 검증. 실패 시 중단.
2. **문서 일관성 검토** (`./scripts/release.sh --check-only` 로 단독 실행 가능).
3. **코드서명 신원 게이트** — 키체인에 유효한 `Scribe Local` 인증서가 있는지 확인(`ad-hoc` 상태로 릴리스되는 것을 원천 차단).
4. **VERSION 범프** (`scripts/build-app.sh`, `Casks/scribe.rb`).
5. **Universal 빌드 + zip** (`build/Scribe.zip`) — `arm64` + `x86_64` 두 아키텍처를 빌드해 `lipo` 로 합치고 `strip` 으로 심볼을 제거한 뒤 `ditto` 로 압축. push 전에 버전 일치와 universal 아키텍처를 검증.
6. **커밋 + push** (`git push origin main`).
7. **GitHub Release 생성** (`gh release create v<version> build/Scribe.zip`) 및 **Homebrew tap(`Casks/scribe.rb`) 버전 자동 갱신**.

## 3. Homebrew Tap 구성

`Casks/scribe.rb` 파일을 별도 `<계정>/homebrew-tap` 저장소의 `Casks/scribe.rb` 에 올려 두면, 사용자는 아래 명령 한 줄로 격리(`com.apple.quarantine`) 경고 없이 설치·업데이트할 수 있다:

```bash
brew install --cask <계정>/tap/scribe
```
