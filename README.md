<div align="center">

<img src="assets/icon.png" width="128" height="128" alt="Scribe 아이콘">

# Scribe

**당신의 AI 코딩 토큰을 고전 문학 집필로 — 메뉴바에서.**

[![Release](https://img.shields.io/github/v/release/sangeui/Scribe?color=444d56&label=release)](https://github.com/sangeui/Scribe/releases/latest)
[![Download](https://img.shields.io/badge/Download-Scribe.zip-2ea44f?logo=apple)](https://github.com/sangeui/Scribe/releases/latest/download/Scribe.zip)
[![macOS](https://img.shields.io/badge/macOS-14%2B%20(Universal)-0969da)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-f05138)](https://swift.org)
[![Homebrew](https://img.shields.io/badge/Homebrew-cask-8957e5)](#homebrew)
[![License](https://img.shields.io/badge/license-MIT-3fb950)](LICENSE)

**한국어** · [English](README.en.md)

[왜 Scribe인가요](#왜-scribe인가요) · [어떻게 작동하나요](#어떻게-작동하나요) · [둘러보기](#둘러보기) · [지원 도구](#지원-도구) · [설치](#설치) · [데이터 소스 & 프라이버시](#데이터-소스)

</div>

**Scribe**는 당신이 이미 태우고 있는 AI 코딩 토큰(**Antigravity** · **Gemini CLI** · **Claude Code**)을 macOS 메뉴바와 바탕화면 속 작은 **고전 문학 작가의 작업실**로 바꿔줍니다. 토큰을 쓰면 셰익스피어부터 괴테까지 8인의 대문호가 프로젝트 구텐베르크(Project Gutenberg)의 실제 고전 43편을 한 글자씩 집필하고, 탈고한 책을 동네 서점에 납품해 베스트셀러로 키우며, 밤에는 작가 살롱에 모여 담소를 나눕니다. 그 아래에는 정밀한 로컬 사용량 트래커가 함께 돌아갑니다 — 오늘의 토큰·비용 환산·캐시 효율·최근 14일 추이를 로컬 로그에서 직접 읽습니다.

> 토큰 사용량은 로컬 **Antigravity · Gemini CLI · Claude Code** 데이터에서 직접 읽습니다(`totalTokens` = input + output + cache, 로컬 날짜 기준) — 외부 CLI나 API 키, 별도 로그인이 전혀 필요 없으며 프롬프트와 대화 내용은 Mac 밖으로 전송되지 않습니다.

---

## 왜 Scribe인가요

- **열어보는 게 기다려지는 토큰 사용량 트래커.** 코딩하며 태운 토큰이 그냥 숫자로 사라지지 않고 *햄릿*, *크리스마스 캐럴*, *어셔가의 몰락*, *파우스트*의 실제 원문 타이핑으로 쌓입니다.
- **오늘의 토큰 소비와 캐시 효율을 한눈에.** 대시보드나 브라우저 탭을 열지 않아도 메뉴바와 바탕화면 상시 창에서 오늘 사용량, 시간대별 추이, 14일 기록을 바로 확인합니다.
- **작가를 돌보고 서점을 운영하는 잔잔한 시뮬레이션.** 졸고 있는 작가에게 커피를 건네고, 탈고한 책을 서점 진열창에 올려 비평가 서평과 주간 정산서를 받아보세요.

<div align="center">
<img src="assets/screenshot-home.png" width="400" alt="팝오버 홈 — 상시 창 알약, 원문 집필 카드, 마감, 오늘의 토큰 요약">
</div>

---

## 어떻게 작동하나요

1. 💻 **평소처럼 코딩하세요.** Antigravity, Gemini CLI, Claude Code에서 태우는 토큰이 곧 작가의 집필 연료가 됩니다. 앱을 처음 켠 시점의 기존 토큰은 기준선(0자)으로 삼고, 그 뒤 **새로 쓴 100만 토큰마다 원문 1,000자**가 써집니다.
2. 🪶 **실제 고전 원문이 한 글자씩 타이핑됩니다.** 구텐베르크 프로젝트의 퍼블릭 도메인 고전 **43편(총 1,412만 자)** 원문이 실시간으로 원고지에 채워집니다. 서재에서 언제든 지금까지 쓴 원문을 펼쳐 읽을 수 있습니다.
3. ☕ **돌발 상황을 돌봐 주세요.** 토큰을 쓰는 동안 작가가 책상에서 꾸벅 졸거나, 산책을 나가거나, 잉크가 바닥나거나, 첫 문장이 막혀 멈추기도 합니다. **2,500만 토큰마다 1개씩** 얻는 커피·홍차·잉크병·호출 종·영감의 깃펜으로 작가를 다독여 즉시 복귀시키세요.
4. 🏛 **탈고와 서점 납품.** 한 편을 끝까지 쓰면 탈고 카드와 함께 작가가 원고 뭉치를 들고 마을 길을 걸어 **동네 서점**에 납품합니다.
5. 📈 **동네 서점과 주간 마감.** 서점 진열창과 매대에 책을 배치하면 독자 서평(★1~5), 신문 문화면 소개, 학교 단체 주문, 입소문이 일어나며 **초판 완판(1천 부) → 재판(1만 부) → 베스트셀러(10만 부) → 밀리언셀러(100만 부)**로 성장합니다.
6. 🥂 **작가 살롱과 회차(New Game+).** 책을 탈고한 문호들은 밤마다 살롱에 모여 문학 담소를 나눕니다. 43편을 모두 탈고하면 2회차가 열려 두 작가가 동시에, 3회차에는 세 작가가 동시에 집필합니다.

---

## 둘러보기

<table>
<tr>
<td width="48%" align="center"><img src="assets/screenshot-floating.png" width="360" alt="바탕화면 상시 창(알약·미니)과 라이트·다크 스타일"></td>
<td width="52%" valign="middle">
<h3>🖥️ 바탕화면 한구석에 두는 작업실</h3>
작가를 메뉴바 밖 바탕화면으로 꺼내 <b>알약(Pill)</b> 또는 <b>미니(Mini)</b> 스타일로 띄워 둘 수 있습니다. 현재 타이핑 중인 문장이 실시간으로 흐르고, 투명도를 조절하거나 원하는 위치로 드래그해 고정할 수 있습니다.
</td>
</tr>
<tr>
<td width="52%" valign="middle">
<h3>📚 8인의 대문호와 43편의 서재</h3>
<b>윌리엄 셰익스피어 · 찰스 디킨스 · 에드거 앨런 포 · 루이스 캐럴 · 로버트 루이스 스티븐슨 · 오스카 와일드 · 제인 오스틴 · 요한 볼프강 폰 괴테</b>까지 8명의 작가와 43편의 작품이 수록되어 있습니다. 책을 클릭하면 지금까지 집필한 실제 원문을 책장 넘기듯 읽을 수 있습니다.
</td>
<td width="48%" align="center"><img src="assets/screenshot-shelf.png" width="340" alt="서재 패널 — 8인의 대문호와 43편의 고전 진척도"></td>
</tr>
<tr>
<td width="48%" align="center"><img src="assets/screenshot-bookstore.png" width="340" alt="동네 서점 — 진열창, 매대, 서평, 14일 판매 추이"></td>
<td width="52%" valign="middle">
<h3>🏪 내 원고가 팔리는 동네 서점</h3>
탈고한 책은 동네 서점의 <b>진열창</b>과 <b>매대</b>에 올려 판매합니다. 품절되면 재판을 찍고, 광고를 집행하거나 서점 주인에게 진열을 맡길 수 있습니다. 매주 월요일에는 판매 부수·반품·놓친 손님과 주인의 한마디가 적힌 <b>주간 정산서</b>가 도착합니다.
</td>
</tr>
<tr>
<td width="52%" valign="middle">
<h3>☕ 작업실 가구 6종과 회복 아이템 12종</h3>
2,500만 토큰마다 얻는 아이템으로 졸음·잉크 고갈·외출·슬럼프·정전을 해결하고, 금고와 사본으로 자연재해(쥐·홍수·화재·도둑)로부터 원고를 지킵니다. 남는 아이템을 모으면 작업실에 <b>탁상등 · 난로 · 책장 · 두꺼운 커튼 · 안락의자 · 고양이</b>를 들여 영구 효과를 얻습니다.
</td>
<td width="48%" align="center"><img src="assets/screenshot-bag.png" width="340" alt="가방 및 작업실 패널 — 가구 6종과 회복 아이템 12종"></td>
</tr>
<tr>
<td width="48%" align="center"><img src="assets/village.png" width="340" alt="마을 낮과 밤, 독자와의 대화"></td>
<td width="52%" valign="middle">
<h3>🏘️ 방향키로 걸어 다니는 마을과 독자들</h3>
팝오버에서 지도 버튼을 누르거나 방향키를 누르면 16비트 픽셀 마을이 열립니다. 작업실·창고·서점·살롱 사이를 걸어 다니며 길에서 마주친 독자에게 책을 추천하고, 땅에 떨어진 아이템을 주울 수 있습니다.
</td>
</tr>
<tr>
<td width="52%" valign="middle">
<h3>🥂 문호들이 모이는 작가 살롱</h3>
한 권 이상 탈고한 작가들은 마을의 <b>살롱</b>에 머뭅니다. 살롱에 들어가 동료 문호들과 시대를 넘나드는 대화를 나누거나, 마음에 드는 작가를 작업실의 손님 작가로 초대해 함께 집필할 수 있습니다.
</td>
<td width="48%" align="center"><img src="assets/salon.png" width="340" alt="작가 살롱 낮과 밤"></td>
</tr>
<tr>
<td width="48%" align="center"><img src="assets/screenshot-usage.png" width="340" alt="토큰 사용량 대시보드 — 오늘 토큰, 캐시 효율, 시간대별·14일 차트"></td>
<td width="52%" valign="middle">
<h3>📊 에이전트별 토큰 사용량 대시보드</h3>
<b>Antigravity · Gemini</b>와 <b>Claude Code</b>의 오늘 토큰, API 단가 환산 비용, 캐시 적중률, 영감 게이지, 오늘 시간대별(0~23시) 막대 차트, 최근 14일 추이, 모델별 세부 내역을 한 화면에서 확인합니다.
</td>
</tr>
<tr>
<td width="52%" valign="middle">
<h3>🏅 74종의 성과 배지와 작가 능력치</h3>
일일 토큰 목표(동·은·금 메달), 탈고, 누적 판매 부수, 서점 운영, 돌발 상황 대처, 자연재해 극복, 그리고 조건이 숨겨진 <b>비밀 성과 13종</b>까지 총 74종의 배지가 준비되어 있습니다. 성과를 달성할 때마다 <b>필력 · 끈기 · 매력 · 감각 · 운</b> 능력치가 올라갑니다.
</td>
<td width="48%" align="center"><img src="assets/screenshot-badges.png" width="340" alt="성과 패널 — 74종 업적 배지와 비밀 성과"></td>
</tr>
<tr>
<td width="48%" align="center"><img src="assets/screenshot-portraits.png" width="340" alt="8인의 대문호 초상화, 돌발 상황 표정, 장신구 10종"></td>
<td width="52%" valign="middle">
<h3>🎨 24종의 표정과 10종의 수집 장신구</h3>
작가마다 고유한 돌발 상황 표정(졸음, 찻잔, 열쇠 찾기, 거울 보기 등)이 그려지며, 특정 성과를 달성하면 <b>외알 안경 · 선글라스 · 파이프 · 월계관 · 왕관 · 장미 · 나비넥타이</b> 등 10종의 장신구를 해금해 초상화에 씌울 수 있습니다.
</td>
</tr>
</table>

<div align="center">
<h3>🌅 일출과 일몰을 따라 물드는 시간의 빛</h3>
<p>바탕화면 상시 창은 현재 달(月)의 일출·일몰 시각에 맞춰 새벽·아침·한낮·노을·밤하늘의 색조로 서서히 물들며, 비·안개·눈·폭풍 등 오늘의 날씨 효과가 함께 반영됩니다.</p>
<img src="assets/hours.png" width="720" alt="시간대별 상시 창 색조 변화">
</div>

---

## 이 밖에도

- **데이터 소스 직접 선택** — **설정(`⌘,`) → 집필 / 기록 탭 상단 `데이터 소스`**에서 **Antigravity · Gemini**, **Claude Code**, **통합(모두 합산)** 중 원하는 공급원을 직접 고를 수 있습니다. 소스를 전환해도 지금까지 쓴 원고 글자 수는 그대로 보존됩니다.
- **출판사 주간 마감** — 매주 출판사에서 목표 글자 수나 토큰 마감을 제안합니다. 일요일까지 완수하면 보너스 아이템과 서점 판매량 부스트를 받습니다.
- **집필 중 딜레마와 내기** — 편집자의 제목 변경 요청, 연재 제안, 길고양이 입양 같은 선택지(`Dilemma`)와 손님 작가의 제한 시간 집필 내기(`Bet`)가 찾아옵니다.
- **영감 게이지와 점화** — 입력·캐시 읽기 토큰이 쌓이면 영감 게이지가 차오르고, **영감 켜기**를 누르면 30분 동안 글자 수 속도가 1.5배로 뜁니다.
- **방해 금지 시간대** — 집중하고 싶은 시간대를 설정하면 알림을 보류했다가 팝오버에 `"소식 n건"`으로 조용히 모아 보여줍니다.

---

## 지원 도구

| 도구 | 집계 범위 | 세부 정보 |
|---|---|---|
| **Antigravity** | 오늘 · 최근 5시간 · 시간대별 · 최근 14일 | 캐시 적중률 · 영감 게이지 · 모델별 토큰 및 API 단가 환산 |
| **Gemini CLI** | 오늘 · 최근 5시간 · 시간대별 · 최근 14일 | 세션별 입력/출력/캐시/사고(thoughts) 토큰 집계 |
| **Claude Code** | 오늘 · 최근 5시간 · 시간대별 · 최근 14일 | 모델별 토큰·비용 환산 및 공식 5시간 / 7일 세션 한도(%) |
| **통합 모드** | 위 모든 에이전트 합산 | 에이전트별 오늘 토큰 비중 막대 및 통합 집필 |

모두 로컬에서 직접 읽습니다 — 외부 사용량 CLI가 필요 없습니다.

---

## 설치

### 요구사항

macOS 14.0 (Sonoma) 이상 (Apple Silicon 및 Intel Universal 바이너리). 그 외 별도 런타임이나 외부 CLI는 필요하지 않습니다.

### Homebrew

```bash
brew tap sangeui/scribe https://github.com/sangeui/Scribe
brew install --cask sangeui/scribe/scribe
```

자체 서명/ad-hoc 앱이므로 Cask가 설치 시 Gatekeeper 격리 속성(`com.apple.quarantine`)을 자동으로 제거합니다. 설치 후 `/Applications/Scribe.app`을 바로 실행하세요.

### 직접 설치 (`Scribe.zip` 다운로드)

Homebrew를 쓰지 않는다면 GitHub Releases에서 압축 파일을 바로 내려받을 수 있습니다.

1. **[📦 Scribe.zip 최신 버전 바로 다운로드](https://github.com/sangeui/Scribe/releases/latest/download/Scribe.zip)** (또는 [최신 릴리스 페이지](https://github.com/sangeui/Scribe/releases/latest) 방문)
2. 압축을 풀고 **`Scribe.app`**을 **`/Applications` (응용 프로그램)** 폴더로 옮깁니다.
3. 이 앱은 유료 Apple 개발자 계정 공증 없이 배포되므로 첫 실행 시 Gatekeeper가 *"확인되지 않은 개발자"* 또는 *"손상되었기 때문에 열 수 없습니다"* 경고를 띄울 수 있습니다. 아래 둘 중 하나로 **최초 한 번만** 해제하면 됩니다.
   - **터미널 (권장):**
     ```bash
     xattr -dr com.apple.quarantine /Applications/Scribe.app
     open -a Scribe
     ```
   - **Finder:** `/Applications/Scribe.app`을 **우클릭(또는 Control+클릭) → 열기(Open)** → 대화상자에서 **열기**를 다시 클릭.

### 소스 빌드

```bash
swift build                      # 디버그 빌드
./scripts/test-gate.sh           # 65개 회귀 검증 테스트 실행
./scripts/create-signing-cert.sh # (선택) 로컬 자체 서명 인증서 생성
./scripts/build-app.sh           # Universal 릴리스 → build/Scribe.app & build/Scribe.zip
```

---

## 데이터 소스

| 소스 경로 | 용도 | 비고 |
|---|---|---|
| `~/.gemini/antigravity/brain/**/.system_generated/logs/transcript.jsonl`<br>`~/.gemini/antigravity/brain/**/transcript.jsonl` | Antigravity 일별/시간대별/모델별 토큰 | 직접 읽기 전용 스캔; 스텝 인덱스 중복 제거; 파일 수정 시각 증분 캐시 |
| `~/.gemini/tmp/**/chats/*.json` | Gemini CLI 일별/시간대별/모델별 토큰 | 메시지별 `tokens`(`input`, `output`, `cached`, `thoughts`, `tool`) 읽기 전용 파싱 |
| `~/.claude/projects/**/*.jsonl` | Claude Code 일별/시간대별/모델별 토큰 | `assistant` 응답의 `usage` 블록 직접 파싱; 메시지 ID 중복 제거; 증분 캐시 |
| `~/Library/Application Support/Scribe/writing.json` | 집필 진행률, 서재, 서점, 가방, 성과 로컬 저장 | 온디바이스 JSON 파일; 설정에서 언제든 초기화 가능 |
| Keychain (`Claude Code-credentials`) / `~/.claude/.credentials.json` → `api.anthropic.com` | Claude Code 공식 5시간/7일 한도 % | `Claude Code` 또는 `통합` 소스 사용 시에만 조회; `Antigravity` 단독 모드에서는 호출하지 않음 |

---

## 프라이버시 & 권한

- **온디바이스 우선 (On-device first).** 토큰 사용량은 로컬 Antigravity, Gemini CLI, Claude Code 로그 파일에서 **숫자(`usage` / `tokens`)와 시각, 모델 이름만** 읽습니다. 사용자가 작성한 프롬프트 본문이나 코드는 파싱하지 않으며, 어떤 데이터도 외부 서버로 업로드하지 않습니다.
- **외부 네트워크 요청 최소화.** `Antigravity` 데이터 소스 모드에서는 외부 네트워크 요청을 전혀 하지 않는 **100% 오프라인**으로 동작합니다. `Claude Code` 모드에서만 공식 5시간/7일 세션 한도 퍼센트를 표시하기 위해 `api.anthropic.com/api/oauth/usage`를 조회합니다.
- **Keychain (선택).** Claude Code 한도 조회 시 `~/.claude/.credentials.json` 파일이 있으면 우선 읽고, 없을 때만 Keychain 자격증명을 참조합니다.

---

## 라이선스

**MIT** — [LICENSE](LICENSE) 참고. 앱에 수록된 43편의 고전 문학 원문은 모두 [Project Gutenberg](https://www.gutenberg.org/)의 퍼블릭 도메인(저작권 만료) 작품을 사용합니다.
