import SwiftUI

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
                        let span = minutes >= 60 ? L10n.tr("\(minutes / 60)시간") + (minutes % 60 > 0 ? " " + L10n.tr("\(minutes % 60)분") : "") : L10n.tr("\(minutes)분")
                        Text(L10n.tr("\(span) 안에 답이 없으면 작가가 알아서 고릅니다"))
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
            return L10n.tr("\(probe.text), \(hours)시간 동안")
        }
        if option.items > 0 { parts.append(L10n.tr("아이템 \(option.items)개를 받습니다")) }
        if option.items < 0 { parts.append(L10n.tr("아이템 \(-option.items)개가 나갑니다")) }
        if parts.isEmpty { parts.append(L10n.tr("숫자 효과는 없습니다.")) }
        parts.append(L10n.tr("결과 문장은 골라 봐야 압니다."))
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
        let color: Color = met ? ChartPalette.good : .secondary
        HStack(spacing: 6) {
            Symbol(name: met ? "checkmark.circle" : "calendar", size: 11, color: color)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    // 지킨 뒤에는 과거형으로. "마감 지킴 · 크리스마스 캐럴 탈고"처럼 무엇을 했는지 적는다.
                    Text(met ? "마감 지킴" : "마감").font(.caption2.weight(.semibold)).foregroundStyle(met ? color : .primary)
                    Text(deadline.title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(met ? (deadline.metAt.map { $0.formatted(.dateTime.weekday(.abbreviated)) } ?? "")
                         : deadline.kind == .finish ? (daysLeft == 0 ? L10n.tr("오늘까지") : L10n.tr("\(daysLeft)일 남음"))
                         : L10n.tr("목표 \(Format.short(deadline.target)) 중 \(Format.short(progress))"))
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
                    Text(L10n.tr("집필 멈춤 · \(minutes)분 뒤 재개") + (wait.map { L10n.tr(" · 아이템은 \($0)분 뒤") } ?? ""))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: 4)
                let usable = count > 0 && wait == nil
                let shown = item ?? event.cure
                Button(action: onUse) {
                    HStack(spacing: 4) {
                        PixelIconView(rows: shown.icon, color: usable ? .white : .secondary, scale: 1.1)
                        Text(count == 0 ? L10n.tr("\(event.cure.role.title) 없음") : wait.map { L10n.tr("\($0)분 뒤") } ?? "\(shown.shortTitle) ×\(count)")
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
                    Text(kind.id == Lucks.inspiration.id ? L10n.tr("글자 \(Int(Balance.inspirationMultiplier))배 · \(minutes)분 남음")
                         : L10n.tr("돌발 상황 없음 · \(minutes)분 남음"))
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
                        let span = minutes >= 60 ? L10n.tr("\(minutes / 60)시간 \(minutes % 60)분") : L10n.tr("\(minutes)분")
                        Text(L10n.tr("\(Format.integer(bet.target))자 · \(span) 안에"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if bet.running {
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.12))
                                GeometryReader { geo in Capsule().fill(gold).frame(width: max(3, geo.size.width * CGFloat(min(1, written / Double(bet.target))))) }
                            }
                            .frame(height: 4)
                            Text("\(Format.integer(bet.target))자 중 \(Format.integer(Int(written)))자").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize()
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
                Text(L10n.tr("가장 많이 쓴 날 · \(best.formatted(.dateTime.month(.defaultDigits).day().weekday(.abbreviated))) \(Format.integer(review.bestDayCharacters))자")
                     + (review.deadlineMet.map { L10n.tr($0 ? " · 마감 지킴" : " · 마감 펑크") } ?? ""))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.callout.weight(.semibold).monospacedDigit())
            Text(L10n.tr(label)).font(.caption2).foregroundStyle(.secondary)
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
            PixelIconView(rows: disaster.icon, color: ChartPalette.warning, scale: 1.5)
            Text(shield.map { disaster.shieldedText($0) } ?? disaster.text(lost: lost)).font(.caption)
            Spacer(minLength: 0)
            Text(at, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(ChartPalette.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
