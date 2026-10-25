import Foundation
import SwiftUI

@MainActor
extension Dump {
    /// 카페인·원문 서재·작업실·출판사·내기·서점·능력치 확인.
    static func selfTestSimulation(
        dir: URL,
        today: Date,
        now: Date,
        firstBook: Book,
        days: (Int) -> [DayUsage],
        check: (Bool, String) -> Void
    ) -> Bool {
        var w: WritingProgress
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
        // 압축: lzma 로 줄였다 풀면 같고, 모든 책에 첫머리 발췌(opening)가 들어 있다.
        check(Library.books.allSatisfy { ($0.opening ?? "").count >= 20 },
              "원문: 모든 책(\(Library.books.count)권)에 서재 미리보기용 첫머리 발췌가 내장됨")
        if let first = Library.books.first, let text = Library.text(of: first), let packed = Library.pack(text.string),
           let back = try? (packed as NSData).decompressed(using: .lzma) as Data {
            check(String(data: back, encoding: .utf8) == text.string && packed.count * 2 < text.string.utf8.count,
                  "압축(lzma): \(first.displayTitle) \(text.string.utf8.count / 1024)KB → \(packed.count / 1024)KB, 풀면 같음")
        }
        // 단일 컨테이너(books.pak): 오프셋·길이만으로 임의 접근 복원이 되는지 확인.
        var repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while repoRoot.path != "/", !FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("Package.swift").path) {
            repoRoot = repoRoot.deletingLastPathComponent()
        }
        let buildBooksDir = repoRoot.appendingPathComponent("build/Books")
        if let data = try? Data(contentsOf: buildBooksDir.appendingPathComponent("manifest.json")),
           let pakBooks = try? JSONDecoder().decode([Book].self, from: data),
           let sample = pakBooks.last {
            let loaded = Library.load(sample, in: buildBooksDir)
            check(loaded?.count == sample.characters,
                  "단일 아카이브(books.pak): 마지막 책(\(sample.displayTitle)) 오프셋 임의 접근 복원 글자 수 일치")
        }
        // 세이브 호환성: 43권 시절 저장된 사용자 지정 순서(orders)가 있어도 앞 순서를 보존하고 새 책을 뒤에 이어 붙인다.
        var migratedState = WritingState()
        let oldOrder = [2, 0, 1] + Array(3..<43)
        migratedState.orders = [oldOrder]
        let migratedProgress = WritingProgress(state: migratedState, now: now)
        check(migratedProgress.roundOrder.count == Library.books.count
              && Array(migratedProgress.roundOrder.prefix(43)) == oldOrder,
              "세이브 호환: 구버전(43권) 집필 순서 보존 및 신규 작품 자동 병합")
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
        guard let waiting = w.awaitingPublisher else { check(false, "출판사: 탈고 뒤 고르기 기다림"); return false }
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
        return true
    }
}
