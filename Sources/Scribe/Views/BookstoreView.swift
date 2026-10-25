import Charts
import SwiftUI

// 서점. 위에 요약과 지난 14일 판매, 독자 주문, 매대(선반과 꼬리표: 출판사, 이달의 책, 광고), 서평(최근 둘만 펼침), 풍문 세 줄.

/// 팝오버 옆에 여는 서점 화면.
struct BookstorePanel: View {
    @Bindable var store: UsageStore
    var scrollable = true

    var body: some View {
        if let progress = store.writing {
            BookstoreContent(progress: progress, scrollable: scrollable, onFeature: store.feature, onAdvertise: store.advertise,
                             onWriteNext: store.writeNext, onPlace: store.place, onLeave: store.leaveToKeeper, onDismissStatement: store.dismissStatement)
        } else {
            ProgressView()
        }
    }
}

struct BookstoreContent: View {
    let progress: WritingProgress
    var scrollable = true
    var now = Date()
    var onFeature: @MainActor (String?) -> Void = { _ in }
    var onAdvertise: @MainActor (String) -> Void = { _ in }
    var onWriteNext: @MainActor (Int) -> Void = { _ in }
    var onPlace: @MainActor (String, ShopSlot) -> Void = { _, _ in }
    var onLeave: @MainActor (String) -> Void = { _ in }
    var onDismissStatement: @MainActor (String) -> Void = { _ in }

    enum Drawer { case reviews, news, gossip, statements }

    @State private var picked: Int?
    @State private var drawer: Drawer?
    @State private var lastDrawer: Drawer = .reviews
    @State private var showsAllReviews = false
    @State private var statementExpanded = false
    @Environment(\.colorScheme) private var scheme

    /// 살아 있는 것 하나. 칩 한 줄로 보이고, 누른 것만 아래에 펼친다.
    enum LiveItem: Hashable {
        case statement, order, reprint(String), ad(String), boost(String)
    }
    @State private var liveSelection: LiveItem?
    @State private var lastLiveSelection: LiveItem?

    /// 메인 화면과 같은 틀. 머리(장면·이름·숫자), 살아 있는 것(배너), 매대, 꼬리표, 한 줄 둘, 발 버튼. 기록은 발 버튼으로 펼친다.
    var body: some View {
        OptionalScroll(enabled: scrollable) {
            VStack(alignment: .leading, spacing: 12) {
                header
                // 살아 있는 것은 칩 한 줄로. 누른 것 하나만 아래에 자연스럽게 펼친다.
                if !liveItems.isEmpty {
                    let activeLive = liveSelection.flatMap { sel in liveItems.contains(where: { $0.item == sel }) ? sel : nil }
                    VStack(alignment: .leading, spacing: 0) {
                        liveStrip
                        Collapsible(progress: activeLive != nil ? 1 : 0, topSpacing: 8) {
                            if let shown = activeLive ?? lastLiveSelection {
                                liveDetail(shown)
                            }
                        }
                    }
                }
                stand
                if let book = shownBook { tag(book) }
                HStack(spacing: 8) {
                    sparkline
                    newsLine
                }
                VStack(alignment: .leading, spacing: 0) {
                    footer
                    Collapsible(progress: drawer != nil ? 1 : 0, topSpacing: 12) {
                        switch drawer ?? lastDrawer {
                        case .reviews: reviews
                        case .news: news
                        case .gossip: gossip
                        case .statements: statements
                        }
                    }
                }
            }
            .padding(16)
            .onChange(of: drawer) { _, newValue in
                if let newValue { lastDrawer = newValue }
            }
            .onChange(of: liveSelection) { _, newValue in
                if let newValue { lastLiveSelection = newValue }
            }
            .animation(.easeOut(duration: 0.25), value: progress.shopBoosts.count)
            .animation(.snappy(duration: 0.26, extraBounce: 0), value: drawer)
            .animation(.snappy(duration: 0.24, extraBounce: 0), value: liveSelection)
            .animation(.snappy(duration: 0.24, extraBounce: 0), value: statementExpanded)
            .animation(.snappy(duration: 0.24, extraBounce: 0), value: showsAllReviews)
        }
    }

    private var ranked: [Int] {
        let done = Set(progress.finished.map(\.bookIndex))
        return done.sorted { progress.sales(of: Library.books[$0]) > progress.sales(of: Library.books[$1]) }
    }

    private var shownBook: Book? {
        let shown = picked.flatMap { ranked.contains($0) ? $0 : nil } ?? ranked.first
        return shown.map { Library.books[$0] }
    }

    private var reprinting: [(Book, ShopState.Reprint)] {
        Library.books.compactMap { book in progress.reprint(for: book).map { (book, $0) } }
    }

    private var activeAds: [(Book, Date)] {
        Library.books.compactMap { book in progress.adEnds(for: book).map { (book, $0) } }
    }

    private var todaySales: Int { progress.dailySales.last?.copies ?? 0 }

    // MARK: 머리

    private var header: some View {
        HStack(spacing: 12) {
            ShopScene(scale: 2.75)
            VStack(alignment: .leading, spacing: 2) {
                Text("서점").font(.headline)
                Text("오늘 \(Format.integer(todaySales))부 · 모두 \(Format.integer(progress.totalSales))부").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Symbol(name: "newspaper", size: 11)
                        Text("서평 \(progress.reviews.count)").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if let featured = progress.featuredBook.flatMap({ f in Library.books.first { $0.file == f } }) {
                        HStack(spacing: 3) {
                            Symbol(name: "star.fill", size: 10, color: BadgeTier.gold.color)
                            Text(featured.displayTitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .hint("진열창 · \(featured.displayTitle)", ["진열창에 걸린 책은 \(Int((Balance.windowSales - 1) * 100))% 더 팔립니다."], symbol: "star")
                    }
                }
                trustRow
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 0) {
                Text(Format.short(progress.weekSales))
                    .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(BadgeTier.gold.color)
                    .contentTransition(.numericText())
                Text("이번 주").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(
            LinearGradient(colors: [BadgeTier.gold.color.opacity(scheme == .dark ? 0.18 : 0.12), BadgeTier.gold.color.opacity(0.02)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 주인의 신뢰. 다섯 칸 점과 단계 이름.
    private var trustRow: some View {
        let level = progress.trustLevel
        let recent = progress.shop.trustLog.suffix(3).reversed().map { "\($0.reason) (\($0.delta > 0 ? "+" : "")\(Int($0.delta.rounded())))" }
        return HStack(spacing: 4) {
            Symbol(name: "person", size: 10)
            Text("주인 · \(level.title)").font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Circle().fill(i <= level.rawValue ? Color.primary.opacity(0.55) : Color.secondary.opacity(0.2)).frame(width: 5, height: 5)
                }
            }
        }
        .hint("주인의 신뢰 \(Int(progress.shop.trust.rounded())) · \(level.title)",
              [level.detail, "책이 꾸준히 팔리고 독자 주문을 지키고 낭독회·사인회가 잘 끝나면 오르고, 매대 책이 품절되거나 반품이 오거나 주문을 놓치면 내립니다."]
              + (recent.isEmpty ? [] : ["최근: " + recent.joined(separator: " / ")]), symbol: "person")
    }

    // MARK: 살아 있는 것(칩 한 줄)

    /// 지금 살아 있는 것들. 정산서, 독자 주문, 품절·재판, 광고, 서점 사건 보정.
    private var liveItems: [(item: LiveItem, symbol: String, text: String, color: Color, attention: Bool)] {
        var items: [(LiveItem, String, String, Color, Bool)] = []
        if let statement = progress.statementCard {
            let delta = Int((statement.trustAfter - statement.trustBefore).rounded())
            items.append((.statement, "doc.text", "정산서 \(Format.short(statement.sold))부" + (delta != 0 ? " · 신뢰 \(delta > 0 ? "+" : "")\(delta)" : ""), .secondary, true))
        }
        if let order = progress.order {
            let days = max(0, Int(ceil(order.expiresAt.timeIntervalSince(now) / 86_400)))
            let index = Library.books.firstIndex { $0.file == order.book }
            let canPull = index.map { progress.pendingInRound.dropFirst().contains($0) } ?? false
            items.append((.order, "envelope.open", "독자 주문 \(days)일", BadgeTier.gold.color, canPull))
        }
        for (book, reprint) in reprinting {
            let hours = max(1, Int((reprint.due.timeIntervalSince(now) / 3600).rounded(.up)))
            items.append((.reprint(book.file), "printer", "\(book.displayTitle) 품절 · \(hours)시간", ChartPalette.warning, false))
        }
        for (book, ends) in activeAds {
            items.append((.ad(book.file), "megaphone.fill", "\(book.displayTitle) 광고 · \(max(1, Int(ends.timeIntervalSince(now) / 3600)))시간", ChartPalette.warning, false))
        }
        for boost in progress.shopBoosts {
            let good = boost.value >= 1
            let delta = Int(((boost.value - 1) * 100).rounded())
            let event = ShopEvents.all.first { $0.title == boost.source }
            items.append((.boost(boost.id), event?.symbol ?? "storefront", "\(boost.source) \(delta >= 0 ? "+" : "")\(delta)%", good ? ChartPalette.good : ChartPalette.warning, false))
        }
        return items.map { (item: $0.0, symbol: $0.1, text: $0.2, color: $0.3, attention: $0.4) }
    }

    private var liveStrip: some View {
        FlowLayout(spacing: 6) {
            Group {
                ForEach(liveItems, id: \.item) { entry in
                    let on = liveSelection == entry.item
                    Button { liveSelection = on ? nil : entry.item } label: {
                        HStack(spacing: 4) {
                            Symbol(name: entry.symbol, size: 10, color: entry.color)
                            Text(entry.text).font(.caption2.weight(.medium)).lineLimit(1)
                            if entry.attention, !on {
                                Circle().fill(entry.color == .secondary ? Color.primary : entry.color).frame(width: 5, height: 5)
                            }
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .foregroundStyle(on ? Color.primary : Color.secondary)
                        .background((entry.color == .secondary ? Color.primary : entry.color).opacity(on ? 0.16 : 0.07), in: Capsule())
                        .overlay(Capsule().stroke((entry.color == .secondary ? Color.primary : entry.color).opacity(on ? 0.35 : 0), lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func liveDetail(_ item: LiveItem) -> some View {
        switch item {
        case .statement:
            if let statement = progress.statementCard { statementBanner(statement) }
        case .order:
            if let order = progress.order { orderCard(order) }
        case .reprint(let file):
            if let (book, reprint) = reprinting.first(where: { $0.0.file == file }) { reprintBanner(book, reprint: reprint) }
        case .ad(let file):
            if let (book, ends) = activeAds.first(where: { $0.0.file == file }) { adBanner(book, ends: ends) }
        case .boost(let id):
            if let boost = progress.shopBoosts.first(where: { $0.id == id }) { boostBanner(boost) }
        }
    }

    // MARK: 배너(살아 있는 것)

    /// 지난주 정산서. 한 줄 요약과 주인의 한마디. "펼치기"로 책별 줄을 그 자리에서 펼치거나 접는다.
    private func statementBanner(_ statement: Statement) -> some View {
        let delta = Int((statement.trustAfter - statement.trustBefore).rounded())
        let visibleLines = statement.lines.filter { $0.sold + $0.missed + $0.returned > 0 || $0.slot == .window || $0.slot == .counter }.prefix(6)
        return HStack(alignment: .top, spacing: 10) {
            Symbol(name: "doc.text", size: 16, color: .secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("지난주 정산서").font(.callout.weight(.semibold))
                    Spacer(minLength: 0)
                    if RenderMode.offscreen {
                        ChipLabel(title: "펼치기", prominent: false)
                    } else {
                        Button(statementExpanded ? "접기" : "펼치기") { statementExpanded.toggle() }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                        Button("닫기") { onDismissStatement(statement.id) }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("\(Format.integer(statement.sold))부 팔림" + (statement.returned > 0 ? " · 반품 \(Format.integer(statement.returned))" : "")
                     + (statement.missed > 0 ? " · 놓친 손님 \(Format.integer(statement.missed))" : "")
                     + " · 신뢰 \(TrustLevel.of(statement.trustAfter).title)" + (delta != 0 ? "(\(delta > 0 ? "+" : "")\(delta))" : ""))
                    .font(.caption).foregroundStyle(.secondary)
                Collapsible(progress: statementExpanded ? 1 : 0, topSpacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(visibleLines) { line in
                            HStack(spacing: 6) {
                                Symbol(name: line.slot.symbol, size: 9)
                                Text(Library.books.first { $0.file == line.book }?.displayTitle ?? line.book).font(.caption2).lineLimit(1)
                                Spacer(minLength: 0)
                                Text("\(Format.integer(line.sold))부"
                                     + (line.returned > 0 ? " · 반품 \(line.returned)" : "")
                                     + (line.missed > 0 ? " · 놓침 \(Format.integer(line.missed))" : "")
                                     + " · 재고 \(Format.short(line.stock))")
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        if !statement.reasons.isEmpty {
                            Text(statement.reasons.joined(separator: " / ")).font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Text("\"\(statement.keeperLine)\"").font(.caption).italic().foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 품절. 재판이 들어올 때까지.
    private func reprintBanner(_ book: Book, reprint: ShopState.Reprint) -> some View {
        let hours = max(1, Int((reprint.due.timeIntervalSince(now) / 3600).rounded(.up)))
        return HStack(spacing: 10) {
            Symbol(name: "printer", size: 16, color: ChartPalette.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(book.displayTitle) 품절").font(.callout.weight(.semibold)).lineLimit(1)
                Text("재판 \(Format.integer(reprint.copies))부가 \(hours)시간 뒤에 들어옵니다 · 그동안 손님을 돌려보냅니다").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(ChartPalette.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func adBanner(_ book: Book, ends: Date) -> some View {
        HStack(spacing: 10) {
            Symbol(name: "megaphone.fill", size: 16, color: ChartPalette.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(book.displayTitle) 광고 중").font(.callout.weight(.semibold)).lineLimit(1)
                Text("\(Int(Balance.adBoost))배로 팔립니다 · \(max(1, Int(ends.timeIntervalSince(now) / 3600)))시간 남음").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(ChartPalette.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func boostBanner(_ boost: ShopBoost) -> some View {
        let book = boost.book.flatMap { f in Library.books.first { $0.file == f } }
        let event = ShopEvents.all.first { $0.title == boost.source }
        let good = boost.value >= 1
        let delta = Int(((boost.value - 1) * 100).rounded())
        return HStack(spacing: 10) {
            Symbol(name: event?.symbol ?? "storefront", size: 16, color: good ? ChartPalette.good : ChartPalette.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(boost.source).font(.callout.weight(.semibold))
                Text("\(book?.displayTitle ?? "모든 책") 판매 \(delta >= 0 ? "+" : "")\(delta)% · \(max(1, Int(boost.endsAt.timeIntervalSince(now) / 3600)))시간 남음")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background((good ? ChartPalette.good : ChartPalette.warning).opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: 매대(원고 자리)

    /// 자리별로 작은 칩에 담는다. 진열창, 매대, 서가, 창고(품절). 누르면 아래 꼬리표가 그 책으로 바뀐다.
    private var stand: some View {
        Group {
            if ranked.isEmpty {
                Text("탈고한 책이 여기 놓입니다. 첫 책을 끝내면 서점이 문을 엽니다.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ShopSlot.allCases, id: \.self) { slot in
                        let books = progress.books(in: slot)
                        if !books.isEmpty || slot == .counter || (slot == .window && progress.trustLevel.hasWindow) {
                            HStack(alignment: .top, spacing: 8) {
                                slotLabel(slot, count: books.count)
                                FlowLayout(spacing: 6) {
                                    Group {
                                        ForEach(books, id: \.file) { book in chip(book) }
                                        if books.isEmpty {
                                            Text(slot == .window ? "비어 있음" : "빈 칸").font(.caption2).foregroundStyle(.tertiary).padding(.vertical, 5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func slotLabel(_ slot: ShopSlot, count: Int) -> some View {
        let slots = progress.trustLevel.counterSlots
        let text = slot == .counter ? "매대 \(count)/\(slots)" : slot.title
        let hint: [String] = switch slot {
        case .window: ["진열창에 걸린 책은 \(Int((Balance.windowSales - 1) * 100))% 더 팔립니다. 신뢰가 '안면' 이상이어야 쓸 수 있고 하루에 한 번 바꿉니다."]
        case .counter: ["매대 책은 제값에 팔립니다. 칸 수는 주인의 신뢰에 달렸습니다(\(slots)칸). 비면 주인이 잘 팔릴 책으로 채우고, 아침마다 다시 정리합니다."]
        case .shelf: ["서가 책은 \(Int(Balance.shelfSales * 100))%만 팔립니다. 직접 내린 책은 이레 동안 주인이 다시 올리지 않습니다."]
        case .storage: ["재고가 떨어진 책. 재판이 들어오면 다시 자리를 잡습니다."]
        }
        return HStack(spacing: 3) {
            Symbol(name: slot.symbol, size: 9)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 58, alignment: .leading)
        .padding(.vertical, 5)
        .hint(slot.title, hint, symbol: slot.symbol)
    }

    private func chip(_ book: Book) -> some View {
        let index = Library.books.firstIndex { $0.file == book.file } ?? 0
        let slot = progress.slot(of: book)
        return BookChip(book: book, tier: progress.salesTier(of: book), selected: shownBook?.file == book.file,
                        featured: progress.featuredBook == book.file, advertised: progress.adEnds(for: book) != nil,
                        sales: progress.sales(of: book), soldOut: slot == .storage, pinned: progress.isPinned(book))
            .onTapGesture { picked = index }
    }

    // MARK: 한 줄 둘

    /// 지난 14일 판매를 작은 막대로.
    private var sparkline: some View {
        let days = progress.dailySales
        let peak = max(1, days.map(\.copies).max() ?? 1)
        return HStack(spacing: 8) {
            Symbol(name: "chart.bar", size: 11)
            Canvas { context, size in
                let w = size.width / CGFloat(max(1, days.count))
                for (i, day) in days.enumerated() {
                    let h = max(2, size.height * CGFloat(day.copies) / CGFloat(peak))
                    let rect = CGRect(x: CGFloat(i) * w + 1, y: size.height - h, width: max(2, w - 2), height: h)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(BadgeTier.gold.color.opacity(i == days.count - 1 ? 1 : 0.5)))
                }
            }
            .frame(height: 18)
            Text("\(Format.short(progress.dailySales.map(\.copies).reduce(0, +)))부 / 14일").font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize()
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .hint("지난 14일 판매", days.suffix(7).map { "\($0.day.formatted(.dateTime.month(.defaultDigits).day())) \(Format.integer($0.copies))부" }, symbol: "chart.bar")
    }

    /// 최근 서점 소식 한 줄. 누르면 아래에 목록이 펼쳐진다.
    private var newsLine: some View {
        let latest = progress.shopLog.first
        let event = latest.flatMap { ShopEvents.byID($0.event) }
        return Button { drawer = drawer == .news ? nil : .news } label: {
            HStack(spacing: 6) {
                Symbol(name: event?.symbol ?? "storefront", size: 11, color: (event?.good ?? true) ? .secondary : ChartPalette.warning)
                Text(latest?.text ?? "아직 소식이 없습니다").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 발

    private var footer: some View {
        HStack(spacing: 8) {
            footerButton(symbol: "newspaper", title: "서평", detail: "\(progress.reviews.count)", drawer: .reviews)
            footerButton(symbol: "storefront", title: "소식", detail: "\(progress.shopLog.count)", drawer: .news)
            footerButton(symbol: "ear", title: "풍문", detail: "", drawer: .gossip)
            footerButton(symbol: "doc.text", title: "정산", detail: progress.shop.statements.isEmpty ? "" : "\(progress.shop.statements.count)", drawer: .statements)
        }
    }

    private func footerButton(symbol: String, title: String, detail: String, drawer target: Drawer) -> some View {
        let on = drawer == target
        return Button { drawer = on ? nil : target } label: {
            HStack(spacing: 5) {
                Symbol(name: symbol, size: 11, color: on ? .primary : .secondary)
                Text(title).font(.caption.weight(.semibold))
                if !detail.isEmpty { Text(detail).font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(on ? 0.16 : 0.08), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func orderCard(_ order: ReaderOrder) -> some View {
        let book = Library.books.first { $0.file == order.book }
        let index = Library.books.firstIndex { $0.file == order.book }
        let days = max(0, Int(ceil(order.expiresAt.timeIntervalSince(now) / 86_400)))
        let canPull = index.map { progress.pendingInRound.dropFirst().contains($0) } ?? false
        return HStack(spacing: 10) {
            Symbol(name: "envelope.open", size: 14, color: BadgeTier.gold.color)
            VStack(alignment: .leading, spacing: 3) {
                Text("독자 주문").font(.caption.weight(.semibold))
                Text(order.text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text("\(days)일 안에 쓰기 시작하면 그 책이 신간 기간 동안 \(Int((Balance.orderBoost - 1) * 100))% 더 팔립니다").font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if let index, canPull {
                if RenderMode.offscreen {
                    ChipLabel(title: "다음에 쓰기", prominent: true)
                } else {
                    Button("다음에 쓰기") { onWriteNext(index) }.buttonStyle(.borderedProminent).controlSize(.small)
                }
            } else if let book, progress.nextBook?.file == book.file {
                Text("다음 차례").font(.caption2.weight(.semibold)).foregroundStyle(BadgeTier.gold.color)
            }
        }
        .padding(12)
        .background(BadgeTier.gold.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: 서점 소식

    /// 최근 서점 사건 다섯. 무슨 일인지, 언제, 어떤 효과가 붙었는지.
    private var news: some View {
        VStack(spacing: 0) {
            ForEach(progress.shopLog.prefix(5)) { record in
                let event = ShopEvents.byID(record.event)
                HStack(alignment: .top, spacing: 10) {
                    Symbol(name: event?.symbol ?? "storefront", size: 13, color: (event?.good ?? true) ? .secondary : ChartPalette.warning)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.text).font(.caption).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text(record.date.formatted(.dateTime.month(.defaultDigits).day().hour().minute())).font(.caption2).foregroundStyle(.secondary)
                            if let effect = Self.effectText(event, copies: record.copies) {
                                Text(effect).font(.caption2.weight(.medium)).foregroundStyle((event?.good ?? true) ? ChartPalette.good : ChartPalette.warning)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 7)
                if record.id != progress.shopLog.prefix(5).last?.id { Divider().opacity(0.5) }
            }
        }
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private static func effectText(_ event: ShopEvent?, copies: Int?) -> String? {
        guard let event else { return nil }
        switch event.effect {
        case .sales(let m, let h):
            let delta = Int(((m - 1) * 100).rounded())
            return "\(event.scope == .all ? "모든 책" : "그 책") 판매 \(delta >= 0 ? "+" : "")\(delta)% · \(h)시간"
        case .copies: return copies.map { "+\(Format.integer($0))부" }
        case .returned: return copies.map { "\(Format.integer($0))부" }
        case .restock: return copies.map { "재고 +\(Format.integer($0))부" }
        case .items(let n): return n > 0 ? "아이템 +\(n)" : "아이템 \(n)"
        case .inspiration(let f): return "영감 +\(Int(f * 100))%"
        case .feature: return "이달의 책"
        case .order: return "독자 주문"
        case .none: return nil
        }
    }

    /// 꼬리표: 고른 책의 부수, 출판사, 단계 사다리, 밀어주기·광고 버튼.
    private func tag(_ book: Book) -> some View {
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
            parts.append("품절 · 재판 \(Format.integer(reprint.copies))부 \(max(1, Int((reprint.due.timeIntervalSince(now) / 3600).rounded(.up))))시간 뒤")
        } else {
            parts.append("재고 \(Format.integer(progress.stock(of: book)))부")
        }
        if let slot, slot != .storage { parts.append(slot.title + (pinned ? " · 직접 고름" : benched ? " · 직접 내림" : " · 주인이 정함")) }
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

    private static func percent(_ multiplier: Double) -> String {
        let delta = Int(((multiplier - 1) * 100).rounded())
        return delta >= 0 ? "+\(delta)%" : "\(delta)%"
    }

    // MARK: 정산서

    private var statements: some View {
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

    private var reviews: some View {
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
                        Button(showsAllReviews ? "최근 둘만" : "서평 \(progress.reviews.count - 2)편 더") { showsAllReviews.toggle() }
                            .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: 풍문

    private var gossip: some View {
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
            Text(soldOut ? "품절" : Format.short(sales)).font(.caption2.monospacedDigit()).foregroundStyle(soldOut ? ChartPalette.warning : .secondary)
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
                        Text(Format.short(step.copies) + "부").font(.system(size: 8).monospacedDigit()).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .hint(step.title + " · " + Format.short(step.copies) + "부", [step.meaning + "."], symbol: "chart.line.uptrend.xyaxis")
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
        switch kind {
        case .sales: "탈고한 책이 팔리는 부수에 곱합니다."
        case .characters: "새 토큰이 글자가 되는 비율에 곱합니다."
        case .eventChance: "돌발 상황이 생길 확률에 곱합니다."
        case .refusal: "아이템을 권했을 때 거절할 확률에 더합니다."
        }
    }

    var body: some View {
        let good: Bool = switch boost.kind {
        case .sales, .characters: boost.value >= 1
        case .eventChance: boost.value <= 1
        case .refusal: boost.value <= 0
        }
        let color: Color = good ? ChartPalette.good : ChartPalette.warning
        let left = max(0, boost.endsAt.timeIntervalSince(now))
        let remain = left >= 3600 ? "\(Int(left / 3600))시간" : "\(max(1, Int(left / 60)))분"
        Text(boost.text + " · " + remain)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
            .hint(boost.source, ["\(boost.text), \(remain) 남았습니다.", Self.explain(boost.kind)], symbol: "clock")
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
                Text(statement.weekStart.formatted(.dateTime.month(.defaultDigits).day()) + " 주").font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text("\(Format.integer(statement.sold))부 · 신뢰 \(TrustLevel.of(statement.trustAfter).title)" + (delta != 0 ? "(\(delta > 0 ? "+" : "")\(delta))" : ""))
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            ForEach(statement.lines.filter { $0.sold + $0.missed + $0.returned > 0 || $0.slot == .window || $0.slot == .counter }.prefix(6)) { line in
                HStack(spacing: 6) {
                    Symbol(name: line.slot.symbol, size: 9)
                    Text(Library.books.first { $0.file == line.book }?.displayTitle ?? line.book).font(.caption2).lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(Format.integer(line.sold))부"
                         + (line.returned > 0 ? " · 반품 \(line.returned)" : "")
                         + (line.missed > 0 ? " · 놓침 \(Format.integer(line.missed))" : "")
                         + " · 재고 \(Format.short(line.stock))")
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
