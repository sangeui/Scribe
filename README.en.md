<div align="center">

<img src="assets/icon.png" width="112" height="112" alt="Scribe icon">

# Scribe

**Your AI coding tokens, turned into classic literature and on-device usage insights — right in your macOS menu bar.**

[![Release](https://img.shields.io/github/v/release/sangeui/Scribe?color=444d56&label=release)](https://github.com/sangeui/Scribe/releases/latest)
[![Download](https://img.shields.io/badge/Download-Scribe.zip-2ea44f?logo=apple)](https://github.com/sangeui/Scribe/releases/latest/download/Scribe.zip)
[![Homebrew](https://img.shields.io/badge/Homebrew-cask-8957e5)](#install)
[![macOS](https://img.shields.io/badge/macOS-14%2B%20(Universal)-0969da)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-f05138)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-3fb950)](LICENSE)

[한국어](README.md) · **English**

</div>

<br>

<div align="center">
<table>
<tr>
<td width="46%" align="center" valign="middle">
<img src="assets/screenshot-home.png" width="360" alt="Menu Bar Popover">
<br><sub><b>Menu Bar Popover</b> — Writing card · Live manuscript strip · Today's token summary</sub>
</td>
<td width="54%" align="center" valign="middle">
<img src="assets/screenshot-floating.png" width="400" alt="Floating Desktop Study (Pill & Mini)">
<br><sub><b>Floating Desktop Study (Pill & Mini)</b> — Tinted by real sunrise, sunset, moon phase & weather</sub>
</td>
</tr>
</table>
</div>

**Scribe** is a pure native macOS (`Swift 6`) app that reads your local **Antigravity · Gemini CLI · Claude Code** token logs to type out public-domain literary classics character by character while surfacing today's tokens, API cost estimates (USD / KRW), and cache efficiency insights.

---

## Install

```bash
brew install --cask sangeui/tap/scribe
```

<details>
<summary><b>Direct Download (Scribe.zip)</b></summary>
<br>

1. Download **[Scribe.zip from the latest release](https://github.com/sangeui/Scribe/releases/latest/download/Scribe.zip)** and move **`Scribe.app`** into **`/Applications`**.
2. Clear the quarantine attribute on first launch:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Scribe.app && open -a Scribe
   ```
</details>

---

## Highlights

<table>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-usage.png" width="340" alt="Usage Dashboard"><br>
<b>Token Dashboard & Insights</b><br>
<sub>Today's tokens · API cost (USD/KRW) · Cache savings · Focus hours & daily trends</sub>
</td>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-shelf.png" width="340" alt="Classic Library"><br>
<b>Classic Literature Shelf</b><br>
<sub>Read Project Gutenberg texts · Reorder your queue · Customize author stats & portraits</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-bookstore.png" width="340" alt="Neighborhood Bookstore"><br>
<b>Neighborhood Bookstore & Weekly Settlement</b><br>
<sub>Curate display windows · Order reprints · Read critic reviews & Monday statements</sub>
</td>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-bag.png" width="340" alt="Bag & Studio"><br>
<b>Recovery Items & Studio Furniture</b><br>
<sub>Cure author events · Block natural disasters · Furnish the study for permanent bonuses</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/village.png" width="340" alt="Pixel Village"><br>
<b>Pixel Village Stroll</b><br>
<sub>Walk with arrow keys · Recommend books to passing readers · Collect lost items</sub>
</td>
<td width="50%" align="center" valign="top">
<img src="assets/salon.png" width="340" alt="Literary Salon"><br>
<b>Literary Salon & Co-Writing</b><br>
<sub>Overhear cross-century conversations · Invite guest co-writers · Take on writing bets</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-badges.png" width="340" alt="Achievements & Badge Showcase"><br>
<b>Patron Titles & Badge Showcase</b><br>
<sub>Unlock daily medals & achievements · Earn Patron Titles · Equip active badge perks</sub>
</td>
<td width="50%" align="center" valign="top">
<img src="assets/screenshot-portraits.png" width="340" alt="Portraits & Accessories"><br>
<b>Expressions & Collectible Accessories</b><br>
<sub>Custom pixel animations per author · Unlockable portrait accessories</sub>
</td>
</tr>
</table>

<div align="center">
<img src="assets/hours.png" width="720" alt="Hourly tint progression of the floating window"><br>
<sub><b>Tinted by Sunrise & Sunset</b> — Shifts smoothly through dawn, midday, dusk, and night palettes with live sun/moon trajectories and weather</sub>
</div>

---

## Supported Agents & Architecture

| Area | Details |
|---|---|
| **Data Sources** | **Antigravity** (`~/.gemini/antigravity/brain/**`) · **Gemini CLI** (`~/.gemini/tmp/**/chats`) · **Claude Code** (`~/.claude/projects/**`) · **Combined Mode** |
| **Localization (EN / KO)** | Instant in-app English & Korean switching · Localized token units (`K·M·B` / `만·억`) and currency (`USD` / `KRW` with daily exchange rate & offline fallback) |
| **On-Device Privacy** | Read-only scan of token counts, timestamps, and model IDs from local logs; prompts and code are never parsed or transmitted externally |
| **Lightweight Native** | Zero external dependencies (`Swift 6`, `AppKit` + `SwiftUI`) · Instant `Pill ↔ Mini` toggle via floating hover button or double-click |

---

## Build & License

```bash
swift build            # debug build
./scripts/test-gate.sh # run regression self-test gate (--selftest)
./scripts/build-app.sh # build Universal app bundle (build/Scribe.app)
```

- **License**: [MIT](LICENSE) · All bundled literary works are public-domain texts from [Project Gutenberg](https://www.gutenberg.org/).
- **Disclaimer**: Displayed costs are estimates based on public standard API rates (USD) and daily reference exchange rates, and may differ from actual invoices or flat-rate subscriptions. Scribe is an independent open-source tool and is not affiliated with Anthropic or Google.
