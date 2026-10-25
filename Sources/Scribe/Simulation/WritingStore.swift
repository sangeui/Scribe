import Foundation
import SwiftUI

/// 날짜별로 쓴 글자를 파일에 두고, 늘어난 토큰만 글자로 바꾼다.
@MainActor
final class WritingStore {
    var state: WritingState
    let url: URL
    let persist: Bool
    /// 파일이 없을 때 처음 한 번만 참. 그때까지 쓴 토큰은 글자로 바꾸지 않는다.
    var needsBaseline: Bool

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
    var skipBackupOnce = false

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
    func sheetPerks(now: Date) -> StatPerks {
        StatPerks((WritingProgress(state: state, now: now).book?.authorShort).flatMap { state.sheets[$0] })
    }

    /// 모든 작가의 체력이 시간만큼 돌아온다. 밤(22~5시)과 쉬는 동안(상황 중)은 두 배. 바뀐 게 있으면 true.
    func recoverStamina(now: Date) -> Bool {
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
    func wear(author: String, tokens: Int, now: Date) {
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
    func checkDeadline(now: Date) -> Bool {
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
    func sell(tokens: Int, now: Date) {
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
    func noteFinishes(since before: Int, now: Date) {
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
    func review(_ note: FinishNote, book: Book, now: Date) {
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
    func publishReviews(now: Date) -> Bool {
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
}
