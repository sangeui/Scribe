import Foundation
import SwiftUI

@MainActor
extension Dump {
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
        let expectedCause = Int(0.1 * Double(AuthorEvents.away.causes.count))
        check(stubborn.state.event?.cause == expectedCause && stubborn.state.eventLog.last?.cause == AuthorEvents.away.causes[expectedCause], "원인: 시작할 때 고름")
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
        // 훈장 진열대(최대 3칸)와 후원자 칭호: 동·은·금 뱃지를 진열하면 slotPerk가 더해지고, 해금된 칭호를 고를 수 있다.
        check(Achievements.all.filter { !$0.daily }.allSatisfy { ($0.patronTitle ?? "").count >= 2 },
              "후원자 칭호: 모든 일반 성과(\(Achievements.all.filter { !$0.daily }.count)개)에 후원자 칭호가 부여됨")
        let secretList = Achievements.all.filter(\.isSecret)
        let defaultSecretClue = Achievements.secretClue(for: "_unknown_")
        check(secretList.allSatisfy { Achievements.secretClue(for: $0.id) != defaultSecretClue },
              "비밀 성과: 모든 비밀 성과(\(secretList.count)개)에 고유 단서가 부여됨")
        w = perkStore.toggleBadge("first_line", now: now)
        w = perkStore.toggleBadge("chars_10k", now: now)
        w = perkStore.toggleBadge("chars_1m", now: now)
        check(w.equippedBadges == ["first_line", "chars_10k", "chars_1m"] && abs(w.perks.characterBonus - 0.14) < 0.0001,
              "훈장 진열대: 3칸 장식 시 기본 5% + 진열(2% + 2% + 5%) = 글자 보너스 \(Int((w.perks.characterBonus * 100).rounded()))%")
        w = perkStore.toggleBadge("books_10", now: now)
        check(w.equippedBadges == ["chars_10k", "chars_1m", "books_10"] && w.equippedBadges.count == Perks.maxEquipped,
              "훈장 진열대: 4번째를 장식하면 가장 먼저 꽂은 것이 빠지고 3칸 유지 (\(w.equippedBadges))")
        w = perkStore.toggleBadge("books_10", now: now)
        check(w.equippedBadges == ["chars_10k", "chars_1m"], "훈장 진열대: 이미 꽂힌 뱃지를 다시 누르면 해제")
        w = perkStore.toggleBadge("chars_5m", now: now)
        check(w.equippedBadges == ["chars_10k", "chars_1m"], "훈장 진열대: 아직 못 받은 뱃지는 장식되지 않음")
        check(w.patronTitle == Achievements.byID("chars_1m")?.patronTitle,
              "후원자 칭호: 기본값은 해금된 가장 높은 등급 칭호 \"\(w.patronTitle ?? "-")\"")
        w = perkStore.selectPatronTitle("first_line", now: now)
        check(w.patronTitle == "첫 원고의 마중물" && w.selectedPatronID == "first_line",
              "후원자 칭호: 직접 선택한 칭호 \"\(w.patronTitle ?? "-")\" 적용")
        w = perkStore.selectPatronTitle("chars_5m", now: now)
        check(w.patronTitle == "첫 원고의 마중물", "후원자 칭호: 미달성 칭호는 선택 불가")
        let reloadedPerk = WritingStore(url: perkURL).progress
        check(reloadedPerk.equippedBadges == ["chars_10k", "chars_1m"] && reloadedPerk.patronTitle == "첫 원고의 마중물",
              "훈장 진열대·후원자 칭호: 파일 저장 및 재로드 일치")
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
        let texts = Set((0..<40).map { (i: Int) -> String in
            let r0 = Double(i % 7) / 7.0
            let r1 = Double(i % 4) / 4.0
            let r2 = Double(i % 3) / 3.0
            return Critics.text(for: 3, days: 5, events: 1, lost: 0, title: "책", author: "작가", voice: .dry,
                                rolls: [r0, r1, r2])
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

        guard selfTestSimulation(dir: dir, today: today, now: now, firstBook: firstBook, days: days, check: check) else {
            return print("FAILED")
        }
        selfTestSystems(dir: dir, now: now, firstBook: firstBook, days: days, check: check)

        print(failures == 0 ? "PASS" : "FAILED \(failures)")
    }
}
