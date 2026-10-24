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

}
