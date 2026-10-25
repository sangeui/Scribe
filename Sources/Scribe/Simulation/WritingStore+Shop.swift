import Foundation
import SwiftUI

extension WritingStore {
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
    func settleUnchosenPublishers(now: Date) -> Bool {
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
    func resolveBet(now: Date) -> Bool {
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
    func receive(_ file: String, copies: Int, now: Date, reason: String?) {
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
    func soldOut(_ file: String, now: Date) {
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
    func tendShop(now: Date) -> Bool {
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
    func arrange(now: Date, morning: Bool) -> Bool {
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
    func settleWeek(now: Date) -> Bool {
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
    func checkOrder(now: Date) -> Bool {
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
}
