import SwiftUI

extension BookstoreContent {
    /// 꼬리표: 고른 책의 부수, 출판사, 단계 사다리, 밀어주기·광고 버튼.
    func tag(_ book: Book) -> some View {
        let sold = progress.sales(of: book)
        let tier = progress.salesTier(of: book)
        let review = progress.review(of: book)
        let publisher = progress.finishCards.first { $0.book == book.file }?.publisher.flatMap(Publisher.init(rawValue:))
        let featured = progress.featuredBook == book.file
        let adEnds = progress.adEnds(for: book)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(book.displayTitle).font(.callout.weight(.semibold)).lineLimit(1)
                Text(book.displayAuthorShort).font(.caption).foregroundStyle(.secondary)
                if let publisher {
                    Text(publisher.title).font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .foregroundStyle(.secondary).background(Color.secondary.opacity(0.12), in: Capsule())
                        .hint(publisher.title, [publisher.detail], symbol: publisher.symbol)
                }
                Spacer(minLength: 0)
                Text("\(Format.integer(sold))부").font(.callout.weight(.semibold).monospacedDigit())
                if let review, review.stars != 3 {
                    Text("서평 \(Self.percent(Critics.salesMultiplier(for: review.stars)))")
                        .font(.caption2.weight(.medium)).foregroundStyle(Self.starColor(review.stars))
                        .hint("서평 효과", ["별 \(review.stars)개 서평 때문에 이 책은 \(Self.percent(Critics.salesMultiplier(for: review.stars))) 팔립니다."], symbol: "star")
                }
                let shop = progress.shopMultiplier(for: book)
                if abs(shop - 1) > 0.001 {
                    Text("사건 \(Self.percent(shop))")
                        .font(.caption2.weight(.medium)).foregroundStyle(shop >= 1 ? ChartPalette.good : ChartPalette.warning)
                        .hint("서점 사건", progress.shopBoosts.filter { $0.book == nil || $0.book == book.file }.map { "\($0.source): \(Self.percent($0.value)), \(max(1, Int($0.endsAt.timeIntervalSince(now) / 3600)))시간 남음" }, symbol: "storefront")
                }
            }
            TierLadder(sold: sold, tier: tier)
            stockLine(book)
            HStack(spacing: 6) {
                featureButton(book, featured: featured)
                counterButton(book)
                adButton(book, adEnds: adEnds)
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 재고와 자리 한 줄. 품절이면 재판까지 남은 시간, 직접 고른 자리면 그렇다고.
    private func stockLine(_ book: Book) -> some View {
        let slot = progress.slot(of: book)
        let pinned = progress.isPinned(book), benched = progress.isBenched(book)
        var parts: [String] = []
        if let reprint = progress.reprint(for: book) {
            parts.append(L10n.tr("품절 · 재판 \(Format.integer(reprint.copies))부 \(max(1, Int((reprint.due.timeIntervalSince(now) / 3600).rounded(.up))))시간 뒤"))
        } else {
            parts.append(L10n.tr("재고 \(Format.integer(progress.stock(of: book)))부"))
        }
        if let slot, slot != .storage { parts.append(slot.title + L10n.tr(pinned ? " · 직접 고름" : benched ? " · 직접 내림" : " · 주인이 정함")) }
        return HStack(spacing: 6) {
            Symbol(name: slot?.symbol ?? "shippingbox", size: 10)
            Text(parts.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            if pinned || benched {
                if RenderMode.offscreen {
                    Text("주인에게 맡기기").font(.caption2).foregroundStyle(.secondary).underline()
                } else {
                    Button("주인에게 맡기기") { onLeave(book.file) }.buttonStyle(.plain).font(.caption2).foregroundStyle(.secondary).underline()
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// 진열창. 걸면 +30%. 하루에 한 번 바꾼다. 걸린 책을 다시 누르면 서가로 내린다.
    @ViewBuilder
    private func featureButton(_ book: Book, featured: Bool) -> some View {
        let locked = !progress.canChangeFeatured
        let noWindow = !progress.trustLevel.hasWindow
        let soldOut = progress.slot(of: book) == .storage
        let gold = BadgeTier.gold.color
        let off = !featured && (locked || noWindow || soldOut)
        Group {
            if RenderMode.offscreen {
                ChipLabel(title: "진열창", prominent: featured)
            } else {
                Button {
                    if featured { onPlace(book.file, .shelf) } else { onPlace(book.file, .window) }
                } label: {
                    HStack(spacing: 4) {
                        Symbol(name: featured ? "star.fill" : "star", size: 10, color: featured ? .white : .primary)
                        Text("진열창").font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .foregroundStyle(featured ? Color.white : Color.primary)
                    .background(featured ? gold : Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(off)
                .opacity(off ? 0.5 : 1)
            }
        }
        .hint(featured ? "진열창에 걸려 있음" : "진열창에 걸기",
              featured ? ["\(Int((Balance.windowSales - 1) * 100))% 더 팔립니다. 다시 누르면 서가로 내리고, 이레 동안 주인이 다시 올리지 않습니다."]
              : ["이 책을 진열창에 겁니다. \(Int((Balance.windowSales - 1) * 100))% 더 팔리고, 직접 고른 자리라 이레 동안 주인이 안 건드립니다.",
                 noWindow ? "주인의 신뢰가 '안면'은 돼야 진열창을 내줍니다." : soldOut ? "품절이라 걸 수 없습니다." : locked ? "지금 걸린 책을 고른 지 하루가 안 돼 아직 못 바꿉니다." : "하루에 한 번 바꿀 수 있습니다."],
              symbol: "star")
    }

    /// 매대. 올리면 제값에 팔리고 직접 고른 자리가 된다. 올라 있는 책을 다시 누르면 서가로 내린다.
    @ViewBuilder
    private func counterButton(_ book: Book) -> some View {
        let on = progress.slot(of: book) == .counter
        let soldOut = progress.slot(of: book) == .storage
        let pinned = progress.isPinned(book)
        Group {
            if RenderMode.offscreen {
                ChipLabel(title: "매대", prominent: on)
            } else {
                Button {
                    if on { onPlace(book.file, .shelf) } else { onPlace(book.file, .counter) }
                } label: {
                    HStack(spacing: 4) {
                        Symbol(name: on ? "tablecells.fill" : "tablecells", size: 10, color: on ? .white : .primary)
                        Text("매대").font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .foregroundStyle(on ? Color.white : Color.primary)
                    .background(on ? Color.primary.opacity(0.75) : Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(soldOut)
                .opacity(soldOut ? 0.5 : 1)
            }
        }
        .hint(on ? "매대에 있음" : "매대에 올리기",
              on ? [pinned ? "직접 고른 자리라 이레 동안 그대로입니다." : "주인이 올린 책입니다. 아침 정리 때 바뀔 수 있습니다.", "다시 누르면 서가로 내리고, 이레 동안 주인이 다시 올리지 않습니다."]
              : [soldOut ? "품절이라 올릴 수 없습니다." : "매대 \(progress.trustLevel.counterSlots)칸 가운데 한 칸에 둡니다. 칸이 다 차 있으면 주인이 고른 책 중 가장 덜 팔리는 것을 내립니다.", "직접 고른 자리는 이레 동안 주인이 안 건드립니다."],
              symbol: "tablecells")
    }

    /// 광고. 아이템 셋으로 하루 동안 두 배.
    @ViewBuilder
    private func adButton(_ book: Book, adEnds: Date?) -> some View {
        let costText = Balance.adCost.map { "\($0.0.shortTitle) \($0.1)" }.joined(separator: " · ")
        Group {
            if let adEnds {
                HStack(spacing: 4) {
                    Symbol(name: "megaphone.fill", size: 10, color: ChartPalette.warning)
                    Text("광고 중 · \(max(1, Int(adEnds.timeIntervalSince(now) / 3600)))시간").font(.caption.weight(.semibold)).foregroundStyle(ChartPalette.warning)
                }
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(ChartPalette.warning.opacity(0.12), in: Capsule())
            } else if RenderMode.offscreen {
                ChipLabel(title: "광고 걸기", prominent: progress.canAdvertise)
            } else {
                Button { onAdvertise(book.file) } label: {
                    HStack(spacing: 4) {
                        Symbol(name: "megaphone", size: 10, color: .primary)
                        Text("광고 걸기").font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .foregroundStyle(Color.primary)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!progress.canAdvertise || progress.slot(of: book) == .storage)
                .opacity(progress.canAdvertise && progress.slot(of: book) != .storage ? 1 : 0.5)
            }
        }
        .hint(adEnds == nil ? "광고 걸기" : "광고 중",
              adEnds == nil ? ["\(costText)를 써서 \(Balance.adHours)시간 동안 이 책이 \(Int(Balance.adBoost))배로 팔립니다. 주인의 신뢰도 조금 오릅니다.",
                               progress.slot(of: book) == .storage ? "품절이라 광고해도 팔 책이 없습니다." : progress.canAdvertise ? "" : "아이템이 모자랍니다."].filter { !$0.isEmpty }
              : ["이 책이 \(Int(Balance.adBoost))배로 팔리는 중입니다."], symbol: "megaphone")
    }

    static func starColor(_ stars: Int) -> Color { stars >= 4 ? BadgeTier.gold.color : stars <= 2 ? ChartPalette.warning : .secondary }

    static func percent(_ multiplier: Double) -> String {
        let delta = Int(((multiplier - 1) * 100).rounded())
        return delta >= 0 ? "+\(delta)%" : "\(delta)%"
    }

    // MARK: 정산서

    var statements: some View {
        Group {
            if progress.shop.statements.isEmpty {
                Text("첫 월요일 아침에 주인이 지난주 셈을 보냅니다.").font(.caption).foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 8) {
                    ForEach(progress.shop.statements.suffix(4).reversed()) { statement in StatementCard(statement: statement) }
                }
            }
        }
    }

    // MARK: 서평

    var reviews: some View {
        Group {
            if progress.reviews.isEmpty {
                Text("첫 탈고 뒤 하루쯤 지나 실립니다.").font(.caption).foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        ForEach(Array(progress.reviews.prefix(2))) { review in
                            ReviewCard(review: review)
                        }
                    }
                    if progress.reviews.count > 2 {
                        Collapsible(progress: showsAllReviews ? 1 : 0, topSpacing: 8) {
                            VStack(spacing: 8) {
                                ForEach(Array(progress.reviews.dropFirst(2))) { review in
                                    ReviewCard(review: review)
                                }
                            }
                        }
                        Button(showsAllReviews ? L10n.tr("최근 둘만") : L10n.tr("서평 \(progress.reviews.count - 2)편 더")) { showsAllReviews.toggle() }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: 풍문

    var gossip: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(Gossip.lines(progress: progress, now: now).prefix(3).enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Color.secondary.opacity(0.4)).frame(width: 4, height: 4).padding(.top, 6)
                    Text(line).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 서점 매대의 표지 한 장. 책등 색 바탕에 제목과 작가, 아래에 판매 단계 띠. 위에 이달의 책 별·광고 확성기·서평 별점, 아래에 부수.
/// 책 칩. 책등 색 네모, 제목, 부수. 금·은 띠로 판매 단계를, 별과 확성기로 이달의 책과 광고를 표시한다.
struct BookChip: View {
    let book: Book
    let tier: SalesTier
    let selected: Bool
    let featured: Bool
    let advertised: Bool
    let sales: Int
    var soldOut = false
    var pinned = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let band: Color? = tier >= .bestseller ? BadgeTier.gold.color : tier == .reprint ? BadgeTier.silver.color : nil
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(soldOut ? Color.secondary.opacity(0.3) : book.spineColor)
                .frame(width: 8, height: 14)
                .overlay(alignment: .bottom) { if let band { Rectangle().fill(band).frame(height: 3) } }
            Text(book.displayTitle).font(.caption.weight(selected ? .semibold : .regular)).lineLimit(1)
                .foregroundStyle(soldOut ? .secondary : .primary)
            Text(soldOut ? L10n.tr("품절") : Format.short(sales)).font(.caption2.monospacedDigit()).foregroundStyle(soldOut ? ChartPalette.warning : .secondary)
            if featured { Symbol(name: "star.fill", size: 8, color: BadgeTier.gold.color) }
            if advertised { Symbol(name: "megaphone.fill", size: 8, color: ChartPalette.warning) }
            if pinned { Symbol(name: "pin.fill", size: 7, color: .secondary) }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(selected ? Color.primary.opacity(scheme == .dark ? 0.16 : 0.1) : Color.secondary.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(selected ? Color.primary.opacity(0.25) : .clear))
        .contentShape(Capsule())
    }
}

struct TierLadder: View {
    let sold: Int
    let tier: SalesTier

    var body: some View {
        let steps = SalesTier.allCases.filter { $0 != .none }
        let next = steps.first { $0.copies > sold }
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 0) {
                ForEach(steps, id: \.self) { step in
                    let reached = step <= tier
                    VStack(spacing: 2) {
                        Circle().fill(reached ? Self.color(step) : Color.secondary.opacity(0.2)).frame(width: 7, height: 7)
                            .overlay(Circle().stroke(step == tier ? Color.primary : .clear, lineWidth: 1.5))
                        Text(step.title).font(.system(size: 9, weight: reached ? .semibold : .regular))
                            .foregroundStyle(reached ? .primary : .secondary)
                        Text(L10n.tr("\(Format.short(step.copies))부")).font(.system(size: 8).monospacedDigit()).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .hint(L10n.tr("\(step.title) · \(Format.short(step.copies))부"), [step.meaning + "."], symbol: "chart.line.uptrend.xyaxis")
                }
            }
            if let next {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.12))
                        Capsule().fill(Self.color(next))
                            .frame(width: max(3, geo.size.width * CGFloat(Double(sold - tier.copies) / Double(next.copies - tier.copies))))
                    }
                }
                .frame(height: 3)
            }
        }
    }

    static func color(_ tier: SalesTier) -> Color {
        tier >= .bestseller ? BadgeTier.gold.color : tier == .reprint ? BadgeTier.silver.color : Color(red: 0.6, green: 0.4, blue: 0.25)
    }
}

/// 서평 한 편. 책 제목, 별점, 본문, 비평가.
struct ReviewCard: View {
    let review: Review

    var body: some View {
        let book = Library.books.first { $0.file == review.book }
        let color = BookstoreContent.starColor(review.stars)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(book?.displayTitle ?? review.book).font(.caption.weight(.semibold)).lineLimit(1)
                Text(review.starText).font(.caption).foregroundStyle(color)
                Spacer(minLength: 0)
                if review.affected == true {
                    Text("작가도 읽음").font(.system(size: 9, weight: .semibold)).foregroundStyle(color)
                        .hint("작가도 읽음", ["실릴 때 이 책의 작가가 쓰는 중이라 하루 동안 영향을 받았습니다.", "★5 글자 +15%·돌발 상황 -30%, ★4 글자 +8%, ★2 거절 +10%p, ★1 거절 +20%p·글자 -10%."], symbol: "person")
                }
            }
            Text(review.text).font(.caption).foregroundStyle(.primary.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            Text("\(review.critic) · \(review.date.formatted(.dateTime.month(.defaultDigits).day()))").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 보정 하나를 작은 알약으로. 어디서 왔는지는 마우스를 올리면 나온다.
struct BoostChip: View {
    let boost: ActiveBoost
    var now = Date()

    static func explain(_ kind: ActiveBoost.Kind) -> String {
        L10n.tr({ switch kind {
        case .sales: "탈고한 책이 팔리는 부수에 곱합니다."
        case .characters: "새 토큰이 글자가 되는 비율에 곱합니다."
        case .eventChance: "돌발 상황이 생길 확률에 곱합니다."
        case .refusal: "아이템을 권했을 때 거절할 확률에 더합니다."
        } }())
    }

    var body: some View {
        let good: Bool = switch boost.kind {
        case .sales, .characters: boost.value >= 1
        case .eventChance: boost.value <= 1
        case .refusal: boost.value <= 0
        }
        let color: Color = good ? ChartPalette.good : ChartPalette.warning
        let left = max(0, boost.endsAt.timeIntervalSince(now))
        let remain = left >= 3600 ? L10n.tr("\(Int(left / 3600))시간") : L10n.tr("\(max(1, Int(left / 60)))분")
        Text(boost.text + " · " + remain)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
            .hint(boost.source, [L10n.tr("\(boost.text), \(remain) 남았습니다."), Self.explain(boost.kind)], symbol: "clock")
    }
}

/// 서점 장면. 작가 초상화 틀과 같은 둥근 네모에 창문·책장·주인·계산대. 시간대와 날씨를 따라간다.
struct ShopScene: View {
    var scale: CGFloat = 2.75

    var body: some View {
        let side = 16 * scale
        let dayPart = DayPart.current()
        let weather = Weather.of(Date())
        PixelFrame(rows: Portraits.shopScene(dayPart: dayPart, weather: weather), scale: side / CGFloat(Portraits.size),
                   palette: Portraits.palette(event: nil, dayPart: dayPart, weather: weather))
            .frame(width: side, height: side)
            .background(Color(red: 0.36, green: 0.27, blue: 0.19))
            .clipShape(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous).stroke(.white.opacity(0.12)))
    }
}

/// 정산서 한 장. 요약, 주인의 한마디, 책별 줄(많이 팔린 순, 여섯까지).
struct StatementCard: View {
    let statement: Statement

    var body: some View {
        let delta = Int((statement.trustAfter - statement.trustBefore).rounded())
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.tr("\(statement.weekStart.formatted(.dateTime.month(.defaultDigits).day().locale(L10n.locale))) 주")).font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text(L10n.tr("\(Format.integer(statement.sold))부 · 신뢰 \(TrustLevel.of(statement.trustAfter).title)") + (delta != 0 ? "(\(delta > 0 ? "+" : "")\(delta))" : ""))
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            ForEach(statement.lines.filter { $0.sold + $0.missed + $0.returned > 0 || $0.slot == .window || $0.slot == .counter }.prefix(6)) { line in
                HStack(spacing: 6) {
                    Symbol(name: line.slot.symbol, size: 9)
                    Text(Library.books.first { $0.file == line.book }?.displayTitle ?? line.book).font(.caption2).lineLimit(1)
                    Spacer(minLength: 0)
                    Text(L10n.tr("\(Format.integer(line.sold))부")
                         + (line.returned > 0 ? L10n.tr(" · 반품 \(line.returned)") : "")
                         + (line.missed > 0 ? L10n.tr(" · 놓침 \(Format.integer(line.missed))") : "")
                         + L10n.tr(" · 재고 \(Format.short(line.stock))"))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if !statement.reasons.isEmpty {
                Text(statement.reasons.joined(separator: " / ")).font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
            Text("\"\(statement.keeperLine)\"").font(.caption2).italic().foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
