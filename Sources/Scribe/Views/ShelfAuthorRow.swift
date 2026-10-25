import SwiftUI

/// 작가별 서가 카드: 초상화와 이름, 나무 선반 위의 책등들, 그리고 클릭 시 펼쳐지는 슬림 서랍(1줄 능력치 바 · 1줄 장신구 아이콘 타일).
struct AuthorRow: View {
    let author: String
    let progress: WritingProgress
    let selected: Int
    let expanded: Bool
    var keepDrawerContent = true
    let decorTick: Int
    let onSelectBook: (Int) -> Void
    let onToggleExpand: () -> Void
    let onFocusAuthor: (String) -> Void
    let onChooseDecor: (Accessory?) -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let works = Library.books.enumerated().filter { $0.element.authorShort == author }
        let firstBook = works.first?.element
        let displayAuthor = firstBook?.displayAuthor ?? author
        let shortAuthor = firstBook?.displayAuthorShort ?? author
        let tint = firstBook?.spineColor ?? .secondary
        let done = works.filter { if case .done = BookStatus(index: $0.offset, progress: progress) { true } else { false } }.count
        let isWritingAuthor = works.contains { $0.offset == progress.bookIndex }
        let isSelectedAuthor = works.contains { $0.offset == selected }
        let pendingCount = progress.pendingInRound.filter { Library.books[$0].authorShort == author }.count
        let sold = works.reduce(0) { $0 + progress.sales(of: $1.element) }
        let hasWindowBook = works.contains { progress.slot(of: $0.element) == .window }
        let counterCount = works.filter { progress.slot(of: $0.element) == .counter }.count
        let sheet = progress.sheet(for: author)
        let perks = StatPerks(sheet)
        let chosenDecor = Decor.chosen(for: author)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: onToggleExpand) {
                    PortraitFrame(author: author, scale: 2.2)
                        .id("\(author)-\(decorTick)")
                }
                .buttonStyle(.plain)
                .hint(displayAuthor, ["초상화나 작가 이름을 눌러 능력치·장신구 서랍을 엽니다."], symbol: "person.text.rectangle")

                VStack(alignment: .leading, spacing: 5) {
                    // 1단: 작가 이름 + 상태 배지 + 간결 요약 + 서점 전면 진열 배지 + 우측 메타/화살표
                    Button(action: onToggleExpand) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(displayAuthor).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                            if done == works.count && !works.isEmpty {
                                Text("완간")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .padding(.horizontal, 4.5).padding(.vertical, 1)
                                    .foregroundStyle(BadgeTier.gold.color)
                                    .background(BadgeTier.gold.color.opacity(0.15), in: Capsule())
                            } else if isWritingAuthor {
                                Text("집필 중")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .padding(.horizontal, 4.5).padding(.vertical, 1)
                                    .foregroundStyle(tint)
                                    .background(tint.opacity(0.14), in: Capsule())
                            }
                            Text(summaryText(done: done, total: works.count, sold: sold))
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                            if hasWindowBook {
                                HStack(spacing: 2) {
                                    Symbol(name: "star.fill", size: 7.5, color: BadgeTier.gold.color)
                                    Text(L10n.isEnglish ? "Window" : "진열창").font(.system(size: 8.5, weight: .semibold))
                                }
                                .padding(.horizontal, 4.5).padding(.vertical, 1)
                                .foregroundStyle(BadgeTier.gold.color)
                                .background(BadgeTier.gold.color.opacity(0.14), in: Capsule())
                            } else if counterCount > 0 {
                                HStack(spacing: 2) {
                                    Symbol(name: "tablecells.fill", size: 7.5, color: ChartPalette.series[0])
                                    Text(L10n.isEnglish ? "Table \(counterCount)" : "매대 \(counterCount)").font(.system(size: 8.5, weight: .semibold))
                                }
                                .padding(.horizontal, 4.5).padding(.vertical, 1)
                                .foregroundStyle(ChartPalette.series[0])
                                .background(ChartPalette.series[0].opacity(0.14), in: Capsule())
                            }
                            Spacer(minLength: 4)
                            HStack(spacing: 4) {
                                if let chosenDecor {
                                    Text(chosenDecor.title)
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(.tertiary)
                                }
                                if sheet.total > 0 {
                                    Text("+\(sheet.total)")
                                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                                        .padding(.horizontal, 4.5).padding(.vertical, 1)
                                        .foregroundStyle(.secondary)
                                        .background(Color.secondary.opacity(0.1), in: Capsule())
                                }
                                Symbol(name: "chevron.down", size: 8)
                                    .rotationEffect(.degrees(expanded ? 180 : 0))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // 2단: 나무 선반 위 책등들 (선반 폭을 넘기면 자동으로 다음 단 선반으로 줄바꿈)
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(shelfRows(for: works, maxWidth: 276).enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .bottom, spacing: 3) {
                                    ForEach(row, id: \.element.id) { index, book in
                                        Spine(book: book, status: BookStatus(index: index, progress: progress),
                                              selected: index == selected, height: 25, tier: progress.salesTier(of: book),
                                              slot: progress.slot(of: book))
                                            .onTapGesture { onSelectBook(index) }
                                            .hint(book.displayTitle, [workHintLine(index: index, book: book)], symbol: "book.closed")
                                    }
                                    Spacer(minLength: 0)
                                }
                                shelfLedge(tint: tint)
                            }
                        }
                    }
                }
            }

            // 3단: 슬림 작가 서랍 (1줄 체력·능력치 바 + 1줄 초상화 장신구 아이콘 스트립 및 몰아 쓰기 버튼)
            Collapsible(progress: expanded ? 1 : 0, topSpacing: 8) {
                if keepDrawerContent {
                    VStack(alignment: .leading, spacing: 7) {
                        Divider().opacity(0.4)
                        compactStatsBar(sheet: sheet, perks: perks, shortAuthor: shortAuthor)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .center, spacing: 5) {
                                Text("초상화 장신구").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
                                Text("· \(chosenDecor?.title ?? L10n.tr("착용 없음"))").font(.system(size: 9.5)).foregroundStyle(.tertiary)
                                Spacer()
                                if pendingCount >= 2 {
                                    focusAuthorButton(shortAuthor: shortAuthor, tint: tint)
                                }
                            }
                            HStack(spacing: 4.5) {
                                decorIconTile(nil, shortAuthor: shortAuthor)
                                ForEach(Decor.all) { accessory in
                                    decorIconTile(accessory, shortAuthor: shortAuthor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7.5)
        .background(
            isSelectedAuthor || expanded
                ? tint.opacity(scheme == .dark ? 0.11 : 0.065)
                : Color.secondary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(isSelectedAuthor || expanded ? tint.opacity(0.32) : Color.primary.opacity(0.04), lineWidth: 1)
        )
    }

    private func summaryText(done: Int, total: Int, sold: Int) -> String {
        L10n.tr(sold > 0 ? "\(done)/\(total)편 · \(Format.short(sold))부" : "\(done)/\(total)편")
    }

    private func shelfRows(for works: [(offset: Int, element: Book)], maxWidth: CGFloat) -> [[(offset: Int, element: Book)]] {
        var rows: [[(offset: Int, element: Book)]] = []
        var current: [(offset: Int, element: Book)] = []
        var width: CGFloat = 0
        for item in works {
            let w = Spine.width(for: item.element, height: 25)
            let needed = current.isEmpty ? w : w + 3
            if !current.isEmpty && width + needed > maxWidth {
                rows.append(current)
                current = [item]
                width = w
            } else {
                current.append(item)
                width += needed
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    @ViewBuilder
    private func focusAuthorButton(shortAuthor: String, tint: Color) -> some View {
        if RenderMode.offscreen {
            ChipLabel(title: "\(shortAuthor) 몰아 쓰기")
        } else {
            Button { onFocusAuthor(author) } label: {
                HStack(spacing: 3) {
                    Symbol(name: "books.vertical", size: 8.5, color: tint)
                    Text("\(shortAuthor) 몰아 쓰기").font(.system(size: 9.5, weight: .semibold))
                }
                .padding(.horizontal, 7).padding(.vertical, 2.5)
                .foregroundStyle(tint)
                .background(tint.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func workHintLine(index: Int, book: Book) -> String {
        switch BookStatus(index: index, progress: progress) {
        case .done:
            let sold = progress.sales(of: book)
            let base = L10n.tr(sold > 0 ? "\(book.title) · 탈고 (\(Format.integer(sold))부 판매)" : "\(book.title) · 탈고 (\(Format.integer(book.characters))자)")
            if let slot = progress.slot(of: book) {
                let stockText = slot == .storage
                    ? (L10n.isEnglish ? "Sold out" : "품절")
                    : L10n.tr("재고 \(Format.integer(progress.stock(of: book)))부")
                return base + " · \(slot.title) (\(stockText))"
            }
            return base
        case .current(let f):
            return L10n.tr("\(book.title) · 쓰는 중 \(Format.percent(f * 100))")
        case .pending:
            let ahead = max(1, (progress.position(of: index) ?? index) - progress.orderPosition)
            return L10n.tr("\(book.title) · \(ahead)편 뒤 예정 (\(Format.integer(book.characters))자)")
        }
    }

    /// 1줄로 압축한 작가 체력 + 5대 능력치 + 다음 상승 토큰 바.
    private func compactStatsBar(sheet: AuthorSheet, perks: StatPerks, shortAuthor: String) -> some View {
        let tired = sheet.stamina < perks.staminaMax * Balance.staminaTiredBelow
        let fraction = max(0, min(1, sheet.stamina / max(1, perks.staminaMax)))
        let heartColor: Color = fraction <= 0.1 ? ChartPalette.critical : tired ? ChartPalette.warning : ChartPalette.rose
        let tokensToNext = max(0, Balance.statTokens - sheet.tokensTowardStat)
        return HStack(spacing: 4) {
            HStack(spacing: 3) {
                Symbol(name: tired ? "heart.slash" : "heart.fill", size: 9, color: heartColor)
                Text("\(Int(sheet.stamina.rounded()))")
                    .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
            .padding(.horizontal, 6).padding(.vertical, 3.5)
            .background(Color.secondary.opacity(0.08), in: Capsule())
            .hint("체력 \(Int(sheet.stamina.rounded())) / \(Int(perks.staminaMax))",
                  ["새 토큰 100만 개마다 \(String(format: "%.1f", Balance.staminaPerMillion))씩 줄고, 한 시간에 \(Int(Balance.staminaRecoveryPerHour))씩 돌아옵니다.",
                   "끈기가 오르면 최대 체력이 늘고 덜 줄어듭니다."],
                  symbol: "heart")

            ForEach(Stat.allCases, id: \.self) { stat in
                let level = sheet.level(stat)
                HStack(spacing: 2.5) {
                    Symbol(name: stat.symbol, size: 8.5, color: level > 0 ? .primary : .secondary.opacity(0.7))
                    Text("\(stat.title) \(level)")
                        .font(.system(size: 9.5, weight: level > 0 ? .medium : .regular).monospacedDigit())
                        .foregroundStyle(level > 0 ? .primary : .secondary)
                }
                .fixedSize()
                .padding(.horizontal, 5.5).padding(.vertical, 3.5)
                .background(Color.secondary.opacity(level > 0 ? 0.1 : 0.05), in: Capsule())
                .hint("\(stat.title) \(level)",
                      [level > 0 ? "지금: \(stat.effectText(level: level))" : "아직 0입니다.",
                       level < Balance.statMax ? "다음: \(stat.effectText(level: level + 1))" : "끝까지 올랐습니다.",
                       stat.raisedLine],
                      symbol: stat.symbol)
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                Symbol(name: "arrow.up", size: 8, color: .secondary)
                Text(Format.short(tokensToNext))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .fixedSize()
            .hint("다음 능력치까지",
                  ["\(shortAuthor)의 능력치는 새 토큰 \(Format.short(Balance.statTokens)) 개마다 하나가 무작위로 1 오릅니다. \(Format.integer(tokensToNext)) 개 남았습니다."],
                  symbol: "arrow.up")
        }
    }

    /// 책등 아래를 받치는 나무/서재 선반선.
    private func shelfLedge(tint: Color) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(scheme == .dark ? 0.35 : 0.24),
                            Color(red: 0.42, green: 0.30, blue: 0.20).opacity(scheme == .dark ? 0.45 : 0.28)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 4)
            Rectangle()
                .fill(Color.white.opacity(scheme == .dark ? 0.12 : 0.35))
                .frame(height: 1)
                .padding(.horizontal, 1)
        }
    }

    /// 1줄 아이콘 스트립용 장신구 타일: 텍스트 없이 24×24 초상화 아이콘만 노출하고 이름·해금 조건은 툴팁으로 안내.
    private func decorIconTile(_ accessory: Accessory?, shortAuthor: String) -> some View {
        let unlocked = accessory.map { Decor.isUnlocked($0, progress: progress) } ?? true
        let isChosen = Decor.chosen(for: author)?.id == accessory?.id
        let rows = accessory.map { Decor.apply(Portraits.rows(author), accessory: $0) } ?? Portraits.rows(author)
        let title = accessory?.title ?? L10n.tr("착용 안 함")
        let lockedBy = accessory?.unlock.flatMap { Achievements.byID($0)?.title }
        return Button {
            guard unlocked else { return }
            onChooseDecor(accessory)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                PixelFrame(rows: rows, scale: 24 / CGFloat(Portraits.size), palette: Portraits.palette)
                    .frame(width: 24, height: 24)
                    .background(Portraits.backdrop(author))
                    .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
                    .saturation(unlocked ? 1 : 0)
                    .opacity(unlocked ? 1 : 0.32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .stroke(isChosen ? ChartPalette.series[0] : Color.primary.opacity(0.08), lineWidth: isChosen ? 1.8 : 0.8)
                    )
                if !unlocked {
                    Symbol(name: "lock.fill", size: 6.5, color: .secondary)
                        .padding(2)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
        }
        .buttonStyle(.plain)
        .hint(title,
              unlocked
                  ? [isChosen ? "현재 \(shortAuthor)에게 착용 중입니다." : "누르면 \(shortAuthor)에게 착용합니다."]
                  : ["성과 \"\(lockedBy ?? "업적")\" 달성 시 열립니다."],
              symbol: unlocked ? "sparkles" : "lock")
    }
}
