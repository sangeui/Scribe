import Foundation
import SwiftUI

@MainActor
extension Dump {
    /// 서점 운영·마을·살롱·로그 파서·업데이터·국제화·토큰 인사이트·환율 확인.
    static func selfTestSystems(
        dir: URL,
        now: Date,
        firstBook: Book,
        days: (Int) -> [DayUsage],
        check: (Bool, String) -> Void
    ) {
        var w: WritingProgress
        // 서점 운영: 탈고하면 견본 100부, 출판사를 고르면 초판이 들어오고, 재고만큼만 팔리며, 품절이면 재판을 기다리고 놓친 손님을 센다.
        // 주인은 아침마다 자리를 정하고, 직접 고른 자리는 이레 동안 두며, 월요일에 정산서를 보낸다.
        WritingStore.stockEnabled = true
        let shopStore = WritingStore(url: dir.appendingPathComponent("shopops.json"))
        shopStore.badgeRewards = false
        shopStore.eventChance = 0; shopStore.disasterChance = 0; shopStore.luckChance = 0; shopStore.dilemmaChance = 0
        shopStore.random = { 0.5 }
        let open = WritingStore.weekStart(of: now).addingTimeInterval(86_400 + 10 * 3600)
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
        let shopEventsStore = WritingStore(url: dir.appendingPathComponent("shopevents.json"))
        shopEventsStore.badgeRewards = false
        shopEventsStore.eventChance = 0; shopEventsStore.disasterChance = 0; shopEventsStore.luckChance = 0; shopEventsStore.dilemmaChance = 0
        shopEventsStore.random = { 0.5 }
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
        {"tag_name":"v0.2.0","html_url":"https://github.com/sangeui/Scribe/releases/tag/v0.2.0","body":"## 주요 변경 사항\\n- **해와 달 표시**: 상시 창에 고도를 표시합니다.\\n- 서재 색상 정돈\\n\\n**Full Changelog**: https://github.com/sangeui/Scribe/compare/v0.1.0...v0.2.0","assets":[{"name":"Scribe.zip","browser_download_url":"https://github.com/sangeui/Scribe/releases/download/v0.2.0/Scribe.zip"}]}
        """.utf8)
        let parsedNew = AppUpdater.parseRelease(data: releaseJSON, currentVersion: "0.1.0")
        let parsedSame = AppUpdater.parseRelease(data: releaseJSON, currentVersion: "0.2.0")
        check(parsedNew?.version == "0.2.0" && parsedNew?.summaryLines.count == 2 && parsedSame == nil,
              "업데이터: 최신 릴리스 감지 (\(parsedNew?.version ?? "-"), 요약 \(parsedNew?.summaryLines.count ?? 0)줄, 같은 버전이면 무시)")

        // 75. 국제화(한국어·영어 String Catalog 및 L10n 런타임 전환) 검증
        func containsHangul(_ s: String) -> Bool {
            s.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }
        }
        L10n.overrideLanguage = .en
        let enBook = Library.books.first
        let enBookTitle = enBook?.displayTitle
        let enBookAuthor = enBook?.displayAuthor
        let enShort12k = Format.short(12_500)
        let enShort2m = Format.short(2_000_000)
        let enPattern = L10n.tr("전체 1,000자 중 500자")
        let allAuthorEvents = AuthorEvents.common + Array(AuthorEvents.byAuthor.values)
        let allBadgesTranslated = Achievements.all.allSatisfy { !containsHangul($0.title) && !containsHangul($0.detail) && !containsHangul($0.patronTitle ?? "") }
        let allItemsTranslated = ItemKind.allCases.allSatisfy { !containsHangul($0.title) && !containsHangul($0.shortTitle) }
        let allDecorTranslated = Decor.all.allSatisfy { !containsHangul($0.title) }
        let allStudioTranslated = Studio.all.allSatisfy { !containsHangul($0.title) && !containsHangul($0.effect) }
        let allEventsTranslated = allAuthorEvents.allSatisfy { !containsHangul($0.text) && $0.causes.allSatisfy { !containsHangul(L10n.tr($0)) } }
        let allDilemmasTranslated = Dilemmas.all.allSatisfy { !containsHangul($0.title) && $0.options.allSatisfy { !containsHangul($0.label) } }
        L10n.overrideLanguage = nil
        check(enBookTitle == enBook?.title && enBookAuthor == enBook?.author && enShort12k == "12.5K" && enShort2m == "2M" && !containsHangul(enPattern),
              "국제화(en): 작품 제목(\(enBookTitle ?? "-"))·숫자(\(enShort12k), \(enShort2m))·동적 문장(\"\(enPattern)\") 영어 변환")
        check(allBadgesTranslated && allItemsTranslated && allDecorTranslated && allStudioTranslated && allEventsTranslated && allDilemmasTranslated && !L10n.isEnglish,
              "국제화(en): 업적(\(Achievements.all.count))·아이템(\(ItemKind.allCases.count))·장신구(\(Decor.all.count))·가구(\(Studio.all.count))·돌발상황(\(allAuthorEvents.count))·사건(\(Dilemmas.all.count)) 한글 잔존 0건 및 기본 로케일 복원")

        // 76. 토큰 단위 국제화(만·억 vs K·M·B) 및 토큰 인사이트(캐시 절감·문맥 밀도·몰입 시간대) 검증
        let koTok1 = Format.tokens(1_250)
        let koTok25m = Format.tokens(25_000_000)
        let koTok150m = Format.tokens(150_000_000)
        L10n.overrideLanguage = .en
        let enTok25m = Format.tokens(25_000_000)
        let enTok150m = Format.tokens(150_000_000)
        L10n.overrideLanguage = nil
        check(koTok1 == "1,250" && koTok25m == "2,500만" && koTok150m == "1.5억" && enTok25m == "25M" && enTok150m == "150M",
              "토큰 단위 국제화: 한국어(\(koTok1), \(koTok25m), \(koTok150m)) vs 영어(\(enTok25m), \(enTok150m))")

        let insightCal = Calendar.current
        let insightToday = insightCal.startOfDay(for: now)
        let insightAfternoon = insightCal.date(bySettingHour: 15, minute: 0, second: 0, of: insightToday)!
        let insightLastWeek = insightCal.date(byAdding: .day, value: -8, to: insightAfternoon)!
        let insightEntries = [
            UsageEntry(id: "i1", provider: .claude, date: insightLastWeek, model: "claude-sonnet-4-6",
                       input: 100_000, output: 20_000, cacheWrite5m: 0, cacheWrite1h: 0, cacheRead: 880_000),
            UsageEntry(id: "i2", provider: .claude, date: insightAfternoon, model: "claude-sonnet-4-6",
                       input: 50_000, output: 10_000, cacheWrite5m: 0, cacheWrite1h: 0, cacheRead: 940_000),
            UsageEntry(id: "i3", provider: .claude, date: insightAfternoon.addingTimeInterval(600), model: "claude-sonnet-4-6",
                       input: 50_000, output: 10_000, cacheWrite5m: 0, cacheWrite1h: 0, cacheRead: 940_000),
        ]
        let insightSnap = UsageAggregator.snapshot(entries: insightEntries, scannedFiles: 1, source: .claude, now: insightAfternoon.addingTimeInterval(1200), calendar: insightCal)
        // claude-sonnet-4-6: input $3/M, cacheRead $0.3/M -> 1.88M cacheRead saves 1.88 * $2.7 = $5.076
        check(insightSnap.todayTurns == 2
              && insightSnap.todayAvgTokensPerTurn == 1_000_000
              && abs(insightSnap.todayCacheSavedCost - 5.076) < 0.01
              && insightSnap.focusWindow?.blockIndex == 2
              && insightSnap.focusWindow?.peakHour == 15
              && insightSnap.weekOverWeekPercent == 100,
              "토큰 인사이트: 오늘 \(insightSnap.todayTurns)턴(평균 \(Format.tokens(insightSnap.todayAvgTokensPerTurn))) · 캐시 절감 \(Format.cost(insightSnap.todayCacheSavedCost)) · \(insightSnap.focusWindow?.title ?? "-") · 주간 +\(Int(insightSnap.weekOverWeekPercent ?? 0))%")

        // 77. 화폐 단위 국제화(원화 한글 단위형 vs USD) · 환율 파서 · 오프라인 이전날 환율 폴백 · 설정 5탭 검증
        ExchangeRate.overrideRate = 1_400.0
        let koCostZero = Format.cost(0)
        let koCost450 = Format.cost(450.0 / 1_400.0)
        let koCost14k = Format.cost(14_200.0 / 1_400.0)
        let koCost142k = Format.cost(142_000.0 / 1_400.0)
        let koCost140m = Format.cost(140_000_000.0 / 1_400.0)
        L10n.overrideLanguage = .en
        let enCostZero = Format.cost(0)
        let enCostSmall = Format.cost(0.45)
        let enCostMid = Format.cost(12.34)
        let enCostBig = Format.cost(120.4)
        let enTabs = SettingsTab.allCases.map(\.title)
        L10n.overrideLanguage = nil
        ExchangeRate.overrideRate = nil
        let koTabs = SettingsTab.allCases.map(\.title)
        check(koCostZero == "0원"
              && koCost450 == "450원"
              && koCost14k == "14,200원"
              && koCost142k == "14.2만 원"
              && koCost140m == "1.4억 원"
              && enCostZero == "$0.00"
              && enCostSmall == "$0.45"
              && enCostMid == "$12.34"
              && enCostBig == "$120",
              "화폐 단위 국제화: 한국어(\(koCostZero), \(koCost450), \(koCost14k), \(koCost142k), \(koCost140m)) vs 영어(\(enCostZero), \(enCostSmall), \(enCostMid), \(enCostBig))")

        let frankfurterJSON = Data(#"{"amount":1.0,"base":"USD","date":"2026-10-23","rates":{"KRW":1388.45}}"#.utf8)
        let openErJSON = Data(#"{"result":"success","rates":{"USD":1,"KRW":1389.12}}"#.utf8)
        let parsed1 = ExchangeRate.parseResponse(data: frankfurterJSON, now: now)
        let parsed2 = ExchangeRate.parseResponse(data: openErJSON, now: now)
        let savedPrevRate = UserDefaults.standard.object(forKey: ExchangeRate.rateKey) as? Double
        let savedPrevDate = UserDefaults.standard.string(forKey: ExchangeRate.dateKey)
        let savedPrevFetchedAt = UserDefaults.standard.object(forKey: ExchangeRate.fetchedAtKey) as? Double
        let yesterday = now.addingTimeInterval(-90_000)
        ExchangeRate.save(rate: 1_392.5, dateString: "2026-10-24", now: yesterday)
        let needsRefresh = ExchangeRate.needsDailyRefresh(now: now)
        let cachedFallbackRate = UserDefaults.standard.double(forKey: ExchangeRate.rateKey)
        if let savedPrevRate { UserDefaults.standard.set(savedPrevRate, forKey: ExchangeRate.rateKey) } else { UserDefaults.standard.removeObject(forKey: ExchangeRate.rateKey) }
        if let savedPrevDate { UserDefaults.standard.set(savedPrevDate, forKey: ExchangeRate.dateKey) } else { UserDefaults.standard.removeObject(forKey: ExchangeRate.dateKey) }
        if let savedPrevFetchedAt { UserDefaults.standard.set(savedPrevFetchedAt, forKey: ExchangeRate.fetchedAtKey) } else { UserDefaults.standard.removeObject(forKey: ExchangeRate.fetchedAtKey) }
        let savedFloatingStyle = UserDefaults.standard.string(forKey: FloatingStyle.key)
        UserDefaults.standard.set(FloatingStyle.pill.rawValue, forKey: FloatingStyle.key)
        FloatingStyle.toggle()
        let toggledToMini = (FloatingStyle.current == .mini)
        FloatingStyle.toggle()
        let toggledBackToPill = (FloatingStyle.current == .pill)
        if let savedFloatingStyle {
            UserDefaults.standard.set(savedFloatingStyle, forKey: FloatingStyle.key)
        } else {
            UserDefaults.standard.removeObject(forKey: FloatingStyle.key)
        }
        check(parsed1?.rate == 1388.45
              && parsed1?.date == "2026-10-23"
              && parsed2?.rate == 1389.12
              && needsRefresh
              && cachedFallbackRate == 1_392.5
              && toggledToMini && toggledBackToPill
              && AppLanguage.ko.resolved == .ko
              && AppLanguage.en.resolved == .en
              && (AppLanguage.system.resolved == .ko || AppLanguage.system.resolved == .en)
              && koTabs == ["일반", "화면", "집필", "알림", "정보"]
              && enTabs == ["General", "Display", "Writing", "Notifications", "About"],
              "환율 파서·오프라인 이전날 환율 폴백(1,392.5원)·시스템 언어 해석(\(AppLanguage.system.resolved.rawValue))·상시 창 모드 토글(알약↔미니)·설정 5탭 검증")
    }
}
