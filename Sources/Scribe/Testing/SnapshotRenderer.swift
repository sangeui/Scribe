import AppKit
import SwiftUI

@MainActor
extension Dump {
    /// `Scribe --writing out.png`: 가짜 진행(앞 두 권 탈고, 세 번째 책 12,380자)으로 집필 화면을 그린다.
    /// `--writing-empty` 는 막 시작한 0자 상태, `--event` 는 작가가 다른 일을 하는 모습, `--luck` 은 손님 작가가 와 있는 모습.
    static func renderWriting(to path: String) {
        var state = WritingState()
        if !CommandLine.arguments.contains("--writing-empty") {
            let today = Calendar.current.startOfDay(for: Date())
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            state.days[DayKey.string(from: yesterday)] = WritingRecord(tokens: 1, characters: Double(Library.starts[2]))
            state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
        }
        state.items = ["coffee": 2, "ink": 1, "bell": 1]
        if CommandLine.arguments.contains("--luck") {
            state.luck = ActiveLuck(id: Lucks.guest.id, startedAt: Date(), endsAt: Date().addingTimeInterval(150 * 60), guest: "Goethe")
            state.note = EventNote(text: Lucks.text(Lucks.guest, guest: "Goethe", items: nil), date: Date(), event: Lucks.guest.id, kind: .luck, notified: true)
        }
        if CommandLine.arguments.contains("--event") {
            let author = WritingProgress(state: state).book?.authorShort ?? ""
            let event = AuthorEvents.byAuthor[author] ?? AuthorEvents.away
            state.event = ActiveEvent(id: event.id, startedAt: Date(), endsAt: Date().addingTimeInterval(23 * 60), cause: 0)
            state.items["muse"] = 1
        }
        if let i = CommandLine.arguments.firstIndex(of: "--weather"), CommandLine.arguments.indices.contains(i + 1) {
            Weather.forced = Weather(rawValue: CommandLine.arguments[i + 1])
        }
        if CommandLine.arguments.contains("--deadline") {
            state.deadline = Deadline(weekStart: WritingStore.weekStart(of: Date()), kind: .characters, target: 50_000)
            state.inspiration = Balance.inspirationGaugeTokens
        }
        if CommandLine.arguments.contains("--finish") {
            var note = FinishNote(book: Library.books[1].file, round: 0, date: Date().addingTimeInterval(-600), days: 3, events: 1, lost: 0)
            note.publisherDue = Date().addingTimeInterval(20 * 3600)
            state.finishNotes = [note]
        }
        if CommandLine.arguments.contains("--bet") {
            state.luck = ActiveLuck(id: Lucks.guest.id, startedAt: Date().addingTimeInterval(-1800), endsAt: Date().addingTimeInterval(90 * 60), guest: "Wilde")
            state.bet = ActiveBet(guest: "Wilde", target: 4_500, offeredAt: Date(), endsAt: Date().addingTimeInterval(90 * 60))
            state.studio = ["lamp", "shelf", "cat"]
        }
        if CommandLine.arguments.contains("--dilemma") {
            let kind = Dilemmas.byID("title")!
            state.dilemma = ActiveDilemma(id: kind.id, text: kind.texts[0], startedAt: Date(), expiresAt: Date().addingTimeInterval(95 * 60))
            state.boosts = [ActiveBoost(kind: .sales, value: 1.5, endsAt: Date().addingTimeInterval(5 * 3600), source: "연재로 쪼개자는 출판사"),
                            ActiveBoost(kind: .refusal, value: 0.15, endsAt: Date().addingTimeInterval(2 * 3600), source: "비평 ★2")]
        }
        if CommandLine.arguments.contains("--stats"), let author = WritingProgress(state: state).book?.authorShort {
            var sheet = AuthorSheet()
            sheet.stats = ["pen": 3, "grit": 1, "charm": 2, "luck": 1]
            sheet.stamina = 24
            sheet.tokensTowardStat = 12_400_000
            state.sheets[author] = sheet
            state.note = EventNote(text: Format.resolve("\(Library.books.first { $0.authorShort == author }?.displayAuthorShort ?? author)의 필력(이|가) 3(이|가) 됐습니다. 문장이 전보다 빨리 나옵니다"),
                                   date: Date().addingTimeInterval(-60), event: "pen", kind: .stat, notified: true)
        }
        if CommandLine.arguments.contains("--review") {
            let book = Library.books[0]
            let text = Critics.text(for: 5, days: 3, events: 0, lost: 0, title: book.displayTitle, author: book.displayAuthorShort, voice: .lofty, rolls: [0.1, 0.2, 0.3])
            var review = Review(book: book.file, round: 0, critic: Critics.all[2].name, stars: 5, text: text, date: Date().addingTimeInterval(-600))
            review.published = true
            review.affected = true
            let panned = Critics.text(for: 2, days: 20, events: 4, lost: 3_000, title: Library.books[1].displayTitle, author: Library.books[1].displayAuthorShort, voice: .snippy, rolls: [0.6, 0.4, 0.9])
            var second = Review(book: Library.books[1].file, round: 0, critic: Critics.all[3].name, stars: 2, text: panned, date: Date().addingTimeInterval(-86_400))
            second.published = true
            state.reviews = [second, review]
            state.sales = [book.file: 12_400, Library.books[1].file: 870]
            state.featuredBook = book.file
            state.featuredAt = Date().addingTimeInterval(-3600)
            state.ads[book.file] = Date().addingTimeInterval(5 * 3600)
            state.order = ReaderOrder(book: Library.books[3].file, offeredAt: Date(), expiresAt: Date().addingTimeInterval(6 * 86_400),
                                      text: ReaderOrders.text(ReaderOrders.lines, book: Library.books[3], roll: 0.1))
            state.shopBoosts = [ShopBoost(book: book.file, value: 1.5, endsAt: Date().addingTimeInterval(9 * 3600), source: "신문 소개")]
            state.shop.migrated = true
            state.shop.stock = [book.file: 340, Library.books[1].file: 0]
            state.shop.reprints[Library.books[1].file] = ShopState.Reprint(due: Date().addingTimeInterval(4 * 3600), copies: 1_200, orderedAt: Date().addingTimeInterval(-2 * 3600))
            state.shop.pinned[book.file] = Date().addingTimeInterval(-3600)
            state.shop.trust = 63
            state.shop.trustLog = [TrustRecord(delta: 5, reason: "독자 주문대로 앨리스를 씀", date: Date().addingTimeInterval(-3 * 86_400)),
                                   TrustRecord(delta: -2, reason: "크리스마스 캐럴 품절로 손님을 돌려보냄", date: Date().addingTimeInterval(-2 * 3600)),
                                   TrustRecord(delta: 4, reason: "한 주 내내 손님이 끊이지 않음", date: Date().addingTimeInterval(-6 * 86_400))]
            state.shop.statements = [Statement(weekStart: WritingStore.weekStart(of: Date()).addingTimeInterval(-7 * 86_400),
                                               lines: [StatementLine(book: book.file, sold: 2_980, returned: 0, missed: 0, stock: 340, slot: .window),
                                                       StatementLine(book: Library.books[1].file, sold: 1_400, returned: 12, missed: 210, stock: 0, slot: .storage)],
                                               sold: 4_380, returned: 12, missed: 210, trustBefore: 59, trustAfter: 63,
                                               reasons: ["한 주 내내 손님이 끊이지 않음 (+4)", "크리스마스 캐럴 12부 반품 (-3)"],
                                               keeperLine: "몇 분은 빈손으로 갔습니다. 재고를 조금 넉넉히 두는 게 어떻겠습니까")]
            state.shopLog = [
                ShopRecord(event: "leak", book: nil, text: "서점 지붕에서 비가 새어 책을 안쪽으로 옮겼습니다", date: Date().addingTimeInterval(-2 * 86_400)),
                ShopRecord(event: "mice", book: Library.books[1].file, text: "창고에 쥐가 들어 크리스마스 캐럴 12부를 갉았습니다", date: Date().addingTimeInterval(-30 * 3600), copies: -12),
                ShopRecord(event: "school", book: Library.books[1].file, text: "학교에서 크리스마스 캐럴을 교재로 쓰겠다며 120부를 주문했습니다", date: Date().addingTimeInterval(-86_400), copies: 120),
                ShopRecord(event: "press", book: book.file, text: "아침 신문 문화면에 햄릿이 소개됐습니다", date: Date().addingTimeInterval(-3 * 3600)),
            ]
            for back in 0..<14 {
                let day = Calendar.current.date(byAdding: .day, value: -back, to: Calendar.current.startOfDay(for: Date()))!
                state.salesByDay[DayKey.string(from: day)] = Double([120, 340, 90, 410, 520, 300, 180, 260, 610, 380, 150, 220, 470, 330][back])
            }
            state.note = EventNote(text: Critics.authorLine(stars: 5, roll: 0.1), date: Date().addingTimeInterval(-600), event: review.id, kind: .review, notified: true)
            state.dilemmaLog = [DilemmaRecord(dilemma: "cat", option: "들인다", outcome: Dilemmas.byID("cat")!.options[0].outcomes[0], date: Date().addingTimeInterval(-7200))]
        }
        let progress = WritingProgress(state: state)
        let moodArg = CommandLine.arguments.firstIndex(of: "--mood").flatMap { CommandLine.arguments.indices.contains($0 + 1) ? CommandLine.arguments[$0 + 1] : nil }
        let mood = moodArg.flatMap(Mood.init(rawValue:)) ?? .focused
        let moodLine = mood == .waiting ? MoodLines.waiting[0] : mood == .slacking ? MoodLines.slackIn[0] : mood == .alone ? MoodLines.alone[0] : nil
        let handoff: (from: String, at: Date)? = CommandLine.arguments.contains("--handoff") ? ("Dickens", Date().addingTimeInterval(-2)) : nil
        let content = VStack(alignment: .leading, spacing: 16) {
            FloatingPill(progress: progress, animated: false, mood: mood, moodLine: moodLine, handoff: handoff)
            FloatingPill(progress: progress, featured: "Goethe", animated: false)
            WritingView(progress: progress) {}
                .frame(width: 348)
            HStack(spacing: 10) {
                ForEach(Portraits.all, id: \.0) { author, _ in
                    PortraitFrame(author: author, scale: 3)
                }
            }
            // 돌발 상황 초상화: 공통 상황은 셰익스피어로, 작가 고유 상황은 그 작가로
            HStack(spacing: 10) {
                ForEach(AuthorEvents.common + [AuthorEvents.dark], id: \.id) { event in
                    PortraitFrame(author: "Shakespeare", scale: 3, event: event)
                }
            }
            HStack(spacing: 10) {
                ForEach(Portraits.all, id: \.0) { author, _ in
                    PortraitFrame(author: author, scale: 3, event: AuthorEvents.byAuthor[author])
                }
            }
            HStack(spacing: 14) {
                ForEach(Array((MenuBarFrames.writing + MenuBarFrames.paused).enumerated()), id: \.offset) { _, frame in
                    PixelFrame(rows: frame, scale: 3, palette: ["#": .primary])
                        .padding(4)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            // 장신구: 와일드에게 하나씩 씌운 모습
            HStack(spacing: 10) {
                ForEach(Decor.all) { accessory in
                    PixelFrame(rows: Decor.apply(Portraits.rows("Wilde"), accessory: accessory), scale: 48 / CGFloat(Portraits.size), palette: Portraits.palette)
                        .frame(width: 48, height: 48)
                        .background(Portraits.backdrop("Wilde"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            if CommandLine.arguments.contains("--review") {
                BookstoreContent(progress: progress, scrollable: false).frame(width: 420)
            }
            // 힌트 카드 모양
            HStack(alignment: .top, spacing: 12) {
                HintCard(hint: Hint(title: "이번 주 마감 · 이번 주 5만자", lines: ["출판사에서 편지가 왔습니다. 이번 주에 50,000자를 보내 달랍니다.", "일요일까지입니다. 지키면 아이템 2개와 판매 +20%(하루).", "어기면 거절 확률이 2일 동안 10%p 오릅니다."], symbol: "calendar"))
                HintCard(hint: Hint(title: "오늘 날씨 · 비", lines: ["비가 옵니다. 글이 조금 잘 됩니다.", "효과: 글자 +5% · 돌발 상황 -10%"], symbol: "cloud.rain"))
            }
            if CommandLine.arguments.contains("--badges") {
                BadgeContent(progress: progress, scrollable: false).frame(width: 400)
            }
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
        print("book=\(progress.book?.title ?? "-") chars=\(progress.charactersInBook) finished=\(progress.finished.count)")
    }

    /// `Scribe --styles out.png`: 가짜 기록이 있는 가방과, 밝은·어두운 바탕화면 위의 상시 창을 그린다.
    /// 평소, 가장 긴 돌발 상황 문장(캐럴), 대표 초상화(괴테).
    static func renderStyles(to path: String) {
        func state(event: AuthorEvent?) -> WritingProgress {
            var state = WritingState()
            let today = Calendar.current.startOfDay(for: Date())
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            state.days[DayKey.string(from: yesterday)] = WritingRecord(tokens: 1, characters: Double(Library.starts[2]))
            state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
            state.items = ["coffee": 2, "bell": 1]
            if let event {
                state.event = ActiveEvent(id: event.id, startedAt: Date(), endsAt: Date().addingTimeInterval(23 * 60))
            }
            return WritingProgress(state: state)
        }
        let longest = AuthorEvents.byAuthor["Carroll"]!
        var quakeState = WritingState()
        quakeState.days[DayKey.string(from: Calendar.current.startOfDay(for: Date()))] = WritingRecord(tokens: 1, characters: 12_380)
        quakeState.eventLog = [EventRecord(event: Disasters.quake.id, book: Library.books[0].file, startedAt: Date().addingTimeInterval(-60),
                                           endedAt: Date().addingTimeInterval(-60), lostCharacters: 12_345)]
        let disasterState = WritingProgress(state: quakeState)
        // 가방: 진행 중 하나, 아이템으로 끝낸 것, 저절로 끝난 것
        var bagState = WritingState()
        bagState.items = ["coffee": 2, "bell": 1]
        bagState.days[DayKey.string(from: Calendar.current.startOfDay(for: Date()))] = WritingRecord(tokens: 1, characters: 12_380)
        let now = Date()
        bagState.eventLog = [
            EventRecord(event: "ink", book: Library.books[0].file, startedAt: now.addingTimeInterval(-26 * 3600),
                        endedAt: now.addingTimeInterval(-26 * 3600 + 41 * 60), endedBy: nil, pausedTokens: 3_400_000),
            EventRecord(event: "nap", book: Library.books[0].file, startedAt: now.addingTimeInterval(-3 * 3600),
                        endedAt: now.addingTimeInterval(-3 * 3600 + 4 * 60), endedBy: "coffee", pausedTokens: 600_000),
            EventRecord(event: "away", book: Library.books[0].file, startedAt: now.addingTimeInterval(-50 * 60),
                        endedAt: now.addingTimeInterval(-12 * 60), endedBy: "bell", pausedTokens: 1_200_000),
            EventRecord(event: Disasters.fire.id, book: Library.books[0].file, startedAt: now.addingTimeInterval(-20 * 60),
                        endedAt: now.addingTimeInterval(-20 * 60), lostCharacters: 3_958),
            EventRecord(event: longest.id, book: Library.books[0].file, startedAt: now.addingTimeInterval(-7 * 60), pausedTokens: 250_000),
        ]
        bagState.event = ActiveEvent(id: longest.id, startedAt: now.addingTimeInterval(-7 * 60), endsAt: now.addingTimeInterval(20 * 60))
        func desk(_ scheme: ColorScheme, _ colors: [Color]) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                FloatingPill(progress: state(event: nil), animated: false)
                FloatingPill(progress: state(event: AuthorEvents.nap), animated: false)
                FloatingPill(progress: state(event: longest), animated: false)
                FloatingPill(progress: state(event: nil), featured: "Goethe", animated: false)
                FloatingPill(progress: disasterState, animated: false)
                HStack(spacing: 16) {
                    FloatingMini(progress: state(event: nil), animated: false)
                    FloatingMini(progress: state(event: AuthorEvents.nap), animated: false)
                    FloatingMini(progress: state(event: longest), animated: false)
                    FloatingMini(progress: disasterState, animated: false)
                    FloatingMini(progress: state(event: nil), featured: "Goethe", animated: false)
                }
            }
            .padding(24)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .environment(\.colorScheme, scheme)
        }
        let content = HStack(alignment: .top, spacing: 0) {
            BagContent(progress: WritingProgress(state: bagState), scrollable: false)
                .frame(width: SidePanel.Kind.bag.size.width)
                .background(Color(nsColor: .windowBackgroundColor))
            desk(.light, [Color(red: 0.78, green: 0.84, blue: 0.93), Color(red: 0.93, green: 0.86, blue: 0.82)])
            desk(.dark, [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.26, green: 0.16, blue: 0.24)])
        }
        write(content, to: path)
    }

    /// `Scribe --village out.png`: 마을 맵을 낮과 밤으로. 작가는 서점 문 앞과 길 가운데.
    /// `Scribe --salon out.png`: 살롱을 낮(작가 셋, 하나 골라 둠)과 밤(대화 상자)으로.
    static func renderSalon(to path: String) {
        var state = WritingState()
        let today = Calendar.current.startOfDay(for: Date())
        let done = Library.starts[3]
        state.days[DayKey.string(from: today.addingTimeInterval(-86_400))] = WritingRecord(tokens: 1, characters: Double(done))
        state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
        for book in Library.books.prefix(3) { state.sales[book.file] = 1_800 }
        let progress = WritingProgress(state: state)
        let day = SalonState()
        day.selected = 1
        day.bubble = (0, "그 경구는 내 대사에서 가져간 것 아니오", Date().addingTimeInterval(60))
        let night = SalonState()
        night.selected = 2
        night.dialogue = SalonTalk.author(SalonTalk.seated(progress)[2], progress: progress, now: Date(), mood: .focused, turn: 1)
        let content = VStack(alignment: .leading, spacing: 16) {
            SalonView(progress: progress, state: day, animated: false, date: today.addingTimeInterval(14 * 3600))
            SalonView(progress: progress, state: night, animated: false, date: today.addingTimeInterval(22 * 3600))
                .environment(\.colorScheme, .dark)
        }
        .padding(16)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
    }

    static func renderVillage(to path: String) {
        var state = WritingState()
        let today = Calendar.current.startOfDay(for: Date())
        state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
        state.shop.reprints[Library.books[1].file] = ShopState.Reprint(due: Date().addingTimeInterval(3600), copies: 500, orderedAt: Date())
        state.shop.migrated = true
        state.shop.stock = [Library.books[0].file: 300, Library.books[1].file: 0]
        state.featuredBook = Library.books[0].file
        state.items = ["coffee": 3, "bell": 2, "ink": 2]
        state.ads[Library.books[0].file] = Date().addingTimeInterval(3600)
        state.shopBoosts = [ShopBoost(book: nil, value: 1.3, endsAt: Date().addingTimeInterval(3600), source: "서점 세일")]
        state.days[DayKey.string(from: today.addingTimeInterval(-86_400))] = WritingRecord(tokens: 1, characters: Double(Library.starts[1]))
        let progress = WritingProgress(state: state)
        var nightState = state
        nightState.event = ActiveEvent(id: AuthorEvents.nap.id, startedAt: Date(), endsAt: Date().addingTimeInterval(1200))
        let nightProgress = WritingProgress(state: nightState)
        let atDoor = VillageState()
        atDoor.stand(at: .bookstore)
        atDoor.facing = .up
        atDoor.setCustomers(3, leaving: false)
        let onPath = VillageState()
        onPath.facing = .left
        onPath.step = 1
        onPath.setCustomers(3, leaving: false)
        onPath.pickupTile = (4, 6)
        let talking = VillageState()
        talking.setCustomers(3, leaving: false)
        talking.col = VillageBuilding.bookstore.doorCol - 2
        talking.row = 5
        talking.x = Double(talking.col)
        talking.y = 5
        talking.facing = .up
        talking.dialogue = VillageTalk.customer(1, progress: progress, now: Date(), turn: 1, leaving: false)
        func weathered(_ kind: Weather) -> WritingProgress {
            Weather.forced = kind
            defer { Weather.forced = nil }
            return WritingProgress(state: state)
        }
        let content = VStack(alignment: .leading, spacing: 16) {
            VillageView(progress: progress, state: onPath, animated: false, date: today.addingTimeInterval(14 * 3600),
                        fuel: LimitRow(name: "5시간", percent: 40, resetsAt: Date().addingTimeInterval(7200)))
            VillageView(progress: nightProgress, state: atDoor, animated: false, date: today.addingTimeInterval(22 * 3600),
                        fuel: LimitRow(name: "5시간", percent: 95, resetsAt: nil))
                .environment(\.colorScheme, .dark)
            VillageView(progress: progress, state: talking, animated: false, date: today.addingTimeInterval(14 * 3600))
            if CommandLine.arguments.contains("--weather") {
                ForEach([Weather.rain, .fog, .snow, .cloudy, .heat, .storm], id: \.self) { kind in
                    VillageView(progress: weathered(kind), state: onPath, animated: false, date: today.addingTimeInterval(14 * 3600))
                }
            }
        }
        .padding(16)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
    }

    /// `Scribe --hours out.png`: 상시 창 알약을 주요 시간대별 2열 3행 격자로 그려 하루 동안 바탕 색조와 해·달 궤적이 어떻게 바뀌는지 한눈에 보여 준다.
    static func renderHours(to path: String) {
        var state = WritingState()
        let today = Calendar.current.startOfDay(for: Date())
        state.days[DayKey.string(from: today)] = WritingRecord(tokens: 1, characters: 12_380)
        let progress = WritingProgress(state: state)
        let pairs: [(Double, Double)] = [(5.5, 8.0), (12.5, 17.5), (19.5, 23.0)]
        let content = VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 18) {
                    ForEach([pair.0, pair.1], id: \.self) { hour in
                        let date = today.addingTimeInterval(hour * 3600)
                        HStack(spacing: 8) {
                            Text(String(format: "%02d:%02d", Int(hour), Int((hour - floor(hour)) * 60)))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 38, alignment: .trailing)
                            FloatingPill(progress: progress, animated: false, dayPart: DayPart.current(date), tintDate: date)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(red: 0.78, green: 0.84, blue: 0.93), Color(red: 0.93, green: 0.86, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        write(content, to: path)
    }

    /// `Scribe --snapshot out.png`: 팝오버, 상시 창, 서재, 가방을 PNG 로 그린다. 한도 칸은 비어 있다.
    static func renderPopover(to path: String) {
        // `--no-logs` 는 기록이 하나도 없는 첫 실행 모습.
        let (entries, files, filesByProvider) = CommandLine.arguments.contains("--no-logs")
            ? ([], 0, [:])
            : ClaudeLogParser.scanAllWithProviders(since: .distantPast)
        let store = UsageStore(persist: false)
        store.show(UsageAggregator.snapshot(entries: entries, scannedFiles: files, filesByProvider: filesByProvider, source: store.agentSource))
        // 한도는 앱과 같은 방법으로 한 번 불러온다. 실패하면 빈 채로 그린다.
        if store.agentSource != .antigravity {
            nonisolated(unsafe) var limits: LimitsResult?
            let done = DispatchSemaphore(value: 0)
            Task.detached {
                limits = try? await ClaudeLimitsClient().fetch(userInitiated: false)
                done.signal()
            }
            done.wait()
            if let limits { store.show(limits) }
        }
        let content = HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                // 글래스는 ImageRenderer 가 그리지 못해 반투명 재질로 그린다.
                if let w = store.writing { FloatingPill(progress: w, animated: false).padding(12) }
                PopoverView(store: store, scrollable: false)
            }
            ShelfPanel(store: store, scrollable: false).frame(width: SidePanel.Kind.shelf.size.width)
            BagPanel(store: store, scrollable: false).frame(width: SidePanel.Kind.bag.size.width)
            UsageDashboard(store: store, scrollable: false).frame(width: SidePanel.Kind.usage.size.width)
            BadgePanel(store: store, scrollable: false).frame(width: SidePanel.Kind.badges.size.width)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
    }

    /// `Scribe --settings out.png`: 설정 다섯 탭을 나란히 그린다.
    static func renderSettings(to path: String) {
        let (entries, files, filesByProvider) = ClaudeLogParser.scanAllWithProviders(since: .distantPast)
        let store = UsageStore(persist: false)
        store.show(UsageAggregator.snapshot(entries: entries, scannedFiles: files, filesByProvider: filesByProvider, source: store.agentSource))
        let content = HStack(alignment: .top, spacing: 12) {
            GeneralSettings(store: store).frame(width: 480, height: 620).hintHost()
            FloatingSettings(store: store).frame(width: 480, height: 620).hintHost()
            WritingSettings(store: store).frame(width: 480, height: 620).hintHost()
            NotificationSettings(store: store).frame(width: 480, height: 620).hintHost()
            RecordSettings(store: store).frame(width: 480, height: 620).hintHost()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        write(content, to: path)
    }

    static func renderMarquee(to path: String) {
        let view = MarqueeText(text: "와일드가 찾아와 함께 씁니다. 3시간 동안 돌발 상황이 없습니다", size: 14, color: .primary, animated: true)
            .frame(width: 200).padding(12).background(Color(nsColor: .windowBackgroundColor))
        write(view, to: path)
    }

    /// `Scribe --tour <dir>`: README 용 개별 고해상도 UI 카드 스크린샷들을 지정된 폴더에 생성한다.
    static func renderTour(to dir: String) {
        let now = Date()
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        var state = WritingState()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        state.days[DayKey.string(from: yesterday)] = WritingRecord(tokens: 210_000_000, characters: Double(Library.starts[2]))
        state.days[DayKey.string(from: today)] = WritingRecord(tokens: 28_400_000, characters: 12_380)
        state.items = ["coffee": 2, "tea": 1, "ink": 2, "bell": 1, "muse": 1, "safe": 1]
        state.studio = ["lamp", "shelf", "cat"]
        state.deadline = Deadline(weekStart: WritingStore.weekStart(of: now), kind: .characters, target: 50_000)
        state.inspiration = Int(Double(Balance.inspirationGaugeTokens) * 0.68)
        state.boosts = [ActiveBoost(kind: .sales, value: 1.5, endsAt: now.addingTimeInterval(5 * 3600), source: "신문 소개")]

        var sheet = AuthorSheet()
        sheet.stats = ["pen": 3, "grit": 1, "charm": 2, "luck": 1]
        sheet.stamina = 76
        sheet.tokensTowardStat = 12_400_000
        state.sheets["Poe"] = sheet

        let book0 = Library.books[0]
        let book1 = Library.books[1]
        let reviewText = Critics.text(for: 5, days: 3, events: 0, lost: 0, title: book0.displayTitle, author: book0.displayAuthorShort, voice: .lofty, rolls: [0.1, 0.2, 0.3])
        var review = Review(book: book0.file, round: 0, critic: Critics.all[2].name, stars: 5, text: reviewText, date: now.addingTimeInterval(-600))
        review.published = true
        review.affected = true
        state.reviews = [review]
        state.sales = [book0.file: 12_400, book1.file: 1_850]
        state.featuredBook = book0.file
        state.featuredAt = now.addingTimeInterval(-3600)
        state.ads[book0.file] = now.addingTimeInterval(4 * 3600)
        state.order = ReaderOrder(book: Library.books[3].file, offeredAt: now, expiresAt: now.addingTimeInterval(6 * 86_400),
                                  text: ReaderOrders.text(ReaderOrders.lines, book: Library.books[3], roll: 0.1))
        state.shopBoosts = [ShopBoost(book: book0.file, value: 1.5, endsAt: now.addingTimeInterval(9 * 3600), source: "신문 소개")]
        state.shop.migrated = true
        state.shop.stock = [book0.file: 340, book1.file: 120]
        state.shop.pinned[book0.file] = now.addingTimeInterval(-3600)
        state.shop.trust = 68
        state.shopLog = [
            ShopRecord(event: "press", book: book0.file, text: "아침 신문 문화면에 햄릿이 소개됐습니다", date: now.addingTimeInterval(-3 * 3600)),
            ShopRecord(event: "school", book: book1.file, text: "학교에서 크리스마스 캐럴을 교재로 쓰겠다며 120부를 주문했습니다", date: now.addingTimeInterval(-86_400), copies: 120),
        ]
        for back in 0..<14 {
            let day = cal.date(byAdding: .day, value: -back, to: today)!
            state.salesByDay[DayKey.string(from: day)] = Double([180, 340, 210, 410, 520, 300, 180, 260, 610, 380, 150, 220, 470, 330][back])
        }
        state.eventLog = [
            EventRecord(event: "nap", book: book0.file, startedAt: now.addingTimeInterval(-3 * 3600),
                        endedAt: now.addingTimeInterval(-3 * 3600 + 4 * 60), endedBy: "coffee", pausedTokens: 600_000),
            EventRecord(event: "away", book: book0.file, startedAt: now.addingTimeInterval(-50 * 60),
                        endedAt: now.addingTimeInterval(-12 * 60), endedBy: "bell", pausedTokens: 1_200_000),
        ]
        state.equippedBadges = ["chars_100k", "first_book", "five_stars"]

        let progress = WritingProgress(state: state)

        // 샘플 토큰 스냅샷 (14일)
        let dailyTokens = [14_200_000, 18_500_000, 9_800_000, 22_100_000, 31_400_000, 16_700_000, 8_400_000,
                           19_300_000, 25_600_000, 34_200_000, 21_900_000, 15_800_000, 29_100_000, 28_400_000]
        var days: [DayUsage] = []
        for i in 0..<14 {
            let d = cal.date(byAdding: .day, value: -(13 - i), to: today)!
            let t = dailyTokens[i]
            days.append(DayUsage(day: d, tokens: t, read: Int(Double(t) * 0.92), cost: Double(t) / 1_000_000 * 0.65))
        }
        var hours = Array(repeating: 0, count: 24)
        let sampleHours: [(Int, Int)] = [(9, 1_800_000), (10, 3_400_000), (11, 2_900_000), (13, 2_100_000),
                                         (14, 4_600_000), (15, 3_800_000), (16, 5_200_000), (17, 2_700_000), (20, 1_900_000)]
        for (h, v) in sampleHours { hours[h] = v }

        let models = [
            ModelUsage(model: "gemini-2.5-pro", tokens: 19_800_000, input: 2_100_000, output: 950_000, cacheWrite: 0, cacheRead: 16_750_000, cost: 12.40),
            ModelUsage(model: "gemini-2.5-flash", tokens: 8_600_000, input: 1_200_000, output: 600_000, cacheWrite: 0, cacheRead: 6_800_000, cost: 6.06),
        ]
        let snapshot = UsageSnapshot(
            source: .antigravity,
            days: days,
            todayByModel: models,
            todayByHour: hours,
            twoWeekByHour: hours.map { $0 * 9 },
            recentFiveHourTokens: 16_300_000,
            todayTurns: 92,
            todayPeakTurnTokens: 640_000,
            todayCacheSavedCost: 24.80,
            twoWeekCacheSavedCost: 268.40,
            todayByProvider: [.antigravity: 28_400_000, .claude: 14_200_000],
            todayCostByProvider: [.antigravity: 18.46, .claude: 9.80],
            filesByProvider: [.antigravity: 18, .claude: 12],
            scannedFiles: 18,
            generatedAt: now
        )

        let store = UsageStore(persist: false)
        store.showSample(snapshot: snapshot, writing: progress, source: .antigravity)

        // 1. 홈 팝오버 + 데스크톱 알약
        let homeView = VStack(spacing: 12) {
            FloatingPill(progress: progress, animated: false)
            PopoverView(store: store, scrollable: false)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        }
        .padding(16)
        write(homeView, to: "\(dir)/screenshot-home.png")

        // 2. 서재 패널
        let shelfView = ShelfPanel(store: store, scrollable: false)
            .frame(width: SidePanel.Kind.shelf.size.width)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(shelfView, to: "\(dir)/screenshot-shelf.png")

        // 3. 동네 서점 카드
        let bookstoreView = BookstoreContent(progress: progress, scrollable: false)
            .frame(width: 420)
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(bookstoreView, to: "\(dir)/screenshot-bookstore.png")

        // 4. 작업실 & 가방 패널
        let bagView = BagContent(progress: progress, scrollable: false)
            .frame(width: SidePanel.Kind.bag.size.width)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(bagView, to: "\(dir)/screenshot-bag.png")

        // 5. 토큰 사용량 대시보드
        let usageView = UsageDashboard(store: store, scrollable: false)
            .frame(width: SidePanel.Kind.usage.size.width)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(usageView, to: "\(dir)/screenshot-usage.png")

        // 6. 성과 패널
        let badgesView = BadgePanel(store: store, scrollable: false)
            .frame(width: SidePanel.Kind.badges.size.width)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .padding(12)
        write(badgesView, to: "\(dir)/screenshot-badges.png")

        // 7. 문호 초상화 & 돌발 상황 & 장신구 컬렉션 카드
        let portraitsView = VStack(alignment: .leading, spacing: 12) {
            Text("대문호 초상화").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Portraits.all, id: \.0) { author, _ in
                    PortraitFrame(author: author, scale: 3)
                }
            }
            Text("돌발 상황 표정").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Array((AuthorEvents.common + [AuthorEvents.dark]).prefix(6)), id: \.id) { event in
                    PortraitFrame(author: "Shakespeare", scale: 3, event: event)
                }
                PortraitFrame(author: "Poe", scale: 3, event: AuthorEvents.byAuthor["Poe"])
                PortraitFrame(author: "Stevenson", scale: 3, event: AuthorEvents.byAuthor["Stevenson"])
            }
            Text("수집 가능한 장신구").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(Decor.all) { accessory in
                    PixelFrame(rows: Decor.apply(Portraits.rows("Wilde"), accessory: accessory), scale: 42 / CGFloat(Portraits.size), palette: Portraits.palette)
                        .frame(width: 42, height: 42)
                        .background(Portraits.backdrop("Wilde"))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(width: 472, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .padding(12)
        write(portraitsView, to: "\(dir)/screenshot-portraits.png")

        // 8. 바탕화면 상시 창 (라이트 / 다크 알약 & 미니)
        var napState = state
        napState.event = ActiveEvent(id: AuthorEvents.nap.id, startedAt: now, endsAt: now.addingTimeInterval(23 * 60))
        let napProgress = WritingProgress(state: napState)
        let floatingCard = VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                FloatingPill(progress: progress, animated: false)
                FloatingPill(progress: napProgress, animated: false)
                HStack(spacing: 12) {
                    FloatingMini(progress: progress, animated: false)
                    FloatingMini(progress: napProgress, animated: false)
                    FloatingMini(progress: progress, featured: "Goethe", animated: false)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.78, green: 0.84, blue: 0.93), Color(red: 0.93, green: 0.86, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .environment(\.colorScheme, .light)

            VStack(alignment: .leading, spacing: 12) {
                FloatingPill(progress: progress, featured: "Goethe", animated: false)
                HStack(spacing: 12) {
                    FloatingMini(progress: progress, animated: false)
                    FloatingMini(progress: napProgress, animated: false)
                    FloatingMini(progress: progress, featured: "Goethe", animated: false)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.26, green: 0.16, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .environment(\.colorScheme, .dark)
        }
        .frame(width: 420)
        .padding(12)
        write(floatingCard, to: "\(dir)/screenshot-floating.png")
    }

    private static func write(_ view: some View, to path: String) {
        RenderMode.offscreen = true
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return print("render failed") }
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        try? png?.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}
