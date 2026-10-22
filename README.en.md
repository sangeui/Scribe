<div align="center">

<img src="assets/icon.png" width="128" height="128" alt="Scribe icon">

# Scribe

**Your AI coding tokens, turned into classic literature — right in your menu bar.**

[![Release](https://img.shields.io/github/v/release/sangeui/Scribe?color=444d56&label=release)](https://github.com/sangeui/Scribe/releases/latest)
[![Download](https://img.shields.io/badge/Download-Scribe.zip-2ea44f?logo=apple)](https://github.com/sangeui/Scribe/releases/latest/download/Scribe.zip)
[![macOS](https://img.shields.io/badge/macOS-14%2B%20(Universal)-0969da)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-f05138)](https://swift.org)
[![Homebrew](https://img.shields.io/badge/Homebrew-cask-8957e5)](#homebrew)
[![License](https://img.shields.io/badge/license-MIT-3fb950)](LICENSE)

[한국어](README.md) · **English**

[Why Scribe](#why-scribe) · [How it works](#how-it-works) · [Tour](#tour) · [Works with](#works-with) · [Install](#install) · [Data sources & privacy](#data-sources)

</div>

**Scribe** turns the AI coding tokens you're already burning — **Antigravity**, **Gemini CLI**, and **Claude Code** — into a cozy **classic literature writer's study** in your macOS menu bar and desktop. As you spend tokens, eight literary masters from Shakespeare to Goethe type out 43 complete public-domain classics from Project Gutenberg character by character, deliver finished manuscripts to a neighborhood bookstore, and gather at a nightly literary salon. Underneath the simulation sits a fast, local usage tracker — today's tokens, API cost estimate, cache efficiency, hourly breakdown, and 14-day history read straight from your local logs.

> Token usage is read directly from local **Antigravity · Gemini CLI · Claude Code** logs (`totalTokens` = input + output + cache, local date) — no external CLI, API key, or login required. Your prompts and conversation contents never leave your Mac.

---

## Why Scribe

- **A token tracker you actually look forward to opening.** Instead of watching abstract numbers vanish, your daily coding sessions type out real passages of *Hamlet*, *A Christmas Carol*, *The Fall of the House of Usher*, and *Faust*.
- **Today's spend and cache efficiency at a glance.** Check your daily tokens, hourly activity, and 14-day trend right from the menu bar or floating desktop pill — no browser dashboard needed.
- **A living literary world.** Hand a cup of coffee to a dozing author, stock your finished books in the neighborhood bookstore window, read critic reviews, and meet weekly publisher deadlines.

<div align="center">
<img src="assets/screenshot-home.png" width="400" alt="Popover home — floating pill, active manuscript, deadline, and today's token summary">
</div>

---

## How it works

1. 💻 **Code as usual.** Every token you burn in Antigravity, Gemini CLI, or Claude Code fuels your author's pen. Existing tokens at first launch become your baseline (`0` characters), and every **1M new tokens writes 1,000 characters** of classic text.
2. 🪶 **Real classics, typed letter by letter.** All **43 classics (14.12M characters)** from Project Gutenberg are bundled offline. Open the **Shelf** anytime to read every page your tokens have written so far.
3. ☕ **Care for your author.** While writing, your author might doze off, run out of ink, wander out for a stroll, or hit writer's block. Every **25M tokens** grants a recovery item (Coffee, Tea, Ink Bottle, Bell, Muse Quill, etc.) to bring them right back to the desk.
4. 🏛 **Finish & deliver to the Bookstore.** Completing a book triggers a completion card, and your author walks down the village path carrying the manuscript to the **Bookstore**.
5. 📈 **Run the Bookstore & hit weekly deadlines.** Place finished books in the display window or main table. Critic reviews (★1–5), newspaper features, school orders, and ad campaigns push your books from **First Print Sold Out (1K) → Reprint (10K) → Bestseller (100K) → Million Seller (1M)**.
6. 🥂 **The Literary Salon & New Game+.** Authors who have finished at least one book gather in the **Salon** at night to chat across centuries. Finish all 43 books to unlock Round 2 (two authors writing simultaneously) and Round 3 (three authors at once).

---

## Tour

<table>
<tr>
<td width="48%" align="center"><img src="assets/screenshot-floating.png" width="360" alt="Floating desktop pill and mini styles in light and dark mode"></td>
<td width="52%" valign="middle">
<h3>🖥️ Let it live on your desktop</h3>
Bring your writer out of the menu bar and onto the desktop in <b>Pill</b> or <b>Mini</b> style. Watch live manuscript lines scroll as you code, adjust opacity, and drag it anywhere on screen.
</td>
</tr>
<tr>
<td width="52%" valign="middle">
<h3>📚 8 Literary Masters & 43 Classics</h3>
Collect works by <b>William Shakespeare · Charles Dickens · Edgar Allan Poe · Lewis Carroll · Robert Louis Stevenson · Oscar Wilde · Jane Austen · Johann Wolfgang von Goethe</b>. Click any book on the Shelf to read the actual manuscript pages you've written.
</td>
<td width="48%" align="center"><img src="assets/screenshot-shelf.png" width="340" alt="Shelf panel — 8 authors and 43 classic books"></td>
</tr>
<tr>
<td width="48%" align="center"><img src="assets/screenshot-bookstore.png" width="340" alt="Neighborhood bookstore — display window, tables, critic reviews, and 14-day sales"></td>
<td width="52%" valign="middle">
<h3>🏪 A neighborhood bookstore for your manuscripts</h3>
Stock finished books in the <b>Display Window</b> and <b>Tables</b>. Order reprints when sold out, run ad campaigns, or let the shopkeeper curate. Every Monday brings a weekly settlement statement with sales, returns, and shopkeeper notes.
</td>
</tr>
<tr>
<td width="52%" valign="middle">
<h3>☕ 6 Studio Furniture Pieces & 12 Recovery Items</h3>
Use items earned every 25M tokens to cure drowsiness, empty inkwells, strolls, writer's block, and blown-out candles — or keep a Safe and Manuscript Copy to automatically block natural disasters. Trade spare items for permanent studio furniture like a <b>Desk Lamp, Stove, Bookshelf, Heavy Curtains, Armchair, and Studio Cat</b>.
</td>
<td width="48%" align="center"><img src="assets/screenshot-bag.png" width="340" alt="Bag & Studio panel — 6 furniture pieces and 12 items"></td>
</tr>
<tr>
<td width="48%" align="center"><img src="assets/village.png" width="340" alt="16-bit pixel village in day and night"></td>
<td width="52%" valign="middle">
<h3>🏘️ Walk the pixel village</h3>
Press the map button or use arrow keys to step into the village. Walk between the Workshop, Storage, Bookstore, and Salon, recommend books to passing readers, and pick up lost items along the path.
</td>
</tr>
<tr>
<td width="52%" valign="middle">
<h3>🥂 The Literary Salon</h3>
Authors who have completed a manuscript relax in the <b>Salon</b>. Step inside to overhear conversations between Shakespeare, Wilde, Austen, and Goethe — or invite one to your workshop as a guest co-writer.
</td>
<td width="48%" align="center"><img src="assets/salon.png" width="340" alt="Literary Salon in day and night"></td>
</tr>
<tr>
<td width="48%" align="center"><img src="assets/screenshot-usage.png" width="340" alt="Token usage dashboard — today's tokens, cache efficiency, hourly & 14-day charts"></td>
<td width="52%" valign="middle">
<h3>📊 Per-Agent Token Usage Dashboard</h3>
Inspect today's token total, API cost equivalent, cache hit rate, Inspiration Gauge, 24-hour activity chart, 14-day history, and per-model breakdown for <b>Antigravity · Gemini</b> and <b>Claude Code</b>.
</td>
</tr>
<tr>
<td width="52%" valign="middle">
<h3>🏅 74 Achievements & Author Stats</h3>
Earn Bronze, Silver, and Gold daily medals, milestone badges across six categories, and <b>13 hidden secret achievements</b>. Every badge awards stat points across <b>Penmanship · Grit · Charm · Sense · Luck</b>.
</td>
<td width="48%" align="center"><img src="assets/screenshot-badges.png" width="340" alt="Achievements panel — 74 badges and 13 secrets"></td>
</tr>
<tr>
<td width="48%" align="center"><img src="assets/screenshot-portraits.png" width="340" alt="Author portraits, event expressions, and 10 unlockable accessories"></td>
<td width="52%" valign="middle">
<h3>🎨 24 Portrait Expressions & 10 Accessories</h3>
Each author features custom pixel expressions for every event, plus 10 unlockable accessories — including a <b>Monocle, Sunglasses, Pipe, Laurel Wreath, Crown, Rose, and Bowtie</b>.
</td>
</tr>
</table>

<div align="center">
<h3>🌅 Tinted by Sunrise and Sunset</h3>
<p>The floating desktop window shifts smoothly through dawn, morning, midday, dusk, and night palettes based on seasonal sunrise and sunset times, complete with live weather effects.</p>
<img src="assets/hours.png" width="720" alt="Hourly tint progression of the floating window">
</div>

---

## Works with

| Tool | Tracked | Highlights |
|---|---|---|
| **Antigravity** | today · recent 5h · hourly · 14 days | Cache hit rate · Inspiration gauge · per-model breakdown & cost estimate |
| **Gemini CLI** | today · recent 5h · hourly · 14 days | Per-session input / output / cached / thoughts token aggregation |
| **Claude Code** | today · recent 5h · hourly · 14 days | Per-model tokens & cost + official 5h / 7d session limit % |
| **Combined Mode** | All providers summed | Combined writing progress + per-agent share bar |

Switch your active data source anytime under **Settings (`⌘,`) → Writing / Record → Data Source**. Switching sources preserves all characters you've already written.

---

## Install

### Requirements

macOS 14.0 (Sonoma) or later (Universal binary for Apple Silicon & Intel). No external CLI or runtime required.

### Homebrew

```bash
brew tap sangeui/scribe https://github.com/sangeui/Scribe
brew install --cask sangeui/scribe/scribe
```

The cask automatically clears the macOS Gatekeeper quarantine attribute on install. Launch `/Applications/Scribe.app` right away.

### Manual install (without Homebrew)

1. Download **[📦 Scribe.zip from the latest release](https://github.com/sangeui/Scribe/releases/latest/download/Scribe.zip)** (or visit the [Releases page](https://github.com/sangeui/Scribe/releases/latest)).
2. Unzip and move **`Scribe.app`** into **`/Applications`**.
3. Because the app is self-signed / ad-hoc (not notarized with a paid Apple Developer ID), macOS Gatekeeper may show an *"unidentified developer"* warning on first launch. Clear it once:
   - **Terminal (fastest):**
     ```bash
     xattr -dr com.apple.quarantine /Applications/Scribe.app
     open -a Scribe
     ```
   - **Finder:** Right-click (or Control-click) `/Applications/Scribe.app` → **Open** → **Open**.

### Build from source

```bash
swift build                      # debug build
./scripts/test-gate.sh           # run 65 regression checks
./scripts/create-signing-cert.sh # (optional) create local self-signed certificate
./scripts/build-app.sh           # Universal release → build/Scribe.app & build/Scribe.zip
```

---

## Data sources

| Source Path | Used for | Notes |
|---|---|---|
| `~/.gemini/antigravity/brain/**/.system_generated/logs/transcript.jsonl`<br>`~/.gemini/antigravity/brain/**/transcript.jsonl` | Antigravity daily/hourly/model tokens | Read-only scan; deduplicated by step index; incremental mtime cache |
| `~/.gemini/tmp/**/chats/*.json` | Gemini CLI daily/hourly/model tokens | Read-only parse of message `tokens` (`input`, `output`, `cached`, `thoughts`, `tool`) |
| `~/.claude/projects/**/*.jsonl` | Claude Code daily/hourly/model tokens | Read-only parse of assistant `usage` blocks; deduplicated by message id |
| `~/Library/Application Support/Scribe/writing.json` | Local save state (progress, shelf, shop, bag, badges) | On-device JSON; resettable in Settings |
| Keychain (`Claude Code-credentials`) / `~/.claude/.credentials.json` → `api.anthropic.com` | Claude Code official 5h/7d limit % | Queried only when `Claude Code` or `Combined` source is selected |

---

## Privacy & permissions

- **On-device first.** Scribe only reads token counts, timestamps, and model IDs from your local logs. Prompt texts and code are never parsed or uploaded anywhere.
- **Zero network in Antigravity mode.** When set to `Antigravity`, Scribe makes zero outbound network requests.

---

## License

**MIT** — see [LICENSE](LICENSE). All 43 bundled literary works are public-domain texts from [Project Gutenberg](https://www.gutenberg.org/).
