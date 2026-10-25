<div align="center">

<img src="assets/icon.png" width="112" height="112" alt="Scribe 아이콘">

# Scribe

**AI 코딩 토큰을 고전 문학 집필과 정밀한 로컬 통계로 — macOS 메뉴바에서.**

[![Release](https://img.shields.io/github/v/release/sangeui/Scribe?color=444d56&label=release)](https://github.com/sangeui/Scribe/releases/latest)
[![Download](https://img.shields.io/badge/Download-Scribe.zip-2ea44f?logo=apple)](https://github.com/sangeui/Scribe/releases/latest/download/Scribe.zip)
[![Homebrew](https://img.shields.io/badge/Homebrew-cask-8957e5)](#설치)
[![macOS](https://img.shields.io/badge/macOS-14%2B%20(Universal)-0969da)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-f05138)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-3fb950)](LICENSE)

**한국어** · [English](README.en.md)

</div>

<br>

<div align="center">
<table>
<tr>
<td width="46%" align="center" valign="middle">
<img src="assets/screenshot-home.png" width="360" alt="메뉴바 팝오버">
<br><sub><b>메뉴바 팝오버</b> — 집필 카드 · 실시간 원고 타이핑 · 오늘의 토큰 요약</sub>
</td>
<td width="54%" align="center" valign="middle">
<img src="assets/screenshot-floating.png" width="400" alt="바탕화면 상시 창(알약·미니)">
<br><sub><b>바탕화면 상시 창 (알약 & 미니)</b> — 일출·일몰·달 위상·날씨가 반영되는 데스크톱 위젯</sub>
</td>
</tr>
</table>
</div>

**Scribe**는 **Antigravity · Gemini CLI · Claude Code**의 로컬 토큰 로그를 읽어 퍼블릭 도메인 고전 문학 원문을 한 글자씩 집필하고, 오늘의 토큰·비용(KRW/USD)·캐시 절감 인사이트를 보여주는 순수 macOS 네이티브(`Swift 6`) 앱입니다.

---

## 설치

```bash
brew install --cask sangeui/tap/scribe
```

<details>
<summary><b>직접 다운로드 (Scribe.zip)</b></summary>
<br>

1. **[최신 Scribe.zip 다운로드](https://github.com/sangeui/Scribe/releases/latest/download/Scribe.zip)** 후 **`Scribe.app`**을 **`/Applications`** 폴더로 옮깁니다.
2. 최초 실행 시 터미널에서 격리 속성을 해제합니다:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Scribe.app && open -a Scribe
   ```
</details>

---

## 주요 화면

<table>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-usage.png" width="340" alt="토큰 대시보드"><br>
<b>토큰 대시보드 & 인사이트</b><br>
<sub>에이전트별 오늘 토큰 · 비용(원화/달러) · 캐시 절감액 · 집중 시간대 및 일별 추이</sub>
</td>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-shelf.png" width="340" alt="서재"><br>
<b>고전 문학 서재</b><br>
<sub>Project Gutenberg 원문 열람 · 집필 대기열 정렬 · 작가별 능력치와 초상화 꾸미기</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-bookstore.png" width="340" alt="동네 서점"><br>
<b>동네 서점 & 주간 정산</b><br>
<sub>탈고 작품 진열 · 재판 입고 · 비평가 서평 · 월요일 주간 판매 정산서</sub>
</td>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-bag.png" width="340" alt="가방 및 작업실"><br>
<b>회복 아이템 & 작업실 가구</b><br>
<sub>돌발 상황 회복 · 자연재해 방어 · 영구 보너스를 주는 작업실 가구 배치</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/village.png" width="340" alt="픽셀 마을"><br>
<b>픽셀 마을 산책</b><br>
<sub>방향키 이동 · 독자 도서 추천 · 길 위의 분실 아이템 수집</sub>
</td>
<td width="50%" align="center" valign="top">
<img src="assets/salon.png" width="340" alt="작가 살롱"><br>
<b>문학 살롱 & 공동 집필</b><br>
<sub>탈고 작가들의 시대 초월 담소 · 작업실 손님 작가 초대 및 집필 내기</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-badges.png" width="340" alt="성과 및 훈장 진열대"><br>
<b>후원자 칭호 & 훈장 진열대</b><br>
<sub>일일 메달과 업적 달성 · 후원자 칭호 해금 · 진열대 보너스 효과 조합</sub>
</td>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-portraits.png" width="340" alt="초상화와 장신구"><br>
<b>상황별 표정 & 장신구</b><br>
<sub>작가 고유 애니메이션 · 성과로 해금하는 초상화 장신구 수집</sub>
</td>
</tr>
</table>

<div align="center">
<img src="assets/hours.png" width="560" alt="시간대별 상시 창 색조 변화"><br>
<sub><b>시간과 계절의 빛</b> — 계절별 일출·일몰 시각, 실시간 태양·달 궤적과 위상, 날씨에 따라 변하는 상시 창</sub>
</div>

---

## 지원 에이전트 및 특징

| 구분 | 내용 |
|---|---|
| **지원 데이터 소스** | **Antigravity** (`~/.gemini/antigravity/brain/**`) · **Gemini CLI** (`~/.gemini/tmp/**/chats`) · **Claude Code** (`~/.claude/projects/**`) · **통합 합산 모드** |
| **한국어 · 영어 국제화** | 앱 내 한/영 즉시 전환 · 토큰 단위(`만·억` / `K·M·B`) 및 통화(`KRW` 일별 기준 환율 자동 반영·오프라인 시 이전 환율 유지 / `USD`) 현지화 |
| **온디바이스 프라이버시** | 로컬 로그에서 토큰 수·시각·모델명만 읽기 전용으로 스캔하며 대화 본문이나 코드는 외부로 전송하지 않음 |
| **네이티브 경량 설계** | 외부 패키지 의존성 0개 (`Swift 6`, `AppKit` + `SwiftUI`) · 상시 창 호버 버튼 및 더블클릭으로 `알약 ↔ 미니` 즉시 전환 |

---

## 소스 빌드 및 라이선스

```bash
swift build            # 디버그 빌드
./scripts/test-gate.sh # 셀프 테스트 게이트(--selftest) 실행
./scripts/build-app.sh # Universal 앱 번들 빌드 (build/Scribe.app)
```

- **라이선스**: [MIT](LICENSE) · 수록된 고전 문학 원문은 [Project Gutenberg](https://www.gutenberg.org/) 퍼블릭 도메인 텍스트를 사용합니다.
- **안내**: 표시되는 비용은 공개 API 표준 단가(USD) 및 일별 기준 환율에 기반한 추정치이며 실제 청구액이나 정액 구독 요금과 무관합니다. Scribe는 Anthropic·Google과 제휴 관계가 없는 독립 오픈소스 도구입니다.
