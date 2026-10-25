import AppKit
import Foundation
@preconcurrency import UserNotifications

/// 알림 권한 상태. 설정 화면에서 보여 준다.
enum NotificationStatus: Equatable, Sendable {
    /// 앱 번들이 아니라(`swift run`) 알림 센터를 못 쓴다.
    case unavailable
    case notAsked
    case allowed
    /// 시스템 설정에서 꺼져 있다. 그동안은 버튼 없는 간이 알림(osascript)으로 대신한다.
    case denied

    var title: String {
        L10n.tr({ switch self {
        case .unavailable: "앱 번들에서만 보낼 수 있습니다"
        case .notAsked: "아직 묻지 않았습니다"
        case .allowed: "허용됨"
        case .denied: "꺼져 있음 · 간이 알림으로 대신 보냅니다"
        } }())
    }
}

/// 잠금 화면 진행 알림. 화면이 잠긴 동안 글자가 늘면 일정 간격으로 알려 준다. 알림은 잠금 화면에도 보인다.
enum LockProgress {
    nonisolated static let enabledKey = "lockProgressEnabled"
    nonisolated static let minutesKey = "lockProgressMinutes"

    static var enabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    static var minutes: Int { UserDefaults.standard.object(forKey: minutesKey) as? Int ?? 60 }
}

/// 방해 금지 시간. 설정에 저장한다. 기본은 23시부터 8시까지.
enum QuietHours {
    nonisolated static let enabledKey = "quietEnabled"
    nonisolated static let startKey = "quietStart"
    nonisolated static let endKey = "quietEnd"

    static var enabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
    static var start: Int { UserDefaults.standard.object(forKey: startKey) as? Int ?? 23 }
    static var end: Int { UserDefaults.standard.object(forKey: endKey) as? Int ?? 8 }

    /// 지금이 방해 금지 시간인지. 시작과 끝이 같으면 꺼진 것으로 본다.
    static func isQuiet(at date: Date = Date()) -> Bool {
        guard enabled, start != end else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        return start < end ? (hour >= start && hour < end) : (hour >= start || hour < end)
    }

    static var description: String { L10n.tr("\(start)시 ~ \(end)시") }
}

/// 보낼 알림 하나. 묶어 보낼 때는 `line` 이 한 줄이 된다.
struct PendingNotification: Sendable, Codable {
    let id: String
    let title: String
    let body: String
    var sound = false
    /// 알림의 버튼("아이템 권하기")이 붙는 종류.
    var category: String?
    /// 버튼이 있어 바로 보내야 하는 알림. 방해 금지 중에는 그래도 묶인다.
    var urgent = false

    var line: String { L10n.tr(title) + (body.isEmpty ? "" : " · " + L10n.tr(body)) }
}

/// 돌발 상황·자연재해·성과·행운·탈고 알림. 알림의 "아이템 권하기" 버튼을 누르면 맞는 아이템을 권한다.
/// 앱 번들로 실행했을 때만 쓴다. `--dump` 같은 맨 실행 파일에서 알림 센터를 부르면 예외가 난다.
/// 권한은 보낼 때마다 다시 확인한다. 시스템 설정에서 켜고 끄면 앱을 다시 켜지 않아도 따라간다.
///
/// 1분 안에 여러 알림이 생기면 "소식 n건" 하나로 묶는다. 버튼이 있는 돌발 상황 알림은 묶지 않고 바로 보낸다.
/// 방해 금지 시간에는 모두 모아 두었다가 끝나면 요약 한 번만 보낸다. 모아 둔 것은 팝오버에 "소식 n건"으로 보인다.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    nonisolated static let category = "authorEvent"
    nonisolated static let useAction = "useItem"
    /// 묶어 보내기 전에 기다리는 시간.
    static let batchWindow: Duration = .seconds(60)

    private weak var store: UsageStore?
    private(set) var status: NotificationStatus = Notifier.isAvailable ? .notAsked : .unavailable

    /// 묶으려고 잠깐 들고 있는 알림.
    private var batch: [PendingNotification] = []
    private var batchTask: Task<Void, Never>?
    /// 방해 금지 동안 모아 둔 알림. 앱을 껐다 켜도 남게 저장한다.
    private(set) var held: [PendingNotification] = [] {
        didSet {
            store?.heldNews = held.map(\.line)
            UserDefaults.standard.set(try? JSONEncoder().encode(held), forKey: Self.heldKey)
        }
    }
    nonisolated static let heldKey = "heldNotifications"

    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app" }

    init(store: UsageStore) {
        self.store = store
        super.init()
        guard Self.isAvailable else { return }
        if let data = UserDefaults.standard.data(forKey: Self.heldKey),
           let saved = try? JSONDecoder().decode([PendingNotification].self, from: data) {
            held = saved
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let use = UNNotificationAction(identifier: Self.useAction, title: L10n.tr("아이템 권하기"), options: [])
        var categories = [UNNotificationCategory(identifier: Self.category, actions: [use], intentIdentifiers: [], options: [])]
        // 선택지가 있는 사건은 사건마다 선택지가 버튼이 된다.
        for dilemma in Dilemmas.all {
            let actions = dilemma.options.enumerated().map { i, option in
                UNNotificationAction(identifier: "\(Self.chooseAction).\(i)", title: option.label, options: [])
            }
            categories.append(UNNotificationCategory(identifier: "\(Self.dilemmaCategory).\(dilemma.id)", actions: actions,
                                                     intentIdentifiers: [], options: []))
        }
        categories.append(UNNotificationCategory(identifier: Self.betCategory, actions: [
            UNNotificationAction(identifier: Self.betAcceptAction, title: L10n.tr("받는다"), options: []),
            UNNotificationAction(identifier: Self.betDeclineAction, title: L10n.tr("사양한다"), options: []),
        ], intentIdentifiers: [], options: []))
        center.setNotificationCategories(Set(categories))
    }

    nonisolated static let dilemmaCategory = "dilemma"
    nonisolated static let chooseAction = "choose"
    nonisolated static let betCategory = "bet"
    nonisolated static let betAcceptAction = "betAccept"
    nonisolated static let betDeclineAction = "betDecline"

    // MARK: 권한

    /// 지금 권한을 읽는다. 아직 안 물었으면 묻는다(ad-hoc 서명이면 macOS 가 거절할 수 있다).
    @discardableResult
    func refreshStatus(ask: Bool = true) async -> NotificationStatus {
        guard Self.isAvailable else { return status }
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings().authorizationStatus
        if settings == .notDetermined, ask {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                NSLog("Scribe 알림 권한 요청 실패: %@", "\(error)")
            }
            settings = await center.notificationSettings().authorizationStatus
        }
        switch settings {
        case .authorized, .provisional: status = .allowed
        case .denied: status = .denied
        default: status = .notAsked
        }
        return status
    }

    // MARK: 보내기

    /// 누른 일에 대한 답(내보내기·가져오기 결과). 방해 금지와 묶기를 건너뛰고 바로 보낸다.
    func sendNow(_ notification: PendingNotification) {
        guard Self.isAvailable else { return }
        Task { await send(notification) }
    }

    /// 알림을 넣는다. 방해 금지면 모아 두고, 급하면 바로, 아니면 잠깐 모았다가 묶어 보낸다.
    func queue(_ notification: PendingNotification) {
        guard Self.isAvailable else { return }
        if QuietHours.isQuiet() {
            held.append(notification)
            return
        }
        if notification.urgent {
            Task { await send(notification) }
            return
        }
        batch.append(notification)
        batchTask?.cancel()
        batchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.batchWindow)
            guard !Task.isCancelled else { return }
            await self?.flushBatch()
        }
    }

    private func flushBatch() async {
        let items = batch
        batch = []
        guard !items.isEmpty else { return }
        // 모으는 사이 방해 금지가 시작됐으면 그쪽으로 넘긴다.
        if QuietHours.isQuiet() {
            held.append(contentsOf: items)
            return
        }
        if items.count == 1 {
            await send(items[0])
        } else {
            await send(Self.combined(items, title: "소식 \(items.count)건"))
        }
    }

    /// 방해 금지가 끝났으면 모아 둔 것을 요약 한 번으로 보낸다. 갱신 때마다 부른다.
    func flushHeldIfAllowed() async {
        guard !held.isEmpty, !QuietHours.isQuiet() else { return }
        let items = held
        held = []
        if items.count == 1 {
            await send(items[0])
        } else {
            await send(Self.combined(items, title: "그동안 소식 \(items.count)건"))
        }
    }

    private static func combined(_ items: [PendingNotification], title: String) -> PendingNotification {
        let preview = items.prefix(3).map { L10n.tr($0.title) }.joined(separator: " · ")
        let rest = items.count > 3 ? L10n.tr(" 외 \(items.count - 3)건") : ""
        return PendingNotification(id: "digest-\(Date().timeIntervalSince1970)", title: title,
                                   body: preview + rest, sound: items.contains { $0.sound })
    }

    /// 실제로 보낸다. 권한이 없으면 간이 알림으로.
    private func send(_ n: PendingNotification) async {
        await refreshStatus()
        let title = L10n.tr(n.title)
        let body = L10n.tr(n.body)
        guard status == .allowed else {
            Self.fallback(title: title, body: body)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if n.sound { content.sound = .default }
        if let category = n.category { content.categoryIdentifier = category }
        do {
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: n.id, content: content, trigger: nil))
        } catch {
            NSLog("Scribe 알림 보내기 실패: %@", "\(error)")
        }
    }

    /// 권한 없이 띄우는 알림. 보낸 쪽이 "스크립트 편집기"로 보이고 버튼은 없다.
    private static func fallback(title: String, body: String) {
        func quoted(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "display notification \(quoted(body)) with title \(quoted(title)) sound name \"Glass\""]
        try? process.run()
    }

    // MARK: 종류별

    /// 설정의 "시험 알림". 묶지 않고 바로 보낸다.
    func sendTest() async {
        guard Self.isAvailable else { return }
        await refreshStatus()
        let body = status == .allowed ? "알림이 이렇게 옵니다." : "시스템 설정에서 Scribe 알림을 허용해 주세요."
        await send(PendingNotification(id: "test-\(Date().timeIntervalSince1970)", title: "Scribe 시험 알림", body: body, sound: true))
    }

    // 글의 규칙: 오른쪽 '옵션' 버튼에 가려지지 않도록 제목과 본문 모두 한 줄 단문으로 유지한다.
    private static func said(_ author: String, _ text: String) -> String { Format.resolve("\(author)(이|가) \(text)") }

    /// 돌발 상황. 아이템이 있으면 버튼이 붙어 바로 보낸다.
    func notify(event: AuthorEvent, cause: String?, book: Book, hasCure: Bool) {
        let role = event.cure.role
        let body = cause ?? (hasCure ? "\(role.title) 아이템 사용 가능" : "\(Balance.eventMinutes.lowerBound)~\(Balance.eventMinutes.upperBound)분 뒤 복귀")
        queue(PendingNotification(id: "event-\(event.id)-\(Date().timeIntervalSince1970)",
                                  title: Self.said(book.displayAuthorShort, event.text), body: body,
                                  sound: true, category: hasCure ? Self.category : nil, urgent: hasCure))
    }

    /// 알림 버튼으로 아이템을 권한 결과.
    func notify(result note: EventNote, event: AuthorEvent, book: Book) {
        let refused = note.kind == .refused
        queue(PendingNotification(id: "result-\(note.date.timeIntervalSince1970)",
                                  title: refused ? Self.said(book.displayAuthorShort, "거절했습니다") : "통했습니다",
                                  body: note.text, urgent: true))
    }

    /// 상황이 저절로 끝나 돌아왔을 때. 소리는 내지 않는다.
    func notify(returned note: EventNote, event: AuthorEvent, book: Book) {
        queue(PendingNotification(id: "returned-\(note.date.timeIntervalSince1970)",
                                  title: Self.said(book.displayAuthorShort, "돌아왔습니다"), body: note.text))
    }

    /// 자연재해. 집필은 멈추지 않으니 버튼은 없다. 방재 아이템이 막았으면 소리도 없다.
    func notify(disaster: Disaster, lost: Int, book: Book?, shield: ItemKind? = nil) {
        if let shield {
            queue(PendingNotification(id: "\(disaster.id)-\(Date().timeIntervalSince1970)",
                                      title: "\(disaster.name) 방어 · \(shield.title)",
                                      body: disaster.cause))
        } else {
            queue(PendingNotification(id: "\(disaster.id)-\(Date().timeIntervalSince1970)",
                                      title: "\(disaster.name) · -\(Format.integer(lost))자",
                                      body: disaster.cause,
                                      sound: true))
        }
    }

    /// 행운.
    func notify(luck: LuckEvent, note: EventNote, book: Book) {
        queue(PendingNotification(id: "luck-\(note.date.timeIntervalSince1970)", title: luck.title, body: note.text, sound: true))
    }

    /// 성과 달성. 한꺼번에 여러 개면 알림 하나에 모은다.
    func notify(badges: [Achievement], rewards: [String: String] = [:]) {
        guard let first = badges.first else { return }
        let title = badges.count == 1 ? "성과 · \(first.title)" : "성과 \(badges.count)개 달성"
        var parts = badges.count == 1 ? ["\(first.tier.name) 뱃지"] : badges.prefix(2).map(\.title)
        let got = badges.compactMap { rewards[$0.id] }
        if !got.isEmpty { parts.append("보상 " + got.joined(separator: ", ")) }
        queue(PendingNotification(id: "badge-\(first.id)-\(Date().timeIntervalSince1970)", title: title, body: parts.joined(separator: " · "), sound: true))
    }

    /// 탈고. 어디에 보낼지 고르라는 말을 붙인다.
    func notify(finish note: FinishNote, book: Book) {
        queue(PendingNotification(id: "finish-\(note.id)", title: "탈고 · \(book.displayTitle)",
                                  body: "\(book.displayAuthorShort) · \(note.days)일 완주 · 출판사를 골라 주세요", sound: true))
    }

    /// 판매 단계. 소리는 내지 않는다.
    func notify(sales news: SalesNews, book: Book) {
        queue(PendingNotification(id: "sales-\(news.id)", title: "\(book.displayTitle) \(news.tier.title)",
                                  body: "누적 \(Format.integer(news.copies))부 돌파"))
    }

    /// 잠긴 동안의 진행. 소리는 내지 않는다.
    func notify(lockProgress progress: WritingProgress, added: Int, events: Int) {
        guard let book = progress.book else { return }
        var parts = ["+\(Format.integer(added))자"]
        if let event = progress.event { parts.append(event.text) }
        queue(PendingNotification(id: "lock-\(Date().timeIntervalSince1970)",
                                  title: "\(book.displayTitle) \(Format.percent(progress.fraction * 100))", body: parts.joined(separator: " · ")))
    }

    /// 선택지가 있는 사건. 선택지가 버튼으로 붙어 바로 보낸다.
    func notify(dilemma active: ActiveDilemma, kind: Dilemma, book: Book) {
        queue(PendingNotification(id: "dilemma-\(active.id)-\(active.startedAt.timeIntervalSince1970)",
                                  title: "\(book.displayAuthorShort) · \(kind.title)",
                                  body: active.text,
                                  sound: true, category: "\(Self.dilemmaCategory).\(kind.id)", urgent: true))
    }

    /// 사건에 답한 결과(알림 버튼으로 답했거나 작가가 알아서 골랐을 때).
    func notify(decision note: EventNote, kind: Dilemma, auto: Bool) {
        queue(PendingNotification(id: "decision-\(note.date.timeIntervalSince1970)",
                                  title: auto ? "작가 선택 · \(kind.title)" : kind.title, body: note.text, urgent: !auto))
    }

    /// 서평이 실렸을 때.
    func notify(review: Review, book: Book, authorLine: String?) {
        queue(PendingNotification(id: "review-\(review.id)", title: "서평 \(review.starText) · \(book.displayTitle)",
                                  body: "\(review.critic): \(review.text)",
                                  sound: review.stars == 5 || review.stars == 1))
    }

    /// 내기. 걸렸을 때는 받기·사양 버튼이 붙고, 끝났을 때는 결과만.
    func notify(bet: ActiveBet, text: String) {
        let name = Library.books.first { $0.authorShort == bet.guest }?.displayAuthorShort ?? bet.guest
        if bet.pending {
            let minutes = max(1, Int(bet.endsAt.timeIntervalSinceNow / 60))
            queue(PendingNotification(id: "bet-\(bet.offeredAt.timeIntervalSince1970)", title: "\(name)의 내기 · \(Format.integer(bet.target))자",
                                      body: "\(minutes)분 제한 · \(text)",
                                      sound: true, category: Self.betCategory, urgent: true))
        } else if let won = bet.won {
            queue(PendingNotification(id: "bet-result-\(bet.offeredAt.timeIntervalSince1970)", title: won ? "내기 승리" : "내기 패배",
                                      body: text, sound: true))
        }
    }

    /// 독자 주문. 소리는 내지 않는다.
    func notify(order: ReaderOrder, book: Book) {
        queue(PendingNotification(id: "order-\(order.offeredAt.timeIntervalSince1970)", title: "독자 주문 · \(book.displayTitle)",
                                  body: "신간 판매 +\(Int((Balance.orderBoost - 1) * 100))% · \(order.text)"))
    }

    /// 영감 게이지가 찼을 때. 소리는 내지 않는다.
    func notifyInspirationReady() {
        queue(PendingNotification(id: "inspiration-\(Date().timeIntervalSince1970)", title: "영감이 찼습니다",
                                  body: "\(Balance.inspirationMinutes)분 동안 집필 속도 \(Int(Balance.inspirationMultiplier))배"))
    }

    /// 마감. 새 과제는 소리 없이, 결과는 소리를 낸다.
    func notify(deadline: Deadline, result: Bool, text: String?) {
        if result {
            let met = deadline.met == true
            queue(PendingNotification(id: "deadline-result-\(deadline.id)", title: met ? "마감 달성 · \(deadline.title)" : "마감 실패 · \(deadline.title)",
                                      body: text ?? "", sound: true))
        } else {
            queue(PendingNotification(id: "deadline-\(deadline.id)", title: "주간 마감 · \(deadline.title)", body: deadline.letter))
        }
    }

    /// 지난주 돌아보기. 소리는 내지 않는다.
    func notify(weekly: WeeklyReview) {
        var parts = ["\(Format.integer(weekly.characters))자"]
        if weekly.finished > 0 { parts.append("탈고 \(weekly.finished)권") }
        if let sales = weekly.sales, sales > 0 { parts.append("판매 \(Format.integer(sales))부") }
        if let met = weekly.deadlineMet { parts.append(met ? "마감 달성" : "마감 실패") }
        queue(PendingNotification(id: "weekly-\(weekly.weekStart.timeIntervalSince1970)", title: "지난주 돌아보기",
                                  body: parts.joined(separator: " · ")))
    }

    /// 월요일 정산서. 소리는 내지 않는다.
    func notify(statement: Statement) {
        let delta = Int((statement.trustAfter - statement.trustBefore).rounded())
        let trust = "신뢰 \(TrustLevel.of(statement.trustAfter).title)" + (delta != 0 ? "(\(delta > 0 ? "+" : "")\(delta))" : "")
        queue(PendingNotification(id: statement.id, title: "서점 정산 · \(Format.integer(statement.sold))부",
                                  body: "\(trust) · \(statement.keeperLine)"))
    }

    /// 품절과 재판 입고.
    func notify(stock news: StockNews, book: Book) {
        switch news.kind {
        case .soldOut:
            let hours = news.due.map { max(1, Int(($0.timeIntervalSince(Date()) / 3600).rounded())) } ?? 0
            queue(PendingNotification(id: "stock-\(news.id)", title: "품절 · \(book.displayTitle)",
                                      body: "재판 \(Format.integer(news.copies))부 · \(hours)시간 뒤 입고"))
        case .restocked:
            queue(PendingNotification(id: "stock-\(news.id)", title: "재판 입고 · \(book.displayTitle)",
                                      body: "\(Format.integer(news.copies))부 입고 완료"))
        }
    }

    // 앱이 앞에 있어도 배너를 띄운다.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        completionHandler()
        if action == Self.useAction {
            Task { @MainActor in self.store?.useCure() }
        } else if action.hasPrefix(Self.chooseAction + "."), let index = Int(action.dropFirst(Self.chooseAction.count + 1)) {
            Task { @MainActor in self.store?.choose(index, fromNotification: true) }
        } else if action == Self.betAcceptAction || action == Self.betDeclineAction {
            let accept = action == Self.betAcceptAction
            Task { @MainActor in self.store?.answerBet(accept: accept) }
        }
    }
}
