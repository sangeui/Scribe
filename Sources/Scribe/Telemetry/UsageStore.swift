import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UsageStore {
    private(set) var snapshot: UsageSnapshot?
    private(set) var agentSource: AgentSource = UserDefaults.standard.string(forKey: AgentSource.key).flatMap(AgentSource.init(rawValue:)) ?? .antigravity
    private(set) var limits: [LimitRow] = []
    private(set) var limitsUpdatedAt: Date?
    private(set) var limitsMessage: String?
    /// 한도를 못 읽는 이유가 로그인이라 안내를 보여 줄 때.
    private(set) var needsLogin = false
    private(set) var plan: String?
    private(set) var isRefreshing = false
    private(set) var floatingVisible = UserDefaults.standard.bool(forKey: FloatingWindowController.visibleKey)
    private(set) var writing: WritingProgress?
    @ObservationIgnored private var lastEntries: [UsageEntry] = []
    @ObservationIgnored private var lastScannedFiles = 0
    @ObservationIgnored private var lastFilesByProvider: [AgentProvider: Int] = [:]
    /// 알림 권한. 설정 화면에서 보여 준다.
    private(set) var notificationStatus: NotificationStatus = .notAsked
    /// 방해 금지 동안 모아 둔 소식. 팝오버에 "소식 n건"으로 보인다.
    var heldNews: [String] = []
    /// 작가의 기분과 그 한 줄.
    private(set) var mood: Mood = .focused
    private var moodNote: (text: String, date: Date)?
    /// 손님 작가와의 마지막 말다툼(주인 작가의 말, 손님의 말).
    private(set) var quarrel: (host: String, guest: String, date: Date)?
    /// 마지막 작가 교대(떠난 작가, 온 작가, 둘의 말, 때). 상시 창은 몇 초 동안 교대 장면을, 팝오버는 15분 동안 두 줄을 보여 준다.
    private(set) var handoff: (from: String, to: String, leaving: String, arriving: String, date: Date)?
    @ObservationIgnored private var nextQuarrelAt = Date.distantPast
    /// 초상화를 연달아 누른 횟수와 마지막 누른 때.
    @ObservationIgnored private var pokes = 0
    @ObservationIgnored private var lastPokeAt = Date.distantPast
    @ObservationIgnored private var judge = MoodJudge()
    @ObservationIgnored private let lines = MoodLines()
    /// 마지막으로 토큰이 늘어난 때. 켤 때는 지금으로 둬서 바로 눈치를 보지 않는다.
    @ObservationIgnored private var lastTokenAt = Date()
    @ObservationIgnored private var lastTokens = -1
    /// 같은 기분이 이어질 때 다음 한마디를 할 시각.
    @ObservationIgnored private var nextLineAt = Date.distantFuture
    /// 화면이 잠겨 있으면 판정하지 않는다. 깨어난 뒤 30초도.
    @ObservationIgnored private var screenLocked = false {
        didSet {
            guard screenLocked != oldValue else { return }
            if screenLocked {
                lockedCharacters = writing?.totalCharacters ?? 0
                lockedEvents = writing?.recentEvents.count ?? 0
                lastLockNoteAt = Date()
            }
        }
    }
    /// 잠긴 순간의 글자 수와 기록 수, 마지막 진행 알림 시각.
    @ObservationIgnored private var lockedCharacters = 0.0
    @ObservationIgnored private var lockedEvents = 0
    @ObservationIgnored private var lastLockNoteAt = Date()
    @ObservationIgnored private var judgeNotBefore = Date.distantPast
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func moodLine(within seconds: TimeInterval) -> String? {
        guard let moodNote, Date().timeIntervalSince(moodNote.date) < seconds else { return nil }
        return moodNote.text
    }

    @ObservationIgnored private lazy var floating = FloatingWindowController(store: self)
    @ObservationIgnored private let scanner = ClaudeLogScanner()
    @ObservationIgnored private let writingStore: WritingStore
    @ObservationIgnored private lazy var notifier = Notifier(store: self)
    let updater = AppUpdater()

    /// `persist` 가 false 면 기록 파일을 읽기만 한다. `--dump`, `--snapshot` 같은 확인용 실행에서 쓴다.
    init(persist: Bool = true) {
        writingStore = WritingStore(persist: persist)
    }
    @ObservationIgnored private let limitsClient = ClaudeLimitsClient()
    @ObservationIgnored private var loop: Task<Void, Never>?
    /// 한도 API 를 다시 불러도 되는 시각. 비공식 API 라 5분보다 자주 부르지 않는다.
    @ObservationIgnored private var limitsNotBefore = Date.distantPast

    /// 로그를 다시 훑는 간격. 파일별 캐시가 있어 바뀐 파일만 읽으니 짧아도 가볍다.
    private static let usageInterval: Duration = .seconds(15)
    private static let limitsInterval: TimeInterval = 300

    /// 메뉴바 아이콘 프레임. 0.3초마다 하나씩 는다.
    private(set) var menuTick = 0
    @ObservationIgnored private var menuLoop: Task<Void, Never>?

    func start() {
        guard loop == nil else { return }
        menuLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                self?.menuTick &+= 1
            }
        }
        _ = notifier  // 알림 버튼이 앱이 뒤에 있을 때도 동작하도록 시작할 때 연결해 둔다.
        watchScreen()
        Task { await refreshNotificationStatus(ask: false) }
        if floatingVisible { floating.setVisible(true) }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshUsage()
                self.updateMood()
                self.updateQuarrel()
                self.noteLockProgress()
                await self.notifier.flushHeldIfAllowed()
                if Date() >= self.limitsNotBefore {
                    await self.refreshLimits(userInitiated: false)
                }
                await self.updater.checkIfNeeded()
                try? await Task.sleep(for: Self.usageInterval)
            }
        }
    }

    /// 팝오버의 새로고침 버튼. 메모리의 토큰을 버리고 Keychain 을 다시 읽는다.
    func refreshNow() async {
        await refreshUsage()
        await refreshLimits(userInitiated: true)
    }

    /// 로그 전체를 훑는다. 글자 수는 날짜별 누적이라 기간을 자르면 안 된다.
    /// 파일별 캐시가 있어 두 번째부터는 바뀐 파일만 다시 읽는다.
    func refreshUsage() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let (entries, files, filesByProvider) = await scanner.scan(since: .distantPast)
        lastEntries = entries
        lastScannedFiles = files
        lastFilesByProvider = filesByProvider
        show(UsageAggregator.snapshot(entries: entries, scannedFiles: files, filesByProvider: filesByProvider, source: agentSource))
    }

    /// 토큰 공급 에이전트 소스를 바꾼다. 지금까지 쓴 글자 수는 보존하고 날짜별 토큰 기준선만 새 소스에 맞춘다.
    func setAgentSource(_ source: AgentSource) {
        guard source != agentSource else { return }
        agentSource = source
        UserDefaults.standard.set(source.rawValue, forKey: AgentSource.key)
        writingStore.rebaseline()
        lastTokens = -1
        if source == .antigravity {
            limitsMessage = nil
            needsLogin = false
        } else if limits.isEmpty {
            Task { await refreshLimits(userInitiated: false) }
        }
        if !lastEntries.isEmpty || snapshot != nil {
            show(UsageAggregator.snapshot(
                entries: lastEntries,
                scannedFiles: lastScannedFiles,
                filesByProvider: lastFilesByProvider,
                source: source))
        }
    }

    /// 집계 결과를 넣고 집필 진행을 갱신한다. `--snapshot` 도 쓴다.
    func show(_ snapshot: UsageSnapshot) {
        let tokens = snapshot.days.reduce(0) { $0 + $1.tokens }
        if lastTokens >= 0, tokens > lastTokens { lastTokenAt = Date() }
        lastTokens = tokens
        self.snapshot = snapshot
        let author = writing?.book?.authorShort ?? Library.books.first?.authorShort
        let before = writing?.book
        writing = writingStore.apply(days: snapshot.days, author: author)
        noteHandoff(from: before, to: writing?.book)
        notifyIfNeeded()
        scheduleEventEnd()
    }

    /// `--tour` 등 오프스크린 프리뷰에서 샘플 스냅샷과 집필 상태를 직접 주입한다.
    func showSample(snapshot: UsageSnapshot, writing: WritingProgress, source: AgentSource = .antigravity) {
        self.agentSource = source
        self.snapshot = snapshot
        self.writing = writing
    }

    /// 책이 다른 작가의 것으로 넘어갔으면 교대 장면과 두 줄을 둔다. 켜자마자 처음 읽는 것은 교대가 아니다.
    private func noteHandoff(from before: Book?, to after: Book?) {
        guard let before, let after, before.authorShort != after.authorShort else { return }
        let lines = Handoffs.exchange(from: before.authorShort, to: after.authorShort, rolls: (Double.random(in: 0..<1), Double.random(in: 0..<1)))
        handoff = (before.authorShort, after.authorShort, lines.leaving, lines.arriving, Date())
        moodNote = (lines.arriving, Date())
    }

    @ObservationIgnored private var eventEndTask: Task<Void, Never>?

    /// 돌발 상황이 끝나는 시각에 맞춰 한 번 더 반영한다. 안 그러면 다음 갱신 때까지 끝난 상황이 화면에 남는다.
    private func scheduleEventEnd() {
        eventEndTask?.cancel()
        guard loop != nil, let endsAt = writing?.activeEvent?.endsAt else { return }
        let wait = max(0.5, endsAt.timeIntervalSinceNow + 0.5)
        eventEndTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard let self, !Task.isCancelled, let snapshot else { return }
            show(snapshot)
        }
    }

    /// 새 돌발 상황과 자연재해를 한 번씩만 알린다.
    private func notifyIfNeeded() {
        guard loop != nil else { return }
        for record in writingStore.unnotifiedDisasters {
            writingStore.markDisasterNotified(record.id)
            // 앱을 오래 꺼 두었다 켰을 때 지난 재해까지 알리지 않는다.
            guard Date().timeIntervalSince(record.startedAt) < 3600,
                  let disaster = Disasters.byID(record.event), let lost = record.lostCharacters else { continue }
            let book = Library.books.first { $0.file == record.book }
            notifier.notify(disaster: disaster, lost: lost, book: book, shield: record.endedBy.flatMap(ItemKind.init(rawValue:)))
        }
        let badges = writingStore.unnotifiedBadges
        let rewards = Dictionary(uniqueKeysWithValues: badges.compactMap { a in writingStore.rewardText(for: a.id).map { (a.id, $0) } })
        for achievement in badges { writingStore.markBadgeNotified(achievement.id) }
        if !badges.isEmpty { notifier.notify(badges: badges, rewards: rewards) }
        writing = writingStore.progress
        for note in writingStore.unnotifiedFinishes {
            writingStore.markFinishNotified(note.id)
            if let book = Library.books.first(where: { $0.file == note.book }), Date().timeIntervalSince(note.date) < 3600 {
                notifier.notify(finish: note, book: book)
            }
        }
        for news in writingStore.unnotifiedSales {
            writingStore.markSalesNotified(news.id)
            if let book = Library.books.first(where: { $0.file == news.book }), Date().timeIntervalSince(news.date) < 3600 {
                notifier.notify(sales: news, book: book)
            }
        }
        if let weekly = writingStore.state.weekly, weekly.notified != true {
            writingStore.markWeeklyNotified()
            notifier.notify(weekly: weekly)
        }
        if let statement = writingStore.unnotifiedStatement {
            writingStore.markStatementNotified(statement.id)
            notifier.notify(statement: statement)
        }
        for news in writingStore.unnotifiedStockNews {
            writingStore.markStockNotified(news.id)
            if let book = Library.books.first(where: { $0.file == news.book }), Date().timeIntervalSince(news.date) < 3600 {
                notifier.notify(stock: news, book: book)
            }
        }
        for review in writingStore.unnotifiedReviews {
            writingStore.markReviewNotified(review.id)
            guard let book = Library.books.first(where: { $0.file == review.book }), Date().timeIntervalSince(review.date) < 3600 else { continue }
            let line = writingStore.state.note.flatMap { $0.kind == .review && $0.event == review.id ? $0.text : nil }
            notifier.notify(review: review, book: book, authorLine: line)
        }
        // 작가가 알아서 고른 사건.
        if let note = writingStore.state.note, note.kind == .dilemma, note.notified != true {
            writingStore.markNoteNotified()
            if Date().timeIntervalSince(note.date) < 3600, let kind = Dilemmas.byID(note.event) {
                notifier.notify(decision: note, kind: kind, auto: true)
            }
        }
        if writingStore.inspirationReadyUnnotified {
            writingStore.markInspirationNotified()
            notifier.notifyInspirationReady()
        }
        if let deadline = writingStore.unnotifiedDeadline {
            let result = deadline.resultNotified == false
            let text = writingStore.state.note.flatMap { $0.kind == .deadline ? $0.text : nil }
            writingStore.markDeadlineNotified()
            notifier.notify(deadline: deadline, result: result, text: text)
            if result, deadline.failed == true, let snapshot { writing = writingStore.apply(days: snapshot.days, author: writing?.book?.authorShort) }
        }
        // 독자 주문이 왔을 때.
        if let note = writingStore.state.note, note.kind == .order, note.notified != true {
            writingStore.markNoteNotified()
            if Date().timeIntervalSince(note.date) < 3600, let order = writingStore.state.order, let book = Library.books.first(where: { $0.file == order.book }) {
                notifier.notify(order: order, book: book)
            }
        }
        // 내기: 걸렸을 때와 끝났을 때.
        if let note = writingStore.state.note, note.kind == .bet, note.notified != true {
            writingStore.markNoteNotified()
            if Date().timeIntervalSince(note.date) < 3600, let bet = writingStore.state.bet {
                notifier.notify(bet: bet, text: note.text)
            }
        }
        if let pending = writingStore.unnotifiedDilemma {
            writingStore.markDilemmaNotified()
            if let kind = Dilemmas.byID(pending.id), let book = writing?.book, Date().timeIntervalSince(pending.startedAt) < 3600 {
                notifier.notify(dilemma: pending, kind: kind, book: book)
            }
        }
        // 돌아옴: 상황이 저절로 끝났을 때 한 번. 오래된 것은 알리지 않는다.
        if let note = writingStore.state.note, note.kind == .returned || note.kind == .luck, note.notified != true {
            writingStore.markNoteNotified()
            if Date().timeIntervalSince(note.date) < 3600, let book = writing?.book {
                if note.kind == .luck, let luck = Lucks.byID(note.event) {
                    notifier.notify(luck: luck, note: note, book: book)
                } else if let event = AuthorEvents.byID(note.event) {
                    notifier.notify(returned: note, event: event, book: book)
                }
            }
        }
        guard let progress = writing, let active = progress.activeEvent, !active.notified,
              let event = progress.event, let book = progress.book else { return }
        writingStore.markNotified()
        let hasCure = progress.cureCount > 0
        notifier.notify(event: event, cause: progress.cause, book: book, hasCure: hasCure)
    }

    /// 한도 결과를 넣는다. `--snapshot` 도 쓴다.
    func show(_ result: LimitsResult) {
        limits = result.rows
        plan = result.plan
        limitsUpdatedAt = Date()
        limitsMessage = nil
        needsLogin = false
    }

    /// 알림 권한을 다시 읽는다. 설정 창을 열 때와 "다시 확인"에서 부른다.
    func refreshNotificationStatus(ask: Bool = true) async {
        notificationStatus = await notifier.refreshStatus(ask: ask)
    }

    /// 설정의 "시험 알림 보내기".
    func sendTestNotification() {
        Task {
            await notifier.sendTest()
            notificationStatus = notifier.status
        }
    }

    /// 시스템 설정의 알림 항목을 연다. 허용은 사용자가 직접 켠다.
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 아이템을 써서 상황을 끝낸다.
    func use(_ item: ItemKind) {
        writing = writingStore.use(item)
        notifyIfNeeded()
    }

    /// 지금 상황에 맞는 아이템을 쓴다. 알림의 버튼이 부른다. 결과(통함·거절)는 알림으로 다시 알린다.
    func useCure() {
        guard let item = writing?.cureItem, let event = writing?.event, let book = writing?.book else { return }
        use(item)
        if let note = writing?.note, Date().timeIntervalSince(note.date) < 5 {
            notifier.notify(result: note, event: event, book: book)
        }
    }

    /// 선택지가 있는 사건에 답한다. 알림 버튼으로 답했으면 결과를 알림으로 돌려준다.
    func choose(_ index: Int, fromNotification: Bool = false) {
        let kind = writing?.dilemmaKind
        writing = writingStore.choose(index)
        if fromNotification, let kind, let note = writing?.note, note.kind == .dilemma, Date().timeIntervalSince(note.date) < 5 {
            notifier.notify(decision: note, kind: kind, auto: false)
        }
        notifyIfNeeded()
    }

    /// 영감 게이지가 찼을 때 영감의 날을 켠다.
    func igniteInspiration() {
        writing = writingStore.igniteInspiration()
        notifyIfNeeded()
        scheduleEventEnd()
    }

    /// 작업실 가구를 산다.
    func buy(_ furniture: Furniture) {
        writing = writingStore.buy(furniture)
        notifyIfNeeded()
    }

    /// 탈고한 원고를 보낼 출판사를 고른다.
    func choosePublisher(_ publisher: Publisher, for noteID: String) {
        writing = writingStore.choosePublisher(publisher, for: noteID)
        notifyIfNeeded()
    }

    /// 서점: 이달의 책, 광고.
    func feature(_ file: String?) {
        writing = writingStore.feature(file)
        notifyIfNeeded()
    }

    func advertise(_ file: String) {
        writing = writingStore.advertise(file)
        notifyIfNeeded()
    }

    func place(_ file: String, _ slot: ShopSlot) {
        writing = writingStore.place(file, slot)
    }

    func leaveToKeeper(_ file: String) {
        writing = writingStore.leaveToKeeper(file)
    }

    func dismissStatement(_ id: String) {
        writingStore.dismissStatement(id)
        writing = writingStore.progress
    }

    /// 마을: 풀밭의 물건을 줍는다. 주운 아이템 이름, 없으면 nil.
    func pickup() -> String? {
        let kind = writingStore.pickup()
        writing = writingStore.progress
        return kind?.title
    }

    /// 살롱: 작가에게 같이 쓰자고 청한다. 결과 한 줄. 오늘 이미 청했으면 nil.
    func invite(_ author: String) -> String? {
        guard let result = writingStore.invite(author) else { return nil }
        writing = writingStore.progress
        notifyIfNeeded()
        return result.text
    }

    /// 마을: 손님에게 책을 권한다. 결과 한 줄.
    func recommend() -> String? {
        guard let (book, copies) = writingStore.recommend() else { return nil }
        writing = writingStore.progress
        return "\(book.displayTitle)(을|를) \(copies)부 사 갔습니다".resolvedParticles
    }

    /// 손님 작가의 내기를 받거나 사양한다.
    func answerBet(accept: Bool) {
        writing = writingStore.answerBet(accept: accept)
        notifyIfNeeded()
    }

    /// 상시 창의 초상화를 눌렀을 때. 상황에 맞는 말 한 줄을 3분 동안 둔다. 연달아 누르면 귀찮아한다.
    func tapPortrait() {
        guard let writing, let book = writing.book else { return }
        let now = Date()
        pokes = now.timeIntervalSince(lastPokeAt) < 6 ? pokes + 1 : 1
        lastPokeAt = now
        let text = Chatter.line(author: book.authorShort, progress: writing, mood: mood, now: now, pokes: pokes,
                                rolls: (Double.random(in: 0..<1), Double.random(in: 0..<1)))
        moodNote = (text, now)
        writingStore.bump(.taps)
        self.writing = writingStore.progress
        notifyIfNeeded()
    }

    /// 15초마다. 손님 작가가 있으면 가끔 둘이 말다툼한다. 주인의 말은 상시 창 한 줄로, 둘의 말은 팝오버에 보인다.
    private func updateQuarrel() {
        guard let writing, let host = writing.book?.authorShort, let guest = writing.guestAuthor, writing.event == nil else {
            if quarrel != nil, writing?.guestAuthor == nil { quarrel = nil }
            return
        }
        let now = Date()
        if nextQuarrelAt == .distantPast { nextQuarrelAt = now.addingTimeInterval(TimeInterval(Balance.quarrelMinutes * 60) * Double.random(in: 0.2...0.6)) }
        guard now >= nextQuarrelAt else { return }
        // 말다툼 차례에 가끔은 내기를 건다. 걸었으면 이번엔 말다툼 대신.
        if Double.random(in: 0..<1) < Balance.betChance, writingStore.offerBet(now: now) {
            self.writing = writingStore.progress
            notifyIfNeeded()
            nextQuarrelAt = now.addingTimeInterval(TimeInterval(Balance.quarrelMinutes * 60))
            return
        }
        let lines = Quarrels.exchange(host: host, guest: guest, rolls: (Double.random(in: 0..<1), Double.random(in: 0..<1)))
        quarrel = (lines.host, lines.guest, now)
        moodNote = (lines.host, now)
        writingStore.bump(.quarrels)
        self.writing = writingStore.progress
        nextQuarrelAt = now.addingTimeInterval(TimeInterval(Balance.quarrelMinutes * 60) * Double.random(in: 0.7...1.3))
    }

    /// 다른 데서 내보낸 기록을 가져온다. 지금 기록은 백업으로 남긴다. 읽을 수 없는 파일이면 false.
    /// 기록 옮기기의 마지막 결과. 설정 패널이 닫혀도 남는다.
    var transferMessage: String?

    /// 기록을 내보낸다. 저장 창을 띄우면 팝오버와 설정 패널이 닫히므로 결과는 알림과 `transferMessage` 로 알린다.
    func exportRecordInteractively() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "scribe-writing-\(DayKey.string(from: Date())).json"
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            try FileManager.default.copyItem(at: WritingStore.defaultURL, to: url)
            reportTransfer("기록을 내보냈습니다", detail: url.lastPathComponent)
        } catch {
            reportTransfer("내보내지 못했습니다", detail: error.localizedDescription)
        }
    }

    /// 기록을 가져온다. 결과는 내보내기와 같은 방법으로 알린다.
    func importRecordInteractively() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            let ok = await importRecord(from: url)
            reportTransfer(ok ? "기록을 가져왔습니다" : "가져오지 못했습니다", detail: ok ? url.lastPathComponent : "읽을 수 없는 파일입니다")
        }
    }

    private func reportTransfer(_ title: String, detail: String) {
        transferMessage = title
        // 방금 누른 일의 답이라 방해 금지 중에도 바로 보낸다.
        notifier.sendNow(PendingNotification(id: "transfer-\(Date().timeIntervalSince1970)", title: title, body: detail + "."))
    }

    func importRecord(from url: URL) async -> Bool {
        guard writingStore.replace(with: url) else { return false }
        await refreshUsage()
        return true
    }

    // MARK: 기분

    /// 화면 잠금과 잠자기를 본다. 잠긴 동안은 판정을 멈추고, 깨어난 뒤 30초는 기다린다.
    private func watchScreen() {
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked = true }
        })
        observers.append(distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screenLocked = false
                self?.judgeNotBefore = Date().addingTimeInterval(30)
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.judgeNotBefore = Date().addingTimeInterval(30) }
        })
    }

    /// 잠긴 동안 글자가 늘면 정해진 간격으로 진행을 알린다. 잠금 화면에 알림으로 보인다.
    private func noteLockProgress() {
        guard screenLocked, LockProgress.enabled, let writing,
              Date().timeIntervalSince(lastLockNoteAt) >= TimeInterval(LockProgress.minutes * 60) else { return }
        let added = Int(writing.totalCharacters - lockedCharacters)
        guard added > 0 else { return }
        notifier.notify(lockProgress: writing, added: added, events: max(0, writing.recentEvents.count - lockedEvents))
        lastLockNoteAt = Date()
    }

    /// 15초마다. 입력 유휴 시간과 토큰 흐름으로 기분을 정하고, 바뀌면 한 줄을 둔다.
    private func updateMood() {
        guard MoodJudge.enabled else {
            if mood != .focused { mood = .focused; moodNote = nil }
            return
        }
        guard !screenLocked, Date() >= judgeNotBefore else { return }
        judge.slackAfter = TimeInterval(MoodJudge.slackMinutes * 60)
        let input = MoodInput(userIdle: UserActivity.secondsSinceLastInput(),
                              tokenIdle: Date().timeIntervalSince(lastTokenAt),
                              eventActive: writing?.event != nil, guestActive: writing?.guestAuthor != nil)
        let result = judge.update(input)
        let author = writing?.book?.authorShort ?? ""
        if let changed = result.changed {
            mood = changed
            if result.caught { writingStore.bump(.caught) }
            if let text = lines.line(for: changed, author: author, caught: result.caught) {
                moodNote = (text, Date())
            }
            nextLineAt = Date().addingTimeInterval(10 * 60)
        } else if mood == judge.current, mood == .waiting || mood == .alone || mood == .slacking, Date() >= nextLineAt {
            if let text = lines.line(for: mood, author: author) { moodNote = (text, Date()) }
            nextLineAt = Date().addingTimeInterval(10 * 60)
        }
    }

    /// 원고 읽기 창을 열었을 때(성과용).
    func noteRead() {
        writingStore.bump(.reads)
        writing = writingStore.progress
        notifyIfNeeded()
    }

    /// 서재에서 순서를 바꿨을 때.
    func writeNext(_ bookIndex: Int) {
        writingStore.writeNext(bookIndex)
        writing = writingStore.progress
    }

    func focusAuthor(_ author: String) {
        writingStore.focus(author: author)
        writing = writingStore.progress
    }

    func dismissFinish(_ id: String) {
        writingStore.dismissFinish(id)
        writing = writingStore.progress
    }

    func dismissWeekly() {
        writingStore.dismissWeekly()
        writing = writingStore.progress
    }

    /// 아이템 교환.
    func exchange(_ from: ItemKind, for to: ItemKind) {
        writing = writingStore.exchange(from, for: to)
        notifyIfNeeded()
    }

    /// 훈장 진열대(최대 3칸)에 뱃지를 장식하거나 내린다.
    func toggleBadge(_ id: String) {
        writing = writingStore.toggleBadge(id)
    }

    /// 후원자 칭호를 바꾼다.
    func selectPatronTitle(_ id: String?) {
        writing = writingStore.selectPatronTitle(id)
    }

    /// 데스크톱 상시 표시 창.
    var isFloatingVisible: Bool {
        get { floatingVisible }
        set { setFloatingVisible(newValue) }
    }

    func setFloatingVisible(_ visible: Bool) {
        floatingVisible = visible
        floating.setVisible(visible)
    }

    /// 설정에서 크기나 투명도를 바꿨을 때.
    func updateFloatingAppearance() {
        floating.applyAppearance()
    }

    /// 상시 창에서 지금 보이는 부분이 바뀌었을 때(모양 전환 중 매 프레임). 창 크기를 거기에 맞춘다.
    func updateFloatingFrame(visible: CGRect) {
        floating.apply(visible: visible)
    }

    private func refreshLimits(userInitiated: Bool) async {
        guard agentSource != .antigravity else {
            limitsMessage = nil
            needsLogin = false
            return
        }
        do {
            show(try await limitsClient.fetch(userInitiated: userInitiated))
            limitsNotBefore = Date().addingTimeInterval(Self.limitsInterval)
        } catch let error as LimitsError {
            // 통합 모드에서 Antigravity 로그만 쓰는 중이고 Claude 로그인이 없으면 로그인 안내를 띄우지 않는다.
            if agentSource == .all, error.needsLogin,
               lastFilesByProvider[.antigravity, default: 0] > 0,
               lastFilesByProvider[.claude, default: 0] == 0 {
                limitsMessage = nil
                needsLogin = false
            } else {
                limitsMessage = error.message
                needsLogin = error.needsLogin
            }
            if case .rateLimited(let retryAfter) = error {
                limitsNotBefore = Date().addingTimeInterval(retryAfter ?? 900)
            } else {
                limitsNotBefore = Date().addingTimeInterval(Self.limitsInterval)
            }
        } catch {
            if agentSource == .claude || userInitiated {
                limitsMessage = "한도를 불러오지 못했습니다."
            }
            limitsNotBefore = Date().addingTimeInterval(Self.limitsInterval)
        }
    }

    /// 메뉴바에 붙일 5시간 한도 %.
    var fiveHourPercent: Double? { limits.first { $0.name == "5시간" }?.percent }

    /// 마을 장작더미용 5시간 기준. Claude 한도가 있으면 그것을, Antigravity 모드면 최근 5시간 활동량을 바탕으로 돌려준다.
    var effectiveFuelLimit: LimitRow? {
        if agentSource != .antigravity, let claudeFuel = limits.first(where: { $0.name == "5시간" }) {
            return claudeFuel
        }
        guard let recent = snapshot?.recentFiveHourTokens, recent > 0 else { return nil }
        // 최근 5시간 동안 5,000만 토큰을 100% 활력으로 환산해 장작더미를 쌓는다.
        let used = min(95.0, Double(recent) / 50_000_000.0 * 100.0)
        return LimitRow(name: "5시간 활동", percent: used, resetsAt: nil)
    }
}
