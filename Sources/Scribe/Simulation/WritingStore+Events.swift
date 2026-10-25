import Foundation
import SwiftUI

extension WritingStore {
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
    func noteWeek(now: Date) {
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

    func setOrder(_ order: [Int], round: Int) {
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
    func rollEvent(newTokens: Int, now: Date, author: String?) {
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
    func updateBadges(now: Date = Date()) {
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
    var perks: Perks { Perks(badges: state.badges, equipped: state.equippedBadges) }

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
    func save(now: Date = Date()) {
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
