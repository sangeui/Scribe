import SwiftUI

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
                    Text("창고 · 아이템 \(ItemKind.allCases.reduce(0) { $0 + progress.count($1) })개")
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
            Symbol(name: furniture.symbol, size: 14, color: owned ? ChartPalette.good : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    Text(furniture.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 2)
                    if owned {
                        Text("있음").font(.caption2.weight(.semibold)).foregroundStyle(ChartPalette.good)
                    } else {
                        buyButton(furniture, affordable: affordable)
                    }
                }
                Text(furniture.effect).font(.caption2).foregroundStyle(.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if !owned {
                    costChips(furniture, progress)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(owned ? ChartPalette.good.opacity(0.08) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 값 표시. 가진 수/필요한 수, 모자라면 주황.
    private func costChips(_ furniture: Furniture, _ progress: WritingProgress) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(furniture.cost.enumerated()), id: \.offset) { _, cost in
                let have = progress.count(cost.0)
                let enough = have >= cost.1
                Text("\(cost.0.shortTitle) \(have)/\(cost.1)")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(enough ? Color.secondary : ChartPalette.warning)
                    .fixedSize()
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
                                Text(L10n.tr("\(Self.when(record.date)) · 사건 · \(Dilemmas.byID(record.dilemma)?.title ?? record.dilemma) · \(record.option)")
                                     + (record.auto == true ? L10n.tr(" · 작가가 알아서") : "")).font(.caption2).foregroundStyle(.secondary)
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
        var detail = [Self.when(record.startedAt), L10n.tr("자연재해 · 집필은 계속")]
        if let book { detail.insert(book.displayAuthorShort, at: 0) }
        return HStack(alignment: .top, spacing: 10) {
            PixelIconView(rows: disaster?.icon ?? PixelIcon.warning, color: ChartPalette.warning, scale: 1.6)
                .frame(width: 16, height: 16).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(shield.map { L10n.tr("\(disaster?.cause ?? L10n.tr("재해가 났지만")) \($0.title) 덕에 원고는 무사했습니다") }
                     ?? disaster?.text(lost: lost) ?? L10n.tr("원고 \(Format.integer(lost))자를 잃었습니다")).font(.callout)
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
            if record.endedAt == nil { return L10n.tr("진행 중") }
            if let item = record.endedBy.flatMap(ItemKind.init(rawValue:)) { return L10n.tr("\(Format.particle(item.shortTitle, "으로", "로")) 끝냄") }
            return L10n.tr("저절로 끝남")
        }()
        var detail = [Self.when(record.startedAt), L10n.tr("\(minutes)분"), how]
        if let book { detail.insert(book.displayAuthorShort, at: 0) }
        return HStack(alignment: .top, spacing: 10) {
            PixelIconView(rows: event?.icon ?? PixelIcon.warning, color: .secondary, scale: 1.6)
                .frame(width: 16, height: 16).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(event?.text ?? L10n.tr("알 수 없는 상황")).font(.callout)
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
        if calendar.isDateInToday(date) { return L10n.tr("오늘 \(time)") }
        if calendar.isDateInYesterday(date) { return L10n.tr("어제 \(time)") }
        return "\(date.formatted(.dateTime.month(.defaultDigits).day().locale(L10n.locale))) \(time)"
    }

    private func nextItem(_ progress: WritingProgress) -> some View {
        let fraction = 1 - Double(progress.tokensToNextItem) / Double(Balance.tokensPerItem)
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(ChartPalette.series[0]).frame(width: max(4, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
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
                Text("가득").font(.caption2.weight(.semibold)).foregroundStyle(ChartPalette.warning)
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
        .background(usable ? ChartPalette.series[0].opacity(0.12) : Color.secondary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .opacity(count > 0 ? 1 : 0.7)
    }
}

