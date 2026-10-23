import SwiftUI

// MARK: - 타자기처럼 나타나는 원고

/// 원고의 끝부분. 실제 글자 수는 1분마다 한꺼번에 늘어나니, 보이는 글자가 4초쯤에 걸쳐 따라가게 한다.
struct ManuscriptText: View {
    let book: Book
    let target: Int
    var tail = 700
    var fontSize: CGFloat = 11
    /// 작가가 다른 일을 하는 동안은 보이는 원고를 멈춘다. 끝나면 밀린 글자를 따라잡는다.
    var paused = false
    /// 지금 쓰는 문장만 한 줄로. 길면 앞을 줄여 끝(커서)이 늘 보이게 한다.
    var singleLine = false
    var color: Color = .primary
    /// 타자 빠르기 배수. 카페인이 돌면 빨라진다.
    var tempo = 1.0

    @State private var base = 0
    @State private var baseDate = Date()
    @State private var speed = 40.0

    var body: some View {
        Group {
            if singleLine { line } else { page }
        }
        .onAppear { restart(from: max(0, target - 120)) }
        .onChange(of: target) { restart(from: shownCount(at: Date())) }
        .onChange(of: book.id) { restart(from: max(0, target - 120)) }
        .onChange(of: paused) {
            if paused {
                base = shownCount(at: Date())
                speed = 0
            } else {
                restart(from: base)
            }
        }
    }

    private func cursor(_ now: Date) -> Text {
        let blink = Int(now.timeIntervalSinceReferenceDate * 2) % 2 == 0
        return Text("▍").foregroundColor(color.opacity(blink ? 0.9 : 0.15))
    }

    /// 한 줄: 마지막 문장 끝(. ? ! 줄바꿈) 뒤부터. 막 문장을 끝냈으면 그 문장을 보여 준다.
    private var line: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            let now = context.date
            (Text(Self.currentSentence(Library.tail(of: book, upTo: shownCount(at: now), length: 200))) + cursor(now))
                .font(.system(size: fontSize, design: .serif).italic())
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.head)
        }
    }

    static func currentSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let enders: Set<Character> = [".", "?", "!", "\n", ";"]
        var body = Substring(trimmed)
        if let last = body.last, enders.contains(last) { body = body.dropLast() }
        if let cut = body.lastIndex(where: { enders.contains($0) }) {
            return String(trimmed[trimmed.index(after: cut)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private var page: some View {
        // 크기를 고정한 틀 안에서 아래에 붙이고 위로 넘친 부분을 잘라 낸다.
        // 유연한 틀(maxHeight: .infinity)은 글이 길면 틀째로 커져 원고지를 벗어난다.
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                let now = context.date
                // 방금 써진 글자는 잉크가 마르듯 연했다가 진해진다(0.6초 분량).
                let text = Library.tail(of: book, upTo: shownCount(at: now), length: tail)
                let freshCount = paused ? 0 : min(text.count, Int(speed * 0.6))
                let split = text.index(text.endIndex, offsetBy: -freshCount)
                (Text(String(text[..<split])) + Text(String(text[split...])).foregroundColor(color.opacity(0.45)) + cursor(now))
                    .font(.system(size: fontSize, design: .serif))
                    .foregroundStyle(color)
                    .lineSpacing(fontSize * 0.25)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private func shownCount(at date: Date) -> Int {
        guard !paused else { return min(target, base) }
        return min(target, base + Int(date.timeIntervalSince(baseDate) * speed))
    }

    private func restart(from count: Int) {
        base = min(count, target)
        baseDate = Date()
        speed = paused ? 0 : max(30 * tempo, Double(target - base) / 4 * tempo)
    }
}


// MARK: - 팝오버

/// 집필 화면. 초상화와 제목, 원고 끝부분, 진행, 한 줄 요약.
struct WritingView: View {
    let progress: WritingProgress
    @Environment(\.colorScheme) private var scheme
    var onUse: @MainActor (ItemKind) -> Void = { _ in }
    var onBag: @MainActor () -> Void = {}
    var onBadges: @MainActor () -> Void = {}
    var onDismissFinish: @MainActor (String) -> Void = { _ in }
    var onDismissWeekly: @MainActor () -> Void = {}
    /// 방해 금지 동안 모아 둔 소식.
    var heldNews: [String] = []
    /// 선택지가 있는 사건에 답한다.
    var onChoose: @MainActor (Int) -> Void = { _ in }
    /// 손님 작가와의 마지막 말다툼.
    var quarrel: (host: String, guest: String, date: Date)? = nil
    /// 마지막 작가 교대.
    var handoff: (from: String, to: String, leaving: String, arriving: String, date: Date)? = nil
    var onBookstore: @MainActor () -> Void = {}
    /// 영감 게이지가 찼을 때 영감의 날을 켠다.
    var onIgnite: @MainActor () -> Void = {}
    /// 탈고한 원고를 보낼 출판사, 손님 작가의 내기.
    var onChoosePublisher: @MainActor (Publisher, String) -> Void = { _, _ in }
    var onAnswerBet: @MainActor (Bool) -> Void = { _ in }
    /// 마을 맵을 연다.
    var onVillage: @MainActor () -> Void = {}
    let onShelf: @MainActor () -> Void
    /// 아래쪽 상태(영감·체력·능력치·보정)를 펼쳐 두는지. 기본은 한 줄 요약.
    @AppStorage("writingStatusExpanded") private var statusExpanded = false

    var body: some View {
        if let book = progress.book {
            content(book, event: progress.event)
        } else {
            Text("원문 폴더를 찾지 못했습니다.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func content(_ book: Book, event: AuthorEvent?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header(book, event: event)
            Group {
                if let event, let active = progress.activeEvent {
                    EventBanner(event: event, active: active, cause: progress.cause, item: progress.cureItem,
                                count: progress.cureCount, tint: book.spineColor) { if let item = progress.cureItem { onUse(item) } }
                }
                if let luck = progress.luck, let kind = progress.luckEvent {
                    LuckBanner(luck: luck, kind: kind)
                }
                if let bet = progress.bet, bet.pending || bet.running {
                    BetBanner(bet: bet, written: bet.startCharacters.map { progress.totalCharacters - $0 } ?? 0, onAnswer: onAnswerBet)
                }
                if let active = progress.dilemma, let kind = progress.dilemmaKind {
                    DilemmaBanner(active: active, kind: kind, tint: book.spineColor, onChoose: onChoose)
                }
                if let note = progress.recentNote(within: 180), let icon = note.icon {
                    NoteLine(icon: icon, color: note.kind == .refused ? .orange : note.kind == .luck ? BadgeTier.gold.color : book.spineColor,
                             text: note.text, at: note.date)
                }
            }
            // 배너는 위에서 짧게 내려오고, 끝나면 접힌다.
            .transition(.move(edge: .top).combined(with: .opacity))
            if let quarrel, let guest = progress.guestAuthor, Date().timeIntervalSince(quarrel.date) < 900 {
                QuarrelLines(host: book.authorShort, guest: guest, hostLine: quarrel.host, guestLine: quarrel.guest)
            }
            if let handoff, handoff.to == book.authorShort, Date().timeIntervalSince(handoff.date) < 900 {
                QuarrelLines(host: handoff.from, guest: handoff.to, hostLine: handoff.leaving, guestLine: handoff.arriving, title: "작가 교대")
            }
            if let recent = progress.recentDisaster(within: 3600), let disaster = Disasters.byID(recent.event),
               let lost = recent.lostCharacters {
                DisasterNote(disaster: disaster, lost: lost, at: recent.startedAt, shield: recent.endedBy.flatMap(ItemKind.init(rawValue:)))
            }
            if !heldNews.isEmpty {
                HStack(spacing: 8) {
                    Symbol(name: "moon.zzz", size: 12)
                    Text("방해 금지 · 소식 \(heldNews.count)건").font(.caption)
                    Spacer(minLength: 0)
                    Text(QuietHours.description).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .hint("방해 금지 동안 모아 둔 소식", Array(heldNews.prefix(6)) + (heldNews.count > 6 ? ["… \(heldNews.count - 6)건 더"] : []), symbol: "moon.zzz")
            }
            ForEach(progress.finishCards) { note in
                if let done = Library.books.first(where: { $0.file == note.book }) {
                    FinishCard(note: note, book: done, onChoose: { onChoosePublisher($0, note.id) }) { onDismissFinish(note.id) }
                }
            }
            if let weekly = progress.weeklyCard {
                WeeklyCard(review: weekly, onDismiss: onDismissWeekly)
            }
            Group {
                if progress.charactersInBook == 0 {
                    // 첫 토큰이 들어오기 전. 빈 칸에 커서만 깜빡이면 고장 난 것처럼 보인다.
                    Text("첫 문장을 기다리는 중입니다.\n토큰을 쓰면 원문이 한 글자씩 써집니다.")
                        .font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ManuscriptText(book: book, target: progress.charactersInBook, tail: 420, fontSize: 12,
                                   paused: event != nil, tempo: progress.caffeinated ? Balance.caffeineTempo : 1)
                        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.25)],
                                             startPoint: .top, endPoint: .bottom))
                }
            }
            .padding(12)
            .frame(height: 140)
            // 원고지: 옅은 크림색 종이와 가장자리 그늘. 어두운 모드에서는 어두운 종이.
            .background(scheme == .dark ? Color(red: 0.14, green: 0.13, blue: 0.12) : Color(red: 0.985, green: 0.975, blue: 0.94),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(scheme == .dark ? 0.1 : 0.07)))
            .shadow(color: .black.opacity(scheme == .dark ? 0.25 : 0.06), radius: 2, y: 1)
            .opacity(event == nil ? 1 : 0.55)
            progressBar(book)
            if let deadline = progress.deadline {
                DeadlineRow(deadline: deadline, progress: progress.deadlineProgress, bookFraction: progress.fraction)
            }
            let expanded = RenderMode.offscreen ? (statusExpanded || progress.inspirationReady) : statusExpanded
            VStack(alignment: .leading, spacing: 0) {
                statusLine(book, expanded: expanded)
                Collapsible(progress: expanded ? 1 : 0, topSpacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            InspirationRow(fraction: progress.inspirationFraction, ready: progress.inspirationReady, onIgnite: onIgnite)
                            StaminaRow(stamina: progress.sheet.stamina, max: progress.statPerks.staminaMax, tired: progress.tired)
                        }
                        StatsRow(sheet: progress.sheet, tokensToNext: progress.tokensToNextStat, authorName: book.displayAuthorShort)
                        if !progress.boosts.isEmpty {
                            FlowLayout(spacing: 4) {
                                ForEach(progress.boosts) { boost in BoostChip(boost: boost) }
                            }
                        }
                    }
                }
            }
            footer
        }
        .onChange(of: progress.inspirationReady) { old, ready in
            if !old && ready { statusExpanded = true }
        }
        .animation(.easeOut(duration: 0.28), value: progress.activeEvent?.id)
        .animation(.easeOut(duration: 0.28), value: progress.dilemma?.id)
        .animation(.easeOut(duration: 0.28), value: progress.luck?.id)
        .animation(.easeOut(duration: 0.28), value: progress.note?.date)
        .animation(.easeOut(duration: 0.28), value: progress.boosts.count)
        .animation(.snappy(duration: 0.26, extraBounce: 0), value: statusExpanded)
    }

    /// 아래쪽 상태 한 줄. 영감·체력·능력치·보정을 요약하고, 누르면 펼치거나 접는다. 손댈 일이 있는 항목(영감 찼음, 지침)은 색이 붙는다.
    private func statusLine(_ book: Book, expanded: Bool) -> some View {
        let gold = BadgeTier.gold.color
        let heart: Color = progress.sheet.stamina <= progress.statPerks.staminaMax * 0.1 ? .red : progress.tired ? .orange : .secondary
        let boosts = progress.boosts.count
        return Button { statusExpanded.toggle() } label: {
            HStack(spacing: 10) {
                statusItem("sparkles", progress.inspirationReady ? "영감 찼음" : "영감 \(Format.percent(progress.inspirationFraction * 100))", progress.inspirationReady ? gold : .secondary)
                statusItem(progress.tired ? "heart.slash" : "heart", "체력 \(Int(progress.sheet.stamina.rounded()))", heart)
                statusItem("person", "능력치 \(progress.sheet.total)", .secondary)
                if boosts > 0 { statusItem("arrow.up.right", "보정 \(boosts)", Color(red: 0.2, green: 0.55, blue: 0.3)) }
                Spacer(minLength: 0)
                Symbol(name: "chevron.down", size: 9)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusItem(_ symbol: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Symbol(name: symbol, size: 10, color: color)
            Text(text).font(.caption2.monospacedDigit()).foregroundStyle(color == .secondary ? Color.secondary : color)
        }
        .fixedSize()
    }

    private func header(_ book: Book, event: AuthorEvent?) -> some View {
        HStack(spacing: 12) {
            PortraitFrame(author: book.authorShort, scale: 2.75, event: event, expression: progress.expression, scene: true, furniture: progress.studio)
                .animation(.easeInOut(duration: 0.4), value: event)
                .overlay(alignment: .bottomTrailing) {
                    // 손님 작가는 초상화 모서리에 작게.
                    if let guest = progress.guestAuthor {
                        PortraitFrame(author: guest, scale: 1.25)
                            .overlay(RoundedRectangle(cornerRadius: 20 * 0.22, style: .continuous).stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                            .offset(x: 6, y: 6)
                            .hint("손님 작가", ["\(Library.books.first { $0.authorShort == guest }?.displayAuthor ?? guest)가 와서 함께 씁니다.", "머무는 동안 돌발 상황이 없고 책이 두 배로 팔립니다."], symbol: "person.2")
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(book.displayTitle).font(.headline).lineLimit(1)
                Text(book.displayAuthor).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if event == nil { AuthorStatusLine(event: nil).fixedSize() }
                    HStack(spacing: 3) {
                        Symbol(name: progress.weather.symbol, size: 11)
                        Text(progress.weather.title).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .fixedSize()
                    .hint("오늘 날씨 · \(progress.weather.title)", [progress.weather.line + "."] + (progress.weather.effectText.map { ["효과: \($0)"] } ?? ["효과는 없습니다."]),
                          symbol: progress.weather.symbol)
                    if progress.cupsToday > 0 {
                        HStack(spacing: 3) {
                            Symbol(name: "cup.and.saucer", size: 11, color: progress.caffeinated ? .orange : .secondary)
                            Text("\(progress.cupsToday)잔").font(.system(size: 11)).foregroundStyle(progress.caffeinated ? Color.orange : Color.secondary)
                        }
                        .fixedSize()
                        .hint(progress.caffeinated ? "카페인 · 손이 떨립니다" : "오늘 커피·홍차 \(progress.cupsToday)잔",
                              progress.caffeinated
                              ? ["오늘 \(progress.cupsToday)잔째입니다. 타자가 빨라지고 손이 떨립니다.", "오늘은 졸지 않는 대신 글이 막히고, 내일은 졸음이 더 옵니다."]
                              : ["하루 \(Balance.caffeineCups)잔을 넘기면 손이 떨리고 타자가 빨라집니다.", "그날은 졸음이 안 오고 다음 날 졸음 확률이 \(Int(Balance.hangoverNapChance * 100))%p 오릅니다."],
                              symbol: "cup.and.saucer")
                    }
                }
            }
            Spacer(minLength: 6)
            // 작은 고리 둘: 체력(붉은색), 영감(금색). 접어 두어도 한눈에.
            VStack(spacing: 6) {
                MiniRing(fraction: progress.sheet.stamina / max(1, progress.statPerks.staminaMax),
                         color: progress.tired ? .orange : Color(red: 0.85, green: 0.35, blue: 0.4), symbol: "heart.fill")
                    .hint("체력 \(Int(progress.sheet.stamina.rounded())) / \(Int(progress.statPerks.staminaMax))",
                          [progress.tired ? "지쳤습니다. 글자가 \(Int((1 - Balance.staminaTiredMultiplier) * 100))% 덜 늘고 0이 되면 탈진합니다." : "쓰면 줄고 쉬면 돌아옵니다."], symbol: "heart")
                MiniRing(fraction: progress.inspirationFraction, color: BadgeTier.gold.color, symbol: "sparkles")
                    .hint("영감 \(Format.percent(progress.inspirationFraction * 100))",
                          [progress.inspirationReady ? "찼습니다. 아래 \"영감 켜기\"를 누르세요." : "읽기 토큰이 쌓이면 찹니다. 차면 한 시간 동안 글자가 두 배."], symbol: "sparkles")
            }
            Text(Format.percent(progress.fraction * 100))
                .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(book.spineColor)
                .lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.5), value: progress.fraction)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        // 작가 색이 머리에 옅게 깔린다. 작가가 바뀌면 색도 천천히 바뀐다.
        .background(
            LinearGradient(colors: [book.spineColor.opacity(scheme == .dark ? 0.22 : 0.13), book.spineColor.opacity(0.02)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeInOut(duration: 0.6), value: book.id)
    }

    private func progressBar(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(book.spineColor)
                        .frame(width: max(4, geo.size.width * CGFloat(min(max(progress.fraction, 0), 1))))
                        .animation(.easeOut(duration: 0.6), value: progress.fraction)
                }
            }
            .frame(height: 4)
            HStack(spacing: 6) {
                Text("\(Format.integer(progress.charactersInBook)) / \(Format.integer(book.characters))자")
                if progress.todayCharacters > 0 {
                    Text("· 오늘 +\(Format.integer(Int(progress.todayCharacters)))")
                        .foregroundStyle(book.spineColor)
                }
                Spacer()
                if let days = progress.daysToFinish { Text("탈고까지 약 \(days)일") }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    /// 가방·성과·서재로 가는 버튼 셋. 숫자는 하나씩만(아이템 수, 받은 뱃지, 이번 회차 탈고).
    private var footer: some View {
        let items = ItemKind.allCases.reduce(0) { $0 + progress.count($1) }
        let earned = Achievements.all.filter { !$0.daily && (progress.badges[$0.id] != nil || $0.isMet(progress.facts)) }.count
        return HStack(spacing: 6) {
            Button(action: onVillage) {
                Symbol(name: "map", size: 12)
                    .frame(width: 34)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .hint("마을", ["작업실, 창고, 서점, 살롱이 있는 작은 맵입니다."], symbol: "map")
            footerButton(symbol: "shippingbox", title: "창고", detail: "\(items)", action: onBag)
            footerButton(symbol: "rosette", title: "성과", detail: "\(earned)", action: onBadges)
            footerButton(symbol: "books.vertical", title: "서재", detail: "\(progress.finishedInRound)/\(Library.books.count)", action: onShelf)
            footerButton(symbol: "storefront", title: "서점", detail: Format.short(progress.totalSales), action: onBookstore)
        }
    }

    private func footerButton(symbol: String, title: String, detail: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Symbol(name: symbol, size: 11)
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.system(size: 9).monospacedDigit()).foregroundStyle(.secondary)
            }
            .lineLimit(1).minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension EventNote {
    /// 한 줄 앞에 그릴 아이콘. 돌발 상황·행운·사건·비평.
    var icon: [String]? {
        switch kind {
        case .returned, .cured, .refused: AuthorEvents.byID(event)?.icon
        case .luck: Lucks.byID(event)?.icon
        case .dilemma: PixelIcon.letter
        case .review: PixelIcon.page
        case .deadline: PixelIcon.bell
        case .bet: PixelIcon.coin
        case .publisher, .order: PixelIcon.letter
        case .shop: PixelIcon.bag
        case .stat: PixelIcon.quill
        }
    }
}

/// 선택지가 있는 사건. 무슨 일인지, 언제까지 답해야 하는지, 선택지 버튼들.
struct DilemmaBanner: View {
    let active: ActiveDilemma
    let kind: Dilemma
    let tint: Color
    let onChoose: @MainActor (Int) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let minutes = max(1, Int(ceil(active.expiresAt.timeIntervalSince(context.date) / 60)))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Symbol(name: "envelope", size: 16, color: tint).padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title).font(.callout.weight(.semibold))
                        Text(active.text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text((minutes >= 60 ? "\(minutes / 60)시간" + (minutes % 60 > 0 ? " \(minutes % 60)분" : "") : "\(minutes)분") + " 안에 답이 없으면 작가가 알아서 고릅니다")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                FlowLayout(spacing: 6) {
                    ForEach(Array(kind.options.enumerated()), id: \.offset) { i, option in
                        Button { onChoose(i) } label: {
                            Text(option.label).font(.caption.weight(.semibold))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .foregroundStyle(Color.white)
                                .background(tint, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .hint(option.label, Self.effects(option), symbol: "arrow.turn.down.right")
                    }
                }
            }
        }
        .padding(12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 선택지에 붙는 효과를 줄마다. 숫자는 보여 주되 결과 문장은 고르기 전엔 모른다.
    private static func effects(_ option: DilemmaOption) -> [String] {
        var parts = option.boosts.map { kind, value, seconds -> String in
            let hours = Int(seconds / 3600)
            let probe = ActiveBoost(kind: kind, value: value, endsAt: Date(), source: "")
            return "\(probe.text), \(hours)시간 동안"
        }
        if option.items > 0 { parts.append("아이템 \(option.items)개를 받습니다") }
        if option.items < 0 { parts.append("아이템 \(-option.items)개가 나갑니다") }
        if parts.isEmpty { parts.append("숫자 효과는 없습니다.") }
        parts.append("결과 문장은 골라 봐야 압니다.")
        return parts
    }
}

/// 이번 주 마감. 과제, 진행 막대, 남은 날. 지켰으면 표시.
struct DeadlineRow: View {
    let deadline: Deadline
    let progress: Int
    /// 탈고 과제는 지금 책의 진행을 막대로 쓴다.
    var bookFraction = 0.0

    var body: some View {
        let fraction = deadline.met == true ? 1 : deadline.kind == .finish ? bookFraction : min(1, Double(progress) / Double(max(1, deadline.target)))
        let sunday = Calendar.current.date(byAdding: .day, value: 6, to: deadline.weekStart) ?? deadline.weekStart
        let daysLeft = max(0, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: sunday).day ?? 0))
        let met = deadline.met == true
        let color: Color = met ? Color(red: 0.2, green: 0.55, blue: 0.3) : .secondary
        HStack(spacing: 6) {
            Symbol(name: met ? "checkmark.circle" : "calendar", size: 11, color: color)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    // 지킨 뒤에는 과거형으로. "마감 지킴 · 크리스마스 캐럴 탈고"처럼 무엇을 했는지 적는다.
                    Text(met ? "마감 지킴" : "마감").font(.caption2.weight(.semibold)).foregroundStyle(met ? color : .primary)
                    Text(deadline.title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(met ? (deadline.metAt.map { $0.formatted(.dateTime.weekday(.abbreviated)) } ?? "")
                         : deadline.kind == .finish ? (daysLeft == 0 ? "오늘까지" : "\(daysLeft)일 남음")
                         : "\(Format.short(progress)) / \(Format.short(deadline.target))")
                        .font(.caption2.monospacedDigit()).foregroundStyle(color)
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    GeometryReader { geo in Capsule().fill(color).frame(width: max(3, geo.size.width * fraction)) }
                }
                .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .hint(met ? "이번 주 마감을 지켰습니다" : "이번 주 마감 · \(deadline.title)",
              met ? ["월요일에 받은 과제 「\(deadline.title)」을 \(deadline.metAt.map { $0.formatted(.dateTime.weekday(.wide)) } ?? "")에 끝냈습니다.",
                     "아이템 \(Balance.deadlineItems)개와 판매 +\(Int((Balance.deadlineSalesBoost - 1) * 100))%(하루)를 받았습니다. 다음 과제는 월요일에 옵니다. 이 줄은 하루 뒤 사라집니다."]
              : [deadline.letter + ".",
                 "일요일까지입니다. 지키면 아이템 \(Balance.deadlineItems)개와 판매 +\(Int((Balance.deadlineSalesBoost - 1) * 100))%(하루).",
                 "어기면 거절 확률이 \(Balance.deadlinePenaltyHours / 24)일 동안 \(Int(Balance.deadlinePenalty * 100))%p 오릅니다."],
              symbol: met ? "checkmark.circle" : "calendar")
    }
}

/// 영감 게이지. 읽기(입력·캐시) 토큰으로 차고, 가득 차면 버튼이 되어 영감의 날을 켠다.
struct InspirationRow: View {
    let fraction: Double
    let ready: Bool
    let onIgnite: @MainActor () -> Void

    var body: some View {
        let gold = BadgeTier.gold.color
        Group {
            if ready {
                Button(action: onIgnite) {
                    HStack(spacing: 4) {
                        Symbol(name: "sparkles", size: 11, color: .white)
                        Text("영감 켜기").font(.caption2.weight(.semibold))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .background(gold, in: Capsule())
                }
                .buttonStyle(.plain)
                .hint("영감 게이지가 찼습니다", ["누르면 \(Balance.inspirationMinutes)분 동안 글자가 \(Int(Balance.inspirationMultiplier))배로 늘어납니다.", "행운이 진행 중이면 끝난 뒤에 켤 수 있습니다."], symbol: "sparkles")
            } else {
                HStack(spacing: 5) {
                    Symbol(name: "sparkles", size: 11, color: gold.opacity(0.9))
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.12))
                        GeometryReader { geo in Capsule().fill(gold).frame(width: max(2, geo.size.width * fraction)) }
                    }
                    .frame(width: 36, height: 3)
                    Text(Format.percent(fraction * 100)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .hint("영감 게이지 · \(Format.percent(fraction * 100))", ["입력·캐시 토큰을 작가가 읽는 양으로 쳐서 쌓입니다.", "\(Format.tokens(Balance.inspirationGaugeTokens))개가 차면 영감의 날(\(Balance.inspirationMinutes)분, 글자 \(Int(Balance.inspirationMultiplier))배)을 직접 켤 수 있습니다."], symbol: "sparkles")
            }
        }
        .fixedSize()
    }
}

/// 손님 작가와의 말다툼. 주인과 손님이 한 마디씩.
struct QuarrelLines: View {
    let host: String
    let guest: String
    let hostLine: String
    let guestLine: String
    /// "말다툼"이거나 "작가 교대".
    var title = "말다툼"

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            line(host, hostLine)
            line(guest, guestLine)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func line(_ author: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            PortraitFrame(author: author, scale: 1)
            Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 돌발 상황 안내. 무슨 일인지, 언제 저절로 끝나는지, 아이템 쓰기 버튼 하나.
struct EventBanner: View {
    let event: AuthorEvent
    let active: ActiveEvent
    var cause: String?
    /// 쓸 아이템. 없으면 nil.
    var item: ItemKind?
    let count: Int
    let tint: Color
    let onUse: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let now = context.date
            let minutes = max(1, Int(ceil(active.endsAt.timeIntervalSince(now) / 60)))
            let refused = active.refusedUntil.flatMap { $0 > now ? $0 : nil }
            let wait = refused.map { max(1, Int(ceil($0.timeIntervalSince(now) / 60))) }
            HStack(spacing: 10) {
                PixelIconView(rows: event.icon, color: tint, scale: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.text).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.85)
                    if let cause {
                        Text(cause).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Text("집필 멈춤 · \(minutes)분 뒤 재개" + (wait.map { " · 아이템은 \($0)분 뒤" } ?? ""))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: 4)
                let usable = count > 0 && wait == nil
                let shown = item ?? event.cure
                Button(action: onUse) {
                    HStack(spacing: 4) {
                        PixelIconView(rows: shown.icon, color: usable ? .white : .secondary, scale: 1.1)
                        Text(count == 0 ? "\(event.cure.role.title) 없음" : wait.map { "\($0)분 뒤" } ?? "\(shown.shortTitle) ×\(count)")
                    }
                    .font(.caption.weight(.semibold))
                    .fixedSize()
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .foregroundStyle(usable ? Color.white : Color.secondary)
                    .background(usable ? tint : Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!usable)
                .hint(count == 0 ? "\(event.cure.role.title) 아이템이 없습니다" : wait != nil ? "방금 거절당했습니다" : "\(shown.title) 권하기",
                      count == 0 ? ["토큰 \(Format.tokens(Balance.tokensPerItem))개마다 아이템이 하나 나옵니다.", "없으면 \(minutes)분 뒤 저절로 돌아옵니다."]
                      : wait != nil ? ["\(wait ?? 0)분 뒤에 다시 권할 수 있습니다.", "거절당할수록 다음엔 덜 거절합니다."]
                      : ["권하면 바로 다시 씁니다. \(Int(Balance.refusalChance * 100))%쯤은 거절합니다.", "같은 역할의 다른 아이템도 통합니다."],
                      symbol: "hand.raised")
            }
        }
        .padding(12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - 옆 패널 서재

/// 높이를 0에서 원래 크기까지 연속 보간해 페이드인·아웃 없이 서랍처럼 자연스럽게 펼치고 접는 틀.
/// 부모 `VStack`의 간격까지 함께 접히도록 위쪽 여백(`topSpacing`)을 안쪽에 넣어 클리핑한다.
struct Collapsible<Content: View>: View, Animatable {
    nonisolated var progress: CGFloat
    var topSpacing: CGFloat = 0
    @ViewBuilder let content: () -> Content
    @State private var measuredHeight: CGFloat = 0

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        if RenderMode.offscreen {
            if clamped > 0.001 {
                content().padding(.top, topSpacing)
            }
        } else {
            let currentHeight: CGFloat? = measuredHeight > 0 ? measuredHeight * clamped : (clamped > 0.001 ? nil : 0)
            content()
                .padding(.top, topSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                    if h > 0, abs(measuredHeight - h) > 0.5 {
                        measuredHeight = h
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: currentHeight, alignment: .bottom)
                .clipped()
                .allowsHitTesting(clamped > 0.5)
                .accessibilityHidden(clamped < 0.5)
        }
    }
}

/// `enabled` 일 때만 `ScrollView` 로 감싼다.
struct OptionalScroll<Content: View>: View {
    let enabled: Bool
    @ViewBuilder let content: Content

    var body: some View {
        if enabled { ScrollView { content } } else { content }
    }
}

/// 서재. 위에 탈고·판매 요약과 고른 작품 칸, 탈고한 책이 있으면 많이 팔린 순서의 진열대,
/// 아래에 작가마다 한 줄(초상화, 이름, 탈고 수와 부수, 책등). 책등을 누르면 위 칸에 그 작품이 나온다.
struct ShelfPanel: View {
    @Bindable var store: UsageStore
    /// 확인용 그림(`--snapshot`)은 `ScrollView` 를 못 그려서 끈다.
    var scrollable = true

    @State private var selected: Int?

    var body: some View {
        if let progress = store.writing {
            OptionalScroll(enabled: scrollable) {
                VStack(alignment: .leading, spacing: 16) {
                    header(progress)
                    BookDetail(index: selected ?? progress.bookIndex, progress: progress,
                               onWriteNext: store.writeNext, onFocusAuthor: store.focusAuthor,
                               onRead: { book, count in
                                   ReaderWindow.shared.show(book: book, count: count)
                                   store.noteRead()
                               })
                    if progress.totalSales > 0 {
                        Showcase(progress: progress, selected: selected ?? progress.bookIndex) { selected = $0 }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Library.authors, id: \.self) { author in
                            AuthorRow(author: author, progress: progress, selected: selected ?? progress.bookIndex) { selected = $0 }
                        }
                    }
                }
                .padding(16)
                .animation(.easeOut(duration: 0.18), value: selected)
            }
        } else {
            ProgressView()
        }
    }

    /// 제목과 회차, 탈고 수, 모두 팔린 부수.
    private func header(_ progress: WritingProgress) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("서재").font(.headline)
            Text("\(progress.round + 1)회차").font(.caption).foregroundStyle(.secondary)
            Spacer()
            stat("\(progress.finishedInRound)/\(Library.books.count)", "탈고")
            stat(Format.integer(progress.totalSales), "부")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value).font(.callout.weight(.semibold).monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// 진열대: 탈고한 책을 많이 팔린 순서로. 책등이 크고 아래에 부수와 단계.
struct Showcase: View {
    let progress: WritingProgress
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        let done = Set(progress.finished.map(\.bookIndex))
        let ranked = done.sorted { progress.sales(of: Library.books[$0]) > progress.sales(of: Library.books[$1]) }.prefix(6)
        VStack(alignment: .leading, spacing: 8) {
            Text("진열대").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                ForEach(Array(ranked), id: \.self) { index in
                    let book = Library.books[index]
                    let tier = progress.salesTier(of: book)
                    VStack(spacing: 4) {
                        Spine(book: book, status: .done(.now), selected: index == selected, height: 44, tier: tier)
                            .onTapGesture { onSelect(index) }
                        Text(book.displayTitle).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(Format.integer(progress.sales(of: book)) + "부").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        if tier != .none {
                            Text(tier.title).font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(tier >= .bestseller ? BadgeTier.gold.color : tier == .reprint ? BadgeTier.silver.color : .secondary)
                        }
                    }
                    .frame(width: 64)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// 책 한 권의 상태.
enum BookStatus {
    case done(Date), current(Double), pending

    @MainActor
    init(index: Int, progress: WritingProgress) {
        if let done = progress.finished.last(where: { $0.bookIndex == index && $0.round == progress.round }) {
            self = .done(done.date)
        } else if index == progress.bookIndex {
            self = .current(progress.fraction)
        } else {
            self = .pending
        }
    }

    /// 책등이 색으로 찬 비율.
    var fill: Double {
        switch self {
        case .done: 1
        case .current(let f): f
        case .pending: 0
        }
    }

    var isCurrent: Bool { if case .current = self { true } else { false } }
}

/// 고른 작품 한 칸: 책등 하나와 제목, 원제, 상태.
private struct BookDetail: View {
    let index: Int
    let progress: WritingProgress
    var onWriteNext: (Int) -> Void = { _ in }
    var onFocusAuthor: (String) -> Void = { _ in }
    var onRead: (Book, Int) -> Void = { _, _ in }

    var body: some View {
        let book = Library.books[index]
        let status = BookStatus(index: index, progress: progress)
        let pendingOfAuthor = progress.pendingInRound.filter { Library.books[$0].authorShort == book.authorShort }
        let readable: Int? = {
            switch status {
            case .done: book.characters
            case .current: progress.charactersInBook > 0 ? progress.charactersInBook : nil
            case .pending: nil
            }
        }()
        HStack(spacing: 12) {
            Spine(book: book, status: status, selected: false, height: 40, tier: progress.salesTier(of: book))
            VStack(alignment: .leading, spacing: 3) {
                Text(book.displayTitle).font(.callout.weight(.semibold)).lineLimit(1)
                Text("\(book.displayAuthor) · \(book.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(line(book, status)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if case .done = status, progress.sales(of: book) > 0 {
                    salesLine(book)
                }
                HStack(spacing: 8) {
                    if let readable {
                        action("원고 읽기") { onRead(book, readable) }
                    }
                    if case .pending = status {
                        if progress.pendingInRound.first != index {
                            action("다음에 쓰기") { onWriteNext(index) }
                        }
                        if pendingOfAuthor.count >= 2 {
                            action("\(book.displayAuthorShort) 몰아 쓰기") { onFocusAuthor(book.authorShort) }
                        }
                    }
                }
                .buttonStyle(.bordered).controlSize(.small)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 버튼. 확인용 그림에서는 글자 알약으로.
    @ViewBuilder
    private func action(_ title: String, _ run: @escaping () -> Void) -> some View {
        if RenderMode.offscreen { ChipLabel(title: title) } else { Button(title, action: run) }
    }

    /// 판매: 부수와 단계, 다음 단계까지 막대.
    private func salesLine(_ book: Book) -> some View {
        let sold = progress.sales(of: book)
        let tier = progress.salesTier(of: book)
        let next = SalesTier.allCases.first { $0.copies > sold }
        let color = tier >= .bestseller ? BadgeTier.gold.color : tier == .reprint ? BadgeTier.silver.color : book.spineColor
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("\(Format.integer(sold))부").font(.caption.weight(.semibold).monospacedDigit())
                if tier != .none {
                    Text(tier.title).font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .foregroundStyle(color).background(color.opacity(0.14), in: Capsule())
                        .hint(tier.title, [tier.meaning + "."], symbol: "chart.line.uptrend.xyaxis")
                }
                Spacer(minLength: 0)
                if let next {
                    Text("\(next.title)까지 \(Format.integer(next.copies - sold))부").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if let next {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.12))
                        Capsule().fill(color).frame(width: max(3, geo.size.width * CGFloat(Double(sold - tier.copies) / Double(next.copies - tier.copies))))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.top, 2)
    }

    private func line(_ book: Book, _ status: BookStatus) -> String {
        switch status {
        case .done(let date):
            return "\(date.formatted(.dateTime.month(.defaultDigits).day())) 탈고 · \(Format.integer(book.characters))자"
        case .current:
            return "쓰는 중 · \(Format.integer(progress.charactersInBook)) / \(Format.integer(book.characters))자 · \(Format.percent(progress.fraction * 100))"
        case .pending:
            let ahead = (progress.position(of: index) ?? index) - progress.orderPosition
            return "\(ahead)편 뒤 · \(Format.integer(book.characters))자"
        }
    }
}

/// 작가 한 줄. 초상화와 이름, 탈고 수, 그 아래 책등들.
private struct AuthorRow: View {
    let author: String
    let progress: WritingProgress
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        let works = Library.books.enumerated().filter { $0.element.authorShort == author }
        let done = works.filter { if case .done = BookStatus(index: $0.offset, progress: progress) { true } else { false } }.count
        HStack(alignment: .top, spacing: 10) {
            PortraitFrame(author: author, scale: 2)
            VStack(alignment: .leading, spacing: 6) {
                let sold = works.reduce(0) { $0 + progress.sales(of: $1.element) }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(works.first?.element.displayAuthor ?? author).font(.caption.weight(.semibold))
                    Text("\(works.count)편 중 \(done)편" + (sold > 0 ? " · \(Format.integer(sold))부" : ""))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(works, id: \.element.id) { index, book in
                        Spine(book: book, status: BookStatus(index: index, progress: progress), selected: index == selected,
                              tier: progress.salesTier(of: book))
                            .onTapGesture { onSelect(index) }
                            .hint(book.displayTitle, ["\(book.title) · \(Format.integer(book.characters))자"], symbol: "book.closed")
                    }
                }
            }
        }
    }
}

/// 책등 하나. 분량만큼 넓고 키는 같다. 쓰는 중인 책은 위에 책갈피.
struct Spine: View {
    let book: Book
    let status: BookStatus
    let selected: Bool
    var height: CGFloat = 22
    var tier: SalesTier = .none

    var body: some View {
        let color = book.spineColor
        // 폭은 분량의 제곱근에 비례(6천 자 ≈ 15pt, 120만 자 ≈ 34pt).
        let width = 14 + CGFloat((Double(book.characters) / 1_000_000).squareRoot()) * 18
        let fill = status.fill
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color.opacity(0.14))
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color)
                .frame(height: fill > 0 ? max(3, height * CGFloat(fill)) : 0)
            // 탈고한 책은 가죽 광택만 살짝.
            if fill >= 1 {
                LinearGradient(colors: [.white.opacity(0.18), .clear, .black.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(fill >= 1 ? Color.clear : color.opacity(0.4), lineWidth: 1)
            if status.isCurrent {
                Rectangle().fill(Color(red: 0.85, green: 0.25, blue: 0.25))
                    .frame(width: 3, height: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 3).offset(y: -2)
            }
            // 판매 단계 띠: 재판은 은색, 베스트셀러부터 금색.
            if tier >= .reprint {
                Rectangle().fill(tier >= .bestseller ? BadgeTier.gold.color : BadgeTier.silver.color)
                    .frame(height: 2.5)
                    .padding(.horizontal, 3).padding(.bottom, 3)
            }
        }
        .frame(width: width, height: height)
        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(Color.primary.opacity(selected ? 0.8 : 0), lineWidth: 1.5))
        .contentShape(Rectangle())
    }
}

// MARK: - 옆 패널 가방

/// 가진 아이템과 쓰임새. 지금 상황에 맞는 아이템만 쓸 수 있다.
struct BagPanel: View {
    @Bindable var store: UsageStore
    /// 확인용 그림(`--snapshot`)은 `ScrollView` 를 못 그려서 끈다.
    var scrollable = true

    var body: some View {
        BagContent(progress: store.writing, scrollable: scrollable, onUse: store.use, onExchange: store.exchange, onBuy: store.buy)
    }
}

/// 가방 내용. 확인용 그림에서 가짜 기록으로도 그릴 수 있게 상태를 직접 받는다.
struct BagContent: View {
    let progress: WritingProgress?
    var scrollable = true
    var onUse: @MainActor (ItemKind) -> Void = { _ in }
    var onExchange: @MainActor (ItemKind, ItemKind) -> Void = { _, _ in }
    var onBuy: @MainActor (Furniture) -> Void = { _ in }

    var body: some View {
        if let progress {
            OptionalScroll(enabled: scrollable) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("가방 · 아이템 \(ItemKind.allCases.reduce(0) { $0 + progress.count($1) })개")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    if let event = progress.event, let active = progress.activeEvent, let book = progress.book {
                        EventBanner(event: event, active: active, cause: progress.cause, item: progress.cureItem,
                                    count: progress.cureCount, tint: book.spineColor) { if let item = progress.cureItem { onUse(item) } }
                    }
                    nextItem(progress)
                    studio(progress)
                    ForEach(ItemRole.allCases, id: \.self) { role in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(role.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(role.cures).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                            }
                            VStack(spacing: 4) {
                                ForEach(role.kinds, id: \.self) { item in
                                    row(item, progress)
                                }
                            }
                        }
                    }
                    Text("같은 아이템 \(Balance.exchangeCost)개는 다른 아이템 하나로 바꿀 수 있습니다. 한 종류는 \(Balance.itemCap)개까지 가집니다.")
                        .font(.caption2).foregroundStyle(.tertiary)
                    history(progress)
                }
                .padding(16)
            }
        } else {
            ProgressView()
        }
    }

    /// 작업실: 아이템으로 사는 가구 여섯. 산 것은 책상 장면에 그려지고 효과가 계속 붙는다.
    private func studio(_ progress: WritingProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("작업실").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(progress.studio.count) / \(Studio.all.count)").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(Studio.all) { furniture in
                    furnitureCard(furniture, progress)
                }
            }
        }
    }

    private func furnitureCard(_ furniture: Furniture, _ progress: WritingProgress) -> some View {
        let owned = progress.studio.contains(furniture.id)
        let items = Dictionary(uniqueKeysWithValues: ItemKind.allCases.map { ($0.rawValue, progress.count($0)) })
        let affordable = Studio.canAfford(furniture, items: items)
        return HStack(alignment: .top, spacing: 8) {
            Symbol(name: furniture.symbol, size: 14, color: owned ? Color(red: 0.2, green: 0.55, blue: 0.3) : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(furniture.title).font(.caption.weight(.semibold))
                Text(furniture.effect).font(.caption2).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if owned {
                    Text("있음").font(.caption2.weight(.semibold)).foregroundStyle(Color(red: 0.2, green: 0.55, blue: 0.3))
                } else {
                    HStack(spacing: 4) {
                        costChips(furniture, progress)
                        Spacer(minLength: 0)
                        buyButton(furniture, affordable: affordable)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(owned ? Color(red: 0.2, green: 0.55, blue: 0.3).opacity(0.08) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 값 표시. 가진 수/필요한 수, 모자라면 주황.
    private func costChips(_ furniture: Furniture, _ progress: WritingProgress) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(furniture.cost.enumerated()), id: \.offset) { _, cost in
                let have = progress.count(cost.0)
                let enough = have >= cost.1
                Text("\(cost.0.shortTitle) \(have)/\(cost.1)")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(enough ? Color.secondary : Color.orange)
            }
        }
    }

    @ViewBuilder
    private func buyButton(_ furniture: Furniture, affordable: Bool) -> some View {
        if RenderMode.offscreen {
            ChipLabel(title: "들이기", prominent: affordable)
        } else {
            Button("들이기") { onBuy(furniture) }
                .buttonStyle(.borderedProminent).controlSize(.mini).disabled(!affordable)
        }
    }

    /// 최근 돌발 상황 8개. 언제, 얼마나, 어떻게 끝났는지와 멈춘 동안 쓴 토큰.
    private func history(_ progress: WritingProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("최근 돌발 상황").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.top, 6)
            if progress.recentEvents.isEmpty, progress.decisions.isEmpty {
                Text("아직 없습니다. 새 토큰 100만 개마다 \(Format.percent(Balance.eventChancePerMillion * 100)) 확률로 생깁니다.")
                    .font(.caption).foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach(progress.recentEvents.prefix(8)) { record in
                        historyRow(record)
                        Divider().opacity(0.5)
                    }
                    // 선택지 사건에 답한 기록도 여기에.
                    ForEach(progress.decisions.prefix(3)) { record in
                        HStack(alignment: .top, spacing: 10) {
                            PixelIconView(rows: PixelIcon.letter, color: .secondary, scale: 1.6)
                                .frame(width: 16, height: 16).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.outcome).font(.callout).foregroundStyle(.secondary)
                                Text("\(Self.when(record.date)) · 사건 · \(Dilemmas.byID(record.dilemma)?.title ?? record.dilemma) · \(record.option)"
                                     + (record.auto == true ? " · 작가가 알아서" : "")).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 7)
                        if record.id != progress.decisions.prefix(3).last?.id { Divider().opacity(0.5) }
                    }
                }
                .padding(.horizontal, 10)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func historyRow(_ record: EventRecord) -> some View {
        if let luck = Lucks.byID(record.event) {
            HStack(alignment: .top, spacing: 10) {
                PixelIconView(rows: luck.icon, color: BadgeTier.gold.color, scale: 1.6)
                    .frame(width: 16, height: 16).padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.outcome ?? luck.title).font(.callout).foregroundStyle(.secondary)
                    Text("\(Self.when(record.startedAt)) · 행운 · \(luck.title)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
        } else if let lost = record.lostCharacters {
            disasterRow(record, lost: lost)
        } else {
            eventRow(record)
        }
    }

    private func disasterRow(_ record: EventRecord, lost: Int) -> some View {
        let disaster = Disasters.byID(record.event)
        let book = Library.books.first { $0.file == record.book }
        let shield = record.endedBy.flatMap(ItemKind.init(rawValue:))
        var detail = [Self.when(record.startedAt), "자연재해 · 집필은 계속"]
        if let book { detail.insert(book.displayAuthorShort, at: 0) }
        return HStack(alignment: .top, spacing: 10) {
            PixelIconView(rows: disaster?.icon ?? PixelIcon.warning, color: .orange, scale: 1.6)
                .frame(width: 16, height: 16).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(shield.map { "\(disaster?.cause ?? "재해가 났지만") \($0.title) 덕에 원고는 무사했습니다" }
                     ?? disaster?.text(lost: lost) ?? "원고 \(Format.integer(lost))자를 잃었습니다").font(.callout)
                    .foregroundStyle(.secondary)
                Text(detail.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
    }

    private func eventRow(_ record: EventRecord) -> some View {
        let event = AuthorEvents.byID(record.event)
        let book = Library.books.first { $0.file == record.book }
        let end = record.endedAt ?? Date()
        let minutes = max(1, Int((end.timeIntervalSince(record.startedAt) / 60).rounded()))
        let how: String = {
            if record.endedAt == nil { return "진행 중" }
            if let item = record.endedBy.flatMap(ItemKind.init(rawValue:)) { return "\(Format.particle(item.shortTitle, "으로", "로")) 끝냄" }
            return "저절로 끝남"
        }()
        var detail = [Self.when(record.startedAt), "\(minutes)분", how]
        if let book { detail.insert(book.displayAuthorShort, at: 0) }
        return HStack(alignment: .top, spacing: 10) {
            PixelIconView(rows: event?.icon ?? PixelIcon.warning, color: .secondary, scale: 1.6)
                .frame(width: 16, height: 16).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(event?.text ?? "알 수 없는 상황").font(.callout)
                    .foregroundStyle(record.endedAt == nil ? .primary : .secondary)
                Text(detail.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
                if record.cause != nil || record.outcome != nil {
                    Text([record.cause, record.outcome].compactMap { $0 }.joined(separator: " → "))
                        .font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                }
                if record.pausedTokens > 0 {
                    Text("멈춘 동안 토큰 \(Format.tokens(record.pausedTokens))").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// 오늘 14:32, 어제 09:05, 10월 19일 14:32
    private static func when(_ date: Date) -> String {
        let time = timeFormatter.string(from: date)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "오늘 \(time)" }
        if calendar.isDateInYesterday(date) { return "어제 \(time)" }
        return "\(date.formatted(.dateTime.month(.defaultDigits).day())) \(time)"
    }

    private func nextItem(_ progress: WritingProgress) -> some View {
        let fraction = 1 - Double(progress.tokensToNextItem) / Double(Balance.tokensPerItem)
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(Color.accentColor).frame(width: max(4, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
                }
            }
            .frame(height: 4)
            Text("다음 아이템까지 토큰 \(Format.tokens(progress.tokensToNextItem)) · \(Format.tokens(Balance.tokensPerItem))마다 하나")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func row(_ item: ItemKind, _ progress: WritingProgress) -> some View {
        let count = progress.count(item)
        let usable = progress.event?.cure.role == item.role && count > 0 && progress.refusedUntil() == nil
        return HStack(spacing: 12) {
            PixelIconView(rows: item.icon, color: count > 0 ? .primary : .secondary.opacity(0.5), scale: 2)
                .frame(width: 22, height: 22)
            Text(item.title).font(.callout.weight(count > 0 ? .semibold : .regular))
                .foregroundStyle(count > 0 ? .primary : .secondary)
            Text("×\(count)").font(.callout.monospacedDigit()).foregroundStyle(count > 0 ? .primary : .tertiary)
            if count >= Balance.itemCap {
                Text("가득").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
            }
            Spacer()
            if count >= Balance.exchangeCost, RenderMode.offscreen {
                ChipLabel(title: "\(Balance.exchangeCost)개 바꾸기")
            } else if count >= Balance.exchangeCost {
                Menu {
                    ForEach(ItemKind.allCases.filter { $0 != item && progress.count($0) < Balance.itemCap }, id: \.self) { to in
                        Button("\(to.title)로") { onExchange(item, to) }
                    }
                } label: {
                    Text("\(Balance.exchangeCost)개 바꾸기").font(.caption)
                }
                .menuStyle(.borderlessButton).fixedSize()
            }
            if usable, RenderMode.offscreen {
                ChipLabel(title: "권하기", prominent: true)
            } else if usable {
                Button("권하기") { onUse(item) }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(usable ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(count > 0 ? 1 : 0.7)
    }
}


/// 행운 배너. 남은 시간을 보여 준다.
struct LuckBanner: View {
    let luck: ActiveLuck
    let kind: LuckEvent

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let minutes = max(1, Int(ceil(luck.endsAt.timeIntervalSince(context.date) / 60)))
            HStack(spacing: 10) {
                PixelIconView(rows: kind.icon, color: BadgeTier.gold.color, scale: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title).font(.callout.weight(.semibold))
                    Text(kind.id == Lucks.inspiration.id ? "글자 \(Int(Balance.inspirationMultiplier))배 · \(minutes)분 남음"
                         : "돌발 상황 없음 · \(minutes)분 남음")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let guest = luck.guest {
                    PortraitFrame(author: guest, scale: 2)
                }
            }
            .padding(12)
            .background(BadgeTier.gold.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// 탈고 카드. 하루 동안 팝오버에 남고, 닫으면 사라진다.
struct FinishCard: View {
    let note: FinishNote
    let book: Book
    var onChoose: @MainActor (Publisher) -> Void = { _ in }
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(book.spineColor).frame(width: 22, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(.white.opacity(0.25)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("탈고").font(.caption.weight(.semibold)).foregroundStyle(book.spineColor)
                        Text(book.displayTitle).font(.callout.weight(.semibold)).lineLimit(1)
                        if let chosen = note.publisher.flatMap(Publisher.init(rawValue:)) {
                            Text(chosen.title).font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .foregroundStyle(book.spineColor).background(book.spineColor.opacity(0.14), in: Capsule())
                                .hint(chosen.title, [chosen.detail], symbol: chosen.symbol)
                        }
                    }
                    HStack(spacing: 10) {
                        Label("\(note.days)일", systemImage: "calendar").labelStyle(.titleOnly)
                        Text("\(Format.integer(book.characters))자")
                        if note.events > 0 { Text("돌발 상황 \(note.events)번") }
                        if note.lost > 0 { Text("재해 \(Format.integer(note.lost))자") }
                    }
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if note.publisher != nil {
                    Button(action: onDismiss) { Text("닫기").font(.caption) }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            // 어디에 보낼지. 하루 안에 안 고르면 대형 출판사로 간다.
            if note.publisher == nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("원고를 어디에 보낼까요").font(.caption.weight(.semibold))
                    HStack(spacing: 6) {
                        ForEach(Publisher.allCases, id: \.self) { publisher in
                            Button { onChoose(publisher) } label: {
                                HStack(spacing: 4) {
                                    Symbol(name: publisher.symbol, size: 10, color: .white)
                                    Text(publisher.title).font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .foregroundStyle(Color.white)
                                .background(book.spineColor, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .hint(publisher.title, [publisher.detail], symbol: publisher.symbol)
                        }
                    }
                    if let due = note.publisherDue {
                        Text("\(max(1, Int(due.timeIntervalSinceNow / 3600)))시간 안에 안 고르면 대형 출판사로 갑니다").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(12)
        .background(book.spineColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 손님 작가의 내기. 걸렸으면 받기·사양 버튼, 받았으면 진행 막대와 남은 시간.
struct BetBanner: View {
    let bet: ActiveBet
    let written: Double
    let onAnswer: @MainActor (Bool) -> Void

    var body: some View {
        let name = Library.books.first { $0.authorShort == bet.guest }?.displayAuthorShort ?? bet.guest
        let gold = BadgeTier.gold.color
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let minutes = max(0, Int(ceil(bet.endsAt.timeIntervalSince(context.date) / 60)))
            HStack(spacing: 10) {
                PortraitFrame(author: bet.guest, scale: 2)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(name)의 내기").font(.callout.weight(.semibold))
                        Text("\(Format.integer(bet.target))자 · \(minutes >= 60 ? "\(minutes / 60)시간 \(minutes % 60)분" : "\(minutes)분") 안에")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if bet.running {
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.12))
                                GeometryReader { geo in Capsule().fill(gold).frame(width: max(3, geo.size.width * CGFloat(min(1, written / Double(bet.target))))) }
                            }
                            .frame(height: 4)
                            Text("\(Format.integer(Int(written))) / \(Format.integer(bet.target))").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize()
                        }
                    } else {
                        HStack(spacing: 6) {
                            Button { onAnswer(true) } label: {
                                Text("받는다").font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 5)
                                    .foregroundStyle(Color.white).background(gold, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            Button { onAnswer(false) } label: {
                                Text("사양한다").font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 5)
                                    .foregroundStyle(.primary).background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// 지난주 돌아보기 카드. 그 주 동안 팝오버에 남고, 닫으면 사라진다.
struct WeeklyCard: View {
    let review: WeeklyReview
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("지난주 돌아보기").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(action: onDismiss) { Text("닫기").font(.caption) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                stat("\(Format.integer(review.characters))", "자")
                stat("\(review.finished)", "탈고")
                stat("\(review.events)", "돌발 상황")
                stat("\(review.disasters)", "재해")
                if let sales = review.sales, sales > 0 { stat("\(Format.integer(sales))", "부") }
                Spacer(minLength: 0)
            }
            if let best = review.bestDay {
                Text("가장 많이 쓴 날 · \(best.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated))) \(Format.integer(review.bestDayCharacters))자"
                     + (review.deadlineMet.map { $0 ? " · 마감 지킴" : " · 마감 펑크" } ?? ""))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.callout.weight(.semibold).monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// 돌아옴·치료·거절 한 줄. 몇 분 동안만 보인다.
struct NoteLine: View {
    let icon: [String]
    let color: Color
    let text: String
    let at: Date

    var body: some View {
        HStack(spacing: 8) {
            PixelIconView(rows: icon, color: color, scale: 1.5)
            Text(text).font(.caption)
            Spacer(minLength: 0)
            Text(at, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// 최근 자연재해 한 줄. 집필은 멈추지 않으니 버튼 없이 알리기만 한다.
struct DisasterNote: View {
    let disaster: Disaster
    let lost: Int
    let at: Date
    /// 방재 아이템이 막았으면 그 아이템.
    var shield: ItemKind? = nil

    var body: some View {
        HStack(spacing: 8) {
            PixelIconView(rows: disaster.icon, color: .orange, scale: 1.5)
            Text(shield.map { disaster.shieldedText($0) } ?? disaster.text(lost: lost)).font(.caption)
            Spacer(minLength: 0)
            Text(at, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
