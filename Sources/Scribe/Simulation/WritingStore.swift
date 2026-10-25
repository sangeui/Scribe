import Foundation
import SwiftUI

/// 날짜별로 쓴 글자를 파일에 두고, 늘어난 토큰만 글자로 바꾼다.
@MainActor
final class WritingStore {
    private(set) var state: WritingState
    private let url: URL
    private let persist: Bool
    /// 파일이 없을 때 처음 한 번만 참. 그때까지 쓴 토큰은 글자로 바꾸지 않는다.
    private var needsBaseline: Bool

    /// 기록 파일 자리. `~/Library/Application Support/<앱 이름>/writing.json`
    static let defaultURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("Scribe")
        // 앱 이름이 Columbus 였을 때의 기록을 한 번 옮겨 온다. 백업과 옛 탐험 기록(journey.json)도 같이.
        let old = support.appendingPathComponent("Columbus")
        let fm = FileManager.default
        if !fm.fileExists(atPath: folder.path), fm.fileExists(atPath: old.path) {
            try? fm.moveItem(at: old, to: folder)
        }
        return folder.appendingPathComponent("writing.json")
    }()

    init(url: URL? = nil, persist: Bool = true) {
        self.url = url ?? Self.defaultURL
        self.persist = persist
        let backup = self.url.deletingPathExtension().appendingPathExtension("backup.json")
        if let data = try? Data(contentsOf: self.url) {
            do {
                state = try JSONDecoder().decode(WritingState.self, from: data)
                needsBaseline = false
            } catch {
                if persist {
                    let aside = self.url.deletingPathExtension()
                        .appendingPathExtension("broken-\(Int(Date().timeIntervalSince1970)).json")
                    try? FileManager.default.moveItem(at: self.url, to: aside)
                    NSLog("writing.json 을 읽지 못해 %@ 로 옮겼습니다: %@", aside.lastPathComponent, "\(error)")
                }
                // 깨졌으면 직전 백업을 쓴다. 그것도 안 되면 빈 기록으로 시작하되, 지난 토큰이 글자가 되지 않게 기준선을 다시 잡는다.
                if let backupData = try? Data(contentsOf: backup), let restored = try? JSONDecoder().decode(WritingState.self, from: backupData) {
                    state = restored
                    needsBaseline = false
                    NSLog("writing.backup.json 에서 되살렸습니다")
                } else {
                    state = WritingState()
                    needsBaseline = true
                }
                // 깨진 파일을 옮긴 직후의 첫 저장은 백업을 덮어쓰지 않는다(마지막 정상 백업을 지킨다).
                skipBackupOnce = true
            }
        } else {
            state = WritingState()
            needsBaseline = true
        }
    }

    /// 다음 저장에서 백업 복사를 건너뛴다.
    private var skipBackupOnce = false

    /// 0..<1 난수. 확인용 실행은 정해진 값을 넣는다.
    var random: () -> Double = { Double.random(in: 0..<1) }
    /// 새 토큰 100만 개마다 돌발 상황이 생길 확률. 확인용 실행은 0 을 넣는다.
    var eventChance = Balance.eventChancePerMillion
    /// 아이템을 거절할 확률. 확인용 실행에서 바꾼다.
    var refusalChance = Balance.refusalChance
    /// 성과 보상 아이템을 줄지. 확인용 실행에서 아이템 수를 셀 때는 끈다.
    var badgeRewards = true
    /// 새 토큰 100만 개마다 자연재해가 생길 확률. 확인용 실행은 0 을 넣는다.
    var disasterChance = Balance.disasterChancePerMillion
    /// 새 토큰 100만 개마다 행운이 생길 확률. 확인용 실행은 0 을 넣는다.
    var luckChance = Balance.luckChancePerMillion
    /// 새 토큰 100만 개마다 선택지가 있는 사건이 생길 확률. 확인용 실행은 0 을 넣는다.
    var dilemmaChance = Balance.dilemmaChancePerMillion

    /// 에이전트 데이터 소스를 바꿨을 때. 지금까지 쓴 글자 수는 그대로 두고 날짜별 토큰 기준선만 새 소스에 맞춘다.
    func rebaseline() {
        needsBaseline = true
    }

    /// 스캔한 일별 토큰을 반영한다. 늘어난 토큰만 글자가 된다.
    /// 처음 만들어질 때는 그때까지의 토큰을 모두 본 것으로 적는다. 아니면 지난 몇 달 치 토큰으로 모든 책이 한 번에 끝난다.
    ///
    /// 순서: ① 끝날 시각이 지난 상황을 끝낸다(앱을 껐다 켜도 오래전에 끝난 상황이 토큰을 삼키지 않게)
    /// ② 상황이 없을 때만 글자를 더한다 ③ 토큰을 본 것으로 적는다 ④ 아이템을 센다(멈춘 동안도) ⑤ 새 상황을 추첨한다.
    func apply(days: [DayUsage], now: Date = Date(), author: String? = nil) -> WritingProgress {
        let baseline = needsBaseline
        needsBaseline = false
        var changed = baseline
        if baseline {
            let incoming = Dictionary(uniqueKeysWithValues: days.map { (DayKey.string(from: $0.day), $0) })
            for key in state.days.keys {
                let d = incoming[key]
                state.days[key]?.tokens = d?.tokens ?? 0
                state.days[key]?.read = d?.read ?? 0
            }
        }
        let before = WritingProgress(state: state, now: now)
        let finishedBefore = before.finished.count
        let currentAuthor = before.book?.authorShort
        if Self.staminaEnabled, recoverStamina(now: now) { changed = true }
        if let luck = state.luck, now >= luck.endsAt {
            state.luck = nil
            if let kind = Lucks.byID(luck.id) {
                state.note = EventNote(text: Lucks.endText(kind), date: luck.endsAt, event: luck.id, kind: .luck, notified: true)
            }
            changed = true
        }
        if let active = state.event, now >= active.endsAt {
            state.event = nil
            let text = AuthorEvents.byID(active.id).flatMap { $0.pick($0.returns, random()) } ?? "다시 자리에 앉아 펜을 듭니다"
            state.note = EventNote(text: text, date: active.endsAt, event: active.id, kind: .returned)
            state.closeRecord(at: active.endsAt, by: nil, outcome: text)
            // 탈진에서 깨면 체력이 반은 돌아와 있다.
            if active.id == AuthorEvents.exhausted.id, let currentAuthor {
                var sheet = state.sheets[currentAuthor] ?? AuthorSheet()
                sheet.stamina = max(sheet.stamina, StatPerks(sheet).staminaMax * 0.5)
                sheet.staminaAt = now
                state.sheets[currentAuthor] = sheet
            }
            changed = true
        }
        if state.boosts.contains(where: { $0.endsAt <= now }) {
            state.boosts.removeAll { $0.endsAt <= now }
            changed = true
        }
        // 답이 없는 사건은 시간이 지나면 작가가 알아서 고른다.
        if let pending = state.dilemma, now >= pending.expiresAt, let dilemma = Dilemmas.byID(pending.id) {
            choose(min(dilemma.options.count - 1, Int(random() * Double(dilemma.options.count))), now: pending.expiresAt, auto: true)
            changed = true
        }
        if publishReviews(now: now) { changed = true }
        if settleUnchosenPublishers(now: now) { changed = true }
        if state.ads.contains(where: { $0.value <= now }) { state.ads = state.ads.filter { $0.value > now }; changed = true }
        if state.shopBoosts.contains(where: { $0.endsAt <= now }) { state.shopBoosts.removeAll { $0.endsAt <= now }; changed = true }
        if Self.stockEnabled, tendShop(now: now) { changed = true }
        let live = Boosts(state.boosts, now: now)
        let weather = Weather.of(now)
        let studio = StudioPerks(owned: state.studio)
        let hourNow = Calendar.current.component(.hour, from: now)
        let night = hourNow >= 22 || hourNow < 5
        let sheetPerks = StatPerks(currentAuthor.flatMap { state.sheets[$0] })
        var newTokens = 0
        var newRead = 0
        for day in days where day.tokens > 0 {
            let key = DayKey.string(from: day.day)
            var record = state.days[key] ?? WritingRecord(tokens: 0, characters: 0)
            // 읽기 토큰은 글자와 따로 센다. 처음 보는 날은 기준만 적는다.
            if let seen = record.read, day.read > seen, !baseline { newRead += day.read - seen }
            if record.read == nil || day.read > record.read! {
                record.read = day.read
                state.days[key] = record
                changed = true
            }
            guard day.tokens > record.tokens else { continue }
            let delta = day.tokens - record.tokens
            if !baseline && state.event == nil {
                let inspired = state.luck?.id == Lucks.inspiration.id ? Balance.inspirationMultiplier : 1
                let tired = Self.staminaEnabled && currentAuthor.flatMap { state.sheets[$0] }.map { $0.stamina < sheetPerks.staminaMax * Balance.staminaTiredBelow } == true
                let added = Double(delta) / 1_000_000 * Writing.charactersPerMillionTokens * (1 + perks.characterBonus) * inspired * live.characters
                    * weather.characters * (night ? studio.nightCharacters : 1) * sheetPerks.characters * (tired ? Balance.staminaTiredMultiplier : 1)
                record.characters += added
                let hour = Calendar.current.component(.hour, from: now)
                if hour >= 22 || hour < 5 { state.counters[Counter.nightCharacters.rawValue, default: 0] += Int(added) }
                if Self.staminaEnabled, let currentAuthor { wear(author: currentAuthor, tokens: delta, now: now) }
            }
            record.tokens = day.tokens
            state.days[key] = record
            if !baseline { newTokens += delta }
            if !baseline, state.event != nil, let i = state.openRecordIndex { state.eventLog[i].pausedTokens += delta }
            changed = true
        }
        if newRead > 0 {
            let gauge = state.inspiration
            state.inspiration = min(Balance.inspirationGaugeTokens, state.inspiration + Int(Double(newRead) * sheetPerks.inspiration))
            if gauge < Balance.inspirationGaugeTokens, state.inspiration >= Balance.inspirationGaugeTokens { state.inspirationNotified = false }
            changed = true
        }
        if newTokens > 0 {
            sell(tokens: newTokens, now: now)
            state.tokensTowardItem += newTokens
            let perItem = Int(Double(Balance.tokensPerItem) * perks.itemTokens * sheetPerks.itemTokens)
            while state.tokensTowardItem >= perItem {
                state.tokensTowardItem -= perItem
                giveRandomItem()
            }
            if persist { rollEvent(newTokens: newTokens, now: now, author: author) }
        }
        if changed { noteFinishes(since: finishedBefore, now: now) }
        // 내기와 독자 주문은 방금 더한 글자까지 세어 매긴다.
        if resolveBet(now: now) { changed = true }
        if checkOrder(now: now) { changed = true }
        noteWeek(now: now)
        if Self.stockEnabled, settleWeek(now: now) { changed = true }
        // 마감은 토큰이 없어도 본다. 주가 바뀌면 지난 과제를 매기고 새 과제를 내야 한다.
        if checkDeadline(now: now) { changed = true }
        if changed { save(now: now) }
        return WritingProgress(state: state, now: now)
    }

    // MARK: 마을

    /// 풀밭에 떨어진 물건을 줍는다. 하루에 한 번. 주운 아이템 이름을 돌려준다.
    @discardableResult
    func pickup(now: Date = Date()) -> ItemKind? {
        let today = DayKey.string(from: Calendar.current.startOfDay(for: now))
        guard state.pickupDay != today else { return nil }
        state.pickupDay = today
        guard let kind = giveRandomItem() else { save(now: now); return nil }
        state.counters[Counter.pickups.rawValue, default: 0] += 1
        state.note = EventNote(text: "풀밭에서 \(kind.title)(을|를) 주웠습니다".resolvedParticles, date: now, event: "pickup", kind: .shop, notified: true)
        save(now: now)
        return kind
    }

    /// 손님에게 책을 권한다. 하루 세 번까지. 진열창·매대 책 가운데 하나가 몇 부 팔리고 신뢰가 조금 오른다. 판 책과 부수를 돌려준다.
    @discardableResult
    func recommend(now: Date = Date()) -> (Book, Int)? {
        let today = DayKey.string(from: Calendar.current.startOfDay(for: now))
        if state.recommendDay != today { state.recommendDay = today; state.recommendCount = 0 }
        guard state.recommendCount < Balance.recommendPerDay else { return nil }
        let progress = WritingProgress(state: state, now: now)
        let shelf = progress.books(in: .window) + progress.books(in: .counter)
        guard !shelf.isEmpty else { return nil }
        let book = shelf[min(shelf.count - 1, Int(random() * Double(shelf.count)))]
        let copies = min(state.shop.stock(of: book.file), Balance.recommendCopies.lowerBound + Int(random() * Double(Balance.recommendCopies.upperBound - Balance.recommendCopies.lowerBound)))
        guard copies > 0 else { return nil }
        state.recommendCount += 1
        state.sales[book.file, default: 0] += Double(copies)
        state.salesByDay[today, default: 0] += Double(copies)
        if Self.stockEnabled {
            state.shop.stock[book.file, default: 0] -= Double(copies)
            state.shop.noteSold(book.file, copies: Double(copies), now: now)
            state.shop.adjustTrust(Balance.trustRecommend, reason: "손님에게 \(book.displayTitle)(을|를) 권해 팔았음".resolvedParticles, now: now)
            if state.shop.stock(of: book.file) <= 0 { soldOut(book.file, now: now) }
        }
        state.counters[Counter.recommendations.rawValue, default: 0] += 1
        state.note = EventNote(text: "권한 \(book.displayTitle)(을|를) 손님이 \(copies)부 사 갔습니다".resolvedParticles, date: now, event: "recommend", kind: .shop, notified: true)
        save(now: now)
        return (book, copies)
    }

    /// 살롱에서 작가에게 같이 쓰자고 청한다. 하루 한 번, 행운이 없을 때만. 매력이 높을수록 잘 응한다.
    /// 응하면 그 작가가 손님 작가로 온다. (응했는지, 한 줄)을 돌려준다. 오늘 이미 청했으면 nil.
    @discardableResult
    func invite(_ author: String, now: Date = Date()) -> (accepted: Bool, text: String)? {
        let today = DayKey.string(from: Calendar.current.startOfDay(for: now))
        guard state.inviteDay != today, state.luck == nil else { return nil }
        state.inviteDay = today
        let name = Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author
        let current = WritingProgress(state: state, now: now).book?.authorShort
        let charm = (current.flatMap { state.sheets[$0] } ?? AuthorSheet()).level(.charm)
        let chance = min(Balance.inviteMaxChance, Balance.inviteBaseChance + Double(charm) * Balance.inviteCharmBonus)
        state.counters[Counter.invites.rawValue, default: 0] += 1
        if random() < chance {
            grant(Lucks.guest, now: now, author: current, invited: author)
            return (true, L10n.tr("\(name)(이|가) 외투를 집어 듭니다. \"그럼 가 볼까요\" 작업실로 같이 갑니다").resolvedParticles)
        }
        save(now: now)
        let excuses = ["오늘은 여기가 좋소. 내일 다시 물어보시오", "지금 쓰는 게 있어서. 다음에", "커피를 다 마시고 나면 생각해 보지", "\(name)(은|는) 고개만 젓습니다"]
        return (false, L10n.tr(excuses[min(excuses.count - 1, Int(random() * Double(excuses.count)))]).resolvedParticles)
    }

    // MARK: 체력과 능력치

    /// 지금 작가의 능력치 배수.
    private func sheetPerks(now: Date) -> StatPerks {
        StatPerks((WritingProgress(state: state, now: now).book?.authorShort).flatMap { state.sheets[$0] })
    }

    /// 모든 작가의 체력이 시간만큼 돌아온다. 밤(22~5시)과 쉬는 동안(상황 중)은 두 배. 바뀐 게 있으면 true.
    private func recoverStamina(now: Date) -> Bool {
        var changed = false
        let hour = Calendar.current.component(.hour, from: now)
        let rate = Balance.staminaRecoveryPerHour * ((hour >= 22 || hour < 5) || state.event != nil ? 2 : 1)
        for (author, var sheet) in state.sheets {
            let cap = StatPerks(sheet).staminaMax
            guard sheet.stamina < cap else { continue }
            let hours = max(0, now.timeIntervalSince(sheet.staminaAt ?? now) / 3600)
            sheet.stamina = min(cap, sheet.stamina + hours * rate)
            sheet.staminaAt = now
            state.sheets[author] = sheet
            changed = true
        }
        return changed
    }

    /// 글을 쓴 만큼 체력이 줄고 능력치 토큰이 쌓인다. 0이 되면 탈진, 토큰이 차면 능력치 하나가 1 오른다.
    private func wear(author: String, tokens: Int, now: Date) {
        var sheet = state.sheets[author] ?? AuthorSheet()
        let perks = StatPerks(sheet)
        if sheet.staminaAt == nil { sheet.staminaAt = now }
        sheet.stamina -= Double(tokens) / 1_000_000 * Balance.staminaPerMillion * perks.staminaDrain
        sheet.tokensTowardStat += tokens
        let name = Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author
        while sheet.tokensTowardStat >= Balance.statTokens {
            sheet.tokensTowardStat -= Balance.statTokens
            let open = Stat.allCases.filter { sheet.level($0) < Balance.statMax }
            guard !open.isEmpty else { break }
            let stat = open[min(open.count - 1, Int(statRandom() * Double(open.count)))]
            sheet.stats[stat.rawValue] = sheet.level(stat) + 1
            state.counters[Counter.statUps.rawValue, default: 0] += 1
            state.note = EventNote(text: Format.resolve("\(name)의 \(stat.title)(이|가) \(sheet.level(stat))(이|가) 됐습니다. \(stat.raisedLine)"),
                                   date: now, event: stat.rawValue, kind: .stat, notified: true)
        }
        if sheet.stamina <= 0 {
            sheet.stamina = 0
            state.sheets[author] = sheet
            if state.event == nil {
                state.counters[Counter.exhaustions.rawValue, default: 0] += 1
                start(AuthorEvents.exhausted, now: now, author: author, minutes: Double(Balance.exhaustedMinutes))
            }
            return
        }
        state.sheets[author] = sheet
    }

    // MARK: 영감 게이지

    /// 게이지가 찼을 때 영감의 날을 켠다. 행운이 진행 중이면 그대로다.
    @discardableResult
    func igniteInspiration(now: Date = Date()) -> WritingProgress {
        guard state.inspiration >= Balance.inspirationGaugeTokens, state.luck == nil else { return WritingProgress(state: state) }
        state.inspiration = 0
        state.inspirationNotified = nil
        state.counters[Counter.ignitions.rawValue, default: 0] += 1
        grant(Lucks.inspiration, now: now)
        return WritingProgress(state: state)
    }

    /// 게이지가 찼는데 아직 알리지 않았으면 true. 알리고 나면 `markInspirationNotified`.
    var inspirationReadyUnnotified: Bool { state.inspiration >= Balance.inspirationGaugeTokens && state.inspirationNotified == false }

    func markInspirationNotified() {
        state.inspirationNotified = true
        save()
    }

    // MARK: 마감

    /// 이번 주 과제의 진행.
    func deadlineProgress(_ deadline: Deadline, now: Date) -> Int {
        switch deadline.kind {
        case .characters:
            return Int(state.days.reduce(0.0) { sum, pair in
                guard let date = DayKey.date(from: pair.key), date >= deadline.weekStart else { return sum }
                return sum + pair.value.net
            })
        case .finish:
            return WritingProgress(state: state, now: now).finished.count
        case .sales:
            return Int(state.salesByDay.reduce(0.0) { sum, pair in
                guard let date = DayKey.date(from: pair.key), date >= deadline.weekStart else { return sum }
                return sum + pair.value
            })
        }
    }

    /// 새 주면 지난 과제를 매기고 새 과제를 낸다. 진행 중인 과제가 목표에 닿으면 바로 지킨 것으로 적고 보상한다. 바뀐 게 있으면 true.
    /// 확인용 실행이 마감을 끌 때.
    nonisolated(unsafe) static var deadlinesEnabled = true
    /// 확인용 실행이 서점 사건과 독자 주문의 추첨을 끌 때. 직접 부르는 것(`happenInShop`, `offerOrder`)은 그대로 된다.
    nonisolated(unsafe) static var shopEnabled = true
    /// 확인용 실행이 체력과 능력치를 끌 때. 켜 두면 큰 토큰을 넣는 확인마다 탈진이 끼어든다.
    nonisolated(unsafe) static var staminaEnabled = true
    /// 확인용 실행이 재고·자리·신뢰·정산서를 끌 때. 켜 두면 판매가 재고에 막혀 다른 확인의 숫자가 달라진다.
    nonisolated(unsafe) static var stockEnabled = true
    /// 오르는 능력치를 고르는 주사위. 다른 추첨과 섞이지 않게 따로 둔다.
    var statRandom: () -> Double = { Double.random(in: 0..<1) }

    @discardableResult
    private func checkDeadline(now: Date) -> Bool {
        guard Self.deadlinesEnabled else { return false }
        let before = state.deadline
        let thisWeek = Self.weekStart(of: now)
        if let old = state.deadline, old.weekStart != thisWeek {
            if old.met != true, old.failed != true {
                state.deadline?.failed = true
                state.deadline?.resultNotified = false
                state.boosts.append(ActiveBoost(kind: .refusal, value: Balance.deadlinePenalty,
                                                endsAt: now.addingTimeInterval(TimeInterval(Balance.deadlinePenaltyHours) * 3600), source: "마감 펑크"))
                state.note = EventNote(text: Deadlines.failedLines[min(Deadlines.failedLines.count - 1, Int(random() * Double(Deadlines.failedLines.count)))],
                                       date: now, event: "deadline", kind: .deadline, notified: true)
                state.counters[Counter.deadlinesMissed.rawValue, default: 0] += 1
                state.weekly?.deadlineMet = false
            } else if old.met == true {
                state.weekly?.deadlineMet = true
            }
            // 매긴 결과는 알리고 나서 새 과제로 바꾼다. 알림 전이면 다음 반영 때.
            if state.deadline?.resultNotified == false { return state.deadline != before }
            state.deadline = nil
        }
        if state.deadline == nil, state.days.values.contains(where: { $0.characters > 0 }) {
            let progress = WritingProgress(state: state, now: now)
            let lastWeek = state.weekly.flatMap { $0.weekStart == thisWeek ? $0 : nil }
            let fallback = Int(progress.recentCharactersPerDay * 7)
            let remaining = progress.book.map { $0.characters - progress.charactersInBook } ?? 0
            state.deadline = Deadlines.assign(weekStart: thisWeek, lastWeekCharacters: lastWeek?.characters ?? fallback,
                                              lastWeekSales: lastWeek?.sales ?? 0, remainingInBook: remaining,
                                              finished: progress.finished.count, book: progress.book?.file, roll: random())
            state.deadline?.notified = false
        }
        guard let deadline = state.deadline, deadline.weekStart == thisWeek, deadline.met != true,
              deadlineProgress(deadline, now: now) >= deadline.target else { return state.deadline != before }
        state.deadline?.met = true
        state.deadline?.metAt = now
        state.deadline?.resultNotified = false
        for _ in 0..<Balance.deadlineItems { giveRandomItem() }
        state.boosts.append(ActiveBoost(kind: .sales, value: Balance.deadlineSalesBoost,
                                        endsAt: now.addingTimeInterval(TimeInterval(Balance.deadlineBoostHours) * 3600), source: "마감 사수"))
        state.note = EventNote(text: Deadlines.metLines[min(Deadlines.metLines.count - 1, Int(random() * Double(Deadlines.metLines.count)))],
                               date: now, event: "deadline", kind: .deadline, notified: true)
        state.counters[Counter.deadlinesMet.rawValue, default: 0] += 1
        return true
    }

    /// 알릴 마감: 새로 낸 과제이거나 결과(지킴·펑크)가 난 것.
    var unnotifiedDeadline: Deadline? {
        guard let d = state.deadline else { return nil }
        return d.notified == false || d.resultNotified == false ? d : nil
    }

    func markDeadlineNotified() {
        guard state.deadline != nil else { return }
        state.deadline?.notified = true
        if state.deadline?.resultNotified == false { state.deadline?.resultNotified = true }
        save()
    }

    /// 탈고한 책이 팔린다. 새 토큰 100만 개마다 책 한 권에 기본 `Balance.copiesPerMillion` 부.
    /// 탈고한 지 한 달 안은 신간이라 최대 3배, 손님 작가가 와 있으면 입소문으로 2배, 날마다 조금 흔들린다.
    private func sell(tokens: Int, now: Date) {
        let progress = WritingProgress(state: state, now: now)
        guard !progress.finished.isEmpty else { return }
        // 책마다 처음 탈고한 날.
        var firstFinish: [String: Date] = [:]
        for done in progress.finished {
            let file = Library.books[done.bookIndex].file
            if firstFinish[file] == nil { firstFinish[file] = done.date }
        }
        let millions = Double(tokens) / 1_000_000
        let guestBoost = state.luck?.id == Lucks.guest.id ? Balance.guestSalesMultiplier : 1
        let jitter = 0.8 + random() * 0.4
        let live = Boosts(state.boosts, now: now)
        var sold = 0.0
        let shelf = StudioPerks(owned: state.studio).sales
        for (file, date) in firstFinish {
            let days = max(0, now.timeIntervalSince(date) / 86_400)
            // 출판사에 따라 신간 기간과 신간 보정이 다르다. 안 골랐으면 대형으로 본다.
            let publisher = state.finishNotes.last { $0.book == file }?.publisher.flatMap(Publisher.init(rawValue:)) ?? .major
            let fresh = 1 + publisher.freshBoost * max(0, 1 - days / Double(publisher.freshDays))
            // 실린 비평이 있으면 별점대로 더 팔리거나 덜 팔린다.
            let reviewed = state.reviews.last { $0.book == file && $0.published == true }.map { Critics.salesMultiplier(for: $0.stars) } ?? 1
            // 서점: 자리에 따라 다르다(재고를 쓸 때). 아니면 이달의 책은 더, 나머지는 덜. 광고 중이거나 독자 주문대로 쓴 책은 더.
            let placed: Double
            if Self.stockEnabled {
                guard let slot = state.shop.slot(of: file, window: state.featuredBook) else { continue }
                placed = slot.sales
            } else {
                placed = state.featuredBook == nil ? 1 : (state.featuredBook == file ? Balance.featuredBoost : Balance.featuredOthers)
            }
            let featured = placed
            let advertised = (state.ads[file].map { $0 > now } ?? false) ? Balance.adBoost : 1
            let ordered = (state.orderBonus[file].map { $0 > now } ?? false) ? Balance.orderBoost : 1
            let shop = state.shopBoosts.filter { $0.endsAt > now && ($0.book == nil || $0.book == file) }.reduce(1.0) { $0 * $1.value }
            // 그 책 작가의 매력.
            let charm = StatPerks(Library.books.first { $0.file == file }.flatMap { state.sheets[$0.authorShort] }).sales
            var copies = millions * Balance.copiesPerMillion * fresh * guestBoost * jitter * live.sales * reviewed * Weather.of(now).sales * shelf
                * featured * advertised * ordered * shop * charm
            if Self.stockEnabled {
                // 창고에 없는 책은 못 판다. 빈손으로 간 손님은 놓친 것으로 센다.
                let have = state.shop.stock[file, default: 0]
                if copies > have {
                    state.shop.weekMissed[file, default: 0] += copies - have
                    copies = have
                }
                state.shop.stock[file] = have - copies
                if copies > 0 { state.shop.noteSold(file, copies: copies, now: now) }
                if have - copies <= 0.5, have > 0 { soldOut(file, now: now) }
            }
            let before = state.sales[file, default: 0]
            let after = before + copies
            state.sales[file] = after
            sold += copies
            let tier = SalesTier.of(copies: after)
            if tier > SalesTier.of(copies: before), tier != .none,
               !state.salesNews.contains(where: { $0.book == file && $0.tier == tier }) {
                state.salesNews.append(SalesNews(book: file, tier: tier, copies: Int(after), date: now))
            }
        }
        if state.salesNews.count > 20 { state.salesNews.removeFirst(state.salesNews.count - 20) }
        state.salesByDay[DayKey.string(from: Calendar.current.startOfDay(for: now)), default: 0] += sold
    }

    var unnotifiedSales: [SalesNews] { state.salesNews.filter { $0.notified != true } }

    func markSalesNotified(_ id: String) {
        guard let i = state.salesNews.firstIndex(where: { $0.id == id }) else { return }
        state.salesNews[i].notified = true
        save()
    }

    /// 새로 탈고한 작품마다 기록을 남긴다. 걸린 날수는 쓰기 시작한 날(앞 작품을 탈고한 날)부터다.
    private func noteFinishes(since before: Int, now: Date) {
        let progress = WritingProgress(state: state, now: now)
        guard progress.finished.count > before else { return }
        let calendar = Calendar.current
        for (i, done) in progress.finished.enumerated().dropFirst(before) {
            let book = Library.books[done.bookIndex]
            let start = i > 0 ? progress.finished[i - 1].date
                : (state.days.keys.sorted().first.flatMap(DayKey.date(from:)) ?? done.date)
            let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: done.date)).day ?? 0) + 1
            let logs = state.eventLog.filter { $0.book == book.file && $0.startedAt >= start && $0.startedAt <= done.date.addingTimeInterval(86_400) }
            var note = FinishNote(book: book.file, round: done.round, date: now, days: days,
                                  events: logs.filter { $0.lostCharacters == nil && !$0.event.hasPrefix("luck.") }.count,
                                  lost: logs.compactMap(\.lostCharacters).reduce(0, +))
            note.publisherDue = now.addingTimeInterval(TimeInterval(Balance.publisherHours) * 3600)
            if !state.finishNotes.contains(where: { $0.id == note.id }) {
                state.finishNotes.append(note)
                review(note, book: book, now: now)
                if Self.stockEnabled { receive(book.file, copies: Balance.sampleRun, now: now, reason: nil) }
            }
        }
        if state.finishNotes.count > 5 { state.finishNotes.removeFirst(state.finishNotes.count - 5) }
    }

    // MARK: 비평

    /// 탈고하면 비평가가 글을 쓴다. 몇 시간에서 이틀 뒤에 실린다(`publishReviews`).
    /// 탈고하면 비평가가 글을 쓰기 시작한다. 별점과 글은 실릴 때 정한다. 그때까지 출판사를 고를 수 있어서다.
    private func review(_ note: FinishNote, book: Book, now: Date) {
        let critic = Critics.all[min(Critics.all.count - 1, Int(random() * Double(Critics.all.count)))]
        let hours = Balance.reviewHours.lowerBound + random() * (Balance.reviewHours.upperBound - Balance.reviewHours.lowerBound)
        var review = Review(book: book.file, round: note.round, critic: critic.name, stars: 0, text: "",
                            date: now.addingTimeInterval(hours * 3600))
        review.days = note.days; review.events = note.events; review.lost = note.lost
        guard !state.reviews.contains(where: { $0.id == review.id }) else { return }
        state.reviews.append(review)
        if state.reviews.count > WritingState.maxReviews { state.reviews.removeFirst(state.reviews.count - WritingState.maxReviews) }
    }

    /// 실릴 때가 된 비평을 싣는다. 지금 쓰는 작가의 책이면 작가가 영향을 받는다(하루 동안의 보정과 한 줄).
    @discardableResult
    private func publishReviews(now: Date) -> Bool {
        var changed = false
        let current = WritingProgress(state: state, now: now).book?.authorShort
        for i in state.reviews.indices where state.reviews[i].published != true && state.reviews[i].date <= now {
            if state.reviews[i].text.isEmpty, let book = Library.books.first(where: { $0.file == state.reviews[i].book }) {
                // 실리는 순간 별점을 정한다. 문예 출판사면 조금 후하다.
                let r = state.reviews[i]
                let publisher = state.finishNotes.first { $0.id == r.id }?.publisher.flatMap(Publisher.init(rawValue:)) ?? .major
                let critic = Critics.all.first { $0.name == r.critic } ?? Critics.all[0]
                let stars = Critics.stars(days: r.days ?? 7, events: r.events ?? 0, lost: r.lost ?? 0, characters: book.characters,
                                          roll: random(), bonus: publisher.starsBonus + StatPerks(state.sheets[book.authorShort]).reviewBonus)
                state.reviews[i].stars = stars
                state.reviews[i].text = Critics.text(for: stars, days: r.days ?? 7, events: r.events ?? 0, lost: r.lost ?? 0, title: book.displayTitle,
                                                     author: book.displayAuthorShort, voice: critic.voice, rolls: (0..<12).map { _ in random() })
            }
            state.reviews[i].published = true
            changed = true
            guard let book = Library.books.first(where: { $0.file == state.reviews[i].book }), book.authorShort == current else { continue }
            let stars = state.reviews[i].stars
            state.reviews[i].affected = true
            state.boosts += Critics.boosts(for: stars, now: now)
            state.note = EventNote(text: Critics.authorLine(stars: stars, roll: random()), date: now, event: state.reviews[i].id, kind: .review, notified: true)
            if stars <= 2 { state.counters[Counter.panned.rawValue, default: 0] += 1 }
        }
        return changed
    }

    /// 확인용 실행에서 비평을 바로 싣는다.
    func publishReviewsForTesting(now: Date) {
        publishReviews(now: now)
        save(now: now)
    }

    var unnotifiedReviews: [Review] { state.reviews.filter { $0.published == true && $0.notified != true } }

    func markReviewNotified(_ id: String) {
        guard let i = state.reviews.firstIndex(where: { $0.id == id }) else { return }
        state.reviews[i].notified = true
        save()
    }

    // MARK: 출판사

    /// 탈고한 원고를 보낼 곳을 고른다. 대형이면 선금 아이템을 바로 준다.
    @discardableResult
    func choosePublisher(_ publisher: Publisher, for noteID: String, now: Date = Date()) -> WritingProgress {
        guard let i = state.finishNotes.firstIndex(where: { $0.id == noteID }), state.finishNotes[i].publisher == nil else {
            return WritingProgress(state: state, now: now)
        }
        state.finishNotes[i].publisher = publisher.rawValue
        for _ in 0..<publisher.advance { giveRandomItem() }
        state.counters[Counter.publishers.rawValue + "." + publisher.rawValue] = 1
        state.note = EventNote(text: publisher.line, date: now, event: noteID, kind: .publisher, notified: true)
        if Self.stockEnabled { receive(state.finishNotes[i].book, copies: publisher.firstRun, now: now, reason: nil) }
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 하루 안에 안 고른 원고는 대형 출판사로 간다.
    private func settleUnchosenPublishers(now: Date) -> Bool {
        var changed = false
        for i in state.finishNotes.indices where state.finishNotes[i].publisher == nil {
            // 옛 기록(기한 없음)은 대형으로 조용히.
            guard let due = state.finishNotes[i].publisherDue else { state.finishNotes[i].publisher = Publisher.major.rawValue; changed = true; continue }
            guard now >= due else { continue }
            state.finishNotes[i].publisher = Publisher.major.rawValue
            for _ in 0..<Publisher.major.advance { giveRandomItem() }
            state.counters[Counter.publishers.rawValue + "." + Publisher.major.rawValue] = 1
            state.note = EventNote(text: "답이 없어 원고가 대형 출판사로 갔습니다. 선금이 왔습니다", date: now, event: state.finishNotes[i].id, kind: .publisher, notified: true)
            if Self.stockEnabled { receive(state.finishNotes[i].book, copies: Publisher.major.firstRun, now: now, reason: nil) }
            changed = true
        }
        return changed
    }

    // MARK: 작업실

    /// 가구를 산다. 아이템이 모자라거나 이미 있으면 그대로다.
    @discardableResult
    func buy(_ furniture: Furniture, now: Date = Date()) -> WritingProgress {
        guard !state.studio.contains(furniture.id), Studio.canAfford(furniture, items: state.items) else { return WritingProgress(state: state, now: now) }
        for (kind, n) in furniture.cost { state.items[kind.rawValue, default: 0] -= n }
        state.studio.append(furniture.id)
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    // MARK: 내기

    /// 손님 작가가 내기를 건다. 손님이 없거나, 이번 손님 때 이미 걸었거나, 손님이 곧 가면 걸지 않는다.
    @discardableResult
    func offerBet(now: Date = Date()) -> Bool {
        guard let luck = state.luck, luck.id == Lucks.guest.id, let guest = luck.guest, luck.endsAt > now.addingTimeInterval(30 * 60) else { return false }
        if let bet = state.bet, bet.offeredAt >= luck.startedAt { return false }
        let progress = WritingProgress(state: state, now: now)
        let hours = luck.endsAt.timeIntervalSince(now) / 3600
        let target = Bets.target(charactersPerDay: max(progress.recentCharactersPerDay, 5_000), hours: hours)
        state.bet = ActiveBet(guest: guest, target: target, offeredAt: now, endsAt: luck.endsAt)
        state.note = EventNote(text: Bets.text(Bets.offers, guest: guest, target: target, roll: random()), date: now, event: "bet", kind: .bet, notified: false)
        save(now: now)
        return true
    }

    /// 내기를 받거나 사양한다.
    @discardableResult
    func answerBet(accept: Bool, now: Date = Date()) -> WritingProgress {
        guard var bet = state.bet, bet.pending else { return WritingProgress(state: state, now: now) }
        if accept {
            bet.accepted = true
            bet.startCharacters = WritingProgress(state: state, now: now).totalCharacters
            state.bet = bet
        } else {
            bet.accepted = false
            bet.won = nil
            bet.resolvedAt = now
            state.bet = bet
            state.note = EventNote(text: Bets.text(Bets.declined, guest: bet.guest, target: bet.target, roll: random()), date: now, event: "bet", kind: .bet, notified: true)
        }
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 받은 내기가 끝났으면 매긴다. 안 받은 채 손님이 갔으면 조용히 지운다.
    private func resolveBet(now: Date) -> Bool {
        guard var bet = state.bet else { return false }
        if bet.pending, now >= bet.endsAt {
            bet.accepted = false; bet.resolvedAt = now; state.bet = bet
            return true
        }
        guard bet.running, let start = bet.startCharacters else { return false }
        let written = WritingProgress(state: state, now: now).totalCharacters - start
        guard written >= Double(bet.target) || now >= bet.endsAt else { return false }
        let won = written >= Double(bet.target)
        bet.won = won
        bet.resolvedAt = now
        state.bet = bet
        if won {
            for _ in 0..<Balance.betWinItems { giveRandomItem() }
            state.boosts.append(ActiveBoost(kind: .sales, value: Balance.betSalesBoost, endsAt: now.addingTimeInterval(TimeInterval(Balance.betBoostHours) * 3600), source: "내기"))
            state.counters[Counter.betsWon.rawValue, default: 0] += 1
        } else {
            for _ in 0..<Balance.betLoseItems {
                let held = ItemKind.allCases.filter { state.items[$0.rawValue, default: 0] > 0 }
                guard !held.isEmpty else { break }
                state.items[held[min(held.count - 1, Int(random() * Double(held.count)))].rawValue, default: 0] -= 1
            }
            state.counters[Counter.betsLost.rawValue, default: 0] += 1
        }
        state.note = EventNote(text: Bets.text(won ? Bets.won : Bets.lost, guest: bet.guest, target: bet.target, roll: random()), date: now, event: "bet", kind: .bet, notified: false)
        return true
    }

    // MARK: 서점

    /// 이달의 책을 고른다. 하루에 한 번. 같은 책을 다시 고르면 내린다.
    @discardableResult
    func feature(_ file: String?, now: Date = Date()) -> WritingProgress {
        if Self.stockEnabled {
            if let file { return place(file, .window, now: now) }
            if let current = state.featuredBook { return place(current, .shelf, now: now) }
            return WritingProgress(state: state, now: now)
        }
        if let at = state.featuredAt, state.featuredBook != nil, now.timeIntervalSince(at) < TimeInterval(Balance.featuredHours) * 3600 {
            return WritingProgress(state: state, now: now)
        }
        state.featuredBook = file
        state.featuredAt = file == nil ? nil : now
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    // MARK: 서점 운영

    /// 책을 자리에 둔다. 진열창은 신뢰가 있어야 하고 하루에 한 번만 바꾼다. 매대가 차 있으면 주인이 고른 책 가운데 가장 덜 팔리는 것을 내린다.
    /// 서가로 보내면 이레 동안 주인이 다시 올리지 않는다. 직접 고른 자리는 이레 동안 그대로다.
    @discardableResult
    func place(_ file: String, _ slot: ShopSlot, now: Date = Date()) -> WritingProgress {
        guard state.shop.stock(of: file) > 0 || slot == .shelf else { return WritingProgress(state: state, now: now) }
        switch slot {
        case .window:
            guard state.shop.level.hasWindow, state.featuredBook != file,
                  state.featuredAt.map({ now.timeIntervalSince($0) >= TimeInterval(Balance.featuredHours) * 3600 }) ?? true
            else { return WritingProgress(state: state, now: now) }
            if let old = state.featuredBook { state.shop.pinned[old] = nil }
            state.featuredBook = file
            state.featuredAt = now
            state.shop.counter.removeAll { $0 == file }
            state.shop.pinned[file] = now
            state.shop.benched[file] = nil
            state.shop.placedAt[file] = now
        case .counter:
            if !state.shop.counter.contains(file) {
                if state.shop.counter.count >= state.shop.level.counterSlots {
                    let loose = state.shop.counter.filter { state.shop.pinned[$0] == nil }
                    guard let drop = loose.min(by: { Shopkeeper.score($0, state: state, now: now) < Shopkeeper.score($1, state: state, now: now) })
                    else { return WritingProgress(state: state, now: now) }
                    state.shop.counter.removeAll { $0 == drop }
                    state.shop.placedAt[drop] = nil
                }
                if state.featuredBook == file { state.featuredBook = nil; state.featuredAt = nil }
                state.shop.counter.append(file)
                state.shop.placedAt[file] = now
            }
            state.shop.pinned[file] = now
            state.shop.benched[file] = nil
        case .shelf:
            if state.featuredBook == file { state.featuredBook = nil; state.featuredAt = nil }
            state.shop.counter.removeAll { $0 == file }
            state.shop.pinned[file] = nil
            state.shop.placedAt[file] = nil
            state.shop.benched[file] = now
        case .storage: break
        }
        _ = arrange(now: now, morning: false)
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 직접 정한 것을 거두고 주인에게 맡긴다.
    @discardableResult
    func leaveToKeeper(_ file: String, now: Date = Date()) -> WritingProgress {
        state.shop.pinned[file] = nil
        state.shop.benched[file] = nil
        _ = arrange(now: now, morning: false)
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 확인용 실행에서 재고를 바로 정한다.
    func setStockForTesting(_ file: String, copies: Int) { state.shop.stock[file] = Double(copies) }

    func dismissStatement(_ id: String) {
        guard let i = state.shop.statements.firstIndex(where: { $0.id == id }) else { return }
        state.shop.statements[i].dismissed = true
        save()
    }

    var unnotifiedStatement: Statement? { state.shop.statements.last.flatMap { $0.notified != true ? $0 : nil } }

    func markStatementNotified(_ id: String) {
        guard let i = state.shop.statements.firstIndex(where: { $0.id == id }) else { return }
        state.shop.statements[i].notified = true
        save()
    }

    var unnotifiedStockNews: [StockNews] { state.shop.stockNews.filter { $0.notified != true } }

    func markStockNotified(_ id: String) {
        guard let i = state.shop.stockNews.firstIndex(where: { $0.id == id }) else { return }
        state.shop.stockNews[i].notified = true
        save()
    }

    /// 재고가 들어온다. 탈고 직후 견본, 출판사를 고른 뒤 초판, 재판. `reason` 이 있으면 한 줄 남긴다.
    private func receive(_ file: String, copies: Int, now: Date, reason: String?) {
        state.shop.stock[file, default: 0] += Double(copies)
        state.shop.reprints[file] = nil
        if let reason, let book = Library.books.first(where: { $0.file == file }) {
            state.shop.stockNews.append(StockNews(book: file, kind: .restocked, copies: copies, due: nil, date: now))
            state.note = EventNote(text: "\(book.displayTitle) \(reason) \(Format.integer(copies))부가 들어왔습니다", date: now, event: "restock", kind: .shop, notified: true)
            state.counters[Counter.reprints.rawValue, default: 0] += 1
        }
        if state.shop.stockNews.count > 20 { state.shop.stockNews.removeFirst(state.shop.stockNews.count - 20) }
        _ = arrange(now: now, morning: false)
    }

    /// 재고가 떨어졌다. 출판사에 재판을 청하고(지난 7일 판매의 1.5배, 초판의 0.5~4배 사이), 매대에 있던 책이면 신뢰가 깎인다.
    private func soldOut(_ file: String, now: Date) {
        guard state.shop.reprints[file] == nil, let book = Library.books.first(where: { $0.file == file }) else { return }
        let publisher = state.finishNotes.last { $0.book == file }?.publisher.flatMap(Publisher.init(rawValue:)) ?? .major
        let weekly = state.shop.sold(file, days: 7, now: now)
        let copies = Int(min(max(weekly * Balance.reprintWeeks, Double(publisher.firstRun) * Balance.reprintMinRatio), Double(publisher.firstRun) * Balance.reprintMaxRatio))
        let hours = publisher.reprintHours * state.shop.level.reprintSpeed
        let due = now.addingTimeInterval(hours * 3600)
        state.shop.reprints[file] = ShopState.Reprint(due: due, copies: copies, orderedAt: now)
        state.shop.stock[file] = 0
        if state.featuredBook == file || state.shop.counter.contains(file) {
            state.shop.adjustTrust(Balance.trustSoldOut, reason: "\(book.displayTitle) 품절로 손님을 돌려보냄", now: now)
        }
        state.shop.stockNews.append(StockNews(book: file, kind: .soldOut, copies: copies, due: due, date: now))
        if state.shop.stockNews.count > 20 { state.shop.stockNews.removeFirst(state.shop.stockNews.count - 20) }
        state.note = EventNote(text: "\(book.displayTitle)(이|가) 품절됐습니다. 재판 \(Format.integer(copies))부가 \(Int(hours.rounded()))시간 뒤에 들어옵니다".resolvedParticles,
                               date: now, event: "soldout", kind: .shop, notified: true)
        state.counters[Counter.soldOuts.rawValue, default: 0] += 1
        _ = arrange(now: now, morning: false)
    }

    /// 매번 반영할 때 서점을 돌본다. 옛 기록엔 재고를 채우고, 들어온 재판을 받고, 아침이면 주인이 자리를 정리한다.
    private func tendShop(now: Date) -> Bool {
        var changed = false
        let finished = Set(WritingProgress(state: state, now: now).finished.map { Library.books[$0.bookIndex].file })
        if !state.shop.migrated {
            for file in finished where state.shop.stock[file] == nil {
                let publisher = state.finishNotes.last { $0.book == file }?.publisher.flatMap(Publisher.init(rawValue:)) ?? .major
                state.shop.stock[file] = Double(publisher.firstRun)
            }
            state.shop.migrated = true
            changed = true
        }
        if state.shop.weekTrustStart == nil, !finished.isEmpty { state.shop.weekTrustStart = state.shop.trust; changed = true }
        if state.shop.trackedSince == nil, !finished.isEmpty { state.shop.trackedSince = now; changed = true }
        for (file, reprint) in state.shop.reprints where reprint.due <= now {
            receive(file, copies: reprint.copies, now: now, reason: "재판")
            changed = true
        }
        let calendar = Calendar.current
        let morning = state.shop.arrangedAt.map { !calendar.isDate($0, inSameDayAs: now) && calendar.component(.hour, from: now) >= Balance.arrangeHour } ?? true
        if !finished.isEmpty, arrange(now: now, morning: morning) { changed = true }
        return changed
    }

    /// 주인이 자리를 정한다. `morning` 이면 직접 고른 책만 두고 다시 고르고, 아니면 빈 자리만 채운다. 바뀐 게 있으면 true.
    @discardableResult
    private func arrange(now: Date, morning: Bool) -> Bool {
        guard Self.stockEnabled else { return false }
        var shop = state.shop
        let level = shop.level
        let pinLife = TimeInterval(Balance.pinDays) * 86_400
        shop.pinned = shop.pinned.filter { now.timeIntervalSince($0.value) < pinLife }
        shop.benched = shop.benched.filter { now.timeIntervalSince($0.value) < pinLife }
        let finished = Set(WritingProgress(state: state, now: now).finished.map { Library.books[$0.bookIndex].file })
        let inStock = finished.filter { shop.stock(of: $0) > 0 }
        var window = state.featuredBook
        if let w = window, !inStock.contains(w) || !level.hasWindow { window = nil; shop.pinned[w] = nil }
        shop.counter = shop.counter.filter { inStock.contains($0) && $0 != window }
        if morning, let w = window, shop.pinned[w] == nil { window = nil }
        if morning { shop.counter = shop.counter.filter { shop.pinned[$0] != nil } }
        var scores: [String: Double] = [:]
        for file in inStock { scores[file] = Shopkeeper.score(file, state: state, now: now) }
        func ranked(_ pool: Set<String>) -> [String] {
            pool.sorted { (scores[$0] ?? 0, $1) > (scores[$1] ?? 0, $0) }
        }
        var pool = ranked(inStock.filter { $0 != window && !shop.counter.contains($0) && shop.benched[$0] == nil })
        if window == nil, level.hasWindow, let best = pool.first {
            window = best
            pool.removeFirst()
            if state.featuredBook != best { state.featuredAt = nil }
        }
        while shop.counter.count > level.counterSlots,
              let drop = shop.counter.filter({ shop.pinned[$0] == nil }).min(by: { (scores[$0] ?? 0) < (scores[$1] ?? 0) }) {
            shop.counter.removeAll { $0 == drop }
        }
        while shop.counter.count < level.counterSlots, !pool.isEmpty {
            shop.counter.append(pool.removeFirst())
        }
        let placed = Set(shop.counter + [window].compactMap { $0 })
        for file in placed where shop.placedAt[file] == nil { shop.placedAt[file] = now }
        shop.placedAt = shop.placedAt.filter { placed.contains($0.key) }
        if morning { shop.arrangedAt = now }
        let changed = window != state.featuredBook || shop.counter != state.shop.counter
        state.featuredBook = window
        if window == nil { state.featuredAt = nil }
        let before = state.shop
        state.shop = shop
        if morning, changed, !shop.counter.isEmpty {
            let names = ([window].compactMap { $0 } + shop.counter).compactMap { f in Library.books.first { $0.file == f }?.displayTitle }
            state.note = EventNote(text: "주인이 아침에 매대를 다시 꾸렸습니다. " + names.joined(separator: " · "), date: now, event: "arrange", kind: .shop, notified: true)
        }
        return changed || before != shop
    }

    /// 월요일 정산서. 지난주 책별 판매·반품·놓친 손님·남은 재고와 신뢰 변화, 주인의 한마디. 주간 합은 비운다.
    private func settleWeek(now: Date) -> Bool {
        let thisWeek = Self.weekStart(of: now)
        guard let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: thisWeek),
              state.shop.statements.last.map({ $0.weekStart < lastWeek }) ?? true,
              let startTrust = state.shop.weekTrustStart,
              (state.shop.trackedSince ?? now) < thisWeek else { return false }
        let progress = WritingProgress(state: state, now: now)
        let finished = Array(Set(progress.finished.map { Library.books[$0.bookIndex].file }))
        guard !finished.isEmpty else { return false }
        let sold = Int(state.shop.weekSold.values.reduce(0, +))
        let missed = Int(state.shop.weekMissed.values.reduce(0, +))
        let returned = Int(state.shop.weekReturned.values.reduce(0, +))
        if sold + missed == 0 {
            state.shop.adjustTrust(Balance.trustWeekQuiet, reason: "한 주 내내 손님이 없음", now: now)
        } else if Double(missed) / Double(sold + missed) > 0.3 {
            state.shop.adjustTrust(Balance.trustWeekBad, reason: "품절로 돌려보낸 손님이 많음", now: now)
        } else if Double(missed) / Double(sold + missed) < 0.05, sold > 0 {
            state.shop.adjustTrust(Balance.trustWeekGood, reason: "한 주 내내 손님이 끊이지 않음", now: now)
        }
        let lines = finished.map { file in
            StatementLine(book: file, sold: Int(state.shop.weekSold[file] ?? 0), returned: Int(state.shop.weekReturned[file] ?? 0),
                          missed: Int(state.shop.weekMissed[file] ?? 0), stock: state.shop.stock(of: file),
                          slot: state.shop.slot(of: file, window: state.featuredBook) ?? .storage)
        }.sorted { ($0.sold, $0.book) > ($1.sold, $1.book) }
        let reasons = state.shop.trustLog.filter { $0.date >= lastWeek }.sorted { abs($0.delta) > abs($1.delta) }.prefix(3)
            .map { "\($0.reason) (\($0.delta > 0 ? "+" : "")\(Int($0.delta.rounded())))" }
        let delta = state.shop.trust - startTrust
        state.shop.statements.append(Statement(weekStart: lastWeek, lines: lines, sold: sold, returned: returned, missed: missed,
                                               trustBefore: startTrust, trustAfter: state.shop.trust, reasons: Array(reasons),
                                               keeperLine: Shopkeeper.line(sold: sold, missed: missed, returned: returned, trustDelta: delta)))
        if state.shop.statements.count > 8 { state.shop.statements.removeFirst(state.shop.statements.count - 8) }
        state.shop.weekSold = [:]
        state.shop.weekMissed = [:]
        state.shop.weekReturned = [:]
        state.shop.weekTrustStart = state.shop.trust
        state.counters[Counter.statements.rawValue, default: 0] += 1
        return true
    }

    /// 광고를 건다. 아이템이 모자라거나 이미 광고 중이면 그대로다.
    @discardableResult
    func advertise(_ file: String, now: Date = Date()) -> WritingProgress {
        guard Balance.adCost.allSatisfy({ state.items[$0.0.rawValue, default: 0] >= $0.1 }),
              (state.ads[file].map { $0 <= now } ?? true),
              !Self.stockEnabled || state.shop.stock(of: file) > 0 else { return WritingProgress(state: state, now: now) }
        for (kind, n) in Balance.adCost { state.items[kind.rawValue, default: 0] -= n }
        state.ads[file] = now.addingTimeInterval(TimeInterval(Balance.adHours) * 3600)
        state.counters[Counter.ads.rawValue, default: 0] += 1
        if Self.stockEnabled {
            state.shop.adjustTrust(Balance.trustAd, reason: "광고로 손님을 불러옴", now: now)
            _ = arrange(now: now, morning: false)
        }
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 서점 사건을 하나 일으킨다. 탈고한 책이 없으면 아무 일도 없다. 확인용 실행에서 직접 부르기도 한다.
    @discardableResult
    func happenInShop(_ forced: ShopEvent? = nil, now: Date = Date()) -> ShopRecord? {
        let progress = WritingProgress(state: state, now: now)
        let done = Array(Set(progress.finished.map(\.bookIndex))).sorted()
        guard !done.isEmpty else { return nil }
        let praised = done.filter { (progress.review(of: Library.books[$0])?.stars ?? 0) >= 4 }
        let event = forced ?? ShopEvents.pick(roll: random(), context: .now(now, hasPraised: !praised.isEmpty, books: done.count))
        var candidates = event.praisedOnly ? praised : done
        // 재고를 쓸 때는 창고가 빈 책에 손님이 몰려도 소용없다. 재고 있는 책 가운데 고른다.
        if Self.stockEnabled {
            let stocked = candidates.filter { state.shop.stock(of: Library.books[$0].file) > 0 }
            if !stocked.isEmpty { candidates = stocked }
        }
        let book = event.scope == .book ? Library.books[candidates[min(candidates.count - 1, Int(random() * Double(candidates.count)))]] : nil
        var copies: Int?
        switch event.effect {
        case .sales(let value, let hours):
            state.shopBoosts.append(ShopBoost(book: book?.file, value: value, endsAt: now.addingTimeInterval(Double(hours) * 3600), source: event.title))
            // 인쇄소가 밀리면 재판도 늦는다.
            if Self.stockEnabled, event.id == "misprint", let book, let reprint = state.shop.reprints[book.file] {
                state.shop.reprints[book.file] = ShopState.Reprint(due: reprint.due.addingTimeInterval(Double(hours) * 3600), copies: reprint.copies, orderedAt: reprint.orderedAt)
            }
        case .copies(let low, let high):
            var n = low + Int(random() * Double(high - low))
            if let book {
                if Self.stockEnabled {
                    n = min(n, state.shop.stock(of: book.file))
                    state.shop.stock[book.file, default: 0] -= Double(n)
                    state.shop.noteSold(book.file, copies: Double(n), now: now)
                    if state.shop.stock(of: book.file) <= 0 { soldOut(book.file, now: now) }
                }
                state.sales[book.file, default: 0] += Double(n)
                state.salesByDay[DayKey.string(from: Calendar.current.startOfDay(for: now)), default: 0] += Double(n)
            }
            copies = n
        case .restock(let low, let high):
            let n = low + Int(random() * Double(high - low))
            copies = n
            if let book, Self.stockEnabled {
                state.shop.stock[book.file, default: 0] += Double(n)
                _ = arrange(now: now, morning: false)
            } else if let book {
                state.sales[book.file, default: 0] += Double(n)
            }
        case .returned(let low, let high):
            let n = low + Int(random() * Double(high - low))
            if let book {
                let lost = min(n, Int(state.sales[book.file, default: 0]))
                copies = -lost
                state.sales[book.file, default: 0] -= Double(lost)
                let key = DayKey.string(from: Calendar.current.startOfDay(for: now))
                state.salesByDay[key] = max(0, state.salesByDay[key, default: 0] - Double(lost))
                if Self.stockEnabled {
                    // 반품은 창고로 돌아온다. 젖은 책과 쥐가 갉은 책은 못 쓴다.
                    if event.id == "returns" { state.shop.stock[book.file, default: 0] += Double(lost) }
                    state.shop.weekReturned[book.file, default: 0] += Double(lost)
                    state.shop.adjustTrust(Balance.trustReturns, reason: "\(book.displayTitle) \(lost)부 반품", now: now)
                }
            }
        case .inspiration(let fraction):
            let before = state.inspiration
            state.inspiration = min(Balance.inspirationGaugeTokens, state.inspiration + Int(Double(Balance.inspirationGaugeTokens) * fraction))
            if before < Balance.inspirationGaugeTokens, state.inspiration >= Balance.inspirationGaugeTokens { state.inspirationNotified = false }
        case .feature:
            let busy = state.featuredAt.map { state.featuredBook != nil && now.timeIntervalSince($0) < TimeInterval(Balance.featuredHours) * 3600 } ?? false
            let pinned = Self.stockEnabled && state.featuredBook.map { state.shop.pinned[$0] != nil } == true
            let allowed = !Self.stockEnabled || (state.shop.level.hasWindow && !pinned)
            if let book, !busy, allowed {
                if Self.stockEnabled {
                    if let old = state.featuredBook { state.shop.pinned[old] = nil }
                    state.shop.counter.removeAll { $0 == book.file }
                    state.shop.placedAt[book.file] = now
                }
                state.featuredBook = book.file
                state.featuredAt = Self.stockEnabled ? nil : now
                if Self.stockEnabled { _ = arrange(now: now, morning: false) }
            } else {
                state.shopBoosts.append(ShopBoost(book: book?.file, value: 1.2, endsAt: now.addingTimeInterval(6 * 3600), source: event.title))
            }
        case .order:
            _ = offerOrder(now: now)
        case .items(let n) where n > 0:
            for _ in 0..<n { giveRandomItem() }
        case .items(let n):
            for _ in 0..<(-n) {
                let held = ItemKind.allCases.filter { state.items[$0.rawValue, default: 0] > 0 }
                guard !held.isEmpty else { break }
                state.items[held[min(held.count - 1, Int(random() * Double(held.count)))].rawValue, default: 0] -= 1
            }
        case .none: break
        }
        var text = L10n.tr(event.texts[min(event.texts.count - 1, Int(random() * Double(event.texts.count)))])
        text = text.replacingOccurrences(of: "{T}", with: book?.displayTitle ?? "").replacingOccurrences(of: "{A}", with: book?.displayAuthorShort ?? "")
            .replacingOccurrences(of: "{N}", with: Format.integer(abs(copies ?? 0)))
        text = Format.resolve(text)
        if Self.stockEnabled, ["reading", "signing", "tea", "club", "portrait"].contains(event.id) {
            state.shop.adjustTrust(Balance.trustGathering, reason: "\(event.title)(이|가) 잘 끝남".resolvedParticles, now: now)
        }
        let record = ShopRecord(event: event.id, book: book?.file, text: text, date: now, copies: copies)
        state.shopLog.append(record)
        if state.shopLog.count > 20 { state.shopLog.removeFirst(state.shopLog.count - 20) }
        state.note = EventNote(text: text, date: now, event: event.id, kind: .shop, notified: true)
        state.counters[Counter.shopEvents.rawValue, default: 0] += 1
        save(now: now)
        return record
    }

    /// 독자가 아직 안 쓴 책 하나를 청한다. 지금 쓰는 책과 바로 다음 책은 빼고, 되도록 다른 작가의 책을.
    @discardableResult
    func offerOrder(now: Date = Date()) -> Bool {
        guard state.order == nil else { return false }
        let progress = WritingProgress(state: state, now: now)
        let pending = Array(progress.pendingInRound.dropFirst())
        guard !pending.isEmpty else { return false }
        let others = pending.filter { Library.books[$0].authorShort != progress.book?.authorShort }
        let pool = others.isEmpty ? pending : others
        let index = pool[min(pool.count - 1, Int(random() * Double(pool.count)))]
        let book = Library.books[index]
        let text = ReaderOrders.text(ReaderOrders.lines, book: book, roll: random())
        state.order = ReaderOrder(book: book.file, offeredAt: now, expiresAt: now.addingTimeInterval(TimeInterval(Balance.orderDays) * 86_400), text: text)
        state.note = EventNote(text: text, date: now, event: "order", kind: .order, notified: false)
        save(now: now)
        return true
    }

    /// 주문한 책을 쓰기 시작했으면 채운 것으로, 기한이 지났으면 지운다.
    private func checkOrder(now: Date) -> Bool {
        guard let order = state.order, order.fulfilled == nil else {
            if let order = state.order, order.fulfilled == true, now.timeIntervalSince(order.offeredAt) > 86_400 * 8 { state.order = nil; return true }
            return false
        }
        if now >= order.expiresAt {
            state.order = nil
            if Self.stockEnabled { state.shop.adjustTrust(Balance.trustOrderMissed, reason: "독자 주문을 기한 안에 못 씀", now: now) }
            return true
        }
        let progress = WritingProgress(state: state, now: now)
        guard progress.book?.file == order.book, let book = progress.book else { return false }
        state.order?.fulfilled = true
        if Self.stockEnabled { state.shop.adjustTrust(Balance.trustOrderKept, reason: "독자 주문대로 \(book.displayTitle)을 씀", now: now) }
        state.orderBonus[order.book] = now.addingTimeInterval(TimeInterval(Balance.freshDays) * 86_400)
        state.counters[Counter.ordersFilled.rawValue, default: 0] += 1
        state.note = EventNote(text: ReaderOrders.text(ReaderOrders.filled, book: book, roll: random()), date: now, event: "order", kind: .order, notified: true)
        return true
    }

    // MARK: 선택지가 있는 사건

    /// 사건을 낸다. 확인용 실행에서 직접 부르기도 한다.
    func offer(_ dilemma: Dilemma, now: Date = Date()) {
        guard state.dilemma == nil else { return }
        let text = dilemma.texts[min(dilemma.texts.count - 1, Int(random() * Double(dilemma.texts.count)))]
        state.dilemma = ActiveDilemma(id: dilemma.id, text: text, startedAt: now,
                                      expiresAt: now.addingTimeInterval(Double(dilemma.minutes) * 60))
        save(now: now)
    }

    /// 사건에 답한다. 효과(보정·아이템)를 붙이고 결과 한 줄을 남긴다. `auto` 는 시간이 지나 작가가 알아서 고른 것.
    @discardableResult
    func choose(_ index: Int, now: Date = Date(), auto: Bool = false) -> WritingProgress {
        guard let pending = state.dilemma, let dilemma = Dilemmas.byID(pending.id), dilemma.options.indices.contains(index) else {
            return WritingProgress(state: state)
        }
        let option = dilemma.options[index]
        state.dilemma = nil
        for (kind, value, seconds) in option.boosts {
            state.boosts.append(ActiveBoost(kind: kind, value: value, endsAt: now.addingTimeInterval(seconds), source: dilemma.title))
        }
        if option.items > 0 {
            for _ in 0..<option.items { giveRandomItem() }
        } else if option.items < 0 {
            for _ in 0..<(-option.items) {
                let held = ItemKind.allCases.filter { state.items[$0.rawValue, default: 0] > 0 }
                guard !held.isEmpty else { break }
                state.items[held[min(held.count - 1, Int(random() * Double(held.count)))].rawValue, default: 0] -= 1
            }
        }
        let outcome = option.outcomes[min(option.outcomes.count - 1, Int(random() * Double(option.outcomes.count)))]
        state.dilemmaLog.append(DilemmaRecord(dilemma: dilemma.id, option: option.label, outcome: outcome, date: now, auto: auto ? true : nil))
        if state.dilemmaLog.count > 30 { state.dilemmaLog.removeFirst(state.dilemmaLog.count - 30) }
        // 작가가 알아서 고른 것은 알린다. 직접 고른 것은 화면에서 봤으니 알리지 않는다.
        state.note = EventNote(text: outcome, date: now, event: dilemma.id, kind: .dilemma, notified: !auto)
        if !auto { state.counters[Counter.decisions.rawValue, default: 0] += 1 }
        save(now: now)
        return WritingProgress(state: state)
    }

    /// 알리지 않은 사건.
    var unnotifiedDilemma: ActiveDilemma? { state.dilemma.flatMap { $0.notified == true ? nil : $0 } }

    func markDilemmaNotified() {
        guard state.dilemma != nil else { return }
        state.dilemma?.notified = true
        save()
    }

    /// 월요일 기준 이번 주 시작.
    static func weekStart(of date: Date) -> Date {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)  // 일 1 … 토 7
        return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day) ?? day
    }

    /// 새 주가 되면 지난주를 정리한다. 지난주에 쓴 기록이 없으면 넘어간다.
    private func noteWeek(now: Date) {
        let thisWeek = Self.weekStart(of: now)
        guard state.weekly?.weekStart != thisWeek else { return }
        let calendar = Calendar.current
        guard let lastWeek = calendar.date(byAdding: .day, value: -7, to: thisWeek) else { return }
        let days = state.days.compactMap { key, record -> (Date, WritingRecord)? in
            guard let date = DayKey.date(from: key), date >= lastWeek, date < thisWeek else { return nil }
            return (date, record)
        }
        guard !days.isEmpty, days.contains(where: { $0.1.characters > 0 }) else { return }
        let progress = WritingProgress(state: state, now: now)
        let best = days.max { $0.1.characters < $1.1.characters }
        let soldLastWeek = state.salesByDay.reduce(0.0) { sum, pair in
            guard let date = DayKey.date(from: pair.key), date >= lastWeek, date < thisWeek else { return sum }
            return sum + pair.value
        }
        state.weekly = WeeklyReview(
            weekStart: thisWeek,
            characters: Int(days.reduce(0) { $0 + $1.1.net }),
            finished: progress.finished.filter { $0.date >= lastWeek && $0.date < thisWeek }.count,
            events: state.eventLog.filter { $0.lostCharacters == nil && !$0.event.hasPrefix("luck.") && $0.startedAt >= lastWeek && $0.startedAt < thisWeek }.count,
            disasters: state.eventLog.filter { $0.lostCharacters != nil && $0.startedAt >= lastWeek && $0.startedAt < thisWeek }.count,
            bestDay: best?.0, bestDayCharacters: Int(best?.1.characters ?? 0), sales: Int(soldLastWeek))
    }

    /// 이 작품을 지금 쓰는 책 바로 다음에 쓴다. 이미 쓴 것, 지금 쓰는 것은 못 옮긴다.
    func writeNext(_ bookIndex: Int) {
        let progress = WritingProgress(state: state)
        var order = progress.roundOrder
        guard let from = order.firstIndex(of: bookIndex), from > progress.orderPosition else { return }
        order.remove(at: from)
        order.insert(bookIndex, at: progress.orderPosition + 1)
        setOrder(order, round: progress.round)
    }

    /// 이 작가의 남은 작품을 지금 책 다음에 몰아 쓴다.
    func focus(author: String) {
        let progress = WritingProgress(state: state)
        var order = progress.roundOrder
        let picked = progress.pendingInRound.filter { Library.books[$0].authorShort == author }
        guard !picked.isEmpty else { return }
        order.removeAll { picked.contains($0) }
        order.insert(contentsOf: picked, at: progress.orderPosition + 1)
        state.counters[Counter.focuses.rawValue, default: 0] += 1
        setOrder(order, round: progress.round)
    }

    private func setOrder(_ order: [Int], round: Int) {
        while state.orders.count <= round { state.orders.append(Array(0..<Library.books.count)) }
        state.orders[round] = order
        save()
    }

    func dismissFinish(_ id: String) {
        guard let i = state.finishNotes.firstIndex(where: { $0.id == id }) else { return }
        state.finishNotes[i].dismissed = true
        save()
    }

    func dismissWeekly() {
        state.weekly?.dismissed = true
        save()
    }

    var unnotifiedFinishes: [FinishNote] { state.finishNotes.filter { $0.notified != true } }

    func markFinishNotified(_ id: String) {
        guard let i = state.finishNotes.firstIndex(where: { $0.id == id }) else { return }
        state.finishNotes[i].notified = true
        save()
    }

    func markWeeklyNotified() {
        state.weekly?.notified = true
        save()
    }

    /// 새 토큰 100만 개마다 한 번씩 추첨한다. 자연재해는 늘 추첨하고, 돌발 상황은 이미 있으면 추첨하지 않는다.
    private func rollEvent(newTokens: Int, now: Date, author: String?) {
        state.tokensTowardEventRoll += newTokens
        let live = Boosts(state.boosts, now: now)
        let weather = Weather.of(now)
        while state.tokensTowardEventRoll >= 1_000_000 {
            state.tokensTowardEventRoll -= 1_000_000
            let studio = StudioPerks(owned: state.studio)
            if random() < disasterChance * weather.disaster * (weather == .storm ? studio.stormDisaster : 1) { strike(Disasters.pick(roll: random()), now: now) }
            if state.luck == nil, random() < luckChance * sheetPerks(now: now).luckChance {
                var luck = Lucks.pick(roll: random())
                // 눈 오는 날은 손님이 못 온다. 대신 선금.
                if weather.blocksGuest, luck.id == Lucks.guest.id { luck = Lucks.advance }
                grant(luck, now: now, author: author)
            }
            if Self.shopEnabled, state.order == nil, random() < Balance.orderChancePerMillion { offerOrder(now: now) }
            if Self.shopEnabled, random() < Balance.shopEventChancePerMillion { happenInShop(now: now) }
            if state.dilemma == nil, now.timeIntervalSince(state.dilemmaLog.last?.date ?? .distantPast) >= Balance.dilemmaCooldown,
               random() < dilemmaChance {
                var dilemma = Dilemmas.pick(roll: random())
                // 고양이를 들였으면 창틀의 고양이는 오지 않는다.
                if studio.blocksCat, dilemma.id == "cat", let other = Dilemmas.all.first(where: { $0.id != "cat" }) { dilemma = other }
                offer(dilemma, now: now)
            }
            // 손님 작가가 있는 동안은 돌발 상황이 없다.
            let month = Calendar.current.component(.month, from: now)
            let winter = month == 12 || month <= 2
            guard state.event == nil, state.luck?.id != Lucks.guest.id,
                  random() < eventChance * perks.eventChance * live.eventChance * weather.event * studio.event * (winter ? studio.winterEvent : 1) else { continue }
            var event = AuthorEvents.pick(author: author ?? "", hour: Calendar.current.component(.hour, from: now), roll: random())
            // 카페인: 오늘 커피·홍차를 많이 권했으면 졸음 대신 글이 막히고, 어제 그랬으면 오늘은 졸음이 더 온다.
            let today = state.cups(on: now), yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now).map { state.cups(on: $0) } ?? 0
            if today >= Balance.caffeineCups, event.id == AuthorEvents.nap.id { event = AuthorEvents.block }
            else if yesterday >= Balance.caffeineCups, today < Balance.caffeineCups, event.id != AuthorEvents.nap.id, random() < Balance.hangoverNapChance { event = AuthorEvents.nap }
            start(event, now: now, author: author)
        }
    }

    /// 행운을 준다. 선금은 그 자리에서 아이템을, 나머지는 시간이 있는 상태로 남는다. 확인용 실행에서 직접 부르기도 한다.
    func grant(_ luck: LuckEvent, now: Date = Date(), author: String? = nil, invited: String? = nil) {
        var items: String?
        var guest: String?
        if luck.id == Lucks.advance.id {
            var counts: [ItemKind: Int] = [:]
            for _ in 0..<Balance.advanceItems {
                if let kind = giveRandomItem() { counts[kind, default: 0] += 1 }
            }
            items = counts.isEmpty ? "가방이 가득이라 사양했습니다"
                : ItemKind.allCases.compactMap { kind in counts[kind].map { "\(kind.shortTitle) \($0)" } }.joined(separator: ", ")
        } else {
            if luck.id == Lucks.guest.id {
                let others = Library.authors.filter { $0 != (author ?? "") }
                guest = invited ?? (others.isEmpty ? nil : others[min(others.count - 1, Int(random() * Double(others.count)))])
            }
            state.luck = ActiveLuck(id: luck.id, startedAt: now, endsAt: now.addingTimeInterval(Double(luck.minutes) * 60), guest: guest)
        }
        let text = Lucks.text(luck, guest: guest, items: items)
        state.note = EventNote(text: text, date: now, event: luck.id, kind: .luck, notified: false)
        var record = EventRecord(event: luck.id, book: WritingProgress(state: state).book?.file, startedAt: now)
        record.endedAt = now.addingTimeInterval(Double(luck.minutes) * 60)
        record.outcome = text
        state.eventLog.append(record)
        if state.eventLog.count > WritingState.maxEventLog {
            state.eventLog.removeFirst(state.eventLog.count - WritingState.maxEventLog)
        }
        save(now: now)
    }

    /// 상황을 시작한다. 확인용 실행에서 직접 부르기도 한다. `author` 는 지금 쓰는 작가(전집 효과용).
    func start(_ event: AuthorEvent, now: Date = Date(), author: String? = nil, minutes fixed: Double? = nil) {
        let range = Balance.eventMinutes
        let minutes = fixed ?? (Double(range.lowerBound) + random() * Double(range.upperBound - range.lowerBound))
            * perks.eventDuration(author: author)
        var active = ActiveEvent(id: event.id, startedAt: now, endsAt: now.addingTimeInterval(minutes * 60))
        if !event.causes.isEmpty { active.cause = min(event.causes.count - 1, Int(random() * Double(event.causes.count))) }
        state.event = active
        // 닫히지 않은 기록이 남아 있으면(예전 파일) 지금 시각으로 닫는다.
        state.closeRecord(at: now, by: nil)
        var record = EventRecord(event: event.id, book: WritingProgress(state: state).book?.file, startedAt: now)
        record.cause = active.cause.map { event.causes[$0] }
        state.eventLog.append(record)
        if state.eventLog.count > WritingState.maxEventLog {
            state.eventLog.removeFirst(state.eventLog.count - WritingState.maxEventLog)
        }
        save(now: now)
    }

    /// 자연재해. 지금 쓰는 책의 원고 일부를 오늘 기록에서 뺀다. 이 책에서 쓴 만큼보다 많이 빼지 않아
    /// 탈고한 책이 되돌아가지 않는다. 아직 이 책을 한 글자도 안 썼으면 아무 일도 없다.
    @discardableResult
    func strike(_ disaster: Disaster, now: Date = Date()) -> Int {
        let progress = WritingProgress(state: state, now: now)
        guard let book = progress.book, progress.charactersInBook > 0 else { return 0 }
        let range = Balance.disasterLoss
        let share = range.lowerBound + random() * (range.upperBound - range.lowerBound)
        var lost = min(progress.charactersInBook, max(1, Int(share * Double(book.characters) * perks.disasterLoss)))
        var line = EventRecord(event: disaster.id, book: book.file, startedAt: now)
        line.endedAt = now
        // 방재 아이템(금고·사본)이 있으면 하나가 저절로 쓰이고 잃는 것이 없다.
        if let shield = ItemRole.shield.kinds.first(where: { state.items[$0.rawValue, default: 0] > 0 }) {
            state.items[shield.rawValue, default: 0] -= 1
            lost = 0
            line.endedBy = shield.rawValue
            line.outcome = shield.curedLines.first
        } else {
            let key = DayKey.string(from: Calendar.current.startOfDay(for: now))
            var record = state.days[key] ?? WritingRecord(tokens: 0, characters: 0)
            record.lost = (record.lost ?? 0) + Double(lost)
            state.days[key] = record
        }
        line.lostCharacters = lost
        state.eventLog.append(line)
        if state.eventLog.count > WritingState.maxEventLog {
            state.eventLog.removeFirst(state.eventLog.count - WritingState.maxEventLog)
        }
        save(now: now)
        return lost
    }

    /// 알리지 않은 자연재해. 알리고 나면 `markDisasterNotified` 로 적는다.
    var unnotifiedDisasters: [EventRecord] {
        state.eventLog.filter { $0.lostCharacters != nil && $0.notified != true }
    }

    func markDisasterNotified(_ id: String) {
        guard let i = state.eventLog.firstIndex(where: { $0.id == id }) else { return }
        state.eventLog[i].notified = true
        save()
    }

    /// 아이템을 써서 지금 상황을 끝낸다. 맞는 아이템이 아니거나 없으면 그대로다.
    /// `Balance.refusalChance` 로 작가가 거절한다. 거절하면 아이템은 그대로 두고 몇 분 동안 다시 쓸 수 없다.
    @discardableResult
    func use(_ item: ItemKind, now: Date = Date()) -> WritingProgress {
        guard let active = state.event, let event = AuthorEvents.byID(active.id), event.cure.role == item.role,
              state.items[item.rawValue, default: 0] > 0 else { return WritingProgress(state: state) }
        // 이미 끝날 시각이 지났으면 아이템을 쓰지 않고 돌아온 것으로 처리한다(갱신 사이 틈).
        if now >= active.endsAt {
            state.event = nil
            let text = event.pick(event.returns, random()) ?? "다시 자리에 앉아 펜을 듭니다"
            state.note = EventNote(text: text, date: active.endsAt, event: active.id, kind: .returned)
            state.closeRecord(at: active.endsAt, by: nil, outcome: text)
            save(now: now)
            return WritingProgress(state: state)
        }
        if let until = active.refusedUntil, now < until { return WritingProgress(state: state) }
        // 거절당할수록 다음엔 덜 거절한다(25 → 15 → 5%).
        let refusals = active.refusals ?? 0
        let chance = max(0, min(0.9, refusalChance - perks.refusalDelta - Balance.refusalDecay * Double(refusals) + Boosts(state.boosts, now: now).refusal
                                   + StudioPerks(owned: state.studio).refusal))
        if !event.refusals.isEmpty, random() < chance {
            let range = Balance.refusalMinutes
            let minutes = (Double(range.lowerBound) + random() * Double(range.upperBound - range.lowerBound)) * perks.refusalWait
            state.event?.refusedUntil = now.addingTimeInterval(minutes * 60)
            state.event?.refusals = refusals + 1
            let lines = item.isPrimary ? event.refusals : item.refusalLines
            let text = event.pick(lines, random()) ?? "지금은 싫다고 합니다"
            state.note = EventNote(text: text, date: now, event: event.id, kind: .refused, notified: true)
            save(now: now)
            return WritingProgress(state: state)
        }
        state.items[item.rawValue, default: 0] -= 1
        state.event = nil
        if refusals > 0 { state.counters[Counter.persistence.rawValue, default: 0] += 1 }
        if item.role == .wake, Self.staminaEnabled, let author = WritingProgress(state: state, now: now).book?.authorShort {
            var sheet = state.sheets[author] ?? AuthorSheet()
            sheet.stamina = min(StatPerks(sheet).staminaMax, sheet.stamina + Balance.staminaCupRestore)
            state.sheets[author] = sheet
        }
        let text = event.pick(item.isPrimary ? event.cured : item.curedLines, random()) ?? "다시 씁니다"
        state.note = EventNote(text: text, date: now, event: event.id, kind: .cured, notified: true)
        state.closeRecord(at: now, by: item, outcome: text)
        save(now: now)
        return WritingProgress(state: state)
    }

    /// 다른 기록 파일로 바꾼다. 먼저 읽어 보고, 되면 지금 파일을 `writing.imported-backup-<시각>.json` 으로 남긴다.
    func replace(with url: URL) -> Bool {
        guard persist, let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any], raw["days"] != nil,
              let loaded = try? JSONDecoder().decode(WritingState.self, from: data), !loaded.days.isEmpty
        else { return false }
        let fm = FileManager.default
        if fm.fileExists(atPath: self.url.path) {
            let aside = self.url.deletingPathExtension().appendingPathExtension("imported-backup-\(Int(Date().timeIntervalSince1970)).json")
            try? fm.copyItem(at: self.url, to: aside)
        }
        state = loaded
        // 가져온 기록의 토큰 수는 다른 Mac 의 로그 합이다. 이 Mac 의 로그와 바로 비교하면 차이가 전부 글자가 되니,
        // 다음 갱신은 토큰만 맞춰 적는 기준선으로 돈다.
        needsBaseline = true
        save()
        return true
    }

    /// 같은 아이템 세 개를 다른 아이템 하나로 바꾼다.
    @discardableResult
    func exchange(_ from: ItemKind, for to: ItemKind) -> WritingProgress {
        guard from != to, state.items[from.rawValue, default: 0] >= Balance.exchangeCost,
              state.items[to.rawValue, default: 0] < Balance.itemCap else { return WritingProgress(state: state) }
        state.items[from.rawValue, default: 0] -= Balance.exchangeCost
        state.items[to.rawValue, default: 0] += 1
        state.counters[Counter.exchanges.rawValue, default: 0] += 1
        save()
        return WritingProgress(state: state)
    }

    /// 돌아옴 알림을 보냈다고 적는다.
    func markNoteNotified() {
        guard state.note != nil else { return }
        state.note?.notified = true
        save()
    }

    /// 확인용 실행에서 아이템을 하나 쥐여 준다.
    func giveForTesting(_ item: ItemKind) {
        state.items[item.rawValue, default: 0] += 1
    }

    /// 알림을 보냈다고 적는다.
    func markNotified() {
        guard state.event != nil else { return }
        state.event?.notified = true
        save()
    }

    /// 새로 이룬 성과를 적고 보상 아이템을 준다. 저장할 때마다 부른다.
    /// 처음 세는 때에 이미 이룬 것은 조용히 채우고 보상도 없다.
    private func updateBadges(now: Date = Date()) {
        let progress = WritingProgress(state: state, now: now)
        let quiet = !state.badgesInitialized
        let calendar = Calendar.current
        for achievement in Achievements.all where achievement.isMet(progress.facts) {
            let previous = state.badges[achievement.id]
            if let previous {
                // 매일 성과만 다시 이룰 수 있다. 오늘 이미 이뤘으면 그대로.
                guard achievement.daily, !calendar.isDate(previous.date, inSameDayAs: now) else { continue }
            }
            var record = BadgeRecord(date: now, notified: quiet)
            if achievement.daily {
                record.count = (previous?.count ?? 0) + 1
                let yesterday = previous.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.date),
                                                                        to: calendar.startOfDay(for: now)).day == 1 } ?? false
                record.streak = yesterday ? (previous?.streak ?? 1) + 1 : 1
            }
            if !quiet, badgeRewards {
                let items = (0..<achievement.rewardCount).compactMap { _ in giveRandomItem() }
                record.reward = items.map(\.rawValue)
            }
            state.badges[achievement.id] = record
        }
        state.badgesInitialized = true
    }

    /// 받은 금 뱃지와 진열대 뱃지(최대 3칸)의 효과. 매일 성과는 오늘 이룬 것만.
    private var perks: Perks { Perks(badges: state.badges, equipped: state.equippedBadges) }

    /// 훈장 진열대(최대 3칸)에 받은 뱃지를 꽂거나 뺀다. 이미 3칸이 다 차 있으면 가장 먼저 꽂았던 것을 빼고 넣는다.
    @discardableResult
    func toggleBadge(_ id: String, now: Date = Date()) -> WritingProgress {
        if let index = state.equippedBadges.firstIndex(of: id) {
            state.equippedBadges.remove(at: index)
            save(now: now)
            return WritingProgress(state: state, now: now)
        }
        let current = WritingProgress(state: state, now: now)
        guard let a = Achievements.byID(id), !a.daily else { return current }
        guard state.badges[id] != nil || a.isMet(current.facts) else { return current }
        state.equippedBadges.removeAll { $0 == id }
        while state.equippedBadges.count >= Perks.maxEquipped {
            state.equippedBadges.removeFirst()
        }
        state.equippedBadges.append(id)
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 해금된 후원자 칭호를 고른다. `nil` 을 넘기면 가장 높은 등급의 해금 칭호를 자동으로 쓴다.
    @discardableResult
    func selectPatronTitle(_ id: String?, now: Date = Date()) -> WritingProgress {
        guard let id else {
            state.patronTitle = nil
            save(now: now)
            return WritingProgress(state: state, now: now)
        }
        let current = WritingProgress(state: state, now: now)
        guard let a = Achievements.byID(id), !a.daily, a.patronTitle != nil,
              state.badges[id] != nil || a.isMet(current.facts) else { return current }
        state.patronTitle = id
        save(now: now)
        return WritingProgress(state: state, now: now)
    }

    /// 가득 차지 않은 종류 가운데 하나를 비중대로 준다. 모두 가득이면 아무것도 주지 않는다.
    @discardableResult
    func giveRandomItem() -> ItemKind? {
        let open = ItemKind.allCases.filter { state.items[$0.rawValue, default: 0] < Balance.itemCap }
        guard let kind = ItemKind.random(random(), among: open) else { return nil }
        state.items[kind.rawValue, default: 0] += 1
        return kind
    }

    /// 성과용 셈 값 이름.
    enum Counter: String {
        /// 아이템 교환 횟수
        case exchanges
        /// 거절당한 뒤 다시 권해 통한 횟수
        case persistence
        /// 밤(22~5시)에 쓴 글자
        case nightCharacters
        /// 원고 읽기 창을 연 횟수
        case reads
        /// 몰아 쓰기 횟수
        case focuses
        /// 농땡이 중에 들킨(돌아온) 횟수
        case caught
        /// 선택지가 있는 사건에 직접 답한 횟수
        case decisions
        /// 지금 쓰는 작가가 별 2개 이하 비평을 받은 횟수
        case panned
        /// 손님 작가와 말다툼한 횟수
        case quarrels
        /// 상시 창 초상화를 누른 횟수
        case taps
        /// 영감의 날을 직접 켠 횟수
        case ignitions
        /// 마감을 지킨·어긴 횟수
        case deadlinesMet
        case deadlinesMissed
        /// 내기를 이긴·진 횟수
        case betsWon
        case betsLost
        /// 써 본 출판사. 키 뒤에 ".major" 처럼 붙는다.
        case publishers
        /// 광고 횟수, 독자 주문대로 쓴 횟수, 서점 사건 수
        case ads
        case ordersFilled
        case shopEvents
        /// 오른 능력치 수
        case statUps
        /// 탈진 횟수
        case exhaustions
        /// 품절·재판·정산서 횟수
        case soldOuts, reprints, statements
        /// 마을에서 주운 물건, 권해서 판 횟수
        case pickups, recommendations
        /// 살롱에서 청한 횟수
        case invites
    }

    /// 셈 값을 올린다. 화면에서 부르는 것(원고 읽기)도 있다.
    func bump(_ counter: Counter, by amount: Int = 1) {
        state.counters[counter.rawValue, default: 0] += amount
        save()
    }

    /// 지금 상태의 진행.
    var progress: WritingProgress { WritingProgress(state: state) }

    /// 알리지 않은 성과.
    var unnotifiedBadges: [Achievement] {
        Achievements.all.filter { state.badges[$0.id]?.notified == false }
    }

    /// 성과 보상으로 받은 아이템 이름("커피 1, 종 2").
    func rewardText(for id: String) -> String? {
        guard let reward = state.badges[id]?.reward, !reward.isEmpty else { return nil }
        var counts: [ItemKind: Int] = [:]
        for raw in reward { if let kind = ItemKind(rawValue: raw) { counts[kind, default: 0] += 1 } }
        return ItemKind.allCases.compactMap { kind in counts[kind].map { n in "\(kind.shortTitle) \(n)" } }.joined(separator: ", ")
    }

    func markBadgeNotified(_ id: String) {
        guard state.badges[id] != nil else { return }
        state.badges[id]?.notified = true
        save()
    }

    /// `now` 는 확인용 실행이 시간을 흉내 낼 때 쓴다. 매일 성과가 "오늘"을 그 시각으로 본다.
    private func save(now: Date = Date()) {
        guard persist else { return }
        updateBadges(now: now)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        guard let data = try? encoder.encode(state) else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let backup = url.deletingPathExtension().appendingPathExtension("backup.json")
        if fm.fileExists(atPath: url.path), !skipBackupOnce {
            try? fm.removeItem(at: backup)
            try? fm.copyItem(at: url, to: backup)
        }
        skipBackupOnce = false
        try? data.write(to: url, options: .atomic)
    }
}
