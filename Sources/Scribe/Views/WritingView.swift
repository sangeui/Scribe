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
        VStack(alignment: .leading, spacing: 10) {
            deskCard(book, event: event)
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
                    NoteLine(icon: icon, color: note.kind == .refused ? ChartPalette.warning : note.kind == .luck ? BadgeTier.gold.color : book.spineColor,
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
            if let deadline = progress.deadline {
                DeadlineRow(deadline: deadline, progress: progress.deadlineProgress, bookFraction: progress.fraction)
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

    /// 집필 카드 안쪽 하단의 문호 컨디션·능력치 서랍. 평소에는 한 줄로 요약하고, 누르면 카드 안에서 게이지와 능력치 칩을 펼친다.
    private func authorConditionDrawer(_ book: Book) -> some View {
        let expanded = RenderMode.offscreen ? (statusExpanded || progress.inspirationReady) : statusExpanded
        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(book.spineColor.opacity(scheme == .dark ? 0.20 : 0.13))
                .frame(height: 1)
                .padding(.bottom, 7)
            statusLine(book, expanded: expanded)
            Collapsible(progress: expanded ? 1 : 0, topSpacing: 8) {
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
    }

    /// 집필 카드 안쪽 하단 상태 한 줄. 영감·체력·능력치·보정을 요약하고, 누르면 카드 안에서 펼치거나 접는다.
    private func statusLine(_ book: Book, expanded: Bool) -> some View {
        let gold = BadgeTier.gold.color
        let heart: Color = progress.sheet.stamina <= progress.statPerks.staminaMax * 0.1 ? ChartPalette.critical : progress.tired ? ChartPalette.warning : .secondary
        let boosts = progress.boosts.count
        return Button { statusExpanded.toggle() } label: {
            HStack(spacing: 6) {
                if progress.inspirationReady {
                    HStack(spacing: 3) {
                        Symbol(name: "sparkles", size: 10, color: gold)
                        Text(L10n.tr("영감 찼음")).font(.caption2.weight(.semibold).monospacedDigit()).foregroundStyle(gold)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(gold.opacity(scheme == .dark ? 0.22 : 0.15), in: Capsule())
                    .fixedSize()
                } else {
                    statusItem("sparkles", "영감 \(Format.percent(progress.inspirationFraction * 100))", .secondary)
                }
                Text("·").font(.caption2).foregroundStyle(.tertiary)
                statusItem(progress.tired ? "heart.slash" : "heart", "체력 \(Int(progress.sheet.stamina.rounded()))", heart)
                Text("·").font(.caption2).foregroundStyle(.tertiary)
                statusItem("person", "능력치 \(progress.sheet.total)", .secondary)
                if boosts > 0 {
                    Text("·").font(.caption2).foregroundStyle(.tertiary)
                    statusItem("arrow.up.right", "보정 \(boosts)", book.spineColor)
                }
                Spacer(minLength: 4)
                HStack(spacing: 3) {
                    Text(L10n.tr(expanded ? "접기" : "펼치기"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Symbol(name: "chevron.down", size: 8.5, color: .secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusItem(_ symbol: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Symbol(name: symbol, size: 10, color: color)
            Text(L10n.tr(text)).font(.caption2.monospacedDigit()).foregroundStyle(color == .secondary ? Color.secondary : color)
        }
        .fixedSize()
    }

    /// 초상화·제목·날씨 헤더와 진행 막대, 한 줄 미니멀 원고 스트립을 하나로 묶은 상단 집필 카드.
    private func deskCard(_ book: Book, event: AuthorEvent?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                                Symbol(name: "cup.and.saucer", size: 11, color: progress.caffeinated ? ChartPalette.warning : .secondary)
                                Text("\(progress.cupsToday)잔").font(.system(size: 11)).foregroundStyle(progress.caffeinated ? ChartPalette.warning : Color.secondary)
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
                // 작은 고리 둘: 평소에는 책등 색에 맞춰 차분하게 두고, 지쳤거나 영감이 찼을 때만 색이 켜진다.
                VStack(spacing: 6) {
                    MiniRing(fraction: progress.sheet.stamina / max(1, progress.statPerks.staminaMax),
                             color: progress.tired ? ChartPalette.warning : book.spineColor.opacity(0.68), symbol: "heart.fill")
                        .hint("체력 \(Int(progress.sheet.stamina.rounded())) (최대 \(Int(progress.statPerks.staminaMax)))",
                              [progress.tired ? "지쳤습니다. 글자가 \(Int((1 - Balance.staminaTiredMultiplier) * 100))% 덜 늘고 0이 되면 탈진합니다." : "쓰면 줄고 쉬면 돌아옵니다."], symbol: "heart")
                    MiniRing(fraction: progress.inspirationFraction,
                             color: progress.inspirationReady ? BadgeTier.gold.color : book.spineColor.opacity(0.55), symbol: "sparkles")
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
            progressBar(book)
            manuscriptStrip(book, event: event)
            authorConditionDrawer(book)
        }
        .padding(10)
        // 작가 색이 머리에 옅게 깔린다. 작가가 바뀌면 색도 천천히 바뀐다.
        .background(
            LinearGradient(colors: [book.spineColor.opacity(scheme == .dark ? 0.22 : 0.13), book.spineColor.opacity(0.03)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(book.spineColor.opacity(scheme == .dark ? 0.24 : 0.14), lineWidth: 1))
        .animation(.easeInOut(duration: 0.6), value: book.id)
    }

    private func progressBar(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule().fill(book.spineColor)
                        .frame(width: max(4, geo.size.width * CGFloat(min(max(progress.fraction, 0), 1))))
                        .animation(.easeOut(duration: 0.6), value: progress.fraction)
                }
            }
            .frame(height: 4)
            HStack(spacing: 6) {
                Text("전체 \(Format.integer(book.characters))자 중 \(Format.integer(progress.charactersInBook))자")
                if progress.todayCharacters > 0 {
                    Text("· 오늘 \(Format.integer(Int(progress.todayCharacters)))자")
                        .foregroundStyle(book.spineColor)
                }
                Spacer()
                if let days = progress.daysToFinish {
                    Text(days <= 1 ? "머지않아 탈고" : "탈고까지 약 \(days)일")
                }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    /// 1줄로 절제된 미니멀 원고 스트립.
    private func manuscriptStrip(_ book: Book, event: AuthorEvent?) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(book.spineColor.opacity(0.75))
                .frame(width: 2.5, height: 14)
            if progress.charactersInBook == 0 {
                Text("첫 문장을 기다리는 중입니다. 토큰을 쓰면 원문이 한 글자씩 써집니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ManuscriptText(book: book, target: progress.charactersInBook, fontSize: 11.5,
                               paused: event != nil, singleLine: true, color: .primary.opacity(0.82),
                               tempo: progress.caffeinated ? Balance.caffeineTempo : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .frame(height: 28)
        .background(scheme == .dark ? Color(red: 0.14, green: 0.13, blue: 0.12).opacity(0.75) : Color(red: 0.985, green: 0.975, blue: 0.94).opacity(0.88),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(scheme == .dark ? 0.08 : 0.06), lineWidth: 1))
        .opacity(event == nil ? 1 : 0.55)
    }

    /// 마을·창고·성과·서재·서점으로 이동하는 5열 공간·보조 창 네비게이션 도크.
    private var footer: some View {
        let items = ItemKind.allCases.reduce(0) { $0 + progress.count($1) }
        let earned = Achievements.all.filter { !$0.daily && (progress.badges[$0.id] != nil || $0.isMet(progress.facts)) }.count
        return HStack(spacing: 6) {
            FooterNavTile(symbol: "map", title: "마을", detail: nil, action: onVillage)
                .hint("마을", ["작업실, 창고, 서점, 살롱이 있는 작은 맵입니다."], symbol: "map")
            FooterNavTile(symbol: "shippingbox", title: "창고", detail: "\(items)", action: onBag)
            FooterNavTile(symbol: "rosette", title: "성과", detail: "\(earned)", action: onBadges)
            FooterNavTile(symbol: "books.vertical", title: "서재", detail: "\(progress.finishedInRound)권", action: onShelf)
            FooterNavTile(symbol: "storefront", title: "서점", detail: Format.short(progress.totalSales), action: onBookstore)
        }
    }
}

/// 집필 화면 하단 네비게이션 도크의 개별 공간·패널 이동 타일.
private struct FooterNavTile: View {
    let symbol: String
    let title: String
    let detail: String?
    let action: @MainActor () -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Symbol(name: symbol, size: 11, color: hovering ? .primary : .secondary)
                    Spacer(minLength: 2)
                    if let detail {
                        Text(L10n.tr(detail))
                            .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Symbol(name: "arrow.up.right", size: 8.5, color: .secondary.opacity(0.8))
                    }
                }
                Text(L10n.tr(title))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(
                Color.secondary.opacity(hovering ? (scheme == .dark ? 0.17 : 0.11) : (scheme == .dark ? 0.10 : 0.06)),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(hovering ? (scheme == .dark ? 0.18 : 0.13) : (scheme == .dark ? 0.10 : 0.07)), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - 서랍·스크롤 컨테이너

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
