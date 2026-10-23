import SwiftUI
import UserNotifications

@main
enum Launcher {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--dump") {
            MainActor.assumeIsolated { Dump.run() }
            return
        }
        if args.contains("--test-notification") {
            // 앱 번들로 띄워야 한다: open -n build/Scribe.app --args --test-notification
            MainActor.assumeIsolated { Dump.testNotification() }
            return
        }
        if args.contains("--limits") {
            Dump.limits()
            return
        }
        if args.contains("--selftest") {
            MainActor.assumeIsolated { Dump.selfTest() }
            return
        }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            MainActor.assumeIsolated { Dump.renderPopover(to: args[i + 1]) }
            return
        }
        if let i = args.firstIndex(of: "--styles"), i + 1 < args.count {
            MainActor.assumeIsolated { Dump.renderStyles(to: args[i + 1]) }
            return
        }
        if let i = args.firstIndex(of: "--hours"), i + 1 < args.count {
            MainActor.assumeIsolated { Dump.renderHours(to: args[i + 1]) }
            return
        }
        if let i = args.firstIndex(of: "--salon"), i + 1 < args.count {
            MainActor.assumeIsolated { Dump.renderSalon(to: args[i + 1]) }
            return
        }
        if let i = args.firstIndex(of: "--village"), i + 1 < args.count {
            MainActor.assumeIsolated { Dump.renderVillage(to: args[i + 1]) }
            return
        }
        if let i = args.firstIndex(of: "--settings"), i + 1 < args.count {
            MainActor.assumeIsolated { Dump.renderSettings(to: args[i + 1]) }
            return
        }
        if let i = args.firstIndex(of: "--marquee"), i + 1 < args.count {
            // 긴 한 줄이 옮겨 가는지 확인. 몇 초 간격으로 두 번 그려 비교한다.
            MainActor.assumeIsolated {
                Dump.renderMarquee(to: args[i + 1])
            }
            return
        }
        if let i = args.firstIndex(of: "--writing"), i + 1 < args.count {
            MainActor.assumeIsolated { Dump.renderWriting(to: args[i + 1]) }
            return
        }
        if let i = args.firstIndex(of: "--tour"), i + 1 < args.count {
            MainActor.assumeIsolated { Dump.renderTour(to: args[i + 1]) }
            return
        }
        migrateDefaults()
        MainActor.assumeIsolated { ScribeApp.main() }
    }
}

/// 앱 이름이 Columbus 였을 때의 설정(상시 창 위치·모양·투명도·대표 초상화)을 한 번 가져온다.
private func migrateDefaults() {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: FloatingWindowController.visibleKey) == nil,
          let old = UserDefaults(suiteName: "local.columbus") else { return }
    for key in [FloatingWindowController.visibleKey, FloatingWindowController.originKey, FloatingWindowController.opacityKey,
                FloatingView.featuredKey, FloatingStyle.key] {
        if let value = old.object(forKey: key) { defaults.set(value, forKey: key) }
    }
}

struct ScribeApp: App {
    @State private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
        }
    }
}

/// 메뉴바에는 움직이는 깃펜 하나만. 쓰는 중이면 줄을 긋고, 돌발 상황이면 그 상황 아이콘과 서 있는 깃펜이 번갈아 보인다.
private struct MenuBarLabel: View {
    let store: UsageStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(nsImage: menuBarIcon(event: store.writing?.event, slacking: store.mood == .slacking, tick: store.menuTick,
                                   sparkle: store.writing?.finishCards.contains { Date().timeIntervalSince($0.date) < 20 } ?? false,
                                   tremble: store.writing?.caffeinated ?? false))
            // 라벨은 앱이 뜨자마자 그려지므로 여기서 갱신 루프를 시작한다.
            .task {
                store.start()
                // `--open-panel <종류>`: 확인용. 뜨자마자 팝오버를 열고 그 옆 패널을 띄운다(settings, shelf, bag, bookstore, badges, usage).
                if let i = CommandLine.arguments.firstIndex(of: "--open-panel"), i + 1 < CommandLine.arguments.count {
                    let name = CommandLine.arguments[i + 1]
                    try? await Task.sleep(for: .seconds(2))
                    await SidePanel.openPopoverForTesting()
                    try? await Task.sleep(for: .milliseconds(300))
                    let kinds: [String: SidePanel.Kind] = ["settings": .settings, "shelf": .shelf, "bag": .bag, "bookstore": .bookstore, "badges": .badges, "usage": .usage]
                    if let kind = kinds[name] { SidePanel.shared.open(kind, store: store) }
                }
                // `--open-settings`: 확인용. 뜨자마자 설정 창을 연다.
                if CommandLine.arguments.contains("--open-settings") {
                    try? await Task.sleep(for: .seconds(1))
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }
    }
}

/// 화면 없이 확인하는 실행들. 기록 파일은 읽기만 한다.
@MainActor
enum Dump {
    /// `Scribe --dump`: 집계 결과와 집필 진행을 찍는다. 다른 도구로 낸 값과 맞춰 볼 때 쓴다.
    static func run() {
        let (entries, files, filesByProvider) = ClaudeLogParser.scanAllWithProviders(since: .distantPast)
        let s = UsageAggregator.snapshot(entries: entries, scannedFiles: files, filesByProvider: filesByProvider, source: .all)
        print("roots (Claude):")
        for root in ClaudeLogParser.projectRoots() { print("  \(root.path)") }
        print("roots (Antigravity / Gemini):")
        for root in ClaudeLogParser.antigravityRoots() + ClaudeLogParser.geminiCLIRoots() { print("  \(root.path)") }
        print("files: \(files) (antigravity=\(filesByProvider[.antigravity] ?? 0), claude=\(filesByProvider[.claude] ?? 0)), entries: \(entries.count), days: \(s.days.count)")
        print("today: tokens=\(s.today.tokens) (antigravity=\(s.todayByProvider[.antigravity] ?? 0), claude=\(s.todayByProvider[.claude] ?? 0)) cost=\(String(format: "%.4f", s.today.cost)) unpriced=\(s.today.hasUnpriced)")
        for m in s.todayByModel {
            print("  \(m.model): tokens=\(m.tokens) in=\(m.input) out=\(m.output) cw=\(m.cacheWrite) cr=\(m.cacheRead) cost=\(m.cost.map { String(format: "%.4f", $0) } ?? "nil")")
        }
        print("last 7 days:")
        for d in s.days.suffix(7) {
            print("  \(DayKey.string(from: d.day)) tokens=\(d.tokens) cost=\(String(format: "%.4f", d.cost))")
        }
        let w = WritingStore(persist: false).apply(days: s.days)
        print("writing: books=\(Library.books.count) roundChars=\(Library.roundCharacters) dir=\(Library.directory?.path ?? "nil")")
        print("  total=\(Int(w.totalCharacters)) round=\(w.round) book=\(w.book.map { "\($0.authorShort) · \($0.title)" } ?? "-") \(w.charactersInBook)/\(w.book?.characters ?? 0) today=\(Int(w.todayCharacters)) recent/day=\(Int(w.recentCharactersPerDay)) eta=\(w.daysToFinish.map(String.init) ?? "-")")
        for book in Library.books where Library.text(of: book)?.count != book.characters {
            print("  length mismatch: \(book.file) manifest=\(book.characters) loaded=\(Library.text(of: book)?.count ?? -1)")
        }
        for f in w.finished { print("  finished round \(f.round) #\(f.bookIndex + 1) \(DayKey.string(from: f.date))") }
    }

    /// `open -n Scribe.app --args --test-notification`: 권한 상태를 로그에 찍고 시험 알림을 하나 보낸다.
    /// 결과는 `log show --predicate 'process == "Scribe"'` 로 본다.
    static func testNotification() {
        let done = DispatchSemaphore(value: 0)
        // 메인 스레드는 아래 wait 로 막혀 있으니, 메인 액터에 묶이지 않는 작업으로 돌린다.
        let available = Notifier.isAvailable
        Task.detached {
            guard available else {
                NSLog("Scribe 시험 알림: 앱 번들이 아니라 보낼 수 없습니다")
                done.signal()
                return
            }
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            NSLog("Scribe 시험 알림: 권한 %d (0 안 물음 1 거절 2 허용), 배너 %d", settings.authorizationStatus.rawValue, settings.alertSetting.rawValue)
            let content = UNMutableNotificationContent()
            content.title = "Scribe 시험 알림"
            content.body = "알림이 이렇게 옵니다."
            content.sound = .default
            do {
                try await center.add(UNNotificationRequest(identifier: "test-\(Date().timeIntervalSince1970)", content: content, trigger: nil))
                NSLog("Scribe 시험 알림: 보냄")
            } catch {
                NSLog("Scribe 시험 알림: 실패 %@", "\(error)")
            }
            try? await Task.sleep(for: .seconds(2))
            done.signal()
        }
        done.wait()
    }

    /// `Scribe --limits`: 앱과 같은 방법(자동 갱신 경로)으로 로그인을 읽어 한도를 찍는다. 토큰은 찍지 않는다.
    nonisolated static func limits() {
        let done = DispatchSemaphore(value: 0)
        Task {
            do {
                let result = try await ClaudeLimitsClient().fetch(userInitiated: false)
                print("plan: \(result.plan ?? "-")")
                for row in result.rows { print("  \(row.name): \(Int(row.percent.rounded()))%") }
            } catch let error as LimitsError {
                print("error: \(error.message)")
            } catch {
                print("error: \(error)")
            }
            done.signal()
        }
        done.wait()
    }

    /// `Scribe --selftest`: 임시 폴더에서 기준선과 글자 환산을 확인한다.
    static func selfTest() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("columbus-selftest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("writing.json")
        // 날씨와 마감은 따로 확인한다. 다른 확인에 끼어들면 숫자가 달라진다.
        Weather.forced = .cloudy
        WritingStore.deadlinesEnabled = false
        WritingStore.shopEnabled = false
        WritingStore.staminaEnabled = false
        WritingStore.stockEnabled = false
        let today = Calendar.current.startOfDay(for: Date())
        func days(_ tokens: Int) -> [DayUsage] { [DayUsage(day: today, tokens: tokens)] }
        var failures = 0
        func check(_ ok: Bool, _ message: String) {
            print((ok ? "ok   " : "FAIL ") + message)
            if !ok { failures += 1 }
        }

        // 처음 만들 때 이미 있던 토큰은 글자가 되지 않는다.
        var w = WritingStore(url: url).apply(days: days(5_000_000))
        check(w.totalCharacters == 0, "기준선: 이미 있던 500만 토큰은 0자 (\(Int(w.totalCharacters)))")
        // 그 뒤 100만 토큰은 1,000자.
        let store = WritingStore(url: url)
        store.badgeRewards = false
        // 추첨을 끈다. 켜 두면 가끔 돌발 상황이나 자연재해가 끼어 글자 수가 달라진다.
        store.eventChance = 0
        store.disasterChance = 0
        store.luckChance = 0
        w = store.apply(days: days(6_000_000))
        check(Int(w.totalCharacters) == 1_000, "100만 토큰 더: \(Int(w.totalCharacters))자 (기대 1000)")
        // 같은 숫자를 다시 받아도 늘지 않는다.
        w = store.apply(days: days(6_000_000))
        check(Int(w.totalCharacters) == 1_000, "같은 토큰 다시: \(Int(w.totalCharacters))자")
        // 다시 읽어도 같다.
        let reread = WritingStore(url: url).apply(days: days(6_000_000))
        check(Int(reread.totalCharacters) == 1_000, "다시 읽기: \(Int(reread.totalCharacters))자")

        // 돌발 상황: 추첨은 끄고 직접 시작한다. 난수는 0.5 로 고정(지속 37.5분).
        let events = WritingStore(url: url)
        events.badgeRewards = false
        events.eventChance = 0
        events.random = { 0.5 }
        let now = Date()
        events.start(AuthorEvents.nap, now: now)
        w = events.apply(days: days(7_000_000), now: now)
        check(Int(w.totalCharacters) == 1_000, "상황 중 100만 토큰: 글자 그대로 \(Int(w.totalCharacters))")
        check(w.event?.id == "nap", "상황 중: nap 그대로")
        // 맞지 않는 아이템, 없는 아이템은 아무 일도 안 한다.
        w = events.use(.ink)
        check(w.event != nil, "잉크병(안 맞음, 없음): 상황 그대로")
        w = events.use(.coffee)
        check(w.event != nil, "커피(맞지만 0개): 상황 그대로")
        // 아이템: `Balance.tokensPerItem` 마다 하나. 기준선 5M 뒤로 그만큼 쌓이면 하나가 생긴다.
        w = events.apply(days: days(5_000_000 + Balance.tokensPerItem), now: now)
        let items = ItemKind.allCases.reduce(0) { $0 + w.count($1) }
        check(items == 1, "\(Format.tokens(Balance.tokensPerItem)) 토큰 쌓임: 아이템 \(items)개 (기대 1)")
        check(Int(w.totalCharacters) == 1_000, "상황 중 더 써도: 글자 그대로 \(Int(w.totalCharacters))")
        check(w.recentEvents.count == 1 && w.recentEvents[0].endedAt == nil && w.recentEvents[0].pausedTokens == Balance.tokensPerItem - 1_000_000,
              "기록: nap 진행 중, 멈춘 동안 토큰 \(w.recentEvents.first?.pausedTokens ?? -1)")
        // 가득: 한 종류 5개가 넘으면 다른 종류로 간다.
        for _ in 0..<Balance.itemCap { events.giveForTesting(.coffee) }
        let coffeeBefore = events.state.items["coffee"] ?? 0
        events.random = { 0.0 }  // 비중대로면 커피가 1순위
        let given = events.giveRandomItem()
        check(given != nil && given != .coffee && events.state.items["coffee"] == coffeeBefore,
              "가득: 커피가 가득이면 \(given?.title ?? "-")로 (커피 \(coffeeBefore)개 그대로)")
        // 맞는 아이템을 쥐여 주고 쓴다(무작위로 나온 아이템이 커피가 아닐 수 있어서 직접 넣는다).
        var state = events.state
        state.items["coffee"] = 1
        let cured = WritingStore(url: dir.appendingPathComponent("cured.json"))
        cured.badgeRewards = false
        cured.random = { 0.5 }
        cured.eventChance = 0
        _ = cured.apply(days: days(10_000_000), now: now)  // 기준선
        cured.start(AuthorEvents.nap, now: now)
        cured.giveForTesting(.coffee)
        w = cured.use(.coffee)
        check(w.event == nil && w.count(.coffee) == 0, "커피 쓰기: 상황 끝, 커피 0개")
        check(w.recentEvents.first?.endedBy == "coffee" && w.recentEvents.first?.endedAt != nil, "기록: 커피로 끝남")
        w = cured.apply(days: days(11_000_000), now: now)
        check(Int(w.totalCharacters) == 1_000, "재개 뒤 100만 토큰: \(Int(w.totalCharacters))자 (기대 1000)")
        check(w.note?.kind == .cured && AuthorEvents.nap.cured.contains(w.note?.text ?? ""), "커피 쓰기: 치료 한 줄 \"\(w.note?.text ?? "")\"")
        // 끝날 시각이 지나면 아이템 없이 저절로 끝난다.
        cured.start(AuthorEvents.ink, now: now)
        w = cured.apply(days: days(11_000_000), now: now.addingTimeInterval(61 * 60))
        check(w.event == nil, "61분 뒤: 저절로 끝남")
        check(w.note?.kind == .returned && AuthorEvents.ink.returns.contains(w.note?.text ?? "") && w.recentEvents.first?.outcome == w.note?.text,
              "저절로 끝남: 돌아온 한 줄 \"\(w.note?.text ?? "")\"")
        let auto = w.recentEvents.first
        check(w.recentEvents.count == 2 && auto?.event == "ink" && auto?.endedBy == nil && auto?.endedAt != nil && auto?.endedAt != auto?.startedAt,
              "기록: 잉크 저절로 끝남, 기록 2줄")
        // 다시 읽어도 기록이 남는다.
        let reloadedStore = WritingStore(url: dir.appendingPathComponent("cured.json"))
        reloadedStore.badgeRewards = false
        let reloaded = reloadedStore.apply(days: days(11_000_000), now: now.addingTimeInterval(61 * 60))
        check(reloaded.recentEvents.count == 2, "기록: 다시 읽기 \(reloaded.recentEvents.count)줄")
        // 아이템 거절: 난수 0.1 이면 25% 안에 들어 거절한다. 아이템은 그대로고 3.2분 동안 다시 못 쓴다.
        let stubborn = WritingStore(url: dir.appendingPathComponent("refuse.json"))
        stubborn.badgeRewards = false
        stubborn.eventChance = 0
        stubborn.disasterChance = 0
        stubborn.luckChance = 0
        stubborn.random = { 0.1 }
        _ = stubborn.apply(days: days(1), now: now)
        stubborn.start(AuthorEvents.away, now: now)
        check(stubborn.state.event?.cause == 0 && stubborn.state.eventLog.last?.cause == AuthorEvents.away.causes[0], "원인: 시작할 때 고름")
        stubborn.giveForTesting(.bell)
        w = stubborn.use(.bell, now: now)
        check(w.event != nil && w.count(.bell) == 1 && w.note?.kind == .refused && w.refusedUntil(now: now) != nil,
              "거절: 상황 그대로, 종 그대로, \"\(w.note?.text ?? "")\"")
        w = stubborn.use(.bell, now: now.addingTimeInterval(60))
        check(w.event != nil && w.count(.bell) == 1, "거절 뒤 1분: 아직 못 씀")
        stubborn.random = { 0.9 }
        w = stubborn.use(.bell, now: now.addingTimeInterval(6 * 60))
        check(w.event == nil && w.count(.bell) == 0 && w.note?.kind == .cured, "거절 뒤 6분: 다시 권하니 통함")
        _ = state

        // 자연재해: 지금 책에서 쓴 만큼까지만 잃고, 탈고한 책은 그대로다.
        let quake = WritingStore(url: dir.appendingPathComponent("disaster.json"))
        quake.badgeRewards = false
        quake.random = { 0.5 }  // 책 분량의 2.5%
        quake.eventChance = 0
        quake.disasterChance = 0
        quake.luckChance = 0
        _ = quake.apply(days: days(1), now: now)  // 기준선
        w = quake.apply(days: days(10_000_001), now: now)
        let lost = quake.strike(Disasters.fire, now: now)
        w = WritingProgress(state: quake.state, now: now)
        check(lost == Int(0.025 * Double(Library.books[0].characters)) && Int(w.totalCharacters) == 10_000 - lost,
              "자연재해: \(lost)자 잃음, 남은 \(Int(w.totalCharacters))자")
        check(w.recentEvents.first?.lostCharacters == lost && quake.unnotifiedDisasters.count == 1, "자연재해: 기록과 알림 대기")
        // 첫 책을 넘기고 둘째 책을 조금 쓴 상태에서 재해가 나도 첫 책 탈고는 그대로
        w = quake.apply(days: days(10_000_001 + 180_000_000), now: now)
        let inBook = w.charactersInBook
        let lost2 = quake.strike(Disasters.flood, now: now)
        w = WritingProgress(state: quake.state, now: now)
        check(w.bookIndex == 1 && w.finished.count == 1 && lost2 <= inBook && w.charactersInBook == inBook - lost2,
              "자연재해: 탈고한 책은 그대로 (책 \(w.bookIndex + 1), 탈고 \(w.finished.count), 잃음 \(lost2) ≤ \(inBook))")
        check(w.badges["first_book"] != nil && w.badges["survivor"] != nil && w.badges["books_5"] == nil,
              "성과: 첫 탈고·재해 생존 달성, 다섯 권은 아직")
        let goals = Achievements.nextGoals { w.badges[$0.id] != nil }
        check(goals.contains { $0.id == "books_5" } && !goals.contains { $0.id == "books_10" } && !goals.contains { $0.id == "first_book" },
              "성과: 단계 묶음은 다음 것 하나만 (다섯 권)")
        check(Achievements.all.filter { $0.portrait != nil }.count == Library.authors.count, "성과: 작가 전집 뱃지 \(Library.authors.count)개")
        check(Set(Achievements.all.map(\.id)).count == Achievements.all.count, "성과: 이름이 겹치지 않음 (\(Achievements.all.count)개)")
        // 이 책을 아직 안 썼으면 아무것도 잃지 않는다
        if w.charactersInBook == 0 {
            check(quake.strike(Disasters.storm, now: now) == 0, "자연재해: 쓴 것이 없으면 0자")
        }
        // 성과: 처음 셀 때 이미 이룬 것은 조용히, 그 뒤에 이룬 것은 알림 대기
        let badgeStore = WritingStore(url: dir.appendingPathComponent("badges.json"))
        badgeStore.eventChance = 0
        badgeStore.disasterChance = 0
        badgeStore.luckChance = 0
        _ = badgeStore.apply(days: days(1), now: now)  // 기준선. 아직 이룬 것 없음
        w = badgeStore.apply(days: days(15_000_001), now: now)
        check(w.badges["first_line"] != nil && w.badges["chars_10k"] != nil && w.badges["chars_100k"] == nil,
              "성과: 첫 문장·1만 자 달성, 10만 자는 아직")
        check(Set(badgeStore.unnotifiedBadges.map(\.id)).isSuperset(of: ["first_line", "chars_10k"]), "성과: 알림 대기")
        let rewarded = ItemKind.allCases.reduce(0) { $0 + w.count($1) }
        check(rewarded >= 2 && badgeStore.rewardText(for: "first_line") != nil && badgeStore.rewardText(for: "chars_10k") != nil,
              "성과 보상: 아이템 \(rewarded)개 (동 1 + 동 1 이상), \(badgeStore.rewardText(for: "first_line") ?? "-")")
        // 금 뱃지 효과: 뱃지를 직접 넣어 두고 100만 토큰을 더 쓰면 글자가 5% 더 늘고, 거절 확률은 5%p 낮다.
        var perked = badgeStore.state
        perked.items = [:]
        perked.badges["chars_1m"] = BadgeRecord(date: now, notified: true)
        perked.badges["books_10"] = BadgeRecord(date: now, notified: true)
        let perkURL = dir.appendingPathComponent("perks.json")
        try? JSONEncoder().encode(perked).write(to: perkURL)
        let perkStore = WritingStore(url: perkURL)
        perkStore.badgeRewards = false
        perkStore.eventChance = 0
        perkStore.disasterChance = 0
        perkStore.luckChance = 0
        let before = perkStore.apply(days: days(15_000_001), now: now).totalCharacters
        let after = perkStore.apply(days: days(16_000_001), now: now).totalCharacters
        check(Int((after - before).rounded()) == 1_050, "금 효과: 100만 토큰에 \(Int((after - before).rounded()))자 (기대 1050)")
        perkStore.random = { 0.22 }  // 거절 기준 25% 안이지만 효과(−5%p)로 20% 이라 통한다
        perkStore.start(AuthorEvents.nap, now: now)
        perkStore.giveForTesting(.coffee)
        w = perkStore.use(.coffee, now: now)
        check(w.event == nil && w.count(.coffee) == 0, "금 효과: 거절 확률 20%, 난수 0.22 는 통함")
        let quietState = WritingStore(url: dir.appendingPathComponent("badges-old.json"))
        quietState.eventChance = 0
        quietState.disasterChance = 0
        quietState.luckChance = 0
        _ = quietState.apply(days: days(1), now: now)
        var old = quietState.state
        old.badges = [:]
        old.badgesInitialized = false
        old.days[DayKey.string(from: today)]?.characters = 20_000
        let oldURL = dir.appendingPathComponent("badges-old2.json")
        try? JSONEncoder().encode(old).write(to: oldURL)
        let upgraded = WritingStore(url: oldURL)
        upgraded.eventChance = 0
        upgraded.disasterChance = 0
        upgraded.luckChance = 0
        w = upgraded.apply(days: days(2), now: now)
        check(w.badges["chars_10k"] != nil && upgraded.unnotifiedBadges.isEmpty, "성과: 예전 기록은 조용히 채움")
        // 매일 성과: 오늘 1만 자로 이루고, 내일 또 1만 자를 쓰면 다시 이룬다(2일째). 효과는 그날만.
        let dailyStore = WritingStore(url: dir.appendingPathComponent("daily.json"))
        dailyStore.badgeRewards = false
        dailyStore.eventChance = 0
        dailyStore.disasterChance = 0
        dailyStore.luckChance = 0
        _ = dailyStore.apply(days: days(1), now: now)
        w = dailyStore.apply(days: days(15_000_001), now: now)
        check(w.dailyCounts["day_10k"]?.total == 1, "매일 성과: 오늘 1만 자 → 1번")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let tomorrowNoon = tomorrow.addingTimeInterval(12 * 3600)
        w = dailyStore.apply(days: [DayUsage(day: today, tokens: 15_000_001), DayUsage(day: tomorrow, tokens: 11_000_000)], now: tomorrowNoon)
        check(w.dailyCounts["day_10k"]?.total == 2 && w.dailyCounts["day_10k"]?.streak == 2, "매일 성과: 내일 또 1만 자 → 2번, 2일째")
        check(w.dailyCounts["day_100k"] == nil && !w.perks.itemTokens.isLess(than: 1), "매일 성과: 10만 자는 아직, 효과 없음")
        // 순서: 7번째 책(오만과 편견)을 다음에 쓰고, 디킨스를 몰아 쓴다. 지금 책과 지나간 자리는 그대로.
        let orderStore = WritingStore(url: dir.appendingPathComponent("order.json"))
        orderStore.badgeRewards = false
        orderStore.eventChance = 0
        orderStore.disasterChance = 0
        orderStore.luckChance = 0
        _ = orderStore.apply(days: days(1), now: now)
        w = orderStore.apply(days: days(1_000_001), now: now)
        check(w.bookIndex == 0 && w.nextBook?.title == Library.books[1].title, "순서: 처음엔 서재 순서")
        orderStore.writeNext(6)
        w = orderStore.progress
        check(w.roundOrder.prefix(3) == [0, 6, 1] && w.nextBook?.title == Library.books[6].title, "순서: 7번째를 다음에 → \(w.roundOrder.prefix(4))")
        orderStore.focus(author: "Dickens")
        w = orderStore.progress
        let dickens = Library.books.indices.filter { Library.books[$0].authorShort == "Dickens" }
        check(Array(w.roundOrder[1..<(1 + dickens.count)]) == dickens && w.roundOrder[1 + dickens.count] == 6,
              "순서: 디킨스 몰아 쓰기 → \(w.roundOrder.prefix(7))")
        // 첫 책을 넘기면 탈고 기록이 생기고, 다음 책은 바뀐 순서를 따른다.
        w = orderStore.apply(days: days(1_000_001 + 178_000_000), now: now)
        check(w.finished.count == 1 && w.bookIndex == dickens[0] && orderStore.state.finishNotes.count == 1
              && orderStore.state.finishNotes.first?.book == Library.books[0].file,
              "순서·탈고: 햄릿 탈고 → 다음은 크리스마스 캐럴, 탈고 기록 1건")
        // 판매: 탈고와 같은 갱신에 들어온 토큰부터 팔린다. 그 뒤 100만 토큰이면 신간(3배)·난수 0.5(흔들림 1.0)로 30부 더.
        let soldAtFinish = w.sales(of: Library.books[0])
        orderStore.random = { 0.5 }
        w = orderStore.apply(days: days(1_000_001 + 179_000_000), now: now)
        // 부수는 소수로 쌓여서 정수로 보면 29~30 이 나온다.
        check(soldAtFinish > 0 && (29...30).contains(w.sales(of: Library.books[0]) - soldAtFinish) && w.totalSales == w.sales(of: Library.books[0]),
              "판매: 탈고 때 \(soldAtFinish)부, 100만 토큰에 \(w.sales(of: Library.books[0]) - soldAtFinish)부 더 (기대 30)")
        // 단계: 1,000부를 넘기면 초판 완판 소식.
        w = orderStore.apply(days: days(1_000_001 + 179_000_000 + 40_000_000), now: now)
        check(w.salesTier(of: Library.books[0]) == .firstPrint && orderStore.unnotifiedSales.first?.tier == .firstPrint,
              "판매: \(w.sales(of: Library.books[0]))부 → 초판 완판 소식")
        // 기분 판정: 조건이 2번 연속 맞아야 바뀌고, 농땡이에서 입력이 오면 바로 깨어난다.
        var judge = MoodJudge()
        let waiting = MoodInput(userIdle: 10, tokenIdle: 15 * 60)
        check(judge.update(waiting).changed == nil && judge.update(waiting).changed == .waiting, "기분: 눈치는 2번 연속 뒤에")
        check(judge.update(MoodInput(userIdle: 20 * 60, tokenIdle: 60)).changed == nil
              && judge.update(MoodInput(userIdle: 20 * 60, tokenIdle: 60)).changed == .alone, "기분: 혼자")
        let quiet = MoodInput(userIdle: 40 * 60, tokenIdle: 40 * 60)
        _ = judge.update(quiet)
        check(judge.update(quiet).changed == .slacking, "기분: 농땡이")
        let back = judge.update(MoodInput(userIdle: 2, tokenIdle: 41 * 60))
        check(back.changed == .waiting && back.caught, "기분: 손이 닿으면 바로 깨어남(들킴)")
        check(MoodJudge.candidate(for: MoodInput(userIdle: 40 * 60, tokenIdle: 40 * 60, guestActive: true), slackAfter: 1800) == .focused,
              "기분: 손님 앞에서는 농땡이 없음")
        check(MoodJudge.candidate(for: MoodInput(userIdle: 1, tokenIdle: 1, eventActive: true), slackAfter: 1800) == .paused, "기분: 돌발 상황이면 멈춤")
        check(QuietHours.isQuiet(at: Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: now)!) == QuietHours.enabled
              && !QuietHours.isQuiet(at: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now)!),
              "방해 금지: 새벽 2시는 조용, 낮 12시는 보냄")
        // 방재 아이템: 금고가 있으면 재해에 쓰이고 잃는 것이 없다.
        let shielded = WritingStore(url: dir.appendingPathComponent("shield.json"))
        shielded.badgeRewards = false
        shielded.random = { 0.5 }
        shielded.eventChance = 0
        shielded.disasterChance = 0
        shielded.luckChance = 0
        _ = shielded.apply(days: days(1), now: now)
        _ = shielded.apply(days: days(10_000_001), now: now)
        shielded.giveForTesting(.safe)
        let kept = shielded.strike(Disasters.flood, now: now)
        w = shielded.progress
        check(kept == 0 && w.count(.safe) == 0 && Int(w.totalCharacters) == 10_000 && w.recentEvents.first?.endedBy == "safe",
              "방재: 금고가 쓰이고 글자 그대로 \(Int(w.totalCharacters))")
        check(w.badges["shield_1"] != nil, "성과: 대비 뱃지")
        // 거절 감소: 두 번 거절당한 뒤에는 25 − 20 = 5% 라 난수 0.1 은 통한다.
        var decayed = stubborn.state
        decayed.counters = [:]
        decayed.event = ActiveEvent(id: AuthorEvents.away.id, startedAt: now, endsAt: now.addingTimeInterval(3600), refusals: 2)
        let decayURL = dir.appendingPathComponent("decay.json")
        try? JSONEncoder().encode(decayed).write(to: decayURL)
        let decayStore = WritingStore(url: decayURL)
        decayStore.badgeRewards = false
        decayStore.random = { 0.1 }
        decayStore.giveForTesting(.messenger)
        w = decayStore.use(.messenger, now: now.addingTimeInterval(30 * 60))
        check(w.event == nil && w.count(.messenger) == 0 && w.note?.kind == .cured && ItemKind.messenger.curedLines.contains(w.note?.text ?? ""),
              "거절 감소·대체 아이템: 심부름꾼이 통함 \"\(w.note?.text ?? "")\"")
        // 교환: 커피 3 → 등잔 1
        decayStore.giveForTesting(.coffee); decayStore.giveForTesting(.coffee); decayStore.giveForTesting(.coffee)
        w = decayStore.exchange(.coffee, for: .lamp)
        check(w.count(.coffee) == 0 && w.count(.lamp) == 1, "교환: 커피 3 → 등잔 1")
        check(w.facts.exchanges == 1 && w.facts.persistence == 1, "셈: 교환 \(w.facts.exchanges)번, 끈기 \(w.facts.persistence)번 (기대 1, 1)")
        // 행운: 영감의 날엔 100만 토큰이 2,000자, 손님 작가가 있으면 돌발 상황이 안 생기고, 선금은 아이템 3개.
        let lucky = WritingStore(url: dir.appendingPathComponent("luck.json"))
        lucky.badgeRewards = false
        lucky.eventChance = 0
        lucky.disasterChance = 0
        lucky.luckChance = 0
        lucky.luckChance = 0
        lucky.random = { 0.5 }
        _ = lucky.apply(days: days(1), now: now)
        lucky.grant(Lucks.inspiration, now: now)
        w = lucky.apply(days: days(1_000_001), now: now)
        check(Int(w.totalCharacters) == 2_000 && w.luckEvent?.id == Lucks.inspiration.id, "행운: 영감의 날 \(Int(w.totalCharacters))자 (기대 2000)")
        w = lucky.apply(days: days(2_000_001), now: now.addingTimeInterval(61 * 60))
        check(w.luck == nil && Int(w.totalCharacters) == 3_000 && w.note?.kind == .luck, "행운: 61분 뒤 끝남, 평소 속도 \(Int(w.totalCharacters))자")
        lucky.eventChance = 1
        lucky.grant(Lucks.guest, now: now, author: "Shakespeare")
        w = lucky.apply(days: days(4_000_001), now: now)
        check(w.event == nil && w.guestAuthor != nil && w.guestAuthor != "Shakespeare", "행운: 손님 작가 \(w.guestAuthor ?? "-") 있는 동안 돌발 상황 없음")
        lucky.eventChance = 0
        let itemsBefore = ItemKind.allCases.reduce(0) { $0 + w.count($1) }
        lucky.grant(Lucks.advance, now: now)
        w = lucky.progress
        check(ItemKind.allCases.reduce(0) { $0 + w.count($1) } == itemsBefore + Balance.advanceItems && w.recentEvents.first?.event == Lucks.advance.id,
              "행운: 선금 아이템 \(Balance.advanceItems)개")
        // 선택지 사건: 답하면 보정이 붙어 글자가 늘고(새 펜 +10%), 아이템이 하나 줄고, 시간이 지나면 보정이 사라진다.
        // 답이 없으면 기한이 지난 뒤 작가가 알아서 고르고 알림이 예약된다.
        let decider = WritingStore(url: dir.appendingPathComponent("dilemma.json"))
        decider.badgeRewards = false
        decider.eventChance = 0; decider.disasterChance = 0; decider.luckChance = 0; decider.dilemmaChance = 0
        decider.random = { 0 }
        _ = decider.apply(days: days(1), now: now)
        decider.offer(Dilemmas.byID("pen")!, now: now)
        w = decider.progress
        check(w.dilemma?.id == "pen" && w.dilemmaKind?.options.count == 2 && decider.unnotifiedDilemma != nil, "사건: 낡은 펜 제시, 알림 대기")
        decider.giveForTesting(.coffee)
        w = decider.choose(0, now: now)
        check(w.dilemma == nil && w.boostSummary.characters == 1.1 && w.count(.coffee) == 0 && w.decisions.first?.option == "새 펜을 산다"
              && w.note?.kind == .dilemma && w.boosts.first?.source == "낡은 펜", "사건: 답하면 글자 +10%, 아이템 -1 \"\(w.note?.text ?? "")\"")
        w = decider.apply(days: days(1_000_001), now: now)
        check(Int(w.totalCharacters) == 1_100, "사건: 보정 중 100만 토큰 \(Int(w.totalCharacters))자 (기대 1100)")
        w = decider.apply(days: days(2_000_001), now: now.addingTimeInterval(25 * 3600))
        check(w.boosts.isEmpty && Int(w.totalCharacters) == 2_100, "사건: 25시간 뒤 보정 끝 \(Int(w.totalCharacters))자 (기대 2100)")
        decider.offer(Dilemmas.byID("cat")!, now: now)
        w = decider.apply(days: days(2_000_001), now: now.addingTimeInterval(3 * 3600))
        check(w.dilemma == nil && w.decisions.first?.auto == true && w.decisions.first?.dilemma == "cat" && decider.state.note?.notified == false,
              "사건: 기한이 지나면 작가가 알아서 고름 \"\(w.note?.text ?? "")\"")
        check(w.facts.decisions == 1 && w.badges["decided"] != nil, "성과: 결단(직접 답한 것만 셈)")
        check(Dilemmas.all.allSatisfy { $0.options.count >= 2 && !$0.texts.isEmpty && $0.options.allSatisfy { !$0.outcomes.isEmpty } }
              && Set(Dilemmas.all.map(\.id)).count == Dilemmas.all.count, "사건: \(Dilemmas.all.count)가지, 선택지 \(Dilemmas.all.reduce(0) { $0 + $1.options.count })개")
        // 비평: 탈고하면 비평이 예약되고 몇 시간 뒤 실린다. 지금 쓰는 작가의 책이면 보정이 붙고, 별점대로 더 팔린다.
        let critic = WritingStore(url: dir.appendingPathComponent("review.json"))
        critic.badgeRewards = false
        critic.eventChance = 0; critic.disasterChance = 0; critic.luckChance = 0; critic.dilemmaChance = 0
        critic.random = { 0.99 }
        _ = critic.apply(days: days(1), now: now)
        let firstBook = Library.books[0]
        let sameAuthor = Library.books[1].authorShort == firstBook.authorShort
        w = critic.apply(days: days(1 + firstBook.characters * 1_000 + 1_000_000), now: now)
        let scheduled = critic.state.reviews.first
        check(w.finished.count == 1 && scheduled?.published != true && scheduled?.text.isEmpty == true && w.reviews.isEmpty
              && w.awaitingPublisher?.book == firstBook.file,
              "비평: 탈고하면 비평이 예약되고(별점은 실릴 때), 출판사 고르기가 기다림")
        let soldBefore = w.sales(of: firstBook)
        w = critic.apply(days: days(1 + firstBook.characters * 1_000 + 2_000_000), now: now.addingTimeInterval(37 * 3600))
        check(w.reviews.count == 1 && w.review(of: firstBook)?.stars == 5 && critic.unnotifiedReviews.count == 1 && w.sales(of: firstBook) > soldBefore,
              "비평: 37시간 뒤 실림, 알림 대기 \"\(w.reviews.first?.text ?? "")\"")
        check((w.reviews.first?.affected == true) == sameAuthor && (sameAuthor ? w.boostSummary.characters == 1.15 && w.note?.kind == .review : w.boosts.isEmpty),
              "비평: \(sameAuthor ? "같은 작가라 글자 +15%" : "다른 작가라 영향 없음")")
        check(w.facts.fiveStars == 1 && w.badges["five_stars"] != nil, "성과: 별 다섯")
        let texts = Set((0..<40).map { i in
            Critics.text(for: 3, days: 5, events: 1, lost: 0, title: "책", author: "작가", voice: .dry,
                         rolls: [Double(i % 7) / 7, Double(i % 4) / 4, Double(i % 3) / 3])
        })
        check(texts.count >= 20, "비평: 같은 조건에서도 문장이 \(texts.count)가지")
        check(Format.resolve("캐럴(과|와) 포(이|가) 햄릿(을|를) 디킨스(으로|로) 3(이|가)") == "캐럴과 포가 햄릿을 디킨스로 3이"
              && Format.resolve("오스틴(은|는) 괴테(과|와)") == "오스틴은 괴테와", "조사: 받침에 맞춤 \"\(Format.resolve("캐럴(과|와) 포(이|가)"))\"")
        check(!texts.contains { $0.contains("(") }, "비평: 조사 표시가 남지 않음")
        check(Decor.all.allSatisfy { $0.unlock.map { Achievements.byID($0) != nil } ?? true } && Set(Decor.all.map(\.id)).count == Decor.all.count,
              "꾸미기: 장신구 \(Decor.all.count)개가 모두 있는 성과로 열림")
        check(Decor.apply(Portraits.rows("Goethe"), accessory: Decor.byID("monocle")!)[Portraits.eyeRow - 1].contains("y")
              && Portraits.all.allSatisfy { $0.1.count == Portraits.size && $0.1.allSatisfy { $0.count == Portraits.size } && Array($0.1[Portraits.eyeRow])[Portraits.eyeColumns.0] == "e" },
              "꾸미기: 외알 안경이 눈 줄에 붙고, 초상화 8장이 모두 24×24에 눈 자리가 같음")
        check(Expression.happy.apply(Portraits.rows("Poe"))[Portraits.mouthRow].filter { $0 == "m" }.count == 4
              && Expression.tired.apply(Portraits.rows("Austen"))[Portraits.eyeRow + 1].contains("e"), "표정: 웃음은 입이 넓고 피곤은 눈이 내려감")
        let quarrel = Quarrels.exchange(host: "Shakespeare", guest: "Wilde", rolls: (0, 0))
        check(quarrel.host == Quarrels.pairs[0].aLine && Quarrels.exchange(host: "Wilde", guest: "Shakespeare", rolls: (0, 0)).host == Quarrels.pairs[0].bLine,
              "말다툼: 둘의 자리가 바뀌면 말도 바뀜")
        // 날씨: 같은 날은 같은 날씨, 계절마다 나올 수 있는 것만 나온다.
        Weather.forced = nil
        let jan = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let weatherDays = (0..<365).map { Weather.of(jan.addingTimeInterval(Double($0) * 86_400)) }
        check(Weather.of(jan) == Weather.of(jan.addingTimeInterval(3600 * 20)) && Set(weatherDays).count >= 5
              && !(0..<59).contains { weatherDays[$0] == .heat } && !(150..<240).contains { weatherDays[$0] == .snow },
              "날씨: 하루 동안 같고 1년에 \(Set(weatherDays).count)가지, 겨울엔 더위 없고 여름엔 눈 없음")
        // 천문(해·달): 시간대 표준 좌표 파싱 및 정오·자정·계절별 고도와 달 위상 검증
        let seoulCoord = Celestial.parseISO6709("+3733+12658")
        let sydneyCoord = Celestial.parseISO6709("-3352+15113")
        check(seoulCoord != nil && abs((seoulCoord?.latitude ?? 0) - 37.55) < 0.01 && (sydneyCoord?.latitude ?? 0) < -33,
              "천문: ISO 6709 위경도 파싱 서울(\(seoulCoord?.latitude ?? 0)), 시드니(\(sydneyCoord?.latitude ?? 0))")
        var seoulCal = Calendar(identifier: .gregorian)
        seoulCal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let summerNoon = seoulCal.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12, minute: 30))!
        let winterNoon = seoulCal.date(from: DateComponents(year: 2026, month: 12, day: 21, hour: 12, minute: 30))!
        let winterMidnight = seoulCal.date(from: DateComponents(year: 2026, month: 12, day: 21, hour: 0, minute: 30))!
        let snapSummer = Celestial.snapshot(at: summerNoon, coordinate: seoulCoord!)
        let snapWinter = Celestial.snapshot(at: winterNoon, coordinate: seoulCoord!)
        let snapMidnight = Celestial.snapshot(at: winterMidnight, coordinate: seoulCoord!)
        check(snapSummer.sun.altitude > 70 && snapWinter.sun.altitude > 25 && snapSummer.sun.altitude > snapWinter.sun.altitude
              && (0.4...0.6).contains(snapSummer.sun.progress) && snapMidnight.sun.altitude < -40
              && (0...1).contains(snapSummer.moon.phase) && !snapSummer.summaryLine.isEmpty,
              "천문: 하지 남중 \(Int(snapSummer.sun.altitude))° > 동지 남중 \(Int(snapWinter.sun.altitude))°, 자정 \(Int(snapMidnight.sun.altitude))°")
        Weather.forced = .cloudy
        // 영감 게이지: 읽기 토큰으로 차고, 가득 차면 영감의 날을 직접 켠다. 처음 보는 날은 기준만 적는다.
        let reader = WritingStore(url: dir.appendingPathComponent("gauge.json"))
        reader.badgeRewards = false
        reader.eventChance = 0; reader.disasterChance = 0; reader.luckChance = 0; reader.dilemmaChance = 0
        reader.random = { 0.5 }
        Weather.forced = .clear
        _ = reader.apply(days: [DayUsage(day: today, tokens: 1, read: 500_000_000)], now: now)
        w = reader.apply(days: [DayUsage(day: today, tokens: 2, read: 500_000_000 + Balance.inspirationGaugeTokens / 2)], now: now)
        check(abs(w.inspirationFraction - 0.5) < 0.001 && !w.inspirationReady, "영감 게이지: 이미 있던 읽기 토큰은 빼고 절반 \(Format.percent(w.inspirationFraction * 100))")
        w = reader.apply(days: [DayUsage(day: today, tokens: 3, read: 500_000_000 + Balance.inspirationGaugeTokens * 2)], now: now)
        check(w.inspirationReady && reader.inspirationReadyUnnotified, "영감 게이지: 가득(넘치지 않음), 알림 대기")
        w = reader.igniteInspiration(now: now)
        check(w.luckEvent?.id == Lucks.inspiration.id && w.inspirationFraction == 0 && w.facts.ignitions == 1, "영감 게이지: 켜면 영감의 날, 게이지 0")
        // 날씨 효과: 비 오는 날 글자 +5%.
        Weather.forced = .rain
        let rainy = WritingStore(url: dir.appendingPathComponent("rain.json"))
        rainy.badgeRewards = false
        rainy.eventChance = 0; rainy.disasterChance = 0; rainy.luckChance = 0; rainy.dilemmaChance = 0
        _ = rainy.apply(days: days(1), now: now)
        w = rainy.apply(days: days(1_000_001), now: now)
        check(Int(w.totalCharacters) == 1_050 && w.weather == .rain, "날씨: 비 오는 날 100만 토큰 \(Int(w.totalCharacters))자 (기대 1050)")
        Weather.forced = .cloudy
        WritingStore.deadlinesEnabled = true
        // 마감: 첫 주엔 글자 과제, 닿으면 지킴(아이템 2, 판매 +20%), 다음 주 과제를 안 지키면 펑크(거절 +10%p).
        let editor = WritingStore(url: dir.appendingPathComponent("deadline.json"))
        editor.badgeRewards = false
        editor.eventChance = 0; editor.disasterChance = 0; editor.luckChance = 0; editor.dilemmaChance = 0
        editor.random = { 0 }
        let monday = WritingStore.weekStart(of: now)
        _ = editor.apply(days: [DayUsage(day: monday, tokens: 1)], now: monday)
        w = editor.apply(days: [DayUsage(day: monday, tokens: 1_000_001)], now: monday)
        check(w.deadline?.kind == .characters && w.deadline?.target == 10_000 && editor.unnotifiedDeadline != nil && w.deadlineProgress == 1_000,
              "마감: 첫 주 과제 \(w.deadline?.title ?? "-"), 진행 \(w.deadlineProgress)")
        editor.markDeadlineNotified()
        let itemsBeforeDeadline = ItemKind.allCases.reduce(0) { $0 + w.count($1) }
        w = editor.apply(days: [DayUsage(day: monday, tokens: 10_000_001)], now: monday.addingTimeInterval(3600))
        check(w.deadline?.met == true && ItemKind.allCases.reduce(0) { $0 + w.count($1) } == itemsBeforeDeadline + Balance.deadlineItems
              && w.boostSummary.sales == Balance.deadlineSalesBoost && w.note?.kind == .deadline && w.facts.deadlinesMet == 1,
              "마감: 1만 자에 닿으면 지킴, 아이템 +\(Balance.deadlineItems), 판매 +20% \"\(w.note?.text ?? "")\"")
        editor.markDeadlineNotified()
        let nextMonday = monday.addingTimeInterval(7 * 86_400)
        w = editor.apply(days: [DayUsage(day: monday, tokens: 10_000_001), DayUsage(day: nextMonday, tokens: 1)], now: nextMonday)
        check(w.deadline?.weekStart == nextMonday && w.deadline?.target == 15_000 && w.weeklyCard?.deadlineMet == true,
              "마감: 다음 주 과제 \(w.deadline?.title ?? "-") (지난주 1만 자의 1.1배 올림), 돌아보기에 지킴")
        editor.markDeadlineNotified()
        let thirdMonday = nextMonday.addingTimeInterval(7 * 86_400)
        w = editor.apply(days: [DayUsage(day: monday, tokens: 10_000_001), DayUsage(day: nextMonday, tokens: 1), DayUsage(day: thirdMonday, tokens: 1)], now: thirdMonday)
        check(editor.state.deadline?.failed == true && w.deadline == nil && w.boostSummary.refusal == Balance.deadlinePenalty && w.facts.deadlinesMissed == 1 && editor.unnotifiedDeadline?.resultNotified == false,
              "마감: 안 지키고 주가 바뀌면 펑크, 거절 +10%p \"\(w.note?.text ?? "")\"")
        editor.markDeadlineNotified()
        w = editor.apply(days: [DayUsage(day: monday, tokens: 10_000_001), DayUsage(day: nextMonday, tokens: 1), DayUsage(day: thirdMonday, tokens: 1)], now: thirdMonday)
        check(w.deadline?.weekStart == thirdMonday && w.deadline?.failed != true, "마감: 펑크를 알린 뒤 새 과제 \(w.deadline?.title ?? "-")")
        // 카페인: 오늘 커피·홍차로 5번 끝냈으면 졸음 대신 글이 막히고, 어제 그랬으면 오늘은 졸음이 더 온다.
        var wired = WritingState()
        wired.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 100)
        for i in 0..<5 {
            var r = EventRecord(event: "nap", book: nil, startedAt: now.addingTimeInterval(Double(-i) * 600 - 60))
            r.endedAt = now.addingTimeInterval(Double(-i) * 600)
            r.endedBy = i % 2 == 0 ? "coffee" : "tea"
            wired.eventLog.append(r)
        }
        let wiredURL = dir.appendingPathComponent("caffeine.json")
        try? JSONEncoder().encode(wired).write(to: wiredURL)
        let caffeine = WritingStore(url: wiredURL)
        caffeine.badgeRewards = false
        caffeine.disasterChance = 0; caffeine.luckChance = 0; caffeine.dilemmaChance = 0
        caffeine.eventChance = 1
        let napRoll = (Double(AuthorEvents.common.firstIndex(of: AuthorEvents.nap)!) + 0.5) / Double(AuthorEvents.common.count)
        caffeine.random = { napRoll }
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        w = caffeine.apply(days: days(1_000_001), now: noon)
        check(w.cupsToday == 5 && w.caffeinated && w.event?.id == AuthorEvents.block.id, "카페인: 5잔이면 졸음 대신 글 막힘 (\(w.event?.id ?? "-"))")
        var hung = wired
        hung.eventLog = wired.eventLog.map { r in
            var c = EventRecord(event: r.event, book: nil, startedAt: r.startedAt.addingTimeInterval(-86_400))
            c.endedAt = r.endedAt?.addingTimeInterval(-86_400); c.endedBy = r.endedBy
            return c
        }
        let hungURL = dir.appendingPathComponent("hangover.json")
        try? JSONEncoder().encode(hung).write(to: hungURL)
        let hangover = WritingStore(url: hungURL)
        hangover.badgeRewards = false
        hangover.disasterChance = 0; hangover.luckChance = 0; hangover.dilemmaChance = 0
        hangover.eventChance = 1
        let blockRoll = (Double(AuthorEvents.common.firstIndex(of: AuthorEvents.block)!) + 0.5) / Double(AuthorEvents.common.count)
        // 난수 순서: 재해, 행운, 사건, 상황 추첨, 상황 고름(글 막힘), 숙취 판정(25% 안이라 졸음으로)
        var hangRolls = [0.5, 0.5, 0.5, 0.0, blockRoll, 0.1]
        hangover.random = { hangRolls.isEmpty ? 0.5 : hangRolls.removeFirst() }
        w = hangover.apply(days: days(1_000_001), now: noon)
        check(w.cupsToday == 0 && w.event?.id == AuthorEvents.nap.id, "카페인: 어제 5잔이면 오늘 졸음이 더 옴 (\(w.event?.id ?? "-"))")
        check(w.facts.mostCupsInDay == 5, "카페인: 하루 최다 \(w.facts.mostCupsInDay)잔")
        let hand = Handoffs.exchange(from: "Shakespeare", to: "Dickens", rolls: (0, 0))
        check(hand.leaving == Handoffs.pairs[0].leaving && !Handoffs.exchange(from: "Austen", to: "Poe", rolls: (0.3, 0.9)).leaving.contains("{"),
              "교대: 둘의 말이 있으면 그것을, 없으면 이름을 넣은 말을")
        // 원문: 문자열+체크포인트로 자른 결과가 글자 배열로 자른 것과 같고, 글자 수가 목록과 맞고, 읽어 둔 책은 둘까지만.
        if let first = Library.books.first, let text = Library.text(of: first) {
            let chars = Array(text.string)
            func naive(_ count: Int, _ tail: Int) -> String {
                let end = min(max(0, count), chars.count)
                var start = max(0, end - tail)
                if start > 0, let space = chars[start..<end].firstIndex(where: { $0 == " " || $0 == "\n" }) { start = space + 1 }
                return String(chars[start..<end])
            }
            let probes = [0, 1, 63, 64, 65, 127, 128, 129, 1_000, 12_345, chars.count - 1, chars.count, chars.count + 50]
            let same = probes.allSatisfy { Library.tail(of: first, upTo: $0, length: 420) == naive($0, 420) && Library.tail(of: first, upTo: $0, length: 200) == naive($0, 200) }
            check(same && Library.prefix(of: first, count: 777) == String(chars.prefix(777)) && text.count == chars.count,
                  "원문: 체크포인트로 자른 끝부분이 글자 배열과 같음 (\(first.displayTitle))")
        }
        let longest = Library.books.max { $0.characters < $1.characters }
        var footprintBefore = 0, footprintAfter = 0
        func footprint() -> Int {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
            let result = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) } }
            return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
        }
        _ = longest.flatMap { Library.text(of: $0) }
        footprintBefore = footprint()
        var mismatched: [String] = []
        for book in Library.books {
            autoreleasepool {
                if Library.text(of: book)?.count != book.characters { mismatched.append(book.file) }
            }
        }
        footprintAfter = footprint()
        check(mismatched.isEmpty, "원문: \(Library.books.count)권 글자 수가 목록과 맞음" + (mismatched.isEmpty ? "" : " (다름: \(mismatched))"))
        check(Library.cachedCount <= Library.cacheLimit, "원문: 모두 읽어도 기억하는 책은 \(Library.cachedCount)권 (최대 \(Library.cacheLimit))")
        if let longest, let text = Library.text(of: longest) {
            let bytes = text.string.utf8.count
            let grew = footprintAfter - footprintBefore
            print("info 원문 메모리: 가장 긴 책 \(longest.displayTitle) \(Format.integer(text.count))자 · 본문 \(bytes / 1024)KB · 체크포인트 \(text.checkpoints.count * MemoryLayout<String.Index>.size / 1024)KB · 모두 읽는 동안 늘어난 상주 메모리 \(grew / 1_048_576)MB")
            check(grew < bytes * 6, "원문: 메모리가 본문 크기의 몇 배 안에 머묾")
        }
        // 압축: zlib 로 줄였다 풀면 같다.
        if let first = Library.books.first, let text = Library.text(of: first), let packed = Library.pack(text.string),
           let back = try? (packed as NSData).decompressed(using: .zlib) as Data {
            check(String(data: back, encoding: .utf8) == text.string && packed.count * 2 < text.string.utf8.count,
                  "압축: \(first.displayTitle) \(text.string.utf8.count / 1024)KB → \(packed.count / 1024)KB, 풀면 같음")
        }
        // 작업실: 아이템으로 가구를 사면 아이템이 줄고 효과가 붙는다(탁상등: 밤 글자 +10%). 모자라면 못 산다.
        let home = WritingStore(url: dir.appendingPathComponent("studio.json"))
        home.badgeRewards = false
        home.eventChance = 0; home.disasterChance = 0; home.luckChance = 0; home.dilemmaChance = 0
        home.random = { 0.5 }
        _ = home.apply(days: days(1), now: now)
        for _ in 0..<3 { home.giveForTesting(.candle) }
        home.giveForTesting(.lamp); home.giveForTesting(.lamp)
        w = home.buy(Studio.byID("lamp")!, now: now)
        check(w.studio == ["lamp"] && w.count(.candle) == 0 && w.count(.lamp) == 0 && w.studioPerks.nightCharacters == 1.1 && w.badges["housewarming"] != nil,
              "작업실: 탁상등을 들이면 초 3·등잔 2가 나가고 집들이 뱃지")
        w = home.buy(Studio.byID("chair")!, now: now)
        check(w.studio.count == 1, "작업실: 아이템이 모자라면 못 삼")
        let late = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: now)!
        w = home.apply(days: days(1_000_001), now: late)
        check(Int(w.totalCharacters) == 1_100, "작업실: 탁상등 덕에 밤 100만 토큰 \(Int(w.totalCharacters))자 (기대 1100)")
        check(Studio.all.allSatisfy { f in f.cost.allSatisfy { $0.1 <= Balance.itemCap } } && Set(Studio.all.map(\.id)).count == Studio.all.count,
              "작업실: 가구 \(Studio.all.count)개, 값은 모두 가질 수 있는 수 안")
        // 출판사: 탈고하면 고르기를 기다리고, 문예는 선금 없이 별점이 후하고, 하루 지나면 대형으로 가며 선금이 온다.
        check(Critics.stars(days: 30, events: 3, lost: 0, characters: 28_000, roll: 0.5) == 2
              && Critics.stars(days: 30, events: 3, lost: 0, characters: 28_000, roll: 0.5, bonus: Publisher.literary.starsBonus) == 3,
              "출판사: 같은 책도 문예 출판사면 별이 하나 더")
        let press = WritingStore(url: dir.appendingPathComponent("press.json"))
        press.badgeRewards = false
        press.eventChance = 0; press.disasterChance = 0; press.luckChance = 0; press.dilemmaChance = 0
        press.random = { 0.5 }
        _ = press.apply(days: days(1), now: now)
        w = press.apply(days: days(1 + firstBook.characters * 1_000 + 1_000), now: now)
        let pressItems = ItemKind.allCases.reduce(0) { $0 + w.count($1) }
        guard let waiting = w.awaitingPublisher else { check(false, "출판사: 탈고 뒤 고르기 기다림"); return print("FAILED") }
        w = press.choosePublisher(.literary, for: waiting.id, now: now)
        check(w.awaitingPublisher == nil && w.finishCards.first?.publisher == "literary" && ItemKind.allCases.reduce(0) { $0 + w.count($1) } == pressItems
              && w.facts.publishersUsed == 1 && w.note?.kind == .publisher, "출판사: 문예로 보내면 선금 없음, 기록에 남음")
        let lazy = WritingStore(url: dir.appendingPathComponent("lazy.json"))
        lazy.badgeRewards = false
        lazy.eventChance = 0; lazy.disasterChance = 0; lazy.luckChance = 0; lazy.dilemmaChance = 0
        lazy.random = { 0.5 }
        _ = lazy.apply(days: days(1), now: now)
        w = lazy.apply(days: days(1 + firstBook.characters * 1_000 + 1_000), now: now)
        let lazyItems = ItemKind.allCases.reduce(0) { $0 + w.count($1) }
        w = lazy.apply(days: days(1 + firstBook.characters * 1_000 + 2_000), now: now.addingTimeInterval(25 * 3600))
        check(w.finishCards.isEmpty && lazy.state.finishNotes.first?.publisher == "major" && ItemKind.allCases.reduce(0) { $0 + w.count($1) } == lazyItems + Balance.publisherAdvance,
              "출판사: 하루 안 고르면 대형으로, 선금 \(Balance.publisherAdvance)개")
        // 내기: 손님이 있을 때 걸리고, 받아서 목표를 채우면 아이템과 판매 보정, 시간이 지나면 아이템을 잃는다.
        let gambler = WritingStore(url: dir.appendingPathComponent("bet.json"))
        gambler.badgeRewards = false
        gambler.eventChance = 0; gambler.disasterChance = 0; gambler.luckChance = 0; gambler.dilemmaChance = 0
        gambler.random = { 0.5 }
        _ = gambler.apply(days: days(1), now: now)
        check(!gambler.offerBet(now: now), "내기: 손님이 없으면 안 검")
        gambler.grant(Lucks.guest, now: now, author: "Shakespeare")
        check(gambler.offerBet(now: now) && gambler.state.bet?.pending == true && gambler.state.bet?.target == 2_000 && gambler.state.note?.kind == .bet,
              "내기: 손님이 \(gambler.state.bet?.target ?? 0)자 내기를 검 \"\(gambler.state.note?.text ?? "")\"")
        check(!gambler.offerBet(now: now), "내기: 같은 손님 때 두 번 안 검")
        w = gambler.answerBet(accept: true, now: now)
        check(w.bet?.running == true, "내기: 받음")
        let betItems = ItemKind.allCases.reduce(0) { $0 + w.count($1) }
        w = gambler.apply(days: days(1 + 2_001_000), now: now.addingTimeInterval(60))
        check(w.bet?.won == true && ItemKind.allCases.reduce(0) { $0 + w.count($1) } == betItems + Balance.betWinItems && w.boostSummary.sales == Balance.betSalesBoost
              && w.facts.betsWon == 1 && w.note?.kind == .bet, "내기: 목표를 채우면 이김, 아이템 +\(Balance.betWinItems), 판매 +50% \"\(w.note?.text ?? "")\"")
        let loser = WritingStore(url: dir.appendingPathComponent("lose.json"))
        loser.badgeRewards = false
        loser.eventChance = 0; loser.disasterChance = 0; loser.luckChance = 0; loser.dilemmaChance = 0
        loser.random = { 0.5 }
        _ = loser.apply(days: days(1), now: now)
        loser.grant(Lucks.guest, now: now, author: "Shakespeare")
        loser.giveForTesting(.coffee); loser.giveForTesting(.ink); loser.giveForTesting(.bell)
        _ = loser.offerBet(now: now)
        _ = loser.answerBet(accept: true, now: now)
        w = loser.apply(days: days(1), now: now.addingTimeInterval(4 * 3600))
        check(w.facts.betsLost == 1 && ItemKind.allCases.reduce(0) { $0 + w.count($1) } == 3 - Balance.betLoseItems && loser.state.bet?.won == false,
              "내기: 시간이 지나면 짐, 아이템 -\(Balance.betLoseItems) \"\(loser.state.note?.text ?? "")\"")
        let shy = WritingStore(url: dir.appendingPathComponent("shy.json"))
        shy.badgeRewards = false
        shy.eventChance = 0; shy.disasterChance = 0; shy.luckChance = 0; shy.dilemmaChance = 0
        shy.random = { 0.5 }
        _ = shy.apply(days: days(1), now: now)
        shy.grant(Lucks.guest, now: now, author: "Shakespeare")
        _ = shy.offerBet(now: now)
        w = shy.answerBet(accept: false, now: now)
        check(shy.state.bet?.accepted == false && w.bet == nil && !shy.offerBet(now: now), "내기: 사양하면 끝, 다시 안 검")
        // 서점: 이달의 책은 +30%·나머지 -10%, 하루에 한 번만 바꿈. 광고는 아이템 셋으로 2배. 독자 주문은 그 책을 시작하면 채워진다.
        let shop = WritingStore(url: dir.appendingPathComponent("shop.json"))
        shop.badgeRewards = false
        shop.eventChance = 0; shop.disasterChance = 0; shop.luckChance = 0; shop.dilemmaChance = 0
        shop.random = { 0.5 }
        _ = shop.apply(days: days(1), now: now)
        w = shop.apply(days: days(1 + firstBook.characters * 1_000 + 1_000_000), now: now)
        let baseSold = w.sales(of: firstBook)
        w = shop.apply(days: days(1 + firstBook.characters * 1_000 + 2_000_000), now: now)
        let plain = w.sales(of: firstBook) - baseSold
        w = shop.feature(firstBook.file, now: now)
        check(w.featuredBook == firstBook.file && !w.canChangeFeatured, "서점: 이달의 책을 걸면 하루 동안 못 바꿈")
        w = shop.feature(nil, now: now.addingTimeInterval(60))
        check(w.featuredBook == firstBook.file, "서점: 하루 안에는 내리지도 못함")
        let featuredBefore = w.sales(of: firstBook)
        w = shop.apply(days: days(1 + firstBook.characters * 1_000 + 3_000_000), now: now)
        let boosted = w.sales(of: firstBook) - featuredBefore
        check(abs(Double(boosted) / Double(max(1, plain)) - Balance.featuredBoost) < 0.4, "서점: 이달의 책은 평소 \(plain)부에서 \(boosted)부로 (약 \(Balance.featuredBoost)배)")
        for (kind, n) in Balance.adCost { for _ in 0..<n { shop.giveForTesting(kind) } }
        let adItemsBefore = Balance.adCost.map { shop.progress.count($0.0) }
        w = shop.advertise(firstBook.file, now: now)
        check(w.adEnds(for: firstBook) != nil && zip(Balance.adCost, adItemsBefore).allSatisfy { w.count($0.0.0) == $0.1 - $0.0.1 } && w.facts.ads == 1,
              "서점: 광고를 걸면 아이템이 나가고 하루 동안 광고 중")
        let adBefore = w.sales(of: firstBook)
        w = shop.apply(days: days(1 + firstBook.characters * 1_000 + 4_000_000), now: now)
        let advertised = w.sales(of: firstBook) - adBefore
        check(Double(advertised) > Double(boosted) * 1.6, "서점: 광고 중에는 \(advertised)부 (이달의 책만일 때 \(boosted)부)")
        w = shop.apply(days: days(1 + firstBook.characters * 1_000 + 4_000_000), now: now.addingTimeInterval(25 * 3600))
        check(w.adEnds(for: firstBook) == nil && w.canChangeFeatured, "서점: 하루 뒤 광고가 끝나고 이달의 책을 바꿀 수 있음")
        check(shop.offerOrder(now: now) && w.order == nil && shop.progress.order != nil && shop.progress.order?.book != shop.progress.book?.file,
              "서점: 독자가 아직 안 쓴 책을 주문 \"\(shop.state.order?.text ?? "")\"")
        if let ordered = shop.state.order, let index = Library.books.firstIndex(where: { $0.file == ordered.book }) {
            shop.writeNext(index)
            // 지금 책을 끝내면 주문한 책이 시작된다.
            let current = shop.progress.book!
            let remaining = current.characters - shop.progress.charactersInBook
            w = shop.apply(days: days(1 + firstBook.characters * 1_000 + 4_000_000 + (remaining + 10) * 1_000), now: now.addingTimeInterval(26 * 3600))
            check(w.book?.file == ordered.book && w.order == nil && shop.state.order?.fulfilled == true && w.facts.ordersFilled == 1
                  && shop.state.orderBonus[ordered.book] != nil && w.badges["order_1"] != nil,
                  "서점: 주문한 책을 시작하면 채워지고 보너스가 붙음 (\(w.book?.displayTitle ?? "-"))")
        }
        // 서점 사건: 신문 소개는 그 책 판매 1.5배, 학교 주문은 부수가 바로 늘고, 좀도둑은 아이템을 가져가며, 탈고한 책이 없으면 아무 일도 없다.
        let shopEventsStore = WritingStore(url: dir.appendingPathComponent("shopevents.json"))
        shopEventsStore.badgeRewards = false
        shopEventsStore.eventChance = 0; shopEventsStore.disasterChance = 0; shopEventsStore.luckChance = 0; shopEventsStore.dilemmaChance = 0
        shopEventsStore.random = { 0.5 }
        _ = shopEventsStore.apply(days: days(1), now: now)
        check(shopEventsStore.happenInShop(ShopEvents.byID("press"), now: now) == nil, "서점 사건: 탈고한 책이 없으면 없음")
        w = shopEventsStore.apply(days: days(1 + firstBook.characters * 1_000 + 1_000_000), now: now)
        let plainShop = w.sales(of: firstBook)
        w = shopEventsStore.apply(days: days(1 + firstBook.characters * 1_000 + 2_000_000), now: now)
        let normalStep = w.sales(of: firstBook) - plainShop
        let pressed = shopEventsStore.happenInShop(ShopEvents.byID("press"), now: now)
        w = shopEventsStore.progress
        check(pressed?.book == firstBook.file && abs(w.shopMultiplier(for: firstBook) - 1.5) < 0.001 && w.note?.kind == .shop && w.shopLog.first?.event == "press",
              "서점 사건: 신문 소개 \"\(pressed?.text ?? "")\"")
        let beforePress = w.sales(of: firstBook)
        w = shopEventsStore.apply(days: days(1 + firstBook.characters * 1_000 + 3_000_000), now: now)
        let pressedStep = w.sales(of: firstBook) - beforePress
        check(abs(Double(pressedStep) / Double(max(1, normalStep)) - 1.5) < 0.4, "서점 사건: 신문 소개 중 \(pressedStep)부 (평소 \(normalStep)부)")
        let beforeSchool = w.sales(of: firstBook)
        let school = shopEventsStore.happenInShop(ShopEvents.byID("school"), now: now)
        w = shopEventsStore.progress
        check((school?.copies ?? 0) >= 60 && w.sales(of: firstBook) == beforeSchool + (school?.copies ?? 0), "서점 사건: 학교 주문 +\(school?.copies ?? 0)부 바로")
        shopEventsStore.giveForTesting(.coffee)
        let beforeThief = ItemKind.allCases.reduce(0) { $0 + shopEventsStore.progress.count($1) }
        _ = shopEventsStore.happenInShop(ShopEvents.byID("thief"), now: now)
        w = shopEventsStore.progress
        check(ItemKind.allCases.reduce(0) { $0 + w.count($1) } == beforeThief - 1 && w.facts.shopEvents == 3, "서점 사건: 좀도둑이 아이템 하나를 가져감")
        let beforeMice = w.sales(of: firstBook)
        let mice = shopEventsStore.happenInShop(ShopEvents.byID("mice"), now: now)
        w = shopEventsStore.progress
        check((mice?.copies ?? 0) < 0 && w.sales(of: firstBook) == beforeMice + (mice?.copies ?? 0) && !(mice?.text.contains("-") ?? true),
              "서점 사건: 창고의 쥐 \(mice?.copies ?? 0)부 \"\(mice?.text ?? "")\"")
        _ = shopEventsStore.happenInShop(ShopEvents.byID("letters"), now: now)
        w = shopEventsStore.progress
        check(abs(w.inspirationFraction - 0.15) < 0.01, "서점 사건: 독자 편지로 영감 \(Int(w.inspirationFraction * 100))%")
        _ = shopEventsStore.happenInShop(ShopEvents.byID("frontrow"), now: now)
        w = shopEventsStore.progress
        check(w.featuredBook == firstBook.file, "서점 사건: 주인이 \(firstBook.displayTitle)을 앞자리에")
        _ = shopEventsStore.happenInShop(ShopEvents.byID("frontrow"), now: now)
        w = shopEventsStore.progress
        check(w.shopBoosts.contains { $0.source == "매대 앞자리" && $0.value == 1.2 }, "서점 사건: 이미 걸린 책이 있으면 대신 판매 1.2배")
        _ = shopEventsStore.happenInShop(ShopEvents.byID("reserve"), now: now)
        w = shopEventsStore.progress
        check(w.order != nil, "서점 사건: 예약 손님이 독자 주문을 만듦")
        w = shopEventsStore.apply(days: days(1 + firstBook.characters * 1_000 + 3_000_000), now: now.addingTimeInterval(13 * 3600))
        check(w.shopBoosts.isEmpty, "서점 사건: 13시간 뒤 보정이 사라짐")
        let plainDay = ShopEvents.Context(weekend: false, hasPraised: false, weather: .clear, month: 6, night: false, books: 1)
        let snowyNight = ShopEvents.Context(weekend: true, hasPraised: true, weather: .snow, month: 12, night: true, books: 4)
        let plainPool = Set((0..<200).map { ShopEvents.pick(roll: Double($0) / 200, context: plainDay).id })
        let snowPool = Set((0..<200).map { ShopEvents.pick(roll: Double($0) / 200, context: snowyNight).id })
        check(!plainPool.contains("holiday") && !plainPool.contains("snowbound") && !plainPool.contains("yearend") && !plainPool.contains("nightowl") && !plainPool.contains("collector")
              && snowPool.isSuperset(of: ["holiday", "snowbound", "yearend", "nightowl", "collector"]) && !snowPool.contains("shelter")
              && Set(ShopEvents.all.map(\.id)).count == ShopEvents.all.count && ShopEvents.all.allSatisfy { !$0.texts.isEmpty },
              "서점 사건: \(ShopEvents.all.count)가지, 맑은 평일 낮엔 \(plainPool.count)가지, 눈 오는 주말 밤엔 \(snowPool.count)가지")
        // 체력과 능력치: 글을 쓰면 체력이 줄고, 0이 되면 탈진해 3시간 쉬며, 쉬는 동안 두 배로 돌아온다. 2천만 토큰마다 능력치 하나가 1 오르고 효과가 붙는다.
        WritingStore.staminaEnabled = true
        let staminaStore = WritingStore(url: dir.appendingPathComponent("stamina.json"))
        staminaStore.badgeRewards = false
        staminaStore.eventChance = 0; staminaStore.disasterChance = 0; staminaStore.luckChance = 0; staminaStore.dilemmaChance = 0
        staminaStore.random = { 0.5 }
        staminaStore.statRandom = { 0.0 }
        let restNow = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        _ = staminaStore.apply(days: days(1), now: restNow)
        w = staminaStore.apply(days: days(1 + 20_000_000), now: restNow)
        let authorName = w.book?.displayAuthorShort ?? ""
        check(w.sheet.level(.pen) == 1 && w.note?.kind == .stat && (w.note?.text.contains("필력이 1이 됐습니다") ?? false) && w.statPerks.characters == 1.02,
              "능력치: 2천만 토큰에 \(authorName) 필력 1 \"\(w.note?.text ?? "")\"")
        check(abs(w.sheet.stamina - (100 - 24)) < 0.01 && !w.tired, "체력: 2천만 토큰에 \(Int(w.sheet.stamina))")
        w = staminaStore.apply(days: days(1 + 20_000_000 + 55_000_000), now: restNow)
        check(w.tired && w.expression == .tired && w.sheet.stamina < 30 && w.sheet.stamina > 0, "체력: \(Int(w.sheet.stamina))이면 지쳐서 표정이 피곤함")
        let tiredBefore = w.totalCharacters
        w = staminaStore.apply(days: days(1 + 20_000_000 + 56_000_000), now: restNow)
        check(abs((w.totalCharacters - tiredBefore) / (1_000 * w.statPerks.characters * 0.7) - 1) < 0.01,
              "체력: 지치면 글자가 30% 덜 늘어 \(Int(w.totalCharacters - tiredBefore))자(필력 \(w.sheet.level(.pen)))")
        w = staminaStore.apply(days: days(1 + 20_000_000 + 90_000_000), now: restNow)
        check(w.sheet.stamina == 0 && w.activeEvent?.id == "exhausted" && w.facts.exhaustions == 1, "체력: 0이 되면 탈진")
        let exhaustedChars = w.totalCharacters
        w = staminaStore.apply(days: days(1 + 20_000_000 + 100_000_000), now: restNow.addingTimeInterval(3600))
        check(w.totalCharacters == exhaustedChars && w.activeEvent?.id == "exhausted" && abs(w.sheet.stamina - 8) < 0.01,
              "체력: 탈진 중엔 안 쓰고 한 시간에 \(Int(w.sheet.stamina)) 돌아옴(두 배)")
        w = staminaStore.apply(days: days(1 + 20_000_000 + 100_000_000), now: restNow.addingTimeInterval(4 * 3600))
        check(w.activeEvent == nil && w.sheet.stamina >= 50, "체력: 3시간 뒤 깨어나 체력 \(Int(w.sheet.stamina))")
        staminaStore.statRandom = { 0.25 }
        w = staminaStore.apply(days: days(1 + 20_000_000 + 120_000_000), now: restNow.addingTimeInterval(4 * 3600))
        check(w.sheet.level(.grit) == 1 && w.statPerks.staminaMax == 105 && w.facts.statUps == 6 && w.sheet.level(.pen) == 5,
              "능력치: 끈기 1이면 최대 체력 105 (여섯 번 올랐고 탈진 중 토큰은 안 셈)")
        let reloadedSheet = WritingStore(url: dir.appendingPathComponent("stamina.json")).progress.sheet
        check(reloadedSheet == w.sheet, "능력치: 저장하고 다시 읽어도 같음")
        WritingStore.staminaEnabled = false

        // 서점 운영: 탈고하면 견본 100부, 출판사를 고르면 초판이 들어오고, 재고만큼만 팔리며, 품절이면 재판을 기다리고 놓친 손님을 센다.
        // 주인은 아침마다 자리를 정하고, 직접 고른 자리는 이레 동안 두며, 월요일에 정산서를 보낸다.
        WritingStore.stockEnabled = true
        let shopStore = WritingStore(url: dir.appendingPathComponent("shopops.json"))
        shopStore.badgeRewards = false
        shopStore.eventChance = 0; shopStore.disasterChance = 0; shopStore.luckChance = 0; shopStore.dilemmaChance = 0
        shopStore.random = { 0.5 }
        let open = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        _ = shopStore.apply(days: days(1), now: open)
        w = shopStore.apply(days: days(1 + firstBook.characters * 1_000 + 1_000), now: open)
        check(w.finished.count == 1 && w.stock(of: firstBook) == Balance.sampleRun && w.slot(of: firstBook) == .window && w.trustLevel == .usual,
              "서점 운영: 탈고하면 견본 \(w.stock(of: firstBook))부가 들어오고 주인이 진열창에 겁니다(신뢰 \(w.trustLevel.title))")
        w = shopStore.choosePublisher(.literary, for: w.finishCards[0].id, now: open)
        check(w.stock(of: firstBook) == Balance.sampleRun + Publisher.literary.firstRun, "서점 운영: 문예 출판사 초판 \(Publisher.literary.firstRun)부 입고 → 재고 \(w.stock(of: firstBook))")
        w = shopStore.apply(days: days(1 + firstBook.characters * 1_000 + 1_001_000), now: open)
        let soldFirst = w.sales(of: firstBook)
        check(soldFirst > 0 && abs(w.stock(of: firstBook) - (Balance.sampleRun + Publisher.literary.firstRun - soldFirst)) <= 1,
              "서점 운영: 팔린 만큼 재고가 줆(\(soldFirst)부 → 재고 \(w.stock(of: firstBook)))")
        shopStore.setStockForTesting(firstBook.file, copies: 5)
        let trustBefore = w.shop.trust
        w = shopStore.apply(days: days(1 + firstBook.characters * 1_000 + 2_001_000), now: open)
        let reprint = w.reprint(for: firstBook)
        check(w.sales(of: firstBook) == soldFirst + 5 && w.stock(of: firstBook) == 0 && w.slot(of: firstBook) == .storage && reprint != nil
              && (w.shop.weekMissed[firstBook.file] ?? 0) > 0 && w.shop.trust == trustBefore + Balance.trustSoldOut && w.featuredBook == nil
              && (w.note?.text.contains("품절") ?? false) && shopStore.unnotifiedStockNews.count == 1,
              "서점 운영: 재고 5부면 5부만 팔리고 품절 → 재판 \(reprint?.copies ?? 0)부 주문, 놓친 손님 \(Int(w.shop.weekMissed[firstBook.file] ?? 0)), 신뢰 \(Int(w.shop.trust)) \"\(w.note?.text ?? "")\"")
        check(reprint.map { abs($0.due.timeIntervalSince(open) - Publisher.literary.reprintHours * 3600) < 1 } == true,
              "서점 운영: 문예 출판사 재판은 \(Int(Publisher.literary.reprintHours))시간 뒤")
        w = shopStore.apply(days: days(1 + firstBook.characters * 1_000 + 2_001_000), now: open.addingTimeInterval(13 * 3600))
        check(w.stock(of: firstBook) == reprint?.copies && w.reprint(for: firstBook) == nil && w.slot(of: firstBook) == .window
              && (w.note?.text.contains("재판") ?? false) && shopStore.unnotifiedStockNews.count == 2,
              "서점 운영: 13시간 뒤 재판 \(w.stock(of: firstBook))부 입고, 다시 진열창")
        // 둘째 책을 끝내면 신간이 앞자리를 차지하고 첫 책은 매대로 간다. 그동안 첫 책이 또 품절되지 않게 재고를 넉넉히 둔다.
        let secondBook = Library.books[w.bookIndex]
        let morning2 = open.addingTimeInterval(36 * 3600)
        shopStore.setStockForTesting(firstBook.file, copies: 100_000)
        w = shopStore.apply(days: days(1 + (firstBook.characters + secondBook.characters) * 1_000 + 3_001_000), now: morning2)
        check(w.finished.count == 2 && w.slot(of: firstBook) == .window && w.slot(of: secondBook) == .counter,
              "서점 운영: 탈고한 날은 신간이 빈 매대 칸에 들어감(\(w.shop.counter.count)/\(w.trustLevel.counterSlots)칸)")
        let morning3 = morning2.addingTimeInterval(24 * 3600)
        w = shopStore.apply(days: days(1 + (firstBook.characters + secondBook.characters) * 1_000 + 3_002_000), now: morning3)
        check(w.slot(of: secondBook) == .window && w.slot(of: firstBook) == .counter && w.shop.counter.count <= w.trustLevel.counterSlots
              && (w.note?.text.hasPrefix("주인이 아침에") ?? false),
              "서점 운영: 다음 날 아침 주인이 신간 \(secondBook.displayTitle)(을|를) 진열창에, \(firstBook.displayTitle)(은|는) 매대로 \"\(w.note?.text ?? "")\"".resolvedParticles)
        w = shopStore.place(firstBook.file, .shelf, now: morning3)
        check(w.slot(of: firstBook) == .shelf && w.isBenched(firstBook) && !w.shop.counter.contains(firstBook.file), "서점 운영: 내리면 서가로 가고 주인이 다시 올리지 않음")
        let morning4 = morning3.addingTimeInterval(24 * 3600)
        w = shopStore.apply(days: days(1 + (firstBook.characters + secondBook.characters) * 1_000 + 3_002_000), now: morning4)
        check(w.slot(of: firstBook) == .shelf, "서점 운영: 다음 날 아침에도 서가")
        w = shopStore.place(firstBook.file, .window, now: morning4)
        check(w.slot(of: firstBook) == .window && w.isPinned(firstBook) && w.slot(of: secondBook) == .counter,
              "서점 운영: 직접 진열창에 걸면 신간이 매대로 밀림")
        w = shopStore.place(secondBook.file, .window, now: morning4.addingTimeInterval(3600))
        check(w.slot(of: firstBook) == .window, "서점 운영: 진열창은 하루에 한 번만 바꿈")
        w = shopStore.apply(days: days(1 + (firstBook.characters + secondBook.characters) * 1_000 + 3_002_000), now: morning4.addingTimeInterval(24 * 3600))
        check(w.slot(of: firstBook) == .window, "서점 운영: 직접 고른 자리는 아침 정리에도 그대로")
        let payday = WritingStore.weekStart(of: morning2).addingTimeInterval(7 * 86_400 + 10 * 3600)
        w = shopStore.apply(days: days(1 + (firstBook.characters + secondBook.characters) * 1_000 + 3_002_000), now: payday)
        let statement = w.statementCard
        check(statement != nil && (statement?.sold ?? 0) > 0 && (statement?.missed ?? 0) > 0 && statement?.lines.count == 2
              && !(statement?.keeperLine.isEmpty ?? true) && w.shop.weekSold.isEmpty && shopStore.unnotifiedStatement != nil,
              "서점 운영: 월요일 정산서 \(statement?.sold ?? 0)부 · 놓친 손님 \(statement?.missed ?? 0) · 신뢰 \(Int(statement?.trustBefore ?? 0))→\(Int(statement?.trustAfter ?? 0)) \"\(statement?.keeperLine ?? "")\"")
        // 마을: 풀밭의 물건은 하루 한 번, 책 권하기는 하루 세 번이고 권한 만큼 재고가 줄고 판매가 는다.
        let heldBeforePickup = ItemKind.allCases.reduce(0) { $0 + shopStore.progress.count($1) }
        let picked = shopStore.pickup(now: payday)
        w = shopStore.progress
        check(picked != nil && ItemKind.allCases.reduce(0) { $0 + w.count($1) } == heldBeforePickup + 1 && shopStore.pickup(now: payday) == nil
              && shopStore.pickup(now: payday.addingTimeInterval(86_400)) != nil,
              "마을: 풀밭에서 \(picked?.title ?? "")(을|를) 줍고 그날은 다시 못 주움, 다음 날은 다시".resolvedParticles)
        let salesBefore = shopStore.progress.totalSales
        let stockBefore = shopStore.progress.stock(of: firstBook) + shopStore.progress.stock(of: secondBook)
        let first = shopStore.recommend(now: payday)
        _ = shopStore.recommend(now: payday)
        _ = shopStore.recommend(now: payday)
        w = shopStore.progress
        check(first != nil && w.totalSales > salesBefore && w.stock(of: firstBook) + w.stock(of: secondBook) == stockBefore - (w.totalSales - salesBefore)
              && shopStore.recommend(now: payday) == nil,
              "마을: 책을 권하면 \(first?.1 ?? 0)부 팔리고 하루 세 번까지(모두 \(w.totalSales - salesBefore)부)")
        // 살롱: 같이 쓰자고 청하기는 하루 한 번, 행운이 없을 때만. 응하면 그 작가가 손님으로 온다.
        shopStore.random = { 0.1 }
        let invited = shopStore.invite("Wilde", now: payday)
        w = shopStore.progress
        check(invited?.accepted == true && w.guestAuthor == "Wilde" && shopStore.invite("Poe", now: payday) == nil,
              "살롱: 청하면 \(invited?.text ?? "") → 손님 \(w.guestAuthor ?? "없음"), 그날은 다시 못 청함")
        shopStore.random = { 0.95 }
        // 손님이 머무는 동안(행운 중)은 청할 수 없다. 이틀 뒤 반영으로 행운을 끝낸 다음에.
        _ = shopStore.apply(days: days(1 + (firstBook.characters + secondBook.characters) * 1_000 + 3_002_000), now: payday.addingTimeInterval(2 * 86_400))
        let declined = shopStore.invite("Poe", now: payday.addingTimeInterval(2 * 86_400))
        check(declined?.accepted == false, "살롱: 주사위가 나쁘면 사양 \"\(declined?.text ?? "")\"")
        // 옛 기록은 처음 반영할 때 출판사 초판만큼 재고를 채운다.
        w = shopEventsStore.apply(days: days(1 + firstBook.characters * 1_000 + 3_000_000), now: now.addingTimeInterval(14 * 3600))
        check(w.stock(of: firstBook) == Publisher.major.firstRun && w.slot(of: firstBook) != nil, "서점 운영: 옛 기록에 초판 \(w.stock(of: firstBook))부를 채움")
        WritingStore.stockEnabled = false

        // Antigravity 로그 파싱과 에이전트 데이터 소스 전환 확인
        let agyBrain = dir.appendingPathComponent("brain/conv-1/.system_generated/logs")
        try? FileManager.default.createDirectory(at: agyBrain, withIntermediateDirectories: true)
        let agyTranscript = agyBrain.appendingPathComponent("transcript.jsonl")
        let isoNow = Date.ISO8601FormatStyle().format(now)
        let agyLines = [
            "{\"step_index\":0,\"source\":\"USER_EXPLICIT\",\"type\":\"USER_INPUT\",\"status\":\"DONE\",\"created_at\":\"\(isoNow)\",\"content\":\"<USER_SETTINGS_CHANGE>\\nThe user changed setting `Model Selection` from None to Gemini 4 Argon (High).\\n</USER_SETTINGS_CHANGE>\"}",
            "{\"step_index\":1,\"source\":\"MODEL\",\"type\":\"PLANNER_RESPONSE\",\"status\":\"DONE\",\"created_at\":\"\(isoNow)\",\"input_tokens\":100000,\"cache_read_tokens\":400000,\"output_tokens\":500000}"
        ].joined(separator: "\n")
        try? agyLines.write(to: agyTranscript, atomically: true, encoding: .utf8)
        let agyFound = ClaudeLogParser.antigravityFiles(in: dir.appendingPathComponent("brain"), modifiedSince: .distantPast)
        let agyEntries = agyFound.flatMap { ClaudeLogParser.parse($0) }
        check(agyFound.count == 1 && agyEntries.count == 1 && agyEntries.first?.total == 1_000_000
              && agyEntries.first?.provider == .antigravity && agyEntries.first?.model == "Gemini 4 Argon (High)"
              && Pricing.cost(of: agyEntries[0]) != nil,
              "Antigravity: 숨김 폴더(.system_generated) 안의 transcript.jsonl 파싱 · 모델 \(agyEntries.first?.model ?? "-") · 100만 토큰")

        // 에이전트 데이터 소스 전환 시 기존 글자 수는 보존하고 기준선만 재조정하는지 확인
        let switchStore = WritingStore(url: dir.appendingPathComponent("switch.json"))
        switchStore.badgeRewards = false
        switchStore.eventChance = 0; switchStore.disasterChance = 0; switchStore.luckChance = 0; switchStore.dilemmaChance = 0
        _ = switchStore.apply(days: days(10_000_000), now: now) // 기준선 1,000만 토큰
        w = switchStore.apply(days: days(12_000_000), now: now) // +200만 토큰 -> 2,000자
        let charsBeforeSwitch = Int(w.totalCharacters)
        switchStore.rebaseline()
        // 더 작은 토큰을 가진 소스(예: Antigravity 단독 100만 토큰)로 전환해도 2,000자는 그대로이고, 그 뒤 +100만 토큰이면 3,000자가 된다.
        w = switchStore.apply(days: days(1_000_000), now: now)
        let charsAtSwitch = Int(w.totalCharacters)
        w = switchStore.apply(days: days(2_000_000), now: now)
        check(charsBeforeSwitch == 2_000 && charsAtSwitch == 2_000 && Int(w.totalCharacters) == 3_000,
              "데이터 소스 전환: 전환 직후 \(charsAtSwitch)자 그대로, 새 소스에서 +100만 토큰 뒤 \(Int(w.totalCharacters))자")

        // 74. 인앱 자동 업데이터 버전 비교 및 GitHub Release JSON 파싱
        check(AppUpdater.compareVersions("v0.2.0", "0.1.0") > 0
              && AppUpdater.compareVersions("0.1.0", "v0.1.0") == 0
              && AppUpdater.compareVersions("0.1.2", "0.2.0") < 0,
              "업데이터: SemVer 비교 (v0.2.0 > 0.1.0, 0.1.0 == v0.1.0)")
        let releaseJSON = Data("""
        {"tag_name":"v0.2.0","html_url":"https://github.com/sangeui/Scribe/releases/tag/v0.2.0","body":"해와 달 표시 추가","assets":[{"name":"Scribe.zip","browser_download_url":"https://github.com/sangeui/Scribe/releases/download/v0.2.0/Scribe.zip"}]}
        """.utf8)
        let parsedNew = AppUpdater.parseRelease(data: releaseJSON, currentVersion: "0.1.0")
        let parsedSame = AppUpdater.parseRelease(data: releaseJSON, currentVersion: "0.2.0")
        check(parsedNew?.version == "0.2.0" && parsedSame == nil,
              "업데이터: 최신 릴리스 감지 (\(parsedNew?.version ?? "-"), 같은 버전이면 무시)")

        print(failures == 0 ? "PASS" : "FAILED \(failures)")
    }

    /// `Scribe --writing out.png`: 가짜 진행(앞 두 권 탈고, 세 번째 책 12,380자)으로 집필 화면을 그린다.
    /// `--writing-empty` 는 막 시작한 0자 상태, `--event` 는 작가가 다른 일을 하는 모습, `--luck` 은 손님 작가가 와 있는 모습.
    static func renderWriting(to path: String) {
        var state = WritingState()
        if !CommandLine.arguments.contains("--writing-empty") {
            let today = Calendar.current.startOfDay(for: Date())
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            state.days[DayKey.string(from: yesterday)] = WritingRecord(tokens: 1, characters: Double(Library.starts[2]))
            state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
        }
        state.items = ["coffee": 2, "ink": 1, "bell": 1]
        if CommandLine.arguments.contains("--luck") {
            state.luck = ActiveLuck(id: Lucks.guest.id, startedAt: Date(), endsAt: Date().addingTimeInterval(150 * 60), guest: "Goethe")
            state.note = EventNote(text: Lucks.text(Lucks.guest, guest: "Goethe", items: nil), date: Date(), event: Lucks.guest.id, kind: .luck, notified: true)
        }
        if CommandLine.arguments.contains("--event") {
            let author = WritingProgress(state: state).book?.authorShort ?? ""
            let event = AuthorEvents.byAuthor[author] ?? AuthorEvents.away
            state.event = ActiveEvent(id: event.id, startedAt: Date(), endsAt: Date().addingTimeInterval(23 * 60), cause: 0)
            state.items["muse"] = 1
        }
        if let i = CommandLine.arguments.firstIndex(of: "--weather"), CommandLine.arguments.indices.contains(i + 1) {
            Weather.forced = Weather(rawValue: CommandLine.arguments[i + 1])
        }
        if CommandLine.arguments.contains("--deadline") {
            state.deadline = Deadline(weekStart: WritingStore.weekStart(of: Date()), kind: .characters, target: 50_000)
            state.inspiration = Balance.inspirationGaugeTokens
        }
        if CommandLine.arguments.contains("--finish") {
            var note = FinishNote(book: Library.books[1].file, round: 0, date: Date().addingTimeInterval(-600), days: 3, events: 1, lost: 0)
            note.publisherDue = Date().addingTimeInterval(20 * 3600)
            state.finishNotes = [note]
        }
        if CommandLine.arguments.contains("--bet") {
            state.luck = ActiveLuck(id: Lucks.guest.id, startedAt: Date().addingTimeInterval(-1800), endsAt: Date().addingTimeInterval(90 * 60), guest: "Wilde")
            state.bet = ActiveBet(guest: "Wilde", target: 4_500, offeredAt: Date(), endsAt: Date().addingTimeInterval(90 * 60))
            state.studio = ["lamp", "shelf", "cat"]
        }
        if CommandLine.arguments.contains("--dilemma") {
            let kind = Dilemmas.byID("title")!
            state.dilemma = ActiveDilemma(id: kind.id, text: kind.texts[0], startedAt: Date(), expiresAt: Date().addingTimeInterval(95 * 60))
            state.boosts = [ActiveBoost(kind: .sales, value: 1.5, endsAt: Date().addingTimeInterval(5 * 3600), source: "연재로 쪼개자는 출판사"),
                            ActiveBoost(kind: .refusal, value: 0.15, endsAt: Date().addingTimeInterval(2 * 3600), source: "비평 ★2")]
        }
        if CommandLine.arguments.contains("--stats"), let author = WritingProgress(state: state).book?.authorShort {
            var sheet = AuthorSheet()
            sheet.stats = ["pen": 3, "grit": 1, "charm": 2, "luck": 1]
            sheet.stamina = 24
            sheet.tokensTowardStat = 12_400_000
            state.sheets[author] = sheet
            state.note = EventNote(text: Format.resolve("\(Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author)의 필력(이|가) 3(이|가) 됐습니다. 문장이 전보다 빨리 나옵니다"),
                                   date: Date().addingTimeInterval(-60), event: "pen", kind: .stat, notified: true)
        }
        if CommandLine.arguments.contains("--review") {
            let book = Library.books[0]
            let text = Critics.text(for: 5, days: 3, events: 0, lost: 0, title: book.displayTitle, author: book.displayAuthorShort, voice: .lofty, rolls: [0.1, 0.2, 0.3])
            var review = Review(book: book.file, round: 0, critic: Critics.all[2].name, stars: 5, text: text, date: Date().addingTimeInterval(-600))
            review.published = true
            review.affected = true
            let panned = Critics.text(for: 2, days: 20, events: 4, lost: 3_000, title: Library.books[1].displayTitle, author: Library.books[1].displayAuthorShort, voice: .snippy, rolls: [0.6, 0.4, 0.9])
            var second = Review(book: Library.books[1].file, round: 0, critic: Critics.all[3].name, stars: 2, text: panned, date: Date().addingTimeInterval(-86_400))
            second.published = true
            state.reviews = [second, review]
            state.sales = [book.file: 12_400, Library.books[1].file: 870]
            state.featuredBook = book.file
            state.featuredAt = Date().addingTimeInterval(-3600)
            state.ads[book.file] = Date().addingTimeInterval(5 * 3600)
            state.order = ReaderOrder(book: Library.books[3].file, offeredAt: Date(), expiresAt: Date().addingTimeInterval(6 * 86_400),
                                      text: ReaderOrders.text(ReaderOrders.lines, book: Library.books[3], roll: 0.1))
            state.shopBoosts = [ShopBoost(book: book.file, value: 1.5, endsAt: Date().addingTimeInterval(9 * 3600), source: "신문 소개")]
            state.shop.migrated = true
            state.shop.stock = [book.file: 340, Library.books[1].file: 0]
            state.shop.reprints[Library.books[1].file] = ShopState.Reprint(due: Date().addingTimeInterval(4 * 3600), copies: 1_200, orderedAt: Date().addingTimeInterval(-2 * 3600))
            state.shop.pinned[book.file] = Date().addingTimeInterval(-3600)
            state.shop.trust = 63
            state.shop.trustLog = [TrustRecord(delta: 5, reason: "독자 주문대로 앨리스를 씀", date: Date().addingTimeInterval(-3 * 86_400)),
                                   TrustRecord(delta: -2, reason: "크리스마스 캐럴 품절로 손님을 돌려보냄", date: Date().addingTimeInterval(-2 * 3600)),
                                   TrustRecord(delta: 4, reason: "한 주 내내 손님이 끊이지 않음", date: Date().addingTimeInterval(-6 * 86_400))]
            state.shop.statements = [Statement(weekStart: WritingStore.weekStart(of: Date()).addingTimeInterval(-7 * 86_400),
                                               lines: [StatementLine(book: book.file, sold: 2_980, returned: 0, missed: 0, stock: 340, slot: .window),
                                                       StatementLine(book: Library.books[1].file, sold: 1_400, returned: 12, missed: 210, stock: 0, slot: .storage)],
                                               sold: 4_380, returned: 12, missed: 210, trustBefore: 59, trustAfter: 63,
                                               reasons: ["한 주 내내 손님이 끊이지 않음 (+4)", "크리스마스 캐럴 12부 반품 (-3)"],
                                               keeperLine: "몇 분은 빈손으로 갔습니다. 재고를 조금 넉넉히 두는 게 어떻겠습니까")]
            state.shopLog = [
                ShopRecord(event: "leak", book: nil, text: "서점 지붕에서 비가 새어 책을 안쪽으로 옮겼습니다", date: Date().addingTimeInterval(-2 * 86_400)),
                ShopRecord(event: "mice", book: Library.books[1].file, text: "창고에 쥐가 들어 크리스마스 캐럴 12부를 갉았습니다", date: Date().addingTimeInterval(-30 * 3600), copies: -12),
                ShopRecord(event: "school", book: Library.books[1].file, text: "학교에서 크리스마스 캐럴을 교재로 쓰겠다며 120부를 주문했습니다", date: Date().addingTimeInterval(-86_400), copies: 120),
                ShopRecord(event: "press", book: book.file, text: "아침 신문 문화면에 햄릿이 소개됐습니다", date: Date().addingTimeInterval(-3 * 3600)),
            ]
            for back in 0..<14 {
                let day = Calendar.current.date(byAdding: .day, value: -back, to: Calendar.current.startOfDay(for: Date()))!
                state.salesByDay[DayKey.string(from: day)] = Double([120, 340, 90, 410, 520, 300, 180, 260, 610, 380, 150, 220, 470, 330][back])
            }
            state.note = EventNote(text: Critics.authorLine(stars: 5, roll: 0.1), date: Date().addingTimeInterval(-600), event: review.id, kind: .review, notified: true)
            state.dilemmaLog = [DilemmaRecord(dilemma: "cat", option: "들인다", outcome: Dilemmas.byID("cat")!.options[0].outcomes[0], date: Date().addingTimeInterval(-7200))]
        }
        let progress = WritingProgress(state: state)
        let moodArg = CommandLine.arguments.firstIndex(of: "--mood").flatMap { CommandLine.arguments.indices.contains($0 + 1) ? CommandLine.arguments[$0 + 1] : nil }
        let mood = moodArg.flatMap(Mood.init(rawValue:)) ?? .focused
        let moodLine = mood == .waiting ? MoodLines.waiting[0] : mood == .slacking ? MoodLines.slackIn[0] : mood == .alone ? MoodLines.alone[0] : nil
        let handoff: (from: String, at: Date)? = CommandLine.arguments.contains("--handoff") ? ("Dickens", Date().addingTimeInterval(-2)) : nil
        let content = VStack(alignment: .leading, spacing: 16) {
            FloatingPill(progress: progress, animated: false, mood: mood, moodLine: moodLine, handoff: handoff)
            FloatingPill(progress: progress, featured: "Goethe", animated: false)
            WritingView(progress: progress) {}
                .frame(width: 348)
            HStack(spacing: 10) {
                ForEach(Portraits.all, id: \.0) { author, _ in
                    PortraitFrame(author: author, scale: 3)
                }
            }
            // 돌발 상황 초상화: 공통 상황은 셰익스피어로, 작가 고유 상황은 그 작가로
            HStack(spacing: 10) {
                ForEach(AuthorEvents.common + [AuthorEvents.dark], id: \.id) { event in
                    PortraitFrame(author: "Shakespeare", scale: 3, event: event)
                }
            }
            HStack(spacing: 10) {
                ForEach(Portraits.all, id: \.0) { author, _ in
                    PortraitFrame(author: author, scale: 3, event: AuthorEvents.byAuthor[author])
                }
            }
            HStack(spacing: 14) {
                ForEach(Array((MenuBarFrames.writing + MenuBarFrames.paused).enumerated()), id: \.offset) { _, frame in
                    PixelFrame(rows: frame, scale: 3, palette: ["#": .primary])
                        .padding(4)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            // 장신구: 와일드에게 하나씩 씌운 모습
            HStack(spacing: 10) {
                ForEach(Decor.all) { accessory in
                    PixelFrame(rows: Decor.apply(Portraits.rows("Wilde"), accessory: accessory), scale: 48 / CGFloat(Portraits.size), palette: Portraits.palette)
                        .frame(width: 48, height: 48)
                        .background(Portraits.backdrop("Wilde"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            if CommandLine.arguments.contains("--review") {
                BookstoreContent(progress: progress, scrollable: false).frame(width: 420)
            }
            // 힌트 카드 모양
            HStack(alignment: .top, spacing: 12) {
                HintCard(hint: Hint(title: "이번 주 마감 · 이번 주 5만자", lines: ["출판사에서 편지가 왔습니다. 이번 주에 50,000자를 보내 달랍니다.", "일요일까지입니다. 지키면 아이템 2개와 판매 +20%(하루).", "어기면 거절 확률이 2일 동안 10%p 오릅니다."], symbol: "calendar"))
                HintCard(hint: Hint(title: "오늘 날씨 · 비", lines: ["비가 옵니다. 글이 조금 잘 됩니다.", "효과: 글자 +5% · 돌발 상황 -10%"], symbol: "cloud.rain"))
            }
            if CommandLine.arguments.contains("--badges") {
                BadgeContent(progress: progress, scrollable: false).frame(width: 400)
            }
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
        print("book=\(progress.book?.title ?? "-") chars=\(progress.charactersInBook) finished=\(progress.finished.count)")
    }

    /// `Scribe --styles out.png`: 가짜 기록이 있는 가방과, 밝은·어두운 바탕화면 위의 상시 창을 그린다.
    /// 평소, 가장 긴 돌발 상황 문장(캐럴), 대표 초상화(괴테).
    static func renderStyles(to path: String) {
        func state(event: AuthorEvent?) -> WritingProgress {
            var state = WritingState()
            let today = Calendar.current.startOfDay(for: Date())
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            state.days[DayKey.string(from: yesterday)] = WritingRecord(tokens: 1, characters: Double(Library.starts[2]))
            state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
            state.items = ["coffee": 2, "bell": 1]
            if let event {
                state.event = ActiveEvent(id: event.id, startedAt: Date(), endsAt: Date().addingTimeInterval(23 * 60))
            }
            return WritingProgress(state: state)
        }
        let longest = AuthorEvents.byAuthor["Carroll"]!
        var quakeState = WritingState()
        quakeState.days[DayKey.string(from: Calendar.current.startOfDay(for: Date()))] = WritingRecord(tokens: 1, characters: 12_380)
        quakeState.eventLog = [EventRecord(event: Disasters.quake.id, book: Library.books[0].file, startedAt: Date().addingTimeInterval(-60),
                                           endedAt: Date().addingTimeInterval(-60), lostCharacters: 12_345)]
        let disasterState = WritingProgress(state: quakeState)
        // 가방: 진행 중 하나, 아이템으로 끝낸 것, 저절로 끝난 것
        var bagState = WritingState()
        bagState.items = ["coffee": 2, "bell": 1]
        bagState.days[DayKey.string(from: Calendar.current.startOfDay(for: Date()))] = WritingRecord(tokens: 1, characters: 12_380)
        let now = Date()
        bagState.eventLog = [
            EventRecord(event: "ink", book: Library.books[0].file, startedAt: now.addingTimeInterval(-26 * 3600),
                        endedAt: now.addingTimeInterval(-26 * 3600 + 41 * 60), endedBy: nil, pausedTokens: 3_400_000),
            EventRecord(event: "nap", book: Library.books[0].file, startedAt: now.addingTimeInterval(-3 * 3600),
                        endedAt: now.addingTimeInterval(-3 * 3600 + 4 * 60), endedBy: "coffee", pausedTokens: 600_000),
            EventRecord(event: "away", book: Library.books[0].file, startedAt: now.addingTimeInterval(-50 * 60),
                        endedAt: now.addingTimeInterval(-12 * 60), endedBy: "bell", pausedTokens: 1_200_000),
            EventRecord(event: Disasters.fire.id, book: Library.books[0].file, startedAt: now.addingTimeInterval(-20 * 60),
                        endedAt: now.addingTimeInterval(-20 * 60), lostCharacters: 3_958),
            EventRecord(event: longest.id, book: Library.books[0].file, startedAt: now.addingTimeInterval(-7 * 60), pausedTokens: 250_000),
        ]
        bagState.event = ActiveEvent(id: longest.id, startedAt: now.addingTimeInterval(-7 * 60), endsAt: now.addingTimeInterval(20 * 60))
        func desk(_ scheme: ColorScheme, _ colors: [Color]) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                FloatingPill(progress: state(event: nil), animated: false)
                FloatingPill(progress: state(event: AuthorEvents.nap), animated: false)
                FloatingPill(progress: state(event: longest), animated: false)
                FloatingPill(progress: state(event: nil), featured: "Goethe", animated: false)
                FloatingPill(progress: disasterState, animated: false)
                HStack(spacing: 16) {
                    FloatingMini(progress: state(event: nil), animated: false)
                    FloatingMini(progress: state(event: AuthorEvents.nap), animated: false)
                    FloatingMini(progress: state(event: longest), animated: false)
                    FloatingMini(progress: disasterState, animated: false)
                    FloatingMini(progress: state(event: nil), featured: "Goethe", animated: false)
                }
            }
            .padding(24)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .environment(\.colorScheme, scheme)
        }
        let content = HStack(alignment: .top, spacing: 0) {
            BagContent(progress: WritingProgress(state: bagState), scrollable: false)
                .frame(width: SidePanel.Kind.bag.size.width)
                .background(Color(nsColor: .windowBackgroundColor))
            desk(.light, [Color(red: 0.78, green: 0.84, blue: 0.93), Color(red: 0.93, green: 0.86, blue: 0.82)])
            desk(.dark, [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.26, green: 0.16, blue: 0.24)])
        }
        write(content, to: path)
    }

    /// `Scribe --village out.png`: 마을 맵을 낮과 밤으로. 작가는 서점 문 앞과 길 가운데.
    /// `Scribe --salon out.png`: 살롱을 낮(작가 셋, 하나 골라 둠)과 밤(대화 상자)으로.
    static func renderSalon(to path: String) {
        var state = WritingState()
        let today = Calendar.current.startOfDay(for: Date())
        let done = Library.starts[3]
        state.days[DayKey.string(from: today.addingTimeInterval(-86_400))] = WritingRecord(tokens: 1, characters: Double(done))
        state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
        for book in Library.books.prefix(3) { state.sales[book.file] = 1_800 }
        let progress = WritingProgress(state: state)
        let day = SalonState()
        day.selected = 1
        day.bubble = (0, "그 경구는 내 대사에서 가져간 것 아니오", Date().addingTimeInterval(60))
        let night = SalonState()
        night.selected = 2
        night.dialogue = SalonTalk.author(SalonTalk.seated(progress)[2], progress: progress, now: Date(), mood: .focused, turn: 1)
        let content = VStack(alignment: .leading, spacing: 16) {
            SalonView(progress: progress, state: day, animated: false, date: today.addingTimeInterval(14 * 3600))
            SalonView(progress: progress, state: night, animated: false, date: today.addingTimeInterval(22 * 3600))
                .environment(\.colorScheme, .dark)
        }
        .padding(16)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
    }

    static func renderVillage(to path: String) {
        var state = WritingState()
        let today = Calendar.current.startOfDay(for: Date())
        state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
        state.shop.reprints[Library.books[1].file] = ShopState.Reprint(due: Date().addingTimeInterval(3600), copies: 500, orderedAt: Date())
        state.shop.migrated = true
        state.shop.stock = [Library.books[0].file: 300, Library.books[1].file: 0]
        state.featuredBook = Library.books[0].file
        state.items = ["coffee": 3, "bell": 2, "ink": 2]
        state.ads[Library.books[0].file] = Date().addingTimeInterval(3600)
        state.shopBoosts = [ShopBoost(book: nil, value: 1.3, endsAt: Date().addingTimeInterval(3600), source: "서점 세일")]
        state.days[DayKey.string(from: today.addingTimeInterval(-86_400))] = WritingRecord(tokens: 1, characters: Double(Library.starts[1]))
        let progress = WritingProgress(state: state)
        var nightState = state
        nightState.event = ActiveEvent(id: AuthorEvents.nap.id, startedAt: Date(), endsAt: Date().addingTimeInterval(1200))
        let nightProgress = WritingProgress(state: nightState)
        let atDoor = VillageState()
        atDoor.stand(at: .bookstore)
        atDoor.facing = .up
        atDoor.setCustomers(3, leaving: false)
        let onPath = VillageState()
        onPath.facing = .left
        onPath.step = 1
        onPath.setCustomers(3, leaving: false)
        onPath.pickupTile = (4, 6)
        let talking = VillageState()
        talking.setCustomers(3, leaving: false)
        talking.col = VillageBuilding.bookstore.doorCol - 2
        talking.row = 5
        talking.x = Double(talking.col)
        talking.y = 5
        talking.facing = .up
        talking.dialogue = VillageTalk.customer(1, progress: progress, now: Date(), turn: 1, leaving: false)
        func weathered(_ kind: Weather) -> WritingProgress {
            Weather.forced = kind
            defer { Weather.forced = nil }
            return WritingProgress(state: state)
        }
        let content = VStack(alignment: .leading, spacing: 16) {
            VillageView(progress: progress, state: onPath, animated: false, date: today.addingTimeInterval(14 * 3600),
                        fuel: LimitRow(name: "5시간", percent: 40, resetsAt: Date().addingTimeInterval(7200)))
            VillageView(progress: nightProgress, state: atDoor, animated: false, date: today.addingTimeInterval(22 * 3600),
                        fuel: LimitRow(name: "5시간", percent: 95, resetsAt: nil))
                .environment(\.colorScheme, .dark)
            VillageView(progress: progress, state: talking, animated: false, date: today.addingTimeInterval(14 * 3600))
            if CommandLine.arguments.contains("--weather") {
                ForEach([Weather.rain, .fog, .snow, .cloudy, .heat, .storm], id: \.self) { kind in
                    VillageView(progress: weathered(kind), state: onPath, animated: false, date: today.addingTimeInterval(14 * 3600))
                }
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
    }

    /// `Scribe --hours out.png`: 상시 창 알약을 시각별로 한 줄씩. 바탕 색조가 하루 동안 어떻게 바뀌는지 본다.
    static func renderHours(to path: String) {
        var state = WritingState()
        let today = Calendar.current.startOfDay(for: Date())
        state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
        let progress = WritingProgress(state: state)
        let hours: [Double] = [0, 3, 5, 5.5, 6.5, 7.5, 8.5, 10, 12, 14, 16, 17, 17.5, 18.5, 19.5, 21, 22.5]
        let month = Calendar.current.component(.month, from: Date())
        let content = VStack(alignment: .leading, spacing: 10) {
            ForEach(hours, id: \.self) { hour in
                let date = today.addingTimeInterval(hour * 3600)
                HStack(spacing: 12) {
                    Text(String(format: "%02d:%02d", Int(hour), Int((hour - floor(hour)) * 60)))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    FloatingPill(progress: progress, animated: false, dayPart: DayPart.current(date), tintDate: date)
                    FloatingMini(progress: progress, animated: false, dayPart: DayPart.current(date), tintDate: date)
                }
            }
            Text("\(month)월 기준. 해 뜨는 때와 지는 때는 달마다 한 시간쯤 움직입니다.").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(24)
        .background(LinearGradient(colors: [Color(red: 0.78, green: 0.84, blue: 0.93), Color(red: 0.93, green: 0.86, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
        write(content, to: path)
    }

    /// `Scribe --snapshot out.png`: 팝오버, 상시 창, 서재, 가방을 PNG 로 그린다. 한도 칸은 비어 있다.
    static func renderPopover(to path: String) {
        // `--no-logs` 는 기록이 하나도 없는 첫 실행 모습.
        let (entries, files, filesByProvider) = CommandLine.arguments.contains("--no-logs")
            ? ([], 0, [:])
            : ClaudeLogParser.scanAllWithProviders(since: .distantPast)
        let store = UsageStore(persist: false)
        store.show(UsageAggregator.snapshot(entries: entries, scannedFiles: files, filesByProvider: filesByProvider, source: store.agentSource))
        // 한도는 앱과 같은 방법으로 한 번 불러온다. 실패하면 빈 채로 그린다.
        if store.agentSource != .antigravity {
            nonisolated(unsafe) var limits: LimitsResult?
            let done = DispatchSemaphore(value: 0)
            Task.detached {
                limits = try? await ClaudeLimitsClient().fetch(userInitiated: false)
                done.signal()
            }
            done.wait()
            if let limits { store.show(limits) }
        }
        let content = HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                // 글래스는 ImageRenderer 가 그리지 못해 반투명 재질로 그린다.
                if let w = store.writing { FloatingPill(progress: w, animated: false).padding(12) }
                PopoverView(store: store, scrollable: false)
            }
            ShelfPanel(store: store, scrollable: false).frame(width: SidePanel.Kind.shelf.size.width)
            BagPanel(store: store, scrollable: false).frame(width: SidePanel.Kind.bag.size.width)
            UsageDashboard(store: store, scrollable: false).frame(width: SidePanel.Kind.usage.size.width)
            BadgePanel(store: store, scrollable: false).frame(width: SidePanel.Kind.badges.size.width)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
    }

    /// `Scribe --settings out.png`: 설정 네 탭을 나란히 그린다.
    static func renderSettings(to path: String) {
        let (entries, files, filesByProvider) = ClaudeLogParser.scanAllWithProviders(since: .distantPast)
        let store = UsageStore(persist: false)
        store.show(UsageAggregator.snapshot(entries: entries, scannedFiles: files, filesByProvider: filesByProvider, source: store.agentSource))
        let content = HStack(alignment: .top, spacing: 12) {
            FloatingSettings(store: store).frame(width: 480, height: 620).hintHost()
            WritingSettings(store: store).frame(width: 480, height: 620).hintHost()
            NotificationSettings(store: store).frame(width: 480, height: 620).hintHost()
            RecordSettings(store: store).frame(width: 480, height: 620).hintHost()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
    }

    static func renderMarquee(to path: String) {
        let view = MarqueeText(text: "와일드가 찾아와 함께 씁니다. 3시간 동안 돌발 상황이 없습니다", size: 14, color: .primary, animated: true)
            .frame(width: 200).padding(12).background(Color(nsColor: .windowBackgroundColor))
        write(view, to: path)
    }

    /// `Scribe --tour <dir>`: README 용 개별 고해상도 UI 카드 스크린샷들을 지정된 폴더에 생성한다.
    static func renderTour(to dir: String) {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        var state = WritingState()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        state.days[DayKey.string(from: yesterday)] = WritingRecord(tokens: 210_000_000, characters: Double(Library.starts[2]))
        state.days[DayKey.string(from: today)] = WritingRecord(tokens: 28_400_000, characters: 12_380)
        state.items = ["coffee": 2, "tea": 1, "ink": 2, "bell": 1, "muse": 1, "safe": 1]
        state.studio = ["lamp", "shelf", "cat"]
        state.deadline = Deadline(weekStart: WritingStore.weekStart(of: now), kind: .characters, target: 50_000)
        state.inspiration = Int(Double(Balance.inspirationGaugeTokens) * 0.68)

        var sheet = AuthorSheet()
        sheet.stats = ["pen": 3, "grit": 1, "charm": 2, "luck": 1]
        sheet.stamina = 76
        sheet.tokensTowardStat = 12_400_000
        state.sheets["Poe"] = sheet

        let book0 = Library.books[0]
        let book1 = Library.books[1]
        let reviewText = Critics.text(for: 5, days: 3, events: 0, lost: 0, title: book0.displayTitle, author: book0.displayAuthorShort, voice: .lofty, rolls: [0.1, 0.2, 0.3])
        var review = Review(book: book0.file, round: 0, critic: Critics.all[2].name, stars: 5, text: reviewText, date: now.addingTimeInterval(-600))
        review.published = true
        review.affected = true
        state.reviews = [review]
        state.sales = [book0.file: 12_400, book1.file: 1_850]
        state.featuredBook = book0.file
        state.featuredAt = now.addingTimeInterval(-3600)
        state.ads[book0.file] = now.addingTimeInterval(4 * 3600)
        state.order = ReaderOrder(book: Library.books[3].file, offeredAt: now, expiresAt: now.addingTimeInterval(6 * 86_400),
                                  text: ReaderOrders.text(ReaderOrders.lines, book: Library.books[3], roll: 0.1))
        state.shopBoosts = [ShopBoost(book: book0.file, value: 1.5, endsAt: now.addingTimeInterval(9 * 3600), source: "신문 소개")]
        state.shop.migrated = true
        state.shop.stock = [book0.file: 340, book1.file: 120]
        state.shop.pinned[book0.file] = now.addingTimeInterval(-3600)
        state.shop.trust = 68
        state.shopLog = [
            ShopRecord(event: "press", book: book0.file, text: "아침 신문 문화면에 햄릿이 소개됐습니다", date: now.addingTimeInterval(-3 * 3600)),
            ShopRecord(event: "school", book: book1.file, text: "학교에서 크리스마스 캐럴을 교재로 쓰겠다며 120부를 주문했습니다", date: now.addingTimeInterval(-86_400), copies: 120),
        ]
        for back in 0..<14 {
            let day = cal.date(byAdding: .day, value: -back, to: today)!
            state.salesByDay[DayKey.string(from: day)] = Double([180, 340, 210, 410, 520, 300, 180, 260, 610, 380, 150, 220, 470, 330][back])
        }
        state.eventLog = [
            EventRecord(event: "nap", book: book0.file, startedAt: now.addingTimeInterval(-3 * 3600),
                        endedAt: now.addingTimeInterval(-3 * 3600 + 4 * 60), endedBy: "coffee", pausedTokens: 600_000),
            EventRecord(event: "away", book: book0.file, startedAt: now.addingTimeInterval(-50 * 60),
                        endedAt: now.addingTimeInterval(-12 * 60), endedBy: "bell", pausedTokens: 1_200_000),
        ]

        let progress = WritingProgress(state: state)

        // 샘플 토큰 스냅샷 (14일)
        let dailyTokens = [14_200_000, 18_500_000, 9_800_000, 22_100_000, 31_400_000, 16_700_000, 8_400_000,
                           19_300_000, 25_600_000, 34_200_000, 21_900_000, 15_800_000, 29_100_000, 28_400_000]
        var days: [DayUsage] = []
        for i in 0..<14 {
            let d = cal.date(byAdding: .day, value: -(13 - i), to: today)!
            let t = dailyTokens[i]
            days.append(DayUsage(day: d, tokens: t, read: Int(Double(t) * 0.92), cost: Double(t) / 1_000_000 * 0.65))
        }
        var hours = Array(repeating: 0, count: 24)
        let sampleHours: [(Int, Int)] = [(9, 1_800_000), (10, 3_400_000), (11, 2_900_000), (13, 2_100_000),
                                         (14, 4_600_000), (15, 3_800_000), (16, 5_200_000), (17, 2_700_000), (20, 1_900_000)]
        for (h, v) in sampleHours { hours[h] = v }

        let models = [
            ModelUsage(model: "gemini-2.5-pro", tokens: 19_800_000, input: 2_100_000, output: 950_000, cacheWrite: 0, cacheRead: 16_750_000, cost: 12.40),
            ModelUsage(model: "gemini-2.5-flash", tokens: 8_600_000, input: 1_200_000, output: 600_000, cacheWrite: 0, cacheRead: 6_800_000, cost: 6.06),
        ]
        let snapshot = UsageSnapshot(
            source: .antigravity,
            days: days,
            todayByModel: models,
            todayByHour: hours,
            recentFiveHourTokens: 16_300_000,
            todayByProvider: [.antigravity: 28_400_000, .claude: 14_200_000],
            todayCostByProvider: [.antigravity: 18.46, .claude: 9.80],
            filesByProvider: [.antigravity: 18, .claude: 12],
            scannedFiles: 18,
            generatedAt: now
        )

        let store = UsageStore(persist: false)
        store.showSample(snapshot: snapshot, writing: progress, source: .antigravity)

        // 1. 홈 팝오버 + 데스크톱 알약
        let homeView = VStack(spacing: 12) {
            FloatingPill(progress: progress, animated: false)
            PopoverView(store: store, scrollable: false)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        }
        .padding(16)
        write(homeView, to: "\(dir)/screenshot-home.png")

        // 2. 서재 패널
        let shelfView = ShelfPanel(store: store, scrollable: false)
            .frame(width: SidePanel.Kind.shelf.size.width)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(shelfView, to: "\(dir)/screenshot-shelf.png")

        // 3. 동네 서점 카드
        let bookstoreView = BookstoreContent(progress: progress, scrollable: false)
            .frame(width: 420)
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(bookstoreView, to: "\(dir)/screenshot-bookstore.png")

        // 4. 작업실 & 가방 패널
        let bagView = BagContent(progress: progress, scrollable: false)
            .frame(width: SidePanel.Kind.bag.size.width)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(bagView, to: "\(dir)/screenshot-bag.png")

        // 5. 토큰 사용량 대시보드
        let usageView = UsageDashboard(store: store, scrollable: false)
            .frame(width: SidePanel.Kind.usage.size.width)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(usageView, to: "\(dir)/screenshot-usage.png")

        // 6. 성과 패널
        let badgesView = BadgePanel(store: store, scrollable: false)
            .frame(width: SidePanel.Kind.badges.size.width)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(badgesView, to: "\(dir)/screenshot-badges.png")

        // 7. 문호 초상화 & 돌발 상황 & 장신구 컬렉션 카드
        let portraitsView = VStack(alignment: .leading, spacing: 12) {
            Text("대문호 초상화").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Portraits.all, id: \.0) { author, _ in
                    PortraitFrame(author: author, scale: 3)
                }
            }
            Text("돌발 상황 표정").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Array((AuthorEvents.common + [AuthorEvents.dark]).prefix(6)), id: \.id) { event in
                    PortraitFrame(author: "Shakespeare", scale: 3, event: event)
                }
                PortraitFrame(author: "Poe", scale: 3, event: AuthorEvents.byAuthor["Poe"])
                PortraitFrame(author: "Stevenson", scale: 3, event: AuthorEvents.byAuthor["Stevenson"])
            }
            Text("수집 가능한 장신구").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(Decor.all) { accessory in
                    PixelFrame(rows: Decor.apply(Portraits.rows("Wilde"), accessory: accessory), scale: 42 / CGFloat(Portraits.size), palette: Portraits.palette)
                        .frame(width: 42, height: 42)
                        .background(Portraits.backdrop("Wilde"))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(width: 472, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .padding(12)
        write(portraitsView, to: "\(dir)/screenshot-portraits.png")

        // 8. 바탕화면 상시 창 (라이트 / 다크 알약 & 미니)
        var napState = state
        napState.event = ActiveEvent(id: AuthorEvents.nap.id, startedAt: now, endsAt: now.addingTimeInterval(23 * 60))
        let napProgress = WritingProgress(state: napState)
        let floatingCard = VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                FloatingPill(progress: progress, animated: false)
                FloatingPill(progress: napProgress, animated: false)
                HStack(spacing: 12) {
                    FloatingMini(progress: progress, animated: false)
                    FloatingMini(progress: napProgress, animated: false)
                    FloatingMini(progress: progress, featured: "Goethe", animated: false)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.78, green: 0.84, blue: 0.93), Color(red: 0.93, green: 0.86, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .environment(\.colorScheme, .light)

            VStack(alignment: .leading, spacing: 12) {
                FloatingPill(progress: progress, featured: "Goethe", animated: false)
                HStack(spacing: 12) {
                    FloatingMini(progress: progress, animated: false)
                    FloatingMini(progress: napProgress, animated: false)
                    FloatingMini(progress: progress, featured: "Goethe", animated: false)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.26, green: 0.16, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .environment(\.colorScheme, .dark)
        }
        .frame(width: 420)
        .padding(12)
        write(floatingCard, to: "\(dir)/screenshot-floating.png")
    }

    private static func write(_ view: some View, to path: String) {
        RenderMode.offscreen = true
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return print("render failed") }
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        try? png?.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}
